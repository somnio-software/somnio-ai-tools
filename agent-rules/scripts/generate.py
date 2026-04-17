#!/usr/bin/env python3
"""
Generates tool-specific adapter files from the canonical source in rules/.

All outputs are grouped per stack (flutter, nestjs, react) so consumers
install only what they need.

Usage:
  python3 scripts/generate.py                    # regenerate all adapters
  python3 scripts/generate.py --only cursor
  python3 scripts/generate.py --only claude
  ...

Source of truth: rules/<stack>/*.md
Generated outputs (all inside adapters/):
  adapters/claude/<stack>/CLAUDE.md                 # minimal, uses @imports
  adapters/claude/<stack>/rules/*.md                # condensed rules
  adapters/cursor/rules/<stack>/*.mdc               # cursor mdc per rule
  adapters/antigravity/rules/<stack>/*.md           # antigravity md per rule
  adapters/windsurf/<stack>/.windsurfrules          # single file per stack
  adapters/copilot/<stack>/copilot-instructions.md  # single file per stack
  adapters/codex/<stack>/system-prompt.md           # single file per stack
"""

from __future__ import annotations

import argparse
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

AUTO_GEN_COMMENT = (
    "# AUTO-GENERATED — do not edit directly. "
    "Edit rules/ and run: cd agent-rules && python3 scripts/generate.py\n"
)


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------


def parse_frontmatter(content: str) -> tuple[dict[str, str], str]:
    if not content.startswith("---"):
        return {}, content

    end = content.index("\n---", 3) if "\n---" in content[3:] else -1
    if end == -1:
        return {}, content

    raw_meta = content[4:end]
    body = content[end + 4 :].lstrip()

    meta: dict[str, str] = {}
    for line in raw_meta.split("\n"):
        colon = line.find(":")
        if colon == -1:
            continue
        key = line[:colon].strip()
        value = line[colon + 1 :].strip().strip("\"'")
        meta[key] = value

    return meta, body


def load_rules() -> dict[str, list[dict]]:
    """Load all rules grouped by stack (subfolder name)."""
    rules_dir = ROOT / "rules"
    files = sorted(rules_dir.rglob("*.md"))

    groups: dict[str, list[dict]] = {}
    for file_path in files:
        rel = file_path.relative_to(rules_dir)
        parts = rel.parts
        stack = parts[0] if len(parts) > 1 else "general"
        filename = file_path.stem

        content = file_path.read_text(encoding="utf-8")
        meta, body = parse_frontmatter(content)

        groups.setdefault(stack, []).append(
            {
                "file_path": file_path,
                "meta": meta,
                "body": body,
                "filename": filename,
            }
        )

    return groups


# ---------------------------------------------------------------------------
# Aggressive condenser
# ---------------------------------------------------------------------------


def _strip_section(lines: list[str], start_idx: int, section_prefix: str) -> int:
    """Return index of first line after the section starting at start_idx.

    A section ends when we hit another heading of equal or lower depth,
    or a horizontal rule (`---`) used as separator.
    """
    depth = section_prefix.count("#")
    i = start_idx + 1
    while i < len(lines):
        stripped = lines[i].lstrip()
        if stripped.startswith("#"):
            # Count leading #s (up to 6)
            other_depth = len(stripped) - len(stripped.lstrip("#"))
            if 0 < other_depth <= depth:
                return i
        if lines[i].strip() == "---":
            return i
        i += 1
    return i


def condense(body: str) -> str:
    """Apply aggressive condensing to a rule body.

    Transformations:
      1. Remove `## Purpose` section entirely (usually redundant with the
         frontmatter description that's already rendered above).
      2. Remove every `#### Bad` block (the negative examples — the
         Common Mistakes list covers these more compactly).
      3. Flatten `#### Good` headings (drop the heading, keep content).
      4. Merge `## Best Practices` + `## Common Mistakes` into a single
         `## Rules` section. Common Mistakes items are prefixed with
         "Avoid" to read naturally as rules.
      5. Collapse runs of 3+ blank lines to 2.
    """
    lines = body.split("\n")
    result: list[str] = []

    # Pass 1: strip Purpose and #### Bad sections, drop #### Good headings.
    i = 0
    while i < len(lines):
        stripped = lines[i].strip()

        if stripped == "## Purpose":
            i = _strip_section(lines, i, "##")
            continue

        if stripped == "#### Bad":
            i = _strip_section(lines, i, "####")
            continue

        if stripped == "#### Good":
            # Drop the heading, keep the content
            i += 1
            continue

        result.append(lines[i])
        i += 1

    merged = "\n".join(result)

    # Pass 2: merge Best Practices + Common Mistakes into Rules.
    merged = _merge_rules_section(merged)

    # Pass 3: normalize blank lines.
    merged = re.sub(r"\n{3,}", "\n\n", merged)

    return merged.strip() + "\n"


def _extract_section(
    body: str, heading: str
) -> tuple[str | None, int, int]:
    """Find `## heading` section. Returns (content, start, end) or (None, -1, -1)."""
    pattern = rf"^## {re.escape(heading)}\s*\n"
    match = re.search(pattern, body, re.MULTILINE)
    if not match:
        return None, -1, -1

    start = match.start()
    # Find end: next ## heading or end of body
    tail = body[match.end():]
    next_match = re.search(r"^## ", tail, re.MULTILINE)
    end = match.end() + next_match.start() if next_match else len(body)

    content = body[match.end():end].strip()
    return content, start, end


def _merge_rules_section(body: str) -> str:
    bp_content, bp_start, bp_end = _extract_section(body, "Best Practices")
    cm_content, cm_start, cm_end = _extract_section(body, "Common Mistakes")

    if bp_content is None and cm_content is None:
        return body

    # Remove both (from highest offset down, so indexes don't shift).
    spans = []
    if bp_content is not None:
        spans.append((bp_start, bp_end))
    if cm_content is not None:
        spans.append((cm_start, cm_end))
    spans.sort(key=lambda s: s[0], reverse=True)
    for start, end in spans:
        body = body[:start] + body[end:]

    # Normalize Common Mistakes bullets to "Avoid <thing>".
    def _as_rule(line: str) -> str:
        m = re.match(r"^(\s*[-*]\s+)(.*)$", line)
        if not m:
            return line
        prefix, content = m.group(1), m.group(2).strip()
        if not content:
            return line
        # Already imperative? leave as-is.
        lower = content.lower()
        if lower.startswith(("don't", "do not", "avoid", "never")):
            return f"{prefix}{content}"
        return f"{prefix}Avoid {content[0].lower()}{content[1:]}"

    cm_lines = []
    if cm_content:
        for raw in cm_content.split("\n"):
            cm_lines.append(_as_rule(raw))

    parts = ["## Rules", ""]
    if bp_content:
        parts.append(bp_content)
    if cm_lines:
        if bp_content:
            parts.append("")
        parts.extend(cm_lines)

    new_section = "\n".join(parts).rstrip() + "\n"

    # Append merged section at end of body (after stripping).
    return body.rstrip() + "\n\n" + new_section


# ---------------------------------------------------------------------------
# Shared rendering helpers
# ---------------------------------------------------------------------------


def _rule_header(rule: dict) -> str:
    """Render the per-rule intro: description heading + optional globs note."""
    meta = rule["meta"]
    lines: list[str] = []
    if meta.get("description"):
        lines.append(f"### {meta['description']}")
    if meta.get("globs"):
        lines.append(f"> Applies to: `{meta['globs']}`")
    if lines:
        lines.append("")
    return "\n".join(lines)


def render_stack_bundle(
    rules: list[dict], header: str, *, condense_content: bool
) -> str:
    """Render a single-file bundle for a stack (windsurf/copilot/codex/etc.).

    No AUTO-GEN banner: these fragments are concatenated at install time and
    wrapped in somnio block markers, which already mark the file as managed.
    """
    out = [header, ""]
    for rule in rules:
        intro = _rule_header(rule)
        body = condense(rule["body"]) if condense_content else rule["body"].strip() + "\n"
        if intro:
            out.append(intro)
        out.append(body.strip())
        out.extend(["", "---", ""])
    return "\n".join(out)


# ---------------------------------------------------------------------------
# Writers
# ---------------------------------------------------------------------------


def write_file(file_path: Path, content: str) -> None:
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(content, encoding="utf-8")
    print(f"  wrote {file_path.relative_to(ROOT)}")


def clean_adapter(adapter_name: str) -> None:
    """Wipe the adapter output dir (except README.md) before regenerating."""
    adapter_dir = ROOT / "adapters" / adapter_name
    if not adapter_dir.exists():
        return
    for entry in adapter_dir.iterdir():
        if entry.name == "README.md":
            continue
        if entry.is_dir():
            shutil.rmtree(entry)
        else:
            entry.unlink()


# ---------------------------------------------------------------------------
# Generators (per-stack)
# ---------------------------------------------------------------------------


def generate_claude(groups: dict[str, list[dict]]) -> None:
    """Claude: modular .claude/rules/<stack>/*.md + minimal CLAUDE.md with @imports.

    Output per stack:
      adapters/claude/<stack>/CLAUDE.md
      adapters/claude/<stack>/rules/*.md  (condensed)
    """
    clean_adapter("claude")

    for stack, rules in groups.items():
        stack_title = stack[0].upper() + stack[1:]

        # Condensed rule files
        for rule in rules:
            condensed_body = condense(rule["body"])
            intro = _rule_header(rule)
            # Keep the per-rule intro at the top of the file so the description/globs
            # stay visible when Claude loads the rule on demand.
            content = (intro + condensed_body).strip() + "\n"
            out_path = (
                ROOT
                / "adapters"
                / "claude"
                / stack
                / "rules"
                / f"{rule['filename']}.md"
            )
            write_file(out_path, content)

        # Minimal CLAUDE.md fragment with @imports for this stack.
        # No AUTO-GEN header — fragments are concatenated at install time and
        # the somnio block markers already mark the file as auto-managed.
        lines = [
            f"## {stack_title} Rules",
            "",
        ]
        for rule in rules:
            lines.append(f"@.claude/rules/{stack}/{rule['filename']}.md")
        lines.append("")

        write_file(
            ROOT / "adapters" / "claude" / stack / "CLAUDE.md",
            "\n".join(lines),
        )


def generate_cursor(groups: dict[str, list[dict]]) -> None:
    """Cursor: one .mdc per rule, grouped by stack. Content is condensed."""
    clean_adapter("cursor")

    for stack, rules in groups.items():
        for rule in rules:
            meta = rule["meta"]
            condensed_body = condense(rule["body"])

            fm = ["---"]
            if meta.get("description"):
                fm.append(f'description: "{meta["description"]}"')
            if meta.get("globs"):
                fm.append(f"globs: {meta['globs']}")
            fm.append(f"alwaysApply: {meta.get('alwaysApply', 'false')}")
            fm.append("---")

            out_path = (
                ROOT
                / "adapters"
                / "cursor"
                / "rules"
                / stack
                / f"{stack}-{rule['filename']}.mdc"
            )
            write_file(out_path, "\n".join(fm) + "\n\n" + condensed_body)


def generate_antigravity(groups: dict[str, list[dict]]) -> None:
    """Antigravity: one .md per rule, grouped by stack. Condensed content."""
    clean_adapter("antigravity")

    for stack, rules in groups.items():
        for rule in rules:
            intro = _rule_header(rule)
            content = (intro + condense(rule["body"])).strip() + "\n"
            out_path = (
                ROOT
                / "adapters"
                / "antigravity"
                / "rules"
                / stack
                / f"{rule['filename']}.md"
            )
            write_file(out_path, content)


def generate_windsurf(groups: dict[str, list[dict]]) -> None:
    """Windsurf: single .windsurfrules per stack (condensed)."""
    clean_adapter("windsurf")

    for stack, rules in groups.items():
        stack_title = stack[0].upper() + stack[1:]
        header = (
            f"# Somnio Coding Standards — Windsurf ({stack_title})\n\n"
            "Follow these standards when generating or editing code."
        )
        content = render_stack_bundle(rules, header, condense_content=True)
        write_file(
            ROOT / "adapters" / "windsurf" / stack / ".windsurfrules",
            content,
        )


def generate_copilot(groups: dict[str, list[dict]]) -> None:
    """Copilot: single copilot-instructions.md per stack (condensed)."""
    clean_adapter("copilot")

    for stack, rules in groups.items():
        stack_title = stack[0].upper() + stack[1:]
        header = (
            f"# Somnio Coding Standards — GitHub Copilot ({stack_title})\n\n"
            "Follow these standards in all code suggestions."
        )
        content = render_stack_bundle(rules, header, condense_content=True)
        write_file(
            ROOT
            / "adapters"
            / "copilot"
            / stack
            / "copilot-instructions.md",
            content,
        )


def generate_codex(groups: dict[str, list[dict]]) -> None:
    """Codex: system-prompt.md per stack, condensed with code blocks stripped."""
    clean_adapter("codex")

    for stack, rules in groups.items():
        stack_title = stack[0].upper() + stack[1:]
        header = (
            f"# System Prompt — Somnio Coding Standards ({stack_title})\n\n"
            "You are an expert software engineer. "
            "Follow these coding standards precisely when generating code."
        )

        out = [header, ""]
        for rule in rules:
            intro = _rule_header(rule)
            body = condense(rule["body"])
            # Extra codex step: strip fenced code blocks from the condensed body.
            body = re.sub(r"```[\s\S]*?```", "", body)
            body = re.sub(r"\n{3,}", "\n\n", body).strip()
            if intro:
                out.append(intro)
            out.append(body)
            out.extend(["", "---", ""])

        write_file(
            ROOT / "adapters" / "codex" / stack / "system-prompt.md",
            "\n".join(out),
        )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

TARGETS = {
    "claude": generate_claude,
    "cursor": generate_cursor,
    "antigravity": generate_antigravity,
    "windsurf": generate_windsurf,
    "copilot": generate_copilot,
    "codex": generate_codex,
}


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate adapter files from canonical rules."
    )
    parser.add_argument(
        "--only",
        choices=TARGETS.keys(),
        help="Generate only a specific adapter.",
    )
    args = parser.parse_args()

    print("Loading rules from rules/...")
    groups = load_rules()
    rule_count = sum(len(r) for r in groups.values())
    print(f"  found {rule_count} rules across {len(groups)} stacks\n")

    if args.only:
        print(f"Generating {args.only}...")
        TARGETS[args.only](groups)
    else:
        for name, fn in TARGETS.items():
            print(f"Generating {name}...")
            fn(groups)

    print("\nDone.")


if __name__ == "__main__":
    main()
