# Agent Rules

Coding standards for NestJS, Flutter, and React that are automatically applied by AI coding agents.

## Architecture

```
agent-rules/
├── rules/              # Source of truth (edit here)
│   ├── flutter/        # 5 rules
│   ├── nestjs/         # 9 rules
│   └── react/          # 6 rules
├── adapters/           # Generated outputs (do not edit)
│   ├── antigravity/    # Individual .md files (body only)
│   ├── claude/         # Single consolidated CLAUDE.md
│   ├── codex/          # Single condensed file (no code blocks)
│   ├── copilot/        # Single consolidated copilot-instructions.md
│   ├── cursor/         # Individual .mdc files with frontmatter
│   └── windsurf/       # Single consolidated .windsurfrules
└── scripts/
    └── generate.py     # Transformation engine (Python 3, no dependencies)
```

## How it works

1. Rules are written as `.md` files in `rules/` with YAML frontmatter (`description`, `globs`, `alwaysApply`)
2. `scripts/generate.py` transforms them into the format each agent tool expects
3. Each adapter gets the same 20 rules in a different packaging:
   - **Cursor**: individual `.mdc` files with frontmatter for auto-apply by glob pattern
   - **Claude/Copilot/Windsurf**: all rules concatenated into a single file
   - **Codex**: condensed version with code blocks stripped (token optimization)
   - **Antigravity**: individual `.md` files with frontmatter stripped

## Generating adapter outputs

The generated files are **not committed** to the repository. They are produced on demand.

### Via the Somnio CLI (recommended)

The CLI generates adapter files automatically before installing, so no manual step is needed:

```bash
somnio rules install
```

### Manually (without the CLI)

Requires Python 3.

```bash
cd agent-rules
python3 scripts/generate.py                    # All adapters
python3 scripts/generate.py --only cursor      # Cursor only
python3 scripts/generate.py --only claude      # Claude only
python3 scripts/generate.py --only copilot     # Copilot only
python3 scripts/generate.py --only windsurf    # Windsurf only
python3 scripts/generate.py --only codex       # Codex only
python3 scripts/generate.py --only antigravity # Antigravity only
```

After generating, copy the output to your project manually. Each adapter's `README.md` has specific instructions:

| Agent | Generated output | Copy to |
|-------|-----------------|---------|
| Claude Code | `adapters/claude/CLAUDE.md` | `CLAUDE.md` (project root) or `~/.claude/CLAUDE.md` (global) |
| Cursor | `adapters/cursor/rules/` | `.cursor/rules/` |
| Copilot | `adapters/copilot/copilot-instructions.md` | `.github/copilot-instructions.md` |
| Windsurf | `adapters/windsurf/.windsurfrules` | `.windsurfrules` (project root) or `~/.windsurfrules` (global) |
| Codex | `adapters/codex/system-prompt.md` | `AGENTS.md` |
| Antigravity | `adapters/antigravity/rules/` | `rules/` |

## Adding or editing rules

1. Edit or create a `.md` file in the appropriate `rules/<stack>/` folder
2. Include YAML frontmatter:
   ```yaml
   ---
   description: Short description of what this rule covers
   globs: "**/*.service.ts"
   alwaysApply: false
   ---
   ```
3. Commit only the source rule file (adapter outputs are gitignored)
4. The next `somnio rules install` will pick up the changes automatically

## Installing rules in a project

### Via the Somnio CLI

```bash
somnio rules install                          # interactive
somnio rules install --agent claude --global  # Claude Code, global
somnio rules install --agent cursor --project # Cursor, current project
somnio rules install --all --project          # all detected agents, project scope
```

The CLI detects which agents are installed on your machine, generates the adapter files, and copies them to the right location.

### Manually (without the CLI)

1. Generate the adapter outputs (see [Generating adapter outputs](#generating-adapter-outputs))
2. Copy the files to the target location (see the table above or each adapter's `README.md`)
