#!/usr/bin/env python3
"""Which scheduled run of a workflow decides each of its steps, for the weekly triage (CLOS-417).

Usage: scheduled_scans.py <owner/name> <workflow file> <base branch>

Reads the completed scheduled runs of the workflow on the base branch created in the 7 days before now
(`gh run list`) and each run's jobs (`gh run view --json jobs`). For each (job, step), the latest run of
the window that ran the step, `success` or `failure`, decides: a failure a later run of the step cleared
is fixed and not reported, and a step a later run skipped (an image scan that runs only some days) is
still decided by the run that ran it. Prints JSON with the window, the runs read, every step and its
deciding run, the failing ones with their step-level finding, and `could_not_see` with the reason (no
run in the window, a `gh` error, a step every run skipped, a job that failed with no failed step).

Exit 0 whenever the arguments are valid: a failing step or a `gh` error is data for the triage, not an
error of this script. Exit 2 for bad arguments. It only reads.
"""
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from repo_config import WORKFLOW_FILE  # noqa: E402  (sibling module: the rule of `scheduled_scans`)

WINDOW = timedelta(days=7)  # the span between two weekly triages
RAN = ("success", "failure")
REPO = re.compile(r"[\w.-]+/[\w.-]+")


class GhError(Exception):
    pass


def gh(*args: str) -> str:
    try:
        result = subprocess.run(["gh", *args], capture_output=True, text=True)
    except OSError as exc:
        raise GhError(str(exc)) from exc
    if result.returncode:
        raise GhError((result.stderr.strip() or f"gh exited {result.returncode}").splitlines()[-1])
    return result.stdout


def finding(workflow: str, base_branch: str, job: str, step: str) -> dict:
    """The step-level finding of a failing step. No input carries a date, a count or a version, so its
    fingerprint is the same every week the step fails."""
    return {
        "source": "scheduled-scan",
        "rule": f"{workflow}/{job}/{step}",
        "file": f".github/workflows/{workflow}",
        "title": f"{step} fails on {base_branch}",
        "label": "audit-needs-human",
    }


def decide(workflow: str, base_branch: str, runs: list, jobs_by_run: dict) -> dict:
    """-> {steps, failing, could_not_see} from `gh run list` rows and each readable run's jobs."""
    deciding, seen, job_decided, could_not_see = {}, set(), {}, []
    for run in sorted(runs, key=lambda r: (r["createdAt"], r["databaseId"]), reverse=True):
        where = {"run_id": run["databaseId"], "run_url": run["url"], "head_sha": run["headSha"],
                 "created_at": run["createdAt"]}
        for job in jobs_by_run.get(run["databaseId"]) or []:
            if job.get("conclusion") in RAN:
                job_decided.setdefault(job["name"], (job, run))
            for step in job.get("steps") or []:
                key = (job["name"], step["name"])
                seen.add(key)
                if key not in deciding and step.get("conclusion") in RAN:
                    deciding[key] = {"job": job["name"], "step": step["name"], "conclusion": step["conclusion"],
                                     "job_id": job.get("databaseId"), **where}
    steps = [deciding[key] for key in sorted(deciding)]
    failing = [{**s, "finding": finding(workflow, base_branch, s["job"], s["step"])}
               for s in steps if s["conclusion"] == "failure"]
    if not runs:
        could_not_see.append(f"{workflow}: no completed scheduled run on {base_branch} in the window")
    for job_name, step_name in sorted(seen - set(deciding)):
        could_not_see.append(f"{workflow}: '{job_name}' / '{step_name}' ran in no run of the window")
    # A timeout or a runner that never started fails the job with no failed step: no step finding
    # covers it, so it is a blind spot to read by hand, not a guessed finding.
    for job_name, (job, run) in sorted(job_decided.items()):
        if job["conclusion"] == "failure" and not any(s.get("conclusion") == "failure" for s in job.get("steps") or []):
            could_not_see.append(f"{workflow}: '{job_name}' failed in {run['url']} with no failed step")
    return {"steps": steps, "failing": failing, "could_not_see": could_not_see}


def _iso(moment: datetime) -> str:
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def read(repo: str, workflow: str, base_branch: str, now: datetime, run_gh=gh) -> dict:
    since = now - WINDOW
    out = {"repo": repo, "workflow": workflow, "base_branch": base_branch,
           "window": {"from": _iso(since), "to": _iso(now)}, "runs": [], "steps": [], "failing": [],
           "could_not_see": []}
    try:
        runs = json.loads(run_gh(
            "run", "list", "--repo", repo, "--workflow", workflow, "--branch", base_branch,
            "--event", "schedule", "--status", "completed", "--created", f">={_iso(since)}",
            "--limit", "100", "--json", "databaseId,createdAt,headSha,url,conclusion"))
    except (GhError, ValueError) as exc:
        out["could_not_see"].append(f"{workflow}: cannot list its scheduled runs: {exc}")
        return out
    jobs_by_run, unreadable = {}, []
    for run in runs:
        try:
            jobs_by_run[run["databaseId"]] = json.loads(
                run_gh("run", "view", str(run["databaseId"]), "--repo", repo, "--json", "jobs"))["jobs"]
        except (GhError, ValueError, KeyError) as exc:
            unreadable.append(f"{workflow}: cannot read the jobs of {run['url']}: {exc}")
    out["runs"] = [{"id": r["databaseId"], "created_at": r["createdAt"], "conclusion": r["conclusion"],
                    "head_sha": r["headSha"], "url": r["url"]} for r in runs]
    decided = decide(workflow, base_branch, runs, jobs_by_run)
    out.update(decided, could_not_see=unreadable + decided["could_not_see"])
    return out


def main(argv: list) -> int:
    if len(argv) != 4 or not REPO.fullmatch(argv[1]) or not WORKFLOW_FILE.fullmatch(argv[2]) or not argv[3].strip():
        print(__doc__, file=sys.stderr)
        return 2
    json.dump(read(argv[1], argv[2], argv[3], datetime.now(timezone.utc)), sys.stdout, indent=2, ensure_ascii=False)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
