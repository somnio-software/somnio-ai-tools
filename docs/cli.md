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
| `somnio setup` | Detect AI CLIs, install missing ones, install skills to every detected agent |
| `somnio hooks` | Install Claude Code hooks (e.g. the work-log Stop hook) |
| `somnio run <name-or-alias>` | Execute a multi-step audit from the target project directory |
| `somnio install` | Install skills to a specific agent or all agents |
| `somnio skills` | Install, update, or remove skills — globally or per project |
| `somnio add <tech>` | Add a new technology's audit skills (scaffolds + registers) |
| `somnio status` | Show installed skills across all agents |
| `somnio update` | Update the CLI binary only (skills are managed by `somnio skills`) |
| `somnio uninstall` | Remove the CLI, optionally with the installed skills |
| `somnio rules` | Install coding-standard rules for all detected agents |
| `somnio workflow` | Create, configure, and run custom workflows |
| `somnio quote` | Display a random motivational quote |

### somnio hooks

Opt-in installer for Claude Code hooks. Currently installs the **work-log Stop hook**, which appends a Haiku-generated 2-3 sentence summary of each Claude Code session turn to `~/.work-log/YYYY-MM-DD.md`. These logs feed directly into the `clockify-tracker` skill's log-based mode.

```bash
somnio hooks            # Interactive: shows what will be installed, prompts for confirmation
somnio hooks --force    # Skip confirmation prompt
somnio hooks --verbose  # Show each installation step
```

What it does:
1. Writes `~/.claude/hooks/work-log-stop.sh` (idempotent — safe to re-run after updates)
2. Makes the script executable
3. Merges the Stop hook entry into `~/.claude/settings.json` without overwriting existing config

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Skip the confirmation prompt |
| `--verbose` | `-v` | Show each step (file written, chmod, settings.json update) |

**To uninstall:**
1. `rm ~/.claude/hooks/work-log-stop.sh`
2. Edit `~/.claude/settings.json` and remove the entry with `"command": "~/.claude/hooks/work-log-stop.sh"` from `hooks.Stop`

> **Note:** `somnio hooks` is intentionally separate from `somnio setup` — hooks modify your Claude Code session behaviour and should be an explicit opt-in. See [docs/work-log-stop-hook.md](work-log-stop-hook.md) for the full hook design.

### somnio setup

Primary installation command. Detects AI CLIs, installs missing ones, then installs every skill globally to each detected agent with the CLI's own installer. Every install is recorded in the `.somnio-skills.json` manifest, so `somnio skills update` keeps it current. Before installing it offers to remove Somnio skills a previous skills.sh install left behind — see [Cleanup of skills.sh installs](#cleanup-of-skillssh-installs).

```bash
somnio setup              # Full wizard
somnio setup --skip-cli   # Skip CLI detection
somnio setup --force      # Skip all prompts, including the skills.sh cleanup
```

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Skip all confirmation prompts |
| `--yes` | `-y` | Same as `--force` |
| `--skip-cli` | | Skip CLI detection and installation |
| `--verbose` | `-v` | Show detailed output, including every skills.sh path removed |

> `--legacy` is deprecated since 3.2.0: it is hidden, has no effect and prints a warning, because the built-in installer is now the only one.

Setup detects agents and resolves the skill content first; the skills.sh cleanup only runs once it knows the install can go ahead, so a machine with no agents (or a content error) keeps its skills.sh copies.

### somnio run

Execute an audit step-by-step from the target project's root directory. Each step runs in a fresh AI context, saving findings as artifacts and generating a final report.

```bash
somnio run fh                          # Flutter health audit (auto-detect agent)
somnio run nh --agent gemini           # NestJS health audit with Gemini CLI
somnio run sa --model opus             # Security audit with a specific model
somnio run fh --skip-validation        # Skip project type check
somnio run fh --no-preflight           # Send all steps to AI
somnio run fh --step-timeout 45        # Per-step timeout of 45 minutes
somnio run fh --project-name hoopis    # Override the name in the report file
```

| Flag | Short | Description |
|------|-------|-------------|
| `--agent` | `-a` | AI CLI to use (auto-detected if omitted) |
| `--model` | `-m` | Model to use (skips interactive selection) |
| `--skip-validation` | | Skip project type check |
| `--no-preflight` | | Skip pre-flight and send all steps to AI |
| `--step-timeout` | | Per-step timeout in minutes (default: 30) |
| `--project-name` | | Project name used in the report file name (default: the git repository name) |

#### Report file name

Every audit writes one report, named:

```
reports/<YYYY-MM-DD>-<project>-<audit>.md
```

```
reports/2026-09-14-hoopis-backend-flutter-health-audit.md
reports/2026-09-14-hoopis-backend-security-audit.md
```

- `<YYYY-MM-DD>` — the date of the run, first so the directory listing sorts
  chronologically on its own.
- `<project>` — the git repository name, slugified to kebab-case (lowercase;
  spaces, `_`, `.` and `/` become `-`; anything else dropped; repeated `-`
  collapsed). It is read from the `origin` remote URL
  (`git@github.com:somnio/hoopis-backend.git` → `hoopis-backend`), so it does
  not depend on what the checkout directory is called, and it is the same from
  a linked worktree or a monorepo subdirectory. Without an `origin` remote it
  is the main checkout's directory name; outside a git repo, the current
  directory name. `--project-name` overrides it.
- `<audit>` — the skill name, unchanged (`security-audit`,
  `nestjs-health-audit`, `flutter-best-practices`).

Because the name carries the date, re-running an audit on a later day leaves the
earlier report in place instead of overwriting it. Two runs on the same day do
overwrite each other. `harness-audit`, `security-audit`, `soc2-audit` and
`iso27001-audit` also write a `.json` export with the same base name;
`reports/.history/last_scores.json` is trend state, not a report, and keeps its
fixed name.

### somnio install

Install skills to a specific agent or all agents at once.

```bash
somnio install --agent claude   # Install to Claude Code only
somnio install --all            # Install to all detected agents
somnio install --all --yes      # Also remove skills.sh copies without asking
```

Like `somnio skills install`, it first offers to remove Somnio skills installed by skills.sh — see [Cleanup of skills.sh installs](#cleanup-of-skillssh-installs). `--yes` / `-y` skips that prompt.

### somnio add

Add a new technology's audit skills to the repository.

```bash
somnio add react       # Scaffold new skills/react-* directories (wizard mode)
somnio add flutter     # Auto-detect existing skills/flutter-* bundles
```

Two modes: **wizard** (when `skills/{tech}-*` does not exist, scaffolds new skill directories) and **auto-detect** (when `skills/{tech}-*` exists, scans and registers valid bundles).

### somnio skills

Manage the lifecycle of installed skills. Skills are versioned independently of the CLI binary, so this group owns installing, refreshing, and removing them.

Every skill the CLI writes is recorded in a `.somnio-skills.json` manifest at the root of the agent's install directory (one per agent and scope). `update` and `remove` act only on what that manifest lists — a skill you authored by hand is never touched, even if it shares a name with a shipped one.

**Scopes.** A skill can live in the agent's config directory (`--global`, e.g. `~/.claude/skills`) or inside the current project (`--project`, e.g. `./.claude/skills`).

`install` and `update` first offer to remove Somnio skills installed by skills.sh — see [Cleanup of skills.sh installs](#cleanup-of-skillssh-installs).

#### somnio skills install

Choose which skills to install and where. Prompts interactively for agents, skills, and scope when no flags are given.

```bash
somnio skills install                                        # interactive
somnio skills install --agent claude --all-skills --global
somnio skills install --all-agents --project --skills flutter_health,security_audit
somnio skills install --dry-run --verbose                    # show the skills.sh cleanup plan only
```

| Flag | Short | Description |
|------|-------|-------------|
| `--agent` | `-a` | Target a single agent |
| `--all-agents` | | Install to every agent detected on this machine |
| `--skills` | `-s` | Comma-separated skill ids/names (skips the wizard) |
| `--all-skills` | | Install every skill without prompting |
| `--global` | `-g` | Install into the agent's config dir. Mutually exclusive with `--project` |
| `--project` | `-p` | Install into the current project directory |
| `--yes` | `-y` | Remove Somnio skills installed by skills.sh without asking |
| `--dry-run` | | Print the skills.sh cleanup plan and exit without removing or installing anything |
| `--verbose` | `-v` | List every skills.sh link path in the cleanup plan |

#### somnio skills update

Refresh already-installed skills in place, overwriting them with the shipped version. It checks **both** the global and project locations for every agent and refreshes whichever exist — it never asks for a scope and never installs anything new.

```bash
somnio skills update                # refresh everything installed
somnio skills update --agent claude # refresh only Claude Code
somnio skills update --verbose
somnio skills update --dry-run --verbose   # show the cleanup plan and what would be refreshed
```

| Flag | Short | Description |
|------|-------|-------------|
| `--agent` | `-a` | Limit the refresh to a single agent |
| `--verbose` | `-v` | Show the install directory for each refreshed location and every skills.sh link path in the cleanup plan |
| `--yes` | `-y` | Remove Somnio skills installed by skills.sh without asking |
| `--dry-run` | | Print the skills.sh cleanup plan and what would be refreshed (agent, scope, location, skill names), then exit without removing or refreshing anything |

When run from the home directory, the project scope is the global folder; that location is refreshed once, as global.

`update` only reinstalls what the discovered manifests cover. Any skills.sh skill outside them is listed as **"will be removed and NOT reinstalled"** (also with `--yes` and in `--dry-run`), and the cleanup prompt then defaults to *no*. Run `somnio skills install` afterwards to get those back.

#### somnio skills remove

Clear a whole scope. Asks whether to remove the global install, the project install, or both, then deletes every somnio-installed skill there — there is no per-skill selection. Lists what will go and asks for confirmation first.

Aliased as `somnio skills uninstall`.

```bash
somnio skills remove                    # asks global / project / both
somnio skills remove --global --force
somnio skills remove --agent claude --project
```

| Flag | Short | Description |
|------|-------|-------------|
| `--agent` | `-a` | Limit removal to a single agent |
| `--global` | `-g` | Remove the global install. Mutually exclusive with `--project` |
| `--project` | `-p` | Remove the project install |
| `--force` | `-f` | Skip the confirmation prompt |
| `--verbose` | `-v` | Show each removed path |

> Running non-interactively requires an explicit `--global` or `--project` — the command clears an entire scope, so it will not guess.

Only skills recorded in a location's `.somnio-skills.json` manifest are removed from it. When the global scope is cleared for all agents (no `--agent`), the Somnio skills installed by skills.sh are removed too, through the same [cleanup](#cleanup-of-skillssh-installs) as the install commands: they are listed with the rest and covered by the same confirmation (`--verbose` lists every link path). Their canonical copies are shared by every agent and never live in a project, so `--agent` and `--project` leave them in place and say how many were kept. It does not remove agent rules or the CLI — that is `somnio uninstall --skills`.

### Cleanup of skills.sh installs

The CLI does not use skills.sh (`npx skills add`). Somnio skills that skills.sh installed globally are not recorded in the `.somnio-skills.json` manifest, so `somnio skills update` could never refresh them: they go stale next to the Somnio-managed copies. `somnio setup`, `somnio install`, `somnio skills install` and `somnio skills update` therefore remove them once, after they know the install can go ahead and before installing anything (`somnio uninstall --skills` and `somnio skills remove --global` remove them too):

1. Reads the skills.sh global lock — `$XDG_STATE_HOME/skills/.skill-lock.json` if `XDG_STATE_HOME` is set, otherwise `~/.agents/.skill-lock.json`. A missing lock means there is nothing to do; an unreadable or unrecognised lock is reported and **nothing is touched**.
2. Picks every lock entry whose source is `somnio-software/somnio-ai-tools` — including skills that are no longer shipped. Third-party skills are never touched.
3. For each one, removes the symlinks in agent skill folders (`~/.claude/skills`, `~/.pi/agent/skills`, …) that point at its canonical copy `~/.agents/skills/<name>`, then the canonical copy, then its lock entry. The rest of the lock is preserved.

Safety rules:

- Real directories in agent folders are never deleted, even when they share a skill's name (they may be hand-written, from another installer, or from skills.sh's copy mode), and a symlink pointing anywhere else is left alone. Only the link itself is ever removed; links are never followed.
- A Somnio entry whose folder name (after skills.sh's name sanitising) is shared with a third-party lock entry is skipped entirely, as is one whose canonical `SKILL.md` declares a different `name`. Their lock entries are kept and a warning is shown.
- Agent folders that are themselves symlinks (e.g. `~/.claude` → `~/dotfiles/claude`) are handled: links are matched both as written and at the folder's real path. If `~/.agents/skills` is itself a symlink, the canonical copy is removed at its real location. A symlinked lock file is rewritten at its target and the symlink is kept.
- What gets removed is exactly the plan that was shown: every item is re-checked right before removal, and anything that changed in between is skipped with a warning.
- An agent skill folder (e.g. `~/.augment/skills`) left empty by the unlinking is removed too, non-recursively — never its parents, a folder with anything else in it, or `~/.agents/skills`. The plan says how many ("N empty agent skill folders will be removed"; `--verbose` lists them). Otherwise those empty folders, which skills.sh creates for agents you may not use, would make the agents look installed. Agent detection (used by `somnio setup`) does not count skills.sh-managed content as evidence of an installed agent: an install folder holding only links into `~/.agents/skills` (or only `.DS_Store`) counts as empty. So does an empty one. An agent is detected by its binary on `PATH`, its detection paths, or an install folder with real content.

The commands list what will be removed (skills, canonical copies, number of links), flag any skill the command will not reinstall, and ask before removing anything. The question states that the removal is global, across all agents; it defaults to *yes* unless some skill would not be reinstalled. `--yes` (`--force` for `setup`) skips the question — the not-reinstalled list is still printed. Without a terminal to ask on and without that flag, the cleanup is skipped with a warning; declining also skips it. Either way the install or update then continues normally. `--dry-run` (on `skills install` and `skills update`) only prints the plan — with `--verbose`, every link path — and exits without removing or installing anything.

Only the global scope is cleaned. A project's `skills-lock.json` and `.agents/skills` may be committed to git, so project-scope skills.sh installs are left alone.

### somnio update

Update the CLI binary to the latest version. It does **not** touch installed skills; use [`somnio skills update`](#somnio-skills-update) for that.

```bash
somnio update             # Update the CLI from git
somnio update --verbose   # Show the raw output of the update process
```

| Flag | Short | Description |
|------|-------|-------------|
| `--verbose` | `-v` | Show the raw output of the update process |

### somnio uninstall

Remove the somnio CLI from this machine (`dart pub global deactivate somnio`). Before doing so it asks, Yes/No, whether to also delete the installed skills and rules — that question comes first because once the binary is gone there is no `somnio skills remove` left to run.

Answering **no** keeps your skills in place; the CLI is removed and the skills stay where they are.

```bash
somnio uninstall              # Asks about skills, then confirms
somnio uninstall --skills     # Remove the CLI and the skills, no prompt
somnio uninstall --no-skills  # Remove the CLI, keep the skills
somnio uninstall --force      # Skip the confirmation prompt
```

| Flag | Short | Description |
|------|-------|-------------|
| `--skills` / `--no-skills` | | Answer the skills question up front instead of being prompted |
| `--force` | `-f` | Skip the confirmation prompt |
| `--yes` | `-y` | Same as `--force` |
| `--verbose` | `-v` | Show each removed file (printed once removal finishes) |

When skills are removed it clears the global installs, the current project's installs, the `.somnio-skills.json` manifests, and the agent rules installed by `somnio rules install`. Where a manifest exists, only what it records is removed — a skill of someone else's that shares a Somnio skill's name is kept. For older installs without a manifest, an entry named like a Somnio skill is removed only if it looks like a Somnio install (a folder whose `SKILL.md` frontmatter `name` matches, a symlink pointing inside the folder, or a plain file); anything else is kept with a warning. Somnio skills installed by skills.sh are removed through the same [cleanup](#cleanup-of-skillssh-installs) as the install commands, so only entries the skills.sh lock attributes to this repo go from `~/.agents/skills`, together with their agent links and lock entries. Deactivating a CLI that was not installed through `dart pub global` is treated as a no-op, not an error.

> To remove skills without removing the CLI, use [`somnio skills remove`](#somnio-skills-remove) instead.

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
somnio workflow run <name> --step-timeout 45  # Per-step timeout of 45 minutes
somnio workflow config        # Configure model assignments
somnio workflow list          # List available workflows
```

See the [Workflow Guide](workflows.md) for details.

---

## Available Audits

| Name | Aliases | Description |
|------|---------|-------------|
| `flutter-health-audit` | `fh`, `somnio-fh` | Flutter project health audit (13 steps) |
| `harness-audit` | `ha`, `somnio-ha` | AI harness completeness audit |
| `flutter-best-practices` | `fp`, `somnio-fp` | Flutter code quality check |
| `angular-health-audit` | `ah`, `somnio-ah` | Angular (2+) project health audit (13 steps) |
| `nestjs-health-audit` | `nh`, `somnio-nh` | NestJS project health audit (13 steps) |
| `nestjs-best-practices` | `np`, `somnio-np` | NestJS code quality check |
| `soc2-audit` | `s2`, `somnio-s2` | SOC 2 readiness audit (any stack, whole project) |
| `react-health-audit` | `rh`, `somnio-rh` | React project health audit (13 steps) |
| `react-best-practices` | `rp`, `somnio-rp` | React code quality check |
| `angularjs-best-practices` | `ajp`, `somnio-ajp` | AngularJS (1.x) code quality check |
| `angularjs-health-audit` | `ajh`, `somnio-ajh` | AngularJS (1.x) legacy project health audit (13 steps) |
| `python-health-audit` | `ph`, `somnio-ph` | Python project health audit (13 steps) |
| `python-best-practices` | `pp`, `somnio-pp` | Python code quality check |
| `angular-best-practices` | `ap`, `somnio-ap` | Angular (2+) code quality check |
| `security-audit` | `sa`, `somnio-sa` | Security audit (any stack, 11 steps) |
| `iso27001-audit` | `iso`, `somnio-iso` | ISO 27001:2022 readiness audit (any stack, whole project) |

See the [Skills Catalog](skills.md) for full descriptions.

---

## Execution Flow

When you run `somnio run <alias>`:

1. **Parse arguments** — `--agent`, `--model`, `--skip-validation`, `--no-preflight`, `--project-name`
2. **Validate project type** — Flutter needs `pubspec.yaml`, NestJS needs `package.json` + `@nestjs/core`, Python needs `pyproject.toml`
3. **Run pre-flight steps** — Tool installation, version alignment, test coverage (no AI needed)
4. **Resolve AI agent and model** — Auto-detect or use `--agent` flag
5. **Parse SKILL.md** — Extract step order from the execution plan
6. **Execute each step** — Spawn a fresh AI CLI process per step, save artifacts to `./reports/.artifacts/<skill-name>/`
7. **Generate final report** — Write to `./reports/<YYYY-MM-DD>-<project>-<skill-name>.md`

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
