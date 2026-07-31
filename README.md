<div align="center">

# Somnio

**AI-powered audit skills for Claude Code, Cursor, and 40+ other agents.**

Run comprehensive health audits, security scans, and best-practices checks on Flutter, NestJS, React, Python (FastAPI, Django, Flask), and more — directly from your AI coding assistant.

[![Install Somnio Skills](https://img.shields.io/badge/skills.sh-Install%20Somnio%20Skills-blue?style=for-the-badge)](https://skills.sh/somnio-software/somnio-ai-tools)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)](#)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)](#)
[![React](https://img.shields.io/badge/React-61DAFB?style=flat-square&logo=react&logoColor=black)](#)
[![NestJS](https://img.shields.io/badge/NestJS-E0234E?style=flat-square&logo=nestjs&logoColor=white)](#)
[![Security](https://img.shields.io/badge/Security-Agnostic-orange?style=flat-square)](#)

</div>

---

## Quick Install

```bash
npx skills add somnio-software/somnio-ai-tools
```

> Works with Claude Code, Cursor, Windsurf, Copilot, and [40+ other agents](https://agentskills.io).

<details>
<summary><strong>Claude Desktop App (Cowork plugin)</strong></summary>

1. Open **Claude Desktop App** → **Cowork** tab → **Customize** → **Explore Plugins**
2. Go to **Personal**, click **+**, paste `somnio-software/somnio-ai-tools`
3. Select which plugins to install from the marketplace

</details>

<details>
<summary><strong>Somnio CLI</strong> (includes multi-step audit runner)</summary>

```bash
dart pub global activate -sgit https://github.com/somnio-software/somnio-ai-tools.git --git-path cli
somnio setup
```

</details>

> [Full installation guide →](docs/installation.md)

---

## Skills

### Audits

| Skill | Alias | Description |
|:------|:-----:|:------------|
| [Flutter Health Audit](docs/skills.md#flutter-health-audit) | `fh` | 13-step project health audit with weighted scoring |
| [Flutter Best Practices](docs/skills.md#flutter-best-practices) | `fp` | Code quality validation against live GitHub standards |
| [NestJS Health Audit](docs/skills.md#nestjs-health-audit) | `nh` | 13-step backend health audit with weighted scoring |
| [NestJS Best Practices](docs/skills.md#nestjs-best-practices) | `np` | DTO, architecture, and error handling validation |
| [SOC 2 Readiness Audit](docs/skills.md#soc-2-readiness-audit) | `s2` | Whole-project SOC 2 Trust Services Criteria readiness & gap analysis |
| [React Health Audit](docs/skills.md#react-health-audit) | `rh` | 13-step frontend health audit with weighted scoring |
| [React Best Practices](docs/skills.md#react-best-practices) | `rp` | Component, hooks, state management, and TypeScript validation |
| [AngularJS Health Audit](docs/skills.md#angularjs-health-audit) | `ajh` | 13-step legacy AngularJS 1.x health audit with weighted scoring |
| [Python Health Audit](docs/skills.md#python-health-audit) | `ph` | 13-step project health audit with weighted scoring |
| [Python Best Practices](docs/skills.md#python-best-practices) | `pp` | Code style, typing, function design, and testing validation |
| [Security Audit](docs/skills.md#security-audit) | `sa` | Framework-agnostic security scan (secrets, deps, SAST) |

### Workflows & Utilities

| Skill | Description |
|:------|:------------|
| [Clockify Tracker](docs/skills.md#clockify-tracker) | Log time manually or auto-fill from daily work logs — two modes, full preview before posting |
| [Workflow Builder](docs/skills.md#workflow-builder) | Custom multi-step AI workflows with parallel execution |
| [Ship](docs/skills.md#ship) | Automated ship workflow: merge, test, bump, changelog, commit, push, open PR |
| [Git Branch Format](docs/skills.md#git-branch-format) | Branch naming convention generator |
| [Git Commit Format](docs/skills.md#git-commit-format) | Conventional Commits message generator |
| [Dart Model from JSON](docs/skills.md#dart-model-from-json) | Generate Dart model classes from a JSON structure with json_annotation + equatable |
| [Optimize Claude Config](docs/skills.md#optimize-claude-config) | Audit & optimize a repo's Claude Code config for lazy-loading rules and a lean CLAUDE.md |
| [DORA Metrics](docs/skills.md#dora-metrics) | Deployment Frequency and Lead Time for Changes, per project and per repo, from the GitHub API |

> [Full skills catalog with examples →](docs/skills.md)

---

## Hooks

Claude Code hooks that run automatically during sessions — opt-in, separate from `somnio setup`.

| Hook | Trigger | What it does |
|:-----|:-------:|:-------------|
| Work-Log Stop | After every turn | Appends a 2-3 sentence Haiku summary to `~/.work-log/YYYY-MM-DD.md` — powers [Clockify log-based mode](docs/skills.md#log-based-mode) |

Install via the Somnio CLI:

```bash
somnio hooks            # interactive: shows what will change, prompts for confirmation
somnio hooks --force    # skip confirmation
```

> [Hook details →](docs/work-log-stop-hook.md) · [CLI reference →](docs/cli.md)

---

## Agent Rules

Global coding standards — automatically applied by your AI agent in every project.

| Rules Pack | Coverage |
|:-----------|:---------|
| Flutter Rules | Layered architecture, BLoC patterns, testing, JSON models |
| Firebase Functions Rules | Architecture, module boundaries, Express + auth, secrets, error handling, testing |
| NestJS Rules | DTOs, services, controllers, repositories, testing, error handling, TypeScript |
| React Rules | Components, hooks, state management, performance, testing, TypeScript |
| TypeScript Rules | tsconfig standards, naming, imports, types, nullables, async/await, error handling |
| Python Rules | Code style (PEP 8/Ruff), strict type hints, function design, module structure, Pydantic validation, EAFP error handling, pytest unit + integration testing |
| FastAPI Rules | Domain-package structure, APIRouter modularization, Pydantic request/response schemas, Depends injection, async vs sync handler choice, HTTPException boundary translation — layers on Python Rules |
| Django Rules | Models and ORM optimization (N+1 defense), migrations, service/selector layer, DRF views/serializers, settings by environment, security hardening, pytest-django testing — layers on Python Rules |
| Flask Rules | Application factory, blueprints, configuration hierarchy, init_app extension pattern, Flask-SQLAlchemy sessions, error handler registration, conftest fixture testing — layers on Python Rules |

Install via the Somnio CLI:

```bash
somnio rules install                          # interactive: detect agents + choose scope
somnio rules install --agent claude --global  # Claude Code, global
somnio rules install --agent cursor --project # Cursor, current project
somnio rules install --all --global           # all detected agents, global
```

> [Agent rules details →](docs/agent-rules.md)

---

## Commands

Root-level commands installed at folder scope — project-specific extensions for Claude Code and Cursor.

```bash
somnio commands install                          # interactive: detect agents + choose which commands
somnio commands install --agent claude --all     # Claude Code, all commands
somnio commands install --agent cursor --all     # Cursor, all commands
```

Commands are written to `.claude/commands/` (Claude) and `.cursor/commands/` (Cursor) — project scope only, not global. Example: `ship` (merge, test, bump, changelog, commit, push, open PR).

> [CLI reference →](docs/cli.md) · [Workflow guide →](docs/workflows.md)

---

## Slash Commands

| Command | Description |
|:--------|:------------|
| `/somnio:audit` | Auto-detect project type and run the appropriate audit |
| `/somnio:quick-check` | Fast 2-3 minute lightweight assessment |
| `somnio run <alias>` | CLI: execute a multi-step audit from terminal |

---

## Plugins & Utility CLIs

Two ways to extend the setup: Cowork marketplace plugins that install through the Claude Desktop App, and standalone CLIs you install yourself and run alongside Somnio.

### Cowork plugins

Somnio ships as a Claude Desktop App plugin (Cowork):

| Package | Focus |
|:--------|:------|
| **Development** | Health audits, security scans, best practices |

> [Plugin system details →](docs/plugins.md)

### Utility CLIs

Separate binaries that add commands to Claude Code. These are not marketplace plugins and do not install via `npx skills add`. You install each one directly.

| Tool | What it does |
|:-----|:-------------|
| [Vector](https://github.com/mcampbellr/vector) | Spec-driven kanban board for Claude Code specs. A JSON record on disk is the source of truth; a local web board renders it live. |

Install the Vector binary once, then run `vector init` in each repo you want to track:

```bash
curl -fsSL https://raw.githubusercontent.com/mcampbellr/vector/main/scripts/install.sh | sh
cd <your-project>
vector init
```

`vector init` seeds the `/vector:*` commands into `.claude/commands/vector/`, detects your stack, and creates the `.vector/` state directory.

> Full install options and usage: [Vector repository](https://github.com/mcampbellr/vector)

---

## Documentation

| | | |
|:--|:--|:--|
| [Installation Guide](docs/installation.md) | [Skills Catalog](docs/skills.md) | [CLI Reference](docs/cli.md) |
| [Plugin System](docs/plugins.md) | [Workflow Builder](docs/workflows.md) | [Architecture](docs/architecture.md) |
| [Agent Rules](docs/agent-rules.md) | [Hooks](docs/work-log-stop-hook.md) | [Contributing](CONTRIBUTING.md) |

---

## Contributing

We welcome contributions. See the [Contributing Guide](CONTRIBUTING.md) for setup instructions, how to add new skills, agent rules, agents, or plugins, and the pull request workflow.

## License

MIT — see [LICENSE](LICENSE) for details.
