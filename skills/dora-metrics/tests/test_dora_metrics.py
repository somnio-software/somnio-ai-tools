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
        issue = dora_metrics.make_issue("github_api_error", "blocked", "a/b: GitHub API error 500")
        text = dora_metrics.format_human_summary(
            self._result([self._repo(measured=False, issues=[issue])]), window_days=14)
        self.assertIn("a/b: GitHub API error 500", text)
        self.assertIn("no guidance for 'github_api_error'", text)
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
        result = {"issues": [dora_metrics.make_issue("github_api_error", "blocked", "m")], "projects": []}
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
        self.assertEqual([i["code"] for i in issues], ["github_api_error"])
        self.assertEqual(issues[0]["impact"], "partial")
        self.assertEqual(issues[0]["evidence"]["prod_branch"], "main")

    def test_branch_is_not_checked_when_the_repo_is_unreachable(self):
        session = FakeSession({"/repos/a/b": FakeResponse(404, "Not Found")})
        dora_metrics.preflight_repo(session, "a/b", "main")
        self.assertTrue(all("/branches/" not in url for url in session.calls))

    def test_unexpected_status_is_github_api_error(self):
        session = FakeSession({"/repos/a/b": FakeResponse(500, "boom")})
        issues = dora_metrics.preflight_repo(session, "a/b", "main")
        self.assertEqual([i["code"] for i in issues], ["github_api_error"])


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

    def test_unrecognized_api_exception_falls_back_to_github_api_error(self):
        with patch.object(dora_metrics, "preflight_repo", return_value=[]), \
             patch.object(dora_metrics, "compute_repo_metrics",
                          side_effect=dora_metrics.GitHubError("GitHub API error 500 at ...")):
            result = dora_metrics.build_result(
                session=None, projects=self.PROJECTS, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"))
        self.assertEqual([i["code"] for i in result["projects"][0]["repos"][0]["issues"]], ["github_api_error"])

    def test_repo_name_containing_401_is_not_mistaken_for_an_auth_failure(self):
        projects = [{"name": "P", "repos": [{"repo": "org/app-401", "prod_branch": "main"}]}]
        boom = dora_metrics.GitHubError(
            "GitHub API error 500 at https://api.github.com/repos/org/app-401/releases: boom")
        with patch.object(dora_metrics, "preflight_repo", return_value=[]), \
             patch.object(dora_metrics, "compute_repo_metrics", side_effect=boom):
            result = dora_metrics.build_result(
                session=None, projects=projects, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"))
        self.assertEqual([i["code"] for i in result["projects"][0]["repos"][0]["issues"]], ["github_api_error"])

    def test_repo_name_containing_404_is_not_mistaken_for_an_unreachable_repo(self):
        projects = [{"name": "P", "repos": [{"repo": "org/404-redirects", "prod_branch": "main"}]}]
        boom = dora_metrics.GitHubError(
            "GitHub API error 500 at https://api.github.com/repos/org/404-redirects/tags: boom")
        with patch.object(dora_metrics, "preflight_repo", return_value=[]), \
             patch.object(dora_metrics, "compute_repo_metrics", side_effect=boom):
            result = dora_metrics.build_result(
                session=None, projects=projects, tag_pattern=r"^v", window_days=14,
                now=dt("2026-07-03T00:00:00Z"))
        self.assertEqual([i["code"] for i in result["projects"][0]["repos"][0]["issues"]], ["github_api_error"])

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
    audits: <YYYY-MM-DD>-<repo>-dora-metrics.{json,md}, one pair per repo."""

    def _repo(self, name):
        return {"repo": name, "type": ["backend"], "deploy_source": "release",
                "measured": True, "deployment_frequency": 2,
                "lead_time_median_hours": 4.3, "lead_time_n": 3,
                "issues": [], "warnings": []}

    def _write(self, result, tmp):
        dora_metrics.write_output(result, window_days=14, out_dir=tmp,
                                  now=dt("2026-09-14T10:00:00Z"))
        return sorted(os.listdir(tmp))

    def test_one_pair_of_files_per_repo(self):
        result = {"issues": [], "projects": [{"name": "Example Project", "repos": [
            self._repo("example-org/example-frontend"),
            self._repo("partner-org/example-backend")]}]}
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(self._write(result, tmp), [
                "2026-09-14-example-backend-dora-metrics.json",
                "2026-09-14-example-backend-dora-metrics.md",
                "2026-09-14-example-frontend-dora-metrics.json",
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

    def test_still_writes_one_file_when_nothing_was_measured(self):
        result = dora_metrics.no_credential_result(
            now=dt("2026-09-14T10:00:00Z"), window_days=14, tag_pattern=r"^v")
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(self._write(result, tmp), [
                "2026-09-14-no-repositories-dora-metrics.json",
                "2026-09-14-no-repositories-dora-metrics.md",
            ])

    def test_writes_nothing_without_an_out_dir(self):
        result = {"issues": [], "projects": [{"name": "P", "repos": [
            self._repo("o/one")]}]}
        with tempfile.TemporaryDirectory() as tmp:
            dora_metrics.write_output(result, window_days=14, out_dir=None,
                                      now=dt("2026-09-14T10:00:00Z"))
            self.assertEqual(os.listdir(tmp), [])


if __name__ == "__main__":
    unittest.main()
