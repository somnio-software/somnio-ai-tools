#!/usr/bin/env python3
"""
Fetching skill — DORA (Deployment Frequency + Lead Time for Changes)

Source: the repo's provider API — GitHub (REST + Search), GitLab (REST v4) or
Bitbucket Cloud (REST 2.0) — NOT local git: lead time depends on the real
first commit of each PR/MR, something only the provider's PR/MR object
guarantees reliably regardless of the merge strategy (including squash).

Contract: it ONLY fetches and aggregates. It does not interpret or rank — that
is a later step, outside the scope of this skill.

Usage:
    export GITHUB_TOKEN=ghp_xxx   # or `gh auth login`; read access to the org's repos
    export GITLAB_TOKEN=glpat-xxx # only if a repo has "provider": "gitlab" (or `glab auth login`)
    export BITBUCKET_TOKEN=xxx    # only if a repo has "provider": "bitbucket"
                                  # (or BITBUCKET_USERNAME + BITBUCKET_APP_PASSWORD)
    python3 dora_metrics.py [--config config/projects.json] [--project "Example Project"] [--out-dir reports]
        [--branch branch] [--deploy-source release|tag] [--provider github|gitlab|bitbucket] [--window-days N]

Provider configurable per repo (the "provider" field in the config, default
"github"). A run can mix providers; each is measured with its own credential,
and a provider with no credential only turns its own repos into
`no_credential` stubs.

Deploy marker configurable per repo (the "deploy_source" field in the config,
default "release" on GitHub/GitLab and "tag" on Bitbucket, which has no
Releases API): "release" uses the provider's Releases (tag_name matches
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
from urllib.parse import quote

import requests

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import troubleshooting  # noqa: E402  (sibling module, loaded by path so the script stays runnable from anywhere)
import practice_guidance  # noqa: E402  (sibling module, same reason)

# Version of the Somnio CLI this script ships with. Kept in sync with
# `packageVersion` in cli/lib/src/version.dart by `dart run tool/stamp_version.dart`
# (run from cli/) and checked by cli/test/src/content/version_stamp_test.dart.
SOMNIO_VERSION = "3.2.5"

API_ROOT = "https://api.github.com"
# GitLab REST v4 (https://docs.gitlab.com/api/rest/). A repo's `api_base`
# replaces it for a self-hosted instance, so it is the full API root
# (".../api/v4"), not the host alone.
GITLAB_API_ROOT = "https://gitlab.com/api/v4"
# Bitbucket Cloud REST 2.0 (https://developer.atlassian.com/cloud/bitbucket/rest/intro/).
# Cloud only: `api_base` is rejected for bitbucket repos (validate_api_base).
BITBUCKET_API_ROOT = "https://api.bitbucket.org/2.0"

DEFAULT_PROVIDER = "github"

# Everything that differs between providers as plain data: the display label,
# the default API root, what a reviewed change is called, and how published
# and not-yet-published Releases read in a message (None: the provider has no
# Releases API), and whether a repo may point it at another API root with
# `api_base` (GitHub Enterprise, self-hosted GitLab). The functions that differ live in `_provider_api`, the one
# dispatch point. GitHub's wording is the wording the script used before it
# supported other providers, so a GitHub-only run reads exactly as it did.
PROVIDERS = {
    "github": {
        "label": "GitHub", "api_root": API_ROOT,
        "change": "PR", "changes": "PRs", "change_ref": "#",
        "releases_label": "published Releases",
        "unpublished_label": "drafts",
        "api_base": True,
    },
    "gitlab": {
        "label": "GitLab", "api_root": GITLAB_API_ROOT,
        "change": "MR", "changes": "MRs", "change_ref": "!",
        "releases_label": "published GitLab Releases",
        "unpublished_label": "upcoming releases",
        "api_base": True,
    },
    "bitbucket": {
        "label": "Bitbucket", "api_root": BITBUCKET_API_ROOT,
        "change": "PR", "changes": "PRs", "change_ref": "#",
        "releases_label": None,
        "unpublished_label": None,
        "api_base": False,
    },
}
VALID_PROVIDERS = tuple(PROVIDERS)


def provider_label(provider: str) -> str:
    return PROVIDERS[provider]["label"]


def repo_provider(repo_cfg: dict) -> str:
    return repo_cfg.get("provider", DEFAULT_PROVIDER)


def _cli_token(binary: str):
    """`<binary> auth token`, if that CLI is installed and logged in locally."""
    if shutil.which(binary):
        try:
            out = subprocess.run([binary, "auth", "token"], capture_output=True, text=True, timeout=10)
            token = out.stdout.strip()
            if out.returncode == 0 and token:
                return token
        except Exception:
            pass
    return None


def get_github_token():
    """Precedence order: 1) GITHUB_TOKEN env var, 2) `gh auth token`
    (if the GitHub CLI is installed and logged in locally). This way anyone on
    the team who already uses `gh` day to day can run this skill without
    generating or pasting a new token anywhere."""
    env_token = os.environ.get("GITHUB_TOKEN")
    if env_token:
        return env_token
    return _cli_token("gh")


def get_gitlab_token():
    """Same precedence as GitHub: 1) GITLAB_TOKEN env var, 2) `glab auth token`
    (if the GitLab CLI is installed and logged in locally)."""
    env_token = os.environ.get("GITLAB_TOKEN")
    if env_token:
        return env_token
    return _cli_token("glab")


def get_bitbucket_credential():
    """1) BITBUCKET_TOKEN env var, sent as a Bearer token; 2) BITBUCKET_USERNAME
    + BITBUCKET_APP_PASSWORD together, sent as Basic auth. Bitbucket has no CLI
    to fall back on, so there is no third option. Half a Basic pair is no
    credential at all."""
    token = os.environ.get("BITBUCKET_TOKEN")
    if token:
        return {"type": "bearer", "token": token}
    username = os.environ.get("BITBUCKET_USERNAME")
    app_password = os.environ.get("BITBUCKET_APP_PASSWORD")
    if username and app_password:
        return {"type": "basic", "username": username, "app_password": app_password}
    return None


class GitHubError(Exception):
    pass


class _ProviderApiError(Exception):
    """Base for the GitLab and Bitbucket errors. `status` keeps the HTTP
    status (None when unknown), so a caller can tell a missing per-PR/MR
    resource from a repo-wide failure without parsing the message."""

    def __init__(self, message: str = "", status: int = None):
        super().__init__(message)
        self.status = status


class GitLabError(_ProviderApiError):
    pass


class BitbucketError(_ProviderApiError):
    pass


# Statuses that mean one PR/MR's commit list is gone or hidden, not that the
# repo is unreachable: that single PR/MR is excluded and the repo is still
# measured.
_PER_CHANGE_MISSING_STATUSES = (403, 404)


API_ERRORS = (GitHubError, GitLabError, BitbucketError)


def gh_session(token: str) -> requests.Session:
    s = requests.Session()
    s.headers.update({
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    return s


def gitlab_session(token: str) -> requests.Session:
    """GitLab REST auth via the PRIVATE-TOKEN header
    (https://docs.gitlab.com/api/rest/authentication/)."""
    s = requests.Session()
    s.headers.update({"PRIVATE-TOKEN": token})
    return s


def bitbucket_session(credential: dict) -> requests.Session:
    """Bearer for a repository/project/workspace access token, Basic for
    username + app password
    (https://developer.atlassian.com/cloud/bitbucket/rest/intro/)."""
    s = requests.Session()
    if credential["type"] == "bearer":
        s.headers.update({"Authorization": f"Bearer {credential['token']}"})
    else:
        s.auth = (credential["username"], credential["app_password"])
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


_FRACTION_RE = re.compile(r"\.(\d+)")


def parse_iso_ts(s: str) -> datetime:
    """Any ISO 8601 timestamp the GitLab and Bitbucket APIs return — a `Z` or
    a numeric offset, with or without fractional seconds — as an aware UTC
    datetime. GitHub keeps parse_ts: its timestamps have one fixed shape.

    The `Z` and the fraction are normalized first so this also parses on
    Pythons older than 3.11, whose fromisoformat accepts neither a `Z` nor a
    fraction that isn't 3 or 6 digits long."""
    text = s.strip()
    if text.endswith(("Z", "z")):
        text = text[:-1] + "+00:00"
    text = _FRACTION_RE.sub(lambda m: "." + m.group(1)[:6].ljust(6, "0"), text, count=1)
    parsed = datetime.fromisoformat(text)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def fmt_ts(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def get_prod_releases(session: requests.Session, repo: str, tag_pattern: str, api_root: str = None):
    """Published Releases (not draft) whose tag matches tag_pattern, ascending order."""
    root = api_root or API_ROOT
    pattern = re.compile(tag_pattern)
    releases = []
    for r in gh_paginate(session, f"{root}/repos/{repo}/releases"):
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


def get_prod_tags(session: requests.Session, repo: str, tag_pattern: str, api_root: str = None):
    """Tags (without a Release) whose name matches tag_pattern, ascending order.

    Distinguishes an annotated tag from a lightweight one via the Git Data API:
    an annotated tag has its own object with a "tagging" date (tagger.date) —
    the signal closest to "when this was marked as a deploy", which can be quite
    a bit later than when the code was written. Using the underlying commit's
    date directly (as we did before) lost that distinction. A lightweight tag
    has no object of its own, so it falls back to the commit's date."""
    root = api_root or API_ROOT
    pattern = re.compile(tag_pattern)
    tag_names = [t.get("name", "") for t in gh_paginate(session, f"{root}/repos/{repo}/tags")]
    tags = []
    for name in tag_names:
        if not pattern.match(name):
            continue
        ref_resp = session.get(f"{root}/repos/{repo}/git/ref/tags/{name}")
        if not ref_resp.ok:
            continue
        obj = ref_resp.json().get("object", {})
        obj_sha = obj.get("sha")
        if obj.get("type") == "tag":
            tag_resp = session.get(f"{root}/repos/{repo}/git/tags/{obj_sha}")
            if not tag_resp.ok:
                continue
            tag_data = tag_resp.json()
            date_str = (tag_data.get("tagger") or {}).get("date")
            if not date_str:
                continue
            tags.append({"tag": name, "published_at": parse_ts(date_str), "url": tag_data.get("object", {}).get("url")})
        else:
            commit_resp = session.get(f"{root}/repos/{repo}/commits/{obj_sha}")
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


def get_pr_first_commit_ts(session: requests.Session, repo: str, pr_number: int, api_root: str = None):
    """Timestamp of the PR's first commit (via the PR object, not the git log of
    main — this stays correct even if the merge to main was a squash)."""
    root = api_root or API_ROOT
    commits = list(gh_paginate(session, f"{root}/repos/{repo}/pulls/{pr_number}/commits"))
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


def get_merged_prs_between(session: requests.Session, repo: str, branch: str, start: datetime, end: datetime,
                           api_root: str = None):
    """PRs merged to `branch` in (start, end], via the Search API (search/issues),
    regardless of the merge strategy (squash/merge commit/rebase)."""
    start_s = fmt_ts(start)
    end_s = fmt_ts(end)
    q = f"repo:{repo} is:pr is:merged base:{branch} merged:{start_s}..{end_s}"
    prs = []
    for item in gh_paginate(session, f"{api_root or API_ROOT}/search/issues", params={"q": q}):
        prs.append({"number": item["number"], "title": item.get("title", "")})
    return prs


def get_release_tag_names(session: requests.Session, repo: str, api_root: str = None) -> dict:
    """Tag names of every Release in the repo, split by draft state. Used only
    to explain an empty result — the measurement itself goes through
    get_prod_releases."""
    published, draft = [], []
    for r in gh_paginate(session, f"{api_root or API_ROOT}/repos/{repo}/releases"):
        name = r.get("tag_name", "")
        if not name:
            continue
        (draft if r.get("draft") else published).append(name)
    return {"published": published, "draft": draft}


def get_all_tag_names(session: requests.Session, repo: str, api_root: str = None) -> list:
    """Every git tag name in the repo, unfiltered."""
    return [t.get("name", "") for t in gh_paginate(session, f"{api_root or API_ROOT}/repos/{repo}/tags")
            if t.get("name")]


# --- GitLab (REST v4) --------------------------------------------------------
# https://docs.gitlab.com/api/rest/ — offset pagination with `page`/`per_page`
# (max 100) and a Link header carrying rel="next", which the docs recommend
# following instead of building page URLs by hand.

def gitlab_project_id(path: str) -> str:
    """A project path used as the `:id` of a GitLab URL must be URL-encoded
    (`group/sub/project` -> `group%2Fsub%2Fproject`); unencoded, the API
    answers 404."""
    return quote(path, safe="")


def _gitlab_project_url(repo: str, api_root: str = None) -> str:
    return f"{api_root or GITLAB_API_ROOT}/projects/{gitlab_project_id(repo)}"


def gitlab_paginate(session: requests.Session, url: str, params: dict = None):
    """GET with pagination via the Link header. Yields items from each page.
    Raises GitLabError with the same message prefixes gh_paginate uses, so
    classify_api_error reads all providers alike."""
    params = dict(params or {})
    params.setdefault("per_page", 100)
    next_url = url
    next_params = params
    while next_url:
        resp = session.get(next_url, params=next_params)
        if resp.status_code == 401:
            raise GitLabError(
                "401 Unauthorized. Check that GITLAB_TOKEN (or `glab auth token`) is valid and has "
                "read access to ALL the groups of the project's GitLab repos.",
                status=401,
            )
        if resp.status_code == 429:
            raise GitLabError(f"Rate limit reached: {resp.text[:300]}", status=429)
        if resp.status_code == 404:
            raise GitLabError(f"404 Not Found at {next_url} — does the project exist and does the token have access?",
                              status=404)
        if not resp.ok:
            raise GitLabError(f"GitLab API error {resp.status_code} at {next_url}: {resp.text[:300]}",
                              status=resp.status_code)
        for item in resp.json():
            yield item
        next_url = None
        next_params = None
        if "next" in resp.links:
            next_url = resp.links["next"]["url"]


def get_gitlab_tags(session: requests.Session, repo: str, tag_pattern: str, api_root: str = None):
    """Tags whose name matches tag_pattern, ascending order. Filtered here
    because the API's `search` parameter is a prefix/suffix match, not a regex.

    Dated by the tag's own `created_at` ("Date when the tag was created") when
    the API gives one, otherwise by the commit it points to
    (`commit.committed_date`) — the same tagging-date/commit-date split
    get_prod_tags makes for GitHub's annotated and lightweight tags."""
    pattern = re.compile(tag_pattern)
    tags = []
    for t in gitlab_paginate(session, f"{_gitlab_project_url(repo, api_root)}/repository/tags"):
        name = t.get("name", "")
        if not pattern.match(name):
            continue
        commit = t.get("commit") or {}
        date_str = t.get("created_at") or commit.get("committed_date") or commit.get("created_at")
        if not date_str:
            continue
        tags.append({"tag": name, "published_at": parse_iso_ts(date_str), "url": None})
    tags.sort(key=lambda x: x["published_at"])
    return tags


def _gitlab_release_ts(release: dict):
    released = release.get("released_at") or release.get("created_at")
    return parse_iso_ts(released) if released else None


def get_gitlab_releases(session: requests.Session, repo: str, tag_pattern: str, now: datetime = None,
                        api_root: str = None):
    """Releases whose tag matches tag_pattern, ascending order by `released_at`.
    An upcoming release (`released_at` still in the future) is GitLab's
    equivalent of a GitHub draft — it hasn't happened yet — so it is left out.
    Detected by comparing against `now`, not by the `upcoming_release` key,
    whose presence on past releases the docs don't pin down."""
    now = now or datetime.now(timezone.utc)
    pattern = re.compile(tag_pattern)
    releases = []
    for r in gitlab_paginate(session, f"{_gitlab_project_url(repo, api_root)}/releases"):
        tag = r.get("tag_name", "")
        if not pattern.match(tag):
            continue
        released_at = _gitlab_release_ts(r)
        if released_at is None or released_at > now:
            continue
        releases.append({"tag": tag, "published_at": released_at, "url": (r.get("_links") or {}).get("self")})
    releases.sort(key=lambda x: x["published_at"])
    return releases


def get_gitlab_release_tag_names(session: requests.Session, repo: str, now: datetime = None,
                                 api_root: str = None) -> dict:
    """Tag names of every Release in the project, with the upcoming ones under
    "draft" (same shape as get_release_tag_names). Used only to explain an
    empty result."""
    now = now or datetime.now(timezone.utc)
    published, draft = [], []
    for r in gitlab_paginate(session, f"{_gitlab_project_url(repo, api_root)}/releases"):
        name = r.get("tag_name", "")
        if not name:
            continue
        released_at = _gitlab_release_ts(r)
        (draft if released_at is not None and released_at > now else published).append(name)
    return {"published": published, "draft": draft}


def get_gitlab_all_tag_names(session: requests.Session, repo: str, api_root: str = None) -> list:
    """Every git tag name in the project, unfiltered."""
    return [t.get("name", "")
            for t in gitlab_paginate(session, f"{_gitlab_project_url(repo, api_root)}/repository/tags")
            if t.get("name")]


def get_gitlab_merged_mrs_between(session: requests.Session, repo: str, branch: str, start: datetime,
                                  end: datetime, api_root: str = None):
    """MRs merged into `branch` between start and end, filtered server-side
    with `merged_after`/`merged_before`. The MR's project-scoped `iid` is the
    number the rest of the script calls `number`.

    The window is checked again on each MR's own `merged_at`: the docs give no
    version history for those two parameters, and a self-hosted instance
    (`api_base`) that ignored them would otherwise hand back every merged MR
    on the branch and inflate the Lead Time silently."""
    params = {
        "state": "merged",
        "target_branch": branch,
        "merged_after": fmt_ts(start),
        "merged_before": fmt_ts(end),
    }
    mrs = []
    for item in gitlab_paginate(session, f"{_gitlab_project_url(repo, api_root)}/merge_requests", params=params):
        merged_at = item.get("merged_at")
        if merged_at and not (start <= parse_iso_ts(merged_at) <= end):
            continue
        mrs.append({"number": item["iid"], "title": item.get("title", "")})
    return mrs


def get_gitlab_mr_first_commit_ts(session: requests.Session, repo: str, mr_iid: int, api_root: str = None):
    """Timestamp of the MR's first commit, read from the MR's own commit list
    (stays correct after a squash). The list's order isn't documented, so the
    earliest date wins rather than the first or last item.

    A 403/404 on this one MR's commit list returns None, so only this MR is
    excluded (pr_first_commit_unfetchable) instead of the whole repo. A 401 or
    a rate limit still raises: those affect every request."""
    url = f"{_gitlab_project_url(repo, api_root)}/merge_requests/{mr_iid}/commits"
    dates = []
    try:
        for c in gitlab_paginate(session, url):
            d = c.get("authored_date") or c.get("committed_date") or c.get("created_at")
            if d:
                dates.append(parse_iso_ts(d))
    except GitLabError as e:
        if e.status in _PER_CHANGE_MISSING_STATUSES:
            return None
        raise
    return min(dates) if dates else None


# --- Bitbucket Cloud (REST 2.0) ---------------------------------------------
# https://developer.atlassian.com/cloud/bitbucket/rest/intro/ — every list is
# a page object `{values, next, ...}`; `next` is followed as given, never
# rebuilt. No Releases API: deploy markers are always plain tags.

def _bitbucket_check(resp, url: str) -> None:
    """Raises BitbucketError with the same message prefixes gh_paginate uses.
    Bitbucket's docs don't document a 429 response; it is still read as a rate
    limit, without relying on a Retry-After header."""
    if resp.status_code == 401:
        raise BitbucketError(
            "401 Unauthorized. Check that BITBUCKET_TOKEN (or BITBUCKET_USERNAME + "
            "BITBUCKET_APP_PASSWORD) is valid and has read access to ALL the workspaces of the "
            "project's Bitbucket repos.",
            status=401,
        )
    if resp.status_code == 429:
        raise BitbucketError(f"Rate limit reached: {resp.text[:300]}", status=429)
    if resp.status_code == 404:
        raise BitbucketError(f"404 Not Found at {url} — does the repo exist and does the credential have access?",
                             status=404)
    if not resp.ok:
        raise BitbucketError(f"Bitbucket API error {resp.status_code} at {url}: {resp.text[:300]}",
                             status=resp.status_code)


def bitbucket_paginate(session: requests.Session, url: str, params: dict = None):
    """GET following each page's `next` URL. Yields items from `values`.
    Asks for 50 items a page on the first request (`next` carries it on): the
    REST intro says "Globally, the minimum length is 10 and the maximum is
    100", and the default (10 in its example) would multiply the requests of a
    full merged-PR scan."""
    next_url = url
    next_params = dict(params or {})
    next_params.setdefault("pagelen", 50)
    while next_url:
        resp = session.get(next_url, params=next_params)
        _bitbucket_check(resp, next_url)
        data = resp.json()
        for item in data.get("values", []):
            yield item
        # `next` already carries every query parameter of the first request.
        next_url = data.get("next")
        next_params = None


def _bitbucket_repo_url(repo: str, api_root: str = None) -> str:
    return f"{api_root or BITBUCKET_API_ROOT}/repositories/{repo}"


def get_bitbucket_tags(session: requests.Session, repo: str, tag_pattern: str, api_root: str = None):
    """Tags whose name matches tag_pattern, ascending order. Dated by the tag's
    own `date` (present on annotated tags), otherwise by its target commit's
    `date` — the closest Bitbucket gets to GitHub's tagger-date/commit-date
    split."""
    pattern = re.compile(tag_pattern)
    tags = []
    for t in bitbucket_paginate(session, f"{_bitbucket_repo_url(repo, api_root)}/refs/tags"):
        name = t.get("name", "")
        if not pattern.match(name):
            continue
        date_str = t.get("date") or (t.get("target") or {}).get("date")
        if not date_str:
            continue
        tags.append({"tag": name, "published_at": parse_iso_ts(date_str), "url": None})
    tags.sort(key=lambda x: x["published_at"])
    return tags


def get_bitbucket_all_tag_names(session: requests.Session, repo: str, api_root: str = None) -> list:
    """Every git tag name in the repo, unfiltered."""
    return [t.get("name", "")
            for t in bitbucket_paginate(session, f"{_bitbucket_repo_url(repo, api_root)}/refs/tags")
            if t.get("name")]


def _bitbucket_pr_merged_at(session: requests.Session, repo: str, pr_item: dict, api_root: str):
    """When the PR was merged. The PR object has no "merged at" field, so the
    merge commit's own date stands in for it; when that commit can't be read,
    the PR's `updated_on` is the fallback (a merged PR's last update is, at
    the latest, its merge)."""
    commit_hash = (pr_item.get("merge_commit") or {}).get("hash")
    if commit_hash:
        url = f"{_bitbucket_repo_url(repo, api_root)}/commit/{commit_hash}"
        resp = session.get(url)
        if resp.status_code in (401, 429):
            _bitbucket_check(resp, url)
        if resp.ok:
            date_str = (resp.json() or {}).get("date")
            if date_str:
                return parse_iso_ts(date_str)
    updated_on = pr_item.get("updated_on")
    return parse_iso_ts(updated_on) if updated_on else None


def _bitbucket_merged_prs_since(session: requests.Session, repo: str, branch: str, since: datetime,
                                api_root: str = None) -> list:
    """Every PR merged into `branch` that can have been merged at or after
    `since`, with its merge time resolved. Only `state=MERGED` is pushed to the
    API; the destination branch is checked here.

    A PR last updated before `since` can't have been merged after it, so its
    merge commit is never fetched — that keeps the per-PR call to the PRs that
    can still matter."""
    prs = []
    for item in bitbucket_paginate(session, f"{_bitbucket_repo_url(repo, api_root)}/pullrequests",
                                   params={"state": "MERGED"}):
        destination = ((item.get("destination") or {}).get("branch") or {}).get("name")
        if destination is not None and destination != branch:
            continue
        updated_on = item.get("updated_on")
        if updated_on and parse_iso_ts(updated_on) < since:
            continue
        merged_at = _bitbucket_pr_merged_at(session, repo, item, api_root)
        if merged_at is None:
            continue
        prs.append({"number": item["id"], "title": item.get("title", ""), "merged_at": merged_at})
    return prs


def get_bitbucket_merged_prs_between(session: requests.Session, repo: str, branch: str, start: datetime,
                                     end: datetime, api_root: str = None, cache: dict = None):
    """PRs merged into `branch` between start and end (both inclusive, like
    GitHub's `merged:start..end`).

    Bitbucket can't filter merged PRs by branch or date on the server (not
    with documented fields), so each call scans the repo's whole merged-PR
    list. `cache` lets the deploy intervals of one measurement share a single
    scan: it keeps, per repo and branch, the PRs that can have been merged
    since the earliest start seen so far, and a later call whose start is not
    earlier reuses them instead of scanning again. compute_repo_metrics walks
    the intervals oldest first, so one repo costs one scan and one merge-commit
    lookup per recent PR, however many deploys it had."""
    key = (repo, branch)
    cached = cache.get(key) if cache is not None else None
    if cached is not None and cached["since"] <= start:
        candidates = cached["prs"]
    else:
        candidates = _bitbucket_merged_prs_since(session, repo, branch, start, api_root)
        if cache is not None:
            cache[key] = {"since": start, "prs": candidates}
    return [{"number": pr["number"], "title": pr["title"]}
            for pr in candidates if start <= pr["merged_at"] <= end]


def get_bitbucket_pr_first_commit_ts(session: requests.Session, repo: str, pr_id: int, api_root: str = None):
    """Timestamp of the PR's first commit, read from the PR's own commit list.
    The docs call the list "chronological" without saying which way, so the
    earliest date wins.

    Documented cases where a merged PR has no commits to read
    (https://api.bitbucket.org/swagger.json, GET
    /repositories/{workspace}/{repo_slug}/pullrequests/{pull_request_id}/commits):
    - 200 with a list that "will be empty if the source branch no longer
      exists", which is common when PRs close their source branch on merge;
    - 404 "if the pull request does not exist or the source branch is from a
      forked repository which no longer exists";
    - 403 "if the authenticated user does not have access to the pull request".
    All three return None, so only this PR is excluded
    (pr_first_commit_unfetchable) and the repo is still measured. A 401 or a
    rate limit still raises: those affect every request."""
    url = f"{_bitbucket_repo_url(repo, api_root)}/pullrequests/{pr_id}/commits"
    try:
        dates = [parse_iso_ts(c["date"]) for c in bitbucket_paginate(session, url) if c.get("date")]
    except BitbucketError as e:
        if e.status in _PER_CHANGE_MISSING_STATUSES:
            return None
        raise
    return min(dates) if dates else None


# --- Provider dispatch -------------------------------------------------------

def _is_rate_limited(resp) -> bool:
    return resp.status_code == 403 and "rate limit" in (resp.text or "").lower()


def _is_429(resp) -> bool:
    return resp.status_code == 429


# Each builder returns one provider's operations. Everything else asks
# `_provider_api` for "release", "tag", "merged", "first_commit",
# "release_names", "tag_names", "preflight_urls" or "rate_limited", and never
# branches on the provider itself. A provider with no Releases API has no
# "release" / "release_names" entries.
#
# The metric entries are lambdas so the module-level function is looked up at
# call time (the tests patch them). `kw` carries `api_root` only when the repo
# sets `api_base`, so a GitHub run without it makes exactly the calls it always
# made. `root` is the API root actually in use, for the preflight URLs.
#
# "preflight_urls" gives the repo URL and the production-branch URL; branch
# names are URL-encoded for GitLab and Bitbucket, whose branch endpoints take
# the name as one path segment, while GitHub keeps the request it always made.
# "rate_limited" reads a response: GitHub signals its rate limit as a 403 with
# "rate limit" in the body, GitLab and Bitbucket as a plain 429.

def _github_api(kw: dict, root: str, now: datetime) -> dict:
    return {
        "release": lambda s, r, p: get_prod_releases(s, r, p, **kw),
        "tag": lambda s, r, p: get_prod_tags(s, r, p, **kw),
        "merged": lambda s, r, b, a, z: get_merged_prs_between(s, r, b, a, z, **kw),
        "first_commit": lambda s, r, n: get_pr_first_commit_ts(s, r, n, **kw),
        "release_names": lambda s, r: get_release_tag_names(s, r, **kw),
        "tag_names": lambda s, r: get_all_tag_names(s, r, **kw),
        "preflight_urls": lambda r, b: (f"{root}/repos/{r}", f"{root}/repos/{r}/branches/{b}"),
        "rate_limited": _is_rate_limited,
    }


def _gitlab_api(kw: dict, root: str, now: datetime) -> dict:
    def preflight_urls(repo, branch):
        project = f"{root}/projects/{gitlab_project_id(repo)}"
        return project, f"{project}/repository/branches/{quote(branch, safe='')}"

    return {
        "release": lambda s, r, p: get_gitlab_releases(s, r, p, now=now, **kw),
        "tag": lambda s, r, p: get_gitlab_tags(s, r, p, **kw),
        "merged": lambda s, r, b, a, z: get_gitlab_merged_mrs_between(s, r, b, a, z, **kw),
        "first_commit": lambda s, r, n: get_gitlab_mr_first_commit_ts(s, r, n, **kw),
        "release_names": lambda s, r: get_gitlab_release_tag_names(s, r, now=now, **kw),
        "tag_names": lambda s, r: get_gitlab_all_tag_names(s, r, **kw),
        "preflight_urls": preflight_urls,
        "rate_limited": _is_429,
    }


def _bitbucket_api(kw: dict, root: str, now: datetime) -> dict:
    def preflight_urls(repo, branch):
        repository = f"{root}/repositories/{repo}"
        return repository, f"{repository}/refs/branches/{quote(branch, safe='')}"

    # One merged-PR scan per repo and branch, shared by every deploy interval
    # of this measurement (see get_bitbucket_merged_prs_between).
    merged_cache = {}
    return {
        "tag": lambda s, r, p: get_bitbucket_tags(s, r, p, **kw),
        "merged": lambda s, r, b, a, z: get_bitbucket_merged_prs_between(s, r, b, a, z, cache=merged_cache, **kw),
        "first_commit": lambda s, r, n: get_bitbucket_pr_first_commit_ts(s, r, n, **kw),
        "tag_names": lambda s, r: get_bitbucket_all_tag_names(s, r, **kw),
        "preflight_urls": preflight_urls,
        "rate_limited": _is_429,
    }


_PROVIDER_APIS = {
    "github": _github_api,
    "gitlab": _gitlab_api,
    "bitbucket": _bitbucket_api,
}


def _provider_api(provider: str, api_root: str = None, now: datetime = None) -> dict:
    """The one place that picks a provider's operations (see the builders
    above). Adding a provider means one PROVIDERS entry and one builder."""
    kw = {} if api_root is None else {"api_root": api_root}
    root = api_root or PROVIDERS[provider]["api_root"]
    return _PROVIDER_APIS[provider](kw, root, now)


def preflight_repo(session: requests.Session, repo: str, branch: str, provider: str = DEFAULT_PROVIDER,
                   api_root: str = None) -> list:
    """Checks, before measuring, the two things whose absence would otherwise
    produce a silent or misleading result: that the credential can see the repo
    at all, and that the configured production branch exists. Two cheap REST
    calls per repo (not Search, which is GitHub's rate-limited API).

    A returned issue with impact "blocked" means the repo cannot be measured;
    the caller skips it and keeps going with the rest of the project. A 404 on
    the repo means "not found or not visible to this credential" on all three
    providers, so it is reported as unreachable, never as missing."""
    issues = []
    label = provider_label(provider)
    root = api_root or PROVIDERS[provider]["api_root"]
    api = _provider_api(provider, api_root)
    repo_url, branch_url = api["preflight_urls"](repo, branch)
    rate_limited = api["rate_limited"]

    resp = session.get(repo_url)
    if resp.status_code == 401:
        return [make_issue("token_unauthorized", "blocked",
                           f"{repo}: 401 Unauthorized from the {label} API — the credential is not valid for this repo.")]
    if rate_limited(resp):
        return [make_issue("rate_limited", "blocked",
                           f"{repo}: {label} API rate limit reached — it could not be measured in this run.")]
    if resp.status_code in (403, 404):
        return [make_issue("repo_unreachable", "blocked",
                           f"{repo}: the {label} API returned {resp.status_code} — the repo is unreachable with this "
                           "credential, it could not be measured.",
                           evidence={"status": resp.status_code})]
    if resp.status_code != 200:
        return [make_issue("api_error", "blocked",
                           f"{repo}: {label} API error {resp.status_code} on {repo_url[len(root):]}: "
                           f"{(resp.text or '')[:300]}",
                           evidence={"status": resp.status_code})]

    branch_resp = session.get(branch_url)
    if branch_resp.status_code == 404:
        issues.append(make_issue(
            "branch_not_found", "partial",
            f"{repo}: branch '{branch}' does not exist — Lead Time can't be measured against it "
            "(Deployment Frequency is unaffected).",
            evidence={"prod_branch": branch},
        ))
    elif rate_limited(branch_resp):
        issues.append(make_issue(
            "rate_limited", "partial",
            f"{repo}: {label} API rate limit reached while checking branch '{branch}' — its existence "
            "could not be verified.",
            evidence={"prod_branch": branch},
        ))
    elif branch_resp.status_code != 200:
        issues.append(make_issue(
            "api_error", "partial",
            f"{repo}: {label} API error {branch_resp.status_code} checking branch '{branch}' — its "
            f"existence could not be verified: {(branch_resp.text or '')[:300]}",
            evidence={"status": branch_resp.status_code, "prod_branch": branch},
        ))
    return issues


EVIDENCE_SAMPLE_SIZE = 5


def diagnose_markers(session: requests.Session, repo: str, tag_pattern: str, deploy_source: str,
                     markers_total: int, deployment_frequency: int, latest_marker_at: str,
                     provider: str = DEFAULT_PROVIDER, api_root: str = None) -> list:
    """Explains a deploy count of 0 instead of leaving it mute — the difference
    between 'they didn't deploy' and 'the repo isn't instrumented' is invisible
    in the number alone, and only the second one is fixable.

    Costs nothing when markers were found inside the window: the extra API calls
    run only on the paths that need evidence. A provider with no Releases API
    (Bitbucket) has only one kind of marker, so there is no "other source" to
    compare against and no draft to look for."""
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
    api = _provider_api(provider, api_root)
    spec = PROVIDERS[provider]
    if "release_names" in api:
        releases = api["release_names"](session, repo)
    else:
        releases = {"published": [], "draft": []}
    tag_names = api["tag_names"](session, repo)
    releases_label = spec["releases_label"]

    if deploy_source == "tag":
        own_names, own_label = tag_names, "tags"
        other_names, other_label = releases["published"], releases_label
    else:
        own_names, own_label = releases["published"], releases_label
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
                f"{repo}: {len(matching_drafts)} Release(s) matching tag_pattern exist but are all "
                f"{spec['unpublished_label']} — {spec['unpublished_label']} are not counted as deploys.",
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
    "api_error",
)

# Codes with no entry in troubleshooting.md, on purpose. api_error is a
# catch-all for unexpected API failures on any provider: there is no fixed
# remediation, so the report shows the raw message (which names the provider).
# Kept as an explicit list so the drift test can tell "deliberate exception"
# from "someone forgot to document a code".
NO_GUIDANCE_CODES = ("api_error",)


# --- Practice guidance -------------------------------------------------------
# A separate, fixed catalog from the issue model above: issues are about
# whether THIS run could measure something; this catalog is about engineering
# practice in general and is never about this run's numbers. Every code here
# is attached to every result, unfiltered — nothing here is chosen, reordered
# or omitted based on what was measured (see references/practice-guidance.md,
# which is the single source of truth for the prose and stays in sync with
# this tuple by hand, same convention as ISSUE_CODES/troubleshooting.md).
PRACTICE_GUIDANCE_CODES = (
    "trunk_based_development",
    "small_prs",
    "automate_release_tagging",
    "fast_ci_feedback",
    "feature_flags_over_long_branches",
    "decouple_deploy_from_release_event",
    "automate_the_deploy_pipeline",
    "reduce_batch_size",
)

# code -> the report heading its dimension renders under. Order here is the
# order dimensions render in, independent of PRACTICE_GUIDANCE_CODES' order.
PRACTICE_GUIDANCE_DIMENSIONS = (
    ("lead_time", "Lowering Lead Time for Changes"),
    ("deployment_frequency", "Raising Deployment Frequency"),
)


def build_practice_guidance(catalog: dict) -> list:
    """Builds the fixed practice-guidance catalog attached to every result:
    every code in PRACTICE_GUIDANCE_CODES, in order, regardless of anything
    measured — never filtered, reordered, or picked based on a repo's numbers.
    A code missing from `catalog` (the file wasn't found, or was edited
    without keeping it in sync with this tuple) is left out here rather than
    invented; the renderer says explicitly when the catalog came back empty."""
    entries = []
    for code in PRACTICE_GUIDANCE_CODES:
        entry = catalog.get(code)
        if not entry:
            continue
        entries.append({
            "code": code,
            "title": entry.get("title", ""),
            "dimension": entry.get("dimension"),
            "what": entry.get("what", ""),
            "why": entry.get("why", ""),
            "how_to_adopt": entry.get("how_to_adopt", ""),
        })
    return entries


def attach_practice_guidance(result: dict, catalog: dict) -> None:
    """Attaches the whole catalog to the result once per run (never per
    repo — the same list regardless of how many repos or projects are in
    `result`)."""
    result["practice_guidance"] = build_practice_guidance(catalog)


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
                          deploy_source: str = "release", provider: str = DEFAULT_PROVIDER,
                          api_root: str = None):
    issues = []
    window_start = now - timedelta(days=window_days)
    api = _provider_api(provider, api_root, now)
    spec = PROVIDERS[provider]

    if deploy_source == "tag":
        all_deploys = api["tag"](session, repo, tag_pattern)
        marker_label = "Tag"
    else:
        all_deploys = api["release"](session, repo, tag_pattern)
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
        prs = api["merged"](session, repo, branch, prev_dep["published_at"], dep["published_at"])
        if not prs:
            issues.append(make_issue(
                "no_prs_in_range", "partial",
                f"{marker_label} {dep['tag']}: 0 merged {spec['changes']} found in the range — check the base "
                "branch/convention.",
                evidence={"tag": dep["tag"], "prev_tag": prev_dep["tag"], "prod_branch": branch},
            ))
            continue
        for pr in prs:
            first_commit_ts = api["first_commit"](session, repo, pr["number"])
            if first_commit_ts is None:
                issues.append(make_issue(
                    "pr_first_commit_unfetchable", "partial",
                    f"{spec['change']} {spec['change_ref']}{pr['number']}: could not fetch the first commit, "
                    "it's excluded.",
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


PRACTICE_GUIDANCE_LABELS = (("what", "What"), ("why", "Why it helps this metric"), ("how_to_adopt", "How to adopt it"))


def _render_practice_entry(entry: dict, lines: list) -> None:
    """One catalog entry, shaped like `_render_issue`'s bullet + nested
    guidance so both guidance styles in this report read the same way. Renders
    the human-readable `title` when the catalog has one; falls back to the
    raw `code` so an entry authored without a title line still renders
    visibly instead of crashing."""
    heading = entry.get("title") or entry["code"]
    lines.append(f"- **{heading}**")
    for key, label in PRACTICE_GUIDANCE_LABELS:
        text = (entry.get(key) or "").strip()
        if not text:
            continue
        _render_guidance_body(label, text, lines)


def _render_practice_guidance(catalog_entries, lines: list) -> None:
    """Renders the fixed practice-guidance catalog once, after every project
    section. Same entries on every run regardless of what was measured — a
    reference appendix, not commentary on this run's numbers (see
    references/practice-guidance.md). A catalog that came back empty (missing
    or unparseable file) says so explicitly rather than omitting the section
    or inventing entries."""
    lines.append("# How to improve these metrics")
    lines.append("")
    lines.append(
        "The following is a fixed catalog of engineering practices — the same "
        "entries every run, not an assessment of the numbers above."
    )
    lines.append("")
    if not catalog_entries:
        lines.append(
            "_(no practice guidance available — expected catalog at "
            "references/practice-guidance.md)_"
        )
        lines.append("")
        return
    by_dimension = {}
    for entry in catalog_entries:
        by_dimension.setdefault(entry.get("dimension"), []).append(entry)
    for dimension, heading in PRACTICE_GUIDANCE_DIMENSIONS:
        group = by_dimension.get(dimension)
        if not group:
            continue
        lines.append(f"## {heading}")
        lines.append("")
        for entry in group:
            _render_practice_entry(entry, lines)
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
            header = f"## `{r['repo']}` ({type_label}) — deploy_source: {r.get('deploy_source', 'release')}"
            # The provider is named only when it isn't the default, so a
            # GitHub repo's heading reads exactly as it always has.
            provider = r.get("provider", DEFAULT_PROVIDER)
            if provider != DEFAULT_PROVIDER:
                header += f" — provider: {provider}"
            lines.append(header)
            lines.append("")
            lines.append(f"- **Deployment Frequency** (window {window_days}d): {r['deployment_frequency']}")
            if r["lead_time_median_hours"] is not None:
                lines.append(f"- **Median Lead Time**: {r['lead_time_median_hours']}h (n={r['lead_time_n']})")
            else:
                lines.append("- **Median Lead Time**: no data in the window")
            lines.append("")
            _render_issue_groups(r.get("issues", []), lines)

    _render_practice_guidance(result.get("practice_guidance"), lines)
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
    """--branch, --deploy-source and --provider are one-off overrides of a
    SINGLE project; it makes no sense to apply them to all if --project isn't
    specified. Separated from main() so the validation can be tested without
    invoking the CLI."""
    if args.branch and not args.project:
        raise ValueError("--branch requires --project (the override is one-off, it isn't applied to all projects).")
    if args.deploy_source and not args.project:
        raise ValueError("--deploy-source requires --project (the override is one-off, it isn't applied to all projects).")
    if getattr(args, "provider", None) and not args.project:
        raise ValueError("--provider requires --project (the override is one-off, it isn't applied to all projects).")


def effective_deploy_source(repo_cfg: dict) -> str:
    """The repo's deploy_source, or its provider's default when omitted:
    "release" on GitHub and GitLab, "tag" on Bitbucket (no Releases API)."""
    explicit = repo_cfg.get("deploy_source")
    if explicit:
        return explicit
    return "release" if _has_releases(repo_provider(repo_cfg)) else "tag"


def _has_releases(provider: str) -> bool:
    """False only for a known provider with no Releases API (Bitbucket). An
    unknown provider is validate_providers' error to report, not this one's."""
    return provider not in PROVIDERS or PROVIDERS[provider]["releases_label"] is not None


def validate_providers(projects) -> None:
    """Validates that each repo's provider is one of the supported values."""
    for project in projects:
        for repo_cfg in project["repos"]:
            provider = repo_provider(repo_cfg)
            if provider not in VALID_PROVIDERS:
                raise ValueError(
                    f"invalid provider '{provider}' in repo {repo_cfg['repo']} "
                    f"(valid: {', '.join(VALID_PROVIDERS)})."
                )


def validate_deploy_sources(projects) -> None:
    """Validates that each repo's deploy_source is one of the supported values,
    and that "release" is only used on a provider that has Releases.
    Separated from main() so the validation can be tested without touching the real config."""
    for project in projects:
        for repo_cfg in project["repos"]:
            ds = effective_deploy_source(repo_cfg)
            if ds not in VALID_DEPLOY_SOURCES:
                raise ValueError(
                    f"invalid deploy_source '{ds}' in repo {repo_cfg['repo']} "
                    f"(valid: {', '.join(VALID_DEPLOY_SOURCES)})."
                )
            provider = repo_provider(repo_cfg)
            if ds == "release" and not _has_releases(provider):
                raise ValueError(
                    f"deploy_source 'release' is not supported in repo {repo_cfg['repo']}: "
                    f"{provider_label(provider)} has no Releases API — use \"tag\" (or omit the field)."
                )


def validate_api_base(projects) -> None:
    """`api_base` points GitHub (Enterprise) or GitLab (self-hosted) at another
    API root. A provider whose PROVIDERS entry says `api_base: False`
    (Bitbucket, Cloud only) rejects it. An unknown provider is
    validate_providers' error to report, not this one's."""
    for project in projects:
        for repo_cfg in project["repos"]:
            provider = repo_provider(repo_cfg)
            if repo_cfg.get("api_base") and provider in PROVIDERS and not PROVIDERS[provider]["api_base"]:
                raise ValueError(
                    f"api_base is not supported in repo {repo_cfg['repo']}: {provider_label(provider)} "
                    f"support is {provider_label(provider)} Cloud only."
                )


def classify_api_error(provider: str, repo: str, message: str) -> dict:
    """Maps an exception raised mid-measurement onto a code, so an access
    problem reaches the report with steps instead of as raw text.

    Matches on the START of the message, never a substring search: the message
    embeds the request URL (and, for the generic shape, the provider's response
    body), so a repo named `org/app-401` would otherwise be reported as an auth
    failure and its owner sent to reissue a perfectly good token. The prefixes
    below are the shapes gh_paginate, gitlab_paginate and bitbucket_paginate
    raise."""
    label = provider_label(provider)
    if message.startswith("401"):
        return make_issue("token_unauthorized", "blocked",
                          f"{repo}: 401 Unauthorized from the {label} API — the credential is not valid for this repo.")
    if message.startswith("Rate limit reached"):
        return make_issue("rate_limited", "blocked",
                          f"{repo}: {label} API rate limit reached — it could not be measured in this run.")
    if message.startswith("404"):
        return make_issue("repo_unreachable", "blocked",
                          f"{repo}: the {label} API returned 404 — the repo is unreachable with this credential, "
                          "it could not be measured.",
                          evidence={"status": 404})
    return make_issue("api_error", "blocked", f"{repo}: {message}")


def _with_provider(repo_result: dict, provider: str) -> dict:
    """Records the provider on a repo result. Omitted for the default
    (GitHub), so a GitHub-only run's JSON is unchanged and a consumer reads a
    missing `provider` as "github"."""
    if provider != DEFAULT_PROVIDER:
        repo_result["provider"] = provider
    return repo_result


def build_result(session, projects, tag_pattern: str, window_days: int, now: datetime,
                 extra_sessions: dict = None) -> dict:
    """Measures every repo of every project. A repo that can't be measured
    contributes its problems to the report and the run continues with the next
    one — a broken access on one repo must not cost the numbers of the others.

    `session` is the GitHub one; `extra_sessions` maps every other provider
    in play to its own session. Each repo is measured with its provider's."""
    sessions = {DEFAULT_PROVIDER: session, **(extra_sessions or {})}
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
            provider = repo_provider(repo_cfg)
            api_root = repo_cfg.get("api_base")
            deploy_source = effective_deploy_source(repo_cfg)
            repo_session = sessions.get(provider)

            issues = preflight_repo(repo_session, repo, branch, provider=provider, api_root=api_root)
            if any(i["impact"] == "blocked" for i in issues):
                repos_result.append(_with_provider({
                    "repo": repo, "prod_branch": branch, "deploy_source": deploy_source,
                    "type": repo_cfg.get("type", []), "measured": False,
                    "issues": issues, "warnings": [i["message"] for i in issues],
                }, provider))
                continue

            try:
                r = compute_repo_metrics(repo_session, repo, branch, repo_tag_pattern, window_days, now,
                                          deploy_source=deploy_source, provider=provider, api_root=api_root)
                r["issues"] = issues + r["issues"] + diagnose_markers(
                    repo_session, repo, repo_tag_pattern, deploy_source,
                    r["markers_total"], r["deployment_frequency"], r["latest_marker_at"],
                    provider=provider, api_root=api_root,
                )
                r["warnings"] = [i["message"] for i in r["issues"] if i["impact"] != "none"]
                r["measured"] = True
                r["type"] = repo_cfg.get("type", [])
            except (*API_ERRORS, requests.exceptions.RequestException) as e:
                issues = issues + [classify_api_error(provider, repo, str(e))]
                r = {
                    "repo": repo, "prod_branch": branch, "deploy_source": deploy_source,
                    "type": repo_cfg.get("type", []), "measured": False,
                    "issues": issues, "warnings": [i["message"] for i in issues],
                }
            repos_result.append(_with_provider(r, provider))
        result["projects"].append({"name": project["name"], "repos": repos_result})
    return result


def no_credential_result(now: datetime, window_days: int, tag_pattern: str, providers: list = None) -> dict:
    """The run can't measure anything, but it still produces a report: the
    person who ran it ends up with a file stating what happened and how to fix
    it, instead of a stderr line that scrolls away. `providers` are the ones in
    play for the run (default: GitHub only); with more than one, the message
    names every provider that was missing a credential."""
    providers = providers or [DEFAULT_PROVIDER]
    if len(providers) == 1:
        message = f"No {provider_label(providers[0])} credential found — nothing could be measured in this run."
    else:
        labels = ", ".join(provider_label(p) for p in providers)
        message = f"No credential found for any provider in this run ({labels}) — nothing could be measured."
    return {
        "generated_at": fmt_ts(now),
        "window_days": window_days,
        "tag_pattern": tag_pattern,
        "issues": [make_issue("no_credential", "blocked", message)],
        "projects": [],
    }


def providers_in_play(projects) -> list:
    """Every provider the given projects use, once each, in first-seen order."""
    seen = []
    for project in projects:
        for repo_cfg in project["repos"]:
            provider = repo_provider(repo_cfg)
            if provider not in seen:
                seen.append(provider)
    return seen


def no_credential_repo_result(repo_cfg: dict) -> dict:
    """An unmeasured repo whose provider has no credential in this run, shaped
    like any other unmeasured repo. Used when other providers in the run do
    have one, so only this provider's repos are lost."""
    provider = repo_provider(repo_cfg)
    issue = make_issue(
        "no_credential", "blocked",
        f"{repo_cfg['repo']}: no {provider_label(provider)} credential found — this repo could not be "
        "measured in this run.",
        evidence={"provider": provider},
    )
    return _with_provider({
        "repo": repo_cfg["repo"], "prod_branch": repo_cfg.get("prod_branch"),
        "deploy_source": effective_deploy_source(repo_cfg),
        "type": repo_cfg.get("type", []), "measured": False,
        "issues": [issue], "warnings": [issue["message"]],
    }, provider)


def split_by_credential(projects, sessions: dict):
    """Splits the projects into what can be measured (repos whose provider has
    a session) and, per project name, a `no_credential` stub for every other
    repo. Every project stays in the measurable list, even with no repos left,
    so merge_stub_repos keeps the config's project order."""
    measurable, stubs = [], {}
    for project in projects:
        repos = []
        for repo_cfg in project["repos"]:
            if sessions.get(repo_provider(repo_cfg)) is None:
                stubs.setdefault(project["name"], []).append(no_credential_repo_result(repo_cfg))
            else:
                repos.append(repo_cfg)
        measurable.append({**project, "repos": repos})
    return measurable, stubs


def merge_stub_repos(result: dict, stubs: dict) -> None:
    """Appends each project's `no_credential` stubs after its measured repos,
    in place. A project the result doesn't have yet is added."""
    by_name = {p["name"]: p for p in result["projects"]}
    for name, repos in stubs.items():
        if name in by_name:
            by_name[name]["repos"].extend(repos)
        else:
            result["projects"].append({"name": name, "repos": list(repos)})


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

        # One file per repo: a repo is the unit that gets measured (never
        # combined with its siblings), so it is also the unit that gets
        # saved and shared.
        for project in result["projects"]:
            for repo in project["repos"]:
                base = os.path.join(
                    out_dir, f"{date}-{slugs[repo['repo']]}-{REPORT_TYPE}"
                )
                per_repo = single_repo_result(result, project, repo)
                with open(f"{base}.md", "w") as f:
                    f.write(format_human_summary(per_repo, window_days))
                bases.append(base)

        if not bases:
            # Nothing measurable (no credential, empty config): still leave one
            # file behind stating what happened, instead of a stderr line that
            # scrolls away.
            base = os.path.join(out_dir, f"{date}-{NO_REPOS_SLUG}-{REPORT_TYPE}")
            with open(f"{base}.md", "w") as f:
                f.write(summary)
            bases.append(base)

        print("Output saved to:")
        for base in bases:
            print(f"  {base}.md")
        print()
    print(summary)
    print(output_json)


# provider -> (resolve its credential, open a session with it). Resolved
# lazily: a provider no repo uses is never asked for a credential.
_CREDENTIALS = {
    "github": (lambda: get_github_token(), lambda token: gh_session(token)),
    "gitlab": (lambda: get_gitlab_token(), lambda token: gitlab_session(token)),
    "bitbucket": (lambda: get_bitbucket_credential(), lambda cred: bitbucket_session(cred)),
}


def open_sessions(providers) -> dict:
    """provider -> session, or None when that provider has no credential."""
    sessions = {}
    for provider in providers:
        resolve, open_session = _CREDENTIALS[provider]
        credential = resolve()
        sessions[provider] = open_session(credential) if credential else None
    return sessions


def main():
    ap = argparse.ArgumentParser(
        description="DORA fetching (Deployment Frequency + Lead Time) from the GitHub, GitLab or Bitbucket API.")
    ap.add_argument("--config", default=os.path.join(os.path.dirname(__file__), "..", "config", "projects.json"))
    ap.add_argument("--project", default=None, help="Project name to run (default: all projects in the config).")
    ap.add_argument("--out-dir", default=None,
                     help="Folder where one Markdown report per repo is saved (default: doesn't save, stdout only).")
    ap.add_argument("--branch", default=None, help="One-off override of prod_branch for this run (requires --project). Doesn't modify the config.")
    ap.add_argument("--deploy-source", default=None, choices=list(VALID_DEPLOY_SOURCES),
                     help="One-off override of deploy_source for this run (requires --project). Doesn't modify the config.")
    ap.add_argument("--provider", default=None, choices=list(VALID_PROVIDERS),
                     help="One-off override of provider for every repo of the project (requires --project). "
                          "Doesn't modify the config.")
    ap.add_argument("--window-days", type=_positive_int, default=None,
                     help="One-off override of window_days for this run. Doesn't modify the config.")
    args = ap.parse_args()

    try:
        validate_scoped_overrides(args)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    guidance = troubleshooting.load_guidance(troubleshooting.default_path())
    # Loaded once per run, not once per repo: the catalog is fixed and attached
    # to the result as-is (attach_practice_guidance), never filtered by what
    # gets measured below.
    practice_catalog = practice_guidance.load_guidance(practice_guidance.default_path())
    now = datetime.now(timezone.utc)

    with open(args.config, "r") as f:
        config = json.load(f)

    tag_pattern = config["tag_pattern"]
    window_days = args.window_days if args.window_days is not None else config["window_days"]

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
        if args.provider:
            for repo_cfg in projects[0]["repos"]:
                repo_cfg["provider"] = args.provider

    try:
        validate_providers(projects)
        validate_deploy_sources(projects)
        validate_api_base(projects)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    # Credentials are resolved per provider, only for the providers the
    # selected repos use. An empty config still needs the GitHub one, as it
    # always did.
    providers = providers_in_play(projects) or [DEFAULT_PROVIDER]
    sessions = open_sessions(providers)
    if all(session is None for session in sessions.values()):
        # No hard exit: the report itself carries the problem and its steps.
        result = no_credential_result(now, window_days, tag_pattern, providers=providers)
        hydrate_issues(result, guidance)
        attach_practice_guidance(result, practice_catalog)
        write_output(result, window_days, args.out_dir, now)
        sys.exit(1)

    # A provider with no credential costs only its own repos: they become
    # `no_credential` stubs and every other repo is measured normally.
    measurable, stubs = split_by_credential(projects, sessions)
    extra_sessions = {p: s for p, s in sessions.items() if p != DEFAULT_PROVIDER}
    result = build_result(sessions.get(DEFAULT_PROVIDER), measurable, tag_pattern, window_days, now,
                          extra_sessions=extra_sessions)
    merge_stub_repos(result, stubs)
    hydrate_issues(result, guidance)
    attach_practice_guidance(result, practice_catalog)
    write_output(result, window_days, args.out_dir, now)

    # Non-zero when something couldn't be measured at all, so CI notices. A
    # "partial" issue doesn't change it: the run measured, with declared gaps.
    sys.exit(1 if has_blocked(result) else 0)


if __name__ == "__main__":
    main()
