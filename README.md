# Somnio

AI-powered audit skills for Claude Code, Cursor, and 40+ other agents. Run comprehensive health audits, security scans, and best-practices checks on Flutter, NestJS, and more — directly from your AI coding assistant.

[![Install Somnio Skills](https://img.shields.io/badge/skills.sh-Install%20Somnio%20Skills-blue?style=for-the-badge)](https://skills.sh/somnio-software/somnio-ai-tools)

## Installation

### Option 1: skills.sh (recommended)

Works with Claude Code, Cursor, Windsurf, Copilot, and [40+ other agents](https://agentskills.io).

```bash
npx skills add somnio-software/somnio-ai-tools
```

### Option 2: Claude Code plugin

```
/plugin install somnio
```

### Option 3: Somnio CLI

The Dart CLI includes a multi-step audit runner that orchestrates analysis across fresh AI contexts. It also installs skills via skills.sh under the hood.

```bash
dart pub global activate -sgit https://github.com/somnio-software/somnio-ai-tools.git --git-path cli
somnio setup
```

`somnio setup` detects installed AI CLIs, offers to install missing ones, then runs `npx skills add` to install all skills globally. See the [CLI README](cli/README.md) for full usage.

## Available Skills

### Flutter Health Audit

Comprehensive Flutter project health audit with 13 analysis steps covering architecture, state management, testing, CI/CD, and more. Produces a weighted score and a Google Docs-ready report.

**Use when:**
- Onboarding to an existing Flutter codebase
- Preparing a technical debt remediation plan
- Running a periodic project health check

**Example prompt:**
```
Run a full Flutter health audit on this project and generate a report.
```

---

### Flutter Best Practices

Micro-level Flutter code quality validation against live GitHub standards. Checks naming conventions, widget structure, state management patterns, and Dart idioms.

**Use when:**
- Reviewing a pull request for Flutter code quality
- Enforcing team-wide coding standards
- Validating a module before release

**Example prompt:**
```
Check this Flutter project against current best practices and flag any violations.
```

---

### NestJS Health Audit

Comprehensive NestJS project health audit with 13 analysis steps. Evaluates architecture, API design, data layer, testing, documentation, and CI/CD with weighted scoring.

**Use when:**
- Assessing a NestJS backend before a major refactor
- Auditing API design and module organization
- Evaluating test coverage and deployment readiness

**Example prompt:**
```
Run a full NestJS health audit and summarize the findings.
```

---

### NestJS Best Practices

Micro-level NestJS code quality validation covering DTOs, error handling, module architecture, dependency injection patterns, and API conventions.

**Use when:**
- Reviewing NestJS service or controller code
- Checking DTO validation and error handling patterns
- Ensuring consistent module structure across a monorepo

**Example prompt:**
```
Validate this NestJS project against best practices for DTOs, error handling, and architecture.
```

---

### Security Audit

Framework-agnostic security audit with 11 analysis steps. Scans for hardcoded secrets, runs SAST checks, audits dependencies, and integrates with Trivy and Gitleaks. Auto-detects Flutter, NestJS, Node.js, Go, Rust, Python, and generic projects.

**Use when:**
- Preparing for a security review or compliance check
- Scanning for leaked credentials and API keys
- Auditing third-party dependency vulnerabilities

**Example prompt:**
```
Run a security audit on this project. Check for secrets, vulnerable dependencies, and misconfigurations.
```

---

### Workflow Builder

Create and execute custom multi-step AI workflows with parallel wave execution. Each step can target a different AI model. Steps are tagged by role (research, planning, execution) and map to configurable model tiers.

**Use when:**
- Automating a repeatable multi-step task (e.g., dependency cleanup, migration)
- Orchestrating work across different model strengths (fast model for research, strong model for execution)
- Building team-shared analysis pipelines

**Example prompt:**
```
Create a workflow called "dependency-cleanup" that audits outdated packages, plans upgrades, and executes the migration.
```

## Commands

| Command | Description |
|---------|-------------|
| `/somnio:audit` | Main entry point. Auto-detects the project type, selects the appropriate audit, and runs it end to end. |
| `/somnio:quick-check` | Fast 2-3 minute lightweight assessment. Good for a quick pulse check before diving deeper. |

## CLI Runner

The Somnio CLI (`somnio run`) orchestrates multi-step audits from the terminal. It handles pre-flight setup (tool installation, version alignment, test execution) directly, then delegates each analysis step to a fresh AI CLI process.

```bash
somnio run fh    # Flutter health audit
somnio run nh    # NestJS health audit
somnio run sa    # Security audit (any project)
```

The CLI supports 19 agent definitions, automatic agent detection, per-step model selection, and resume-on-failure. See the [CLI README](cli/README.md) for all options.

## Directory Structure

```
somnio-ai-tools/
├── .claude-plugin/
│   └── plugin.json              # Claude Code plugin manifest
├── skills/
│   ├── flutter-health-audit/    # SKILL.md + agents/ + references/ + assets/
│   ├── flutter-best-practices/  # SKILL.md + references/ + assets/
│   ├── nestjs-health-audit/     # SKILL.md + agents/ + references/ + assets/
│   ├── nestjs-best-practices/   # SKILL.md + references/ + assets/
│   ├── security-audit/          # SKILL.md + agents/ + references/ + assets/
│   └── workflow-builder/        # SKILL.md + references/
├── commands/
│   ├── audit.md                 # /somnio:audit command
│   └── quick-check.md           # /somnio:quick-check command
├── cli/                         # Dart CLI (audit runner)
├── docs/
├── CLAUDE.md
├── LICENSE
└── README.md
```

Each skill directory contains a `SKILL.md` entry point with detailed instructions. Health and security audit skills include `agents/` directories with 19 agent definitions for parallel execution, plus 50+ reference files with analysis instructions.

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'Add your feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a pull request

For CLI development, see `cli/CLAUDE.md` and the [CLI README](cli/README.md) for build and test commands.

## License

MIT -- see [LICENSE](LICENSE) for details.
