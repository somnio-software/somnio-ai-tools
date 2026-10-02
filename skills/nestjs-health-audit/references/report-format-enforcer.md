# NestJS Report Format Enforcer

> Enforce consistent report format structure for NestJS Project Health Audit reports based on the established template located in assets/report-template.md

---

When generating the final report, you MUST follow this exact
structure and format based on the template in
assets/report-template.md:

--------------------------------------------------------------------
IMPORTANT EXCLUSIONS
--------------------------------------------------------------------

NEVER include recommendations for:
- CODEOWNERS or SECURITY.md files (governance decisions, not
  technical requirements)
- Deployment-specific workflows (deployment decisions, not
  technical requirements)

--------------------------------------------------------------------
REPORT HEADER
--------------------------------------------------------------------

The header MUST carry BOTH blocks, in this order, before the first
`---`: the project-metadata block (`**Project:**` / `**Date:**` /
`**Auditor:**` / `**Framework:** [NestJS/Node.js]`) AND the
`> **Exclusions:**` blockquote. Neither block replaces the other. See
assets/report-template.md for the exact shape.

--------------------------------------------------------------------
MANDATORY REPORT STRUCTURE
--------------------------------------------------------------------

The report MUST contain exactly these 15 numbered sections in this
order, followed by two trailing unnumbered blocks:

1. Executive Summary
2. At-a-Glance Scorecard
3. Tech Stack
4. Architecture
5. API Design
6. Data Layer
7. Testing
8. Code Quality (Linter & Warnings)
9. Documentation & Operations
10. CI/CD (Configs Found in Repo)
11. AI Harness & Adoption
12. Additional Metrics
13. Risks & Opportunities
14. Recommendations
15. Appendix: Evidence Index

...then, unnumbered, in this order:
- Appendix: Scoring Methodology
- Report Metadata

There is no "Quality Index" section. It was removed; its one
non-duplicate line (an interpretation sentence) now lives at the end
of the At-a-Glance Scorecard block (Section 2).

--------------------------------------------------------------------
SECTION FORMAT REQUIREMENTS
--------------------------------------------------------------------

Each section MUST follow this exact format:

[Section Number]. [Section Name]

Description: [One-sentence description of the section's purpose]

Score: [Score]/100 ([Label])

Section 7 (Testing) MUST include the canonical coverage fields between
Score and Key Findings — "Code Coverage:" (with its multi-dimension/
monorepo/no-tool fallback sub-lines) and "Coverage Breakdown:" —
exactly as shown in assets/report-template.md. Extract the values from
the @nestjs_test_coverage artifact. NEVER restate the coverage
percentage anywhere else (not in Counts & Metrics, not in Additional
Metrics — see the checklist below).

Key Findings:
- [Bullet point 1]
- [Bullet point 2]
- [Bullet point 3]
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

--------------------------------------------------------------------
SPECIAL SECTION FORMATS
--------------------------------------------------------------------

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
- Tech Stack: [Score]/100 ([Label])
- Architecture: [Score]/100 ([Label])
- API Design: [Score]/100 ([Label])
- Data Layer: [Score]/100 ([Label])
- Testing: [Score]/100 ([Label])
- Code Quality (Linter & Warnings): [Score]/100 ([Label])
- Documentation & Operations: [Score]/100 ([Label])
- CI/CD (Configs Found in Repo): [Score]/100 ([Label])
- AI Harness & Adoption: [Score]/100 ([Label])
- Overall: [Score]/100 ([Label])

Immediately below the scorecard table, in this exact order:
1. `> **Test Coverage:** [X]% (lines) — full breakdown in the Testing
   section.` with the "no coverage tool detected" fallback as a SECOND
   line inside the SAME blockquote (not a separate one).
2. `> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)` — en
   dash (U+2013) inside each range, middle dot (U+00B7) as separator.
3. A one-sentence interpretation of the Overall Score (the sentence
   absorbed from the removed Quality Index section, or the bracketed
   placeholder if none exists).
NEVER add a Weight column to this table — weights appear only in the
"Appendix: Scoring Methodology" block (see below).

12. Additional Metrics:
- Node.js version: [Version]
- NestJS version: [Version]
- TypeScript version: [Version]
- Package manager: [npm/yarn/pnpm]
- Monorepo tool: [nx/turborepo/lerna/none]
- Total modules count: [Count] ([App breakdown if monorepo])
- Total controllers count: [Count]
- Total services count: [Count]
- Total DTOs count: [Count]
- API type detected: [REST/GraphQL/Hybrid]
- OpenAPI/Swagger enabled: [Yes/No]
- Database ORM: [TypeORM/Prisma/Sequelize/MikroORM/none]
- Authentication method: [JWT/Passport/Session/none]

NEVER include a "Coverage %:" or "Overall aggregated coverage %:"
bullet here. Coverage is reported exactly twice in the whole report —
the scorecard's Test Coverage line and the Testing section's Code
Coverage / Coverage Breakdown fields — and nowhere else.

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

Appendix: Scoring Methodology (unnumbered, follows Section 15):
A `| Section | Weight |` table, one row per scored section matching
the scorecard's own row labels, plus a **Total** row of **1.00**. The
weight NUMBERS themselves are NOT re-pasted in this file — they are
defined once, in `references/report-generator.md`, which is the single
source of truth; read them from there when validating this block.
Followed by the rounding rule and the scoring bands, matching
assets/report-template.md exactly. This appendix is the ONLY place in
the whole report where weights may appear.

Report Metadata (unnumbered, follows the Scoring Methodology appendix):
the trailing `| Field | Value |` table exactly as
assets/report-template.md renders it.

--------------------------------------------------------------------
FORMATTING RULES
--------------------------------------------------------------------

1. USE MARKDOWN SYNTAX: Use proper Markdown formatting (# headers, **bold**, `backtick` paths)
2. USE BOLD: Use **bold** for scores, labels, and key terms
3. USE CODE BLOCKS: Use backticks for file paths and inline code
4. USE TABLES: Use Markdown tables for scorecards and metadata
5. SECTION HEADERS: Use "## X. Section Name" Markdown format
6. SUBSECTION HEADERS: Use "Description:", "Score:", etc.
7. BULLET POINTS: Use "- " for all lists
8. NUMBERED LISTS: Use "1. ", "2. " format
9. SCORES: Always format as "[Score]/100 ([Label])"
10. LABELS: Use "Strong" (85-100), "Fair" (70-84), "Weak" (0-69)

--------------------------------------------------------------------
CONTENT REQUIREMENTS
--------------------------------------------------------------------

1. All sections must be present and in order
2. Each section must have all required subsections
3. Scores must be integers (0-100)
4. Labels must match score ranges
5. Evidence must reference actual file paths
6. Recommendations must be actionable
7. Risks must be specific and relevant
8. Metrics must be quantifiable when possible

--------------------------------------------------------------------
MONOREPO HANDLING
--------------------------------------------------------------------

For monorepo repositories (nx, turborepo, lerna):
1. Include app-specific metrics in Counts & Metrics
2. Report per-app coverage in the Testing section's "Coverage
   Breakdown:" field, not in Additional Metrics
3. Include app-specific evidence in Evidence sections
4. Mention app names in descriptions where relevant
5. Report cross-app consistency in Key Findings

--------------------------------------------------------------------
VALIDATION CHECKLIST
--------------------------------------------------------------------

Before finalizing the report, verify:
✓ The header carries BOTH the project-metadata block and the
  `> **Exclusions:**` blockquote
✓ All 15 numbered sections are present, plus the two trailing
  unnumbered blocks (Appendix: Scoring Methodology, Report Metadata)
✓ No "Quality Index" section exists anywhere in the report
✓ The `> **Test Coverage:**` line (with its no-coverage-tool fallback
  as a second line in the same blockquote) sits directly under the
  At-a-Glance Scorecard table
✓ The Testing section carries the canonical `**Code Coverage:**` and
  `**Coverage Breakdown:**` fields between Score and Key Findings
✓ The AI Harness & Adoption section uses `### Harness Coverage`, never
  a bare `### Coverage`
✓ NO coverage percentage is restated in Counts & Metrics or in
  Additional Metrics — coverage appears exactly twice in the whole
  report (the scorecard line and the Testing fields)
✓ The `## Appendix: Scoring Methodology` block is present, immediately
  before `## Report Metadata`
✓ Weights appear ONLY inside the Scoring Methodology appendix, NEVER
  as a column in the At-a-Glance Scorecard table
✓ All sections follow the required format
✓ All scores are integers with proper labels
✓ All evidence references actual files
✓ All recommendations are actionable
✓ Markdown formatting is used consistently
✓ Monorepo metrics are included if applicable
✓ Overall score calculation is correct
✓ Report uses proper Markdown headings and formatting

Remember: This format ensures consistency, readability, and
professional presentation of NestJS project health audit results.
