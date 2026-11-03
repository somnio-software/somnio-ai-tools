# Next.js Best Practices Audit Report

**Project:** [PROJECT_NAME]
**Date:** [AUDIT_DATE]
**Auditor:** AI-Assisted Analysis

---

## 1. Executive Summary

**Overall Score:** [XX]/100 ([Strong/Fair/Weak])

**Description:**
[One paragraph summary of the codebase quality and key findings]

**Project Context:**
- Installed Next.js version: [X.Y.Z / Unknown — from lockfile]
- Router(s): [App Router / Pages Router / Both]
- Caching model: [Cache Components / Previous model / Pages Router data fetching / Mixed]
- Docs source: [node_modules/next/dist/docs / .next-docs / nextjs.org/docs (versioned path)]

**Top Strengths:**
- [Strength 1]
- [Strength 2]
- [Strength 3]

**Critical Issues:**
- [Critical Issue 1]
- [Critical Issue 2]
- [Critical Issue 3]

**Immediate Action Items:**
1. [Most urgent action]
2. [Second priority action]
3. [Third priority action]

---

## 2. Score Breakdown

| Section | Score | Label |
|---------|-------|-------|
| App Router Architecture | [XX]/100 | [Label] |
| Server & Client Components | [XX]/100 | [Label] |
| Data Fetching & Caching | [XX]/100 | [Label] |
| Server Actions & Route Handlers | [XX]/100 | [Label] |
| Rendering Performance | [XX]/100 | [Label] |
| Testing Quality | [XX]/100 | [Label] |
| TypeScript Standards | [XX]/100 | [Label] |
| **Weighted Overall** | **[XX]/100** | **[Label]** |

> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)

---

## 3. App Router Architecture

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of routing structure and file-convention findings]

**Routing Model:**
- Router roots: [`app/` / `src/app/` / `pages/` — list what exists]
- Mixed routers: [No / Yes — migration state described]
- Route segments: [XX] (dynamic: [XX], route groups: [XX], parallel/intercepting: [XX])

**Boundaries:**
- `loading` coverage: [XX]/[XX] data segments
- `error` coverage: [XX]/[XX] data segments; `global-error`: [Present/Missing]
- `not-found` coverage: [XX]/[XX] dynamic segments

**Metadata:**
- Metadata API: [`metadata` / `generateMetadata` / file-based / Missing]
- Legacy `next/head` or raw `<head>` in App Router: [None/Found — count]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[app/path/layout.tsx:XX]` — [Structure Issue]: [Description]
- `[app/path/page.tsx:XX]` — [Boundary Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 4. Server & Client Components

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of Server/Client boundary findings]

**Client Surface:**
- `'use client'` files: [XX] of [XX] component files
- `'use client'` on `layout`/`page` files: [XX]
- Unnecessary `'use client'` (no client features): [XX]

**Boundary Safety:**
- `server-only` on server modules: [XX]/[XX] modules with secrets or DB access
- Server-only code reachable from client modules: [None/Found — count]
- Non-serializable or over-broad props to Client Components: [None/Found — count]

**Hydration:**
- Hydration-risk patterns: [XX] occurrences
- `async` Client Components: [None/Found]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[components/Widget.tsx:XX]` — [Boundary Issue]: [Description]
- `[lib/db.ts:XX]` — [Server-Only Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 5. Data Fetching & Caching

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of data access, streaming and caching findings for the installed version]

**Caching Model:**
- Model in use: [Cache Components / Previous model / Pages Router data fetching / Mixed]
- Caching APIs in use: [list with counts]
- APIs not documented for the installed version: [None/Found — list]

**Fetching Patterns:**
- Server-side data reads: [XX] modules
- Client-side fetching of render-time data: [XX] occurrences
- Sequential waterfalls: [XX] occurrences

**Streaming:**
- `<Suspense>` boundaries around request-time data: [XX]
- Whole-page blocking boundaries: [XX]

**Revalidation:**
- Tag-based: [XX] · Path-based: [XX] · Time-based: [XX]
- Shared-cache entries holding user-specific data: [None/Found]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[app/path/page.tsx:XX]` — [Waterfall Issue]: [Description]
- `[lib/data.ts:XX]` — [Cache Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 6. Server Actions & Route Handlers

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of mutation and HTTP handler findings]

**Inventory:**
- Server Actions: [XX] in [XX] files
- Route Handlers: [XX] (methods: [list])

**Input & Authorization:**
- Schema-validated input: [XX]/[XX] entry points
- In-action/in-handler authorization: [XX]/[XX] non-public entry points

**Mutation Hygiene:**
- Revalidation after mutation: [XX]/[XX] mutating actions
- Structured error returns: [Yes/Partial/No]
- Progressive enhancement (`<form action>`): [Yes/Partial/No]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[app/actions/x.ts:XX]` — [Authz Issue]: [Description]
- `[app/api/x/route.ts:XX]` — [Validation Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 7. Rendering Performance

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of rendering and optimization findings]

**Asset Optimization:**
- `next/image`: [XX] · raw `<img>`: [XX]
- Fonts via `next/font`: [Yes/Partial/No]
- `next/script`: [XX] · raw `<script>`: [XX]

**Code Splitting:**
- Dynamic imports (`next/dynamic` / `React.lazy`): [XX]
- Heavy client libraries loaded eagerly: [None/Found — list]

**Rendering Strategy:**
- Routes forced dynamic without request-time data: [XX]
- `generateStaticParams` on dynamic routes with known params: [XX]/[XX]
- Static shell / Partial Prerendering: [Used / Not used / Not documented for installed version]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[components/Hero.tsx:XX]` — [Image Issue]: [Description]
- `[app/layout.tsx:XX]` — [Script Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 8. Testing Quality

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of testing findings]

**Test Tooling:**
- Unit/component runner: [Vitest/Jest/None]
- React Testing Library: [Yes/No]
- E2E runner: [Playwright/Cypress/None]

**Next.js Surface Coverage:**
- Async Server Components covered by E2E: [Yes/Partial/No]
- Server Action logic unit-tested: [Yes/Partial/No]
- Route Handlers tested: [Yes/Partial/No]
- Critical flows with E2E: [XX]/[XX]

**Test Quality:**
- Semantic queries (`getByRole` etc.): [Good/Needs Improvement]
- `userEvent` vs `fireEvent`: [userEvent/fireEvent/Mixed]
- Tests without assertions: [XX]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[path/to/file.test.tsx:XX]` — [Test Issue]: [Description]
- `[e2e/flow.spec.ts:XX]` — [E2E Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 9. TypeScript Standards

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of TypeScript and tooling findings]

**TypeScript Configuration:**
- Strict mode: [Enabled/Disabled]
- `ignoreBuildErrors`: [Not set / Set — CI type check: Yes/No]
- Typed routes: [Enabled / Disabled / Not documented for installed version]

**Linting & Tooling:**
- `eslint-config-next`: [Core Web Vitals / Base / Missing]
- Package manager: [pnpm/npm/yarn/bun] · Lockfile committed: [Yes/No]

**Type Safety:**
- Explicit `any` / `as any`: [XX]
- Untyped page/layout/handler props: [XX]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[next.config.ts:XX]` — [Config Issue]: [Description]
- `[app/path/page.tsx:XX]` — [Type Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 10. Prioritized Recommendations

### 🔴 Critical (Must Fix Immediately)
1. [Critical recommendation with file reference]
2. [Critical recommendation with file reference]

### 🟠 High Priority
1. [High priority recommendation]
2. [High priority recommendation]
3. [High priority recommendation]

### 🟡 Medium Priority
1. [Medium priority recommendation]
2. [Medium priority recommendation]
3. [Medium priority recommendation]

### 🟢 Low Priority (Nice to Have)
1. [Low priority recommendation]
2. [Low priority recommendation]

---

## 11. Evidence Index

**Route Files Analyzed:**
- `[app/path/page.tsx]`
- `[app/path/layout.tsx]`

**Client Component Files Analyzed:**
- `[components/Widget.tsx]`

**Server Action / Route Handler Files Analyzed:**
- `[app/actions/x.ts]`
- `[app/api/x/route.ts]`

**Data Access Files Analyzed:**
- `[lib/data.ts]`

**Test Files Analyzed:**
- `[path/to/file.test.tsx]`
- `[e2e/flow.spec.ts]`

**Configuration Files Analyzed:**
- `[next.config.ts]`
- `[tsconfig.json]`

---

## Appendix: Scoring Methodology

**Weighted formula** (weights sum to 100% — the authoritative source is this skill's
`references/best-practices-generator.md`; this table is a read-only summary of what was applied):

| Section | Weight |
|---------|--------|
| App Router Architecture | 15% |
| Server & Client Components | 20% |
| Data Fetching & Caching | 20% |
| Server Actions & Route Handlers | 15% |
| Rendering Performance | 10% |
| Testing Quality | 10% |
| TypeScript Standards | 10% |
| **Total** | **100%** |

**Not applicable sections:** [None / list each `N/A` section — its weight is excluded and the remaining weights are renormalized proportionally]

**Rounding rule:** Standard mathematical rounding (0.5 rounds up). No subjective adjustment.

**Scoring bands:** Strong (85–100) · Fair (70–84) · Weak (0–69)

---

## Report Metadata

| Field | Value |
|-------|-------|
| Generated by | Somnio CLI v3.3.3 |
| Skill | nextjs-best-practices |
| Date | [YYYY-MM-DD] |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
| Standards Source | https://nextjs.org/docs (version-matched to the installed Next.js) |
