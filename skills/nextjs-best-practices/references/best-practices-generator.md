# Next.js Best Practices Report Generator

> Consolidate all analysis findings into a comprehensive best practices report using the standard template format.

---

## REPORT GENERATION INSTRUCTIONS

1.  **GATHER ALL ANALYSIS OUTPUTS**:
    Collect findings from all analysis rules:
    - App Router Architecture Analysis
    - Server & Client Components Analysis
    - Data Fetching & Caching Analysis
    - Server Actions & Route Handlers Analysis
    - Rendering Performance Analysis
    - Testing Quality Analysis
    - TypeScript Standards Analysis
    Take the installed `next` version, the docs source and the caching model
    from those outputs. If two outputs disagree on the version, report the
    lockfile-derived one and note the conflict in the Executive Summary.

2.  **COMPUTE OVERALL SCORE**:
    Calculate weighted average:
    - App Router Architecture: 15%
    - Server & Client Components: 20%
    - Data Fetching & Caching: 20%
    - Server Actions & Route Handlers: 15%
    - Rendering Performance: 10%
    - Testing Quality: 10%
    - TypeScript Standards: 10%
    If a section scored `N/A` (no surface for that dimension in the project),
    exclude it and divide by the sum of the remaining weights, so the
    remaining weights keep their proportions. Name the excluded sections in
    the Appendix.

3.  **PRIORITIZE FINDINGS**:
    Rank all violations by:
    - Critical: missing authorization in a Server Action or Route Handler,
      secrets or server-only modules reachable from the client bundle,
      user-specific data in a shared cache, `ignoreBuildErrors` with no CI
      type check, no tests at all
    - High: unvalidated action/handler input, APIs not documented for the
      installed version, request waterfalls on key routes, `'use client'` on
      layouts/pages, mutations without revalidation, missing error
      boundaries on data routes
    - Medium: missing loading/not-found boundaries, raw `<img>`/`<script>`,
      over-broad revalidation, unnecessary dynamic rendering, missing E2E
      coverage of critical flows, typed routes not enabled
    - Low: style issues, package-manager recommendation, minor improvements

4.  **GENERATE REPORT USING TEMPLATE**:
    Use the template at:
    "assets/report-template.md"

5.  **RECOMMENDED FOLLOW-UPS**:
    Where the analysis outputs list recommended follow-up skills (official
    Next.js agent skills from https://github.com/vercel/next.js/tree/canary/skills,
    Vercel's `react-best-practices` skill, or `nextjs-security-audit`),
    include them in Prioritized Recommendations at the priority of the
    finding they address. Never recommend a skill the outputs did not
    justify.

## REPORT SECTIONS

1. EXECUTIVE SUMMARY
   - Overall Score with label (Strong/Fair/Weak)
   - Installed Next.js version, router(s), caching model, docs source
   - Top 3 Strengths
   - Top 3 Critical Issues
   - Immediate Action Items

2. SCORE BREAKDOWN
   - App Router Architecture: XX/100 (Label)
   - Server & Client Components: XX/100 (Label)
   - Data Fetching & Caching: XX/100 (Label)
   - Server Actions & Route Handlers: XX/100 (Label)
   - Rendering Performance: XX/100 (Label)
   - Testing Quality: XX/100 (Label)
   - TypeScript Standards: XX/100 (Label)

3. APP ROUTER ARCHITECTURE
   - Routing Model
   - Route Structure & Colocation
   - Boundaries
   - Metadata
   - Violations and Recommendations

4. SERVER & CLIENT COMPONENTS
   - Client Surface
   - Boundary Safety
   - Hydration
   - Violations and Recommendations

5. DATA FETCHING & CACHING
   - Caching Model
   - Fetching Patterns
   - Streaming
   - Revalidation
   - Violations and Recommendations

6. SERVER ACTIONS & ROUTE HANDLERS
   - Inventory
   - Input & Authorization
   - Mutation Hygiene
   - Violations and Recommendations

7. RENDERING PERFORMANCE
   - Asset Optimization
   - Code Splitting
   - Rendering Strategy
   - Violations and Recommendations

8. TESTING QUALITY
   - Test Tooling
   - Next.js Surface Coverage
   - Test Quality
   - Violations and Recommendations

9. TYPESCRIPT STANDARDS
   - TypeScript Configuration
   - Linting & Tooling
   - Type Safety
   - Violations and Recommendations

10. PRIORITIZED RECOMMENDATIONS
    - Critical (Must Fix)
    - High Priority
    - Medium Priority
    - Low Priority (Nice to Have)

11. EVIDENCE INDEX
    - All file references organized by category

APPENDIX: SCORING METHODOLOGY (unnumbered — no `## N.` prefix)
   - A `| Section | Weight |` table: one row per scored section, in the same
     order as the Score Breakdown rows and with byte-identical row labels,
     using the percentages from step 2 above, closing with a
     `| **Total** | **100%** |` row
   - The rounding rule and the scoring bands
   - Any section excluded as `N/A` and the renormalization applied
   - Weights appear ONLY here and in this file — NEVER as a column in the
     Score Breakdown table

REPORT METADATA (unnumbered — no `## N.` prefix)
   - A `| Field | Value |` table with Generated by, Skill, Date, the
     Somnio AI Tools link and the Standards Source, exactly as
     `assets/report-template.md` renders it.
     NOT a plain-text `---`-delimited list.

## OUTPUT REQUIREMENTS

- Use Markdown format (# headers, **bold**, `backtick` file paths)
- Include all file references with line numbers
- Provide specific, actionable recommendations
- Include code examples where helpful
- Score each section 0-100 with label, or `N/A` with the reason
- List violations with severity level
- Every version-dependent statement names the installed version it applies to
- Emit the numbered sections in the SAME ORDER as the template — do not
  reorder them by score, severity or any other criterion
- Close with the two unnumbered blocks above, in that order: Appendix:
  Scoring Methodology, then Report Metadata
