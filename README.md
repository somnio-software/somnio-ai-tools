<div align="center">

# Somnio

**AI-powered audit skills for Claude Code, Cursor, and 40+ other agents.**

Run comprehensive health audits, security scans, and best-practices checks on Flutter, NestJS, and more — directly from your AI coding assistant.

[![Install Somnio Skills](https://img.shields.io/badge/skills.sh-Install%20Somnio%20Skills-blue?style=for-the-badge)](https://skills.sh/somnio-software/somnio-ai-tools)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)](#)
[![NestJS](https://img.shields.io/badge/NestJS-E0234E?style=flat-square&logo=nestjs&logoColor=white)](#)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)](#)
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
| [Security Audit](docs/skills.md#security-audit) | `sa` | Framework-agnostic security scan (secrets, deps, SAST) |

### Workflows & Utilities

| Skill | Description |
|:------|:------------|
| [Workflow Builder](docs/skills.md#workflow-builder) | Custom multi-step AI workflows with parallel execution |
| [Git Branch Format](docs/skills.md#git-branch-format) | Branch naming convention generator |
| [Git Commit Format](docs/skills.md#git-commit-format) | Conventional Commits message generator |

> [Full skills catalog with examples →](docs/skills.md)

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

Somnio is also available as a **Claude Desktop App plugin** (Cowork) with four packages:

| Package | Focus |
|:--------|:------|
| **Development** | Health audits, security scans, best practices |
| **Marketing** | Content strategy, ASO audits, campaign analysis |
| **Operations** | Story definition, backlog management, connectors |
| **Engineering Management** | Performance reviews, career path evaluation |

> [Plugin system details →](docs/plugins.md)

---

## Documentation

| | | |
|:--|:--|:--|
| [Installation Guide](docs/installation.md) | [Skills Catalog](docs/skills.md) | [CLI Reference](docs/cli.md) |
| [Plugin System](docs/plugins.md) | [Workflow Builder](docs/workflows.md) | [Architecture](docs/architecture.md) |
| [Contributing](docs/contributing.md) | | |

---

## Contributing

We welcome contributions. See the [Contributing Guide](docs/contributing.md) for setup instructions, how to add new skills or plugins, and the pull request workflow.

## License

MIT — see [LICENSE](LICENSE) for details.
