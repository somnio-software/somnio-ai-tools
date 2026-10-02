# Flutter Report Format Enforcer

> Enforce consistent report format structure for Flutter Project Health Audit reports based on the established template located in assets/report-template.md

---

When generating the final report, you MUST follow this exact structure
and format based on the template in assets/report-template.md:

----------------------------------------------------------------------
IMPORTANT EXCLUSIONS
----------------------------------------------------------------------

NEVER include recommendations for:
- Adding new languages or translations (internationalization
  expansion)
- CODEOWNERS or SECURITY.md files (governance decisions, not
  technical requirements)
- Platform-specific workflows for Android/iOS builds (deployment
  decisions, not technical requirements)

----------------------------------------------------------------------
HEADER
----------------------------------------------------------------------

The header MUST carry BOTH blocks, in this order: the project-metadata
block (`**Project:**` / `**Date:**` / `**Auditor:**` / `**Framework:**`)
AND the Exclusions blockquote — do not drop either one.

```markdown
# Flutter Project Health Audit Report

**Project:** [PROJECT_NAME]
**Date:** [AUDIT_DATE]
**Auditor:** AI-Assisted Analysis
**Framework:** [Flutter/Dart — single app/monorepo]

> **Exclusions:** Never recommend adding new languages/translations, CODEOWNERS/SECURITY.md files, or platform-specific Android/iOS build workflows.

---
```

----------------------------------------------------------------------
MANDATORY REPORT STRUCTURE
----------------------------------------------------------------------

The report MUST contain exactly these 15 numbered sections, in this
order, followed by 2 trailing unnumbered blocks. There is no "Quality
Index" section — it was a byte-for-byte duplicate of the Section 2
scorecard and has been deleted; its one non-duplicate line (a trailing
interpretation sentence) now lives at the end of Section 2:

1. Executive Summary
2. At-a-Glance Scorecard
3. Tech Stack
4. Architecture
5. State Management
6. Repositories & Data Layer
7. Testing
8. Code Quality (Linter & Warnings)
9. Documentation & Operations
10. CI/CD (Configs Found in Repo)
11. AI Harness & Adoption
12. Additional Metrics
13. Risks & Opportunities
14. Recommendations
15. Appendix: Evidence Index
Appendix: Scoring Methodology (UNNUMBERED)
Report Metadata (UNNUMBERED)

----------------------------------------------------------------------
SECTION FORMAT REQUIREMENTS
----------------------------------------------------------------------

Each section MUST follow this exact format:

[Section Number]. [Section Name]

Description: [One-sentence description of the section's purpose]

Score: [Score]/100 ([Label])

Section 7 (Testing) MUST include "Code Coverage:" on a line immediately
after Score, before Key Findings. Extract from @flutter_test_coverage
artifact (line starting with "Code Coverage:").
MUST also include "Coverage Breakdown:" immediately after "Code Coverage:",
listing per-component coverage (one line per lib/package). Extract from
@flutter_test_coverage artifact (lines under "COVERAGE BREAKDOWN:").
For monorepos, separate by application and by package.

Example (single app with packages):
  Code Coverage: 3% (overall: lib + packages)
  Coverage Breakdown:
    locl/lib: 2%
    packages/app_config_repository: 10%
    packages/community_repository: 0%
    packages/location_service: 85%

Example (multi-app monorepo):
  Code Coverage: App appA: 15%, App appB: 22%
  Coverage Breakdown:
    appA/lib: 12%
    appA/packages/shared_ui: 20%
    appB/lib: 18%
    packages/common_utils: 45%

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

----------------------------------------------------------------------
SPECIAL SECTION FORMATS
----------------------------------------------------------------------

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
- State Management: [Score]/100 ([Label])
- Repositories & Data Layer: [Score]/100 ([Label])
- Testing: [Score]/100 ([Label])
- Code Quality (Linter & Warnings): [Score]/100 ([Label])
- Documentation & Operations: [Score]/100 ([Label])
- CI/CD (Configs Found in Repo): [Score]/100 ([Label])
- AI Harness & Adoption: [Score]/100 ([Label])
- Overall: [Score]/100 ([Label])

REQUIRED — no Weight column in this table (weights live only in the
Appendix: Scoring Methodology). Immediately below the scorecard, in
this exact order:
> **Test Coverage:** [X]% (lines) — full breakdown in the Testing section.
> Fallback when no coverage tool is detected: `Not measured (no coverage tool detected/configured)`

> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)

[One-sentence interpretation of the Overall Score.]

The "Test Coverage" label is mandatory and must never be shortened to
a bare "Coverage" — that word is the AI Harness rubric heading
("Harness Coverage") in Section 11.

11. AI Harness & Adoption:
Description: [One-sentence description of the harness analysis].
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
- Total: [Score]/100
Key Findings:
- [Finding 1]
- [Continue as needed]
Evidence:
- [Real file path only, never invented]
- [Continue as needed]
Risks:
- [Risk item 1]
- [Continue as needed]
Actions to Raise the Score:
1. [+N] [Action naming the file/key to add and the how-to] → dimension D, X/Y → Y/Y.
2. [Continue as needed, sorted by points recovered descending]
Counts & Metrics:
- [Metric name]: [Value]
- [Continue as needed]

12. Additional Metrics:
- Supported platforms: [Platform list]
- Number of feature folders: [Count] ([App breakdown if multi-app])
- Packages count: [Count]
- State management detected: [Pattern]
- Force-upgrade/maintenance mode: [Status]
- Spell-check scope: [Scope]
- Public API docs enforcement: [Status]

REQUIRED — NO coverage percentage anywhere in this section (no
"Coverage %:", "Coverage breakdown by component:", or "Overall
aggregated coverage %:" bullets). That data lives only in the Section 2
Test Coverage line and the Section 7 Code Coverage / Coverage
Breakdown fields.

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

Appendix: Scoring Methodology (UNNUMBERED — required, must appear
after Section 15 and before Report Metadata):

```markdown
## Appendix: Scoring Methodology

**Weighted formula** (weights sum to 1.00 — the authoritative source is
`references/report-generator.md`; this table is a read-only summary of
what was applied):

| Section | Weight |
|---------|--------|
| Tech Stack | [Weight] |
| Architecture | [Weight] |
| State Management | [Weight] |
| Repositories & Data Layer | [Weight] |
| Testing | [Weight] |
| Code Quality (Linter & Warnings) | [Weight] |
| Documentation & Operations | [Weight] |
| CI/CD (Configs Found in Repo) | [Weight] |
| AI Harness & Adoption | [Weight] |
| **Total** | **1.00** |

Weights are defined in `references/report-generator.md` — that file is
the single source of truth; do not restate the numbers here. Fill in
each row's `[Weight]` value by reading it from there.

**Rounding rule:** Standard mathematical rounding (0.5 rounds up). No subjective adjustment.

**Scoring bands:** Strong (85–100) · Fair (70–84) · Weak (0–69)
```

This appendix is the ONLY place in the report where weights may appear.
The Section 2 scorecard table NEVER carries a Weight column.

----------------------------------------------------------------------
FORMATTING RULES
----------------------------------------------------------------------

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

----------------------------------------------------------------------
CONTENT REQUIREMENTS
----------------------------------------------------------------------

1. All sections must be present and in order
2. Each section must have all required subsections
3. Scores must be integers (0-100)
4. Labels must match score ranges
5. Evidence must reference actual file paths
6. Recommendations must be actionable
7. Risks must be specific and relevant
8. Metrics must be quantifiable when possible

----------------------------------------------------------------------
MULTI-APP HANDLING
----------------------------------------------------------------------

For multi-app repositories:
1. Include app-specific metrics in Counts & Metrics
2. Report per-app coverage in Section 7's Coverage Breakdown, never in
   Additional Metrics (Additional Metrics carries no coverage data —
   see Section 12 above)
3. Include app-specific evidence in Evidence sections
4. Mention app names in descriptions where relevant
5. Report cross-app consistency in Key Findings

----------------------------------------------------------------------
VALIDATION CHECKLIST
----------------------------------------------------------------------

Before finalizing the report, verify:
✓ All 15 numbered sections are present, in order, with no "Quality
  Index" section
✓ The header carries both the project-metadata block and the
  Exclusions blockquote
✓ The `> **Test Coverage:**` line (with its fallback second line)
  appears directly under the Section 2 scorecard table
✓ Section 7 (Testing) has the canonical `Code Coverage:` and `Coverage
  Breakdown:` fields between Score and Key Findings
✓ Section 11 (AI Harness & Adoption) uses `Harness Coverage:`, never a
  bare `Coverage:`
✓ NO coverage percentage is restated in Counts & Metrics or Additional
  Metrics anywhere in the report
✓ The `## Appendix: Scoring Methodology` block is present, after
  Section 15 and before `## Report Metadata`
✓ Weights appear ONLY in the Appendix: Scoring Methodology — never as a
  column in the Section 2 scorecard table
✓ All sections follow the required format
✓ All scores are integers with proper labels
✓ All evidence references actual files
✓ All recommendations are actionable
✓ Markdown formatting is used consistently
✓ Multi-app metrics are included if applicable
✓ Overall score calculation is correct
✓ Report uses proper Markdown headings and formatting

Remember: This format ensures consistency, readability, and
professional presentation of Flutter project health audit results.
