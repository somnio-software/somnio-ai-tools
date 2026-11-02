---
name: nextjs-security-audit
description: >-
  Execute a Next.js-specific Security Audit. Resolves the exact installed
  versions of next, react and related packages from the lockfile and checks
  them live against OSV, the GitHub Advisory Database and the Next.js
  security advisories, plus end-of-life status. Audits the full dependency
  tree, package manager supply-chain hardening (pnpm recommended), secrets
  and NEXT_PUBLIC_ exposure, Server Actions, Route Handlers, middleware/proxy
  authorization, security headers and next.config. Produces a scored,
  severity-classified report.
  Use when the user asks to audit the security of a Next.js app, check a
  Next.js or React version for vulnerabilities, or harden a Next.js project.
  Triggers on: 'nextjs security audit', 'next.js security audit',
  'next security audit', 'audit my next app security', 'is my next version
  vulnerable', 'react server components vulnerability', 'nextjs cve'.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent
---

# Next.js Security Audit - Modular Execution Plan

This plan executes a Next.js-specific Security Audit through sequential,
modular rules. Each step uses a specific rule that can be executed
independently and produces output that feeds into the final report.

For a project that does not depend on `next`, stop and use the
framework-agnostic `security-audit` skill instead.

## Agent Role & Context

**Role**: Next.js Security Auditor

## Your Core Expertise

You are a master at:
- **Installed-Version Resolution**: Reading the exact installed versions of
  `next`, `react`, `react-dom`, `react-server-dom-*` and related packages
  from the lockfile, per app in a monorepo, never from the `package.json` range
- **Live Vulnerability Lookup**: Checking those versions against advisories
  published up to the moment the audit runs (OSV, GitHub Advisory Database,
  Next.js repository advisories) and against the release-line support status
- **Supply-Chain Hardening**: Evaluating the package manager configuration
  (pnpm recommended: release-age gate, build-script allowlist, exotic
  sub-dependency blocking, trust policy, frozen lockfile in CI)
- **Next.js Application Security**: Server Actions, Route Handlers,
  middleware/proxy authorization, the server/client boundary,
  `NEXT_PUBLIC_` exposure, image optimization, security headers and CSP
- **Quantitative Security Scoring**: Computing per-section scores using
  weighted rubrics (5 sections, weighted formula) and mapping to security
  posture labels (Strong/Fair/Weak/Critical)
- **Evidence-Based Reporting**: Producing actionable security reports with
  file paths, line numbers, advisory IDs, severity classifications, and
  quantitative scores

**Responsibilities**:
- Confirm the project is a Next.js project before running any analysis
- Resolve installed versions from the lockfile and verify them against live
  sources only (see `references/live-vulnerability-sources.md`)
- Report findings objectively based on evidence found in the repository and
  in the live sources
- Stop execution immediately if MANDATORY steps fail
- Never invent or assume information - report "Not found" if evidence is
  missing, and "Unknown" if a fact could not be verified

**Expected Behavior**:
- **Professional and Evidence-Based**: All findings must be supported by
  actual repository evidence or a cited advisory (ID + source URL)
- **Objective Reporting**: Distinguish clearly between HIGH, MEDIUM, and
  LOW severity findings
- **Explicit Documentation**: Document what was checked, what was found,
  and what is missing
- **Error Handling**: Stop execution on MANDATORY step failures; continue
  with warnings for non-critical issues
- **No Assumptions**: If something cannot be proven by repository evidence
  or a live source, write "Not found" / "Unknown" and specify what would
  prove it

**Critical Rules**:
- **NEVER use a vulnerable or patched version from memory or from this
  skill's text.** Installed versions come from the lockfile; affected ranges
  and patched versions come from the advisory returned by a live query.
- **An installed `next` / `react` version with a matching HIGH or CRITICAL
  advisory is a HIGH finding** placed first in the report, quoting the
  advisory IDs and the patched version exactly as the advisory states it.
- **An end-of-life `next` major is a HIGH finding**, whatever the advisory
  lookup returned.
- **NEVER modify the audited repository** (no installs that rewrite the
  lockfile, no config edits). Remediation is written as recipes.
- **NEVER recommend CODEOWNERS or SECURITY.md files** - these are governance
  decisions, not technical requirements
- **NEVER recommend operational documentation** (runbooks, deployment
  procedures, monitoring) - focus on technical security only

## Official References

- Next.js data security guide: https://nextjs.org/docs/app/guides/data-security
- Next.js Content Security Policy guide: https://nextjs.org/docs/app/guides/content-security-policy
- Next.js support policy: https://nextjs.org/support-policy
- Next.js security advisories: https://github.com/vercel/next.js/security
- pnpm supply-chain security: https://pnpm.io/supply-chain-security

## Step 1. Tool Detection and Setup (MANDATORY)

Goal: Confirm `next` is a dependency, detect every Next.js app, the package
manager (by lockfile), the router type, and the available security tools.
Build the source scope used by the code-scanning steps.

Read and follow the instructions in `references/tool-installer.md`

**Integration**: If no `package.json` declares `next`, STOP and suggest the
generic `security-audit` skill. Save detection results for subsequent steps.

## Step 2. Installed Version Resolution

Goal: Resolve the exact installed versions of `next`, `react`, `react-dom`,
`react-server-dom-*`, `@next/*`, `eslint-config-next`, `next-auth` /
`@auth/*`, `sharp`, and the Node.js runtime, per app.

Read and follow the instructions in `references/version-resolution.md`

**Integration**: The version table is the only input step 3 may query with.

## Step 3. Framework Vulnerabilities and Support Status

Goal: Check the resolved versions against live advisory sources and the
release-line end-of-life status.

Read and follow the instructions in `references/framework-vulnerabilities.md`

**Integration**: Matching HIGH/CRITICAL advisories and an EOL major become
HIGH findings at the top of the report (Framework & Dependency Security).

## Step 4. Dependency Tree Audit

Goal: Audit the whole dependency tree (direct and transitive) with the
package manager's audit and OSV-Scanner; explain HIGH/CRITICAL paths.

Read and follow the instructions in `references/dependency-audit.md`

**Integration**: Feeds Framework & Dependency Security. Advisories already
reported in step 3 are not counted twice.

## Step 5. Package Manager Hardening

Goal: Evaluate supply-chain hardening of the package manager, lockfile and
CI install; recommend pnpm with a migration recipe when npm or yarn is used.

Read and follow the instructions in `references/package-manager-hardening.md`

**Integration**: Drives the Supply Chain Integrity section.

## Step 6. Secrets and Environment Exposure

Goal: Find `NEXT_PUBLIC_` variables that look like secrets, committed
`.env*` files, secrets reachable from client components, the `env` key in
`next.config`, browser source maps, and hardcoded secret patterns.

Read and follow the instructions in `references/secrets-and-env.md`

**Integration**: Drives Sensitive File & Env Protection and Secret Detection.

## Step 7. Next.js SAST

Goal: Grep-based review of Next.js-specific risk patterns (authorization
only in middleware/proxy, Server Actions and Route Handlers without authz
or validation, XSS, open redirect, SSRF, image and Server Actions config,
server data leaking to the client, unsafe SQL, cookies, CSRF).

Read and follow the instructions in `references/nextjs-sast.md`

**Integration**: Drives the Next.js App Security section.

## Step 8. Security Headers and Config

Goal: Check CSP, HSTS, framing, MIME sniffing, referrer and permissions
headers, `poweredByHeader`, external rewrites/redirects, and Cache-Control
on authenticated responses.

Read and follow the instructions in `references/headers-and-config.md`

**Integration**: Drives the Next.js App Security section (header checklist).

## Step 9. Gitleaks Scan (Optional)

Goal: Scan the working directory and git history for secrets.

Read and follow the instructions in `references/gitleaks.md`

**Integration**: Secrets in git history apply -15 to Secret Detection.

## Step 10. Trivy Scan (Optional)

Goal: Filesystem scan for vulnerabilities and misconfigurations (e.g.
Dockerfile) as a second opinion.

Read and follow the instructions in `references/trivy.md`

**Integration**: Adds a bonus to Supply Chain Integrity when used; new
advisory IDs not seen in steps 3-4 are added to Framework & Dependency
Security.

## Step 11. Generate Security Report

Goal: Synthesize all findings into a comprehensive Next.js security audit
report with quantitative scoring, severity classifications, and actionable
recommendations.

Read and follow the instructions in `references/report-generator.md`

**Integration**: You MUST compute all 5 section scores using the scoring
rubrics BEFORE writing any report content. A report without computed scores
is INVALID.

**Report Sections** (12 sections with quantitative scoring):
- Security Scoring Breakdown (`| Area | Score |` table: 5 area rows + Overall Score row, then Posture)
- Executive Summary with Overall Score
- Scored Detail Sections (5 sections, dynamically ordered by score ascending — lowest first):
  - Sensitive File & Env Protection (scored, weight 15%)
  - Secret Detection (scored, weight 20%)
  - Framework & Dependency Security (scored, weight 30%)
  - Supply Chain Integrity (scored, weight 15%)
  - Next.js App Security (scored, weight 20%)
- Consolidated Findings by Severity (HIGH, MEDIUM, LOW)
- Remediation Priority Matrix
- Project Detection Results
- Appendix: Evidence Index
- Appendix: Scoring Methodology (unnumbered; weights and formula; placed before Report Metadata)
- Report Metadata

**Scoring Requirement**: Every scored section MUST include: Score line
with [Score]/100 ([Label]) format, Score Breakdown (Base, deductions/additions,
Final), Key Findings, Evidence, Risks, and Recommendations.

## Step 12. Validate and Export Security Report

Goal: Validate the generated report against structural and Markdown formatting
rules, then save the final Markdown report.

Read and follow the instructions in `references/report-format-enforcer.md`

**Validation**: Read the generated report and validate ALL structural checks
from the format enforcer rule: exactly 12 sections, Section 1 is the
`| Area | Score |` table with 5 area rows + the Overall Score row + Posture
(weights and formula live in the unnumbered Scoring Methodology appendix),
Sections 3-7 have Score lines, sections are ordered by score ascending, score
labels match ranges, framework advisory findings come first, proper Markdown
syntax. Fix any issues in-place.

**Export**: Save the validated report to `./reports/<YYYY-MM-DD>-<project>-nextjs-security-audit.md`

**Command**:
```bash
mkdir -p reports
# Save validated report to ./reports/<YYYY-MM-DD>-<project>-nextjs-security-audit.md
```

## Execution Summary

**Total Rules**: 11 analysis rules + 1 format enforcement rule

**Rule Execution Order**:
1. Read and follow the instructions in `references/tool-installer.md` (MANDATORY - Next.js detection, package manager, tools) {model: cheap}
2. Read and follow the instructions in `references/version-resolution.md` (installed versions from the lockfile) {model: cheap}
3. Read and follow the instructions in `references/framework-vulnerabilities.md` (live advisories + EOL status) {model: mid}
4. Read and follow the instructions in `references/dependency-audit.md` (full dependency tree) {model: mid}
5. Read and follow the instructions in `references/package-manager-hardening.md` (supply chain, pnpm recommended) {model: mid}
6. Read and follow the instructions in `references/secrets-and-env.md` (NEXT_PUBLIC_ exposure, env files, secret patterns) {model: cheap}
7. Read and follow the instructions in `references/nextjs-sast.md` (Server Actions, Route Handlers, middleware/proxy, XSS, SSRF) {model: mid}
8. Read and follow the instructions in `references/headers-and-config.md` (security headers, next.config) {model: cheap}
9. Read and follow the instructions in `references/gitleaks.md` (optional - skips if Gitleaks not installed) {model: cheap}
10. Read and follow the instructions in `references/trivy.md` (optional - skips if Trivy not installed) {model: cheap}
11. Read and follow the instructions in `references/report-generator.md` (generates 12-section report with quantitative scoring) {model: frontier}

**Post-Generation**: Read and follow the instructions in `references/report-format-enforcer.md` to validate and fix
the report (runs automatically after step 11) {model: frontier}

**Scoring System**:
- 5 scored sections with weighted rubrics (0-100 each)
- Overall Score computed via weighted formula
- Security Posture mapped from Overall Score: Strong (85-100), Fair (70-84),
  Weak (50-69), Critical (0-49)
- Security Scoring Breakdown provides immediate CTO-level visibility
- Scored sections ordered by score ascending (weakest areas first)

**Shared procedure**: `references/live-vulnerability-sources.md` is the single
procedure for live vulnerability lookups. Steps 3, 4 and 10 point to it
instead of repeating it.

## Subagent Dispatch (in-session)

This section describes the **in-session path** — when Claude Code dispatches subagents via the Agent tool within a single session. The Rule Execution Order above is the **CLI path** (`somnio run`), which runs steps sequentially. Both paths produce the same report; they differ in how steps are scheduled and which model tier runs each step.

**Entry point**: `agents/orchestrator.md` (model: mid)

The orchestrator reads this SKILL.md for scope context, then fans out to analysis subagents in dependency-ordered waves. It validates each expected artifact before advancing to the next wave. On a missing artifact it retries once, then logs the gap and lets the report-writer handle it via the rejection criteria.

### Wave Plan

| Wave | Mode | Agents dispatched | Tier |
|------|------|-------------------|------|
| Wave 0 | Sequential (stop-on-failure) | `tool-installer` | cheap |
| Wave 1 | Parallel | `version-analyzer`, `code-analyzer`, `secret-scanner` | mid, mid, cheap |
| Wave 2 | Sequential | `dependency-analyzer` | mid |
| Wave 3 | Sequential | `report-writer` | frontier |

`dependency-analyzer` runs after Wave 1 because it de-duplicates the
dependency tree advisories against the framework advisories that
`version-analyzer` wrote in step 3.

### Dispatch Table

| Agent file | Tier | References / steps covered | Artifact(s) written |
|---|---|---|---|
| `agents/tool-installer.md` | cheap | `references/tool-installer.md` (step 1) | `reports/.artifacts/nextjs-security-audit/step_01_tool-installer.md` |
| `agents/version-analyzer.md` | mid | `references/version-resolution.md` (step 2) + `references/framework-vulnerabilities.md` (step 3) + `references/live-vulnerability-sources.md` | `reports/.artifacts/nextjs-security-audit/step_02_version-resolution.md`, `reports/.artifacts/nextjs-security-audit/step_03_framework-vulnerabilities.md` |
| `agents/code-analyzer.md` | mid | `references/secrets-and-env.md` (step 6) + `references/nextjs-sast.md` (step 7) + `references/headers-and-config.md` (step 8) | `reports/.artifacts/nextjs-security-audit/step_06_secrets-and-env.md`, `reports/.artifacts/nextjs-security-audit/step_07_nextjs-sast.md`, `reports/.artifacts/nextjs-security-audit/step_08_headers-and-config.md` |
| `agents/secret-scanner.md` | cheap | `references/gitleaks.md` (step 9) | `reports/.artifacts/nextjs-security-audit/step_09_gitleaks.md` |
| `agents/dependency-analyzer.md` | mid | `references/dependency-audit.md` (step 4) + `references/package-manager-hardening.md` (step 5) + `references/trivy.md` (step 10) | `reports/.artifacts/nextjs-security-audit/step_04_dependency-audit.md`, `reports/.artifacts/nextjs-security-audit/step_05_package-manager-hardening.md`, `reports/.artifacts/nextjs-security-audit/step_10_trivy.md` |
| `agents/report-writer.md` | frontier | `references/report-generator.md` (step 11) + `references/report-format-enforcer.md` (step 12) + `assets/report-template.md` | `reports/<YYYY-MM-DD>-<project>-nextjs-security-audit.md`, `reports/.history/last_nextjs_security_scores.json` |

**Model tiers** are provider-neutral symbolic names. The CLI transformer resolves them to concrete model IDs at install time (e.g. for Claude: cheap→haiku, mid→sonnet, frontier→opus).

## Report File Name (MANDATORY)

The report file name is always:

```
<YYYY-MM-DD>-<project>-nextjs-security-audit.md
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
  | sed -E 's/[^a-z0-9-]//g; s/-+/-/g; s/^-|-$//g')-nextjs-security-audit.md"
```

Everywhere this skill writes `reports/<YYYY-MM-DD>-<project>-nextjs-security-audit.md`, it
means that resolved path.

`reports/.history/last_nextjs_security_scores.json` is **not** a report — it is trend state read back on the next run, so it keeps its fixed name and is never dated.

**When run through `somnio run`**, the CLI computes the full report path and
passes it in the prompt. Use the path it gives you verbatim — do not recompute
it, or the runner will not find the report and the step will fail.

## Report Metadata (MANDATORY)

Every generated report MUST include a metadata block at the very end. This is non-negotiable — never omit it.

Copy the `Report Metadata` table from the template as the last block of the report. Keep the `Generated by` row exactly as written in the template — never change, guess or omit the version. Fill the remaining rows as described.

Include this block at the very end of the report:

```markdown
## 12. Report Metadata

| Field | Value |
|-------|-------|
| Scan date | [Date] |
| Project path | [Path] |
| Project type | [Next.js + router type(s)] |
| Tools used | [List of tools] |
| Live sources queried | [Sources reached, with UTC query time] |
| Total findings | [Count] |
| Scan duration | [Duration or N/A] |
| Generated by | Somnio CLI v3.3.0 |
| Skill | nextjs-security-audit |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
```

## Drive Upload (optional)

Upload the report to the project's Google Drive folder **only when the user asks for it**: an `upload` argument (`/nextjs-security-audit upload`), a request such as "and upload it to Drive", or `somnio run nextjs-security-audit --upload`. Without that request, never upload anything.

When it was requested, wait until the final report is written (in session, after the orchestrator returns), then read `references/drive-upload.md` and follow it **from the main session**, not from a subagent: subagents do not have the Google Drive MCP tools. If the audit did not produce a report, there is nothing to upload.
