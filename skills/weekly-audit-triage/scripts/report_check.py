#!/usr/bin/env python3
"""Check the Monday audit reports before they are uploaded to Drive.

Usage: report_check.py <validated config JSON> <YYYY-MM-DD> <report>...

The config is repo_config.py's output (defaults applied), the date is the run's. Prints `PASS <report>`,
or one `FAIL <report>: <reason>` line per reason, and exits 0 when every report passes, 2 otherwise.
The rules are those of the Tech Metrics spreadsheet that reads the reports: references/repo-config.md,
"Report checks".
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


def expected_reports(config: dict) -> set:
    """-> the (key, type) pairs the config's audits write; without `audits`, any accepted type."""
    if config.get("audits"):
        return {(audit.get("report_name", config["report_name"]), audit["skill"]) for audit in config["audits"]}
    return {(config["report_name"], typ) for typ in ACCEPTED_TYPES}


def _name_reasons(stem: str, config: dict, date: str) -> list:
    match = DATED.fullmatch(stem)
    if not match:
        return ["the name does not start with a YYYY-MM-DD date"]
    reasons = []
    if match.group(1) != date:
        reasons.append(f"dated {match.group(1)}, not the run date {date}")
    expected = expected_reports(config)
    # Longest key first, so a key that is a prefix of another never claims its reports.
    keys = sorted({key for key, _ in expected}, key=len, reverse=True)
    rest = match.group(2)
    key = next((k for k in keys if rest.startswith(f"{k}-")), None)
    if key is None:
        reasons.append(f"the repository key is not {' or '.join(repr(k) for k in keys)}")
        return reasons
    typ = rest[len(key) + 1:]
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


def main(argv: list) -> int:
    if len(argv) < 3 or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", argv[1]):
        print(__doc__, file=sys.stderr)
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
    failed = False
    for path in argv[2:]:
        reasons = check(path, config, argv[1])
        for reason in reasons:
            print(f"FAIL {path}: {reason}")
        if not reasons:
            print(f"PASS {path}")
        failed = failed or bool(reasons)
    return 2 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
