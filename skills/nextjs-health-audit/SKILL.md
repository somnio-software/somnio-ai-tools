---
name: nextjs-health-audit
description: >-
  Execute a comprehensive Next.js Project Health Audit. Analyzes tech stack
  (installed next/react versions, live advisory and end-of-life checks,
  package manager), App Router / Pages Router architecture, data and state
  (Server Components, Server Actions, caching), testing, code quality,
  performance, CI/CD, documentation and AI harness. Produces a shareable
  Markdown report with section scores and a weighted overall score. Use when
  the user asks to audit a Next.js project, run a Next.js health check,
  evaluate a Next.js app's quality, or assess technical debt in a Next.js
  codebase. Triggers on: 'next.js audit', 'nextjs audit', 'nextjs health',
  'next.js health', 'next audit', 'app router audit', 'next.js health check'.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent, Task
---

# Next.js Project Health Audit - Modular Execution Plan

This plan executes the Next.js Project Health Audit through sequential,
modular rules. Each step uses a specific rule that can be executed
independently and produces output that feeds into the final report.

## Agent Role & Context

**Role**: Next.js Project Health Auditor

## Your Core Expertise

You are a master at:
- **Comprehensive Project Auditing**: Evaluating all aspects of Next.js
  project health (tech stack, architecture, data and state management,
  testing, code quality, performance, CI/CD, documentation, AI harness)
- **Evidence-Based Analysis**: Analyzing repository evidence objectively
  without inventing data or making assumptions
- **Modular Rule Execution**: Coordinating sequential execution of 14
  specialized analysis rules
- **Score Calculation**: Calculating section scores (0-100) and weighted
  overall scores accurately
- **Technical Risk Assessment**: Identifying technical risks, technical
  debt, dependency advisories and project maturity indicators
- **Report Integration**: Synthesizing findings from multiple analysis
  rules into unified Markdown reports
- **Next.js Expertise**: App Router and Pages Router, Server and Client
  Components, Server Actions, Route Handlers, Proxy, caching and
  revalidation, `next/image`, `next/font`, `next/script`, Turbopack
- **Current APIs Only**: Next.js APIs change between majors. Before
  stating that an API, config option or command exists, check it against
  the official docs for the installed version (https://nextjs.org/docs,
  or the version-matched copy in `node_modules/next/dist/docs/` on
  Next.js 16.2+). Never invent an API

**Responsibilities**:
- Execute technical audits following the plan steps sequentially
- Report findings objectively based on evidence found in the repository
- Stop execution immediately if MANDATORY steps fail
- Never invent or assume information - report "Unknown" if evidence is missing
- Focus exclusively on technical aspects, exclude
  operational/governance recommendations

**Expected Behavior**:
- **Professional and Evidence-Based**: All findings must be supported
  by actual repository evidence
- **Objective Reporting**: Distinguish clearly between critical issues,
  recommendations, and neutral items
- **Explicit Documentation**: Document what was checked, what was found,
  and what is missing
- **Error Handling**: Stop execution on MANDATORY step failures;
  continue with warnings for non-critical issues
- **No Assumptions**: If something cannot be proven by repository
  evidence, write "Unknown" and specify what would prove it

**Critical Rules**:
- **NEVER recommend CODEOWNERS or SECURITY.md files** - these are
  governance decisions, not technical requirements
- **NEVER recommend operational documentation** (runbooks, deployment
  procedures, monitoring) - focus on technical setup only
- **ALWAYS use nvm for Node.js version management** - global
  configuration is MANDATORY
- **pnpm FIRST, never migrate**: detect the package manager from the
  lockfile. With `pnpm-lock.yaml`, run `corepack enable` and
  `pnpm install --frozen-lockfile`. With npm/yarn/bun, install with what
  the repository uses (frozen/immutable) and record the finding
  "not using pnpm" for the Tech Stack and CI/CD sections. Never delete,
  convert or regenerate a lockfile
- **ALWAYS execute comprehensive dependency management** - in a
  workspace monorepo (pnpm workspaces, Turborepo, Nx) one frozen install
  at the root installs every app and package
- **NEVER state a vulnerable or patched version from memory** - installed
  versions come from the lockfile, advisories from live sources
  (`references/live-vulnerability-sources.md`)

**Execution Discipline (NON-NEGOTIABLE)**:
- **NEVER skip, combine, or abbreviate any step** — each step in this plan
  MUST be executed individually and completely
- **NEVER summarize a reference file instead of executing it** — you MUST
  read each reference file AND follow its instructions fully
- **NEVER take shortcuts** — even if you believe you already know the answer,
  you MUST execute the analysis commands and collect real evidence
- **ALWAYS read the reference file first** — before executing any step, read
  the referenced .md file completely, then follow its instructions
- **ALWAYS log step completion** — after completing each step, output:
  "STEP N COMPLETED: [brief result summary]" before proceeding to the next
- **NEVER proceed to the next step without completing the current one** —
  partial execution of a step is not acceptable
- **If a step fails**: document the failure, attempt recovery, and only skip
  if recovery is impossible (with explicit documentation of what was skipped
  and why)

## REQUIREMENT - NODE.JS VERSION ALIGNMENT

**MANDATORY STEP 0**: Before executing any Next.js project analysis,
ALWAYS verify and align the Node.js version with the project's
required version using nvm.

**Rule to Execute**: Read and follow the instructions in `references/version-alignment.md`

**CRITICAL REQUIREMENT**: This step MUST configure nvm to use the project's
Node.js version. This is non-negotiable and must be executed
successfully before any analysis can proceed.

This requirement applies to ANY Next.js project regardless of versions
found and ensures accurate analysis by preventing version-related build
failures.

## Step 0. Node.js Environment Setup and Test Coverage Verification

Goal: Configure the Node.js environment with MANDATORY nvm configuration,
install dependencies with the repository's package manager and frozen
lockfile, validate the install (installed `next`/`react` versions,
non-blocking `next build` and type check), and generate test coverage.

**CRITICAL**: This step MUST configure nvm to use the project's Node.js
version and install ALL dependencies. Execution stops if nvm
configuration fails.

**Rules to Execute**:
1. Read and follow the instructions in `references/tool-installer.md` (MANDATORY: installs nvm, Node.js, enables the package manager — pnpm via Corepack first)
2. Read and follow the instructions in `references/version-alignment.md` (MANDATORY - stops if fails)
3. Read and follow the instructions in `references/version-validator.md`
4. Read and follow the instructions in `references/test-coverage.md` (coverage generation)

**Execution Order**:
1. Execute `references/tool-installer.md` rule first (MANDATORY - stops if fails)
2. Execute `references/version-alignment.md` rule (MANDATORY - stops if fails)
3. Execute `references/version-validator.md` rule to verify nvm setup,
   the frozen install, installed versions, build and type check
4. Execute `references/test-coverage.md` rule to generate coverage

**Comprehensive Dependency Management**:
- `pnpm-lock.yaml`: `corepack enable && pnpm install --frozen-lockfile`
- `package-lock.json`: `npm ci` (finding: not using pnpm)
- `yarn.lock`: `corepack enable && yarn install --immutable` (Yarn 1:
  `--frozen-lockfile`) (finding: not using pnpm)
- Workspace monorepo: one install at the root; never per-directory
  installs inside a workspace
- Verification: `pnpm list --depth 0` / `npm ls --depth=0`

**Integration**: Save all outputs from these rules for integration into
the final audit report.

**Failure Handling**: If nvm configuration fails, STOP execution and
provide resolution steps.

## Parallel Execution Strategy

Steps 1-9 can be partially parallelized using the Agent tool to launch
multiple analysis agents simultaneously. Use the following wave structure:

**Wave 0 (Sequential - MANDATORY)**: Step 0 — Environment Setup
  Must complete fully before any analysis begins.

**Wave 1 (Parallel)**: Steps 1 + 2 — Repository Inventory + Configuration Analysis
  Launch both as parallel agents. Both read from the filesystem independently.

**Wave 2 (Parallel)**: Steps 3 + 4 + 5 + 8 — CI/CD + Testing + Code Quality + AI Harness & Adoption
  Launch all four as parallel agents. Independent read-only analyses; the
  AI Harness & Adoption step depends on no prior artifact.

**Wave 3 (Parallel)**: Steps 6 + 7 + 9 — State Management + Documentation + Dependency & Security
  Launch all three as parallel agents. Independent analyses; the
  Dependency & Security step needs network access for its live lookups.

**Wave 4 (Sequential)**: Steps 10 + 11 — Report Generation + Export
  Must run last — requires ALL previous results.

**Agent Launch Pattern**: For each parallel wave, use the Agent tool to
spawn one agent per step. Each agent MUST:
1. Read the referenced .md file completely
2. Execute ALL instructions in that file
3. Return the complete analysis results
4. Never abbreviate or summarize — return full evidence

Example for Wave 1:
- Agent 1: "Read references/repository-inventory.md and execute ALL instructions. Return complete findings."
- Agent 2: "Read references/config-analysis.md and execute ALL instructions. Return complete findings."

## Step 1. Repository Inventory

Goal: Detect the Next.js apps, router model (App Router / Pages Router /
mixed), `src/` layout, route groups, parallel and intercepting routes,
`proxy.ts` or the deprecated `middleware.ts`, `instrumentation.ts`,
output mode (standalone/export), Turbopack vs webpack, monorepo setup
and deploy target hints.

**Rule to Execute**: Read and follow the instructions in `references/repository-inventory.md`

**Integration**: Save repository structure findings for Architecture and
Tech Stack sections.

## Step 2. Core Configuration Files

Goal: Deep review of `next.config.*` (images, experimental flags,
`typescript.ignoreBuildErrors` / `eslint` red flags, headers, output),
`tsconfig.json`, ESLint (`eslint-config-next` /
`@next/eslint-plugin-next`), Prettier and environment-variable
conventions.

**Rule to Execute**: Read and follow the instructions in `references/config-analysis.md`

**Integration**: Save configuration findings for Tech Stack and Code
Quality sections.

## Step 3. CI/CD Workflows Analysis

Goal: Read all CI workflows: frozen install, lint, type check, tests,
`next build`, `.next/cache` caching and preview deployments.

**Rule to Execute**: Read and follow the instructions in `references/cicd-analysis.md`

**Integration**: Save CI/CD findings for CI/CD section scoring.

## Step 4. Testing Infrastructure

Goal: Find and classify all test files: Vitest/Jest with React Testing
Library, Playwright/Cypress E2E, and how Server Actions, Route Handlers
and async Server Components are tested.

**Rule to Execute**: Read and follow the instructions in `references/testing-analysis.md`

**Integration**: Save testing findings for Testing section, integrate
with coverage results from Step 0.

## Step 5. Code Quality and Linter

Goal: Analyze ESLint, TypeScript strictness and formatting, and collect
the Next.js usage signals (`'use client'` surface, `next/image`,
`next/font`, `next/script`, dynamic imports, bundle analysis) used by
the Code Quality and Performance sections.

**Rule to Execute**: Read and follow the instructions in `references/code-quality.md`

**Integration**: Save code quality findings for Code Quality and
Performance section scoring.

## Step 6. Data & State Management Analysis

Goal: Analyze the server/client state boundary, React Server Component
data fetching, Server Actions and revalidation, the caching model
(`use cache` / Cache Components, or the previous fetch-cache model) and
client state libraries.

**Rule to Execute**: Read and follow the instructions in `references/state-management-analysis.md`

**Integration**: Save findings for State Management section scoring.

## Step 7. Documentation and Operations

Goal: Review the README, environment setup, Storybook, architecture
documentation (including caching and rendering strategy) and
agent-facing docs.

**Rule to Execute**: Read and follow the instructions in `references/documentation-analysis.md`

**Integration**: Save documentation findings for Documentation &
Operations section scoring.

## Step 8. AI Harness & Adoption Analysis

Goal: Analyze the project's AI harness — CLAUDE.md / AGENTS.md
(including the managed Next.js agent block), `.claude/rules/`,
`settings.json` permissions and hooks, `.claude/agents/`,
commands/skills (including official Next.js skills), and the pre-push
git hook — judging quality, not just presence, against the
10-dimension, 100-point rubric. Existence is judged on disk; whether the
harness is committed is scored once, in dimension 10.

**Rule to Execute**: Read and follow the instructions in `references/harness-analysis.md`

**Integration**: Save the AI Harness & Adoption findings, score, and
maturity band for the AI Harness & Adoption section scoring.

## Step 9. Dependency & Security Analysis

Goal: Resolve the installed `next`, `react` and `react-dom` versions from
the lockfile, check them and the whole tree against live advisory
sources (OSV, GitHub Advisory Database), check the installed Next.js
major's support status (endoflife.date), run the package manager's
audit, and record package-manager hygiene. Follows
`references/live-vulnerability-sources.md`; no version is ever taken
from memory.

**Rule to Execute**: Read and follow the instructions in `references/dependency-security-analysis.md`

**Integration**: Feeds the existing Tech Stack section — not a new
section. For depth, recommend `/somnio:nextjs-security-audit`.

## Step 10. Generate Final Report

Goal: Generate the final Next.js Project Health Audit report by
integrating all analysis results.

**Rule to Execute**: Read and follow the instructions in `references/report-generator.md`

**Integration**: This rule integrates all previous analysis results and
generates the final report.

**Report Sections**:
- Executive Summary with overall score
- At-a-Glance Scorecard with all 9 section scores, plus the Test
  Coverage line and a one-sentence interpretation of the Overall Score
- All 9 detailed sections (Tech Stack, Architecture, State Management,
  Testing, Code Quality, Performance, Documentation &
  Operations, CI/CD, AI Harness & Adoption)
- Additional Metrics (no coverage percentages — those live only in the
  scorecard Test Coverage line and the Testing section's Code Coverage
  / Coverage Breakdown fields)
- Risks & Opportunities (5-8 bullets)
- Recommendations (6-10 prioritized actions)
- Appendix: Evidence Index
- Appendix: Scoring Methodology (unnumbered, trailing)

**Note**: After this step completes, the CLI automatically runs
`references/report-format-enforcer.md` to validate and fix the
generated report's structure before export.

## Step 11. Export Final Report

Goal: Save the final shareable Markdown report to the reports
directory.

**Action**: Create the reports directory if it doesn't exist and save
the final Next.js Project Health Audit report to:
`./reports/<YYYY-MM-DD>-<project>-nextjs-health-audit.md`

**Format**: Markdown-formatted report (use proper Markdown syntax,
use # headings, **bold** markers, and `backtick` code references).

**Command**:
```bash
mkdir -p reports
# Save report content to ./reports/<YYYY-MM-DD>-<project>-nextjs-health-audit.md
```

**Note**: For security analysis, run the standalone Next.js Security Audit (`/somnio:nextjs-security-audit`).

## Execution Summary

**Total Rules**: 14 rules

**Rule Execution Order**:
1. `references/tool-installer.md` {model: cheap}
2. `references/version-alignment.md` (MANDATORY - stops if nvm fails) {model: cheap}
3. `references/version-validator.md` (verification of nvm setup) {model: cheap}
4. `references/test-coverage.md` (coverage generation) {model: cheap}
5. `references/repository-inventory.md` {model: cheap}
6. `references/config-analysis.md` {model: cheap}
7. `references/cicd-analysis.md` {model: cheap}
8. `references/testing-analysis.md` {model: mid}
9. `references/code-quality.md` {model: mid}
10. `references/state-management-analysis.md` {model: mid}
11. `references/documentation-analysis.md` {model: cheap}
12. Read and follow the instructions in `references/harness-analysis.md` {model: mid}
13. `references/dependency-security-analysis.md` (live advisory lookup, feeds Tech Stack) {model: mid}
14. `references/report-generator.md` {model: frontier}

**Wave-Based Parallel Execution**:
- Wave 0 (Sequential): Step 0 — Environment Setup (rules 1-4)
- Wave 1 (Parallel): Steps 1 + 2 — Repository Inventory + Configuration (rules 5-6)
- Wave 2 (Parallel): Steps 3 + 4 + 5 + 8 — CI/CD + Testing + Code Quality + AI Harness & Adoption (rules 7-9, 12)
- Wave 3 (Parallel): Steps 6 + 7 + 9 — State Management + Documentation + Dependency & Security (rules 10-11, 13)
- Wave 4 (Sequential): Steps 10 + 11 — Report Generation + Export (rule 14)

## Subagent Dispatch (in-session)

This section describes the **in-session path** when Claude Code dispatches subagents via the Agent/Task tool. The Rule Execution Order above remains the **CLI path** (`somnio run`). Both paths use the same references as the single source of truth; only the dispatch mechanism differs.

**Entry point**: `agents/orchestrator.md` (`model: mid`) — single dispatch target. The orchestrator coordinates all waves and never reads source files or writes report prose.

### Wave Plan

| Wave | Mode | Agents dispatched | Tier |
|------|------|-------------------|------|
| Wave 0 | Sequential — MANDATORY gate | `env-setup-agent` | cheap |
| Wave 1 | Parallel | `repo-analyzer`, `config-analyzer` | cheap, cheap |
| Wave 2 | Parallel | `cicd-analyzer`, `testing-analyzer`, `code-quality-analyzer`, `harness-analyzer` | cheap, mid, mid, mid |
| Wave 3 | Parallel | `state-management-analyzer`, `docs-analyzer`, `dependency-security-analyzer` | mid, cheap, mid |
| Wave 4 | Sequential | `report-writer` | frontier |

Wave 0 emits a GATE status; the orchestrator halts all subsequent waves on `GATE: FAILED`.

### Dispatch Table

| Agent file | Tier | Reference(s) covered | Artifact path |
|------------|------|----------------------|---------------|
| `agents/env-setup-agent.md` | cheap | tool-installer, version-alignment, version-validator, test-coverage | `reports/.artifacts/nextjs-health-audit/step_00_env_setup.md` |
| `agents/repo-analyzer.md` | cheap | repository-inventory | `reports/.artifacts/nextjs-health-audit/step_01_repository_inventory.md` |
| `agents/config-analyzer.md` | cheap | config-analysis | `reports/.artifacts/nextjs-health-audit/step_02_config_analysis.md` |
| `agents/cicd-analyzer.md` | cheap | cicd-analysis | `reports/.artifacts/nextjs-health-audit/step_03_cicd_analysis.md` |
| `agents/testing-analyzer.md` | mid | testing-analysis | `reports/.artifacts/nextjs-health-audit/step_04_testing_analysis.md` |
| `agents/code-quality-analyzer.md` | mid | code-quality | `reports/.artifacts/nextjs-health-audit/step_05_code_quality.md` |
| `agents/state-management-analyzer.md` | mid | state-management-analysis | `reports/.artifacts/nextjs-health-audit/step_06_state_management.md` |
| `agents/docs-analyzer.md` | cheap | documentation-analysis | `reports/.artifacts/nextjs-health-audit/step_07_documentation.md` |
| `agents/harness-analyzer.md` | mid | harness-analysis | `reports/.artifacts/nextjs-health-audit/step_08_harness_analysis.md` |
| `agents/dependency-security-analyzer.md` | mid | dependency-security-analysis, live-vulnerability-sources | `reports/.artifacts/nextjs-health-audit/step_09_dependency_security.md` |
| `agents/orchestrator.md` | mid | (routing only — reads no reference) | n/a |
| `agents/report-writer.md` | frontier | report-generator, report-format-enforcer | `reports/<YYYY-MM-DD>-<project>-nextjs-health-audit.md` |

Tiers (`cheap`/`mid`/`frontier`) are symbolic and provider-neutral. The CLI transformer resolves them to concrete model IDs per `AgentConfig.modelTiers` at install time.

**Benefits of Modular Approach**:
- Each rule can be executed independently
- Outputs can be saved and reused
- Easier debugging and maintenance
- Wave-based parallelization accelerates analysis using the Agent tool
- Clear separation of concerns
- Strict no-shortcuts enforcement ensures complete, evidence-based analysis
- Frozen, lockfile-faithful dependency installs (pnpm first)
- Complete nvm configuration enforcement
- Live, evidence-backed dependency advisories instead of remembered versions

## Report File Name (MANDATORY)

The report file name is always:

```
<YYYY-MM-DD>-<project>-nextjs-health-audit.md
```

- `<YYYY-MM-DD>` — the date of this run.
- `<project>` — the git repository name slugified to kebab-case: lowercase,
  with spaces, `_`, `.` and `/` turned into `-`, every other character dropped,
  and repeated `-` collapsed. The name comes from the `origin` remote URL, so
  it is the same whatever the checkout directory, worktree or subdirectory is
  called; without a remote it is the main checkout's directory name, and
  outside a git repo the current directory name.
- The trailing segment is this skill's name and never changes.

Derive it once, before writing anything:

```bash
mkdir -p reports
REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#/+$##; s#.*[/:]##; s#\.git$##')"
if [ -z "$REPO" ]; then
  COMMON="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  [ -n "$COMMON" ] && REPO="$(basename "${COMMON%/.git}" .git)"
fi
[ -n "$REPO" ] || REPO="$(basename "$PWD")"
REPORT="reports/$(date +%F)-$(printf '%s' "$REPO" \
  | tr '[:upper:]' '[:lower:]' | tr ' _./' '-' \
  | sed -E 's/[^a-z0-9-]//g; s/-+/-/g; s/^-|-$//g')-nextjs-health-audit.md"
```

Everywhere this skill writes `reports/<YYYY-MM-DD>-<project>-nextjs-health-audit.md`, it
means that resolved path.

**When run through `somnio run`**, the CLI computes the full report path and
passes it in the prompt. Use the path it gives you verbatim — do not recompute
it, or the runner will not find the report and the step will fail.

## Report Metadata (MANDATORY)

Every generated report MUST include a metadata block at the very end. This is non-negotiable — never omit it.

Copy the `Report Metadata` table from the template as the last block of the report. Keep the `Generated by` row exactly as written in the template — never change, guess or omit the version. Fill the remaining rows as described.

Include this block at the very end of the report:

```markdown
## Report Metadata

| Field | Value |
|-------|-------|
| Generated by | Somnio CLI v3.3.3 |
| Skill | nextjs-health-audit |
| Date | [YYYY-MM-DD] |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
```

## Drive Upload (optional)

Upload the report to the project's Google Drive folder **only when the user asks for it**: an `upload` argument (`/nextjs-health-audit upload`), a request such as "and upload it to Drive", or `somnio run nextjs-health-audit --upload`. Without that request, never upload anything.

When it was requested, wait until the final report is written (in session, after the orchestrator returns), then read `references/drive-upload.md` and follow it **from the main session**, not from a subagent: subagents do not have the Google Drive MCP tools. If the audit did not produce a report, there is nothing to upload.
