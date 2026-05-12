[Home](../README.md) > CLI Reference

# Somnio CLI

A Dart CLI that installs AI-powered audit skills into supported agents and executes multi-step project health and security audits. Each audit step runs in a fresh AI context, producing structured artifacts and a final report.

## Installation

Requires Dart SDK 3.0+.

```bash
dart pub global activate -sgit https://github.com/somnio-software/somnio-ai-tools.git --git-path cli
```

## Quick Start

```bash
somnio setup          # Detect AI CLIs, install skills
somnio run fh         # Run Flutter health audit
somnio run nh --agent gemini --model gemini-3-flash  # Specific agent + model
somnio -q status      # Quiet mode (suppress banner)
```

---

## Commands

| Command | Description |
|---------|-------------|
| `somnio setup` | Detect AI CLIs, install missing ones, install skills via skills.sh |
| `somnio run <name-or-alias>` | Execute a multi-step audit from the target project directory |
| `somnio install` | Install skills to a specific agent or all agents |
| `somnio add <tech>` | Add a new technology's audit skills (scaffolds + registers) |
| `somnio status` | Show installed skills across all agents |
| `somnio update` | Update CLI and reinstall skills |
| `somnio uninstall` | Remove all Somnio skills from all agents |
| `somnio rules` | Install coding-standard rules for all detected agents |
| `somnio workflow` | Create, configure, and run custom workflows |
| `somnio quote` | Display a random motivational quote |

### somnio setup

Primary installation command. Detects AI CLIs, installs missing ones, then installs all skills via `npx skills add`.

```bash
somnio setup              # Full wizard
somnio setup --skip-cli   # Skip CLI detection
somnio setup --force      # Skip all prompts
somnio setup --legacy     # Use built-in installer instead of skills.sh
```

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Skip all confirmation prompts |
| `--skip-cli` | | Skip CLI detection and installation |
| `--legacy` | | Use built-in installer instead of skills.sh |
| `--verbose` | `-v` | Show detailed output (npx stdout, file-by-file progress) |

### somnio run

Execute an audit step-by-step from the target project's root directory. Each step runs in a fresh AI context, saving findings as artifacts and generating a final report.

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

### somnio install

Install skills to a specific agent or all agents at once.

```bash
somnio install --agent claude   # Install to Claude Code only
somnio install --all            # Install to all detected agents
somnio install --force          # Overwrite existing files
```

### somnio add

Add a new technology's audit skills to the repository.

```bash
somnio add react       # Scaffold new skills/react-* directories (wizard mode)
somnio add flutter     # Auto-detect existing skills/flutter-* bundles
```

Two modes: **wizard** (when `skills/{tech}-*` does not exist, scaffolds new skill directories) and **auto-detect** (when `skills/{tech}-*` exists, scans and registers valid bundles).

### somnio update

Update the CLI to the latest version and reinstall all skills across all agents.

```bash
somnio update             # Update CLI + reinstall skills via skills.sh
somnio update --verbose   # Show each removed file and npx output
somnio update --legacy    # Use built-in installer instead of skills.sh
```

| Flag | Short | Description |
|------|-------|-------------|
| `--legacy` | | Use built-in installer instead of skills.sh |
| `--verbose` | `-v` | Show detailed output (removed files, npx stdout) |

### somnio uninstall

Remove all Somnio-installed skills, commands, workflows, and rules from all agents.

```bash
somnio uninstall            # Prompts for confirmation, then removes everything
somnio uninstall --force    # Skip confirmation prompt
somnio uninstall --verbose  # Show each removed file
```

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Skip the confirmation prompt |
| `--verbose` | `-v` | Show each removed file |

### somnio rules

Install global coding-standard rules into detected agents. Rules are injected into each agent's native rules file (e.g., `CLAUDE.md`, `.cursor/rules/`, `.windsurfrules`).

```bash
somnio rules install                           # Interactive: detect agents + choose scope
somnio rules install --agent claude --global   # Claude Code, global scope
somnio rules install --agent cursor --project  # Cursor, current project
somnio rules install --all --global            # All detected agents, global
```

See the [Agent Rules guide](agent-rules.md) for available rule packs and details.

### somnio workflow

Create, configure, and run custom workflows.

```bash
somnio workflow plan <name>   # Create a new workflow
somnio workflow run <name>    # Execute a workflow
somnio workflow config        # Configure model assignments
somnio workflow list          # List available workflows
```

See the [Workflow Guide](workflows.md) for details.

---

## Available Audits

| Name | Aliases | Description |
|------|---------|-------------|
| `flutter-health-audit` | `fh`, `somnio-fh` | Flutter project health audit (13 steps) |
| `flutter-best-practices` | `fp`, `somnio-fp` | Flutter code quality check |
| `nestjs-health-audit` | `nh`, `somnio-nh` | NestJS project health audit (13 steps) |
| `nestjs-best-practices` | `np`, `somnio-np` | NestJS code quality check |
| `react-health-audit` | `rh`, `somnio-rh` | React project health audit (13 steps) |
| `react-best-practices` | `rp`, `somnio-rp` | React code quality check |
| `security-audit` | `sa`, `somnio-sa` | Security audit (any stack, 11 steps) |

See the [Skills Catalog](skills.md) for full descriptions.

---

## Execution Flow

When you run `somnio run <alias>`:

1. **Parse arguments** — `--agent`, `--model`, `--skip-validation`, `--no-preflight`
2. **Validate project type** — Flutter needs `pubspec.yaml`, NestJS needs `package.json` + `@nestjs/core`
3. **Run pre-flight steps** — Tool installation, version alignment, test coverage (no AI needed)
4. **Resolve AI agent and model** — Auto-detect or use `--agent` flag
5. **Parse SKILL.md** — Extract step order from the execution plan
6. **Execute each step** — Spawn a fresh AI CLI process per step, save artifacts to `./reports/.artifacts/`
7. **Generate final report** — Write to `./reports/`

### Token Usage Tracking

Each step displays real-time token consumption:

```
Step  5/13: flutter_architecture_analyzer  IT: 38.2K  OT: 4.1K  Time: 3m 12s  Cost: $0.28
Step  6/13: flutter_state_management       IT: 35.7K  OT: 3.8K  Time: 2m 45s  Cost: $0.25
```

A summary is printed at the end with total tokens, cost, and time breakdown.

---

## Supported AI Agents

Somnio uses a data-driven agent registry. Adding a new agent requires a single `AgentConfig` entry.

**CLI agents** (can execute audits via `somnio run`):
Claude Code, Cursor, Gemini CLI, Antigravity, Codex, Augment Code, Amp, Aider, Cline, OpenCode, CodeBuddy, Qwen CLI

**IDE-only agents** (receive skill files via `somnio setup`):
GitHub Copilot, Windsurf, Roo Code, Kilo Code, Amazon Q

---

**See also:** [Installation](installation.md) | [Skills Catalog](skills.md) | [Architecture](architecture.md)
