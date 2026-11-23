#!/usr/bin/env python3
"""Stable fingerprint of an audit finding: sha1(source|rule|file|title)[:10].

The line number is left out on purpose so the same finding keeps its fingerprint when the code
above it moves. Reads findings.json (a list, or {"findings": [...]}) and prints it with the
`fingerprint` of every entry recomputed. The input is a local scratch file the triage builds in $TMPDIR
from the reports; it is never uploaded anywhere. Usage: fingerprint.py <scratch>.json
"""
import hashlib
import json
import re
import sys


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[:#]\d+\b", "", str(text or ""))).strip().lower()


def fingerprint(finding: dict) -> str:
    key = "|".join(
        normalize(finding.get(k))
        for k in ("source", "rule", "file", "title")
    )
    return hashlib.sha1(key.encode()).hexdigest()[:10]


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    with open(sys.argv[1], encoding="utf-8") as fh:
        data = json.load(fh)
    findings = data["findings"] if isinstance(data, dict) else data
    for f in findings:
        f["fingerprint"] = fingerprint(f)
    json.dump(findings, sys.stdout, indent=2, ensure_ascii=False)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
