# Somnio CLI

A Dart CLI that installs AI-powered audit skills into supported agents and executes multi-step project health and security audits. Each audit step runs in a fresh AI context, producing structured artifacts and a final report.

## Installation

```bash
dart pub global activate -sgit https://github.com/somnio-software/somnio-ai-tools.git --git-path cli
```

Requires Dart SDK 3.0+.

## Quick Start

```bash
# First-time setup: detect AI CLIs, install missing ones, install skills
somnio setup

# Run a Flutter health audit from a Flutter project root
somnio run fh

# Run a NestJS health audit with a specific agent and model
somnio run nh --agent gemini --model gemini-3-flash
```

Suppress the banner on any command with `--quiet` / `-q`:

```bash
somnio -q status
somnio -q run fh
```

## Commands

| Command | Description |
|---------|-------------|
| `somnio setup` | Detect AI CLIs, install missing ones, install skills via skills.sh |
| `somnio run <name-or-alias>` | Execute a multi-step audit from the target project directory |
| `somnio add <tech>` | Add a new technology's audit skills (scaffolds + registers) |
| `somnio status` | Show installed skills across all agents |
| `somnio update` | Update CLI and reinstall skills |
| `somnio uninstall` | Remove all Somnio skills from all agents |
| `somnio quote` | Display a random motivational quote |

### somnio setup

Primary installation command. Detects AI CLIs, installs missing ones, then installs all skills via `npx skills add` (skills.sh). Falls back to the built-in installer if npx is unavailable.

```bash
somnio setup              # Full wizard (detect CLIs + install via skills.sh)
somnio setup --skip-cli   # Skip CLI detection, go straight to skill install
somnio setup --force      # Skip all prompts, install everything
somnio setup --legacy     # Use built-in installer instead of skills.sh
```

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Skip all confirmation prompts |
| `--skip-cli` | | Skip CLI detection and installation |
| `--legacy` | | Use built-in installer instead of skills.sh |

### somnio run

Execute an audit step-by-step from the target project's root directory. Each rule runs in a fresh AI context, saving findings as artifacts and generating a final report.

```bash
somnio run fh                          # Flutter health audit (auto-detect agent)
somnio run nh --agent gemini           # NestJS health audit with Gemini CLI
somnio run sa --model opus             # Security audit with a specific model
somnio run fh --skip-validation        # Skip project type check
somnio run fh --no-preflight           # Send all steps to AI
```

| Flag | Short | Description |
|------|-------|-------------|
| `--agent` | `-a` | AI CLI to use (auto-detected if omitted) |
| `--model` | `-m` | Model to use (skips interactive selection) |
| `--skip-validation` | | Skip project type check |
| `--no-preflight` | | Skip pre-flight and send all steps to AI |

**Available audits:**

| Name | Aliases | Description |
|------|---------|-------------|
| flutter-health-audit | fh, somnio-fh | Flutter project health audit |
| flutter-best-practices | fp, somnio-fp | Flutter code quality check |
| nestjs-health-audit | nh, somnio-nh | NestJS project health audit |
| nestjs-best-practices | np, somnio-np | NestJS code quality check |
| security-audit | sa, somnio-sa | Security audit (any stack) |

**Execution flow:**

1. Parse arguments (`--agent`, `--model`, `--skip-validation`, `--no-preflight`)
2. Validate project type (Flutter needs `pubspec.yaml`, NestJS needs `package.json` + `@nestjs/core`)
3. Run pre-flight steps (tool install, version alignment, test coverage) -- no AI needed
4. Resolve AI agent and model
5. Parse SKILL.md for step order
6. Execute each step in a fresh AI process, saving artifacts to `./reports/.artifacts/`
7. Generate final report to `./reports/`

**Token usage tracking:**

Each AI step displays real-time token consumption when it completes:

```
Step  5/13: flutter_architecture_analyzer  IT: 38.2K  OT: 4.1K  Time: 3m 12s  Cost: $0.28
Step  6/13: flutter_state_management       IT: 35.7K  OT: 3.8K  Time: 2m 45s  Cost: $0.25
```

A summary is printed at the end of the run with total tokens, cost, and time breakdown.

### somnio add

Add a new technology's audit skills to the repository.

```bash
somnio add react       # Scaffold new skills/react-* directories (wizard mode)
somnio add flutter     # Auto-detect existing skills/flutter-* bundles
```

Two modes: **wizard** (when `skills/{tech}-*` does not exist, scaffolds new skill directories) and **auto-detect** (when `skills/{tech}-*` exists, scans and registers valid bundles).

### somnio status

Show CLI availability and installed skills across all agents.

### somnio update

Update the CLI to the latest version and reinstall all skills.

### somnio uninstall

Remove all Somnio skills from all agents. Prompts for confirmation unless `--force` is passed.

## Supported AI Agents

Somnio uses a data-driven agent registry. Adding a new agent requires a single `AgentConfig` entry.

**CLI agents** (can execute audits via `somnio run`):
Claude Code, Cursor, Gemini CLI, Codex, Augment Code, Amp, Aider, Cline, OpenCode, CodeBuddy, Qwen CLI

**IDE-only agents** (receive skill files via `somnio setup`):
GitHub Copilot, Windsurf, Roo Code, Kilo Code, Amazon Q

## Architecture

```
cli/lib/src/
├── agents/          # Agent registry and config models
├── commands/        # CLI command classes (one per command)
├── content/         # Skill registry and content loader
├── installers/      # File writers (agent-specific install paths)
├── runner/          # Audit execution engine
│   ├── agent_resolver.dart   # Auto-detect available AI CLIs
│   ├── plan_parser.dart      # Extract steps from SKILL.md
│   ├── preflight.dart        # Pre-flight steps (no AI needed)
│   └── step_executor.dart    # Spawn fresh AI CLI per step
├── transformers/    # Convert plans + YAML rules per agent format
└── utils/           # Shared helpers
```

**Key layers:**

- **Skill Registry** (`content/skill_registry.dart`) -- Static registry of all audit skill bundles. Each `SkillBundle` defines paths to its plan, rules, workflow, and template.
- **Agent Registry** (`agents/agent_registry.dart`) -- Data-driven definitions for all supported agents. Each `AgentConfig` declares binary, prompt style, install format, models, and token parser.
- **Transformers** -- Convert SKILL.md and references into agent-specific formats: `skillDir` (Claude), `singleFile` (Cursor), `workflow` (Gemini), `markdown` (generic).
- **Runner** -- Executes audits step-by-step, spawning a fresh AI CLI process per step via `AgentConfig.buildArgs()`.

## Development

```bash
git clone https://github.com/somnio-software/somnio-ai-tools
cd somnio-ai-tools/cli

dart pub get                              # Install dependencies
dart analyze                              # Run static analysis
dart test                                 # Run all tests
dart test test/src/utils/banner_test.dart  # Run a single test file
dart run bin/somnio.dart                  # Run CLI locally
dart pub global activate --source path .  # Install local version globally
```

Version is stored in both `lib/src/version.dart` and `pubspec.yaml` -- keep them in sync.
