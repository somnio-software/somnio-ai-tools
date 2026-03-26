[Home](../README.md) > Skills

# Skills Catalog

Somnio provides audit, workflow, and utility skills. Audit skills run multi-step analysis and produce reports. Utility skills assist with day-to-day Git workflows.

---

## Flutter Health Audit

**Aliases:** `fh`, `somnio-fh`

Comprehensive Flutter project health audit with 13 analysis steps covering tech stack, architecture, state management, testing, code quality, CI/CD, and documentation. Produces a weighted score and a Google Docs-ready report.

**Use when:**
- Onboarding to an existing Flutter codebase
- Preparing a technical debt remediation plan
- Running a periodic project health check

**Example prompt:**
```
Run a full Flutter health audit on this project and generate a report.
```

**Output:** Weighted score report saved to `./reports/`

---

## Flutter Best Practices

**Aliases:** `fp`, `somnio-fp`

Micro-level Flutter code quality validation against live GitHub standards. Checks naming conventions, widget structure, state management patterns, and Dart idioms.

**Use when:**
- Reviewing a pull request for Flutter code quality
- Enforcing team-wide coding standards
- Validating a module before release

**Example prompt:**
```
Check this Flutter project against current best practices and flag any violations.
```

**Output:** Violations report with prioritized action plan

---

## NestJS Health Audit

**Aliases:** `nh`, `somnio-nh`

Comprehensive NestJS project health audit with 13 analysis steps. Evaluates architecture, API design, data layer, testing, documentation, and CI/CD with weighted scoring.

**Use when:**
- Assessing a NestJS backend before a major refactor
- Auditing API design and module organization
- Evaluating test coverage and deployment readiness

**Example prompt:**
```
Run a full NestJS health audit and summarize the findings.
```

**Output:** Weighted score report saved to `./reports/`

---

## NestJS Best Practices

**Aliases:** `np`, `somnio-np`

Micro-level NestJS code quality validation covering DTOs, error handling, module architecture, dependency injection patterns, and API conventions.

**Use when:**
- Reviewing NestJS service or controller code
- Checking DTO validation and error handling patterns
- Ensuring consistent module structure across a monorepo

**Example prompt:**
```
Validate this NestJS project against best practices for DTOs, error handling, and architecture.
```

**Output:** Violations report with prioritized action plan

---

## Security Audit

**Aliases:** `sa`, `somnio-sa`

Framework-agnostic security audit with 11 analysis steps. Scans for hardcoded secrets, runs SAST checks, audits dependencies, and integrates with Trivy and Gitleaks. Auto-detects Flutter, NestJS, Node.js, Go, Rust, Python, and generic projects.

**Use when:**
- Preparing for a security review or compliance check
- Scanning for leaked credentials and API keys
- Auditing third-party dependency vulnerabilities

**Example prompt:**
```
Run a security audit on this project. Check for secrets, vulnerable dependencies, and misconfigurations.
```

**Output:** Severity-classified report saved to `./reports/`

---

## Workflow Builder

Create and execute custom multi-step AI workflows with parallel wave execution. Each step can target a different AI model. Steps are tagged by role (`research`, `planning`, `execution`) and map to configurable model tiers.

**Use when:**
- Automating a repeatable multi-step task (e.g., dependency cleanup, migration)
- Orchestrating work across different model strengths
- Building team-shared analysis pipelines

**Example prompt:**
```
Create a workflow called "dependency-cleanup" that audits outdated packages, plans upgrades, and executes the migration.
```

See the [Workflow Guide](workflows.md) for full documentation.

---

## Clockify Tracker

Log time and manage time entries in Clockify directly from your AI assistant using the Clockify REST API.

**Use when:**
- Logging hours for a project in Clockify
- Creating time entries for multiple days at once
- Checking your Clockify workspaces and projects

**Example prompts:**
```
Log 8 hours today on project "Backend API" in Clockify, starting at 09:00. I'm in UTC-3.
```
```
Track 6 hours on "Mobile App" from March 23 to 27, 10:00–16:00, timezone UTC-3.
```
```
Add a Clockify time entry for yesterday on "Frontend" project, 9:00 to 18:00, Buenos Aires time.
```

**Requires:** `CLOCKIFY_API_KEY` environment variable (Profile → API in Clockify). Optionally set `CLOCKIFY_TZ_OFFSET` (e.g. `-3`) to avoid specifying timezone in each prompt.

**Output:** Confirmed time entry (or entries) created via Clockify API

---

## Git Branch Format

Generates properly formatted Git branch names following project conventions.

**Format:**
```
{type}/{TICKET_NUMBER}_{short_description}   # with ticket
{type}/{short_description}                    # without ticket
```

**Types:** `feat`, `fix`, `refactor`, `chore`, `test`, `docs`, `style`, `perf`, `ci`, `build`, `revert`

**Example prompt:**
```
What branch name should I use for adding dark mode support? Ticket: PROJ-312
```

**Output:** `feat/PROJ-312_dark_mode_support`

---

## Git Commit Format

Generates properly formatted Git commit messages following Conventional Commits.

**Format:**
```
{type}({optional scope}): {short imperative description}

* Added ...
* Changed ...
* Fixed ...
```

**Types:** `feat`, `fix`, `refactor`, `chore`, `test`, `docs`, `style`, `perf`, `ci`, `build`, `revert`

**Example prompt:**
```
Write a commit message for upgrading Flutter and fixing deprecated APIs.
```

**Output:**
```
feat(flutter): upgrade Flutter SDK to v3.19

* Updated Flutter SDK version to 3.19
* Changed minimum iOS deployment target to 14.0
* Fixed deprecated API usages after upgrade
```

---

**See also:** [Installation](installation.md) | [CLI Reference](cli.md) | [Workflow Guide](workflows.md)
