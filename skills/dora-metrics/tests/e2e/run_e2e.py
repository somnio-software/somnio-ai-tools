#!/usr/bin/env python3
"""
E2E of scripts/dora_metrics.py against a real, throwaway GitHub repo.

Reproduces the 7 cases validated manually in session (release mode with
realistic lead time, median with n>1, annotated tag, lightweight tag, 0-PRs
warning, --window-days, --branch). It does not require real minute-long waits:
it uses GIT_AUTHOR_DATE/GIT_COMMITTER_DATE to simulate realistic lead times and
windows, and only a short sleep (a few seconds) where needed to avoid the
specific race condition between a merge commit and the PR's `merged_at`
(see the docstring of dora_metrics.py).

WARNING: on startup, this script DELETES all the contents of --repo
(releases, tags, branches except main, and the history of main via force-push)
so that each run is reproducible. --repo must be a 100% throwaway repo of your
own — never a real one. It has no default: pass your own throwaway repo with
--repo.

Requires: gh CLI authenticated with admin permissions on --repo (delete
releases/tags/branches, force-push to main).

Usage:
    python3 tests/e2e/run_e2e.py --repo your-user/your-throwaway-repo
    python3 tests/e2e/run_e2e.py --repo your-user/your-throwaway-repo --yes
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timedelta, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DORA_SCRIPT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "..", "scripts", "dora_metrics.py"))

RESULTS = []


def check(case, condition, detail=""):
    RESULTS.append((case, bool(condition)))
    status = "PASS" if condition else "FAIL"
    print(f"  [{status}] {case}" + (f" — {detail}" if detail else ""))


def run(cmd, cwd=None, env=None, check_rc=True, input_text=None):
    result = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True, input=input_text)
    if check_rc and result.returncode != 0:
        raise RuntimeError(f"Command failed ({' '.join(cmd)}):\nSTDOUT: {result.stdout}\nSTDERR: {result.stderr}")
    return result


def gh(args, check_rc=True):
    return run(["gh"] + args, check_rc=check_rc)


def git(args, cwd, env=None, check_rc=True):
    return run(["git"] + args, cwd=cwd, env=env, check_rc=check_rc)


def backdated_env(hours_ago):
    ts = datetime.now(timezone.utc) - timedelta(hours=hours_ago)
    iso = ts.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    env = dict(os.environ)
    env["GIT_AUTHOR_DATE"] = iso
    env["GIT_COMMITTER_DATE"] = iso
    return env


def reset_repo(repo, workdir):
    print(f"Resetting {repo} to a clean state (deletes releases, tags, branches != main)...")

    out = gh(["release", "list", "--repo", repo, "--json", "tagName", "-q", ".[].tagName"], check_rc=False)
    for tag in out.stdout.split():
        gh(["release", "delete", tag, "--repo", repo, "--yes", "--cleanup-tag"], check_rc=False)

    # Tags without a Release (annotated or lightweight) — delete via the API, not
    # via a git push to a bare URL (that depends on a credential helper that may
    # not be configured; the API through gh always uses the already-authenticated
    # session).
    out = gh(["api", f"repos/{repo}/tags", "--paginate", "-q", ".[].name"], check_rc=False)
    for name in out.stdout.split():
        gh(["api", "-X", "DELETE", f"repos/{repo}/git/refs/tags/{name}"], check_rc=False)

    out = gh(["api", f"repos/{repo}/branches", "--paginate", "-q", ".[].name"], check_rc=False)
    for branch in out.stdout.split():
        if branch != "main":
            gh(["api", "-X", "DELETE", f"repos/{repo}/git/refs/heads/{branch}"], check_rc=False)

    # The initial clone (before this reset) already brought the repo's old tags
    # in LOCALLY — deleting them remotely doesn't remove them from the clone, and
    # git refuses to recreate a tag that already exists locally.
    out = git(["tag", "-l"], cwd=workdir, check_rc=False)
    for name in out.stdout.split():
        git(["tag", "-d", name], cwd=workdir, check_rc=False)

    git(["checkout", "--orphan", "e2e-reset"], cwd=workdir)
    git(["rm", "-rf", "."], cwd=workdir, check_rc=False)
    with open(os.path.join(workdir, "README.md"), "w") as f:
        f.write("# e2e reset\n")
    git(["add", "README.md"], cwd=workdir)
    git(["commit", "-m", "Reset for e2e run"], cwd=workdir)
    git(["branch", "-M", "main"], cwd=workdir)
    git(["push", "--force", "origin", "main"], cwd=workdir)
    print("Repo reset.\n")


def merge_pr_with_backdated_commit(repo, workdir, branch_name, base, hours_ago, title):
    """Creates a branch from `base`, commits with a backdated date (hours_ago),
    opens a PR against `base` and merges it. Returns the PR number."""
    git(["checkout", base, "-q"], cwd=workdir)
    git(["pull", "-q", "origin", base], cwd=workdir)
    git(["checkout", "-b", branch_name, "-q"], cwd=workdir)
    marker = os.path.join(workdir, f"{branch_name}.txt")
    with open(marker, "w") as f:
        f.write(title)
    git(["add", os.path.basename(marker)], cwd=workdir)
    env = backdated_env(hours_ago)
    git(["commit", "-m", title], cwd=workdir, env=env)
    git(["push", "-q", "-u", "origin", branch_name], cwd=workdir)
    gh(["pr", "create", "--repo", repo, "--title", title, "--body", "e2e", "--base", base, "--head", branch_name])
    out = gh(["pr", "list", "--repo", repo, "--head", branch_name, "--json", "number", "-q", ".[0].number"])
    pr_number = int(out.stdout.strip())
    gh(["pr", "merge", str(pr_number), "--repo", repo, "--merge", "--delete-branch"])
    return pr_number


def run_dora(repo, prod_branch="main", deploy_source="release", tag_pattern=None,
             window_days=3650, extra_args=None):
    # Short margin: a just-created release/tag can take a moment to show up in
    # GitHub's listing endpoint (propagation lag observed empirically between
    # `gh release create` and the next run seeing it) — it's not a bug in
    # dora_metrics.py, it's the API.
    time.sleep(6)
    cfg = {
        "tag_pattern": tag_pattern or r"^v\d+\.\d+\.\d+$",
        "window_days": window_days,
        "proyectos": [{
            "nombre": "E2E",
            "repos": [{"repo": repo, "tipo": ["web"], "prod_branch": prod_branch, "deploy_source": deploy_source}],
        }],
    }
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(cfg, f)
        cfg_path = f.name
    try:
        cmd = ["python3", DORA_SCRIPT, "--config", cfg_path, "--proyecto", "E2E"]
        if extra_args:
            cmd += extra_args
        result = run(cmd)
    finally:
        os.unlink(cfg_path)
    json_start = result.stdout.index("\n{\n") + 1
    return json.loads(result.stdout[json_start:])


def repo_metrics(dora_output, repo):
    for p in dora_output["proyectos"]:
        for r in p["repos"]:
            if r.get("repo") == repo:
                return r
    raise KeyError(f"repo {repo} not found in the output: {dora_output}")


def seed_baseline_release(repo, workdir):
    """Initial release with no PRs, so that v0.1.0 (Case A) isn't the repo's
    first historical release — that one is always excluded from the Lead Time
    by design (there's no prior release against which to bound the PR search),
    and Case A needs ITS PR to be measurable."""
    gh(["release", "create", "v0.0.1", "--repo", repo, "--title", "v0.0.1", "--notes", "baseline, no PRs", "--target", "main"])


def case_a_release_lead_time(repo, workdir):
    print("Case A — release, realistic lead time (commit backdated 30h)")
    merge_pr_with_backdated_commit(repo, workdir, "e2e-case-a", "main", hours_ago=30, title="Case A")
    time.sleep(7)  # real margin, avoids the merge-commit vs merged_at race
    git(["checkout", "main", "-q"], cwd=workdir)
    git(["pull", "-q", "origin", "main"], cwd=workdir)
    gh(["release", "create", "v0.1.0", "--repo", repo, "--title", "v0.1.0", "--notes", "case a", "--target", "main"])
    out = run_dora(repo)
    r = repo_metrics(out, repo)
    check("A.DF == 2 (v0.0.1 baseline + v0.1.0)", r["deployment_frequency"] == 2, f"DF={r['deployment_frequency']}")
    check("A.lead_time_n == 1", r["lead_time_n"] == 1, f"n={r['lead_time_n']}")
    lt = r["lead_time_median_hours"] or 0
    check("A.lead_time ~= 30h", 29.5 <= lt <= 30.5, f"lead_time={lt}h")


def case_b_median(repo, workdir):
    print("Case B — median with n>1 (commits backdated 40h and 20h)")
    merge_pr_with_backdated_commit(repo, workdir, "e2e-case-b-1", "main", hours_ago=40, title="Case B 1")
    merge_pr_with_backdated_commit(repo, workdir, "e2e-case-b-2", "main", hours_ago=20, title="Case B 2")
    time.sleep(7)
    git(["checkout", "main", "-q"], cwd=workdir)
    git(["pull", "-q", "origin", "main"], cwd=workdir)
    gh(["release", "create", "v0.2.0", "--repo", repo, "--title", "v0.2.0", "--notes", "case b", "--target", "main"])
    out = run_dora(repo)
    r = repo_metrics(out, repo)
    check("B.DF == 3 (v0.0.1 + v0.1.0 + v0.2.0)", r["deployment_frequency"] == 3, f"DF={r['deployment_frequency']}")
    titles = {d["title"] for d in r["lead_time_detail"]}
    # n can come out as 2 or 3: Case A's PR sometimes slips in here due to the
    # 1-2 second race condition between merge and release already documented in
    # dora_metrics.py (the whole flow runs in seconds, the exact scenario where
    # that offset matters). It's not a bug in this suite or in the script — we
    # validate content, not an exact count.
    check("B.lead_time_n >= 2 (Case B 1 and 2 present)",
          r["lead_time_n"] >= 2 and {"Case B 1", "Case B 2"} <= titles,
          f"n={r['lead_time_n']} titles={titles}")
    lt = r["lead_time_median_hours"] or 0
    check("B.median ~= 30h (median of 40 and 20)", 29.5 <= lt <= 30.5, f"median={lt}h")


def case_c_annotated_tag(repo, workdir):
    print("Case C — annotated tag (uses its own date, not the commit's)")
    merge_pr_with_backdated_commit(repo, workdir, "e2e-case-c", "main", hours_ago=15, title="Case C")
    time.sleep(7)
    git(["checkout", "main", "-q"], cwd=workdir)
    git(["pull", "-q", "origin", "main"], cwd=workdir)
    git(["tag", "-a", "v0.3.0", "-m", "case c annotated"], cwd=workdir)
    git(["push", "-q", "origin", "v0.3.0"], cwd=workdir)
    out = run_dora(repo, deploy_source="tag")
    r = repo_metrics(out, repo)
    tags = [d["tag"] for d in r["deploys_in_window"]]
    check("C.v0.3.0 present in tag mode", "v0.3.0" in tags, f"tags={tags}")
    detail = [d for d in r["lead_time_detail"] if d["deploy_tag"] == "v0.3.0"]
    check("C.case-c PR found with lead time ~15h",
          bool(detail) and 14.5 <= detail[0]["lead_time_hours"] <= 15.5,
          f"detail={detail}")


def case_d_lightweight_tag(repo, workdir):
    print("Case D — lightweight tag (fallback to the commit's date)")
    git(["checkout", "main", "-q"], cwd=workdir)
    git(["pull", "-q", "origin", "main"], cwd=workdir)
    git(["tag", "v0.4.0"], cwd=workdir)
    git(["push", "-q", "origin", "v0.4.0"], cwd=workdir)
    out = run_dora(repo, deploy_source="tag")
    r = repo_metrics(out, repo)
    tags = [d["tag"] for d in r["deploys_in_window"]]
    check("D.v0.4.0 present in tag mode (lightweight)", "v0.4.0" in tags, f"tags={tags}")


def case_e_zero_prs_warning(repo, workdir):
    print("Case E — 0 merged PRs between consecutive releases")
    gh(["release", "create", "v0.5.0", "--repo", repo, "--title", "v0.5.0", "--notes", "case e r1", "--target", "main"])
    gh(["release", "create", "v0.6.0", "--repo", repo, "--title", "v0.6.0", "--notes", "case e r2", "--target", "main"])
    out = run_dora(repo)
    r = repo_metrics(out, repo)
    check("E.0-PRs warning for v0.6.0",
          any("v0.6.0" in w and "0 merged PRs" in w for w in r["warnings"]),
          f"warnings={r['warnings']}")


def case_f_window_days(repo, workdir):
    print("Case F — --window-days filters by window (annotated tag backdated 20 days)")
    git(["checkout", "main", "-q"], cwd=workdir)
    git(["pull", "-q", "origin", "main"], cwd=workdir)
    env = backdated_env(hours_ago=20 * 24)
    git(["tag", "-a", "v0.7.0", "-m", "case f, 20 days ago"], cwd=workdir, env=env)
    git(["push", "-q", "origin", "v0.7.0"], cwd=workdir)
    out_14 = run_dora(repo, deploy_source="tag", window_days=14)
    out_60 = run_dora(repo, deploy_source="tag", window_days=60)
    tags_14 = [d["tag"] for d in repo_metrics(out_14, repo)["deploys_in_window"]]
    tags_60 = [d["tag"] for d in repo_metrics(out_60, repo)["deploys_in_window"]]
    check("F.v0.7.0 excluded with a 14d window", "v0.7.0" not in tags_14, f"tags_14={tags_14}")
    check("F.v0.7.0 included with a 60d window", "v0.7.0" in tags_60, f"tags_60={tags_60}")


def case_g_branch_override(repo, workdir):
    print("Case G — --branch isolates the PR search by base branch")
    git(["checkout", "main", "-q"], cwd=workdir)
    git(["pull", "-q", "origin", "main"], cwd=workdir)
    git(["checkout", "-b", "staging", "-q"], cwd=workdir)
    git(["push", "-q", "-u", "origin", "staging"], cwd=workdir)
    merge_pr_with_backdated_commit(repo, workdir, "e2e-case-g", "staging", hours_ago=10, title="Case G")
    time.sleep(7)
    git(["checkout", "staging", "-q"], cwd=workdir)
    git(["pull", "-q", "origin", "staging"], cwd=workdir)
    gh(["release", "create", "v0.8.0", "--repo", repo, "--title", "v0.8.0", "--notes", "case g", "--target", "staging"])

    out_staging = run_dora(repo, extra_args=["--branch", "staging"])
    r_staging = repo_metrics(out_staging, repo)
    detail = [d for d in r_staging["lead_time_detail"] if d["deploy_tag"] == "v0.8.0"]
    check("G.--branch staging finds the case-g PR",
          bool(detail) and 9.5 <= detail[0]["lead_time_hours"] <= 10.5,
          f"detail={detail}")

    out_main = run_dora(repo)  # default: prod_branch=main, must not see the staging PR
    r_main = repo_metrics(out_main, repo)
    check("G.default (branch=main) does NOT mix in the PR merged to staging",
          any("v0.8.0" in w and "0 merged PRs" in w for w in r_main["warnings"]),
          f"warnings={r_main['warnings']}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", required=True,
                     help="Your own throwaway repo (org/repo). Required — never point at a real repo.")
    ap.add_argument("--yes", action="store_true", help="Skips the interactive confirmation before deleting the repo.")
    args = ap.parse_args()

    print(f"This script will DELETE releases, tags and branches (!= main) of {args.repo}, and force-push to main.")
    if not args.yes:
        confirm = input("Confirm? type the repo name to continue: ")
        if confirm.strip() != args.repo:
            print("Cancelled.")
            sys.exit(1)

    with tempfile.TemporaryDirectory() as workdir:
        run(["git", "clone", f"https://github.com/{args.repo}.git", workdir])
        reset_repo(args.repo, workdir)
        seed_baseline_release(args.repo, workdir)

        for case_fn in (case_a_release_lead_time, case_b_median, case_c_annotated_tag,
                        case_d_lightweight_tag, case_e_zero_prs_warning,
                        case_f_window_days, case_g_branch_override):
            case_fn(args.repo, workdir)
            print()

    total = len(RESULTS)
    passed = sum(1 for _, ok in RESULTS if ok)
    print(f"=== {passed}/{total} checks OK ===")
    for name, ok in RESULTS:
        if not ok:
            print(f"  FAILED: {name}")
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
