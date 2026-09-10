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
    python3 dora_metrics.py [--config config/projects.json] [--project "Example Project"] [--out-dir reports]
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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import troubleshooting  # noqa: E402  (sibling module, loaded by path so the script stays runnable from anywhere)

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


def _is_rate_limited(resp) -> bool:
    return resp.status_code == 403 and "rate limit" in (resp.text or "").lower()


def preflight_repo(session: requests.Session, repo: str, branch: str) -> list:
    """Checks, before measuring, the two things whose absence would otherwise
    produce a silent or misleading result: that the credential can see the repo
    at all, and that the configured production branch exists. Two cheap REST
    calls per repo (not Search, which is the rate-limited API).

    A returned issue with impact "blocked" means the repo cannot be measured;
    the caller skips it and keeps going with the rest of the project."""
    issues = []

    resp = session.get(f"{API_ROOT}/repos/{repo}")
    if resp.status_code == 401:
        return [make_issue("token_unauthorized", "blocked",
                           f"{repo}: 401 Unauthorized from the GitHub API — the credential is not valid for this repo.")]
    if _is_rate_limited(resp):
        return [make_issue("rate_limited", "blocked",
                           f"{repo}: GitHub API rate limit reached — it could not be measured in this run.")]
    if resp.status_code in (403, 404):
        return [make_issue("repo_unreachable", "blocked",
                           f"{repo}: the GitHub API returned {resp.status_code} — the repo is unreachable with this "
                           "credential, it could not be measured.",
                           evidence={"status": resp.status_code})]
    if resp.status_code != 200:
        return [make_issue("github_api_error", "blocked",
                           f"{repo}: GitHub API error {resp.status_code} on /repos/{repo}: {(resp.text or '')[:300]}",
                           evidence={"status": resp.status_code})]

    branch_resp = session.get(f"{API_ROOT}/repos/{repo}/branches/{branch}")
    if branch_resp.status_code == 404:
        issues.append(make_issue(
            "branch_not_found", "partial",
            f"{repo}: branch '{branch}' does not exist — Lead Time can't be measured against it "
            "(Deployment Frequency is unaffected).",
            evidence={"prod_branch": branch},
        ))
    elif _is_rate_limited(branch_resp):
        issues.append(make_issue(
            "rate_limited", "partial",
            f"{repo}: GitHub API rate limit reached while checking branch '{branch}' — its existence "
            "could not be verified.",
            evidence={"prod_branch": branch},
        ))
    elif branch_resp.status_code != 200:
        issues.append(make_issue(
            "github_api_error", "partial",
            f"{repo}: GitHub API error {branch_resp.status_code} checking branch '{branch}' — its "
            f"existence could not be verified: {(branch_resp.text or '')[:300]}",
            evidence={"status": branch_resp.status_code, "prod_branch": branch},
        ))
    return issues


EVIDENCE_SAMPLE_SIZE = 5


def get_release_tag_names(session: requests.Session, repo: str) -> dict:
    """Tag names of every Release in the repo, split by draft state. Used only
    to explain an empty result — the measurement itself goes through
    get_prod_releases."""
    published, draft = [], []
    for r in gh_paginate(session, f"{API_ROOT}/repos/{repo}/releases"):
        name = r.get("tag_name", "")
        if not name:
            continue
        (draft if r.get("draft") else published).append(name)
    return {"published": published, "draft": draft}


def get_all_tag_names(session: requests.Session, repo: str) -> list:
    """Every git tag name in the repo, unfiltered."""
    return [t.get("name", "") for t in gh_paginate(session, f"{API_ROOT}/repos/{repo}/tags") if t.get("name")]


def diagnose_markers(session: requests.Session, repo: str, tag_pattern: str, deploy_source: str,
                     markers_total: int, deployment_frequency: int, latest_marker_at: str) -> list:
    """Explains a deploy count of 0 instead of leaving it mute — the difference
    between 'they didn't deploy' and 'the repo isn't instrumented' is invisible
    in the number alone, and only the second one is fixable.

    Costs nothing when markers were found inside the window: the extra API calls
    run only on the paths that need evidence."""
    if markers_total > 0:
        if deployment_frequency == 0:
            return [make_issue(
                "no_markers_in_window", "none",
                f"{repo}: 0 deploys in the window. {markers_total} deploy marker(s) exist in history, "
                f"the most recent on {latest_marker_at}.",
                evidence={"markers_total": markers_total, "latest_marker_at": latest_marker_at},
            )]
        return []

    issues = []
    pattern = re.compile(tag_pattern)
    releases = get_release_tag_names(session, repo)
    tag_names = get_all_tag_names(session, repo)

    if deploy_source == "tag":
        own_names, own_label = tag_names, "tags"
        other_names, other_label = releases["published"], "published Releases"
    else:
        own_names, own_label = releases["published"], "published Releases"
        other_names, other_label = tag_names, "tags"

    if not own_names:
        issues.append(make_issue(
            "no_markers_at_all", "partial",
            f"{repo}: no {own_label} at all — there is no deploy marker to count.",
            evidence={"deploy_source": deploy_source},
        ))
    else:
        issues.append(make_issue(
            "no_markers_matching_pattern", "partial",
            f"{repo}: {len(own_names)} {own_label} found, none matching tag_pattern "
            f"'{tag_pattern}' — no deploy marker was counted.",
            evidence={"tag_pattern": tag_pattern,
                      "names_found": own_names[:EVIDENCE_SAMPLE_SIZE],
                      "names_total": len(own_names)},
        ))

    if deploy_source == "release":
        matching_drafts = [n for n in releases["draft"] if pattern.match(n)]
        if matching_drafts:
            issues.append(make_issue(
                "matching_releases_all_draft", "partial",
                f"{repo}: {len(matching_drafts)} Release(s) matching tag_pattern exist but are all drafts — "
                "drafts are not counted as deploys.",
                evidence={"draft_tags": matching_drafts[:EVIDENCE_SAMPLE_SIZE]},
            ))

    matching_other = [n for n in other_names if pattern.match(n)]
    if matching_other:
        issues.append(make_issue(
            "deploy_source_mismatch", "partial",
            f"{repo}: deploy_source is '{deploy_source}' and nothing matched, but {len(matching_other)} "
            f"{other_label} matching tag_pattern do exist.",
            evidence={"deploy_source": deploy_source,
                      "matching_other_source": matching_other[:EVIDENCE_SAMPLE_SIZE]},
        ))
    return issues


VALID_DEPLOY_SOURCES = ("release", "tag")


# --- Issue model -----------------------------------------------------------
# Every problem the script reports is an "issue" with a stable code. The code is
# what links it to its remediation steps in references/troubleshooting.md, so
# the steps travel inside the report instead of being matched by text at render
# time. "impact" describes whether the MEASUREMENT succeeded, never whether a
# number is good: blocked = nothing measurable at that level, partial = measured
# with a declared gap, none = a factual note with nothing to fix.
ISSUE_IMPACTS = ("blocked", "partial", "none")

ISSUE_CODES = (
    "no_credential",
    "repo_unreachable",
    "token_unauthorized",
    "rate_limited",
    "branch_not_found",
    "no_markers_at_all",
    "no_markers_matching_pattern",
    "deploy_source_mismatch",
    "matching_releases_all_draft",
    "no_markers_in_window",
    "first_marker_no_prior",
    "no_prs_in_range",
    "pr_first_commit_unfetchable",
    "github_api_error",
)

# Codes with no entry in troubleshooting.md, on purpose. github_api_error is a
# catch-all for unexpected API failures: there is no fixed remediation, so the
# report shows the raw message. Kept as an explicit list so the drift test can
# tell "deliberate exception" from "someone forgot to document a code".
NO_GUIDANCE_CODES = ("github_api_error",)


def make_issue(code: str, impact: str, message: str, evidence: dict = None) -> dict:
    """Builds one issue. `guidance` is filled in later by hydrate_issues, never
    here — the script must never carry remediation prose of its own."""
    if code not in ISSUE_CODES:
        raise ValueError(f"unknown issue code '{code}' (add it to ISSUE_CODES and to references/troubleshooting.md).")
    if impact not in ISSUE_IMPACTS:
        raise ValueError(f"unknown impact '{impact}' (valid: {', '.join(ISSUE_IMPACTS)}).")
    return {"code": code, "impact": impact, "message": message, "evidence": evidence or {}, "guidance": None}


def iter_issues(result: dict):
    """Yields every issue in the result: root-level ones (global problems, not
    tied to a repo) and each repo's."""
    for issue in result.get("issues", []):
        yield issue
    for project in result.get("projects", []):
        for repo in project.get("repos", []):
            for issue in repo.get("issues", []):
                yield issue


def hydrate_issues(result: dict, guidance: dict) -> None:
    """Attaches the What / How to check / Where to fix steps to each issue, in
    place. A code with no entry keeps guidance=None and the renderer says so
    explicitly — it never invents steps."""
    for issue in iter_issues(result):
        issue["guidance"] = guidance.get(issue["code"])


def has_blocked(result: dict) -> bool:
    return any(i["impact"] == "blocked" for i in iter_issues(result))


def compute_repo_metrics(session: requests.Session, repo: str, branch: str,
                          tag_pattern: str, window_days: int, now: datetime,
                          deploy_source: str = "release"):
    issues = []
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
            issues.append(make_issue(
                "first_marker_no_prior", "partial",
                f"{marker_label} {dep['tag']} has no known prior {marker_label.lower()} — "
                "the PR population can't be bounded, it's excluded from the Lead Time.",
                evidence={"tag": dep["tag"], "deploy_source": deploy_source},
            ))
            continue
        prev_dep = all_deploys[idx - 1]
        prs = get_merged_prs_between(session, repo, branch, prev_dep["published_at"], dep["published_at"])
        if not prs:
            issues.append(make_issue(
                "no_prs_in_range", "partial",
                f"{marker_label} {dep['tag']}: 0 merged PRs found in the range — check the base branch/convention.",
                evidence={"tag": dep["tag"], "prev_tag": prev_dep["tag"], "prod_branch": branch},
            ))
            continue
        for pr in prs:
            first_commit_ts = get_pr_first_commit_ts(session, repo, pr["number"])
            if first_commit_ts is None:
                issues.append(make_issue(
                    "pr_first_commit_unfetchable", "partial",
                    f"PR #{pr['number']}: could not fetch the first commit, it's excluded.",
                    evidence={"pr": pr["number"], "tag": dep["tag"]},
                ))
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
        "markers_total": len(all_deploys),
        "latest_marker_at": fmt_ts(all_deploys[-1]["published_at"]) if all_deploys else None,
        "issues": issues,
        # Derived, kept for consumers that read the raw strings (the E2E suite
        # asserts on them). Issues with impact "none" are notes, not warnings.
        "warnings": [i["message"] for i in issues if i["impact"] != "none"],
    }


GUIDANCE_LABELS = (("what", "What"), ("how_to_check", "How to check"), ("where_to_fix", "Where to fix"))


def _render_issue(issue: dict, lines: list) -> None:
    """One issue: the raw message first, exactly as produced, then its steps.
    The message is never rewritten — an issue with no guidance says so out loud
    rather than getting invented steps."""
    lines.append(f"- {issue['message']}")
    guidance = issue.get("guidance")
    if not guidance:
        lines.append(f"  - _(no guidance for '{issue['code']}' in references/troubleshooting.md)_")
        return
    for key, label in GUIDANCE_LABELS:
        text = (guidance.get(key) or "").strip()
        if not text:
            continue
        _render_guidance_body(label, text, lines)


def _render_guidance_body(label: str, text: str, lines: list) -> None:
    """Guidance is authored as markdown: some fields are a paragraph, others a
    bullet list. A paragraph reads better collapsed onto the label's line; a
    list must keep its line breaks or the bullets run together into one
    sentence. Nested one level under the issue so it stays inside it."""
    raw = text.split("\n")
    if not any(ln.lstrip().startswith("- ") for ln in raw):
        lines.append(f"  - **{label}:** {' '.join(text.split())}")
        return
    lines.append(f"  - **{label}:**")
    for ln in raw:
        lines.append(f"    {ln.strip()}" if ln.strip() else "")


def _render_issue_groups(issues: list, lines: list) -> None:
    """Problems (blocked/partial) and notes (impact none) are separated on
    purpose: a note explains a number, it is not something to fix."""
    problems = [i for i in issues if i["impact"] != "none"]
    notes = [i for i in issues if i["impact"] == "none"]
    if problems:
        lines.append("**Problems found and how to fix them:**")
        lines.append("")
        for issue in problems:
            _render_issue(issue, lines)
        lines.append("")
    if notes:
        lines.append("**Notes:**")
        lines.append("")
        for issue in notes:
            _render_issue(issue, lines)
        lines.append("")


def format_human_summary(result: dict, window_days: int) -> str:
    """Renders the fetched data as a readable Markdown report — the same
    numbers printed to stdout, plus, for every problem found, the steps to fix
    it. Pure formatting: no interpretation, no ranking, no number and no
    guidance that isn't already in the result."""
    lines = []

    root_issues = result.get("issues", [])
    if root_issues:
        lines.append("# DORA Metrics")
        lines.append("")
        _render_issue_groups(root_issues, lines)

    for p in result["projects"]:
        lines.append(f"# DORA Metrics — {p['name']}")
        lines.append("")
        for r in p["repos"]:
            type_label = ", ".join(r.get("type", [])) or "unspecified"
            if not r.get("measured", True):
                lines.append(f"## `{r['repo']}` — not measured")
                lines.append("")
                _render_issue_groups(r.get("issues", []), lines)
                continue
            lines.append(f"## `{r['repo']}` ({type_label}) — deploy_source: {r.get('deploy_source', 'release')}")
            lines.append("")
            lines.append(f"- **Deployment Frequency** (window {window_days}d): {r['deployment_frequency']}")
            if r["lead_time_median_hours"] is not None:
                lines.append(f"- **Median Lead Time**: {r['lead_time_median_hours']}h (n={r['lead_time_n']})")
            else:
                lines.append("- **Median Lead Time**: no data in the window")
            lines.append("")
            _render_issue_groups(r.get("issues", []), lines)
    return "\n".join(lines).rstrip() + "\n"


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
    it makes no sense to apply them to all if --project isn't specified.
    Separated from main() so the validation can be tested without invoking the CLI."""
    if args.branch and not args.project:
        raise ValueError("--branch requires --project (the override is one-off, it isn't applied to all projects).")
    if args.deploy_source and not args.project:
        raise ValueError("--deploy-source requires --project (the override is one-off, it isn't applied to all projects).")


def validate_deploy_sources(projects) -> None:
    """Validates that each repo's deploy_source is one of the supported values.
    Separated from main() so the validation can be tested without touching the real config."""
    for project in projects:
        for repo_cfg in project["repos"]:
            ds = repo_cfg.get("deploy_source", "release")
            if ds not in VALID_DEPLOY_SOURCES:
                raise ValueError(
                    f"invalid deploy_source '{ds}' in repo {repo_cfg['repo']} "
                    f"(valid: {', '.join(VALID_DEPLOY_SOURCES)})."
                )


def classify_github_error(repo: str, message: str) -> dict:
    """Maps an exception raised mid-measurement onto a code, so an access
    problem reaches the report with steps instead of as raw text.

    Matches on the START of the message, never a substring search: the message
    embeds the request URL (and, for the generic shape, GitHub's response body),
    so a repo named `org/app-401` would otherwise be reported as an auth
    failure and its owner sent to reissue a perfectly good token. The prefixes
    below are the shapes gh_paginate raises."""
    if message.startswith("401"):
        return make_issue("token_unauthorized", "blocked",
                          f"{repo}: 401 Unauthorized from the GitHub API — the credential is not valid for this repo.")
    if message.startswith("Rate limit reached"):
        return make_issue("rate_limited", "blocked",
                          f"{repo}: GitHub API rate limit reached — it could not be measured in this run.")
    if message.startswith("404"):
        return make_issue("repo_unreachable", "blocked",
                          f"{repo}: the GitHub API returned 404 — the repo is unreachable with this credential, "
                          "it could not be measured.",
                          evidence={"status": 404})
    return make_issue("github_api_error", "blocked", f"{repo}: {message}")


def build_result(session, projects, tag_pattern: str, window_days: int, now: datetime) -> dict:
    """Measures every repo of every project. A repo that can't be measured
    contributes its problems to the report and the run continues with the next
    one — a broken access on one repo must not cost the numbers of the others."""
    result = {
        "generated_at": fmt_ts(now),
        "window_days": window_days,
        "tag_pattern": tag_pattern,
        "issues": [],       # global problems, not tied to a repo
        "projects": [],
    }

    for project in projects:
        repos_result = []
        for repo_cfg in project["repos"]:
            repo = repo_cfg["repo"]
            branch = repo_cfg["prod_branch"]
            repo_tag_pattern = repo_cfg.get("tag_pattern", tag_pattern)
            deploy_source = repo_cfg.get("deploy_source", "release")

            issues = preflight_repo(session, repo, branch)
            if any(i["impact"] == "blocked" for i in issues):
                repos_result.append({
                    "repo": repo, "prod_branch": branch, "deploy_source": deploy_source,
                    "type": repo_cfg.get("type", []), "measured": False,
                    "issues": issues, "warnings": [i["message"] for i in issues],
                })
                continue

            try:
                r = compute_repo_metrics(session, repo, branch, repo_tag_pattern, window_days, now,
                                          deploy_source=deploy_source)
                r["issues"] = issues + r["issues"] + diagnose_markers(
                    session, repo, repo_tag_pattern, deploy_source,
                    r["markers_total"], r["deployment_frequency"], r["latest_marker_at"],
                )
                r["warnings"] = [i["message"] for i in r["issues"] if i["impact"] != "none"]
                r["measured"] = True
                r["type"] = repo_cfg.get("type", [])
            except (GitHubError, requests.exceptions.RequestException) as e:
                issues = issues + [classify_github_error(repo, str(e))]
                r = {
                    "repo": repo, "prod_branch": branch, "deploy_source": deploy_source,
                    "type": repo_cfg.get("type", []), "measured": False,
                    "issues": issues, "warnings": [i["message"] for i in issues],
                }
            repos_result.append(r)
        result["projects"].append({"name": project["name"], "repos": repos_result})
    return result


def no_credential_result(now: datetime, window_days: int, tag_pattern: str) -> dict:
    """The run can't measure anything, but it still produces a report: the
    person who ran it ends up with a file stating what happened and how to fix
    it, instead of a stderr line that scrolls away."""
    return {
        "generated_at": fmt_ts(now),
        "window_days": window_days,
        "tag_pattern": tag_pattern,
        "issues": [make_issue("no_credential", "blocked",
                              "No GitHub credential found — nothing could be measured in this run.")],
        "projects": [],
    }


REPORT_TYPE = "dora-metrics"
NO_REPOS_SLUG = "no-repositories"


def slugify(raw: str) -> str:
    """Kebab-case slug safe for a file name: lowercase, separators collapsed to
    a single hyphen, everything else dropped."""
    slug = re.sub(r"[\s_./\\]+", "-", raw.lower())
    slug = re.sub(r"[^a-z0-9-]", "", slug)
    slug = re.sub(r"-+", "-", slug).strip("-")
    return slug or "project"


def repo_file_slugs(result: dict) -> dict:
    """Maps each `org/repo` to the slug used in its file name.

    The repo name alone is what identifies the report, so `org/api` becomes
    `api`. Two repos with the same name in different orgs would collide, so in
    that case — and only then — both fall back to the org-qualified slug.
    """
    full_names = [r["repo"] for p in result["projects"] for r in p["repos"]]
    grouped = {}
    for full in full_names:
        grouped.setdefault(slugify(full.split("/")[-1]), []).append(full)
    return {
        full: (short if len(collisions) == 1 else slugify(full))
        for short, collisions in grouped.items()
        for full in collisions
    }


def single_repo_result(result: dict, project: dict, repo: dict) -> dict:
    """Narrows `result` to one repo, keeping the run-level fields.

    Each saved file has to stand on its own — the window, the tag pattern and
    any run-level issue matter just as much when reading a single repo's
    numbers — so those are carried over rather than stripped.
    """
    narrowed = {k: v for k, v in result.items() if k != "projects"}
    narrowed["projects"] = [
        {**{k: v for k, v in project.items() if k != "repos"}, "repos": [repo]}
    ]
    return narrowed


def write_output(result: dict, window_days: int, out_dir: str, now: datetime) -> None:
    output_json = json.dumps(result, indent=2, ensure_ascii=False)
    summary = format_human_summary(result, window_days)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
        date = now.strftime("%Y-%m-%d")
        slugs = repo_file_slugs(result)
        bases = []

        # One pair of files per repo: a repo is the unit that gets measured
        # (never combined with its siblings), so it is also the unit that gets
        # saved and shared.
        for project in result["projects"]:
            for repo in project["repos"]:
                base = os.path.join(
                    out_dir, f"{date}-{slugs[repo['repo']]}-{REPORT_TYPE}"
                )
                per_repo = single_repo_result(result, project, repo)
                with open(f"{base}.json", "w") as f:
                    f.write(json.dumps(per_repo, indent=2, ensure_ascii=False))
                with open(f"{base}.md", "w") as f:
                    f.write(format_human_summary(per_repo, window_days))
                bases.append(base)

        if not bases:
            # Nothing measurable (no credential, empty config): still leave one
            # file behind stating what happened, instead of a stderr line that
            # scrolls away.
            base = os.path.join(out_dir, f"{date}-{NO_REPOS_SLUG}-{REPORT_TYPE}")
            with open(f"{base}.json", "w") as f:
                f.write(output_json)
            with open(f"{base}.md", "w") as f:
                f.write(summary)
            bases.append(base)

        print("Output saved to:")
        for base in bases:
            print(f"  {base}.json")
            print(f"  {base}.md")
        print()
    print(summary)
    print(output_json)


def main():
    ap = argparse.ArgumentParser(description="DORA fetching (Deployment Frequency + Lead Time) from the GitHub API.")
    ap.add_argument("--config", default=os.path.join(os.path.dirname(__file__), "..", "config", "projects.json"))
    ap.add_argument("--project", default=None, help="Project name to run (default: all projects in the config).")
    ap.add_argument("--out-dir", default=None, help="Folder where the output JSON is saved (default: doesn't save, stdout only).")
    ap.add_argument("--branch", default=None, help="One-off override of prod_branch for this run (requires --project). Doesn't modify the config.")
    ap.add_argument("--deploy-source", default=None, choices=list(VALID_DEPLOY_SOURCES),
                     help="One-off override of deploy_source for this run (requires --project). Doesn't modify the config.")
    ap.add_argument("--window-days", type=_positive_int, default=None,
                     help="One-off override of window_days for this run. Doesn't modify the config.")
    args = ap.parse_args()

    try:
        validate_scoped_overrides(args)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    guidance = troubleshooting.load_guidance(troubleshooting.default_path())
    now = datetime.now(timezone.utc)

    with open(args.config, "r") as f:
        config = json.load(f)

    tag_pattern = config["tag_pattern"]
    window_days = args.window_days if args.window_days is not None else config["window_days"]

    token = get_github_token()
    if not token:
        # No hard exit: the report itself carries the problem and its steps.
        result = no_credential_result(now, window_days, tag_pattern)
        hydrate_issues(result, guidance)
        write_output(result, window_days, args.out_dir, now)
        sys.exit(1)

    projects = config["projects"]
    if args.project:
        projects = [p for p in projects if p["name"].lower() == args.project.lower()]
        if not projects:
            print(f"ERROR: project '{args.project}' is not in {args.config}.", file=sys.stderr)
            sys.exit(1)
        if args.branch:
            for repo_cfg in projects[0]["repos"]:
                repo_cfg["prod_branch"] = args.branch
        if args.deploy_source:
            for repo_cfg in projects[0]["repos"]:
                repo_cfg["deploy_source"] = args.deploy_source

    try:
        validate_deploy_sources(projects)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    result = build_result(gh_session(token), projects, tag_pattern, window_days, now)
    hydrate_issues(result, guidance)
    write_output(result, window_days, args.out_dir, now)

    # Non-zero when something couldn't be measured at all, so CI notices. A
    # "partial" issue doesn't change it: the run measured, with declared gaps.
    sys.exit(1 if has_blocked(result) else 0)


if __name__ == "__main__":
    main()
