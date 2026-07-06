# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`somnio-ai-tools` ships AI-agent **skills**, **agent rules**, **hooks**, and **plugins** for Claude Code, Cursor, and 40+ other agents — plus the **Somnio CLI** (a Dart tool) that installs them and runs multi-step audits from the terminal. Skills/rules are plain markdown; the CLI is the only compiled code.

## Repository layout

| Path | What lives here |
|------|-----------------|
| `cli/` | The Somnio CLI — a Dart 3 package (`pubspec.yaml`, `bin/somnio.dart`). The only real codebase. |
| `skills/` | Markdown skill bundles (one dir each: `SKILL.md` + `references/` + `assets/`). Distributed via skills.sh. |
| `agent-rules/` | Canonical coding-standard rules (`rules/<stack>/*.md`) + generated per-agent adapters (`adapters/`). |
| `commands/`, `hooks/` | Claude Code slash-command markdown and shell hooks (e.g. `hooks/work-log-stop.sh`). |
| `plugins/`, `.claude-plugin/` | Claude Desktop App (Cowork) plugin packages + `marketplace.json`. |
| `docs/` | Source-of-truth docs. **`docs/architecture.md` is the best deep-dive — read it before non-trivial CLI work.** |

## CLI development (all commands run from `cli/`)

```bash
dart pub get                                # install deps
dart analyze                                # static analysis (must pass)
dart test                                   # all tests
dart test test/src/runner/plan_parser_test.dart   # single test file
dart test --coverage                        # with coverage
dart run bin/somnio.dart <args>             # run CLI locally
dart pub global activate --source path .    # install local build globally
```

There is no build step — Dart runs from source. CI gate is `dart analyze` + `dart test`.

### Version bumps

The version lives in **two** places that must stay in sync: `cli/pubspec.yaml` and `cli/lib/src/version.dart` (`packageVersion`). Update both, and add an entry to `cli/CHANGELOG.md`.

## CLI architecture (the big picture)

The CLI is **data-driven**: agents and skills are declared as config/registry entries, not as branching code paths. Adding support is almost always a single registry edit, no new code paths.

- **Two registries are the spine:**
  - `cli/lib/src/content/skill_registry.dart` — every installable `SkillBundle` (paths to its `SKILL.md`, references, assets).
  - `cli/lib/src/agents/agent_registry.dart` — every supported agent as an `AgentConfig` (binary, prompt style, install format, models, token parser).
- **Flow:** `content_loader` reads a skill's markdown → a **transformer** (`transformers/`, one per install format: `skillDir`/Claude, `singleFile`/Cursor, `workflow`, `markdown`) reshapes it for the target agent → an **installer** (`installers/`) writes it to the agent's path (`~/.claude/skills/`, etc.).
- **Runner** (`runner/`) powers `somnio run <alias>`: validates project type → runs pre-flight shell steps (no AI) → resolves an AI CLI → `plan_parser` extracts ordered steps from the `SKILL.md` "Rule Execution Order" section → `step_executor` spawns a **fresh AI CLI process per step** (deliberate: 13-step audits would overflow one context window) → artifacts land in `./reports/.artifacts/`, final report in `./reports/`.
- **Workflow** subsystem (`workflow/`) — separate engine for custom multi-step pipelines with wave-based parallel execution (`workflow_wave_planner.dart`).
- Commands are registered in `cli/lib/src/cli_runner.dart` (`SomnioCliRunner`); one class per command in `commands/`.

### Extension points (where to add things)

- **New skill:** scaffold with `somnio add <framework>`, or manually create `skills/<name>/{SKILL.md,references,assets}` and register a `SkillBundle` in `skill_registry.dart`.
- **New agent:** add one `AgentConfig` to `agent_registry.dart` (and its `agents` list). No other files change.
- **New CLI command:** add a `Command` class in `commands/` and `addCommand(...)` it in `cli_runner.dart`.

## Agent rules (`agent-rules/`)

`rules/<stack>/*.md` (django, fastapi, flask, flutter, functions, nestjs, python, react, typescript) are the **single source of truth**. Adapters under `adapters/` (claude, cursor, antigravity, copilot, codex, windsurf) are **generated — never edit them directly**. After editing a rule, regenerate:

```bash
cd agent-rules
python3 scripts/generate.py                 # all adapters
python3 scripts/generate.py --only claude   # one target
```

> Note: `CONTRIBUTING.md` still references `npm run generate` / `generate.js`; the actual generator is `python3 scripts/generate.py`. To make an adapter installable via `somnio rules install`, also register it in `cli/lib/src/content/agent_rule_registry.dart`.

## Skill file format

Each `SKILL.md` starts with YAML frontmatter (`name`, `description`, `allowed-tools`). The `description` doubles as the agent's trigger detection — it lists the phrases that activate the skill, so keep it specific. For runner-executed audits, the step order comes from the "Rule Execution Order" section, with each step mapping to a file in `references/`.

## Conventions

- **Commits:** Conventional Commits. **Branches:** `{type}/{TICKET}_{description}`. (Dedicated `git-commit-format` / `git-branch-format` skills exist for these.)
- Markdown skills should not invent data — audits are explicitly evidence-based; the same applies when authoring skill instructions.
