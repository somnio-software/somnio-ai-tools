#!/usr/bin/env python3
"""Print the "Audit pending" section of the TL watch message from files a run already read.

Usage: audit_ledger.py <folder> <owner/name>... [--now <ISO 8601>]

The folder holds, per repository, <name>.config.json (the output of the weekly-audit-triage skill's
repo_config.py) and <name>.prs.json (`gh pr list --json`), and per Jira project one or more
<KEY>.jira*.json search pages (a list, {"issues": [...]} or {"issues": {"nodes": [...]}}). A missing
or unreadable file is listed under "Could not see", never guessed. No network, no command: it only
reads that folder. Exits 0 with the section, or 2 on a usage error.
"""
import argparse
import glob
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone

REPO = re.compile(r"[\w.-]+/[\w.-]+")
PROJECT = re.compile(r"[A-Z][A-Z0-9]+")
# The fixer's branch: fix/<KEY>-n-<slug> or chore/<KEY>-n-<slug>, <KEY> the project and n the issue number.
FIXER_BRANCH = re.compile(r"(?:fix|chore)/([A-Z][A-Z0-9]+-\d+)-.")
# The triage's run label and its comment on an open ticket whose finding it sees again.
RUN_LABEL = re.compile(r"weekly-audit-run-(\d{4}-\d{2}-\d{2})$")
STILL_PRESENT = re.compile(r"Still present in the (\d{4}-\d{2}-\d{2}) run")
REVIEW_WAIT = timedelta(hours=72)
MISSED_RUNS = 2
MAX_TEXT = 80


def dig(value, *keys):
    """value[k1][k2]..., or None as soon as a level is not an object."""
    for key in keys:
        value = value.get(key) if isinstance(value, dict) else None
    return value


def parse_time(text):
    """ISO 8601 with Z, +00:00 or -0300 (Jira) -> aware UTC datetime; naive means UTC. None if unparseable."""
    if not isinstance(text, str):
        return None
    text = re.sub(r"Z$", "+00:00", text.strip())
    text = re.sub(r"([+-]\d{2})(\d{2})$", r"\1:\2", text)
    try:
        value = datetime.fromisoformat(text)
    except ValueError:
        return None
    return (value if value.tzinfo else value.replace(tzinfo=timezone.utc)).astimezone(timezone.utc)


def parse_day(text):
    try:
        return datetime.strptime(text, "%Y-%m-%d").date()
    except ValueError:
        return None


def clean(text):
    """Ticket text is data: no Slack link or mention syntax, one line, at most 80 characters."""
    text = " ".join(str(text or "").replace("<", "").replace(">", "").split())
    return text if len(text) <= MAX_TEXT else text[: MAX_TEXT - 1] + "…"


def read_json(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


def page_issues(data):
    """The issues of one Jira search page in any of the three shapes, or None for another shape."""
    if isinstance(data, dict):
        data = data.get("issues")
        if isinstance(data, dict):
            data = data.get("nodes")
    if isinstance(data, list) and all(isinstance(i, dict) for i in data):
        return data
    return None


def load_issues(folder, project, unseen):
    """Issues of every <KEY>.jira*.json page, merged by key (comments are joined). None if no page reads."""
    paths = sorted(glob.glob(os.path.join(folder, f"{project}.jira*.json")))
    if not paths:
        unseen.append(f"Jira issues of {project}")
        return None
    issues, keyless, read = {}, 0, False
    for path in paths:
        page = page_issues(read_json(path))
        if page is None:
            unseen.append(f"{os.path.basename(path)} (unreadable)")
            continue
        read = True
        for raw in page:
            key = raw.get("key")
            if not isinstance(key, str) or not key:
                keyless += 1
                continue
            issue = issues.setdefault(key, {"key": key, "comments": []})
            for name in ("summary", "status", "labels", "parent", "created"):
                if dig(raw, "fields", name) is not None:
                    issue.setdefault(name, raw["fields"][name])
            comments = dig(raw, "fields", "comment", "comments")
            issue["comments"].extend(comments if isinstance(comments, list) else [])
    if keyless:
        unseen.append(f"{keyless} {project} issue(s) without a key")
    return issues if read else None


def labels(issue):
    value = issue.get("labels")
    return {l for l in value if isinstance(l, str)} if isinstance(value, list) else set()


def is_open(issue):
    return dig(issue, "status", "statusCategory", "key") != "done"


def seen_dates(issue):
    """Dates of the runs that saw this issue: its run labels and its "Still present in the <DATE> run" comments."""
    dates = {parse_day(m.group(1)) for l in labels(issue) if (m := RUN_LABEL.match(l))}
    # A comment is searched as serialised JSON, so markdown and ADF bodies both match.
    dates |= {parse_day(d) for d in STILL_PRESENT.findall(json.dumps(issue["comments"]))}
    return {d for d in dates if d}


def is_bot(login):
    # ponytail: `gh pr list` (GraphQL) drops the "[bot]" suffix the REST API shows, so an App reviewer is
    # recognised by name. A bot named otherwise counts as a person and hides its PR; add it here if seen.
    return login.endswith(("[bot]", "bot")) or login == "copilot-pull-request-reviewer"


def age(text, now):
    created = parse_time(text)
    return f"{(now.date() - created.date()).days}d" if created else "?d"


def waiting(issues, now):
    found = [
        i for i in issues.values()
        if is_open(i) and "audit-auto-fixable" in labels(i)
        and not labels(i) & {"audit-approved", "audit-needs-human", "wont-do"}
    ]
    latest = datetime.max.replace(tzinfo=timezone.utc)
    found.sort(key=lambda i: (parse_time(i.get("created")) or latest, i["key"]))
    return [f'{i["key"]} "{clean(i.get("summary"))}" {age(i.get("created"), now)}' for i in found]


def unreviewed(issues, prs, now):
    approved = {k for k, i in issues.items() if is_open(i) and "audit-approved" in labels(i)}
    found = []
    for pr in prs:
        if not isinstance(pr, dict) or pr.get("isDraft") is not False:
            continue
        match = FIXER_BRANCH.match(str(pr.get("headRefName") or ""))
        created = parse_time(pr.get("createdAt"))
        if not match or match.group(1) not in approved or not created or now - created <= REVIEW_WAIT:
            continue
        author = str(dig(pr, "author", "login") or "").lower()
        reviewers = {str(dig(r, "author", "login") or "").lower() for r in pr.get("reviews") or []}
        if any(r and r != author and not is_bot(r) for r in reviewers):
            continue
        url = re.sub(r"[<>\s]", "", str(pr.get("url") or ""))
        found.append((created, f'#{pr.get("number")} {url} ({match.group(1)}) {age(pr.get("createdAt"), now)}'))
    return [line for _, line in sorted(found)]


def not_seen(issues):
    runs = set().union(*(seen_dates(i) for i in issues.values()))
    found = []
    for issue in issues.values():
        tags = labels(issue)
        if not is_open(issue) or "wont-do" in tags or not any(t.startswith("audit-fp-") for t in tags):
            continue
        created = parse_time(issue.get("created"))
        last = max(seen_dates(issue) | ({created.date()} if created else set()), default=None)
        if last is None or sum(1 for d in runs if d > last) < MISSED_RUNS:
            continue
        parent = dig(issue, "parent", "key")
        task = f" (task {clean(parent)})" if parent else ""
        found.append((last, issue["key"], f'{issue["key"]} "{clean(issue.get("summary"))}"{task} last seen {last}'))
    return [line for *_, line in sorted(found)]


def items(title, lines):
    return f"- {title} ({len(lines)}): {'; '.join(lines) if lines else 'none'}"


def build_section(folder, repos, now):
    out = [f"Audit pending — {now.date()} UTC"]
    projects, no_config = {}, []
    for repo in repos:
        # ponytail: the file is repo_config.py's output, so only the field this script uses is re-checked.
        project = dig(read_json(os.path.join(folder, repo.split("/")[1] + ".config.json")), "jira_project")
        if isinstance(project, str) and PROJECT.fullmatch(project):
            projects.setdefault(project, []).append(repo)
        else:
            no_config.append(repo)

    for project, members in projects.items():
        out.append(f"{project} · {', '.join(members)}")
        unseen = []
        issues = load_issues(folder, project, unseen)
        prs = []
        for repo in members:
            data = read_json(os.path.join(folder, repo.split("/")[1] + ".prs.json"))
            if isinstance(data, list):
                prs.extend(data)
            else:
                unseen.append(f"open PRs of {repo}")
        if issues is not None:
            lists = (waiting(issues, now), unreviewed(issues, prs, now), not_seen(issues))
            if not any(lists) and not unseen:
                out.append("Nothing pending.")
                continue
            out.append(items("Waiting for audit-approved", lists[0]))
            out.append(items("Fixer PRs without review for more than 3 days", lists[1]))
            out.append(items("Audit tickets not seen in the last 2 runs, can be closed", lists[2]))
        if unseen:
            out.append(f"- Could not see: {'; '.join(unseen)}")

    for repo in no_config:
        out.append(repo)
        out.append("- Could not see: no valid .claude/weekly-audit.json on its default branch")
    return "\n".join(out)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("folder")
    parser.add_argument("repos", nargs="+", metavar="owner/name")
    parser.add_argument("--now", help="ISO 8601 time the ages are measured at (default: now, UTC)")
    args = parser.parse_args(argv)
    if not os.path.isdir(args.folder):
        parser.error(f"no folder {args.folder}")
    bad = [r for r in args.repos if not REPO.fullmatch(r)]
    if bad:
        parser.error(f"not owner/name: {', '.join(bad)}")
    names = [r.split("/")[1] for r in args.repos]
    if len(set(names)) != len(names):
        parser.error("two repositories share a name, so their files would collide")
    now = parse_time(args.now) if args.now else datetime.now(timezone.utc)
    if now is None:
        parser.error(f"--now is not an ISO 8601 time: {args.now}")
    print(build_section(args.folder, args.repos, now))
    return 0


if __name__ == "__main__":
    sys.exit(main())
