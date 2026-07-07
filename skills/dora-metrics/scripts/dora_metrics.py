#!/usr/bin/env python3
"""
Fetching skill — DORA (Deployment Frequency + Lead Time for Changes)

Source: GitHub API (REST + Search), NOT local git — lead time depends on the
real first commit of each PR, something only the GitHub API guarantees
reliably regardless of the merge strategy (including squash).

Contract: it ONLY fetches and aggregates. It does not interpret or rank — that
is a later step, outside the scope of this skill.

Usage:
    export GITHUB_TOKEN=ghp_xxx   # or a token with 'repo' (read) scope for the org's repos
    python3 dora_metrics.py [--config config/proyectos.json] [--proyecto "Example Project"] [--out-dir outputs]
        [--branch branch] [--deploy-source release|tag] [--window-days N]

Deploy marker configurable per repo (the "deploy_source" field in the config,
default "release"): "release" uses GitHub Releases (tag_name matches
tag_pattern); "tag" uses plain git tags (without going through Releases),
resolving the date via the commit they point to, for projects that tag but
don't publish Releases.

Known limitation (deploy_source=tag, or release with a lightweight tag pointing
at the merge commit): the timestamp of that commit can differ by 1-2 seconds
from the `merged_at` that GitHub ends up persisting on the PR. Verified
empirically in E2E tests (see tests/e2e/) that this can fail in both
directions:
- Excluding a PR that was in fact merged within the window (the PR lands just
  outside the upper bound).
- Attributing a PR to the NEXT deploy interval instead of the one that actually
  included it (if the PR was merged 1-2 seconds after the previous deploy).
With real windows (days/weeks between deploys) this few-second offset never
gets close to mattering; it only reproduced in tests where the full flow
(tag/release → merge → next tag/release) was compressed into minutes. No
artificial margin is added for this case — the cost of guessing the "right"
margin isn't justified for a scenario that in production would only happen with
a CI pipeline that auto-tags on merge.

Requires: requests  (pip install requests --break-system-packages)
"""

import argparse
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
from datetime import datetime, timedelta, timezone

import requests

API_ROOT = "https://api.github.com"


def get_github_token():
    """Precedence order: 1) GITHUB_TOKEN env var, 2) `gh auth token`
    (if the GitHub CLI is installed and logged in locally). This way anyone on
    the team who already uses `gh` day to day can run this skill without
    generating or pasting a new token anywhere."""
    env_token = os.environ.get("GITHUB_TOKEN")
    if env_token:
        return env_token
    if shutil.which("gh"):
        try:
            out = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True, timeout=10)
            token = out.stdout.strip()
            if out.returncode == 0 and token:
                return token
        except Exception:
            pass
    return None


class GitHubError(Exception):
    pass


def gh_session(token: str) -> requests.Session:
    s = requests.Session()
    s.headers.update({
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    return s


def gh_paginate(session: requests.Session, url: str, params: dict = None):
    """GET with pagination via the Link header. Yields items from each page."""
    params = dict(params or {})
    params.setdefault("per_page", 100)
    next_url = url
    next_params = params
    while next_url:
        resp = session.get(next_url, params=next_params)
        if resp.status_code == 401:
            raise GitHubError(
                "401 Unauthorized. Check that GITHUB_TOKEN is valid and has "
                "access to ALL the orgs of the project's repos (if multi-org)."
            )
        if resp.status_code == 403 and "rate limit" in resp.text.lower():
            raise GitHubError(f"Rate limit reached: {resp.text[:300]}")
        if resp.status_code == 404:
            raise GitHubError(f"404 Not Found at {next_url} — does the repo exist and does the token have access?")
        if not resp.ok:
            raise GitHubError(f"GitHub API error {resp.status_code} at {next_url}: {resp.text[:300]}")
        data = resp.json()
        items = data.get("items", data) if isinstance(data, dict) else data
        for item in items:
            yield item
        next_url = None
        next_params = None
        if "next" in resp.links:
            next_url = resp.links["next"]["url"]


def parse_ts(s: str) -> datetime:
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def fmt_ts(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def get_prod_releases(session: requests.Session, repo: str, tag_pattern: str):
    """Published Releases (not draft) whose tag matches tag_pattern, ascending order."""
    pattern = re.compile(tag_pattern)
    releases = []
    for r in gh_paginate(session, f"{API_ROOT}/repos/{repo}/releases"):
        if r.get("draft"):
            continue
        tag = r.get("tag_name", "")
        if not pattern.match(tag):
            continue
        published = r.get("published_at") or r.get("created_at")
        if not published:
            continue
        releases.append({"tag": tag, "published_at": parse_ts(published), "url": r.get("html_url")})
    releases.sort(key=lambda x: x["published_at"])
    return releases


def get_prod_tags(session: requests.Session, repo: str, tag_pattern: str):
    """Tags (without a Release) whose name matches tag_pattern, ascending order.

    Distinguishes an annotated tag from a lightweight one via the Git Data API:
    an annotated tag has its own object with a "tagging" date (tagger.date) —
    the signal closest to "when this was marked as a deploy", which can be quite
    a bit later than when the code was written. Using the underlying commit's
    date directly (as we did before) lost that distinction. A lightweight tag
    has no object of its own, so it falls back to the commit's date."""
    pattern = re.compile(tag_pattern)
    tag_names = [t.get("name", "") for t in gh_paginate(session, f"{API_ROOT}/repos/{repo}/tags")]
    tags = []
    for name in tag_names:
        if not pattern.match(name):
            continue
        ref_resp = session.get(f"{API_ROOT}/repos/{repo}/git/ref/tags/{name}")
        if not ref_resp.ok:
            continue
        obj = ref_resp.json().get("object", {})
        obj_sha = obj.get("sha")
        if obj.get("type") == "tag":
            tag_resp = session.get(f"{API_ROOT}/repos/{repo}/git/tags/{obj_sha}")
            if not tag_resp.ok:
                continue
            tag_data = tag_resp.json()
            date_str = (tag_data.get("tagger") or {}).get("date")
            if not date_str:
                continue
            tags.append({"tag": name, "published_at": parse_ts(date_str), "url": tag_data.get("object", {}).get("url")})
        else:
            commit_resp = session.get(f"{API_ROOT}/repos/{repo}/commits/{obj_sha}")
            if not commit_resp.ok:
                continue
            commit_data = commit_resp.json()
            commit_info = commit_data.get("commit", {})
            date_str = (commit_info.get("committer") or {}).get("date") or (commit_info.get("author") or {}).get("date")
            if not date_str:
                continue
            tags.append({"tag": name, "published_at": parse_ts(date_str), "url": commit_data.get("html_url")})
    tags.sort(key=lambda x: x["published_at"])
    return tags


def get_pr_first_commit_ts(session: requests.Session, repo: str, pr_number: int):
    """Timestamp of the PR's first commit (via the PR object, not the git log of
    main — this stays correct even if the merge to main was a squash)."""
    commits = list(gh_paginate(session, f"{API_ROOT}/repos/{repo}/pulls/{pr_number}/commits"))
    if not commits:
        return None
    dates = []
    for c in commits:
        commit_info = c.get("commit", {})
        author_date = (commit_info.get("author") or {}).get("date")
        committer_date = (commit_info.get("committer") or {}).get("date")
        d = author_date or committer_date
        if d:
            dates.append(parse_ts(d))
    if not dates:
        return None
    return min(dates)


def get_merged_prs_between(session: requests.Session, repo: str, branch: str, start: datetime, end: datetime):
    """PRs merged to `branch` in (start, end], via the Search API (search/issues),
    regardless of the merge strategy (squash/merge commit/rebase)."""
    start_s = fmt_ts(start)
    end_s = fmt_ts(end)
    q = f"repo:{repo} is:pr is:merged base:{branch} merged:{start_s}..{end_s}"
    prs = []
    for item in gh_paginate(session, f"{API_ROOT}/search/issues", params={"q": q}):
        prs.append({"number": item["number"], "title": item.get("title", "")})
    return prs


VALID_DEPLOY_SOURCES = ("release", "tag")


def compute_repo_metrics(session: requests.Session, repo: str, branch: str,
                          tag_pattern: str, window_days: int, now: datetime,
                          deploy_source: str = "release"):
    warnings = []
    window_start = now - timedelta(days=window_days)

    if deploy_source == "tag":
        all_deploys = get_prod_tags(session, repo, tag_pattern)
        marker_label = "Tag"
    else:
        all_deploys = get_prod_releases(session, repo, tag_pattern)
        marker_label = "Release"
    deploys_in_window = [d for d in all_deploys if window_start <= d["published_at"] <= now]
    tag_to_idx = {d["tag"]: i for i, d in enumerate(all_deploys)}

    # DF stays an integer count (0 included): "0 deploys in the window" is a
    # real, measurable value, not a "not applicable" (same criterion that
    # minister:dora-metrics uses for its own deployment_frequency).
    deployment_frequency = len(deploys_in_window)

    lead_times_hours = []
    lt_detail = []
    for dep in deploys_in_window:
        idx = tag_to_idx[dep["tag"]]
        if idx == 0:
            warnings.append(
                f"{marker_label} {dep['tag']} has no known prior {marker_label.lower()} — "
                "the PR population can't be bounded, it's excluded from the Lead Time."
            )
            continue
        prev_dep = all_deploys[idx - 1]
        prs = get_merged_prs_between(session, repo, branch, prev_dep["published_at"], dep["published_at"])
        if not prs:
            warnings.append(f"{marker_label} {dep['tag']}: 0 merged PRs found in the range — check the base branch/convention.")
            continue
        for pr in prs:
            first_commit_ts = get_pr_first_commit_ts(session, repo, pr["number"])
            if first_commit_ts is None:
                warnings.append(f"PR #{pr['number']}: could not fetch the first commit, it's excluded.")
                continue
            lead_time_h = (dep["published_at"] - first_commit_ts).total_seconds() / 3600
            lead_times_hours.append(lead_time_h)
            lt_detail.append({
                "pr": pr["number"],
                "title": pr["title"],
                "deploy_tag": dep["tag"],
                "first_commit_ts": fmt_ts(first_commit_ts),
                "deploy_ts": fmt_ts(dep["published_at"]),
                "lead_time_hours": round(lead_time_h, 1),
            })

    # None (not 0) when there are no computable lead times: "no measurable
    # deploys in the window" is not the same as "lead time of 0 hours" —
    # confusing the two would classify a window with no signal as if it were an
    # instant delivery.
    lead_time_median_hours = round(statistics.median(lead_times_hours), 1) if lead_times_hours else None

    return {
        "repo": repo,
        "prod_branch": branch,
        "deploy_source": deploy_source,
        "window_start": fmt_ts(window_start),
        "window_end": fmt_ts(now),
        "deployment_frequency": deployment_frequency,
        "deploys_in_window": [{"tag": d["tag"], "published_at": fmt_ts(d["published_at"]), "url": d["url"]} for d in deploys_in_window],
        "lead_time_median_hours": lead_time_median_hours,
        "lead_time_n": len(lead_times_hours),
        "lead_time_detail": lt_detail,
        "warnings": warnings,
    }


def _positive_int(value: str) -> int:
    try:
        ivalue = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"must be a positive integer, got {value!r}") from exc
    if ivalue < 1:
        raise argparse.ArgumentTypeError(f"must be >= 1, got {ivalue}")
    return ivalue


def validate_scoped_overrides(args) -> None:
    """--branch and --deploy-source are one-off overrides of a SINGLE project;
    it makes no sense to apply them to all if --proyecto isn't specified.
    Separated from main() so the validation can be tested without invoking the CLI."""
    if args.branch and not args.proyecto:
        raise ValueError("--branch requires --proyecto (the override is one-off, it isn't applied to all projects).")
    if args.deploy_source and not args.proyecto:
        raise ValueError("--deploy-source requires --proyecto (the override is one-off, it isn't applied to all projects).")


def validate_deploy_sources(proyectos) -> None:
    """Validates that each repo's deploy_source is one of the supported values.
    Separated from main() so the validation can be tested without touching the real config."""
    for proyecto in proyectos:
        for repo_cfg in proyecto["repos"]:
            ds = repo_cfg.get("deploy_source", "release")
            if ds not in VALID_DEPLOY_SOURCES:
                raise ValueError(
                    f"invalid deploy_source '{ds}' in repo {repo_cfg['repo']} "
                    f"(valid: {', '.join(VALID_DEPLOY_SOURCES)})."
                )


def main():
    ap = argparse.ArgumentParser(description="DORA fetching (Deployment Frequency + Lead Time) from the GitHub API.")
    ap.add_argument("--config", default=os.path.join(os.path.dirname(__file__), "..", "config", "proyectos.json"))
    ap.add_argument("--proyecto", default=None, help="Project name to run (default: all projects in the config).")
    ap.add_argument("--out-dir", default=None, help="Folder where the output JSON is saved (default: doesn't save, stdout only).")
    ap.add_argument("--branch", default=None, help="One-off override of prod_branch for this run (requires --proyecto). Doesn't modify the config.")
    ap.add_argument("--deploy-source", default=None, choices=list(VALID_DEPLOY_SOURCES),
                     help="One-off override of deploy_source for this run (requires --proyecto). Doesn't modify the config.")
    ap.add_argument("--window-days", type=_positive_int, default=None,
                     help="One-off override of window_days for this run. Doesn't modify the config.")
    args = ap.parse_args()

    try:
        validate_scoped_overrides(args)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    token = get_github_token()
    if not token:
        print(
            "ERROR: no GitHub credential found.\n"
            "  Option 1: export GITHUB_TOKEN=ghp_xxxx\n"
            "  Option 2: run `gh auth login` once (if you have the GitHub CLI "
            "installed) — the script detects it on its own, nothing to export.",
            file=sys.stderr,
        )
        sys.exit(1)

    with open(args.config, "r") as f:
        config = json.load(f)

    tag_pattern = config["tag_pattern"]
    window_days = args.window_days if args.window_days is not None else config["window_days"]
    proyectos = config["proyectos"]
    if args.proyecto:
        proyectos = [p for p in proyectos if p["nombre"].lower() == args.proyecto.lower()]
        if not proyectos:
            print(f"ERROR: project '{args.proyecto}' is not in {args.config}.", file=sys.stderr)
            sys.exit(1)
        if args.branch:
            for repo_cfg in proyectos[0]["repos"]:
                repo_cfg["prod_branch"] = args.branch
        if args.deploy_source:
            for repo_cfg in proyectos[0]["repos"]:
                repo_cfg["deploy_source"] = args.deploy_source

    try:
        validate_deploy_sources(proyectos)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    session = gh_session(token)
    now = datetime.now(timezone.utc)

    result = {
        "generated_at": fmt_ts(now),
        "window_days": window_days,
        "tag_pattern": tag_pattern,
        "proyectos": [],
    }

    for proyecto in proyectos:
        repos_result = []
        for repo_cfg in proyecto["repos"]:
            try:
                repo_tag_pattern = repo_cfg.get("tag_pattern", tag_pattern)
                deploy_source = repo_cfg.get("deploy_source", "release")
                r = compute_repo_metrics(
                    session, repo_cfg["repo"], repo_cfg["prod_branch"], repo_tag_pattern, window_days, now,
                    deploy_source=deploy_source,
                )
                r["tipo"] = repo_cfg.get("tipo", [])
            except (GitHubError, requests.exceptions.RequestException) as e:
                r = {"repo": repo_cfg["repo"], "error": str(e)}
            repos_result.append(r)
        result["proyectos"].append({"nombre": proyecto["nombre"], "repos": repos_result})

    output_json = json.dumps(result, indent=2, ensure_ascii=False)

    if args.out_dir:
        os.makedirs(args.out_dir, exist_ok=True)
        fname = os.path.join(args.out_dir, f"{now.strftime('%Y-%m-%d')}_dora.json")
        with open(fname, "w") as f:
            f.write(output_json)
        print(f"Output saved to {fname}\n")

    # Human-readable summary — it ONLY fetches and reports, does not interpret.
    for p in result["proyectos"]:
        print(f"=== {p['nombre']} ===")
        for r in p["repos"]:
            if "error" in r:
                print(f"  [{r['repo']}] ERROR: {r['error']}")
                continue
            print(f"  [{r['repo']}] ({', '.join(r.get('tipo', []))}) [deploy_source: {r.get('deploy_source', 'release')}]")
            print(f"    Deployment Frequency (window {window_days}d): {r['deployment_frequency']}")
            if r["lead_time_median_hours"] is not None:
                print(f"    Median Lead Time: {r['lead_time_median_hours']}h  (n={r['lead_time_n']})")
            else:
                print("    Median Lead Time: no data in the window")
            for w in r["warnings"]:
                print(f"    ! {w}")
        print()

    print(output_json)


if __name__ == "__main__":
    main()
