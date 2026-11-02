# Next.js Health Audit Report Generator

> Generate the final Next.js Project Health Audit report by integrating all analysis results and calculating scores using the standardized format structure from assets/report-template.md.

---

Goal: Generate the final Next.js Project Health Audit report by
integrating all analysis results and calculating scores using the
standardized format structure from
assets/report-template.md.

Apply the "Next.js Project Health Audit" rule to generate the full
report with:
- 9 section scores (0-100 integer): Tech Stack, Architecture, State
  Management, Testing, Code Quality, Performance, Documentation
  & Operations, CI/CD, AI Harness & Adoption
- Weighted overall score using: Tech Stack 0.18, Architecture 0.18,
  State Management 0.135, Testing 0.135, Code Quality 0.135,
  Performance 0.075, Documentation & Operations 0.03, CI/CD 0.03,
  AI Harness & Adoption 0.10
- ROUNDING RULE: Use standard mathematical rounding (0.5 rounds up).
  Do NOT apply subjective adjustments.
- Important exclusions:
  * Do NOT recommend CODEOWNERS or SECURITY.md files - these are
    governance decisions, not technical requirements
  * Do NOT recommend deployment-specific workflows - these are
    deployment decisions, not technical requirements
- Labels: 85-100=Strong, 70-84=Fair, 0-69=Weak
- Markdown-formatted report ready for reading and sharing
- All sections with: Description, Score, Key Findings, Evidence,
  Risks, Recommendations, Counts & Metrics

NOTE: For security analysis, run the standalone Next.js Security Audit
(`/somnio:nextjs-security-audit`). This report's Tech Stack section
carries only the first-pass dependency summary from
`references/dependency-security-analysis.md`.

MANDATORY REPORT STRUCTURE (15 sections in exact order):
1. Executive Summary
2. At-a-Glance Scorecard
3. Tech Stack
4. Architecture
5. State Management
6. Testing
7. Code Quality (Linter & Warnings)
8. Performance
9. Documentation & Operations
10. CI/CD (Configs Found in Repo)
11. AI Harness & Adoption
12. Additional Metrics
13. Risks & Opportunities
14. Recommendations
15. Appendix: Evidence Index

Two further UNNUMBERED blocks follow section 15, in this order:
`## Appendix: Scoring Methodology` (weight table — see the special
format below; this file is the authoritative source for the weight
literals) and `## Report Metadata` (see SKILL.md).

There is no "Quality Index" section. It was removed; its former
content was a byte-for-byte duplicate of the At-a-Glance Scorecard plus
a one-sentence interpretation, which is now the interpretation sentence
under the scorecard (see the Section 2 special format below). Never
emit a "Quality Index" heading.

Integrate results from all previous analysis steps:
- Node.js Version Alignment and Version Validator results (installed
  versions, build result, TypeScript errors)
- Repository Inventory findings (router model, routes, special files,
  output mode, bundler, deploy hints)
- Configuration Analysis results (next.config red flags, ESLint,
  TypeScript, env conventions)
- CI/CD Analysis findings
- Testing Analysis results
- Code Quality Analysis results (including the Next.js usage signals)
- State Management Analysis results (data fetching, caching, Server
  Actions, client state)
- Documentation Analysis results
- AI Harness & Adoption Analysis results
- Dependency & Security Analysis results
- Coverage results from test-coverage step

SECTION-TO-STEP MAPPING (which step feeds which scored section):
- Tech Stack (Section 3): version-alignment, version-validator,
  config-analysis, dependency-security-analysis
- Architecture (Section 4): repository-inventory
- State Management (Section 5): state-management-analysis (Next.js data
  & state: server/client boundary, RSC fetching, caching, Server
  Actions, client state)
- Testing (Section 6): testing-analysis, test-coverage
- Code Quality (Section 7): code-quality, config-analysis red flags
- Performance (Section 8): derived — see below
- Documentation & Operations (Section 9): documentation-analysis
- CI/CD (Section 10): cicd-analysis
- AI Harness & Adoption (Section 11): harness-analysis

TECH STACK SECTION (Section 3) — dependency security input:
The Tech Stack score MUST consume
`references/dependency-security-analysis.md`'s findings; there is no
separate dependency or security section. Specifically:
- Key Findings and Counts & Metrics name the INSTALLED `next`, `react`
  and `react-dom` versions from the lockfile (never a `package.json`
  range presented as the version) and the router model
- Every vulnerability statement carries its advisory ID (GHSA / CVE),
  the source URL and the query time, exactly as recorded by the
  dependency-security step. Patched versions are quoted from the
  advisory. Never write a vulnerable or patched version from memory
- If the live lookup failed, write `Unknown — could not verify against
  live sources` for that package and say which sources failed; never
  "no known vulnerabilities"
- Support status of the installed `next` major (endoflife.date) is a
  Key Finding; an end-of-life major is a Risk
- Package-manager findings (`not using pnpm`, missing `packageManager`
  pin, multiple/no lockfile, lockfile out of sync) appear in Key
  Findings or Risks, with pnpm as the recommendation — never as a
  change made during the audit
- When any critical/high advisory or an end-of-life major is found, the
  Recommendations list includes running `/somnio:nextjs-security-audit`

PERFORMANCE SECTION (Section 8):
Since there is no dedicated performance reference step in the health
audit, derive the Performance score from evidence gathered across
all previous steps:
- Server Components by default: share of `'use client'` files and
  client `layout`/`page` files (code-quality, repository-inventory) —
  a small client surface keeps JavaScript off the critical path
- `next/image` usage vs raw `<img>`, `priority`/`preload` on
  above-the-fold images, `sizes` on responsive images, remote patterns
  instead of `unoptimized` (code-quality, config-analysis)
- `next/font` vs external font links (code-quality)
- `next/script` with explicit strategies vs raw `<script>`;
  `@next/third-parties` for common embeds (code-quality)
- Dynamic imports (`next/dynamic`, `React.lazy`) for heavy client-only
  widgets; `<Suspense>` boundaries and `loading.*` files around slow
  data (code-quality, repository-inventory, state-management-analysis)
- Caching and rendering: deliberate caching model (`use cache` +
  `cacheLife`, or fetch/segment revalidation), static or partially
  prerendered routes in the `next build` route table, request
  waterfalls (state-management-analysis, version-validator)
- Bundle analysis readiness (`next analyze` for Turbopack,
  `@next/bundle-analyzer` for webpack) and
  `experimental.optimizePackageImports` (code-quality, config-analysis)
- React Compiler enabled, manual memoization, array-index keys and list
  virtualization for long lists (code-quality)
- `.next/cache` persisted in CI affects build time only — mention it in
  CI/CD, not here
Score this section based on available evidence or mark as "Unknown"
if no evidence could be gathered. Never quote Core Web Vitals or
bundle sizes that were not measured in this run.

Verify the Overall Score calculation:
- Check that the Overall Score uses the correct weighted formula
- Calculate: overall_score = round( Σ(section_score × weight) )
- Ensure the Overall Score is an integer value (0-100)
- Verify the label assignment: 85-100=Strong, 70-84=Fair, 0-69=Weak

Address any "Unknown" items by referencing missing files/artifacts.

SECTION FORMAT REQUIREMENTS:
Each section MUST follow this exact format:

[Section Number]. [Section Name]

Description: [One-sentence description of the section's purpose]

Score: [Score]/100 ([Label])

Section 6 (Testing) EXCEPTION: MUST include, immediately after Score
and before Key Findings, exactly these two fields (this is the report's
canonical, and only other, coverage surface besides the Section 2
scorecard line below):
- "Code Coverage: XX% (lines)" plus a sub-line for multi-dimension
  stacks ("XX% lines / XX% branches / XX% functions"), monorepos
  ("App [name]: XX%, App [name2]: YY%"), or "Not measured (no coverage
  tool detected/configured)" if none was found. Extract from
  test_coverage results.
- "Coverage Breakdown:" — a bullet list, one line per
  module/package/app ("`[module]`: XX% (lines[, YY% branches, ZZ%
  functions])"), or "N/A — single package, see Code Coverage above" for
  single-package projects, or "(no coverage data — artifact missing or
  no coverage tool configured)" if none was found.
Section 6's Counts & Metrics subsection must NOT restate the coverage
percentage — it lives only in the two fields above.

Key Findings:
- [Bullet point 1]
- [Bullet point 2]
- [Continue as needed]

Evidence:
- [File path or configuration reference]
- [Specific evidence item]
- [Continue as needed]

Risks:
- [Risk item 1]
- [Risk item 2]
- [Continue as needed]

Recommendations:
- [Recommendation 1]
- [Recommendation 2]
- [Continue as needed]

Counts & Metrics:
- [Metric name]: [Value]
- [Metric name]: [Value]
- [Continue as needed]

SPECIAL SECTION FORMATS:

1. Executive Summary:
Description: [Comprehensive analysis description]
Overall Score: [Score]/100 ([Label])
Top Strengths:
- [Strength 1]
- [Strength 2]
- [Continue as needed]
Top Risks:
- [Risk 1]
- [Risk 2]
- [Continue as needed]
Priority Recommendations:
1. [Recommendation 1]
2. [Recommendation 2]
3. [Continue as needed]

2. At-a-Glance Scorecard:
| Section | Score | Label |
|---------|-------|-------|
| Tech Stack | [Score]/100 | [Label] |
| Architecture | [Score]/100 | [Label] |
| State Management | [Score]/100 | [Label] |
| Testing | [Score]/100 | [Label] |
| Code Quality (Linter & Warnings) | [Score]/100 | [Label] |
| Performance | [Score]/100 | [Label] |
| Documentation & Operations | [Score]/100 | [Label] |
| CI/CD (Configs Found in Repo) | [Score]/100 | [Label] |
| AI Harness & Adoption | [Score]/100 | [Label] |
| **Overall** | **[Score]/100** | **[Label]** |

The scorecard has exactly the template's columns (`| Section | Score | Label |`). Never add Weight, Previous, Baseline, Change or Delta columns; trend data goes only in its defined slot.

Immediately below the scorecard, in this exact order, three more lines:
- "Test Coverage: [X]% (lines) — full breakdown in the Testing
  section." with a second line inside the same quoting, the fallback
  "Not measured (no coverage tool detected/configured)" for when no
  coverage tool was detected. Never label this bare "Coverage" — that
  word is already the AI Harness rubric table heading in section 11.
- "Scoring: Strong (85-100) / Fair (70-84) / Weak (0-69)" (in the
  rendered Markdown this uses an en dash in each range and a middle dot
  separator; see assets/report-template.md for the exact characters).
- A one-sentence interpretation of the Overall Score. This is the
  sentence formerly carried by the deleted Quality Index section — if
  there is a concrete interpretation to give, put it here.

11. AI Harness & Adoption:
Description: [One-sentence description of the state of the harness]
Score: [Score]/100 ([Label])
Maturity: [sin harness | harness básico | harness sólido | paved path]
Harness Coverage:
- CLAUDE.md: [Status] — [Points]/13
- Rules: [Status] — [Points]/9
- Permissions: [Status] — [Points]/13
- Hooks: [Status] — [Points]/14
- Pre-push git hook: [Status] — [Points]/11
- Agents: [Status] — [Points]/11
- Commands / Skills: [Status] — [Points]/9
- Advanced orchestration: [Status] — [Points]/5
- Lifecycle: [Status] — [Points]/3
- Harness versioning: [Status] — [Points]/12
- Total: [Points]/100
Key Findings:
- [Bullet point 1]
- [Bullet point 2]
- [Continue as needed]
Evidence:
- [Real file path or configuration reference, never invented]
- [Continue as needed]
Risks:
- [Risk item 1]
- [Continue as needed]
Actions to Raise the Score:
1. [+N] [Concrete how-to for this repo] -> dimension D, X/Y -> Y/Y.
2. [Continue, sorted by points recovered descending]
Counts & Metrics:
- [Metric name]: [Value]
- [Continue as needed]

12. Additional Metrics:
- Node.js version: [Version]
- Next.js version (installed): [Version]
- React version (installed): [Version]
- TypeScript version: [Version or Not used]
- Package manager: [pnpm/npm/yarn/bun]
- Router: [App Router/Pages Router/Mixed]
- Bundler: [Turbopack/Webpack]
- Output mode: [default/standalone/export]
- Monorepo tool: [pnpm workspaces/turborepo/nx/none]
- Routes: [N pages, N Route Handlers]
- Client Component files: [N of M]
- Server Action files: [Count]
- Caching model: [Cache Components/previous model/Pages Router ISR]
- State management: [none needed/Context/Zustand/Redux/Mixed]
- Client server-state library: [TanStack Query/SWR/None]
- Styling approach: [CSS Modules/Tailwind/CSS-in-JS/Other]

13. Risks & Opportunities:
- [Risk/Opportunity 1]
- [Risk/Opportunity 2]
- [Continue as needed]

14. Recommendations:
1. [Priority Level]: [Recommendation 1]
2. [Priority Level]: [Recommendation 2]
3. [Continue as needed]

15. Appendix: Evidence Index:
File Paths and Configs by Area:
[Area Name]:
- [File path or config reference]
- [Continue as needed]

Appendix: Scoring Methodology (UNNUMBERED — this file is the
authoritative source of the weight literals; report-format-enforcer.md
and agents/report-writer.md must not restate these numbers, only point
here):
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
| Total | 1.00 |
Row labels must match the scorecard row labels verbatim. Rounding rule
and scoring bands as stated above.

FORMATTING RULES:
- USE MARKDOWN SYNTAX: Use ## headings, **bold**, `backtick` paths
- USE BOLD: Bold the field label only; never bold the numeric value after `**Score:**`.
- USE CODE BLOCKS: Backticks for file paths and inline code
- USE TABLES: Markdown pipe tables wherever the template renders one
- SECTION HEADERS: Use "## X. Section Name"; subsections use "### Name"
- FIELD LABELS: Bold them — "**Description:**", "**Score:**", etc.
- BULLET POINTS: Use "- " for all lists
- NUMBERED LISTS: Use "1. ", "2. " format
- SCORES: Always format as "[Score]/100 ([Label])"
- LABELS: Use "Strong" (85-100), "Fair" (70-84), "Weak" (0-69)

MONOREPO HANDLING:
For monorepo repositories (pnpm workspaces, turborepo, nx):
- Include app-specific metrics in Counts & Metrics
- Report per-app coverage in the Testing section's Coverage Breakdown
  field (never in Additional Metrics)
- Include app-specific evidence in Evidence sections
- Mention app names in descriptions where relevant
- Report cross-app consistency in Key Findings

Format: Markdown-formatted report — ## headings, **bold** field
labels and pipe tables, exactly as assets/report-template.md renders
them. That template and references/report-format-enforcer.md are
authoritative on formatting; this file must not contradict them.
