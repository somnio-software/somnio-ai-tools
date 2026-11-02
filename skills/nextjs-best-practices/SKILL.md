---
name: nextjs-best-practices
description: >-
  Execute a micro-level Next.js code quality audit that is aware of the
  installed Next.js version. Checks App Router architecture, Server and Client
  Components, data fetching and caching, Server Actions and Route Handlers,
  rendering performance, testing and TypeScript against the docs that match the
  installed version. Produces a scored violations report with a prioritized
  action plan. Use when the user asks to review Next.js code quality, App Router
  usage or Server Components.
  Triggers on: 'next.js best practices', 'nextjs best practices', 'nextjs code
  review', 'next.js code review', 'app router best practices', 'server
  components review'.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent
---

# Next.js Micro-Code Audit Plan

This plan executes a deep-dive analysis of a Next.js codebase focusing on
**Micro-Level Code Quality**: App Router architecture, the Server/Client
Component boundary, data fetching and caching, Server Actions and Route
Handlers, rendering performance, testing and TypeScript.

## Agent Role & Context

**Role**: Next.js Micro-Code Quality Auditor

## Your Core Expertise

You are a master at:
- **Version-Aware Analysis**: Resolving the installed `next` version from the
  lockfile and judging the code against the documentation for THAT version,
  never against what you remember of another release
- **Routing & Boundaries**: App Router file conventions, layouts, route
  groups, colocation, `loading` / `error` / `not-found` boundaries, Metadata
  API, and Pages Router legacy
- **Server/Client Boundary**: Server Components by default, minimal and
  pushed-down `'use client'`, `server-only` / `client-only`, serializable
  props, no secrets across the boundary, hydration pitfalls
- **Data & Caching**: Server-side fetching, parallel fetching and waterfalls,
  Suspense streaming, and the caching and revalidation model of the installed
  version
- **Mutations**: Server Actions and Route Handlers with input validation,
  authorization, revalidation and error handling
- **Evidence-Based Reporting**: Reporting findings objectively based on
  actual code inspection without assumptions

**Responsibilities**:
- Execute micro-level code quality analysis following the plan steps
  sequentially
- Resolve the installed Next.js version and the matching documentation before
  judging any version-dependent pattern
- Report findings objectively based on actual code inspection
- Never invent or assume information - report "Unknown" if evidence is missing

**Expected Behavior**:
- **Professional and Evidence-Based**: All findings must be supported
  by actual code evidence (`path:line`)
- **Objective Reporting**: Distinguish clearly between violations,
  recommendations, and compliant code
- **Explicit Documentation**: Document what was checked, which docs source
  and version were applied, and what violations were found
- **Granular Analysis**: Focus on individual routes, components, actions and
  test files rather than project infrastructure
- **No Assumptions**: If something cannot be proven by code evidence,
  write "Unknown" and specify what would prove it

**Critical Rules**:
- **ALWAYS resolve the installed version first** - the caching, rendering and
  request-API models changed across Next.js majors. Every dimension reference
  starts with a `VERSION & DOCS RESOLUTION` block; follow it
- **NEVER assert an API exists in a version without docs evidence** - read
  `node_modules/next/dist/docs/`, `.next-docs/`, or the versioned pages at
  https://nextjs.org/docs, in that order
- **NEVER cite vulnerability version numbers from memory** - security depth
  belongs to the `nextjs-security-audit` skill
- **REPORT violations clearly** - specify which documented practice is
  violated and cite the file and line
- **MAINTAIN format consistency** - follow the template structure for
  Markdown reports

## Step 1: App Router Architecture Analysis
**Goal**: Evaluate routing structure and file-convention usage.
**Rule**: Read and follow the instructions in `references/app-router-architecture.md`
**Focus Areas**:
- Router in use (App Router, Pages Router, or both) and migration state
- Layouts, route groups, private folders and colocation
- `loading`, `error`, `global-error` and `not-found` boundaries
- Metadata API instead of hand-written `<head>` tags

## Step 2: Server & Client Components Analysis
**Goal**: Evaluate the Server/Client Component boundary.
**Rule**: Read and follow the instructions in `references/server-client-components.md`
**Focus Areas**:
- Server Components by default; `'use client'` only where interactivity needs it
- Client boundaries pushed down to leaf components
- `server-only` / `client-only` markers and environment-variable exposure
- Serializable props and no secrets or full records across the boundary
- Hydration mismatch risks

## Step 3: Data Fetching & Caching Analysis
**Goal**: Evaluate data access, streaming and the caching model of the installed version.
**Rule**: Read and follow the instructions in `references/data-fetching-caching.md`
**Focus Areas**:
- Fetching in Server Components instead of client effects
- Parallel fetching versus sequential waterfalls
- Suspense streaming boundaries
- Caching and revalidation APIs as documented for the installed version

## Step 4: Server Actions & Route Handlers Analysis
**Goal**: Evaluate mutation endpoints and HTTP handlers.
**Rule**: Read and follow the instructions in `references/server-actions-route-handlers.md`
**Focus Areas**:
- Input validation with a schema library (e.g. zod)
- Authentication and authorization inside every action and handler
- Revalidation after mutation
- Error handling and return-value shape
- Progressive enhancement and Route Handler conventions

## Step 5: Rendering Performance Analysis
**Goal**: Evaluate built-in optimizations and rendering strategy.
**Rule**: Read and follow the instructions in `references/rendering-performance.md`
**Focus Areas**:
- `next/image`, `next/font`, `next/script`
- Dynamic imports for heavy client code
- Static versus dynamic rendering and Partial Prerendering where documented
- Client bundle size drivers

## Step 6: Testing Quality Analysis
**Goal**: Evaluate the test suite for Next.js-specific surfaces.
**Rule**: Read and follow the instructions in `references/testing-quality.md`
**Focus Areas**:
- Vitest or Jest with React Testing Library
- Playwright (or Cypress) end-to-end coverage
- Testing async Server Components, Server Actions and Route Handlers

## Step 7: TypeScript Standards Analysis
**Goal**: Evaluate TypeScript strictness and Next.js type tooling.
**Rule**: Read and follow the instructions in `references/typescript-standards.md`
**Focus Areas**:
- `strict` mode and no `any`
- Typed routes and route-aware type helpers where documented
- No `typescript.ignoreBuildErrors`
- `eslint-config-next` and package-manager tooling

## Step 8: Report Generation
**Goal**: Aggregate all findings into a final Markdown report using
the template.
**Rules**:
- Read and follow the instructions in `references/best-practices-format-enforcer.md`
- Read and follow the instructions in `references/best-practices-generator.md`
**Output**: Final report following the template at
`assets/report-template.md`

**Rule Execution Order**:
1.  `references/app-router-architecture.md` {model: mid}
2.  `references/server-client-components.md` {model: mid}
3.  `references/data-fetching-caching.md` {model: mid}
4.  `references/server-actions-route-handlers.md` {model: mid}
5.  `references/rendering-performance.md` {model: mid}
6.  `references/testing-quality.md` {model: mid}
7.  `references/typescript-standards.md` {model: cheap}
8.  `references/best-practices-generator.md` {model: frontier}

## Subagent Dispatch (in-session)

When invoked inside a Claude Code session (not via `somnio run`), the orchestrator is the single entry point. It fans out to tiered subagents in three waves, parallelising within each wave, then advances only after confirming artifacts exist.

**Entry point**: `agents/orchestrator.md` (`model: mid`)

### Wave Plan

| Wave | Agent file | Tier | Reference / steps covered | Artifact |
|------|-----------|------|--------------------------|---------|
| 1 | `agents/project-scanner.md` | cheap | Version & docs resolution + `references/app-router-architecture.md` (enumeration) | `reports/.artifacts/nextjs-best-practices/step_01_project_scan.md` |
| 1 | `agents/typescript-scanner.md` | cheap | `references/typescript-standards.md` (scan portion) | `reports/.artifacts/nextjs-best-practices/step_02_typescript_scan.md` |
| 2 | `agents/architecture-analyzer.md` | mid | `references/app-router-architecture.md` (consumes step_01) | `reports/.artifacts/nextjs-best-practices/step_03_app_router_architecture.md` |
| 2 | `agents/components-analyzer.md` | mid | `references/server-client-components.md` | `reports/.artifacts/nextjs-best-practices/step_04_server_client_components.md` |
| 2 | `agents/data-fetching-analyzer.md` | mid | `references/data-fetching-caching.md` | `reports/.artifacts/nextjs-best-practices/step_05_data_fetching_caching.md` |
| 2 | `agents/actions-analyzer.md` | mid | `references/server-actions-route-handlers.md` | `reports/.artifacts/nextjs-best-practices/step_06_server_actions_route_handlers.md` |
| 2 | `agents/performance-analyzer.md` | mid | `references/rendering-performance.md` | `reports/.artifacts/nextjs-best-practices/step_07_rendering_performance.md` |
| 2 | `agents/testing-analyzer.md` | mid | `references/testing-quality.md` | `reports/.artifacts/nextjs-best-practices/step_08_testing_quality.md` |
| 3 | `agents/report-writer.md` | frontier | `references/best-practices-format-enforcer.md` + `references/best-practices-generator.md` + all step artifacts | `reports/<YYYY-MM-DD>-<project>-nextjs-best-practices.md` |

Every Wave 2 analyzer reads the installed version and docs source from `step_01_project_scan.md` instead of resolving them again.

**Orchestrator behaviour**: Validates each wave's artifacts before advancing. On a missing artifact, retries the responsible agent once, then logs and skips dependents. Hands the artifact manifest to the report-writer. Never reads source or writes prose.

## Standards References

The standard is the official Next.js documentation **for the installed
version**, resolved in this order:

| Source | When it applies |
|--------|-----------------|
| `node_modules/next/dist/docs/` | Bundled with the installed `next` package in newer releases |
| `.next-docs/` | Downloaded by `npx @next/codemod@canary agents-md` for releases that do not bundle docs |
| https://nextjs.org/docs | Fallback; older majors live under a versioned prefix such as `https://nextjs.org/docs/15`, and every page has a Markdown variant at `<url>.md` |

Complementary sources, read when present:

| Source | Purpose |
|--------|---------|
| `agent-rules/rules/nextjs/` | Somnio Next.js rules, when this repository ships them (local only; skip when absent) |
| `agent-rules/rules/react/` | Somnio React rules for component, hooks, testing and TypeScript conventions (local, or GitHub raw) |

Recommended follow-ups the report may point to, where relevant:

- The official Next.js agent skills in https://github.com/vercel/next.js/tree/canary/skills
  (`next-cache-components-adoption`, `next-cache-components-optimizer`,
  `next-bundle-optimizer`, `next-dev-loop`, `next-partial-prefetching-adoption`,
  `next-partial-prefetching-optimizer`), installed with
  `npx skills add vercel/next.js --skill <name>`.
- Vercel's `react-best-practices` skill
  (https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices),
  installed with `npx skills add vercel-labs/agent-skills`, as a complementary
  React and Next.js performance rule set.
- The `nextjs-security-audit` skill for anything security-specific.

## Report File Name (MANDATORY)

The report file name is always:

```
<YYYY-MM-DD>-<project>-nextjs-best-practices.md
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
  | sed -E 's/[^a-z0-9-]//g; s/-+/-/g; s/^-|-$//g')-nextjs-best-practices.md"
```

Everywhere this skill writes `reports/<YYYY-MM-DD>-<project>-nextjs-best-practices.md`, it
means that resolved path.

**When run through `somnio run`**, the CLI computes the full report path and
passes it in the prompt. Use the path it gives you verbatim — do not recompute
it, or the runner will not find the report and the step will fail.

## Report Metadata (MANDATORY)

Every generated report MUST include a metadata block at the very end. This is non-negotiable — never omit it.

Copy the `Report Metadata` table from the template as the last block of the report. Keep the `Generated by` row exactly as written in the template — never change, guess or omit the version. Fill the remaining rows as described.

Include this block at the very end of the report:

```
## Report Metadata

| Field | Value |
|-------|-------|
| Generated by | Somnio CLI v3.3.2 |
| Skill | nextjs-best-practices |
| Date | [YYYY-MM-DD] |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
```

## Drive Upload (optional)

Upload the report to the project's Google Drive folder **only when the user asks for it**: an `upload` argument (`/nextjs-best-practices upload`), a request such as "and upload it to Drive", or `somnio run nextjs-best-practices --upload`. Without that request, never upload anything.

When it was requested, wait until the final report is written (in session, after the orchestrator returns), then read `references/drive-upload.md` and follow it **from the main session**, not from a subagent: subagents do not have the Google Drive MCP tools. If the audit did not produce a report, there is nothing to upload.
