#!/usr/bin/env python3
"""Parser for references/practice-guidance.md.

That markdown file is the single source of truth for the fixed catalog of
engineering-practice guidance attached to every DORA report. This module
turns it into data so the script can embed the whole, unfiltered catalog in
its JSON output, instead of an agent transcribing the file by hand.

Contract of the file: each machine-readable entry is preceded by an anchor
comment `<!-- code: some_code -->`, optionally followed by a standalone bold
title line (`**Trunk-based development**`), sits under one of the file's `##`
dimension headings ("Lowering Lead Time for Changes" or "Raising Deployment
Frequency"), and contains up to three subsections: `### What`,
`### Why it helps this metric` and `### How to adopt it`. Sections without an
anchor that aren't a dimension heading are for human readers only and are
ignored here — same convention as `troubleshooting.py`.

This module reuses `troubleshooting.py`'s anchor and subsection regexes
rather than redefining them, since both files share the same anchor-comment
convention; it does not import or change anything about `troubleshooting.py`'s
own public contract (`load_guidance`, `default_path`), which stays exactly as
it is and is tested on its own.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from troubleshooting import ANCHOR_RE, SUBSECTION_RE  # noqa: E402  (sibling module, loaded by path)

# Level-2 heading that is NOT immediately preceded by an anchor comment is a
# dimension heading grouping several entries; an entry's own heading (if any)
# sits at a deeper level and is picked up, unmapped, by SUBSECTION_RE like any
# other non-matching ### heading (see troubleshooting.py's _parse_entry).
DIMENSION_RE = re.compile(r"^##\s+(.+?)\s*$", re.MULTILINE)

# Human dimension heading text -> the `dimension` value in the rendered JSON.
# Keep this in sync with the headings in references/practice-guidance.md; a
# heading with no entry here would leave an anchor's `dimension` as None.
_DIMENSION_HEADING_TO_KEY = {
    "lowering lead time for changes": "lead_time",
    "raising deployment frequency": "deployment_frequency",
}

# Heading text -> key in the returned entry. Any other ### heading (including
# an entry's own human-readable title, if it has one) is ignored.
_HEADING_TO_KEY = {
    "what": "what",
    "why it helps this metric": "why",
    "how to adopt it": "how_to_adopt",
}
_KEYS = ("what", "why", "how_to_adopt")

# An entry's optional human-readable title: a standalone bold line
# (`**Trunk-based development**`) sitting right after the anchor comment,
# before any ### subsection. practice-guidance.md uses bold here instead of a
# heading because the ## level is already taken by the two dimension
# headings (unlike troubleshooting.md, which is free to use ## per entry).
TITLE_RE = re.compile(r"^\*\*(.+?)\*\*\s*$")


def _extract_title(body: str) -> str:
    """Returns an entry's bold title line, or "" when it doesn't have one —
    same convention as missing ### subsections below: callers never have to
    guess whether the key exists. Only the entry's first non-blank line is
    checked, so a bold phrase used later in the prose (e.g. inside "Why it
    helps this metric") is never mistaken for the title."""
    for line in body.split("\n"):
        stripped = line.strip()
        if not stripped:
            continue
        m = TITLE_RE.match(stripped)
        return m.group(1).strip() if m else ""
    return ""


def _parse_entry(body: str) -> dict:
    """Splits one entry's body into its ### subsections. Missing subsections
    come back as empty strings so callers never have to guess whether a key
    exists — only whether it has content. Mirrors
    troubleshooting.py's `_parse_entry`, with this file's own heading map."""
    entry = {k: "" for k in _KEYS}
    matches = list(SUBSECTION_RE.finditer(body))
    for i, m in enumerate(matches):
        key = _HEADING_TO_KEY.get(m.group(1).strip().lower())
        if not key:
            continue
        end = matches[i + 1].start() if i + 1 < len(matches) else len(body)
        entry[key] = body[m.end():end].strip()
    return entry


def _dimension_for(pos: int, dimensions: list) -> str:
    """Which dimension heading a position falls under: the closest one that
    starts before `pos`. `dimensions` is a list of (start_offset, key), in
    file order. An anchor above every dimension heading (a file authored
    wrong) comes back as None rather than guessing."""
    current = None
    for start, key in dimensions:
        if start > pos:
            break
        current = key
    return current


def load_guidance(path: str) -> dict:
    """Reads the practice-guidance file and returns
    {code: {what, why, how_to_adopt, dimension}}. A missing file returns {} —
    the caller degrades to saying no guidance is available, it never invents
    entries."""
    if not os.path.exists(path):
        return {}
    with open(path, "r") as f:
        text = f.read()

    dimensions = []
    for m in DIMENSION_RE.finditer(text):
        key = _DIMENSION_HEADING_TO_KEY.get(m.group(1).strip().lower())
        dimensions.append((m.start(), key))

    guidance = {}
    anchors = list(ANCHOR_RE.finditer(text))
    for i, m in enumerate(anchors):
        end = anchors[i + 1].start() if i + 1 < len(anchors) else len(text)

        # Stop at the first --- (horizontal rule) before the next anchor,
        # same convention as troubleshooting.py.
        entry_text = text[m.end():end]
        hr_match = re.search(r"^---\s*$", entry_text, re.MULTILINE)
        if hr_match:
            end = m.end() + hr_match.start()

        entry = _parse_entry(text[m.end():end])
        entry["title"] = _extract_title(text[m.end():end])
        entry["dimension"] = _dimension_for(m.start(), dimensions)
        guidance[m.group(1)] = entry
    return guidance


def default_path() -> str:
    """Path to the practice-guidance file that ships next to this module."""
    return os.path.join(os.path.dirname(__file__), "..", "references", "practice-guidance.md")
