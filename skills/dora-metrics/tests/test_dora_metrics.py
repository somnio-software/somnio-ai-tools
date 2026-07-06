"""Unit tests para scripts/dora_metrics.py.

Sin red: todas las llamadas a GitHub se mockean a nivel de función
(get_prod_releases, get_prod_tags, get_merged_prs_between,
get_pr_first_commit_ts). Corren en segundos.

Uso:
    python3 -m unittest discover -s tests -p "test_*.py" -v
"""

import argparse
import importlib.util
import os
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
    def test_branch_without_proyecto_raises(self):
        args = SimpleNamespace(branch="main", proyecto=None, deploy_source=None)
        with self.assertRaises(ValueError):
            dora_metrics.validate_scoped_overrides(args)

    def test_deploy_source_without_proyecto_raises(self):
        args = SimpleNamespace(branch=None, proyecto=None, deploy_source="tag")
        with self.assertRaises(ValueError):
            dora_metrics.validate_scoped_overrides(args)

    def test_with_proyecto_ok(self):
        args = SimpleNamespace(branch="main", proyecto="Example Project", deploy_source="tag")
        dora_metrics.validate_scoped_overrides(args)  # no debe tirar

    def test_no_overrides_ok(self):
        args = SimpleNamespace(branch=None, proyecto=None, deploy_source=None)
        dora_metrics.validate_scoped_overrides(args)  # no debe tirar


class TestValidateDeploySources(unittest.TestCase):
    def test_valid_sources_ok(self):
        proyectos = [{"repos": [{"repo": "a/b", "deploy_source": "release"},
                                 {"repo": "a/c", "deploy_source": "tag"},
                                 {"repo": "a/d"}]}]  # sin campo -> default release
        dora_metrics.validate_deploy_sources(proyectos)  # no debe tirar

    def test_invalid_source_raises(self):
        proyectos = [{"repos": [{"repo": "a/b", "deploy_source": "ci_pipeline"}]}]
        with self.assertRaises(ValueError):
            dora_metrics.validate_deploy_sources(proyectos)


class TestComputeRepoMetrics(unittest.TestCase):
    """Todas mockean get_prod_releases/get_prod_tags/get_merged_prs_between/
    get_pr_first_commit_ts — compute_repo_metrics no debe pegarle a la red."""

    def _releases(self, tags_and_dates):
        return [{"tag": t, "published_at": dt(d), "url": f"https://x/{t}"} for t, d in tags_and_dates]

    def test_deployment_frequency_counts_releases_in_window(self):
        releases = self._releases([
            ("v1.0.0", "2026-06-01T00:00:00Z"),  # fuera de ventana
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
        self.assertEqual(r["deployment_frequency"], 0)  # 0 real, no None (ver comentario en el script)
        self.assertIsNone(r["lead_time_median_hours"])  # sin dato computable, no 0.0
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
        self.assertTrue(any("no tiene release anterior" in w for w in r["warnings"]))

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
        self.assertTrue(any("0 PRs mergeados" in w for w in r["warnings"]))

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
            1: dt("2026-06-30T00:00:00Z"),   # 24h antes del release
            2: dt("2026-06-29T00:00:00Z"),   # 48h antes
            3: dt("2026-06-30T12:00:00Z"),   # 12h antes
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
        self.assertEqual(r["lead_time_median_hours"], 24.0)  # mediana de [12, 24, 48]

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
        self.assertTrue(any("no se pudo obtener el primer commit" in w for w in r["warnings"]))

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


if __name__ == "__main__":
    unittest.main()
