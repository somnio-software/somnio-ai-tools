#!/usr/bin/env python3
"""Check the Monday audit reports before they are uploaded to Drive.

Usage: report_check.py [--previous DIR] <validated config JSON> <YYYY-MM-DD> <report>...
       report_check.py --previous DIR --unchanged <repo sha> <ai_tools_ref or main> <config> <YYYY-MM-DD>

The config is repo_config.py's output (defaults applied), the date is the run's. Prints `PASS <report>`,
or one `FAIL <report>: <reason>` line per reason, and exits 0 when every report passes, 2 otherwise.
The rules are those of the Tech Metrics spreadsheet that reads the reports: references/repo-config.md,
"Report checks".

With --previous, each report's `## ` sections are also compared with those of the newest earlier report
of the same key and type in DIR: a missing one fails until the report carries the note line printed
under the FAIL, and then gives `WARN`. With --unchanged and no reports, it prints `SKIP` or `RUN` for
each health audit of the config instead, and exits 0 (CLOS-419).
"""
import json
import os
import re
import sys

# The report types the Tech Metrics spreadsheet reads. A closed list on purpose: the spreadsheet rejected
# nextjs-health-audit, which looks like any other <tech>-health-audit, so the pattern is not the rule
# (CLOS-413 OD-3). A new stack is one line here; repo_config.py checks `audits[].skill` against it.
ACCEPTED_TYPES = (
    "security-audit",
    "dora-metrics",
    "nestjs-health-audit",
    "react-health-audit",
    "python-health-audit",
)
DORA = "dora-metrics"
DATED = re.compile(r"(\d{4}-\d{2}-\d{2})-(.+)")
WINDOW_ROW = re.compile(r"^\|\s*Measurement window\s*\|\s*(\d+) days\s*\|\s*$", re.MULTILINE)
# The run notes the Weekly checks routine writes under a report's title (CLOS-419 D6).
RUN_LINE = re.compile(r"^> Run: \S+ @ ([0-9a-f]{40}) · somnio-ai-tools @ ([0-9a-f]{40})[ \t]*$", re.MULTILINE)
WARNING_LINE = re.compile(r"^> ⚠️", re.MULTILINE)
SHA = re.compile(r"[0-9a-f]{40}")
HEALTH = "-health-audit"


def expected_reports(config: dict) -> set:
    """-> the (key, type) pairs the config's audits write; without `audits`, any accepted type."""
    if config.get("audits"):
        return {(audit.get("report_name", config["report_name"]), audit["skill"]) for audit in config["audits"]}
    return {(config["report_name"], typ) for typ in ACCEPTED_TYPES}


def _parse(stem: str, config: dict) -> tuple:
    """-> (date, key, type) of a report name; None for each part it cannot find."""
    match = DATED.fullmatch(stem)
    if not match:
        return None, None, None
    # Longest key first, so a key that is a prefix of another never claims its reports.
    keys = sorted({key for key, _ in expected_reports(config)}, key=len, reverse=True)
    rest = match.group(2)
    key = next((k for k in keys if rest.startswith(f"{k}-")), None)
    return match.group(1), key, rest[len(key) + 1:] if key else None


def _name_reasons(stem: str, config: dict, date: str) -> list:
    found, key, typ = _parse(stem, config)
    if found is None:
        return ["the name does not start with a YYYY-MM-DD date"]
    reasons = []
    if found != date:
        reasons.append(f"dated {found}, not the run date {date}")
    expected = expected_reports(config)
    if key is None:
        keys = sorted({k for k, _ in expected}, key=len, reverse=True)
        reasons.append(f"the repository key is not {' or '.join(repr(k) for k in keys)}")
        return reasons
    if typ not in ACCEPTED_TYPES:
        reasons.append(f"type '{typ}' is not one the spreadsheet reads ({', '.join(ACCEPTED_TYPES)})")
    elif (key, typ) not in expected:
        reasons.append(f"no audit in the config writes '{typ}' under '{key}'")
    return reasons


def _dora_reasons(text: str, config: dict) -> list:
    heading = f"## {config['repo']}"
    lines = text.splitlines()
    reasons = [] if heading in lines else [f"no line is exactly '{heading}'"]
    # The backticked `## \`owner/name\` (…) — deploy_source: …` form the spreadsheet rejects.
    reasons += [
        f"heading '{line}' is not exactly '{heading}'"
        for line in lines
        if line.startswith("## ") and line != heading and config["repo"] in line
    ]
    window = (config.get("dora") or {}).get("window_days")
    found = {int(days) for days in WINDOW_ROW.findall(text)}
    if window is None:
        reasons.append("the config has no 'dora.window_days' to check the window against")
    elif not found:
        reasons.append("no '| Measurement window | N days |' row")
    elif found != {window}:
        days = ", ".join(str(d) for d in sorted(found))
        reasons.append(f"the measurement window is {days} days, the config's is {window}")
    return reasons


def check(path: str, config: dict, date: str) -> list:
    """-> every reason the report fails; empty when it passes."""
    stem, ext = os.path.splitext(os.path.basename(path))
    reasons = [] if ext == ".md" else ["not a .md file"]
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        return reasons + [f"cannot read it: {exc}"]
    if not text.strip():
        reasons.append("the file is empty")
    reasons += _name_reasons(stem, config, date)
    if stem.endswith(f"-{DORA}") and text.strip():
        reasons += _dora_reasons(text, config)
    return reasons


def _read(path: str):
    """-> the file's text, or None when it cannot be read or is blank."""
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except (OSError, UnicodeDecodeError):
        return None
    return text if text.strip() else None


def previous_report(directory: str, config: dict, date: str, key: str, typ: str) -> tuple:
    """-> (date, text) of the newest report of `key` and `typ` dated before `date` in `directory`; a report
    that is blank or cannot be read counts as none. (None, None) when there is none."""
    dated = []
    for name in os.listdir(directory):
        stem, ext = os.path.splitext(name)
        found, k, t = _parse(stem, config)
        if ext == ".md" and (k, t) == (key, typ) and found < date:
            dated.append((found, name))
    if not dated:
        return None, None
    found, name = max(dated)
    text = _read(os.path.join(directory, name))
    return (found, text) if text is not None else (None, None)


def sections(text: str) -> list:
    """-> the report's `## ` headings, trimmed and without a leading `N.`, in order, outside code fences."""
    found, fenced = [], False
    for line in text.splitlines():
        if line.lstrip().startswith(("```", "~~~")):
            fenced = not fenced
        elif not fenced and line.startswith("## "):
            name = re.sub(r"^\d+\.\s*", "", line[3:].strip())
            if name not in found:
                found.append(name)
    return found


def section_lines(path: str, config: dict, date: str, directory: str) -> list:
    """-> what the section check prints for one report: a FAIL line and the note to add, a WARN, a NOTE,
    or nothing. A report whose name or text the other checks reject is not compared."""
    _, key, typ = _parse(os.path.splitext(os.path.basename(path))[0], config)
    if typ not in ACCEPTED_TYPES:
        return []
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except (OSError, UnicodeDecodeError):
        return []
    found, previous = previous_report(directory, config, date, key, typ)
    if previous is None:
        return [f"NOTE {path}: no previous report"]
    current = set(sections(text))
    missing = [name for name in sections(previous) if name not in current]
    if not missing:
        return []
    note = f"> ⚠️ Sections missing since {found}: {'; '.join(missing)}"
    if note in (line.rstrip() for line in text.splitlines()):
        return [f"WARN {path}: sections missing since {found}: {'; '.join(missing)}"]
    return [f"FAIL {path}: sections missing since {found} not noted", note]


def unchanged_lines(config: dict, date: str, directory: str, repo_sha: str, ref: str) -> list:
    """-> `SKIP <key>-<type>: …` or `RUN <key>-<type>: <reason>` for each health audit of the config.
    A health audit is skipped only when its previous report was made from both SHAs and has no warning."""
    lines = []
    for key, typ in dict.fromkeys(
        (audit.get("report_name", config["report_name"]), audit["skill"]) for audit in config.get("audits") or []
    ):
        if not typ.endswith(HEALTH):
            continue
        name = f"{key}-{typ}"
        found, text = previous_report(directory, config, date, key, typ)
        run = RUN_LINE.search(text or "")
        if ref == "main":
            reason = "somnio-ai-tools is not pinned"
        elif text is None:
            reason = "no previous report"
        elif run is None:
            reason = f"the report of {found} has no '> Run:' line"
        elif WARNING_LINE.search(text):
            reason = f"the report of {found} has a '> ⚠️' line"
        elif run.group(1) != repo_sha:
            reason = f"the repository is at {repo_sha[:12]}, the report of {found} audited {run.group(1)[:12]}"
        elif run.group(2) != ref:
            reason = f"somnio-ai-tools is at {ref[:12]}, the report of {found} used {run.group(2)[:12]}"
        else:
            lines.append(f"SKIP {name}: no changes since {repo_sha[:12]} (report of {found})")
            continue
        lines.append(f"RUN {name}: {reason}")
    return lines


def main(argv: list) -> int:
    previous = unchanged = None
    while argv and argv[0] in ("--previous", "--unchanged"):
        if argv[0] == "--previous" and len(argv) > 1:
            previous, argv = argv[1], argv[2:]
        elif argv[0] == "--unchanged" and len(argv) > 2:
            unchanged, argv = argv[1:3], argv[3:]
        else:
            argv = []
    if unchanged is not None:
        sha, ref = unchanged
        usable = (previous is not None and len(argv) == 2 and SHA.fullmatch(sha)
                  and (ref == "main" or SHA.fullmatch(ref)))
    else:
        usable = len(argv) >= 3
    if not usable or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", argv[1]):
        print(__doc__, file=sys.stderr)
        return 2
    if previous is not None and not os.path.isdir(previous):
        print(f"no directory {previous}", file=sys.stderr)
        return 2
    try:
        with open(argv[0], encoding="utf-8") as fh:
            config = json.load(fh)
    except (OSError, ValueError) as exc:
        print(f"cannot read the config: {exc}", file=sys.stderr)
        return 2
    if not isinstance(config, dict) or not all(isinstance(config.get(k), str) for k in ("repo", "report_name")):
        print("the config must be repo_config.py's output", file=sys.stderr)
        return 2
    if unchanged is not None:
        for line in unchanged_lines(config, argv[1], previous, *unchanged):
            print(line)
        return 0
    failed = False
    for path in argv[2:]:
        reasons = check(path, config, argv[1])
        for reason in reasons:
            print(f"FAIL {path}: {reason}")
        lines = section_lines(path, config, argv[1], previous) if previous is not None else []
        for line in lines:
            print(line)
        reasons += [line for line in lines if line.startswith("FAIL ")]
        if not reasons:
            print(f"PASS {path}")
        failed = failed or bool(reasons)
    return 2 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
