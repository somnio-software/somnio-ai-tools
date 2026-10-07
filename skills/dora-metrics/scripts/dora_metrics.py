#!/usr/bin/env python3
"""
Fetching skill — DORA (Deployment Frequency + Lead Time for Changes)

Source: the repo provider's API (GitHub REST + Search, GitLab, Bitbucket Cloud,
Azure DevOps), NOT local git — lead time depends on the real first commit of
each PR/MR, something only the provider's PR object guarantees reliably
regardless of the merge strategy (including squash).

Contract: it ONLY fetches and aggregates. It does not interpret or rank — that
is a later step, outside the scope of this skill.

Usage:
    export GITHUB_TOKEN=ghp_xxx   # or a token with 'repo' (read) scope for the org's repos
    python3 dora_metrics.py [--config config/projects.json] [--project "Example Project"] [--out-dir reports]
        [--branch branch] [--deploy-source release|tag] [--window-days N]

Deploy marker configurable per repo (the "deploy_source" field in the config,
default "release"; "tag" on Bitbucket and Azure DevOps, which have no Releases
API): "release" uses Releases (tag_name matches tag_pattern); "tag" uses plain
git tags (without going through Releases), resolving the date via the tag
object or the commit they point to, for projects that tag but don't publish
Releases; "merge" treats every PR/MR merged into `prod_branch` as its own
deploy — for repos where the integration branch deploys itself on every merge
and nobody publishes releases or tags (lead time = first commit of the PR ->
its merge).

Provider configurable per repo ("provider": github | gitlab | bitbucket |
azure, default github). Azure DevOps repos are identified as
`organization/project/repository` and authenticate with a PAT.

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
import practice_guidance  # noqa: E402  (sibling module, same reason)

API_ROOT = "https://api.github.com"
GITLAB_API_ROOT = "https://gitlab.com/api/v4"
BITBUCKET_API_ROOT = "https://api.bitbucket.org/2.0"
AZURE_API_ROOT = "https://dev.azure.com"
AZURE_API_VERSION = "7.1"

PROVIDERS = ("github", "gitlab", "bitbucket", "azure")
PROVIDER_LABELS = {"github": "GitHub", "gitlab": "GitLab", "bitbucket": "Bitbucket", "azure": "Azure DevOps"}
# Providers without a Releases API: "release" is not a valid deploy_source for them.
PROVIDERS_WITHOUT_RELEASES = ("bitbucket", "azure")
# What the provider calls a merged change — only used in messages.
PROVIDER_PR_LABELS = {"github": "PRs", "gitlab": "MRs", "bitbucket": "PRs", "azure": "PRs"}


def provider_label(provider: str) -> str:
    return PROVIDER_LABELS.get(provider, provider)


def parse_iso_ts(s: str) -> datetime:
    """Parses the ISO-8601 shapes the non-GitHub providers emit (trailing `Z`,
    fractional seconds, explicit offsets) and normalizes to UTC. GitHub's
    strict `%Y-%m-%dT%H:%M:%SZ` keeps using parse_ts."""
    text = s.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    # Python accepts at most 6 fractional digits; Azure DevOps emits 7.
    m = re.match(r"^(.*T\d{2}:\d{2}:\d{2})\.(\d+)(.*)$", text)
    if m:
        text = f"{m.group(1)}.{m.group(2)[:6]}{m.group(3)}"
    dt = datetime.fromisoformat(text)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _json(resp):
    """Azure DevOps answers with a UTF-8 BOM on some endpoints; `resp.json()`
    chokes on it. Strips it before decoding."""
    text = resp.text if isinstance(getattr(resp, "text", None), str) else ""
    if text and text.lstrip().startswith("﻿"):
        return json.loads(text.lstrip().lstrip("﻿"))
    return resp.json()


class ProviderError(Exception):
    """Base of the per-provider API errors; build_result catches this."""


class GitLabError(ProviderError):
    pass


class BitbucketError(ProviderError):
    pass


class AzureDevOpsError(ProviderError):
    pass


# --- Credentials -------------------------------------------------------------

def get_gitlab_token():
    """1) GITLAB_TOKEN env var, 2) `glab auth token` (logged-in GitLab CLI)."""
    env_token = os.environ.get("GITLAB_TOKEN")
    if env_token:
        return env_token
    if shutil.which("glab"):
        try:
            out = subprocess.run(["glab", "auth", "token"], capture_output=True, text=True, timeout=10)
            token = out.stdout.strip()
            if out.returncode == 0 and token:
                return token
        except Exception:
            pass
    return None


def get_bitbucket_credential():
    """1) BITBUCKET_TOKEN (bearer), 2) BITBUCKET_USERNAME + BITBUCKET_APP_PASSWORD
    together (basic auth). Bitbucket Cloud has no CLI to fall back to."""
    token = os.environ.get("BITBUCKET_TOKEN")
    if token:
        return {"type": "bearer", "token": token}
    username = os.environ.get("BITBUCKET_USERNAME")
    app_password = os.environ.get("BITBUCKET_APP_PASSWORD")
    if username and app_password:
        return {"type": "basic", "username": username, "app_password": app_password}
    return None


AZURE_DEVOPS_RESOURCE_ID = "499b84ac-1321-427f-aa17-267ca6975798"


def get_azure_credential():
    """1) AZURE_DEVOPS_PAT env var (a Personal Access Token with Code: Read),
    2) `az account get-access-token` for the Azure DevOps resource (logged-in
    Azure CLI). PATs are the documented path; the CLI token is a convenience
    for people who already run `az login` day to day."""
    pat = os.environ.get("AZURE_DEVOPS_PAT")
    if pat:
        return {"type": "pat", "token": pat}
    if shutil.which("az"):
        try:
            out = subprocess.run(
                ["az", "account", "get-access-token", "--resource", AZURE_DEVOPS_RESOURCE_ID,
                 "--query", "accessToken", "-o", "tsv"],
                capture_output=True, text=True, timeout=20)
            token = out.stdout.strip()
            if out.returncode == 0 and token:
                return {"type": "bearer", "token": token}
        except Exception:
            pass
    return None


def gitlab_session(token: str) -> requests.Session:
    s = requests.Session()
    s.headers.update({"PRIVATE-TOKEN": token})
    return s


def bitbucket_session(credential: dict) -> requests.Session:
    s = requests.Session()
    if credential["type"] == "bearer":
        s.headers.update({"Authorization": f"Bearer {credential['token']}"})
    else:
        s.auth = (credential["username"], credential["app_password"])
    return s


def azure_session(credential: dict) -> requests.Session:
    s = requests.Session()
    if credential["type"] == "pat":
        s.auth = ("", credential["token"])
    else:
        s.headers.update({"Authorization": f"Bearer {credential['token']}"})
    s.headers.update({"Accept": "application/json"})
    return s


# --- Pagination per provider --------------------------------------------------

def _raise_for_status(resp, url: str, error_cls, label: str):
    """Common status handling for the non-GitHub providers. The message shapes
    are the ones classify_api_error matches on (prefix, never substring)."""
    if resp.status_code == 401 or (label == "Azure DevOps" and resp.status_code == 203):
        raise error_cls(f"401 Unauthorized. Check that the {label} credential is valid and can read the repo.")
    if resp.status_code == 429 or (resp.status_code == 403 and "rate limit" in (resp.text or "").lower()):
        raise error_cls(f"Rate limit reached: {(resp.text or '')[:300]}")
    if resp.status_code == 404:
        raise error_cls(f"404 Not Found at {url} — does the repo exist and does the credential have access?")
    if not resp.ok:
        raise error_cls(f"{label} API error {resp.status_code} at {url}: {(resp.text or '')[:300]}")


def gitlab_paginate(session: requests.Session, url: str, params: dict = None):
    """GET with Link-header pagination (GitLab), yielding items."""
    params = dict(params or {})
    params.setdefault("per_page", 100)
    next_url, next_params = url, params
    while next_url:
        resp = session.get(next_url, params=next_params)
        _raise_for_status(resp, next_url, GitLabError, "GitLab")
        data = _json(resp)
        for item in (data if isinstance(data, list) else [data]):
            yield item
        links = getattr(resp, "links", None) or {}
        next_url = links.get("next", {}).get("url")
        next_params = None


def bitbucket_paginate(session: requests.Session, url: str, params: dict = None):
    """GET with `next`-link pagination (Bitbucket Cloud), yielding `values`."""
    params = dict(params or {})
    params.setdefault("pagelen", 100)
    next_url, next_params = url, params
    while next_url:
        resp = session.get(next_url, params=next_params)
        _raise_for_status(resp, next_url, BitbucketError, "Bitbucket")
        data = _json(resp)
        if isinstance(data, dict):
            for item in data.get("values", []):
                yield item
            next_url = data.get("next")
        else:
            for item in data:
                yield item
            next_url = None
        next_params = None


def azure_paginate(session: requests.Session, url: str, params: dict = None):
    """GET with Azure DevOps pagination: `value` lists continued through the
    `x-ms-continuationtoken` response header (refs, PRs) or `$skip` for the
    endpoints that only support `$top`/`$skip` (pull requests)."""
    params = dict(params or {})
    params.setdefault("api-version", AZURE_API_VERSION)
    use_skip = "$top" in params
    skip = int(params.get("$skip", 0))
    while True:
        if use_skip:
            params["$skip"] = skip
        resp = session.get(url, params=params)
        _raise_for_status(resp, url, AzureDevOpsError, "Azure DevOps")
        data = _json(resp)
        items = data.get("value", []) if isinstance(data, dict) else data
        for item in items:
            yield item
        token = (getattr(resp, "headers", None) or {}).get("x-ms-continuationtoken")
        if token:
            params["continuationToken"] = token
            continue
        if use_skip and len(items) >= int(params["$top"]):
            skip += len(items)
            continue
        return


# --- GitLab -----------------------------------------------------------------

def gitlab_project_id(path: str) -> str:
    """GitLab addresses a project by its URL-encoded path (`group%2Fproject`)."""
    from urllib.parse import quote
    return quote(path, safe="")


def get_gitlab_releases(session, project: str, tag_pattern: str, now: datetime = None, api_root: str = None):
    """Published GitLab Releases whose tag matches tag_pattern, ascending.
    An "upcoming" release (released_at in the future) is GitLab's draft."""
    root = api_root or GITLAB_API_ROOT
    now = now or datetime.now(timezone.utc)
    pattern = re.compile(tag_pattern)
    releases = []
    for r in gitlab_paginate(session, f"{root}/projects/{gitlab_project_id(project)}/releases"):
        tag = r.get("tag_name", "")
        released = r.get("released_at") or r.get("created_at")
        if not pattern.match(tag) or not released:
            continue
        published_at = parse_iso_ts(released)
        if published_at > now:
            continue
        releases.append({"tag": tag, "published_at": published_at,
                         "url": (r.get("_links") or {}).get("self")})
    releases.sort(key=lambda x: x["published_at"])
    return releases


def get_gitlab_tags(session, project: str, tag_pattern: str, api_root: str = None):
    """GitLab tags matching tag_pattern, dated by the commit they point to."""
    root = api_root or GITLAB_API_ROOT
    pattern = re.compile(tag_pattern)
    tags = []
    for t in gitlab_paginate(session, f"{root}/projects/{gitlab_project_id(project)}/repository/tags"):
        name = t.get("name", "")
        date_str = (t.get("commit") or {}).get("committed_date") or (t.get("commit") or {}).get("created_at")
        if not pattern.match(name) or not date_str:
            continue
        tags.append({"tag": name, "published_at": parse_iso_ts(date_str), "url": None})
    tags.sort(key=lambda x: x["published_at"])
    return tags


def get_gitlab_release_tag_names(session, project: str, api_root: str = None, now: datetime = None) -> dict:
    """Tag names of every GitLab Release, upcoming ones reported as `draft`."""
    root = api_root or GITLAB_API_ROOT
    now = now or datetime.now(timezone.utc)
    published, draft = [], []
    for r in gitlab_paginate(session, f"{root}/projects/{gitlab_project_id(project)}/releases"):
        name = r.get("tag_name", "")
        if not name:
            continue
        released = r.get("released_at")
        upcoming = bool(released) and parse_iso_ts(released) > now
        (draft if upcoming else published).append(name)
    return {"published": published, "draft": draft}


def get_gitlab_all_tag_names(session, project: str, api_root: str = None) -> list:
    root = api_root or GITLAB_API_ROOT
    return [t.get("name", "") for t in gitlab_paginate(session, f"{root}/projects/{gitlab_project_id(project)}/repository/tags")
            if t.get("name")]


def get_gitlab_mr_first_commit_ts(session, project: str, mr_iid: int, api_root: str = None):
    root = api_root or GITLAB_API_ROOT
    dates = []
    for c in gitlab_paginate(session, f"{root}/projects/{gitlab_project_id(project)}/merge_requests/{mr_iid}/commits"):
        d = c.get("created_at") or c.get("authored_date") or c.get("committed_date")
        if d:
            dates.append(parse_iso_ts(d))
    return min(dates) if dates else None


def get_gitlab_merged_mrs_between(session, project: str, branch: str, start: datetime, end: datetime, api_root: str = None):
    """MRs merged into `branch` in (start, end]. GitLab filters by `updated_after`
    only, so the merge timestamp is checked here when the item carries it."""
    root = api_root or GITLAB_API_ROOT
    params = {"state": "merged", "target_branch": branch, "updated_after": start.isoformat(),
              "order_by": "updated_at", "sort": "desc"}
    mrs = []
    for item in gitlab_paginate(session, f"{root}/projects/{gitlab_project_id(project)}/merge_requests", params=params):
        merged = item.get("merged_at")
        if merged:
            merged_at = parse_iso_ts(merged)
            if not (start < merged_at <= end):
                continue
        else:
            merged_at = None
        mrs.append({"number": item["iid"], "title": item.get("title", ""),
                    **({"merged_at": merged_at, "url": item.get("web_url")} if merged_at else {})})
    return mrs


# --- Bitbucket Cloud ----------------------------------------------------------

def get_bitbucket_tags(session, repo: str, tag_pattern: str, api_root: str = None):
    """Bitbucket tags matching tag_pattern. An annotated tag carries its own
    `date`; a lightweight one is dated by its target commit."""
    root = api_root or BITBUCKET_API_ROOT
    pattern = re.compile(tag_pattern)
    tags = []
    for t in bitbucket_paginate(session, f"{root}/repositories/{repo}/refs/tags"):
        name = t.get("name", "")
        date_str = t.get("date") or (t.get("target") or {}).get("date")
        if not pattern.match(name) or not date_str:
            continue
        tags.append({"tag": name, "published_at": parse_iso_ts(date_str),
                     "url": ((t.get("links") or {}).get("html") or {}).get("href")})
    tags.sort(key=lambda x: x["published_at"])
    return tags


def get_bitbucket_all_tag_names(session, repo: str, api_root: str = None) -> list:
    root = api_root or BITBUCKET_API_ROOT
    return [t.get("name", "") for t in bitbucket_paginate(session, f"{root}/repositories/{repo}/refs/tags") if t.get("name")]


def get_bitbucket_pr_first_commit_ts(session, repo: str, pr_id: int, api_root: str = None):
    root = api_root or BITBUCKET_API_ROOT
    dates = [parse_iso_ts(c["date"]) for c in bitbucket_paginate(session, f"{root}/repositories/{repo}/pullrequests/{pr_id}/commits")
             if c.get("date")]
    return min(dates) if dates else None


def _bitbucket_pr_merged_at(session, repo: str, pr_item: dict, api_root: str):
    """Bitbucket's PR object has no merged_at: the merge commit's date is the
    closest thing, with `updated_on` as the fallback."""
    merge_hash = (pr_item.get("merge_commit") or {}).get("hash")
    if merge_hash:
        resp = session.get(f"{api_root}/repositories/{repo}/commit/{merge_hash}")
        if getattr(resp, "ok", False):
            data = _json(resp)
            if isinstance(data, dict) and data.get("date"):
                return parse_iso_ts(data["date"])
    return parse_iso_ts(pr_item["updated_on"]) if pr_item.get("updated_on") else None


def get_bitbucket_merged_prs_between(session, repo: str, branch: str, start: datetime, end: datetime, api_root: str = None):
    """PRs merged into `branch` in (start, end]."""
    root = api_root or BITBUCKET_API_ROOT
    params = {"state": "MERGED", "q": f'destination.branch.name="{branch}"', "sort": "-updated_on"}
    prs = []
    for item in bitbucket_paginate(session, f"{root}/repositories/{repo}/pullrequests", params=params):
        updated = item.get("updated_on")
        if updated and parse_iso_ts(updated) < start:
            break  # sorted by updated_on desc: nothing older can be inside the window
        merged_at = _bitbucket_pr_merged_at(session, repo, item, root)
        if merged_at is None or not (start < merged_at <= end):
            continue
        prs.append({"number": item["id"], "title": item.get("title", ""), "merged_at": merged_at,
                    "url": ((item.get("links") or {}).get("html") or {}).get("href")})
    return prs


# --- Azure DevOps -------------------------------------------------------------

def azure_repo_parts(repo: str):
    """`organization/project/repository` -> (org, project, repository). The
    project and repository names may hold spaces or dots; they are URL-quoted
    where they appear in a path."""
    parts = repo.split("/")
    if len(parts) != 3 or not all(parts):
        raise ValueError(f"Azure DevOps repos are identified as organization/project/repository, got {repo!r}.")
    return parts[0], parts[1], parts[2]


def _azure_repo_url(repo: str, api_root: str = None) -> str:
    from urllib.parse import quote
    org, project, name = azure_repo_parts(repo)
    root = api_root or AZURE_API_ROOT
    return f"{root}/{quote(org, safe='')}/{quote(project, safe='')}/_apis/git/repositories/{quote(name, safe='')}"


def get_azure_tags(session, repo: str, tag_pattern: str, api_root: str = None):
    """Azure DevOps tags matching tag_pattern. An annotated tag (peeledObjectId
    present) is dated by its tag object; a lightweight one by its commit."""
    base = _azure_repo_url(repo, api_root)
    pattern = re.compile(tag_pattern)
    tags = []
    for ref in azure_paginate(session, f"{base}/refs", params={"filter": "tags/"}):
        name = (ref.get("name") or "").replace("refs/tags/", "", 1)
        if not pattern.match(name):
            continue
        date_str, url = None, None
        if ref.get("peeledObjectId"):
            resp = session.get(f"{base}/annotatedtags/{ref['objectId']}", params={"api-version": AZURE_API_VERSION})
            if getattr(resp, "ok", False):
                data = _json(resp)
                date_str = ((data.get("taggedBy") or {}).get("date")) if isinstance(data, dict) else None
                url = data.get("url") if isinstance(data, dict) else None
            commit_id = ref["peeledObjectId"]
        else:
            commit_id = ref.get("objectId")
        if not date_str and commit_id:
            resp = session.get(f"{base}/commits/{commit_id}", params={"api-version": AZURE_API_VERSION})
            if getattr(resp, "ok", False):
                data = _json(resp)
                if isinstance(data, dict):
                    date_str = ((data.get("committer") or {}).get("date")) or ((data.get("author") or {}).get("date"))
                    url = url or data.get("remoteUrl")
        if not date_str:
            continue
        tags.append({"tag": name, "published_at": parse_iso_ts(date_str), "url": url})
    tags.sort(key=lambda x: x["published_at"])
    return tags


def get_azure_all_tag_names(session, repo: str, api_root: str = None) -> list:
    base = _azure_repo_url(repo, api_root)
    return [(ref.get("name") or "").replace("refs/tags/", "", 1)
            for ref in azure_paginate(session, f"{base}/refs", params={"filter": "tags/"}) if ref.get("name")]


def get_azure_pr_first_commit_ts(session, repo: str, pr_id: int, api_root: str = None):
    base = _azure_repo_url(repo, api_root)
    dates = []
    for c in azure_paginate(session, f"{base}/pullrequests/{pr_id}/commits"):
        d = (c.get("author") or {}).get("date") or (c.get("committer") or {}).get("date")
        if d:
            dates.append(parse_iso_ts(d))
    return min(dates) if dates else None


def get_azure_merged_prs_between(session, repo: str, branch: str, start: datetime, end: datetime, api_root: str = None):
    """Completed PRs into `branch` whose closedDate (= merge) is in (start, end].
    The API returns them newest first and only supports $top/$skip paging."""
    base = _azure_repo_url(repo, api_root)
    params = {"searchCriteria.status": "completed", "searchCriteria.targetRefName": f"refs/heads/{branch}",
              "$top": 100}
    prs = []
    for item in azure_paginate(session, f"{base}/pullrequests", params=params):
        closed = item.get("closedDate")
        if not closed:
            continue
        merged_at = parse_iso_ts(closed)
        if merged_at < start:
            break  # newest first: everything after this is older than the window
        if not (start < merged_at <= end):
            continue
        prs.append({"number": item["pullRequestId"], "title": item.get("title", ""), "merged_at": merged_at,
                    "url": item.get("url")})
    return prs


# --- Config helpers ----------------------------------------------------------

def effective_deploy_source(repo_cfg: dict) -> str:
    """Explicit `deploy_source` wins; otherwise "release", except on providers
    without a Releases API (Bitbucket, Azure DevOps), which default to "tag"."""
    explicit = repo_cfg.get("deploy_source")
    if explicit:
        return explicit
    return "tag" if repo_cfg.get("provider", "github") in PROVIDERS_WITHOUT_RELEASES else "release"


def validate_providers(projects) -> None:
    for project in projects:
        for repo_cfg in project["repos"]:
            provider = repo_cfg.get("provider", "github")
            if provider not in PROVIDERS:
                raise ValueError(f"invalid provider '{provider}' in repo {repo_cfg['repo']} (valid: {', '.join(PROVIDERS)}).")
            if provider == "azure":
                azure_repo_parts(repo_cfg["repo"])


def validate_api_base(projects) -> None:
    """`api_base` (self-hosted GitHub Enterprise / GitLab) is not supported for
    Bitbucket: only Bitbucket Cloud is."""
    for project in projects:
        for repo_cfg in project["repos"]:
            if repo_cfg.get("api_base") and repo_cfg.get("provider") == "bitbucket":
                raise ValueError(f"api_base is not supported for Bitbucket (repo {repo_cfg['repo']}): only Bitbucket Cloud is.")


def classify_api_error(provider: str, repo: str, message: str) -> dict:
    """Maps an exception raised mid-measurement onto a code, so an access
    problem reaches the report with steps instead of as raw text.

    Matches on the START of the message, never a substring search: the message
    embeds the request URL (and, for the generic shape, the provider's response
    body), so a repo named `org/app-401` would otherwise be reported as an auth
    failure and its owner sent to reissue a perfectly good token. The prefixes
    below are the shapes the paginators raise."""
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


def get_pr_merged_at(session: requests.Session, repo: str, pr_number: int):
    """merged_at of one PR, from the PR object (deploy_source "merge")."""
    resp = session.get(f"{API_ROOT}/repos/{repo}/pulls/{pr_number}")
    if not getattr(resp, "ok", False):
        return None
    data = _json(resp)
    merged = data.get("merged_at") if isinstance(data, dict) else None
    return parse_ts(merged) if merged else None


def get_merged_prs_between(session: requests.Session, repo: str, branch: str, start: datetime, end: datetime):
    """PRs merged to `branch` in (start, end], via the Search API (search/issues),
    regardless of the merge strategy (squash/merge commit/rebase)."""
    start_s = fmt_ts(start)
    end_s = fmt_ts(end)
    q = f"repo:{repo} is:pr is:merged base:{branch} merged:{start_s}..{end_s}"
    prs = []
    for item in gh_paginate(session, f"{API_ROOT}/search/issues", params={"q": q}):
        pr = {"number": item["number"], "title": item.get("title", ""), "url": item.get("html_url")}
        merged = (item.get("pull_request") or {}).get("merged_at")
        if merged:
            pr["merged_at"] = parse_ts(merged)
        prs.append(pr)
    return prs


def _is_rate_limited(resp) -> bool:
    return resp.status_code == 403 and "rate limit" in (resp.text or "").lower()


def preflight_repo(session: requests.Session, repo: str, branch: str, provider: str = "github",
                   api_root: str = None) -> list:
    """Checks, before measuring, the two things whose absence would otherwise
    produce a silent or misleading result: that the credential can see the repo
    at all, and that the configured production branch exists. Two cheap REST
    calls per repo (not Search, which is the rate-limited API).

    A returned issue with impact "blocked" means the repo cannot be measured;
    the caller skips it and keeps going with the rest of the project."""
    if provider == "github":
        return _preflight_github(session, repo, branch, api_root or API_ROOT)
    label = provider_label(provider)
    if provider == "gitlab":
        root = api_root or GITLAB_API_ROOT
        repo_url = f"{root}/projects/{gitlab_project_id(repo)}"
        branch_url = f"{repo_url}/repository/branches/{branch}"
    elif provider == "bitbucket":
        root = api_root or BITBUCKET_API_ROOT
        repo_url = f"{root}/repositories/{repo}"
        branch_url = f"{repo_url}/refs/branches/{branch}"
    else:  # azure
        repo_url = _azure_repo_url(repo, api_root)
        branch_url = f"{repo_url}/refs?filter=heads/{branch}"

    resp = session.get(repo_url)
    status = resp.status_code
    if status == 401 or (provider == "azure" and status == 203):
        return [make_issue("token_unauthorized", "blocked",
                           f"{repo}: 401 Unauthorized from the {label} API — the credential is not valid for this repo.")]
    if status == 429 or _is_rate_limited(resp):
        return [make_issue("rate_limited", "blocked",
                           f"{repo}: {label} API rate limit reached — it could not be measured in this run.")]
    if status in (403, 404):
        return [make_issue("repo_unreachable", "blocked",
                           f"{repo}: the {label} API returned {status} — the repo is unreachable with this "
                           "credential, it could not be measured.",
                           evidence={"status": status})]
    if status != 200:
        return [make_issue("api_error", "blocked",
                           f"{repo}: {label} API error {status} on {repo_url}: {(resp.text or '')[:300]}",
                           evidence={"status": status})]

    issues = []
    branch_resp = session.get(branch_url)
    bstatus = branch_resp.status_code
    missing = bstatus == 404
    if provider == "azure" and bstatus == 200:
        try:
            data = _json(branch_resp)
            missing = isinstance(data, dict) and not data.get("value")
        except Exception:
            missing = False
    if missing:
        issues.append(make_issue(
            "branch_not_found", "partial",
            f"{repo}: branch '{branch}' does not exist — Lead Time can't be measured against it "
            "(Deployment Frequency is unaffected).",
            evidence={"prod_branch": branch},
        ))
    elif bstatus == 429 or _is_rate_limited(branch_resp):
        issues.append(make_issue(
            "rate_limited", "partial",
            f"{repo}: {label} API rate limit reached while checking branch '{branch}' — its existence "
            "could not be verified.",
            evidence={"prod_branch": branch},
        ))
    elif bstatus != 200:
        issues.append(make_issue(
            "api_error", "partial",
            f"{repo}: {label} API error {bstatus} checking branch '{branch}' — its "
            f"existence could not be verified: {(branch_resp.text or '')[:300]}",
            evidence={"status": bstatus, "prod_branch": branch},
        ))
    return issues


def _preflight_github(session: requests.Session, repo: str, branch: str, api_root: str) -> list:
    issues = []

    resp = session.get(f"{api_root}/repos/{repo}")
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
        return [make_issue("api_error", "blocked",
                           f"{repo}: GitHub API error {resp.status_code} on /repos/{repo}: {(resp.text or '')[:300]}",
                           evidence={"status": resp.status_code})]

    branch_resp = session.get(f"{api_root}/repos/{repo}/branches/{branch}")
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
            "api_error", "partial",
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
                     markers_total: int, deployment_frequency: int, latest_marker_at: str,
                     provider: str = "github", api_root: str = None) -> list:
    """Explains a deploy count of 0 instead of leaving it mute — the difference
    between 'they didn't deploy' and 'the repo isn't instrumented' is invisible
    in the number alone, and only the second one is fixable.

    Costs nothing when markers were found inside the window: the extra API calls
    run only on the paths that need evidence."""
    if deploy_source == "merge":
        # The marker is the merge itself: there is no pattern to mismatch and no
        # draft to explain. A zero is a factual note, never a configuration gap.
        if deployment_frequency == 0:
            return [make_issue(
                "no_merged_prs_in_window", "none",
                f"{repo}: 0 {PROVIDER_PR_LABELS.get(provider, 'PRs')} merged into the production branch in the "
                "window — with deploy_source 'merge' every merge is a deploy, so nothing was deployed.",
                evidence={"deploy_source": deploy_source},
            )]
        return []

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
    label = provider_label(provider)
    if provider == "github":
        releases = get_release_tag_names(session, repo)
        tag_names = get_all_tag_names(session, repo)
    elif provider == "gitlab":
        releases = get_gitlab_release_tag_names(session, repo, api_root)
        tag_names = get_gitlab_all_tag_names(session, repo, api_root)
    elif provider == "bitbucket":
        releases = None
        tag_names = get_bitbucket_all_tag_names(session, repo, api_root)
    else:  # azure
        releases = None
        tag_names = get_azure_all_tag_names(session, repo, api_root)

    if deploy_source == "tag" or releases is None:
        own_names, own_label = tag_names, "tags"
        other_names, other_label = (releases["published"] if releases else []), f"published {label} Releases"
    else:
        own_names, own_label = releases["published"], f"published {label} Releases"
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

    if deploy_source == "release" and releases is not None:
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


VALID_DEPLOY_SOURCES = ("release", "tag", "merge")


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
    "no_merged_prs_in_window",
    "api_error",
)

# Codes with no entry in troubleshooting.md, on purpose. api_error is a
# catch-all for unexpected API failures (any provider): there is no fixed
# remediation, so the report shows the raw message. Kept as an explicit list so
# the drift test can tell "deliberate exception" from "someone forgot to
# document a code".
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


def _provider_fetchers(provider: str, api_root: str):
    """The four calls compute_repo_metrics needs, bound to one provider. Kept as
    module-level functions (looked up at call time) so tests can patch them."""
    if provider == "gitlab":
        return {
            "releases": lambda s, r, p, now: get_gitlab_releases(s, r, p, now=now, api_root=api_root),
            "tags": lambda s, r, p: get_gitlab_tags(s, r, p, api_root=api_root),
            "merged": lambda s, r, b, a, z: get_gitlab_merged_mrs_between(s, r, b, a, z, api_root=api_root),
            "first_commit": lambda s, r, n: get_gitlab_mr_first_commit_ts(s, r, n, api_root=api_root),
        }
    if provider == "bitbucket":
        return {
            "releases": None,
            "tags": lambda s, r, p: get_bitbucket_tags(s, r, p, api_root=api_root),
            "merged": lambda s, r, b, a, z: get_bitbucket_merged_prs_between(s, r, b, a, z, api_root=api_root),
            "first_commit": lambda s, r, n: get_bitbucket_pr_first_commit_ts(s, r, n, api_root=api_root),
        }
    if provider == "azure":
        return {
            "releases": None,
            "tags": lambda s, r, p: get_azure_tags(s, r, p, api_root=api_root),
            "merged": lambda s, r, b, a, z: get_azure_merged_prs_between(s, r, b, a, z, api_root=api_root),
            "first_commit": lambda s, r, n: get_azure_pr_first_commit_ts(s, r, n, api_root=api_root),
        }
    return {
        "releases": lambda s, r, p, now: get_prod_releases(s, r, p),
        "tags": lambda s, r, p: get_prod_tags(s, r, p),
        "merged": lambda s, r, b, a, z: get_merged_prs_between(s, r, b, a, z),
        "first_commit": lambda s, r, n: get_pr_first_commit_ts(s, r, n),
    }


def compute_repo_metrics(session: requests.Session, repo: str, branch: str,
                          tag_pattern: str, window_days: int, now: datetime,
                          deploy_source: str = "release", provider: str = "github",
                          api_root: str = None):
    issues = []
    window_start = now - timedelta(days=window_days)
    fetch = _provider_fetchers(provider, api_root)
    pr_label = PROVIDER_PR_LABELS.get(provider, "PRs")

    if deploy_source == "merge":
        return _compute_merge_metrics(session, repo, branch, window_days, window_start, now, fetch, pr_label, provider)

    if deploy_source == "tag" or fetch["releases"] is None:
        all_deploys = fetch["tags"](session, repo, tag_pattern)
        marker_label = "Tag"
    else:
        all_deploys = fetch["releases"](session, repo, tag_pattern, now)
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
        prs = fetch["merged"](session, repo, branch, prev_dep["published_at"], dep["published_at"])
        if not prs:
            issues.append(make_issue(
                "no_prs_in_range", "partial",
                f"{marker_label} {dep['tag']}: 0 merged {pr_label} found in the range — check the base branch/convention.",
                evidence={"tag": dep["tag"], "prev_tag": prev_dep["tag"], "prod_branch": branch},
            ))
            continue
        for pr in prs:
            first_commit_ts = fetch["first_commit"](session, repo, pr["number"])
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
        "provider": provider,
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


def _compute_merge_metrics(session, repo, branch, window_days, window_start, now, fetch, pr_label, provider):
    """deploy_source "merge": every PR/MR merged into the production branch
    inside the window is one deploy, dated by its merge; its lead time runs from
    its first commit to that merge. Nothing is bounded by a previous marker, so
    the whole window is one population and there is no "first marker" gap."""
    issues = []
    merged = fetch["merged"](session, repo, branch, window_start, now)
    # A provider whose listing does not carry the merge timestamp (GitHub's
    # Search API) is asked for it per PR.
    deploys = []
    for pr in merged:
        merged_at = pr.get("merged_at")
        if merged_at is None and provider == "github":
            merged_at = get_pr_merged_at(session, repo, pr["number"])
        if merged_at is None:
            issues.append(make_issue(
                "pr_first_commit_unfetchable", "partial",
                f"PR #{pr['number']}: could not resolve its merge time, it's excluded.",
                evidence={"pr": pr["number"]},
            ))
            continue
        deploys.append({**pr, "merged_at": merged_at})
    deploys.sort(key=lambda d: d["merged_at"])

    lead_times_hours, lt_detail = [], []
    for pr in deploys:
        first_commit_ts = fetch["first_commit"](session, repo, pr["number"])
        if first_commit_ts is None:
            issues.append(make_issue(
                "pr_first_commit_unfetchable", "partial",
                f"PR #{pr['number']}: could not fetch the first commit, it's excluded.",
                evidence={"pr": pr["number"]},
            ))
            continue
        lead_time_h = (pr["merged_at"] - first_commit_ts).total_seconds() / 3600
        lead_times_hours.append(lead_time_h)
        lt_detail.append({
            "pr": pr["number"],
            "title": pr.get("title", ""),
            "deploy_tag": f"PR #{pr['number']}",
            "first_commit_ts": fmt_ts(first_commit_ts),
            "deploy_ts": fmt_ts(pr["merged_at"]),
            "lead_time_hours": round(lead_time_h, 1),
        })
    lead_time_median_hours = round(statistics.median(lead_times_hours), 1) if lead_times_hours else None
    return {
        "repo": repo,
        "provider": provider,
        "prod_branch": branch,
        "deploy_source": "merge",
        "window_start": fmt_ts(window_start),
        "window_end": fmt_ts(now),
        "deployment_frequency": len(deploys),
        "deploys_in_window": [{"tag": f"PR #{d['number']}", "published_at": fmt_ts(d["merged_at"]), "url": d.get("url")}
                              for d in deploys],
        "lead_time_median_hours": lead_time_median_hours,
        "lead_time_n": len(lead_times_hours),
        "lead_time_detail": lt_detail,
        "markers_total": len(deploys),
        "latest_marker_at": fmt_ts(deploys[-1]["merged_at"]) if deploys else None,
        "issues": issues,
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
            provider = r.get("provider", "github")
            provider_note = "" if provider == "github" else f" · {provider_label(provider)}"
            lines.append(f"## `{r['repo']}` ({type_label}{provider_note}) — deploy_source: {r.get('deploy_source', 'release')}")
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
    """--branch and --deploy-source are one-off overrides of a SINGLE project;
    it makes no sense to apply them to all if --project isn't specified.
    Separated from main() so the validation can be tested without invoking the CLI."""
    if args.branch and not args.project:
        raise ValueError("--branch requires --project (the override is one-off, it isn't applied to all projects).")
    if args.deploy_source and not args.project:
        raise ValueError("--deploy-source requires --project (the override is one-off, it isn't applied to all projects).")
    if getattr(args, "provider", None) and not args.project:
        raise ValueError("--provider requires --project (the override is one-off, it isn't applied to all projects).")


def validate_deploy_sources(projects) -> None:
    """Validates that each repo's deploy_source is one of the supported values.
    Separated from main() so the validation can be tested without touching the real config."""
    for project in projects:
        for repo_cfg in project["repos"]:
            ds = effective_deploy_source(repo_cfg)
            if ds not in VALID_DEPLOY_SOURCES:
                raise ValueError(
                    f"invalid deploy_source '{ds}' in repo {repo_cfg['repo']} "
                    f"(valid: {', '.join(VALID_DEPLOY_SOURCES)})."
                )
            provider = repo_cfg.get("provider", "github")
            if ds == "release" and provider in PROVIDERS_WITHOUT_RELEASES:
                raise ValueError(
                    f"deploy_source 'release' is not available on {provider_label(provider)} (repo {repo_cfg['repo']}): "
                    "it has no Releases API — use 'tag' or 'merge'."
                )


def classify_github_error(repo: str, message: str) -> dict:
    """GitHub-flavoured alias of classify_api_error, kept for callers/tests."""
    return classify_api_error("github", repo, message)


def build_result(session, projects, tag_pattern: str, window_days: int, now: datetime,
                 extra_sessions: dict = None) -> dict:
    """Measures every repo of every project. A repo that can't be measured
    contributes its problems to the report and the run continues with the next
    one — a broken access on one repo must not cost the numbers of the others.

    `session` is the GitHub session; `extra_sessions` maps the other providers
    in play to theirs ({"gitlab": ..., "bitbucket": ..., "azure": ...})."""
    extra_sessions = extra_sessions or {}
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
            provider = repo_cfg.get("provider", "github")
            api_root = repo_cfg.get("api_base")
            repo_session = session if provider == "github" else extra_sessions.get(provider)
            repo_tag_pattern = repo_cfg.get("tag_pattern", tag_pattern)
            deploy_source = effective_deploy_source(repo_cfg)
            base = {"repo": repo, "provider": provider, "prod_branch": branch, "deploy_source": deploy_source,
                    "type": repo_cfg.get("type", [])}

            issues = preflight_repo(repo_session, repo, branch, provider=provider, api_root=api_root)
            if any(i["impact"] == "blocked" for i in issues):
                repos_result.append({**base, "measured": False,
                                     "issues": issues, "warnings": [i["message"] for i in issues]})
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
                r["provider"] = provider
                r["type"] = repo_cfg.get("type", [])
            except (GitHubError, ProviderError, requests.exceptions.RequestException, ValueError) as e:
                issues = issues + [classify_api_error(provider, repo, str(e))]
                r = {**base, "measured": False, "issues": issues, "warnings": [i["message"] for i in issues]}
            repos_result.append(r)
        result["projects"].append({"name": project["name"], "repos": repos_result})
    return result


def providers_in_play(projects) -> list:
    """Providers referenced by the selected projects, in first-seen order."""
    seen = []
    for project in projects:
        for repo_cfg in project["repos"]:
            provider = repo_cfg.get("provider", "github")
            if provider not in seen:
                seen.append(provider)
    return seen


def no_credential_repo_result(repo_cfg: dict) -> dict:
    """The stub a repo gets when its provider has no credential: same shape as
    any other unmeasurable repo, so the report reads the same."""
    provider = repo_cfg.get("provider", "github")
    issue = make_issue("no_credential", "blocked",
                       f"{repo_cfg['repo']}: no {provider_label(provider)} credential found — it could not be "
                       "measured in this run.")
    return {"repo": repo_cfg["repo"], "provider": provider, "prod_branch": repo_cfg.get("prod_branch"),
            "deploy_source": effective_deploy_source(repo_cfg), "type": repo_cfg.get("type", []),
            "measured": False, "issues": [issue], "warnings": [issue["message"]]}


def split_by_credential(projects, sessions: dict):
    """Separates the repos whose provider has a session from those that don't.
    Returns (measurable_projects, stubs) where stubs maps project name -> list
    of no-credential repo results, to be merged back by merge_stub_repos."""
    measurable, stubs = [], {}
    for project in projects:
        kept = []
        for repo_cfg in project["repos"]:
            if sessions.get(repo_cfg.get("provider", "github")):
                kept.append(repo_cfg)
            else:
                stubs.setdefault(project["name"], []).append(no_credential_repo_result(repo_cfg))
        measurable.append({**project, "repos": kept})
    return measurable, stubs


def merge_stub_repos(result: dict, stubs: dict) -> None:
    """Appends the no-credential stubs to their project's repos, in place."""
    for project in result["projects"]:
        project["repos"].extend(stubs.get(project["name"], []))
    for name, repos in stubs.items():
        if not any(p["name"] == name for p in result["projects"]):
            result["projects"].append({"name": name, "repos": list(repos)})


def no_credential_result(now: datetime, window_days: int, tag_pattern: str, providers: list = None) -> dict:
    """The run can't measure anything, but it still produces a report: the
    person who ran it ends up with a file stating what happened and how to fix
    it, instead of a stderr line that scrolls away."""
    labels = [provider_label(p) for p in (providers or ["github"])]
    listed = labels[0] if len(labels) == 1 else ", ".join(labels[:-1]) + " or " + labels[-1]
    return {
        "generated_at": fmt_ts(now),
        "window_days": window_days,
        "tag_pattern": tag_pattern,
        "issues": [make_issue("no_credential", "blocked",
                              f"No {listed} credential found — nothing could be measured in this run.")],
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


def main():
    ap = argparse.ArgumentParser(description="DORA fetching (Deployment Frequency + Lead Time) from the GitHub / GitLab / Bitbucket / Azure DevOps APIs.")
    ap.add_argument("--config", default=os.path.join(os.path.dirname(__file__), "..", "config", "projects.json"))
    ap.add_argument("--project", default=None, help="Project name to run (default: all projects in the config).")
    ap.add_argument("--out-dir", default=None, help="Folder where the output JSON is saved (default: doesn't save, stdout only).")
    ap.add_argument("--branch", default=None, help="One-off override of prod_branch for this run (requires --project). Doesn't modify the config.")
    ap.add_argument("--deploy-source", default=None, choices=list(VALID_DEPLOY_SOURCES),
                     help="One-off override of deploy_source for this run (requires --project). Doesn't modify the config.")
    ap.add_argument("--window-days", type=_positive_int, default=None,
                     help="One-off override of window_days for this run. Doesn't modify the config.")
    ap.add_argument("--provider", default=None, choices=list(PROVIDERS),
                     help="One-off override of provider for every repo of --project. Doesn't modify the config.")
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
        validate_api_base(projects)
        validate_deploy_sources(projects)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    # One credential per provider in play. A provider without one does not
    # block the others: its repos are reported as unmeasured, the rest measure.
    sessions = {}
    for provider in providers_in_play(projects):
        if provider == "github":
            token = get_github_token()
            sessions[provider] = gh_session(token) if token else None
        elif provider == "gitlab":
            token = get_gitlab_token()
            sessions[provider] = gitlab_session(token) if token else None
        elif provider == "bitbucket":
            cred = get_bitbucket_credential()
            sessions[provider] = bitbucket_session(cred) if cred else None
        else:
            cred = get_azure_credential()
            sessions[provider] = azure_session(cred) if cred else None

    if not any(sessions.values()):
        # No hard exit: the report itself carries the problem and its steps.
        result = no_credential_result(now, window_days, tag_pattern, providers=list(sessions))
        hydrate_issues(result, guidance)
        attach_practice_guidance(result, practice_catalog)
        write_output(result, window_days, args.out_dir, now)
        sys.exit(1)

    measurable, stubs = split_by_credential(projects, sessions)
    result = build_result(sessions.get("github"), measurable, tag_pattern, window_days, now,
                          extra_sessions={k: v for k, v in sessions.items() if k != "github"})
    merge_stub_repos(result, stubs)
    hydrate_issues(result, guidance)
    attach_practice_guidance(result, practice_catalog)
    write_output(result, window_days, args.out_dir, now)

    # Non-zero when something couldn't be measured at all, so CI notices. A
    # "partial" issue doesn't change it: the run measured, with declared gaps.
    sys.exit(1 if has_blocked(result) else 0)


if __name__ == "__main__":
    main()
