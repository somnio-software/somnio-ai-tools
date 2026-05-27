<div align="center">

# Somnio

**AI-powered audit skills for Claude Code, Cursor, and 40+ other agents.**

Run comprehensive health audits, security scans, and best-practices checks on Flutter, NestJS, React, and more — directly from your AI coding assistant.

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
| [React Health Audit](docs/skills.md#react-health-audit) | `rh` | 13-step frontend health audit with weighted scoring |
| [React Best Practices](docs/skills.md#react-best-practices) | `rp` | Component, hooks, state management, and TypeScript validation |
| [Security Audit](docs/skills.md#security-audit) | `sa` | Framework-agnostic security scan (secrets, deps, SAST) |

### Workflows & Utilities

| Skill | Description |
|:------|:------------|
| [Clockify Tracker](docs/skills.md#clockify-tracker) | Log time manually or auto-fill from daily work logs — two modes, full preview before posting |
| [Workflow Builder](docs/skills.md#workflow-builder) | Custom multi-step AI workflows with parallel execution |
| [Ship](docs/skills.md#ship) | Automated ship workflow: merge, test, bump, changelog, commit, push, open PR |
| [Git Branch Format](docs/skills.md#git-branch-format) | Branch naming convention generator |
| [Git Commit Format](docs/skills.md#git-commit-format) | Conventional Commits message generator |

> [Full skills catalog with examples →](docs/skills.md)

### Clockify time tracking

The `/clockify-tracker` skill has two independent modes:

#### Manual mode — no setup required

Tell the skill what to log and it handles the Clockify API calls:

```
/clockify-tracker
carga 8 horas en el proyecto Somnio con la descripción "Technology"
empezando a las 09:00 para los días 25–29 de mayo, timezone Buenos Aires
```

```
Log 6 hours on "Mobile App" from March 23 to 27, 10:00–16:00, UTC-3
```

#### Log-based mode — auto-fill from work logs

> **Claude Code only (current implementation).** Cursor (v1.7+) and Windsurf also expose stop-event hooks, but the script calls the `claude` CLI to generate summaries — so automatic mode only works out-of-the-box with Claude Code. Manual mode works with any agent.

Automatically fills Clockify from daily work log files that the work-log Stop hook writes after each assistant turn.

**How the hook works:**

Claude Code fires a `Stop` event after every assistant turn. The hook (`work-log-stop.sh`) receives the last response as a JSON payload, classifies it (pure Q&A is skipped automatically), and spawns a background Haiku process that writes a 2-3 sentence summary to `~/.work-log/YYYY-MM-DD.md`. The main session is never re-entered — no context pollution, no extra cost.

```
After each Claude Code assistant turn
         ↓
Stop hook runs in background (work-log-stop.sh)
         ↓
Haiku classifies: Q&A → skipped / real work → summarised
         ↓
Summary appended to ~/.work-log/YYYY-MM-DD.md
         ↓
/clockify-tracker use logs → entries previewed and posted
```

**Install the hook (once):**

```bash
somnio hooks            # interactive install with confirmation
somnio hooks --force    # skip confirmation
somnio hooks --verbose  # show each step
```

This writes `~/.claude/hooks/work-log-stop.sh` and registers it as a `Stop` hook in `~/.claude/settings.json`. Safe to re-run after CLI updates — fully idempotent.

**Common usage:**

```
/clockify-tracker use logs for this week
/clockify-tracker usa los logs de los últimos 5 días
```

**Uninstall the hook:**

```bash
rm ~/.claude/hooks/work-log-stop.sh
# then edit ~/.claude/settings.json and remove the work-log-stop.sh entry from hooks.Stop
```

**Preferences — `~/.clockify-prefs.json`**

Managed by the `/clockify-tracker` skill, not the hook. Created automatically on first log-based run. Stores your API key, timezone, default time block, workspace ID, and repo→project mappings (asked once per repo, reused forever). The hook only writes to `~/.work-log/` — it never reads or writes the prefs file.

```json
{
  "api_key": "<Clockify API key>",
  "timezone": { "name": "Buenos Aires, Argentina", "offset": -3 },
  "default_start": "09:00",
  "default_end": "17:00",
  "workspace_id": "<id>",
  "auto_cleanup": true,
  "repo_mappings": {
    "my-repo":  { "name": "My Clockify Project", "id": "<project id>" },
    "internal": { "name": "ignore", "id": null }
  }
}
```

`auto_cleanup: true` skips the deletion confirmation — set it by answering "always" the first time the prompt appears.

**Custom API key / prefs locations**

| Env var | Purpose |
|---------|---------|
| `CLOCKIFY_API_KEY` | API key value directly. |
| `CLOCKIFY_API_KEY_FILE` | Path to a file containing just the API key — useful with secrets managers or symlinked vault files (e.g. `~/.secrets/clockify`). |
| `CLOCKIFY_PREFS_PATH` | Custom path for the prefs JSON file. Defaults to `~/.clockify-prefs.json` when unset. |

Key resolution order: `CLOCKIFY_API_KEY` env → `CLOCKIFY_API_KEY_FILE` → shell config files (`~/.zshrc`, `~/.bashrc`, etc.) → `api_key` in prefs → prompt.

> [Work-log hook details →](docs/work-log-stop-hook.md) 

>[Clockify Tracker full docs →](docs/skills.md#clockify-tracker)

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

| Command | Description |
|:--------|:------------|
| `/somnio:audit` | Auto-detect project type and run the appropriate audit |
| `/somnio:quick-check` | Fast 2-3 minute lightweight assessment |
| `somnio run <alias>` | CLI: execute a multi-step audit from terminal |

> [CLI reference →](docs/cli.md) · [Workflow guide →](docs/workflows.md)

---

## Plugins

Somnio is also available as a **Claude Desktop App plugin** (Cowork):

| Package | Focus |
|:--------|:------|
| **Development** | Health audits, security scans, best practices |

> [Plugin system details →](docs/plugins.md)

---

## Documentation

| | | |
|:--|:--|:--|
| [Installation Guide](docs/installation.md) | [Skills Catalog](docs/skills.md) | [CLI Reference](docs/cli.md) |
| [Plugin System](docs/plugins.md) | [Workflow Builder](docs/workflows.md) | [Architecture](docs/architecture.md) |
| [Agent Rules](docs/agent-rules.md) | [Contributing](CONTRIBUTING.md) | |

---

## Contributing

We welcome contributions. See the [Contributing Guide](CONTRIBUTING.md) for setup instructions, how to add new skills, agent rules, agents, or plugins, and the pull request workflow.

## License

MIT — see [LICENSE](LICENSE) for details.
