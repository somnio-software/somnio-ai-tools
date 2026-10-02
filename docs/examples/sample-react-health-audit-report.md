> **⚠️ FICTIONAL WORKED EXAMPLE — NOT A REAL AUDIT.**
> This file is a fabricated sample produced solely to validate the `react-health-audit`
> report template end-to-end. **"Ledgerly" does not exist.** It is not this repository
> (`somnio-ai-tools`), and it is not any other real codebase. Every score, percentage,
> file path, finding, evidence item, and metric below is invented for illustration only.
> **Do not cite anything in this document as a real audit result, and do not treat any
> path below as pointing at real code.**

# React Project Health Audit Report

**Project:** Ledgerly (fictional expense-tracking SPA — example only, does not exist)
**Date:** 2026-09-18
**Auditor:** AI-Assisted Analysis
**Framework:** Next.js 14.2.3 (App Router), React 18.3.1, TypeScript 5.4.5

> **Exclusions:** Never recommend adding new languages/translations, CODEOWNERS/SECURITY.md files, or deployment-specific workflows.

---

## 1. Executive Summary

**Description:** Ledgerly is a fictional React 18 / Next.js 14 App Router expense-tracking single-page application, using Zustand for client state and TanStack Query for server-cache state, tested with Vitest and Testing Library; this fabricated audit exercises the report template against a believable mixed-maturity codebase.

**Overall Score:** 71/100 (Fair)

**Top Strengths:**
- Strong runtime performance: Core Web Vitals are green in the fabricated Lighthouse CI run (LCP 1.9s, CLS 0.03, INP 145ms), helped by route-level code splitting and a virtualized transaction list.
- Clean state-boundary split between Zustand (UI/client state) and TanStack Query (server cache), avoiding the common anti-pattern of duplicating server data in a global store.
- Modern, current major versions across the core stack (React 18, Next.js 14, TypeScript 5.4) with no unsupported runtimes.

**Top Risks:**
- Overall test coverage sits at 58% (lines), with `src/components/ui` (39%) and `src/app/(dashboard)/budgets` (54%) well below the rest of the codebase — regressions in shared UI primitives are likely to ship undetected.
- CI (`.github/workflows/ci.yml`) runs lint, typecheck, and build on every PR but never executes the Vitest suite, so a red test run does not block a merge.
- The AI coding harness is only partially set up (`CLAUDE.md` present but thin, no `.claude/hooks`, no pre-push gate, no custom subagents), so AI-assisted changes have no automated backstop before they reach a PR.

**Priority Recommendations:**
1. Add a `vitest run --coverage` step to `.github/workflows/ci.yml` and make it a required check, so CI actually gates on the existing test suite instead of only lint/typecheck/build.
2. Raise coverage in `src/components/ui` and `src/app/(dashboard)/budgets` first — they are both below 55% and sit on the app's most reused and most financially sensitive code paths, respectively.
3. Flesh out `CLAUDE.md` with project-specific conventions and add at least a pre-commit hook running lint + typecheck, to close the largest gap in the AI Harness & Adoption score.

---

## 2. At-a-Glance Scorecard

| Section | Score | Label |
|---------|-------|-------|
| Tech Stack | 82/100 | Fair |
| Architecture | 78/100 | Fair |
| State Management | 74/100 | Fair |
| Testing | 61/100 | Weak |
| Code Quality (Linter & Warnings) | 69/100 | Weak |
| Performance | 88/100 | Strong |
| Documentation & Operations | 55/100 | Weak |
| CI/CD (Configs Found in Repo) | 64/100 | Weak |
| AI Harness & Adoption | 40/100 | Weak |
| **Overall** | **71/100** | **Fair** |

> **Test Coverage:** 58% (lines) — full breakdown in the Testing section.
> Fallback when no coverage tool is detected: `Not measured (no coverage tool detected/configured)`

> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)

Ledgerly's Fair 71/100 overall reflects a genuinely fast, reasonably modern frontend held back by a thin test-and-CI safety net and an AI harness that hasn't moved past its default scaffold — the codebase is more mature than its process around it.

---

## 3. Tech Stack

**Description:** Analysis of technology versions, dependencies, and tooling setup.

**Score:** 82/100 (Fair)

### Key Findings
- Core stack is current: React 18.3.1, Next.js 14.2.3 (App Router), TypeScript 5.4.5 — no framework majors are more than one release behind.
- Zustand 4.5 and @tanstack/react-query 5.28 are both on current majors and match the versions declared in `package.json`.
- Two dependencies are meaningfully stale: `date-fns` is pinned to 2.30 (current major is 3.x) and `recharts` is pinned to 2.4 while 2.12 is current, both used in `src/components/charts/SpendingTrendChart.tsx`.
- `package.json` has no `engines` field, so the Node.js version the app is built and deployed with is not pinned anywhere in the repo.

### Evidence
- `package.json`
- `package-lock.json`
- `src/components/charts/SpendingTrendChart.tsx`
- `next.config.js`

### Risks
- An unpinned Node engine means CI and local dev can silently drift onto a different Node major, producing "works on my machine" failures.
- `recharts` 2.4 predates several accessibility and tree-shaking fixes shipped in 2.12+, so bundle size and screen-reader support for charts are worse than they need to be.

### Recommendations
- Add `"engines": { "node": ">=20.11 <21" }` to `package.json` and mirror it in `.nvmrc`.
- Bump `date-fns` to 3.x and `recharts` to 2.12+ in a dedicated dependency-upgrade PR, since both touch the same chart component and should be validated together.

### Counts & Metrics
- React version: 18.3.1
- Next.js version: 14.2.3
- TypeScript version: 5.4.5
- Direct dependencies: 34
- Direct devDependencies: 21
- Dependencies more than one major behind latest: 2

---

## 4. Architecture

**Description:** Analysis of the App Router route structure, feature boundaries, and module organization.

**Score:** 78/100 (Fair)

### Key Findings
- The app uses Next.js route groups to separate concerns cleanly: `src/app/(auth)/` for login/signup and `src/app/(dashboard)/` for the authenticated shell (transactions, budgets, reports).
- Feature folders under `src/features/transactions/`, `src/features/budgets/`, and `src/features/accounts/` each own their components, hooks, and types, which keeps most domain logic out of `src/app`.
- `src/lib/utils/format.ts` has grown into a 640-line catch-all covering currency formatting, date formatting, CSV export, and validation helpers, imported from all three feature folders — a single unrelated change here risks breaking unrelated features.
- `src/features/transactions/` imports directly from `src/features/budgets/hooks/useBudgetTotals.ts` to compute "remaining budget" on the transaction list, creating a cross-feature dependency that isn't mirrored in the other direction.

### Evidence
- `src/app/(auth)/login/page.tsx`
- `src/app/(dashboard)/transactions/page.tsx`
- `src/app/(dashboard)/budgets/page.tsx`
- `src/features/transactions/`
- `src/features/budgets/hooks/useBudgetTotals.ts`
- `src/lib/utils/format.ts`

### Risks
- `format.ts` acting as an unofficial shared-kernel module makes it a high-blast-radius file with no dedicated tests of its own beyond what feature tests happen to exercise.
- The one-directional cross-feature import between transactions and budgets is the seed of a circular dependency if budgets ever needs transaction data back.

### Recommendations
- Split `src/lib/utils/format.ts` into `format/currency.ts`, `format/date.ts`, and `format/csv.ts`, each with its own unit tests.
- Extract the "remaining budget" calculation into a shared `src/features/shared/budget-math.ts` (or a small `@ledgerly/domain` internal package) that both features import, instead of one feature reaching into another's internals.

### Counts & Metrics
- Feature folders under `src/features/`: 3
- Route groups under `src/app/`: 2
- Largest shared utility file: `src/lib/utils/format.ts` (640 lines)
- Cross-feature imports detected: 1

---

## 5. State Management

**Description:** Analysis of client state (Zustand) and server-cache state (TanStack Query) usage and boundaries.

**Score:** 74/100 (Fair)

### Key Findings
- Server data (transactions, budgets, accounts) is fetched exclusively through TanStack Query hooks in `src/lib/api/`, with no server data duplicated into Zustand — the intended split is respected almost everywhere.
- Zustand slices are feature-scoped: `src/store/useTransactionsFilterStore.ts` and `src/store/useBudgetsUiStore.ts` each own a narrow piece of UI state (active filters, selected month, open/closed panels).
- `src/store/useAppStore.ts` is a 310-line exception that mixes genuine UI state (sidebar collapsed, active theme) with one piece of server-derived state (`currentAccountBalance`), which is set manually from a `useEffect` after a TanStack Query call resolves instead of being read from the query cache directly.
- `src/lib/api/queryClient.ts` sets a global `staleTime` of 0, so every component mount that reads a query hook triggers a network refetch even for rarely-changing data like account metadata.

### Evidence
- `src/lib/api/useTransactionsQuery.ts`
- `src/lib/api/useBudgetsQuery.ts`
- `src/lib/api/queryClient.ts`
- `src/store/useTransactionsFilterStore.ts`
- `src/store/useBudgetsUiStore.ts`
- `src/store/useAppStore.ts`

### Risks
- Mirroring `currentAccountBalance` into Zustand via a `useEffect` creates a second source of truth that can go stale relative to the TanStack Query cache after a mutation invalidates it.
- A global `staleTime` of 0 causes redundant network calls on every navigation between dashboard tabs, which is very likely a meaningful, currently-unmeasured contributor to the app's real-world load pattern (separate from the synthetic Performance figures in Section 8).

### Recommendations
- Remove `currentAccountBalance` from `useAppStore.ts` and read it directly from `useAccountQuery()` wherever it's needed, letting TanStack Query stay the single source of truth for server data.
- Set a per-query `staleTime` (e.g. 60s for account metadata, 10s for transactions) instead of relying on the global default of 0.

### Counts & Metrics
- Zustand stores: 3 (`useTransactionsFilterStore`, `useBudgetsUiStore`, `useAppStore`)
- TanStack Query hooks: 7
- Global `staleTime` configured: 0ms

---

## 6. Testing

**Description:** Analysis of the Vitest + Testing Library test suite, its structure, and its coverage.

**Score:** 61/100 (Weak)

**Code Coverage:** 58% (lines)
> Multi-dimension stacks (JS/TS): `58% lines / 51% branches / 63% functions`

**Coverage Breakdown:**
- `src/app/(dashboard)/transactions`: 66% (lines, 58% branches, 70% functions)
- `src/app/(dashboard)/budgets`: 54% (lines, 45% branches, 60% functions)
- `src/lib/api` (TanStack Query hooks): 71% (lines, 64% branches, 75% functions)
- `src/store` (Zustand slices): 60% (lines, 52% branches, 66% functions)
- `src/components/ui`: 39% (lines, 30% branches, 45% functions)
- `src/lib/utils`: 82% (lines, 77% branches, 85% functions)

### Key Findings
- `src/components/ui` (Button, Input, Modal, Table primitives reused across every feature) is the single worst-covered area at 39% lines, despite being the most widely reused code in the app.
- TanStack Query hooks are the best-tested layer at 71%, largely because `src/lib/api/useTransactionsQuery.test.ts` and `src/lib/api/useBudgetsQuery.test.ts` mock MSW handlers thoroughly.
- No end-to-end or integration tests exist above the component level — every test in `src/**/*.test.tsx` renders a single component or hook in isolation with Testing Library; there is no test that exercises the transactions page top-to-bottom.
- The budgets feature (54% lines) has zero tests for the "remaining budget" cross-feature calculation called out in Section 4.

### Evidence
- `vitest.config.ts`
- `src/test/setup.ts`
- `src/lib/api/useTransactionsQuery.test.ts`
- `src/features/budgets/hooks/useBudgetTotals.ts` (untested)
- `src/components/ui/` (10 components, 3 with tests)

### Risks
- The complete absence of integration-level tests means a change that's correct in isolation (e.g. a Button prop rename) can still break a real user flow without any test catching it.
- The untested `useBudgetTotals` calculation sits directly behind a user-facing number ("remaining budget") shown on the dashboard — a silent bug here is a trust-damaging, financially-visible bug.

### Recommendations
- Add Testing Library coverage for the remaining 7 of 10 components in `src/components/ui`, prioritizing `Table` and `Modal` since they're the most composed-into other components.
- Add at least one Testing Library test that renders the full transactions page with a mocked TanStack Query response and asserts the budget-remaining figure, closing the gap identified in Architecture (Section 4) and here together.

### Counts & Metrics
- Test count: 118
- Test framework: Vitest 1.6 + @testing-library/react 15
- Component test files: 34 of 61 components

---

## 7. Code Quality (Linter & Warnings)

**Description:** Analysis of linting configuration, warning volume, and formatting consistency.

**Score:** 69/100 (Weak)

### Key Findings
- ESLint is configured (`eslint-config-next` + `@typescript-eslint`) and runs in CI, but `eslint.config.js` sets 14 rules to `"warn"` instead of `"error"`, including `@typescript-eslint/no-explicit-any` and `react-hooks/exhaustive-deps`.
- A repo-wide lint run reports 47 warnings and 0 errors — the warning count has apparently been allowed to accumulate rather than block merges, since CI only fails on errors.
- `tsconfig.json` does not enable `strict: true`; it enables `strictNullChecks` alone, so several other strict-mode checks (e.g. `noImplicitAny`) are effectively off.
- Prettier is installed and configured (`.prettierrc`) but is not run in CI and has no pre-commit hook, so formatting consistency depends entirely on each contributor's editor setup.

### Evidence
- `eslint.config.js`
- `tsconfig.json`
- `.prettierrc`
- `.github/workflows/ci.yml`

### Risks
- 14 rules parked at `"warn"` (including `exhaustive-deps`) means real dependency-array bugs surface as noise in `next lint` output rather than blocking anything.
- Without `strict: true`, TypeScript is not catching the class of bugs the team is likely assuming it catches, which is a false sense of safety.

### Recommendations
- Promote `@typescript-eslint/no-explicit-any` and `react-hooks/exhaustive-deps` from `"warn"` to `"error"`, then work through the current 47 warnings in a follow-up cleanup PR before flipping the switch.
- Enable `strict: true` in `tsconfig.json` incrementally, starting with `noImplicitAny`, and add `prettier --check` as a required CI step.

### Counts & Metrics
- ESLint errors: 0
- ESLint warnings: 47
- Rules set to `"warn"`: 14
- TypeScript strict mode: partial (`strictNullChecks` only)

---

## 8. Performance

**Description:** Analysis of Core Web Vitals, code-splitting, memoization, and rendering-cost patterns.

**Score:** 88/100 (Strong)

### Key Findings
- Fabricated Lighthouse CI numbers for `/transactions` (the heaviest route) are strong across the board: LCP 1.9s, CLS 0.03, INP 145ms, TBT 180ms.
- `src/app/(dashboard)/reports/page.tsx` lazy-loads `SpendingTrendChart` via `next/dynamic` with `ssr: false`, keeping the charting library out of the initial bundle for every route that doesn't render a chart.
- The transaction list in `src/features/transactions/components/TransactionList.tsx` uses `@tanstack/react-virtual` to virtualize rows, so a 5,000-row account renders roughly 20 DOM rows at a time.
- Grep across `src/components/` finds 3 remaining `.map((item, index) => <Row key={index} />)` occurrences using array index as a React key, all in lower-traffic settings screens rather than the hot paths above.

### Evidence
- Fabricated Lighthouse CI report, `reports/.artifacts/react-health-audit/lighthouse-transactions.json`
- `src/app/(dashboard)/reports/page.tsx`
- `src/features/transactions/components/TransactionList.tsx`
- `src/features/settings/components/NotificationRow.tsx` (index-as-key)

### Risks
- The 3 remaining index-as-key usages are currently harmless because those lists are rarely reordered, but they're a latent bug waiting for the first reorderable settings list.
- Performance numbers above are Lighthouse-lab figures for one route; there is no field data (no Web Vitals reporting wired to a real-user-monitoring endpoint) confirming these hold up under real network and device conditions.

### Recommendations
- Replace the 3 index-based `key` props in `src/features/settings/components/NotificationRow.tsx` with a stable field (e.g. `notification.id`).
- Wire `useReportWebVitals` (Next.js) to a real analytics endpoint so the strong lab numbers above can be cross-checked against real-user field data.

### Counts & Metrics
- LCP (transactions route, lab): 1.9s
- CLS (transactions route, lab): 0.03
- INP (transactions route, lab): 145ms
- `next/dynamic` lazy-loaded components: 4
- Array-index-as-key occurrences: 3

---

## 9. Documentation & Operations

**Description:** Analysis of README quality, contributor documentation, and operational runbooks.

**Score:** 55/100 (Weak)

### Key Findings
- `README.md` covers local setup (install, env vars, `npm run dev`) in reasonable detail but has no section on architecture, feature-folder conventions, or how state management is split between Zustand and TanStack Query.
- There is no `CONTRIBUTING.md` and no documented PR checklist; contribution conventions live only in accumulated team knowledge.
- No architecture decision records exist anywhere in the repo (no `docs/adr/` or equivalent), including for the Zustand/TanStack Query split itself, which is exactly the kind of decision an ADR is for.
- No operational runbook exists for on-call scenarios (e.g. "transactions API is returning 500s") — the only relevant doc is a two-line "Support" section in `README.md` pointing at a Slack channel.

### Evidence
- `README.md`
- Repository root (no `CONTRIBUTING.md`, no `docs/adr/`)

### Risks
- New contributors have no written guide to the feature-folder + Zustand/TanStack Query conventions identified in Sections 4–5, so those conventions are likely to erode as the team grows.
- Absence of a runbook means incident response for this app currently depends on whoever is online in Slack knowing the system from memory.

### Recommendations
- Add an "Architecture" section to `README.md` documenting the route-group layout, feature-folder convention, and the Zustand-vs-TanStack-Query rule from Section 5.
- Start a `docs/adr/` with at least one retroactive ADR for the state-management split, and add a one-page incident runbook for the transactions and budgets APIs.

### Counts & Metrics
- `README.md` length: 84 lines
- ADRs found: 0
- Runbooks found: 0

---

## 10. CI/CD (Configs Found in Repo)

**Description:** Analysis of continuous-integration configuration and what it actually gates on.

**Score:** 64/100 (Weak)

### Key Findings
- `.github/workflows/ci.yml` runs three jobs on every pull request: `eslint . `, `tsc --noEmit`, and `next build` — all three are required checks.
- The same workflow does **not** run `vitest run`, so the 118 tests described in Section 6 execute locally (if at all) but never gate a merge in CI.
- There is no caching configured for `node_modules` or the Next.js build cache in the workflow, so every run reinstalls dependencies and rebuilds from scratch (~6 fabricated minutes per run).
- No scheduled or nightly workflow exists (e.g. a weekly dependency-audit run); the only trigger is `pull_request`.

### Evidence
- `.github/workflows/ci.yml`

### Risks
- A PR with a fully red test suite can merge cleanly as long as lint, typecheck, and build pass, which directly undermines the value of the 118 tests that do exist.
- Full, uncached reinstalls on every run make CI slower than it needs to be, which increases the temptation to skip or ignore it under deadline pressure.

### Recommendations
- Add a `vitest run --coverage` step to `.github/workflows/ci.yml` and mark it required, per the Executive Summary's top recommendation.
- Add `actions/cache` (or `actions/setup-node`'s built-in cache) keyed on the lockfile hash to cut redundant install time.

### Counts & Metrics
- CI jobs defined: 3 (lint, typecheck, build)
- CI jobs that run the test suite: 0
- Workflow triggers: `pull_request` only

---

## 11. AI Harness & Adoption

**Description:** Analysis of how much AI-agent scaffolding (CLAUDE.md, rules, hooks, permissions, agents, commands) this repository has in place.

**Score:** 40/100 (Weak)

**Maturity:** harness básico

### Harness Coverage
| Dimension | Status | Points |
|---|---|---|
| CLAUDE.md | Present, thin | 9/13 |
| Rules | Partial | 4/9 |
| Permissions | Partial | 8/13 |
| Hooks | Minimal | 3/14 |
| Pre-push git hook | Missing | 0/11 |
| Agents | Missing | 0/11 |
| Commands / Skills | Partial | 5/9 |
| Advanced orchestration | Missing | 1/5 |
| Lifecycle | Partial | 2/3 |
| Harness versioning | Partial | 8/12 |
| **Total** | | **40/100** |

### Key Findings
- `CLAUDE.md` exists at the repo root and documents the dev commands (`npm run dev`, `npm test`) and the App Router layout, but has no section on the Zustand/TanStack Query convention from Section 5, so an AI agent reading it would repeat the exact mixing mistake found in `useAppStore.ts`.
- `.claude/settings.json` allow-lists `npm run *` and `git status`/`git diff`, but does not allow-list `vitest` directly, so an agent frequently has to ask for permission mid-task to run tests.
- `.claude/hooks/` contains a single `PostToolUse` hook that runs Prettier on saved files; there is no `PreToolUse` hook, no pre-push hook, and no CI-mirroring hook.
- No custom subagents or slash commands exist beyond two generic ones (`/lint-fix`, `/test-file`) copied from a template and never adapted to Ledgerly's feature-folder layout.

### Evidence
- `CLAUDE.md`
- `.claude/settings.json`
- `.claude/hooks/post-tool-use-format.sh`
- `.claude/commands/lint-fix.md`
- `.claude/commands/test-file.md`

### Risks
- Because `CLAUDE.md` omits the state-management convention, every future AI-assisted change to server state has a real chance of reintroducing the `useAppStore.ts` anti-pattern from Section 5 instead of fixing it.
- With no pre-push hook and no CI test gate (Section 10), an AI agent's changes can reach `main` without either a local or a remote automated check ever running the test suite.

### Actions to Raise the Score
1. **[+11]** Add a pre-push git hook that runs `vitest run` and `tsc --noEmit` before allowing a push. → dimension Pre-push git hook, 0/11 → 11/11.
2. **[+11]** Add a project-specific subagent (e.g. a "ledgerly-reviewer" agent scoped to `src/features/`) that enforces the Zustand/TanStack Query boundary from Section 5. → dimension Agents, 0/11 → 11/11.
3. **[+11]** Expand `.claude/hooks/` with a `PreToolUse` hook that blocks edits to `src/lib/api/queryClient.ts` without an accompanying test file change. → dimension Hooks, 3/14 → 14/14 (largest single jump, but the most involved to build correctly).
4. **[+5]** Allow-list `vitest`, `next lint`, and `next build` explicitly in `.claude/settings.json` so agents stop needing mid-task permission prompts for routine commands. → dimension Permissions, 8/13 → 13/13.
5. **[+5]** Rewrite `/lint-fix` and `/test-file` to reference Ledgerly's actual feature-folder paths, and add one more command for "add a Vitest test for a component." → dimension Commands / Skills, 5/9 → 9/9 (partial; remaining points need broader adoption evidence).
6. **[+4]** Expand `CLAUDE.md` with the state-management convention from Section 5 and the feature-folder convention from Section 4. → dimension CLAUDE.md, 9/13 → 13/13.

### Counts & Metrics
- `.claude/commands/` files: 2
- `.claude/hooks/` files: 1
- Custom subagents: 0
- CLAUDE.md length: 38 lines

---

## 12. Additional Metrics

- **Framework:** Next.js 14.2.3 (App Router)
- **State management detected:** Zustand (client/UI state) + TanStack Query (server cache)
- **TypeScript:** Enabled (5.4.5, partial strict mode — see Section 7)
- **Test framework:** Vitest 1.6 + Testing Library
- **Build tool:** Next.js (Webpack build, Turbopack for local dev)
- **Package manager:** npm

---

## 13. Risks & Opportunities

- Zero CI gating on the 118-test Vitest suite (Sections 6, 10) is the single highest-leverage fix available: it's a config change, not new test-writing effort, and it protects every test the team already has.
- `src/components/ui` at 39% coverage (Section 6) is both the most reused code in the app and the worst-tested — an opportunity to raise the overall coverage figure meaningfully with a small, targeted effort.
- The unofficial shared-kernel role of `src/lib/utils/format.ts` (Section 4) and the manual state mirroring in `useAppStore.ts` (Section 5) are two separate instances of the same underlying pattern — logic escaping its intended boundary — worth fixing together under one "boundary cleanup" initiative.
- The AI harness gap (Section 11) compounds every other risk here: without a documented convention and a pre-push test gate, AI-assisted contributions are more likely to repeat exactly the anti-patterns this audit found than to fix them.
- Strong Performance (Section 8) and a reasonably current Tech Stack (Section 3) mean the team can spend its next quarter on process (tests, CI, harness) rather than a stack migration.

---

## 14. Recommendations

1. **High:** Add a `vitest run --coverage` step to `.github/workflows/ci.yml` as a required check (Sections 6, 10).
2. **High:** Add a pre-push git hook running `vitest run` and `tsc --noEmit` (Section 11).
3. **High:** Bring `src/components/ui` test coverage from 39% toward the codebase average by testing `Table` and `Modal` first (Section 6).
4. **Medium:** Remove `currentAccountBalance` from `useAppStore.ts` and read it directly from `useAccountQuery()` (Section 5).
5. **Medium:** Split `src/lib/utils/format.ts` into `format/currency.ts`, `format/date.ts`, and `format/csv.ts` with dedicated tests (Section 4).
6. **Medium:** Promote `@typescript-eslint/no-explicit-any` and `react-hooks/exhaustive-deps` from `"warn"` to `"error"` after clearing the current 47 warnings (Section 7).
7. **Medium:** Expand `CLAUDE.md` with the state-management and feature-folder conventions from Sections 4–5 (Section 11).
8. **Low:** Bump `date-fns` to 3.x and `recharts` to 2.12+ in a dedicated dependency PR (Section 3).
9. **Low:** Add `actions/cache` to `.github/workflows/ci.yml` to cut redundant install/build time (Section 10).
10. **Low:** Replace the 3 remaining array-index `key` props in `src/features/settings/components/NotificationRow.tsx` (Section 8).

---

## 15. Appendix: Evidence Index

**Tech Stack:**
- `package.json`
- `package-lock.json`
- `next.config.js`

**Architecture:**
- `src/app/(dashboard)/transactions/page.tsx`
- `src/features/transactions/`
- `src/features/budgets/hooks/useBudgetTotals.ts`
- `src/lib/utils/format.ts`

**State Management:**
- `src/lib/api/useTransactionsQuery.ts`
- `src/lib/api/queryClient.ts`
- `src/store/useAppStore.ts`

**Testing:**
- `vitest.config.ts`
- `src/test/setup.ts`
- `src/lib/api/useTransactionsQuery.test.ts`

**Code Quality:**
- `eslint.config.js`
- `tsconfig.json`
- `.prettierrc`

**Performance:**
- `reports/.artifacts/react-health-audit/lighthouse-transactions.json` (fabricated)
- `src/features/transactions/components/TransactionList.tsx`
- `src/app/(dashboard)/reports/page.tsx`

**Documentation:**
- `README.md`

**CI/CD:**
- `.github/workflows/ci.yml`

**AI Harness & Adoption:**
- `CLAUDE.md`
- `.claude/settings.json`
- `.claude/hooks/post-tool-use-format.sh`
- `.claude/commands/lint-fix.md`

---

## Appendix: Scoring Methodology

**Weighted formula** (weights sum to 1.00 — the authoritative source is this skill's
`references/report-generator.md`; this table is a read-only summary of what was applied):

| Section | Weight |
|---------|--------|
| Tech Stack | 0.18 |
| Architecture | 0.18 |
| State Management | 0.135 |
| Testing | 0.135 |
| Code Quality (Linter & Warnings) | 0.135 |
| Performance | 0.075 |
| Documentation & Operations | 0.03 |
| CI/CD (Configs Found in Repo) | 0.03 |
| AI Harness & Adoption | 0.10 |
| **Total** | **1.00** |

**Rounding rule:** Standard mathematical rounding (0.5 rounds up). No subjective adjustment.

**Scoring bands:** Strong (85–100) · Fair (70–84) · Weak (0–69)

---

## Report Metadata

| Field | Value |
|-------|-------|
| Generated by | Somnio CLI v0.0.0 (fictional example — no real run) |
| Skill | react-health-audit |
| Date | 2026-09-18 |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
