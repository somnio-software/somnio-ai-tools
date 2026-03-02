# Somnio CLI

CLI tool that installs AI agent skills from the technology-tools repository into any supported AI agent. Supports 16 agents out of the box via an extensible agent registry.

## Installation

```bash
dart pub global activate --source git https://github.com/somnio-software/technology-tools --git-path cli
```

## Quick Start

First-time setup — the wizard detects your CLIs, helps install missing ones, and installs skills:

```bash
somnio setup
```

Already have your CLIs installed? Skip the CLI detection/installation step:

```bash
somnio setup --skip-cli
```

Suppress the banner on any command with `--quiet` / `-q`:

```bash
somnio -q status
somnio -q run fh
```

## Supported Agents

Somnio uses a data-driven agent registry. Adding a new agent requires a single `AgentConfig` entry — no other files change.

### CLI Agents (for `somnio run`)

These agents have a CLI binary that can execute audits step-by-step:

| Agent | Binary | Prompt Style | Auto-approve | Output |
|-------|--------|-------------|--------------|--------|
| Claude Code | `claude` | `-p "prompt"` | `--allowedTools Read,Bash,Glob,Grep,Write` | `--output-format json` |
| Cursor | `agent` | `... "prompt"` | `--print --force` | `--output-format json` |
| Gemini CLI | `gemini` | `-p "prompt"` | `--yolo` | `-o json` |
| Codex | `codex` | `exec "prompt"` | `--dangerously-bypass-approvals-and-sandbox` | `--json` |
| Augment Code | `auggie` | `... "prompt"` | `--print` | `--output-format json` |
| Amp | `amp` | `-x "prompt"` | - | `--stream-json` |
| Aider | `aider` | `--message "prompt"` | `--yes-always` | - |
| Cline | `cline` | `... "prompt"` | `-y` | `--json` |
| OpenCode | `opencode` | `-p "prompt"` | - | `-f json` |
| CodeBuddy | `codebuddy` | `-p "prompt"` | `--dangerously-skip-permissions` | `--output-format json` |
| Qwen CLI | `qwen` | `-p "prompt"` | `--yolo` | `--output-format json` |

### IDE-Only Agents (for `somnio install`)

These agents receive skill files but cannot execute audits:

| Agent | Install Path | Scope |
|-------|-------------|-------|
| GitHub Copilot | `.github/agents/` | Project |
| Windsurf | `.windsurf/workflows/` | Project |
| Roo Code | `.roo/rules/` | Project |
| Kilo Code | `.kilocode/rules/` | Project |
| Amazon Q | `.amazonq/prompts/` | Project |

## Commands

### `somnio setup`

Full guided setup wizard. The primary entry point for new and existing users.

```bash
somnio setup              # Full wizard (detect CLIs + install missing + install skills)
somnio setup --skip-cli   # Skip CLI detection/install, just detect agents and install skills
somnio setup --force      # Skip all prompts, install everything
```

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Skip all confirmation prompts, auto-install missing CLIs |
| `--skip-cli` | | Skip CLI detection and installation (go straight to skill install) |

**What it does:**

1. **Step 1/3: Detect CLIs** — checks PATH for all registered CLI agent binaries *(skipped with `--skip-cli`)*
2. **Step 2/3: Install missing CLIs** — offers `npm install -g` for npm-based CLIs, shows manual instructions for others *(skipped with `--skip-cli`)*
3. **Step 3/3: Install skills** — detects all available agents and installs all skill bundles to each

> **Note:** `somnio init` still works as a hidden alias for `somnio setup --skip-cli`.

### `somnio install`

Install skills to any supported agent. This is the primary installation command.

```bash
somnio install --agent claude      # Install to Claude Code
somnio install --agent copilot     # Install to GitHub Copilot
somnio install --agent windsurf    # Install to Windsurf
somnio install --agent roo         # Install to Roo Code
somnio install --all               # Install to all detected agents
```

| Flag | Short | Description |
|------|-------|-------------|
| `--agent` | `-a` | Target agent ID (see supported agents table) |
| `--all` | | Install to all detected agents |
| `--force` | `-f` | Overwrite existing skills without prompting |

**How install formats work:**

Each agent has a specific install format that determines how skill files are structured:

| Format | Agents | Structure |
|--------|--------|-----------|
| `skillDir` | Claude Code | Directory per skill: `SKILL.md` + `rules/*.md` + `templates/` |
| `singleFile` | Cursor | One self-contained `.md` per skill (plan + rules embedded) |
| `workflow` | Gemini/Antigravity | Workflow file + `somnio_rules/` directory |
| `markdown` | Copilot, Windsurf, Roo, Kilo, Amazon Q, new CLIs | Single `.md` per skill with header + plan + rules |

### `somnio claude`

Install skills into Claude Code. Alias for `somnio install --agent claude`.

```bash
somnio claude
somnio claude --force
```

### `somnio cursor`

Install commands into Cursor. Alias for `somnio install --agent cursor`.

```bash
somnio cursor
somnio cursor --force
```

### `somnio antigravity`

Install workflows into Antigravity/Gemini. Alias for `somnio install --agent gemini`.

```bash
somnio antigravity
somnio antigravity --force
```

### `somnio update`

Update the CLI to the latest version and reinstall all skills to previously configured agents.

```bash
somnio update
```

Runs `dart pub global activate` under the hood, then force-reinstalls skills to any agents that were previously set up.

### `somnio status`

Show CLI availability and installed skills.

```bash
somnio status
somnio -q status    # Without the banner
```

Displays two tables:
- **CLI Availability** — checks all registered CLI agents for binary availability on PATH
- **Installed Skills** — registry-driven scan of all 17 agents showing installed skills, rules, and locations

### `somnio uninstall`

Remove all Somnio skills, commands, and workflows from all agents.

```bash
somnio uninstall          # Prompts for confirmation before deleting
somnio uninstall --force  # Skip confirmation prompt
```

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Skip confirmation prompt |

Shows what will be removed and asks for confirmation before proceeding. Scans all registered agents and removes files matching the somnio prefix.

### `somnio run`

Execute a health audit step-by-step from the target project's terminal. Each rule runs in a fresh AI context, saving findings as artifacts and generating a final report.

**Must be run from the project root** (e.g., inside a Flutter or NestJS repo).

```bash
# From a Flutter project root
somnio run fh

# From a NestJS project root
somnio run nh

# Force a specific AI CLI
somnio run fh --agent gemini
somnio run fh --agent codex

# Skip project type validation
somnio run fh --skip-validation

# Skip CLI pre-flight (send all steps to AI)
somnio run fh --no-preflight
```

| Flag | Short | Description |
|------|-------|-------------|
| `--agent` | `-a` | AI CLI to use (auto-detected if omitted). Any registered CLI agent ID works |
| `--model` | `-m` | Model to use (skips interactive selection) |
| `--skip-validation` | | Skip project type check (e.g., pubspec.yaml for Flutter) |
| `--no-preflight` | | Skip CLI pre-flight and send all steps to AI |

**Model selection:**

When `--model` is not provided, the CLI presents an interactive menu with the available models for the resolved agent. Each agent has a default model optimized for cost and speed:

| Agent | Default | Example models |
|-------|---------|----------------|
| Claude | `haiku` | `haiku`, `sonnet`, `opus` |
| Cursor | `auto` | `auto`, `claude-4.6-opus`, `gpt-5.3-codex`, `composer-1.5`, ... |
| Gemini | `gemini-3-flash` | `gemini-3-flash`, `gemini-3.1-pro-preview`, `gemini-2.5-pro` |
| Codex | `gpt-5.3-codex` | `gpt-5.3-codex`, `gpt-5.2-codex`, `gpt-5.1-codex-max`, `gpt-5.1-codex-mini` |
| Auggie | `claude-sonnet-4-5` | `claude-opus-4-6`, `claude-sonnet-4-5`, `gpt-5.3` |
| Qwen | `qwen3-coder-plus` | `qwen3-coder-plus`, `qwen3-coder-next`, `qwen3-5-plus` |

Press Enter at the prompt to accept the default, or pass `--model` to skip the prompt entirely:

```bash
somnio run fh                       # Interactive model selection
somnio run fh --model opus           # Skip prompt, use opus
somnio run nh --agent gemini -m gemini-3-pro
```

**Available codes** are derived from the skill registry — any health audit bundle registered via `somnio add` is automatically available:

| Code | Audit | Technology |
|------|-------|------------|
| `fh` | Flutter Project Health Audit | Flutter |
| `fp` | Flutter Best Practices Check | Flutter |
| `nh` | NestJS Project Health Audit | NestJS |
| `np` | NestJS Best Practices Check | NestJS |
| `sa` | Security Audit | Any |

**How it works:**

1. **Validates** the current directory is the correct project type
2. **Pre-flight** — the CLI handles tool installation, version alignment, version validation, and test coverage directly (no AI needed). These steps complete in seconds instead of minutes
3. **AI steps** — analysis rules (architecture, security, code quality, etc.) each run in a fresh AI context via `agentConfig.buildArgs()`
4. **Report** — the final step reads all artifacts and generates a Google Docs-ready audit report

Pre-flight artifacts and the previous report are automatically cleaned before each run. Use `--no-preflight` to send all steps to AI (useful for debugging or when running as a skill in an IDE).

**Token usage tracking:**

Each AI step displays real-time token consumption and cost when it completes:

```
✓ Step  5/13: flutter_architecture_analyzer  IT: 38.2K  OT: 4.1K  Time: 3m 12s  Cost: $0.28
✓ Step  6/13: flutter_state_management       IT: 35.7K  OT: 3.8K  Time: 2m 45s  Cost: $0.25
```

- **IT** — Input tokens (includes cache)
- **OT** — Output tokens
- **Cost** — USD cost (Claude only; agents without token parsers show time only)

A summary is printed at the end of the run:

```
────────────────────────────────────────────────────
Total tokens  ─  Input: 317.3K  Output: 35.1K
Total cost    ─  $2.31
Total time    ─  25m 55s  (AI: 25m 55s | Pre-flight: ~12s)
────────────────────────────────────────────────────
```

Output is saved to `./reports/`:
- `./reports/.artifacts/` — per-step findings
- `./reports/{tech}_audit.txt` — final report

### `somnio quote`

Display the Somnio banner with a random team quote.

```bash
somnio quote   # or: somnio q
```

### `somnio add`

Add a new technology skill bundle to the repository.

```bash
somnio add react          # Scaffold new react-plans/ directory (wizard mode)
somnio add django          # Same, for django
somnio add flutter --force # Auto-detect existing flutter-plans/ bundles
```

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Skip confirmation prompts |

**Two modes:**

- **Wizard mode** — When `{tech}-plans/` doesn't exist, scaffolds a new skill bundle directory with README, plan, sample YAML rule, report template, and workflow.
- **Auto-detect mode** — When `{tech}-plans/` already exists, scans for `{tech}_project_health_audit/` and `{tech}_best_practices_check/` subdirectories, validates them, and registers valid bundles in the skill registry.

The technology name must be lowercase alphanumeric, start with a letter, and be at least 2 characters.

## Installed Skills

| Short Name | ID | Description | Technology |
|------------|----|-------------|------------|
| `somnio-fh` | `flutter_health` | Flutter Project Health Audit | Flutter |
| `somnio-fp` | `flutter_plan` | Flutter Best Practices Check | Flutter |
| `somnio-nh` | `nestjs_health` | NestJS Project Health Audit | NestJS |
| `somnio-np` | `nestjs_plan` | NestJS Best Practices Check | NestJS |
| `somnio-sa` | `security_audit` | Framework-Agnostic Security Audit | Any |

After installation, invoke skills as slash commands:

- **Claude Code**: `/somnio-fh`, `/somnio-fp`, `/somnio-nh`, `/somnio-np`, `/somnio-sa`
- **Cursor**: Available as commands in the command palette
- **Other agents**: Varies by agent (check agent documentation)

## Architecture

### Agent Registry

The core of the multi-agent system is the `AgentRegistry` in `lib/src/agents/agent_registry.dart`. Each agent is defined as an `AgentConfig` with:

- **Identity**: `id`, `displayName`
- **Execution**: `binary`, `promptStyle`, `promptFlag`, `autoApproveFlags`, `outputFlags`, `models`
- **Installation**: `installFormat`, `installScope`, `installPath`, `ruleExtension`
- **Escape hatches**: `readInstructionTemplate`, `tokenUsageParser` (for agent-specific quirks)

Adding a new agent requires only adding one `AgentConfig(...)` entry to `agent_registry.dart`. No other files need to change.

### Install Formats

| Format | Transformer | Description |
|--------|-------------|-------------|
| `skillDir` | `SkillDirTransformer` | Directory with SKILL.md + rules/ + templates/ (Claude) |
| `singleFile` | `SingleFileTransformer` | Single self-contained .md file (Cursor) |
| `workflow` | `WorkflowTransformer` | Workflow + somnio_rules/ (Gemini/Antigravity) |
| `markdown` | `MarkdownTransformer` | Generic single .md per skill (all new agents) |

### Prompt Styles

| Style | Example | Agents |
|-------|---------|--------|
| `flag` | `claude -p "prompt"` | Claude, Gemini, Aider, Amp, OpenCode, CodeBuddy, Qwen |
| `subcommand` | `codex exec "prompt"` | Codex |
| `positionalLast` | `agent --print "prompt"` | Cursor, Augment, Cline |

## Adding New Technologies

1. Create a `{tech}-plans/` directory at the repository root with your plans and YAML rules.
2. Run `somnio add {tech}` — the CLI will detect your bundles and register them.
3. Run `somnio init` to install the new skills.

See `somnio add --help` for the full wizard flow if starting from scratch.

## Development

```bash
# Clone the repo
git clone https://github.com/somnio-software/technology-tools
cd technology-tools/cli

# Get dependencies
dart pub get

# Run locally
dart run bin/somnio.dart --help

# Run tests
dart test

# Static analysis
dart analyze

# Install your local version globally
dart pub global activate --source path .
```

### Project Structure

```
cli/lib/src/
├── agents/                  # Agent registry (NEW)
│   ├── agent_config.dart    # AgentConfig data model
│   ├── agent_registry.dart  # All 17 agent definitions
│   └── token_parsers.dart   # Claude/Gemini token parsing
├── commands/                # CLI commands
│   ├── install_command.dart # somnio install --agent <id>
│   ├── run_command.dart     # somnio run <code>
│   ├── claude_command.dart  # Alias: somnio install --agent claude
│   ├── cursor_command.dart  # Alias: somnio install --agent cursor
│   └── ...
├── content/                 # Skill bundles and content loading
├── installers/              # File writers
│   └── agent_installer.dart # Generic installer (uses AgentConfig)
├── runner/                  # Audit execution engine
│   ├── agent_resolver.dart  # Registry-driven agent detection
│   ├── step_executor.dart   # Spawns AI CLIs via buildArgs()
│   └── ...
├── transformers/            # Format converters
│   ├── transformer.dart     # Interface + factory
│   ├── markdown_transformer.dart  # Generic format (NEW)
│   └── ...
└── utils/                   # Utilities
    ├── command_helpers.dart  # Shared helpers (DRY across commands)
    └── ...
```
