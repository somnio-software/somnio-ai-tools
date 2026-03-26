#!/usr/bin/env python3
"""
Generates tool-specific adapter files from the canonical source in rules/.

Usage:
  python3 scripts/generate.py                    # regenerate all adapters
  python3 scripts/generate.py --only cursor
  python3 scripts/generate.py --only claude
  python3 scripts/generate.py --only copilot
  python3 scripts/generate.py --only windsurf
  python3 scripts/generate.py --only codex
  python3 scripts/generate.py --only antigravity

Source of truth: rules/**/*.md
Generated outputs (all inside adapters/):
  adapters/cursor/rules/**/*.mdc
  adapters/claude/CLAUDE.md
  adapters/copilot/copilot-instructions.md
  adapters/windsurf/.windsurfrules
  adapters/codex/system-prompt.md
  adapters/antigravity/rules/**/*.md
"""

import argparse
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

AUTO_GEN_COMMENT = (
    "# AUTO-GENERATED — do not edit directly. "
    "Edit rules/ and run: cd agent-rules && python3 scripts/generate.py\n"
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def parse_frontmatter(content: str) -> tuple[dict[str, str], str]:
    """Parse YAML-like frontmatter and return (meta, body)."""
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


def collect_md_files(directory: Path) -> list[Path]:
    """Recursively collect all .md files under a directory, sorted."""
    return sorted(directory.rglob("*.md"))


def load_rules() -> dict[str, list[dict]]:
    """Load all rules from rules/, grouped by subfolder name."""
    rules_dir = ROOT / "rules"
    files = collect_md_files(rules_dir)

    groups: dict[str, list[dict]] = {}
    for file_path in files:
        rel = file_path.relative_to(rules_dir)
        parts = rel.parts
        group = parts[0] if len(parts) > 1 else "general"
        filename = file_path.stem

        content = file_path.read_text(encoding="utf-8")
        meta, body = parse_frontmatter(content)

        groups.setdefault(group, []).append(
            {"file_path": file_path, "meta": meta, "body": body, "filename": filename}
        )

    return groups


# ---------------------------------------------------------------------------
# Renderers
# ---------------------------------------------------------------------------


def render_full(groups: dict[str, list[dict]], header: str) -> str:
    """Full content renderer: all sections with headers and glob notes."""
    lines = [AUTO_GEN_COMMENT, header, ""]

    for group, rules in groups.items():
        group_title = group[0].upper() + group[1:]
        lines.extend([f"## {group_title} Rules", ""])

        for rule in rules:
            meta, body = rule["meta"], rule["body"]
            if meta.get("description"):
                lines.append(f"### {meta['description']}")
            if meta.get("globs"):
                lines.append(f"> Applies to: `{meta['globs']}`")
            lines.extend(["", body.strip(), "", "---", ""])

    return "\n".join(lines)


def render_condensed(groups: dict[str, list[dict]], header: str) -> str:
    """Condensed renderer for Codex: strips code blocks, keeps prose only."""
    lines = [AUTO_GEN_COMMENT, header, ""]

    for group, rules in groups.items():
        group_title = group[0].upper() + group[1:]
        lines.extend([f"## {group_title} Rules", ""])

        for rule in rules:
            meta, body = rule["meta"], rule["body"]
            if meta.get("description"):
                lines.extend([f"### {meta['description']}", ""])

            condensed = re.sub(r"```[\s\S]*?```", "", body)
            condensed = re.sub(r"\n{3,}", "\n\n", condensed).strip()
            lines.extend([condensed, "", "---", ""])

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Writers
# ---------------------------------------------------------------------------


def write_file(file_path: Path, content: str) -> None:
    """Write content to file, creating parent directories as needed."""
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(content, encoding="utf-8")
    print(f"  wrote {file_path.relative_to(ROOT)}")


# ---------------------------------------------------------------------------
# Generators
# ---------------------------------------------------------------------------


def generate_cursor(groups: dict[str, list[dict]]) -> None:
    for group, rules in groups.items():
        for rule in rules:
            meta, body, filename = rule["meta"], rule["body"], rule["filename"]
            out_name = f"{group}-{filename}.mdc"
            out_path = ROOT / "adapters" / "cursor" / "rules" / group / out_name

            fm_lines = ["---"]
            if meta.get("description"):
                fm_lines.append(f'description: "{meta["description"]}"')
            if meta.get("globs"):
                fm_lines.append(f"globs: {meta['globs']}")
            fm_lines.append(f"alwaysApply: {meta.get('alwaysApply', 'false')}")
            fm_lines.append("---")

            write_file(out_path, "\n".join(fm_lines) + "\n" + body)


def generate_claude(groups: dict[str, list[dict]]) -> None:
    header = (
        "# Somnio Agent Rules — Claude Code\n\n"
        "Copy this file (or relevant sections) into your project's `CLAUDE.md`."
    )
    write_file(ROOT / "adapters" / "claude" / "CLAUDE.md", render_full(groups, header))


def generate_copilot(groups: dict[str, list[dict]]) -> None:
    header = (
        "# Somnio Coding Standards — GitHub Copilot\n\n"
        "Follow these standards in all code suggestions."
    )
    write_file(
        ROOT / "adapters" / "copilot" / "copilot-instructions.md",
        render_full(groups, header),
    )


def generate_windsurf(groups: dict[str, list[dict]]) -> None:
    header = (
        "# Somnio Coding Standards — Windsurf\n\n"
        "Follow these standards when generating or editing code."
    )
    write_file(
        ROOT / "adapters" / "windsurf" / ".windsurfrules",
        render_full(groups, header),
    )


def generate_codex(groups: dict[str, list[dict]]) -> None:
    header = (
        "# System Prompt — Somnio Coding Standards\n\n"
        "You are an expert software engineer. "
        "Follow these coding standards precisely when generating code."
    )
    write_file(
        ROOT / "adapters" / "codex" / "system-prompt.md",
        render_condensed(groups, header),
    )


def generate_antigravity(groups: dict[str, list[dict]]) -> None:
    for group, rules in groups.items():
        for rule in rules:
            out_path = (
                ROOT / "adapters" / "antigravity" / "rules" / group / f"{rule['filename']}.md"
            )
            write_file(out_path, rule["body"])


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

TARGETS = {
    "cursor": generate_cursor,
    "claude": generate_claude,
    "copilot": generate_copilot,
    "windsurf": generate_windsurf,
    "codex": generate_codex,
    "antigravity": generate_antigravity,
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
    print(f"  found {rule_count} rules across {len(groups)} groups\n")

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
