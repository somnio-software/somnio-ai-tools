"""Unit tests for scripts/dora_metrics.py.

No network: all GitHub calls are mocked at the function level
(get_prod_releases, get_prod_tags, get_merged_prs_between,
get_pr_first_commit_ts). They run in seconds.

Usage:
    python3 -m unittest discover -s tests -p "test_*.py" -v
"""

import argparse
import importlib.util
import os
import tempfile
import unittest
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import patch

SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "..", "scripts", "dora_metrics.py")
_spec = importlib.util.spec_from_file_location("dora_metrics", SCRIPT_PATH)
dora_metrics = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dora_metrics)


def dt(s):
    return dora_metrics.parse_ts(s)


class TestTimestamps(unittest.TestCase):
    def test_parse_fmt_roundtrip(self):
        s = "2026-07-01T12:00:00Z"
        self.assertEqual(dora_metrics.fmt_ts(dora_metrics.parse_ts(s)), s)

    def test_parse_ts_is_utc_aware(self):
        d = dora_metrics.parse_ts("2026-07-01T12:00:00Z")
        self.assertEqual(d.tzinfo, timezone.utc)


class TestPositiveInt(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(dora_metrics._positive_int("5"), 5)

    def test_rejects_zero(self):
        with self.assertRaises(argparse.ArgumentTypeError):
            dora_metrics._positive_int("0")

    def test_rejects_negative(self):
        with self.assertRaises(argparse.ArgumentTypeError):
            dora_metrics._positive_int("-3")

    def test_rejects_non_numeric(self):
        with self.assertRaises(argparse.ArgumentTypeError):
            dora_metrics._positive_int("abc")


class TestValidateScopedOverrides(unittest.TestCase):
    def test_branch_without_project_raises(self):
        args = SimpleNamespace(branch="main", project=None, deploy_source=None)
        with self.assertRaises(ValueError):
            dora_metrics.validate_scoped_overrides(args)

    def test_deploy_source_without_project_raises(self):
        args = SimpleNamespace(branch=None, project=None, deploy_source="tag")
        with self.assertRaises(ValueError):
            dora_metrics.validate_scoped_overrides(args)

    def test_with_project_ok(self):
        args = SimpleNamespace(branch="main", project="Example Project", deploy_source="tag")
        dora_metrics.validate_scoped_overrides(args)  # should not raise

    def test_no_overrides_ok(self):
        args = SimpleNamespace(branch=None, project=None, deploy_source=None)
        dora_metrics.validate_scoped_overrides(args)  # should not raise


class TestValidateDeploySources(unittest.TestCase):
    def test_valid_sources_ok(self):
        projects = [{"repos": [{"repo": "a/b", "deploy_source": "release"},
                                {"repo": "a/c", "deploy_source": "tag"},
                                {"repo": "a/d"}]}]  # no field -> default release
        dora_metrics.validate_deploy_sources(projects)  # should not raise

    def test_invalid_source_raises(self):
        projects = [{"repos": [{"repo": "a/b", "deploy_source": "ci_pipeline"}]}]
        with self.assertRaises(ValueError):
            dora_metrics.validate_deploy_sources(projects)


class TestComputeRepoMetrics(unittest.TestCase):
    """All of these mock get_prod_releases/get_prod_tags/get_merged_prs_between/
    get_pr_first_commit_ts — compute_repo_metrics must not hit the network."""

    def _releases(self, tags_and_dates):
        return [{"tag": t, "published_at": dt(d), "url": f"https://x/{t}"} for t, d in tags_and_dates]

    def test_deployment_frequency_counts_releases_in_window(self):
        releases = self._releases([
            ("v1.0.0", "2026-06-01T00:00:00Z"),  # outside the window
            ("v1.1.0", "2026-07-01T00:00:00Z"),
            ("v1.2.0", "2026-07-02T00:00:00Z"),
        ])
        with patch.object(dora_metrics, "get_prod_releases", return_value=releases), \
             patch.object(dora_metrics, "get_merged_prs_between", return_value=[]):
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="a/b", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"),
            )
        self.assertEqual(r["deployment_frequency"], 2)
        self.assertEqual([d["tag"] for d in r["deploys_in_window"]], ["v1.1.0", "v1.2.0"])

    def test_zero_releases_gives_df_zero_and_lead_time_none(self):
        with patch.object(dora_metrics, "get_prod_releases", return_value=[]):
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="a/b", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"),
            )
        self.assertEqual(r["deployment_frequency"], 0)  # real 0, not None (see the comment in the script)
        self.assertIsNone(r["lead_time_median_hours"])  # no computable data, not 0.0
        self.assertEqual(r["lead_time_n"], 0)

    def test_first_release_excluded_from_lead_time_with_warning(self):
        releases = self._releases([("v1.0.0", "2026-07-01T00:00:00Z")])
        with patch.object(dora_metrics, "get_prod_releases", return_value=releases):
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="a/b", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"),
            )
        self.assertEqual(r["deployment_frequency"], 1)
        self.assertIsNone(r["lead_time_median_hours"])
        self.assertTrue(any("no known prior release" in w for w in r["warnings"]))

    def test_zero_prs_between_releases_warns(self):
        releases = self._releases([
            ("v1.0.0", "2026-06-20T00:00:00Z"),
            ("v1.1.0", "2026-07-01T00:00:00Z"),
        ])
        with patch.object(dora_metrics, "get_prod_releases", return_value=releases), \
             patch.object(dora_metrics, "get_merged_prs_between", return_value=[]):
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="a/b", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"),
            )
        self.assertIsNone(r["lead_time_median_hours"])
        self.assertTrue(any("0 merged PRs" in w for w in r["warnings"]))

    def test_lead_time_computed_from_first_commit_to_release(self):
        releases = self._releases([
            ("v1.0.0", "2026-06-20T00:00:00Z"),
            ("v1.1.0", "2026-07-01T00:00:00Z"),
        ])
        with patch.object(dora_metrics, "get_prod_releases", return_value=releases), \
             patch.object(dora_metrics, "get_merged_prs_between",
                          return_value=[{"number": 42, "title": "Fix X"}]), \
             patch.object(dora_metrics, "get_pr_first_commit_ts",
                          return_value=dt("2026-06-30T12:00:00Z")):
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="a/b", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"),
            )
        self.assertEqual(r["lead_time_n"], 1)
        self.assertEqual(r["lead_time_median_hours"], 12.0)
        self.assertEqual(r["lead_time_detail"][0]["pr"], 42)

    def test_lead_time_median_with_multiple_prs(self):
        releases = self._releases([
            ("v1.0.0", "2026-06-20T00:00:00Z"),
            ("v1.1.0", "2026-07-01T00:00:00Z"),
        ])
        commit_dates = {
            1: dt("2026-06-30T00:00:00Z"),   # 24h before the release
            2: dt("2026-06-29T00:00:00Z"),   # 48h before
            3: dt("2026-06-30T12:00:00Z"),   # 12h before
        }
        with patch.object(dora_metrics, "get_prod_releases", return_value=releases), \
             patch.object(dora_metrics, "get_merged_prs_between",
                          return_value=[{"number": n, "title": "x"} for n in commit_dates]), \
             patch.object(dora_metrics, "get_pr_first_commit_ts",
                          side_effect=lambda session, repo, pr_number: commit_dates[pr_number]):
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="a/b", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"),
            )
        self.assertEqual(r["lead_time_n"], 3)
        self.assertEqual(r["lead_time_median_hours"], 24.0)  # median of [12, 24, 48]

    def test_pr_without_recoverable_commit_is_excluded_with_warning(self):
        releases = self._releases([
            ("v1.0.0", "2026-06-20T00:00:00Z"),
            ("v1.1.0", "2026-07-01T00:00:00Z"),
        ])
        with patch.object(dora_metrics, "get_prod_releases", return_value=releases), \
             patch.object(dora_metrics, "get_merged_prs_between",
                          return_value=[{"number": 7, "title": "x"}]), \
             patch.object(dora_metrics, "get_pr_first_commit_ts", return_value=None):
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="a/b", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"),
            )
        self.assertEqual(r["lead_time_n"], 0)
        self.assertIsNone(r["lead_time_median_hours"])
        self.assertTrue(any("could not fetch the first commit" in w for w in r["warnings"]))

    def test_deploy_source_tag_dispatches_to_get_prod_tags(self):
        tags = self._releases([("v1.0.0", "2026-07-01T00:00:00Z")])
        with patch.object(dora_metrics, "get_prod_tags", return_value=tags) as mock_tags, \
             patch.object(dora_metrics, "get_prod_releases") as mock_releases:
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="a/b", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"),
                deploy_source="tag",
            )
        mock_tags.assert_called_once()
        mock_releases.assert_not_called()
        self.assertEqual(r["deploy_source"], "tag")
        self.assertTrue(any(w.startswith("Tag ") for w in r["warnings"]))

    def test_warnings_are_derived_from_issues_with_identical_text(self):
        releases = self._releases([("v1.0.0", "2026-07-01T00:00:00Z")])
        with patch.object(dora_metrics, "get_prod_releases", return_value=releases):
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="a/b", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"),
            )
        self.assertEqual([i["code"] for i in r["issues"]], ["first_marker_no_prior"])
        self.assertEqual(r["warnings"], [i["message"] for i in r["issues"]])

    def test_marker_totals_are_reported_for_later_diagnosis(self):
        releases = self._releases([
            ("v1.0.0", "2026-05-01T00:00:00Z"),   # outside the window
            ("v1.1.0", "2026-07-01T00:00:00Z"),
        ])
        with patch.object(dora_metrics, "get_prod_releases", return_value=releases), \
             patch.object(dora_metrics, "get_merged_prs_between", return_value=[]):
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="a/b", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"),
            )
        self.assertEqual(r["markers_total"], 2)
        self.assertEqual(r["latest_marker_at"], "2026-07-01T00:00:00Z")

    def test_no_markers_at_all_reports_zero_totals(self):
        with patch.object(dora_metrics, "get_prod_releases", return_value=[]):
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="a/b", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"),
            )
        self.assertEqual(r["markers_total"], 0)
        self.assertIsNone(r["latest_marker_at"])


class TestFormatHumanSummary(unittest.TestCase):
    GUIDANCE = {"what": "The branch is missing.",
                "how_to_check": "Compare with the repo's branch list.",
                "where_to_fix": "Correct prod_branch in config/projects.json."}

    def _repo(self, **kw):
        base = {"repo": "example-org/example-frontend", "type": ["web", "mobile"],
                "deploy_source": "release", "measured": True, "deployment_frequency": 2,
                "lead_time_median_hours": 4.3, "lead_time_n": 3, "issues": [], "warnings": []}
        base.update(kw)
        return base

    def _result(self, repos, root_issues=None):
        return {"issues": root_issues or [], "projects": [{"name": "Example Project", "repos": repos}]}

    def test_includes_metrics(self):
        text = dora_metrics.format_human_summary(self._result([self._repo()]), window_days=14)
        self.assertIn("# DORA Metrics — Example Project", text)
        self.assertIn("## `example-org/example-frontend` (web, mobile) — deploy_source: release", text)
        self.assertIn("**Deployment Frequency** (window 14d): 2", text)
        self.assertIn("**Median Lead Time**: 4.3h (n=3)", text)
        self.assertNotIn("**Problems found", text)

    def test_no_lead_time_data(self):
        text = dora_metrics.format_human_summary(
            self._result([self._repo(deployment_frequency=0, lead_time_median_hours=None, lead_time_n=0)]),
            window_days=14)
        self.assertIn("no data in the window", text)

    def test_problem_renders_message_verbatim_then_the_steps(self):
        issue = dora_metrics.make_issue("branch_not_found", "partial", "a/b: branch 'master' does not exist")
        issue["guidance"] = self.GUIDANCE
        text = dora_metrics.format_human_summary(
            self._result([self._repo(issues=[issue], warnings=[issue["message"]])]), window_days=14)
        self.assertIn("**Problems found and how to fix them:**", text)
        self.assertIn("a/b: branch 'master' does not exist", text)
        self.assertIn("**What:** The branch is missing.", text)
        self.assertIn("**How to check:** Compare with the repo's branch list.", text)
        self.assertIn("**Where to fix:** Correct prod_branch in config/projects.json.", text)

    def test_bullet_list_guidance_keeps_one_bullet_per_line(self):
        issue = dora_metrics.make_issue("no_credential", "blocked", "No GitHub credential found.")
        issue["guidance"] = {
            "what": "The script found no credential.",
            "how_to_check": "",
            "where_to_fix": "- Option 1: export GITHUB_TOKEN=ghp_xxxx with a token that has\n  repo read scope.\n- Option 2: run `gh auth login` once.",
        }
        text = dora_metrics.format_human_summary(
            {"issues": [issue], "projects": []}, window_days=14)
        self.assertIn("  - **Where to fix:**\n", text)
        self.assertIn("    - Option 1: export GITHUB_TOKEN=ghp_xxxx with a token that has", text)
        self.assertIn("    - Option 2: run `gh auth login` once.", text)
        # Prose fields still collapse onto the label's line.
        self.assertIn("  - **What:** The script found no credential.", text)

    def test_issue_without_guidance_says_so_instead_of_inventing(self):
        issue = dora_metrics.make_issue("api_error", "blocked", "a/b: GitHub API error 500")
        text = dora_metrics.format_human_summary(
            self._result([self._repo(measured=False, issues=[issue])]), window_days=14)
        self.assertIn("a/b: GitHub API error 500", text)
        self.assertIn("no guidance for 'api_error'", text)
        self.assertNotIn("**What:**", text)

    def test_impact_none_renders_under_notes_not_problems(self):
        issue = dora_metrics.make_issue("no_markers_in_window", "none", "a/b: 0 deploys in the window.")
        issue["guidance"] = {"what": "Nothing wrong.", "how_to_check": "", "where_to_fix": "Nothing to fix."}
        text = dora_metrics.format_human_summary(
            self._result([self._repo(deployment_frequency=0, issues=[issue])]), window_days=14)
        self.assertIn("**Notes:**", text)
        self.assertNotIn("**Problems found and how to fix them:**", text)
        self.assertNotIn("**How to check:**", text)  # empty subsection is skipped, not rendered blank

    def test_unmeasured_repo_shows_the_problem_and_no_metric_lines(self):
        issue = dora_metrics.make_issue("repo_unreachable", "blocked", "a/b: the GitHub API returned 404")
        issue["guidance"] = self.GUIDANCE
        text = dora_metrics.format_human_summary(
            self._result([{"repo": "a/b", "type": [], "deploy_source": "release",
                           "measured": False, "issues": [issue], "warnings": [issue["message"]]}]),
            window_days=14)
        self.assertIn("## `a/b` — not measured", text)
        self.assertNotIn("**Deployment Frequency**", text)
        self.assertIn("a/b: the GitHub API returned 404", text)

    def test_root_issue_renders_at_the_top(self):
        issue = dora_metrics.make_issue("no_credential", "blocked", "No GitHub credential found.")
        issue["guidance"] = self.GUIDANCE
        text = dora_metrics.format_human_summary({"issues": [issue], "projects": []}, window_days=14)
        self.assertTrue(text.startswith("# DORA Metrics"))
        self.assertIn("No GitHub credential found.", text)
        self.assertIn("**Problems found and how to fix them:**", text)


class TestIssueModel(unittest.TestCase):
    def test_make_issue_shape(self):
        i = dora_metrics.make_issue("branch_not_found", "partial", "msg", evidence={"prod_branch": "main"})
        self.assertEqual(i["code"], "branch_not_found")
        self.assertEqual(i["impact"], "partial")
        self.assertEqual(i["message"], "msg")
        self.assertEqual(i["evidence"], {"prod_branch": "main"})
        self.assertIsNone(i["guidance"])  # hydrated later, never at construction

    def test_make_issue_rejects_unknown_code(self):
        with self.assertRaises(ValueError):
            dora_metrics.make_issue("not_a_real_code", "partial", "msg")

    def test_make_issue_rejects_unknown_impact(self):
        with self.assertRaises(ValueError):
            dora_metrics.make_issue("branch_not_found", "critical", "msg")

    def test_hydrate_fills_root_and_repo_issues(self):
        result = {
            "issues": [dora_metrics.make_issue("no_credential", "blocked", "m")],
            "projects": [{"name": "P", "repos": [
                {"repo": "a/b", "issues": [dora_metrics.make_issue("branch_not_found", "partial", "m")]},
            ]}],
        }
        guidance = {"no_credential": {"what": "w1", "how_to_check": "h1", "where_to_fix": "f1"},
                    "branch_not_found": {"what": "w2", "how_to_check": "h2", "where_to_fix": "f2"}}
        dora_metrics.hydrate_issues(result, guidance)
        self.assertEqual(result["issues"][0]["guidance"]["what"], "w1")
        self.assertEqual(result["projects"][0]["repos"][0]["issues"][0]["guidance"]["what"], "w2")

    def test_hydrate_leaves_guidance_none_when_code_absent(self):
        result = {"issues": [dora_metrics.make_issue("api_error", "blocked", "m")], "projects": []}
        dora_metrics.hydrate_issues(result, {})
        self.assertIsNone(result["issues"][0]["guidance"])

    def test_has_blocked(self):
        blocked = {"issues": [], "projects": [{"name": "P", "repos": [
            {"repo": "a/b", "issues": [dora_metrics.make_issue("repo_unreachable", "blocked", "m")]}]}]}
        partial = {"issues": [], "projects": [{"name": "P", "repos": [
            {"repo": "a/b", "issues": [dora_metrics.make_issue("branch_not_found", "partial", "m")]}]}]}
        self.assertTrue(dora_metrics.has_blocked(blocked))
        self.assertFalse(dora_metrics.has_blocked(partial))


class TestGuidanceDrift(unittest.TestCase):
    """Every code the script emits must have an entry in troubleshooting.md and
    vice versa. Without this the single source of truth drifts silently and
    reports start showing problems with no steps."""

    def test_codes_and_entries_match(self):
        import importlib.util as _ilu
        path = os.path.join(os.path.dirname(__file__), "..", "scripts", "troubleshooting.py")
        spec = _ilu.spec_from_file_location("troubleshooting", path)
        troubleshooting = _ilu.module_from_spec(spec)
        spec.loader.exec_module(troubleshooting)

        documented = set(troubleshooting.load_guidance(troubleshooting.default_path()))
        expected = set(dora_metrics.ISSUE_CODES) - set(dora_metrics.NO_GUIDANCE_CODES)
        self.assertEqual(documented, expected)


class TestPracticeGuidanceDrift(unittest.TestCase):
    """Every code in PRACTICE_GUIDANCE_CODES must have an entry in
    practice-guidance.md, and vice versa. Without this the single source of
    truth drifts silently and reports include guidance with no prose."""

    def test_codes_and_entries_match(self):
        import importlib.util as _ilu
        path = os.path.join(os.path.dirname(__file__), "..", "scripts", "practice_guidance.py")
        spec = _ilu.spec_from_file_location("practice_guidance", path)
        practice_guidance = _ilu.module_from_spec(spec)
        spec.loader.exec_module(practice_guidance)

        documented = set(practice_guidance.load_guidance(practice_guidance.default_path()))
        expected = set(dora_metrics.PRACTICE_GUIDANCE_CODES)
        self.assertEqual(documented, expected)


class TestPracticeGuidanceInvariance(unittest.TestCase):
    """The practice guidance catalog is fixed and independent of any repo's
    measured numbers. Two runs with different measurements must produce
    identical guidance, per D1-a: the guidance is about engineering practices,
    never about interpreting a specific team's numbers. This test is the
    regression gate for that contract."""

    def test_guidance_is_identical_regardless_of_measurements(self):
        """Build two result dicts with vastly different numbers and assert
        the guidance attached is identical. This directly tests D1-a: guidance
        must never vary with the numbers."""
        import importlib.util as _ilu
        path = os.path.join(os.path.dirname(__file__), "..", "scripts", "practice_guidance.py")
        spec = _ilu.spec_from_file_location("practice_guidance", path)
        practice_guidance = _ilu.module_from_spec(spec)
        spec.loader.exec_module(practice_guidance)

        catalog = practice_guidance.load_guidance(practice_guidance.default_path())

        # Two very different result dicts
        result1 = {"deployment_frequency": 1, "lead_time_median_hours": 100}
        result2 = {"deployment_frequency": 10, "lead_time_median_hours": 2}

        # Attach guidance to both
        dora_metrics.attach_practice_guidance(result1, catalog)
        dora_metrics.attach_practice_guidance(result2, catalog)

        # Guidance must be identical regardless of numbers
        self.assertEqual(result1["practice_guidance"], result2["practice_guidance"])

    def test_guidance_is_identical_on_empty_result(self):
        """Guidance is present and identical even when no measurements exist."""
        import importlib.util as _ilu
        path = os.path.join(os.path.dirname(__file__), "..", "scripts", "practice_guidance.py")
        spec = _ilu.spec_from_file_location("practice_guidance", path)
        practice_guidance = _ilu.module_from_spec(spec)
        spec.loader.exec_module(practice_guidance)

        catalog = practice_guidance.load_guidance(practice_guidance.default_path())

        result_with_numbers = {"deployment_frequency": 5}
        result_with_nothing = {}

        dora_metrics.attach_practice_guidance(result_with_numbers, catalog)
        dora_metrics.attach_practice_guidance(result_with_nothing, catalog)

        # Both must have identical guidance
        self.assertEqual(
            result_with_numbers["practice_guidance"],
            result_with_nothing["practice_guidance"]
        )


class TestPracticeGuidancePresentOnEveryRun(unittest.TestCase):
    """Practice guidance must be present and non-empty on every report,
    including runs with no repos measured or no credentials."""

    def test_no_credential_result_has_guidance(self):
        """When no credentials are available, the fallback result still
        carries the full, unfiltered guidance catalog."""
        import importlib.util as _ilu
        path = os.path.join(os.path.dirname(__file__), "..", "scripts", "practice_guidance.py")
        spec = _ilu.spec_from_file_location("practice_guidance", path)
        practice_guidance = _ilu.module_from_spec(spec)
        spec.loader.exec_module(practice_guidance)

        catalog = practice_guidance.load_guidance(practice_guidance.default_path())
        result = dora_metrics.no_credential_result(
            now=dt("2026-09-14T10:00:00Z"), window_days=14, tag_pattern=r"^v"
        )

        dora_metrics.attach_practice_guidance(result, catalog)

        self.assertIn("practice_guidance", result)
        self.assertIsNotNone(result["practice_guidance"])
        self.assertTrue(len(result["practice_guidance"]) > 0)

    def test_normal_run_has_guidance(self):
        """A normal measurement run includes the full guidance catalog."""
        import importlib.util as _ilu
        path = os.path.join(os.path.dirname(__file__), "..", "scripts", "practice_guidance.py")
        spec = _ilu.spec_from_file_location("practice_guidance", path)
        practice_guidance = _ilu.module_from_spec(spec)
        spec.loader.exec_module(practice_guidance)

        catalog = practice_guidance.load_guidance(practice_guidance.default_path())
        result = {"issues": [], "projects": []}

        dora_metrics.attach_practice_guidance(result, catalog)

        self.assertIn("practice_guidance", result)
        self.assertIsNotNone(result["practice_guidance"])
        self.assertTrue(len(result["practice_guidance"]) > 0)

    def test_guidance_count_matches_codes(self):
        """The attached guidance has exactly as many entries as codes defined,
        less any that are missing from the file."""
        import importlib.util as _ilu
        path = os.path.join(os.path.dirname(__file__), "..", "scripts", "practice_guidance.py")
        spec = _ilu.spec_from_file_location("practice_guidance", path)
        practice_guidance = _ilu.module_from_spec(spec)
        spec.loader.exec_module(practice_guidance)

        catalog = practice_guidance.load_guidance(practice_guidance.default_path())
        result = {}

        dora_metrics.attach_practice_guidance(result, catalog)

        # If the catalog loaded successfully, entry count should equal code count
        self.assertEqual(
            len(result["practice_guidance"]),
            len(dora_metrics.PRACTICE_GUIDANCE_CODES)
        )


class TestPracticeEntryRendersTitle(unittest.TestCase):
    """`_render_practice_entry` must show the catalog's human-readable title,
    not the raw anchor code, and must fall back to the code only when an
    entry genuinely has no title."""

    def test_attached_entries_carry_the_title_field(self):
        """build_practice_guidance includes `title` on every entry, sourced
        from the parsed catalog."""
        import importlib.util as _ilu
        path = os.path.join(os.path.dirname(__file__), "..", "scripts", "practice_guidance.py")
        spec = _ilu.spec_from_file_location("practice_guidance", path)
        practice_guidance = _ilu.module_from_spec(spec)
        spec.loader.exec_module(practice_guidance)

        catalog = practice_guidance.load_guidance(practice_guidance.default_path())
        entries = dora_metrics.build_practice_guidance(catalog)

        trunk = next(e for e in entries if e["code"] == "trunk_based_development")
        self.assertEqual(trunk["title"], "Trunk-based development")

    def test_renders_the_title_not_the_code(self):
        lines = []
        dora_metrics._render_practice_entry(
            {"code": "trunk_based_development", "title": "Trunk-based development",
             "what": "", "why": "", "how_to_adopt": ""},
            lines,
        )
        self.assertIn("- **Trunk-based development**", lines)
        self.assertNotIn("- **trunk_based_development**", lines)

    def test_falls_back_to_the_code_when_title_is_empty(self):
        """An entry with no title (title == "") degrades to showing the code,
        instead of rendering a blank bold heading or crashing."""
        lines = []
        dora_metrics._render_practice_entry(
            {"code": "no_title_example", "title": "", "what": "", "why": "", "how_to_adopt": ""},
            lines,
        )
        self.assertIn("- **no_title_example**", lines)


class FakeResponse:
    def __init__(self, status_code, text=""):
        self.status_code = status_code
        self.text = text


class FakeSession:
    """Returns a canned response per URL suffix. Anything not listed 200s."""

    def __init__(self, routes):
        self.routes = routes
        self.calls = []

    def get(self, url, params=None):
        self.calls.append(url)
        for suffix, resp in self.routes.items():
            if url.endswith(suffix):
                return resp
        return FakeResponse(200)


class TestPreflightRepo(unittest.TestCase):
    def test_all_good_returns_no_issues(self):
        session = FakeSession({})
        self.assertEqual(dora_metrics.preflight_repo(session, "a/b", "main"), [])

    def test_repo_404_is_blocked(self):
        session = FakeSession({"/repos/a/b": FakeResponse(404, "Not Found")})
        issues = dora_metrics.preflight_repo(session, "a/b", "main")
        self.assertEqual([i["code"] for i in issues], ["repo_unreachable"])
        self.assertEqual(issues[0]["impact"], "blocked")

    def test_repo_401_is_token_unauthorized(self):
        session = FakeSession({"/repos/a/b": FakeResponse(401, "Bad credentials")})
        issues = dora_metrics.preflight_repo(session, "a/b", "main")
        self.assertEqual([i["code"] for i in issues], ["token_unauthorized"])

    def test_rate_limit_is_its_own_code(self):
        session = FakeSession({"/repos/a/b": FakeResponse(403, "API rate limit exceeded for user")})
        issues = dora_metrics.preflight_repo(session, "a/b", "main")
        self.assertEqual([i["code"] for i in issues], ["rate_limited"])

    def test_repo_403_without_rate_limit_is_unreachable(self):
        session = FakeSession({"/repos/a/b": FakeResponse(403, "Resource not accessible")})
        issues = dora_metrics.preflight_repo(session, "a/b", "main")
        self.assertEqual([i["code"] for i in issues], ["repo_unreachable"])

    def test_branch_404_is_partial_and_names_the_branch(self):
        session = FakeSession({"/branches/master": FakeResponse(404, "Branch not found")})
        issues = dora_metrics.preflight_repo(session, "a/b", "master")
        self.assertEqual([i["code"] for i in issues], ["branch_not_found"])
        self.assertEqual(issues[0]["impact"], "partial")
        self.assertEqual(issues[0]["evidence"]["prod_branch"], "master")
        self.assertIn("master", issues[0]["message"])

    def test_branch_rate_limit_is_reported_not_treated_as_success(self):
        session = FakeSession({"/branches/main": FakeResponse(403, "API rate limit exceeded for user")})
        issues = dora_metrics.preflight_repo(session, "a/b", "main")
        self.assertEqual([i["code"] for i in issues], ["rate_limited"])
        self.assertEqual(issues[0]["impact"], "partial")

    def test_branch_unexpected_status_is_reported_not_treated_as_success(self):
        session = FakeSession({"/branches/main": FakeResponse(500, "boom")})
        issues = dora_metrics.preflight_repo(session, "a/b", "main")
        self.assertEqual([i["code"] for i in issues], ["api_error"])
        self.assertEqual(issues[0]["impact"], "partial")
        self.assertEqual(issues[0]["evidence"]["prod_branch"], "main")

    def test_branch_is_not_checked_when_the_repo_is_unreachable(self):
        session = FakeSession({"/repos/a/b": FakeResponse(404, "Not Found")})
        dora_metrics.preflight_repo(session, "a/b", "main")
        self.assertTrue(all("/branches/" not in url for url in session.calls))

    def test_unexpected_status_is_api_error(self):
        session = FakeSession({"/repos/a/b": FakeResponse(500, "boom")})
        issues = dora_metrics.preflight_repo(session, "a/b", "main")
        self.assertEqual([i["code"] for i in issues], ["api_error"])


class TestDiagnoseMarkers(unittest.TestCase):
    """diagnose_markers only touches the network when something needs
    explaining, so the happy path is asserted to make zero calls."""

    def _diagnose(self, **kw):
        params = dict(session=None, repo="a/b", tag_pattern=r"^v\d+\.\d+\.\d+$",
                      deploy_source="release", markers_total=0,
                      deployment_frequency=0, latest_marker_at=None)
        params.update(kw)
        return dora_metrics.diagnose_markers(**params)

    def test_healthy_repo_produces_no_issues_and_no_calls(self):
        with patch.object(dora_metrics, "get_release_tag_names") as names, \
             patch.object(dora_metrics, "get_all_tag_names") as tags:
            issues = self._diagnose(markers_total=3, deployment_frequency=2,
                                    latest_marker_at="2026-07-01T00:00:00Z")
        self.assertEqual(issues, [])
        names.assert_not_called()
        tags.assert_not_called()

    def test_no_markers_at_all(self):
        with patch.object(dora_metrics, "get_release_tag_names", return_value={"published": [], "draft": []}), \
             patch.object(dora_metrics, "get_all_tag_names", return_value=[]):
            issues = self._diagnose()
        self.assertEqual([i["code"] for i in issues], ["no_markers_at_all"])
        self.assertEqual(issues[0]["impact"], "partial")

    def test_markers_exist_but_none_match_the_pattern(self):
        found = ["release-2026-07-01", "release-2026-07-14"]
        with patch.object(dora_metrics, "get_release_tag_names", return_value={"published": found, "draft": []}), \
             patch.object(dora_metrics, "get_all_tag_names", return_value=found):
            issues = self._diagnose()
        self.assertEqual([i["code"] for i in issues], ["no_markers_matching_pattern"])
        self.assertEqual(issues[0]["evidence"]["names_found"], found)
        self.assertEqual(issues[0]["evidence"]["tag_pattern"], r"^v\d+\.\d+\.\d+$")

    def test_evidence_is_capped_at_five_names(self):
        found = [f"release-{n}" for n in range(12)]
        with patch.object(dora_metrics, "get_release_tag_names", return_value={"published": found, "draft": []}), \
             patch.object(dora_metrics, "get_all_tag_names", return_value=[]):
            issues = self._diagnose()
        self.assertEqual(len(issues[0]["evidence"]["names_found"]), 5)
        self.assertEqual(issues[0]["evidence"]["names_total"], 12)

    def test_deploy_source_mismatch_release_configured_but_tags_used(self):
        with patch.object(dora_metrics, "get_release_tag_names", return_value={"published": [], "draft": []}), \
             patch.object(dora_metrics, "get_all_tag_names", return_value=["v1.4.0", "v1.5.0"]):
            issues = self._diagnose()
        codes = [i["code"] for i in issues]
        self.assertIn("deploy_source_mismatch", codes)
        self.assertEqual(issues[codes.index("deploy_source_mismatch")]["evidence"]["matching_other_source"],
                         ["v1.4.0", "v1.5.0"])

    def test_deploy_source_mismatch_tag_configured_but_releases_used(self):
        with patch.object(dora_metrics, "get_all_tag_names", return_value=[]), \
             patch.object(dora_metrics, "get_release_tag_names", return_value={"published": ["v1.4.0"], "draft": []}):
            issues = self._diagnose(deploy_source="tag")
        self.assertIn("deploy_source_mismatch", [i["code"] for i in issues])

    def test_matching_releases_all_draft(self):
        with patch.object(dora_metrics, "get_release_tag_names",
                          return_value={"published": [], "draft": ["v1.4.0"]}), \
             patch.object(dora_metrics, "get_all_tag_names", return_value=[]):
            issues = self._diagnose()
        codes = [i["code"] for i in issues]
        self.assertIn("matching_releases_all_draft", codes)

    def test_drafts_are_not_checked_for_deploy_source_tag(self):
        with patch.object(dora_metrics, "get_all_tag_names", return_value=[]), \
             patch.object(dora_metrics, "get_release_tag_names", return_value={"published": [], "draft": ["v1.4.0"]}):
            issues = self._diagnose(deploy_source="tag")
        self.assertNotIn("matching_releases_all_draft", [i["code"] for i in issues])

    def test_markers_exist_but_none_in_window_is_impact_none(self):
        issues = self._diagnose(markers_total=4, deployment_frequency=0,
                                latest_marker_at="2026-05-02T00:00:00Z")
        self.assertEqual([i["code"] for i in issues], ["no_markers_in_window"])
        self.assertEqual(issues[0]["impact"], "none")
        self.assertIn("2026-05-02T00:00:00Z", issues[0]["message"])
        self.assertIn("4", issues[0]["message"])


class TestBuildResult(unittest.TestCase):
    PROJECTS = [{"name": "P", "repos": [{"repo": "a/b", "type": ["web"], "prod_branch": "main"}]}]

    def test_blocked_repo_is_not_measured(self):
        blocked = [dora_metrics.make_issue("repo_unreachable", "blocked", "unreachable")]
        with patch.object(dora_metrics, "preflight_repo", return_value=blocked), \
             patch.object(dora_metrics, "compute_repo_metrics") as compute:
            result = dora_metrics.build_result(
                session=None, projects=self.PROJECTS, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"))
        compute.assert_not_called()
        repo = result["projects"][0]["repos"][0]
        self.assertFalse(repo["measured"])
        self.assertEqual([i["code"] for i in repo["issues"]], ["repo_unreachable"])

    def test_preflight_and_marker_issues_are_merged_in_order(self):
        preflight = [dora_metrics.make_issue("branch_not_found", "partial", "branch")]
        metrics = {"repo": "a/b", "deployment_frequency": 0, "lead_time_median_hours": None,
                   "lead_time_n": 0, "markers_total": 0, "latest_marker_at": None,
                   "issues": [], "warnings": []}
        markers = [dora_metrics.make_issue("no_markers_at_all", "partial", "no markers")]
        with patch.object(dora_metrics, "preflight_repo", return_value=preflight), \
             patch.object(dora_metrics, "compute_repo_metrics", return_value=dict(metrics)), \
             patch.object(dora_metrics, "diagnose_markers", return_value=markers):
            result = dora_metrics.build_result(
                session=None, projects=self.PROJECTS, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"))
        repo = result["projects"][0]["repos"][0]
        self.assertEqual([i["code"] for i in repo["issues"]], ["branch_not_found", "no_markers_at_all"])
        self.assertEqual(repo["warnings"], [i["message"] for i in repo["issues"]])
        self.assertTrue(repo["measured"])

    def test_api_exception_mid_measurement_becomes_a_coded_issue(self):
        with patch.object(dora_metrics, "preflight_repo", return_value=[]), \
             patch.object(dora_metrics, "compute_repo_metrics",
                          side_effect=dora_metrics.GitHubError("401 Unauthorized. Check that GITHUB_TOKEN...")):
            result = dora_metrics.build_result(
                session=None, projects=self.PROJECTS, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"))
        repo = result["projects"][0]["repos"][0]
        self.assertFalse(repo["measured"])
        self.assertEqual([i["code"] for i in repo["issues"]], ["token_unauthorized"])

    def test_unrecognized_api_exception_falls_back_to_api_error(self):
        with patch.object(dora_metrics, "preflight_repo", return_value=[]), \
             patch.object(dora_metrics, "compute_repo_metrics",
                          side_effect=dora_metrics.GitHubError("GitHub API error 500 at ...")):
            result = dora_metrics.build_result(
                session=None, projects=self.PROJECTS, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"))
        self.assertEqual([i["code"] for i in result["projects"][0]["repos"][0]["issues"]], ["api_error"])

    def test_repo_name_containing_401_is_not_mistaken_for_an_auth_failure(self):
        projects = [{"name": "P", "repos": [{"repo": "org/app-401", "prod_branch": "main"}]}]
        boom = dora_metrics.GitHubError(
            "GitHub API error 500 at https://api.github.com/repos/org/app-401/releases: boom")
        with patch.object(dora_metrics, "preflight_repo", return_value=[]), \
             patch.object(dora_metrics, "compute_repo_metrics", side_effect=boom):
            result = dora_metrics.build_result(
                session=None, projects=projects, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"))
        self.assertEqual([i["code"] for i in result["projects"][0]["repos"][0]["issues"]], ["api_error"])

    def test_repo_name_containing_404_is_not_mistaken_for_an_unreachable_repo(self):
        projects = [{"name": "P", "repos": [{"repo": "org/404-redirects", "prod_branch": "main"}]}]
        boom = dora_metrics.GitHubError(
            "GitHub API error 500 at https://api.github.com/repos/org/404-redirects/tags: boom")
        with patch.object(dora_metrics, "preflight_repo", return_value=[]), \
             patch.object(dora_metrics, "compute_repo_metrics", side_effect=boom):
            result = dora_metrics.build_result(
                session=None, projects=projects, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"))
        self.assertEqual([i["code"] for i in result["projects"][0]["repos"][0]["issues"]], ["api_error"])

    def test_rate_limit_message_still_classified(self):
        projects = [{"name": "P", "repos": [{"repo": "a/b", "prod_branch": "main"}]}]
        boom = dora_metrics.GitHubError("Rate limit reached: API rate limit exceeded for user")
        with patch.object(dora_metrics, "preflight_repo", return_value=[]), \
             patch.object(dora_metrics, "compute_repo_metrics", side_effect=boom):
            result = dora_metrics.build_result(
                session=None, projects=projects, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"))
        self.assertEqual([i["code"] for i in result["projects"][0]["repos"][0]["issues"]], ["rate_limited"])

    def test_one_blocked_repo_does_not_stop_the_next(self):
        projects = [{"name": "P", "repos": [{"repo": "a/b", "prod_branch": "main"},
                                             {"repo": "a/c", "prod_branch": "main"}]}]
        metrics = {"repo": "a/c", "deployment_frequency": 1, "lead_time_median_hours": None,
                   "lead_time_n": 0, "markers_total": 1, "latest_marker_at": "2026-07-01T00:00:00Z",
                   "issues": [], "warnings": []}
        blocked = [dora_metrics.make_issue("repo_unreachable", "blocked", "unreachable")]
        with patch.object(dora_metrics, "preflight_repo", side_effect=[blocked, []]), \
             patch.object(dora_metrics, "compute_repo_metrics", return_value=dict(metrics)), \
             patch.object(dora_metrics, "diagnose_markers", return_value=[]):
            result = dora_metrics.build_result(
                session=None, projects=projects, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"))
        repos = result["projects"][0]["repos"]
        self.assertFalse(repos[0]["measured"])
        self.assertTrue(repos[1]["measured"])


class TestNoCredentialResult(unittest.TestCase):
    def test_builds_a_report_instead_of_dying(self):
        result = dora_metrics.no_credential_result(now=dt("2026-07-03T00:00:00Z"), window_days=14, tag_pattern=r"^v")
        self.assertEqual([i["code"] for i in result["issues"]], ["no_credential"])
        self.assertEqual(result["projects"], [])
        self.assertTrue(dora_metrics.has_blocked(result))


class TestSlugify(unittest.TestCase):
    def test_lowercases_and_replaces_separators(self):
        self.assertEqual(dora_metrics.slugify("Example Project"), "example-project")
        self.assertEqual(dora_metrics.slugify("Hoopis_Backend"), "hoopis-backend")
        self.assertEqual(dora_metrics.slugify("hoopis.backend"), "hoopis-backend")
        self.assertEqual(dora_metrics.slugify("example-org/api"), "example-org-api")

    def test_drops_other_characters_and_collapses_hyphens(self):
        self.assertEqual(dora_metrics.slugify("my repo (v2)!"), "my-repo-v2")
        self.assertEqual(dora_metrics.slugify("a___b"), "a-b")
        self.assertEqual(dora_metrics.slugify("--a--"), "a")

    def test_falls_back_when_nothing_survives(self):
        self.assertEqual(dora_metrics.slugify(""), "project")
        self.assertEqual(dora_metrics.slugify("!!!"), "project")


class TestRepoFileSlugs(unittest.TestCase):
    def _result(self, *repo_names):
        return {"issues": [], "projects": [
            {"name": "P", "repos": [{"repo": r} for r in repo_names]}]}

    def test_uses_the_repo_name_alone(self):
        slugs = dora_metrics.repo_file_slugs(
            self._result("example-org/example-frontend"))
        self.assertEqual(slugs["example-org/example-frontend"], "example-frontend")

    def test_qualifies_with_the_org_only_on_collision(self):
        slugs = dora_metrics.repo_file_slugs(
            self._result("example-org/api", "partner-org/api", "example-org/web"))
        self.assertEqual(slugs["example-org/api"], "example-org-api")
        self.assertEqual(slugs["partner-org/api"], "partner-org-api")
        # The non-colliding repo keeps the short form.
        self.assertEqual(slugs["example-org/web"], "web")

    def test_spans_projects(self):
        result = {"issues": [], "projects": [
            {"name": "A", "repos": [{"repo": "org-a/api"}]},
            {"name": "B", "repos": [{"repo": "org-b/api"}]}]}
        slugs = dora_metrics.repo_file_slugs(result)
        self.assertEqual(slugs["org-a/api"], "org-a-api")
        self.assertEqual(slugs["org-b/api"], "org-b-api")


class TestSingleRepoResult(unittest.TestCase):
    def _result(self):
        return {
            "generated_at": "2026-07-03T00:00:00Z", "window_days": 14,
            "tag_pattern": r"^v", "issues": [{"code": "root"}],
            "projects": [{"name": "P", "notes": "n", "repos": [
                {"repo": "o/one"}, {"repo": "o/two"}]}],
        }

    def test_keeps_only_the_given_repo(self):
        full = self._result()
        narrowed = dora_metrics.single_repo_result(
            full, full["projects"][0], full["projects"][0]["repos"][1])
        self.assertEqual(narrowed["projects"][0]["repos"], [{"repo": "o/two"}])

    def test_carries_over_run_level_and_project_fields(self):
        full = self._result()
        narrowed = dora_metrics.single_repo_result(
            full, full["projects"][0], full["projects"][0]["repos"][0])
        self.assertEqual(narrowed["window_days"], 14)
        self.assertEqual(narrowed["tag_pattern"], r"^v")
        self.assertEqual(narrowed["issues"], [{"code": "root"}])
        self.assertEqual(narrowed["projects"][0]["name"], "P")
        self.assertEqual(narrowed["projects"][0]["notes"], "n")

    def test_does_not_mutate_the_original(self):
        full = self._result()
        dora_metrics.single_repo_result(
            full, full["projects"][0], full["projects"][0]["repos"][0])
        self.assertEqual(len(full["projects"][0]["repos"]), 2)


class TestWriteOutput(unittest.TestCase):
    """The saved file names are the contract this skill shares with the other
    audits: <YYYY-MM-DD>-<repo>-dora-metrics.md, one file per repo (markdown only)."""

    def _repo(self, name):
        return {"repo": name, "type": ["backend"], "deploy_source": "release",
                "measured": True, "deployment_frequency": 2,
                "lead_time_median_hours": 4.3, "lead_time_n": 3,
                "issues": [], "warnings": []}

    def _write(self, result, tmp):
        dora_metrics.write_output(result, window_days=14, out_dir=tmp,
                                  now=dt("2026-09-14T10:00:00Z"))
        return sorted(os.listdir(tmp))

    def test_one_markdown_file_per_repo(self):
        """Verify that one markdown file is written per repo, never JSON."""
        result = {"issues": [], "projects": [{"name": "Example Project", "repos": [
            self._repo("example-org/example-frontend"),
            self._repo("partner-org/example-backend")]}]}
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(self._write(result, tmp), [
                "2026-09-14-example-backend-dora-metrics.md",
                "2026-09-14-example-frontend-dora-metrics.md",
            ])

    def test_each_file_holds_only_its_own_repo(self):
        result = {"issues": [], "projects": [{"name": "Example Project", "repos": [
            self._repo("example-org/example-frontend"),
            self._repo("partner-org/example-backend")]}]}
        with tempfile.TemporaryDirectory() as tmp:
            self._write(result, tmp)
            path = os.path.join(tmp, "2026-09-14-example-frontend-dora-metrics.md")
            with open(path) as f:
                text = f.read()
            self.assertIn("example-org/example-frontend", text)
            self.assertNotIn("example-backend", text)

    def test_writes_one_markdown_file_when_nothing_was_measured(self):
        """Verify fallback markdown file when no repos are measured, never JSON."""
        result = dora_metrics.no_credential_result(
            now=dt("2026-09-14T10:00:00Z"), window_days=14, tag_pattern=r"^v")
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(self._write(result, tmp), [
                "2026-09-14-no-repositories-dora-metrics.md",
            ])

    def test_writes_nothing_without_an_out_dir(self):
        result = {"issues": [], "projects": [{"name": "P", "repos": [
            self._repo("o/one")]}]}
        with tempfile.TemporaryDirectory() as tmp:
            dora_metrics.write_output(result, window_days=14, out_dir=None,
                                      now=dt("2026-09-14T10:00:00Z"))
            self.assertEqual(os.listdir(tmp), [])

    def test_never_writes_json_files(self):
        """Verify that no .json files are ever written to --out-dir.
        This guards against accidental reintroduction of JSON output."""
        result = {"issues": [], "projects": [{"name": "Example Project", "repos": [
            self._repo("example-org/example-frontend"),
            self._repo("partner-org/example-backend")]}]}
        with tempfile.TemporaryDirectory() as tmp:
            self._write(result, tmp)
            files = os.listdir(tmp)
            json_files = [f for f in files if f.endswith(".json")]
            self.assertEqual(json_files, [],
                           f"Found unexpected JSON files in --out-dir: {json_files}")


class FakeHttpResponse:
    """Like FakeResponse, but with a JSON body and a `.links` dict — enough to
    drive gitlab_paginate/bitbucket_paginate and the GitLab/Bitbucket parsing
    functions without hitting the network."""

    def __init__(self, status_code=200, json_data=None, text="", links=None):
        self.status_code = status_code
        self._json = [] if json_data is None else json_data
        self.text = text
        self.links = links or {}

    @property
    def ok(self):
        return 200 <= self.status_code < 300

    def json(self):
        return self._json


class FakeHttpSession:
    """Routes by URL suffix, like FakeSession, but returns a FakeHttpResponse."""

    def __init__(self, routes=None, default=None):
        self.routes = routes or {}
        self.default = default if default is not None else FakeHttpResponse(200, [])
        self.calls = []

    def get(self, url, params=None):
        self.calls.append((url, params))
        for suffix, resp in self.routes.items():
            if url.endswith(suffix):
                return resp
        return self.default


class TestParseIsoTs(unittest.TestCase):
    def test_handles_z_suffix(self):
        self.assertEqual(dora_metrics.parse_iso_ts("2026-07-01T12:00:00Z"), dt("2026-07-01T12:00:00Z"))

    def test_handles_fractional_seconds_and_offset(self):
        d = dora_metrics.parse_iso_ts("2026-07-01T12:00:00.123456+00:00")
        self.assertEqual(d.tzinfo, timezone.utc)
        self.assertEqual(d.replace(microsecond=0), dt("2026-07-01T12:00:00Z"))

    def test_normalizes_non_utc_offset_to_utc(self):
        self.assertEqual(dora_metrics.parse_iso_ts("2026-07-01T09:00:00-03:00"), dt("2026-07-01T12:00:00Z"))


class TestEffectiveDeploySource(unittest.TestCase):
    def test_github_defaults_to_release(self):
        self.assertEqual(dora_metrics.effective_deploy_source({"repo": "a/b"}), "release")

    def test_gitlab_defaults_to_release(self):
        self.assertEqual(dora_metrics.effective_deploy_source({"repo": "a/b", "provider": "gitlab"}), "release")

    def test_bitbucket_defaults_to_tag(self):
        self.assertEqual(dora_metrics.effective_deploy_source({"repo": "a/b", "provider": "bitbucket"}), "tag")

    def test_explicit_value_wins(self):
        repo_cfg = {"repo": "a/b", "provider": "gitlab", "deploy_source": "tag"}
        self.assertEqual(dora_metrics.effective_deploy_source(repo_cfg), "tag")


class TestClassifyApiError(unittest.TestCase):
    def test_401_maps_to_token_unauthorized_with_provider_label(self):
        issue = dora_metrics.classify_api_error("gitlab", "g/p", "401 Unauthorized. ...")
        self.assertEqual(issue["code"], "token_unauthorized")
        self.assertIn("GitLab API", issue["message"])

    def test_rate_limit_message_mentions_provider(self):
        issue = dora_metrics.classify_api_error("bitbucket", "ws/repo", "Rate limit reached: ...")
        self.assertEqual(issue["code"], "rate_limited")
        self.assertIn("Bitbucket API", issue["message"])

    def test_404_maps_to_repo_unreachable(self):
        issue = dora_metrics.classify_api_error("github", "a/b", "404 Not Found at ...")
        self.assertEqual(issue["code"], "repo_unreachable")

    def test_unrecognized_message_is_api_error(self):
        issue = dora_metrics.classify_api_error("gitlab", "g/p", "boom")
        self.assertEqual(issue["code"], "api_error")


class TestCredentialResolution(unittest.TestCase):
    def test_gitlab_token_env_var_takes_precedence(self):
        with patch.dict(os.environ, {"GITLAB_TOKEN": "glpat-xxx"}, clear=False):
            self.assertEqual(dora_metrics.get_gitlab_token(), "glpat-xxx")

    def test_gitlab_token_absent_and_no_glab_returns_none(self):
        with patch.dict(os.environ, {}, clear=True), patch("shutil.which", return_value=None):
            self.assertIsNone(dora_metrics.get_gitlab_token())

    def test_bitbucket_bearer_token_takes_precedence(self):
        with patch.dict(os.environ, {"BITBUCKET_TOKEN": "tok", "BITBUCKET_USERNAME": "u",
                                      "BITBUCKET_APP_PASSWORD": "p"}, clear=True):
            cred = dora_metrics.get_bitbucket_credential()
        self.assertEqual(cred, {"type": "bearer", "token": "tok"})

    def test_bitbucket_falls_back_to_basic_auth(self):
        with patch.dict(os.environ, {"BITBUCKET_USERNAME": "u", "BITBUCKET_APP_PASSWORD": "p"}, clear=True):
            cred = dora_metrics.get_bitbucket_credential()
        self.assertEqual(cred, {"type": "basic", "username": "u", "app_password": "p"})

    def test_bitbucket_requires_both_username_and_password(self):
        with patch.dict(os.environ, {"BITBUCKET_USERNAME": "u"}, clear=True):
            self.assertIsNone(dora_metrics.get_bitbucket_credential())


class TestValidateProviders(unittest.TestCase):
    def test_valid_providers_ok(self):
        projects = [{"repos": [{"repo": "a/b", "provider": "github"},
                                {"repo": "a/c", "provider": "gitlab"},
                                {"repo": "a/d", "provider": "bitbucket"},
                                {"repo": "a/e"}]}]
        dora_metrics.validate_providers(projects)  # should not raise

    def test_invalid_provider_raises(self):
        projects = [{"repos": [{"repo": "a/b", "provider": "gitea"}]}]
        with self.assertRaises(ValueError):
            dora_metrics.validate_providers(projects)


class TestValidateDeploySourcesBitbucket(unittest.TestCase):
    def test_bitbucket_release_is_rejected(self):
        projects = [{"repos": [{"repo": "a/b", "provider": "bitbucket", "deploy_source": "release"}]}]
        with self.assertRaises(ValueError):
            dora_metrics.validate_deploy_sources(projects)

    def test_bitbucket_tag_or_omitted_is_ok(self):
        projects = [{"repos": [{"repo": "a/b", "provider": "bitbucket", "deploy_source": "tag"},
                                {"repo": "a/c", "provider": "bitbucket"}]}]
        dora_metrics.validate_deploy_sources(projects)  # should not raise


class TestValidateApiBase(unittest.TestCase):
    def test_bitbucket_with_api_base_raises(self):
        projects = [{"repos": [{"repo": "a/b", "provider": "bitbucket", "api_base": "https://example.com"}]}]
        with self.assertRaises(ValueError):
            dora_metrics.validate_api_base(projects)

    def test_gitlab_with_api_base_ok(self):
        projects = [{"repos": [{"repo": "a/b", "provider": "gitlab", "api_base": "https://gitlab.example.com/api/v4"}]}]
        dora_metrics.validate_api_base(projects)  # should not raise

    def test_github_without_api_base_ok(self):
        projects = [{"repos": [{"repo": "a/b", "provider": "github"}]}]
        dora_metrics.validate_api_base(projects)  # should not raise


class TestValidateScopedOverridesProvider(unittest.TestCase):
    def test_provider_without_project_raises(self):
        args = SimpleNamespace(branch=None, project=None, deploy_source=None, provider="gitlab")
        with self.assertRaises(ValueError):
            dora_metrics.validate_scoped_overrides(args)

    def test_provider_missing_attribute_is_tolerated(self):
        # Mirrors how the older tests in TestValidateScopedOverrides construct
        # args without a .provider attribute at all.
        args = SimpleNamespace(branch=None, project=None, deploy_source=None)
        dora_metrics.validate_scoped_overrides(args)  # should not raise

    def test_provider_with_project_ok(self):
        args = SimpleNamespace(branch=None, project="Example Project", deploy_source=None, provider="bitbucket")
        dora_metrics.validate_scoped_overrides(args)  # should not raise


class TestGitLabFunctions(unittest.TestCase):
    def test_project_id_is_url_encoded(self):
        self.assertEqual(dora_metrics.gitlab_project_id("group/sub/project"), "group%2Fsub%2Fproject")

    def test_get_gitlab_tags_filters_and_parses_dates(self):
        session = FakeHttpSession({
            "/repository/tags": FakeHttpResponse(200, [
                {"name": "v1.0.0", "commit": {"committed_date": "2026-07-01T12:00:00.000+00:00"}},
                {"name": "not-a-match", "commit": {"committed_date": "2026-07-02T00:00:00Z"}},
            ]),
        })
        tags = dora_metrics.get_gitlab_tags(session, "group/project", r"^v\d+\.\d+\.\d+$")
        self.assertEqual([t["tag"] for t in tags], ["v1.0.0"])
        self.assertEqual(tags[0]["published_at"], dora_metrics.parse_iso_ts("2026-07-01T12:00:00.000+00:00"))

    def test_get_gitlab_releases_excludes_upcoming(self):
        session = FakeHttpSession({
            "/releases": FakeHttpResponse(200, [
                {"tag_name": "v1.0.0", "released_at": "2026-07-01T00:00:00Z"},
                {"tag_name": "v2.0.0", "released_at": "2099-01-01T00:00:00Z"},
            ]),
        })
        releases = dora_metrics.get_gitlab_releases(session, "group/project", r"^v",
                                                    now=dt("2026-07-03T00:00:00Z"))
        self.assertEqual([r["tag"] for r in releases], ["v1.0.0"])

    def test_get_gitlab_release_tag_names_splits_upcoming_as_draft(self):
        session = FakeHttpSession({
            "/releases": FakeHttpResponse(200, [
                {"tag_name": "v1.0.0", "released_at": "2026-01-01T00:00:00Z"},
                {"tag_name": "v9.0.0", "released_at": "2099-01-01T00:00:00Z"},
            ]),
        })
        names = dora_metrics.get_gitlab_release_tag_names(session, "group/project")
        self.assertEqual(names["published"], ["v1.0.0"])
        self.assertEqual(names["draft"], ["v9.0.0"])

    def test_get_gitlab_mr_first_commit_ts_takes_the_min(self):
        session = FakeHttpSession({
            "/commits": FakeHttpResponse(200, [
                {"created_at": "2026-07-01T12:00:00.000+00:00"},
                {"created_at": "2026-06-30T08:00:00.000+00:00"},
            ]),
        })
        ts = dora_metrics.get_gitlab_mr_first_commit_ts(session, "group/project", 5)
        self.assertEqual(ts, dora_metrics.parse_iso_ts("2026-06-30T08:00:00.000+00:00"))

    def test_get_gitlab_merged_mrs_between_maps_iid_to_number(self):
        session = FakeHttpSession({"/merge_requests": FakeHttpResponse(200, [{"iid": 7, "title": "Fix Y"}])})
        mrs = dora_metrics.get_gitlab_merged_mrs_between(
            session, "group/project", "main", dt("2026-06-01T00:00:00Z"), dt("2026-07-01T00:00:00Z"))
        self.assertEqual(mrs, [{"number": 7, "title": "Fix Y"}])

    def test_gitlab_paginate_classifies_401_and_429(self):
        session = FakeHttpSession({"/x": FakeHttpResponse(401, [], text="Unauthorized")})
        with self.assertRaises(dora_metrics.GitLabError):
            list(dora_metrics.gitlab_paginate(session, "https://gitlab.com/api/v4/x"))

        session = FakeHttpSession({"/x": FakeHttpResponse(429, [], text="too many requests")})
        with self.assertRaises(dora_metrics.GitLabError):
            list(dora_metrics.gitlab_paginate(session, "https://gitlab.com/api/v4/x"))


class TestBitbucketFunctions(unittest.TestCase):
    def test_get_bitbucket_tags_uses_top_level_date_or_target_date(self):
        session = FakeHttpSession({
            "/refs/tags": FakeHttpResponse(200, {"values": [
                {"name": "v1.0.0", "date": "2026-07-01T12:00:00.000000+00:00"},
                {"name": "v1.1.0", "target": {"date": "2026-07-02T00:00:00+00:00"}},
                {"name": "skip-me", "date": "2026-07-03T00:00:00+00:00"},
            ]}),
        })
        tags = dora_metrics.get_bitbucket_tags(session, "ws/repo", r"^v\d+\.\d+\.\d+$")
        self.assertEqual([t["tag"] for t in tags], ["v1.0.0", "v1.1.0"])

    def test_get_bitbucket_pr_first_commit_ts(self):
        session = FakeHttpSession({
            "/commits": FakeHttpResponse(200, {"values": [
                {"date": "2026-06-30T08:00:00+00:00"},
                {"date": "2026-06-30T10:00:00+00:00"},
            ]}),
        })
        ts = dora_metrics.get_bitbucket_pr_first_commit_ts(session, "ws/repo", 3)
        self.assertEqual(ts, dora_metrics.parse_iso_ts("2026-06-30T08:00:00+00:00"))

    def test_bitbucket_pr_merged_at_prefers_merge_commit_date(self):
        session = FakeHttpSession({"/commit/abc123": FakeHttpResponse(200, {"date": "2026-07-01T09:00:00+00:00"})})
        pr_item = {"merge_commit": {"hash": "abc123"}, "updated_on": "2026-07-01T10:00:00+00:00"}
        merged_at = dora_metrics._bitbucket_pr_merged_at(session, "ws/repo", pr_item, dora_metrics.BITBUCKET_API_ROOT)
        self.assertEqual(merged_at, dora_metrics.parse_iso_ts("2026-07-01T09:00:00+00:00"))

    def test_bitbucket_pr_merged_at_falls_back_to_updated_on(self):
        session = FakeHttpSession({})
        pr_item = {"updated_on": "2026-07-01T10:00:00+00:00"}
        merged_at = dora_metrics._bitbucket_pr_merged_at(session, "ws/repo", pr_item, dora_metrics.BITBUCKET_API_ROOT)
        self.assertEqual(merged_at, dora_metrics.parse_iso_ts("2026-07-01T10:00:00+00:00"))

    def test_get_bitbucket_merged_prs_between_filters_by_window(self):
        session = FakeHttpSession({
            "/pullrequests": FakeHttpResponse(200, {"values": [
                {"id": 1, "title": "in", "updated_on": "2026-06-15T00:00:00+00:00"},
                {"id": 2, "title": "out", "updated_on": "2026-01-01T00:00:00+00:00"},
            ]}),
        })
        prs = dora_metrics.get_bitbucket_merged_prs_between(
            session, "ws/repo", "main", dt("2026-06-01T00:00:00Z"), dt("2026-07-01T00:00:00Z"))
        self.assertEqual([p["number"] for p in prs], [1])

    def test_bitbucket_paginate_classifies_401_and_429(self):
        session = FakeHttpSession({"/x": FakeHttpResponse(401, {}, text="Unauthorized")})
        with self.assertRaises(dora_metrics.BitbucketError):
            list(dora_metrics.bitbucket_paginate(session, "https://api.bitbucket.org/2.0/x"))

        session = FakeHttpSession({"/x": FakeHttpResponse(429, {}, text="too many requests")})
        with self.assertRaises(dora_metrics.BitbucketError):
            list(dora_metrics.bitbucket_paginate(session, "https://api.bitbucket.org/2.0/x"))


class TestPreflightGitlab(unittest.TestCase):
    def test_repo_404_is_blocked(self):
        session = FakeHttpSession({"/projects/a%2Fb": FakeHttpResponse(404, {}, text="Not Found")})
        issues = dora_metrics.preflight_repo(session, "a/b", "main", provider="gitlab")
        self.assertEqual([i["code"] for i in issues], ["repo_unreachable"])

    def test_repo_401_is_token_unauthorized(self):
        session = FakeHttpSession({"/projects/a%2Fb": FakeHttpResponse(401, {}, text="Bad credentials")})
        issues = dora_metrics.preflight_repo(session, "a/b", "main", provider="gitlab")
        self.assertEqual([i["code"] for i in issues], ["token_unauthorized"])

    def test_rate_limit_429_is_its_own_code(self):
        session = FakeHttpSession({"/projects/a%2Fb": FakeHttpResponse(429, {}, text="too many requests")})
        issues = dora_metrics.preflight_repo(session, "a/b", "main", provider="gitlab")
        self.assertEqual([i["code"] for i in issues], ["rate_limited"])

    def test_branch_404_is_partial(self):
        session = FakeHttpSession({"/branches/master": FakeHttpResponse(404, {}, text="Branch Not Found")})
        issues = dora_metrics.preflight_repo(session, "a/b", "master", provider="gitlab")
        self.assertEqual([i["code"] for i in issues], ["branch_not_found"])
        self.assertEqual(issues[0]["impact"], "partial")

    def test_unexpected_status_is_api_error(self):
        session = FakeHttpSession({"/projects/a%2Fb": FakeHttpResponse(500, {}, text="boom")})
        issues = dora_metrics.preflight_repo(session, "a/b", "main", provider="gitlab")
        self.assertEqual([i["code"] for i in issues], ["api_error"])


class TestPreflightBitbucket(unittest.TestCase):
    def test_repo_404_is_blocked(self):
        session = FakeHttpSession({"/repositories/ws/repo": FakeHttpResponse(404, {}, text="Not Found")})
        issues = dora_metrics.preflight_repo(session, "ws/repo", "main", provider="bitbucket")
        self.assertEqual([i["code"] for i in issues], ["repo_unreachable"])

    def test_rate_limit_429(self):
        session = FakeHttpSession({"/repositories/ws/repo": FakeHttpResponse(429, {}, text="rate limited")})
        issues = dora_metrics.preflight_repo(session, "ws/repo", "main", provider="bitbucket")
        self.assertEqual([i["code"] for i in issues], ["rate_limited"])

    def test_branch_404(self):
        session = FakeHttpSession({"/refs/branches/develop": FakeHttpResponse(404, {}, text="not found")})
        issues = dora_metrics.preflight_repo(session, "ws/repo", "develop", provider="bitbucket")
        self.assertEqual([i["code"] for i in issues], ["branch_not_found"])


class TestComputeRepoMetricsGitlab(unittest.TestCase):
    def test_dispatches_to_gitlab_functions_and_labels_mrs(self):
        releases = [{"tag": "v1.0.0", "published_at": dt("2026-06-20T00:00:00Z"), "url": None},
                    {"tag": "v1.1.0", "published_at": dt("2026-07-01T00:00:00Z"), "url": None}]
        with patch.object(dora_metrics, "get_gitlab_releases", return_value=releases) as m_rel, \
             patch.object(dora_metrics, "get_gitlab_tags") as m_tag, \
             patch.object(dora_metrics, "get_gitlab_merged_mrs_between",
                          return_value=[{"number": 9, "title": "x"}]) as m_merged, \
             patch.object(dora_metrics, "get_gitlab_mr_first_commit_ts",
                          return_value=dt("2026-06-30T12:00:00Z")) as m_commit:
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="g/p", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"), provider="gitlab")
        m_rel.assert_called_once()
        m_tag.assert_not_called()
        m_merged.assert_called_once()
        m_commit.assert_called_once()
        self.assertEqual(r["lead_time_n"], 1)
        self.assertEqual(r["lead_time_detail"][0]["pr"], 9)

    def test_no_prs_message_says_mrs_not_prs(self):
        releases = [{"tag": "v1.0.0", "published_at": dt("2026-06-20T00:00:00Z"), "url": None},
                    {"tag": "v1.1.0", "published_at": dt("2026-07-01T00:00:00Z"), "url": None}]
        with patch.object(dora_metrics, "get_gitlab_releases", return_value=releases), \
             patch.object(dora_metrics, "get_gitlab_merged_mrs_between", return_value=[]):
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="g/p", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"), provider="gitlab")
        self.assertTrue(any("0 merged MRs" in w for w in r["warnings"]))

    def test_deploy_source_tag_dispatches_to_get_gitlab_tags(self):
        tags = [{"tag": "v1.0.0", "published_at": dt("2026-07-01T00:00:00Z"), "url": None}]
        with patch.object(dora_metrics, "get_gitlab_tags", return_value=tags) as m_tag, \
             patch.object(dora_metrics, "get_gitlab_releases") as m_rel:
            dora_metrics.compute_repo_metrics(
                session=None, repo="g/p", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"), provider="gitlab", deploy_source="tag")
        m_tag.assert_called_once()
        m_rel.assert_not_called()


class TestComputeRepoMetricsBitbucket(unittest.TestCase):
    def test_dispatches_to_bitbucket_tags_always(self):
        tags = [{"tag": "v1.0.0", "published_at": dt("2026-06-20T00:00:00Z"), "url": None},
                {"tag": "v1.1.0", "published_at": dt("2026-07-01T00:00:00Z"), "url": None}]
        with patch.object(dora_metrics, "get_bitbucket_tags", return_value=tags) as m_tag, \
             patch.object(dora_metrics, "get_bitbucket_merged_prs_between",
                          return_value=[{"number": 4, "title": "x"}]), \
             patch.object(dora_metrics, "get_bitbucket_pr_first_commit_ts",
                          return_value=dt("2026-06-30T12:00:00Z")):
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="ws/repo", branch="main", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"), provider="bitbucket", deploy_source="tag")
        m_tag.assert_called_once()
        self.assertEqual(r["lead_time_n"], 1)
        self.assertEqual(r["deploy_source"], "tag")


class TestDiagnoseMarkersGitlab(unittest.TestCase):
    def test_no_markers_at_all_uses_gitlab_label(self):
        with patch.object(dora_metrics, "get_gitlab_release_tag_names", return_value={"published": [], "draft": []}), \
             patch.object(dora_metrics, "get_gitlab_all_tag_names", return_value=[]):
            issues = dora_metrics.diagnose_markers(
                session=None, repo="g/p", tag_pattern=r"^v", deploy_source="release",
                markers_total=0, deployment_frequency=0, latest_marker_at=None, provider="gitlab")
        self.assertEqual([i["code"] for i in issues], ["no_markers_at_all"])
        self.assertIn("published GitLab Releases", issues[0]["message"])


class TestDiagnoseMarkersBitbucket(unittest.TestCase):
    def test_bitbucket_has_no_release_fn_so_no_mismatch_check(self):
        with patch.object(dora_metrics, "get_bitbucket_all_tag_names", return_value=["release-1"]):
            issues = dora_metrics.diagnose_markers(
                session=None, repo="ws/repo", tag_pattern=r"^v\d+\.\d+\.\d+$", deploy_source="tag",
                markers_total=0, deployment_frequency=0, latest_marker_at=None, provider="bitbucket")
        codes = [i["code"] for i in issues]
        self.assertEqual(codes, ["no_markers_matching_pattern"])
        self.assertNotIn("deploy_source_mismatch", codes)


class TestCredentialSplitting(unittest.TestCase):
    def test_providers_in_play_dedups_in_first_seen_order(self):
        projects = [{"name": "P", "repos": [{"repo": "a/b"}, {"repo": "a/c", "provider": "gitlab"},
                                             {"repo": "a/d", "provider": "github"}]}]
        self.assertEqual(dora_metrics.providers_in_play(projects), ["github", "gitlab"])

    def test_split_by_credential_separates_measurable_from_stubs(self):
        projects = [{"name": "P", "repos": [
            {"repo": "a/b", "provider": "github", "prod_branch": "main"},
            {"repo": "a/c", "provider": "gitlab", "prod_branch": "main"},
        ]}]
        sessions = {"github": object(), "gitlab": None}
        measurable, stubs = dora_metrics.split_by_credential(projects, sessions)
        self.assertEqual([r["repo"] for r in measurable[0]["repos"]], ["a/b"])
        self.assertEqual(len(stubs["P"]), 1)
        self.assertEqual(stubs["P"][0]["repo"], "a/c")
        self.assertFalse(stubs["P"][0]["measured"])
        self.assertEqual(stubs["P"][0]["issues"][0]["code"], "no_credential")

    def test_merge_stub_repos_appends_by_project_name(self):
        result = {"projects": [{"name": "P", "repos": [{"repo": "a/b"}]}]}
        stubs = {"P": [{"repo": "a/c"}]}
        dora_metrics.merge_stub_repos(result, stubs)
        self.assertEqual([r["repo"] for r in result["projects"][0]["repos"]], ["a/b", "a/c"])

    def test_no_credential_repo_result_names_the_provider(self):
        repo_cfg = {"repo": "a/c", "provider": "gitlab", "prod_branch": "main"}
        stub = dora_metrics.no_credential_repo_result(repo_cfg)
        self.assertIn("no GitLab credential found", stub["issues"][0]["message"])
        self.assertFalse(stub["measured"])
        self.assertEqual(stub["provider"], "gitlab")


class TestNoCredentialResultMultiProvider(unittest.TestCase):
    def test_single_provider_message_unchanged(self):
        result = dora_metrics.no_credential_result(dt("2026-07-03T00:00:00Z"), 14, r"^v", providers=["github"])
        self.assertEqual(result["issues"][0]["message"],
                         "No GitHub credential found — nothing could be measured in this run.")

    def test_multi_provider_message_lists_all(self):
        result = dora_metrics.no_credential_result(dt("2026-07-03T00:00:00Z"), 14, r"^v",
                                                    providers=["github", "gitlab"])
        self.assertIn("GitHub", result["issues"][0]["message"])
        self.assertIn("GitLab", result["issues"][0]["message"])


class TestBuildResultMultiProvider(unittest.TestCase):
    def test_dispatches_gitlab_repo_with_its_extra_session(self):
        projects = [{"name": "P", "repos": [{"repo": "g/p", "provider": "gitlab", "prod_branch": "main"}]}]
        gitlab_session = object()
        metrics = {"repo": "g/p", "deployment_frequency": 1, "lead_time_median_hours": None,
                   "lead_time_n": 0, "markers_total": 1, "latest_marker_at": "2026-07-01T00:00:00Z",
                   "issues": [], "warnings": []}
        with patch.object(dora_metrics, "preflight_repo", return_value=[]) as m_preflight, \
             patch.object(dora_metrics, "compute_repo_metrics", return_value=dict(metrics)) as m_compute, \
             patch.object(dora_metrics, "diagnose_markers", return_value=[]):
            result = dora_metrics.build_result(
                session=None, projects=projects, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"), extra_sessions={"gitlab": gitlab_session})
        m_preflight.assert_called_once_with(gitlab_session, "g/p", "main", provider="gitlab", api_root=None)
        _, kwargs = m_compute.call_args
        self.assertEqual(kwargs.get("provider"), "gitlab")
        self.assertEqual(result["projects"][0]["repos"][0]["provider"], "gitlab")

    def test_bitbucket_repo_default_deploy_source_is_tag(self):
        projects = [{"name": "P", "repos": [{"repo": "ws/repo", "provider": "bitbucket", "prod_branch": "main"}]}]
        bb_session = object()
        metrics = {"repo": "ws/repo", "deployment_frequency": 0, "lead_time_median_hours": None,
                   "lead_time_n": 0, "markers_total": 0, "latest_marker_at": None,
                   "issues": [], "warnings": []}
        with patch.object(dora_metrics, "preflight_repo", return_value=[]), \
             patch.object(dora_metrics, "compute_repo_metrics", return_value=dict(metrics)) as m_compute, \
             patch.object(dora_metrics, "diagnose_markers", return_value=[]):
            dora_metrics.build_result(
                session=None, projects=projects, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"), extra_sessions={"bitbucket": bb_session})
        _, kwargs = m_compute.call_args
        self.assertEqual(kwargs.get("deploy_source"), "tag")


class TestAzureDevOpsFunctions(unittest.TestCase):
    def test_repo_parts_require_org_project_repository(self):
        self.assertEqual(dora_metrics.azure_repo_parts("ratefast/app.rate-fast.com/RateFast.App"),
                         ("ratefast", "app.rate-fast.com", "RateFast.App"))
        with self.assertRaises(ValueError):
            dora_metrics.azure_repo_parts("org/repo")

    def test_repo_url_quotes_project_and_repository(self):
        url = dora_metrics._azure_repo_url("org/My Project/My.Repo")
        self.assertEqual(url, "https://dev.azure.com/org/My%20Project/_apis/git/repositories/My.Repo")

    def test_pat_env_var_takes_precedence(self):
        with patch.dict(os.environ, {"AZURE_DEVOPS_PAT": "pat-xxx"}, clear=True):
            self.assertEqual(dora_metrics.get_azure_credential(), {"type": "pat", "token": "pat-xxx"})

    def test_no_pat_and_no_az_cli_returns_none(self):
        with patch.dict(os.environ, {}, clear=True), patch("shutil.which", return_value=None):
            self.assertIsNone(dora_metrics.get_azure_credential())

    def test_get_azure_tags_uses_tag_object_date_for_annotated_and_commit_date_for_lightweight(self):
        session = FakeHttpSession({
            "/refs": FakeHttpResponse(200, {"value": [
                {"name": "refs/tags/v1.0.0", "objectId": "tagobj", "peeledObjectId": "c1"},
                {"name": "refs/tags/v1.1.0", "objectId": "c2"},
                {"name": "refs/tags/nope", "objectId": "c3"},
            ]}),
            "/annotatedtags/tagobj": FakeHttpResponse(200, {"taggedBy": {"date": "2026-07-01T12:00:00Z"}, "url": "u1"}),
            "/commits/c2": FakeHttpResponse(200, {"committer": {"date": "2026-07-02T00:00:00.1234567Z"}}),
        })
        tags = dora_metrics.get_azure_tags(session, "org/proj/repo", r"^v\d+\.\d+\.\d+$")
        self.assertEqual([t["tag"] for t in tags], ["v1.0.0", "v1.1.0"])
        self.assertEqual(tags[0]["published_at"], dt("2026-07-01T12:00:00Z"))
        self.assertEqual(tags[1]["published_at"].replace(microsecond=0), dt("2026-07-02T00:00:00Z"))

    def test_get_azure_merged_prs_between_filters_by_closed_date_and_stops_when_older(self):
        session = FakeHttpSession({
            "/pullrequests": FakeHttpResponse(200, {"value": [
                {"pullRequestId": 3, "title": "newest, after window", "closedDate": "2026-07-05T00:00:00Z"},
                {"pullRequestId": 2, "title": "in window", "closedDate": "2026-06-20T10:00:00Z"},
                {"pullRequestId": 1, "title": "older than window", "closedDate": "2026-05-01T00:00:00Z"},
            ]}),
        })
        prs = dora_metrics.get_azure_merged_prs_between(
            session, "org/proj/repo", "staging", dt("2026-06-01T00:00:00Z"), dt("2026-07-01T00:00:00Z"))
        self.assertEqual([p["number"] for p in prs], [2])
        self.assertEqual(prs[0]["merged_at"], dt("2026-06-20T10:00:00Z"))
        self.assertEqual(len(session.calls), 1)  # $skip paging stops at the first page (< $top items)

    def test_get_azure_pr_first_commit_ts_takes_the_min_author_date(self):
        session = FakeHttpSession({
            "/pullrequests/7/commits": FakeHttpResponse(200, {"value": [
                {"author": {"date": "2026-06-30T08:00:00Z"}},
                {"author": {"date": "2026-06-29T22:00:00Z"}},
            ]}),
        })
        ts = dora_metrics.get_azure_pr_first_commit_ts(session, "org/proj/repo", 7)
        self.assertEqual(ts, dt("2026-06-29T22:00:00Z"))

    def test_azure_paginate_treats_203_as_unauthorized(self):
        # Azure DevOps answers 203 (a sign-in page) instead of 401 to a bad PAT.
        session = FakeHttpSession({"/x": FakeHttpResponse(203, {}, text="<html>sign in</html>")})
        with self.assertRaises(dora_metrics.AzureDevOpsError):
            list(dora_metrics.azure_paginate(session, "https://dev.azure.com/x"))

    def test_json_strips_utf8_bom(self):
        resp = FakeHttpResponse(200, {"value": []}, text="\ufeff{\"value\": [{\"a\": 1}]}")
        self.assertEqual(dora_metrics._json(resp), {"value": [{"a": 1}]})


class TestPreflightAzure(unittest.TestCase):
    def test_repo_203_is_token_unauthorized(self):
        session = FakeHttpSession({"/_apis/git/repositories/repo": FakeHttpResponse(203, {}, text="sign in")})
        issues = dora_metrics.preflight_repo(session, "org/proj/repo", "main", provider="azure")
        self.assertEqual([i["code"] for i in issues], ["token_unauthorized"])

    def test_branch_missing_is_an_empty_refs_list(self):
        session = FakeHttpSession({
            "/_apis/git/repositories/repo": FakeHttpResponse(200, {"id": "x"}),
            "/refs?filter=heads/develop": FakeHttpResponse(200, {"value": [], "count": 0}),
        })
        issues = dora_metrics.preflight_repo(session, "org/proj/repo", "develop", provider="azure")
        self.assertEqual([i["code"] for i in issues], ["branch_not_found"])

    def test_branch_present(self):
        session = FakeHttpSession({
            "/_apis/git/repositories/repo": FakeHttpResponse(200, {"id": "x"}),
            "/refs?filter=heads/main": FakeHttpResponse(200, {"value": [{"name": "refs/heads/main"}], "count": 1}),
        })
        self.assertEqual(dora_metrics.preflight_repo(session, "org/proj/repo", "main", provider="azure"), [])


class TestDeploySourceMerge(unittest.TestCase):
    """deploy_source "merge": every PR merged into prod_branch in the window is
    one deploy, dated by its merge; lead time = first commit -> merge."""

    def test_github_merge_counts_prs_and_measures_each_lead_time(self):
        merged = [{"number": 1, "title": "a", "merged_at": dt("2026-06-25T00:00:00Z")},
                  {"number": 2, "title": "b", "merged_at": dt("2026-07-01T00:00:00Z")}]
        first = {1: dt("2026-06-24T12:00:00Z"), 2: dt("2026-06-29T00:00:00Z")}
        with patch.object(dora_metrics, "get_merged_prs_between", return_value=merged) as m_merged, \
             patch.object(dora_metrics, "get_pr_first_commit_ts",
                          side_effect=lambda s, r, n: first[n]), \
             patch.object(dora_metrics, "get_prod_releases") as m_rel:
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="a/b", branch="develop", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"), deploy_source="merge")
        m_rel.assert_not_called()
        args, _ = m_merged.call_args
        self.assertEqual(args[3], dt("2026-06-19T00:00:00Z"))  # window start
        self.assertEqual(args[4], dt("2026-07-03T00:00:00Z"))  # now
        self.assertEqual(r["deploy_source"], "merge")
        self.assertEqual(r["deployment_frequency"], 2)
        self.assertEqual([d["tag"] for d in r["deploys_in_window"]], ["PR #1", "PR #2"])
        self.assertEqual(r["lead_time_n"], 2)
        self.assertEqual(r["lead_time_median_hours"], 30.0)  # median of [12, 48]
        self.assertEqual(r["markers_total"], 2)
        self.assertEqual(r["latest_marker_at"], "2026-07-01T00:00:00Z")
        self.assertEqual(r["issues"], [])

    def test_github_merge_resolves_missing_merge_time_per_pr(self):
        with patch.object(dora_metrics, "get_merged_prs_between", return_value=[{"number": 5, "title": "x"}]), \
             patch.object(dora_metrics, "get_pr_merged_at", return_value=dt("2026-07-01T00:00:00Z")) as m_at, \
             patch.object(dora_metrics, "get_pr_first_commit_ts", return_value=dt("2026-06-30T00:00:00Z")):
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="a/b", branch="develop", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"), deploy_source="merge")
        m_at.assert_called_once()
        self.assertEqual(r["deployment_frequency"], 1)
        self.assertEqual(r["lead_time_median_hours"], 24.0)

    def test_zero_merges_is_df_zero_lead_time_none_and_a_note(self):
        with patch.object(dora_metrics, "get_merged_prs_between", return_value=[]):
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="a/b", branch="develop", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"), deploy_source="merge")
        self.assertEqual(r["deployment_frequency"], 0)
        self.assertIsNone(r["lead_time_median_hours"])
        issues = dora_metrics.diagnose_markers(
            session=None, repo="a/b", tag_pattern=r"^v", deploy_source="merge",
            markers_total=0, deployment_frequency=0, latest_marker_at=None)
        self.assertEqual([i["code"] for i in issues], ["no_merged_prs_in_window"])
        self.assertEqual(issues[0]["impact"], "none")

    def test_merge_with_deploys_makes_no_diagnostic_calls(self):
        with patch.object(dora_metrics, "get_release_tag_names") as names, \
             patch.object(dora_metrics, "get_all_tag_names") as tags:
            issues = dora_metrics.diagnose_markers(
                session=None, repo="a/b", tag_pattern=r"^v", deploy_source="merge",
                markers_total=3, deployment_frequency=3, latest_marker_at="2026-07-01T00:00:00Z")
        self.assertEqual(issues, [])
        names.assert_not_called()
        tags.assert_not_called()

    def test_azure_merge_dispatches_to_azure_functions(self):
        merged = [{"number": 905, "title": "x", "merged_at": dt("2026-07-01T00:00:00Z")}]
        with patch.object(dora_metrics, "get_azure_merged_prs_between", return_value=merged) as m_merged, \
             patch.object(dora_metrics, "get_azure_pr_first_commit_ts", return_value=dt("2026-06-30T12:00:00Z")), \
             patch.object(dora_metrics, "get_azure_tags") as m_tags:
            r = dora_metrics.compute_repo_metrics(
                session=None, repo="org/proj/repo", branch="staging", tag_pattern=r"^v",
                window_days=14, now=dt("2026-07-03T00:00:00Z"), provider="azure", deploy_source="merge")
        m_merged.assert_called_once()
        m_tags.assert_not_called()
        self.assertEqual(r["provider"], "azure")
        self.assertEqual(r["lead_time_detail"][0]["pr"], 905)
        self.assertEqual(r["lead_time_detail"][0]["deploy_tag"], "PR #905")

    def test_merge_is_a_valid_deploy_source_everywhere_and_release_is_not_on_azure(self):
        dora_metrics.validate_deploy_sources([{"repos": [
            {"repo": "a/b", "deploy_source": "merge"},
            {"repo": "o/p/r", "provider": "azure", "deploy_source": "merge"},
            {"repo": "o/p/r2", "provider": "azure"},  # defaults to tag
        ]}])
        with self.assertRaises(ValueError):
            dora_metrics.validate_deploy_sources([{"repos": [{"repo": "o/p/r", "provider": "azure", "deploy_source": "release"}]}])

    def test_azure_default_deploy_source_is_tag(self):
        self.assertEqual(dora_metrics.effective_deploy_source({"repo": "o/p/r", "provider": "azure"}), "tag")

    def test_azure_repo_identifier_is_validated_with_providers(self):
        with self.assertRaises(ValueError):
            dora_metrics.validate_providers([{"repos": [{"repo": "org/repo", "provider": "azure"}]}])
        dora_metrics.validate_providers([{"repos": [{"repo": "org/proj/repo", "provider": "azure"}]}])


class TestBuildResultAzure(unittest.TestCase):
    def test_azure_repo_uses_its_session_and_records_the_provider(self):
        projects = [{"name": "P", "repos": [{"repo": "o/p/r", "provider": "azure", "prod_branch": "staging",
                                             "deploy_source": "merge"}]}]
        az_session = object()
        metrics = {"repo": "o/p/r", "deployment_frequency": 4, "lead_time_median_hours": 6.0,
                   "lead_time_n": 4, "markers_total": 4, "latest_marker_at": "2026-07-01T00:00:00Z",
                   "issues": [], "warnings": []}
        with patch.object(dora_metrics, "preflight_repo", return_value=[]) as m_pre, \
             patch.object(dora_metrics, "compute_repo_metrics", return_value=dict(metrics)) as m_compute, \
             patch.object(dora_metrics, "diagnose_markers", return_value=[]):
            result = dora_metrics.build_result(
                session=None, projects=projects, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"), extra_sessions={"azure": az_session})
        m_pre.assert_called_once_with(az_session, "o/p/r", "staging", provider="azure", api_root=None)
        _, kwargs = m_compute.call_args
        self.assertEqual((kwargs["provider"], kwargs["deploy_source"]), ("azure", "merge"))
        repo = result["projects"][0]["repos"][0]
        self.assertEqual(repo["provider"], "azure")
        self.assertTrue(repo["measured"])

    def test_azure_error_is_classified_with_its_label(self):
        projects = [{"name": "P", "repos": [{"repo": "o/p/r", "provider": "azure", "prod_branch": "main"}]}]
        with patch.object(dora_metrics, "preflight_repo", return_value=[]), \
             patch.object(dora_metrics, "compute_repo_metrics",
                          side_effect=dora_metrics.AzureDevOpsError("401 Unauthorized. Check the PAT.")):
            result = dora_metrics.build_result(
                session=None, projects=projects, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"), extra_sessions={"azure": object()})
        issue = result["projects"][0]["repos"][0]["issues"][0]
        self.assertEqual(issue["code"], "token_unauthorized")
        self.assertIn("Azure DevOps API", issue["message"])

    def test_no_credential_stub_names_azure(self):
        stub = dora_metrics.no_credential_repo_result({"repo": "o/p/r", "provider": "azure", "prod_branch": "main"})
        self.assertIn("no Azure DevOps credential found", stub["issues"][0]["message"])
        self.assertEqual(stub["deploy_source"], "tag")

    def test_summary_mentions_the_provider_and_merge_source(self):
        result = {"issues": [], "projects": [{"name": "P", "repos": [{
            "repo": "o/p/r", "provider": "azure", "deploy_source": "merge", "type": ["backend"], "measured": True,
            "deployment_frequency": 4, "lead_time_median_hours": 6.0, "lead_time_n": 4, "issues": []}]}],
            "practice_guidance": []}
        text = dora_metrics.format_human_summary(result, 14)
        self.assertIn("Azure DevOps", text)
        self.assertIn("deploy_source: merge", text)


if __name__ == "__main__":
    unittest.main()
