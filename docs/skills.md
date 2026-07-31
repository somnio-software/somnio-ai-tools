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

## AngularJS Best Practices

**Aliases:** `ajp`, `somnio-ajp`

Micro-level **AngularJS (Angular 1.x)** code-quality audit. Validates code against concrete standards for module/controller/directive architecture, `$scope` and binding patterns, services and `$http` data flow, digest-cycle performance, minification-safe dependency injection (`$inject`/ng-annotate), and Karma/Jasmine testing. Produces a prioritized violations report.

**Use when:**
- Reviewing an AngularJS 1.x pull request or module for code quality
- Hardening minification-safe DI and digest-cycle performance
- Establishing a team code-quality baseline on a legacy codebase

**Example prompt:**
```
Run an AngularJS best-practices check on this project and list violations.
```

**Output:** Prioritized violations report saved to `./reports/`

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

## AngularJS Health Audit

**Aliases:** `ajh`, `somnio-ajh`

Comprehensive **legacy AngularJS (Angular 1.x)** project health audit with 13 analysis steps covering tech stack & runtime, module/component architecture (controllers, directives, `.component()`/controllerAs vs `$scope`), state & data flow (services/factories, `$http` interceptors, `$rootScope`), templating & DOM patterns, digest-cycle hygiene, testing (Karma/Jasmine/angular-mocks), code quality (minification-safe DI, JSHint/ESLint), CI/CD (Grunt/gulp), AI harness, and documentation. Calibrated for the EOL 1.x paradigm (Bower/Grunt) and flags framework/Bower migration risk. Produces a weighted score and a report.

**Use when:**
- Assessing a legacy AngularJS 1.x app before a migration
- Preparing a technical debt or modernization plan
- Running a periodic project health check on a Bower/Grunt codebase

**Example prompt:**
```
Run a full AngularJS health audit on this project and generate a report.
```

**Output:** Weighted score report saved to `./reports/`

---

## Python Health Audit

**Aliases:** `ph`, `somnio-ph`

Comprehensive 13-step health audit for Python projects. Analyses code quality, dependency hygiene, type-annotation coverage, test coverage, security posture, and architectural consistency. Works with any Python project that has a `pyproject.toml` (Poetry, Hatch, PDM, plain PEP 517 builds).

**Use when:**
- Onboarding to an existing Python codebase
- Preparing a technical debt remediation plan for a Python service or library
- Running a periodic project health check on a FastAPI, Django, Flask, or plain Python package

**Example prompt:**
```
Run a full Python health audit on this project and generate a report.
```

**Output:** Weighted score report saved to `./reports/`

---

## Python Best Practices

**Aliases:** `pp`, `somnio-pp`

Micro-level Python code quality validation against team standards. Checks PEP 8 / Ruff compliance, type-annotation usage, test structure, import hygiene, and framework-specific patterns (FastAPI route definitions, Django ORM usage, Flask blueprint layout).

**Use when:**
- Reviewing a pull request for Python code quality
- Enforcing team-wide Python coding standards
- Validating a feature module or service before release

**Example prompt:**
```
Check this Python project against current best practices and flag any violations.
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

**How the hook works:**

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

**Uninstall:**

```bash
rm ~/.claude/hooks/work-log-stop.sh
# then edit ~/.claude/settings.json and remove the work-log-stop.sh entry from hooks.Stop
```

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

## Dart Model from JSON

Generates Dart model classes from a JSON structure using `json_annotation` and `equatable`. Handles nested objects, arrays, nullable fields, and default values. Each nested object becomes a separate class. Includes `copyWith`, `fromJson`, `toJson`, and `props`.

**Use when:**
- You have a JSON API response and need the Dart model classes for it
- You want consistent model generation following project conventions
- You need to quickly scaffold multiple nested model classes

**Example prompt:**
```
Generate Dart models for this JSON: { "id": "123", "name": "John", "address": { "city": "NY" } }
```

**Output:** Dart class definitions (one per nested object) ready to paste into your project files

---

## Optimize Claude Config

Audits and optimizes a repository's Claude Code configuration so path-scoped rules load **lazily** (only when relevant) and `CLAUDE.md` stays a lightweight, always-loaded index. It first maps the **real project tree** with `git ls-files` (top-level domains, monorepo package roots, per-domain extensions, generated/frozen areas) so every path glob is derived from and validated against actual files — including how many files each glob matches. The skill is idempotent (leaves correct config untouched) and conservative (never deletes ambiguous content or auto-applies new scopes without confirmation).

It covers three areas:

1. **Rule frontmatter** (`.claude/rules/**/*.md`) — migrates to the native lazy-load `paths:` YAML array and validates every glob against the tree: eager `globs:` → `paths:`, one-line CSV `paths:` → array, unscoped rules get a proposed scope, **stale globs that match zero files** (the most common silent failure) and over-broad globs are flagged with corrected patterns.
2. **CLAUDE.md slimming** — removes redundant `@import`-only shells, de-duplicates inlined rule bodies (leaving pointers), and preserves hand-written content and healthy indexes.
3. **read-not-create hook** — verifies/installs the `PreToolUse(Write)` hook (`.claude/hooks/inject-rules.py`) that injects a matching rule when a new file is created, working around the caveat that `paths:` rules load on read, not on create.

Not Flutter-specific — the domain/extension map adapts to any stack (detects `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, …). Requires `git` and `python3`.

**Use when:**
- Your `.claude/rules/` have grown and you're not sure they load lazily (or load at all)
- `CLAUDE.md` has bloated with inlined rule bodies or redundant imports
- You want to verify the read-not-create hook is installed

**Invocation:**
```
/optimize-claude-config              # audit, report, confirm, apply
/optimize-claude-config --audit-only # report only, never writes
/optimize-claude-config <path>       # operate on another repo instead of the cwd
```

> Recommended first run: `--audit-only` to review the report before applying anything.

**Output:** An audit report of every rule, CLAUDE.md, and the hook — then, after confirmation, the applied fixes (never committed automatically).

---

## DORA Metrics

Fetches two DORA metrics per project and per repo — **Deployment Frequency** and **Lead Time for Changes** — from the GitHub API only (never a local git clone), so lead time stays accurate regardless of merge strategy (including squash merges).

> **Read-only and non-judgmental.** This skill only fetches and reports the numbers — it never ranks, scores, or compares projects or people. Interpreting the data is a separate, deliberate step left to whoever runs it: mixing measurement with evaluation is how metrics stop being useful (Goodhart's Law).

Projects map to their GitHub repos in `config/projects.json` (mono-repo or multi-repo). If a project isn't in the config yet, the skill asks for its repos instead of guessing, and offers to add it.

**Example prompts:**
```
Run the DORA metrics for Example Project.
```
```
What's the lead time for Example Project over the last 2 weeks?
```
```
Add project Omega to DORA metrics, single repo acme/omega-api, prod branch develop.
```

**Requires:** a GitHub credential with read access to the relevant orgs — the `GITHUB_TOKEN` env var, or `gh auth token` if the GitHub CLI is already logged in locally.

**Output:** Deployment Frequency and median Lead Time per repo for the requested window (14 days by default), plus process-gap warnings (e.g. merged PRs with no release yet, a release with no prior release to measure against). Optionally saved as a portable JSON file.

---

**See also:** [Installation](installation.md) | [CLI Reference](cli.md) | [Workflow Guide](workflows.md)
