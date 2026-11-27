"""Tests for scripts/scheduled_scans.py: which scheduled run decides each step (CLOS-417 D5, D6)."""
import importlib.util
import json
import os
import subprocess
import sys
import unittest
from datetime import datetime, timezone

SCRIPTS = os.path.join(os.path.dirname(__file__), "..", "scripts")


def _load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(SCRIPTS, f"{name}.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


scans = _load("scheduled_scans")
fingerprint = _load("fingerprint")

WF = "vulnerability-scan.yml"
REPO = "somnio-products/closebook-finance-platform"
NOW = datetime(2026, 11, 30, 13, 0, tzinfo=timezone.utc)  # the Monday triage
REPO_SCAN = "Scan the repository (lockfile, Dockerfiles, Terraform)"
IMAGES = "Scan the images"
AUDIT = "Check dependency advisories"
DAYS = {"thu": "2026-11-26", "fri": "2026-11-27", "mon": "2026-11-23", "tue": "2026-11-24",
        "wed": "2026-11-25"}


def run(day, run_id, trivy=None, audit="success", images=None):
    """A scheduled run of vulnerability-scan.yml as `gh run list` and `gh run view --json jobs` print it.
    `images` None means the image steps were skipped (Tuesday, Wednesday, Friday)."""
    trivy_steps = [("Set up job", "success"), (REPO_SCAN, trivy or "success"),
                   ("Build the images", "skipped" if images is None else "success"),
                   (IMAGES, "skipped" if images is None else images)]
    trivy_ok = all(c in ("success", "skipped") for _, c in trivy_steps)
    jobs = [
        {"databaseId": run_id * 10, "name": "Trivy", "conclusion": "success" if trivy_ok else "failure",
         "steps": [{"name": n, "conclusion": c} for n, c in trivy_steps]},
        {"databaseId": run_id * 10 + 1, "name": "Dependency advisories",
         "conclusion": "success" if audit == "success" else "failure",
         "steps": [{"name": "Set up job", "conclusion": "success"}, {"name": AUDIT, "conclusion": audit}]},
    ]
    row = {"databaseId": run_id, "createdAt": f"{DAYS[day]}T19:00:00Z", "headSha": f"{run_id:040d}",
           "url": f"https://github.com/{REPO}/actions/runs/{run_id}", "conclusion": "success"}
    return row, jobs


def decide(*runs):
    return scans.decide(WF, "develop", [r for r, _ in runs], {r["databaseId"]: jobs for r, jobs in runs})


def failing(result):
    return {(f["job"], f["step"]): f["run_id"] for f in result["failing"]}


class TestDecide(unittest.TestCase):
    def test_an_image_failure_on_thursday_is_not_hidden_by_friday(self):
        result = decide(run("thu", 4, images="failure"), run("fri", 5))
        self.assertEqual(failing(result), {("Trivy", IMAGES): 4})
        steps = {(s["job"], s["step"]): s["run_id"] for s in result["steps"]}
        self.assertEqual(steps[("Trivy", REPO_SCAN)], 5)
        self.assertEqual(steps[("Trivy", IMAGES)], 4)

    def test_a_failure_a_later_run_cleared_is_not_reported(self):
        result = decide(run("tue", 2, trivy="failure"), run("wed", 3))
        self.assertEqual(result["failing"], [])
        self.assertEqual(result["could_not_see"], [f"{WF}: 'Trivy' / 'Build the images' ran in no run of the window",
                                                   f"{WF}: 'Trivy' / '{IMAGES}' ran in no run of the window"])

    def test_a_skipped_weekday_leaves_the_latest_run_deciding(self):
        # No Wednesday run (the schedule skipped it, as on 2026-11-20): Tuesday's failure is the latest.
        result = decide(run("mon", 1, images="success"), run("tue", 2, audit="failure"))
        self.assertEqual(failing(result), {("Dependency advisories", AUDIT): 2})
        # Thursday ran the step again and it passed: cleared.
        result = decide(run("mon", 1, images="success"), run("tue", 2, audit="failure"), run("thu", 4, images="success"))
        self.assertEqual(failing(result), {})

    def test_the_order_of_gh_rows_does_not_matter(self):
        rows = [run("fri", 5), run("thu", 4, images="failure"), run("mon", 1, images="success")]
        self.assertEqual(failing(decide(*rows)), failing(decide(*reversed(rows))))

    def test_a_failing_step_carries_its_run_and_its_finding(self):
        [only] = decide(run("thu", 4, images="failure"))["failing"]
        self.assertEqual(only["run_url"], f"https://github.com/{REPO}/actions/runs/4")
        self.assertEqual(only["head_sha"], f"{4:040d}")
        self.assertEqual(only["created_at"], "2026-11-26T19:00:00Z")
        self.assertEqual(only["job_id"], 40)
        self.assertEqual(only["finding"], {
            "source": "scheduled-scan",
            "rule": f"{WF}/Trivy/{IMAGES}",
            "file": f".github/workflows/{WF}",
            "title": f"{IMAGES} fails on develop",
            "label": "audit-needs-human",
        })

    def test_the_same_failing_step_has_the_same_fingerprint_on_any_date(self):
        [monday] = decide(run("mon", 1, images="failure"))["failing"]
        [thursday] = decide(run("thu", 4, images="failure"))["failing"]
        self.assertNotEqual(monday["run_id"], thursday["run_id"])
        self.assertEqual(monday["finding"], thursday["finding"])
        self.assertEqual(fingerprint.fingerprint(monday["finding"]), fingerprint.fingerprint(thursday["finding"]))

    def test_an_empty_window(self):
        result = decide()
        self.assertEqual((result["steps"], result["failing"]), ([], []))
        self.assertEqual(result["could_not_see"], [f"{WF}: no completed scheduled run on develop in the window"])

    def test_a_job_that_failed_with_no_failed_step(self):
        row, jobs = run("thu", 4, images="success")
        jobs[0]["conclusion"] = "failure"  # timed out: the running step is cancelled, none failed
        jobs[0]["steps"][-1]["conclusion"] = "cancelled"
        result = decide((row, jobs))
        self.assertEqual(result["failing"], [])
        self.assertIn(f"{WF}: 'Trivy' failed in {row['url']} with no failed step", result["could_not_see"])


class FakeGh:
    def __init__(self, runs, fail_list=None, fail_view=()):
        self.runs, self.fail_list, self.fail_view, self.calls = runs, fail_list, set(fail_view), []

    def __call__(self, *args):
        self.calls.append(args)
        if args[:2] == ("run", "list"):
            if self.fail_list:
                raise scans.GhError(self.fail_list)
            return json.dumps([r for r, _ in self.runs])
        run_id = int(args[2])
        if run_id in self.fail_view:
            raise scans.GhError("HTTP 502")
        return json.dumps({"jobs": dict((r["databaseId"], j) for r, j in self.runs)[run_id]})


class TestRead(unittest.TestCase):
    def test_it_asks_gh_for_the_completed_scheduled_runs_of_the_last_7_days(self):
        fake = FakeGh([run("thu", 4, images="failure"), run("fri", 5)])
        result = scans.read(REPO, WF, "develop", NOW, run_gh=fake)
        listing = fake.calls[0]
        for flag, value in [("--workflow", WF), ("--branch", "develop"), ("--event", "schedule"),
                            ("--status", "completed"), ("--created", ">=2026-11-23T13:00:00Z")]:
            self.assertEqual(listing[listing.index(flag) + 1], value)
        self.assertEqual(result["window"], {"from": "2026-11-23T13:00:00Z", "to": "2026-11-30T13:00:00Z"})
        self.assertEqual([r["id"] for r in result["runs"]], [4, 5])
        self.assertEqual(failing(result), {("Trivy", IMAGES): 4})

    def test_a_gh_error_on_the_listing_is_could_not_see(self):
        result = scans.read(REPO, WF, "develop", NOW, run_gh=FakeGh([], fail_list="HTTP 404: workflow not found"))
        self.assertEqual(result["could_not_see"], [f"{WF}: cannot list its scheduled runs: HTTP 404: workflow not found"])
        self.assertEqual(result["failing"], [])

    def test_a_run_whose_jobs_cannot_be_read_is_could_not_see_and_the_rest_decide(self):
        fake = FakeGh([run("thu", 4, images="failure"), run("fri", 5)], fail_view={5})
        result = scans.read(REPO, WF, "develop", NOW, run_gh=fake)
        self.assertEqual(result["could_not_see"][0],
                         f"{WF}: cannot read the jobs of https://github.com/{REPO}/actions/runs/5: HTTP 502")
        self.assertEqual(failing(result), {("Trivy", IMAGES): 4})


class TestCommandLine(unittest.TestCase):
    def run_script(self, *args):
        return subprocess.run([sys.executable, os.path.join(SCRIPTS, "scheduled_scans.py"), *args],
                              capture_output=True, text=True, env={**os.environ, "PATH": ""})

    def test_without_gh_the_workflow_is_could_not_see_and_it_exits_0(self):
        result = self.run_script(REPO, WF, "develop")
        self.assertEqual(result.returncode, 0, result.stderr)
        out = json.loads(result.stdout)
        self.assertEqual(out["failing"], [])
        self.assertTrue(out["could_not_see"][0].startswith(f"{WF}: cannot list its scheduled runs:"))

    def test_bad_arguments_exit_2(self):
        for args in [(), (REPO, WF), ("closebook", WF, "develop"), (REPO, ".github/workflows/x.yml", "develop"),
                     (REPO, WF, " ")]:
            with self.subTest(args=args):
                self.assertEqual(self.run_script(*args).returncode, 2)


if __name__ == "__main__":
    unittest.main()
