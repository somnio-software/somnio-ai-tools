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

## React Health Audit

**Aliases:** `rh`, `somnio-rh`

Comprehensive React project health audit with 13 analysis steps covering tech stack, architecture, state management, testing, code quality, performance, CI/CD, and documentation. Supports CRA, Vite, Next.js, and Remix. Produces a weighted score and a Google Docs-ready report.

**Use when:**
- Onboarding to an existing React or Next.js codebase
- Preparing a frontend technical debt remediation plan
- Running a periodic project health check

**Example prompt:**
```
Run a full React health audit on this project and generate a report.
```

**Output:** Weighted score report saved to `./reports/`

---

## React Best Practices

**Aliases:** `rp`, `somnio-rp`

Micro-level React code quality validation against local GitHub standards. Checks component architecture, hooks patterns, state management, performance optimizations, and TypeScript usage.

**Use when:**
- Reviewing a pull request for React code quality
- Enforcing team-wide React coding standards
- Validating a feature module before release

**Example prompt:**
```
Check this React project against current best practices and flag any violations.
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

Log time and manage time entries in Clockify directly from your AI assistant using the Clockify REST API. Supports two modes:

> **The work-log hook is optional.** Manual mode works with just a Clockify API key — no hook, no setup beyond that. Log-based mode additionally requires the hook to have generated `~/.work-log/` files.

### Manual mode

Provide description, project, dates, and times explicitly.

**Example prompts:**
```
Log 8 hours today on project "Backend API" in Clockify, starting at 09:00. I'm in UTC-3.
```
```
Track 6 hours on "Mobile App" from March 23 to 27, 10:00–16:00, timezone UTC-3.
```
```
carga 8 horas en el proyecto Somnio con la descripción "Technology" empezando a las 09:00
para los días 25, 26, 27, 28 y 29 de mayo usando el timezone de Buenos Aires, Argentina
```

### Log-based mode

> **Prerequisite:** run `somnio hooks` once to install the work-log Stop hook. Without it there are no `~/.work-log/` files to read. See [docs/work-log-stop-hook.md](work-log-stop-hook.md) for the full setup.
> **Claude Code only (current implementation).** Cursor (v1.7+) and Windsurf also expose stop-event hooks, but the script calls the `claude` CLI to generate summaries — so this mode only works out-of-the-box with Claude Code.

Automatically fill Clockify from your `~/.work-log/` daily files. Each file is generated by the Stop hook: after every Claude Code session turn, a background Haiku process appends a 2-3 sentence summary of what was done. Pure Q&A sessions are filtered out automatically — only real work gets logged.

**Example prompts:**
```
/clockify-tracker use logs for this week
```
```
/clockify-tracker usa los logs de los últimos 5 días
```

The skill will:
1. Ask which days to cover (if not specified)
2. Read `~/.work-log/YYYY-MM-DD.md` for each day
3. Map root repos to Clockify projects (asked once per repo, saved forever)
4. Ask for an hour split on days with multiple projects
5. Generate a 2-sentence executive summary per entry
6. Show a full preview of all entries before posting

**Preferences file — `~/.clockify-prefs.json`**

Created and managed by this skill — the hook does not touch it. Created automatically on first use of log-based mode; all values are saved and reused on subsequent runs.

```json
{
  "api_key": "<your Clockify API key>",
  "timezone": { "name": "Buenos Aires, Argentina", "offset": -3 },
  "default_start": "09:00",
  "default_end": "17:00",
  "workspace_id": "<workspace id>",
  "auto_cleanup": true,
  "repo_mappings": {
    "mini-meta-repo":  { "name": "Nubank",         "id": "<project id>" },
    "somnio-ai-tools": { "name": "ignore",          "id": null }
  }
}
```

Keys explained:

| Key | Description |
|-----|-------------|
| `api_key` | Clockify API key (Profile → API). Alternative sources: `CLOCKIFY_API_KEY` env var, `CLOCKIFY_API_KEY_FILE` env var (path to a file containing the key), or shell config files (`~/.zshrc` etc.). See resolution order below. |
| `timezone` | Your local timezone — asked once, applied to every entry. |
| `default_start` / `default_end` | Default time block for each day (e.g. 09:00–17:00). |
| `workspace_id` | Resolved automatically from the API on first run. |
| `auto_cleanup` | If `true`, deletes processed `~/.work-log/` files after posting without asking. Set by answering "always" to the cleanup prompt. |
| `repo_mappings` | Maps root repo names to Clockify projects. Use `"name": "ignore"` to permanently skip a repo. |

> **Note on repo mappings:** the hook logs entries using the **root git repo name** (e.g. `mini-meta-repo`), not the worktree or branch name. Any worktree from the same repo (e.g. `mini-meta-repo/fix-NU-334`) maps to the same project automatically. If you have stale per-worktree entries in `repo_mappings` from before this behaviour was introduced, you can safely remove them and keep only the root repo key.

**API key resolution order:** `CLOCKIFY_API_KEY` env var → `CLOCKIFY_API_KEY_FILE` env var → shell config files (`~/.zshrc`, `~/.bashrc`, etc.) → `api_key` in prefs file → prompted once and optionally saved. The prefs file path itself defaults to `~/.clockify-prefs.json` but can be overridden with `CLOCKIFY_PREFS_PATH`.

**Output:** Confirmed time entry (or entries) created via Clockify API, with a full preview shown before posting.

---

## Ship

Fully automated ship workflow. Detects the base branch, merges it in, runs tests, reviews the diff, bumps `VERSION`, updates `CHANGELOG.md`, commits, pushes, and opens a pull request. Non-interactive — only stops for merge conflicts, failing tests, review ASKs, or ambiguous minor/major version bumps.

**Use when:**
- Ready to land a feature branch and open a PR
- Asked to "ship", "deploy", "push to main", or "create a PR"
- Closing out work and need version/changelog/commit/push done in one pass

**Example prompts:**
```
Ship it.
```
```
Create a PR for this branch.
```

**Output:** Pull request URL, with `VERSION` bumped and `CHANGELOG.md` updated.

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
