# Python Report Format Enforcer

> Enforce consistent report format structure for Python Project Health Audit reports based on the established template located in assets/report-template.md

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
MANDATORY HEADER
--------------------------------------------------------------------

The header MUST carry BOTH blocks, in this order, exactly as
assets/report-template.md renders them:
1. The project-metadata block (Project / Date / Auditor / Framework)
2. The Exclusions blockquote

Neither block replaces the other — do not drop the project-metadata
block in favor of the Exclusions blockquote or vice versa.

--------------------------------------------------------------------
MANDATORY REPORT STRUCTURE
--------------------------------------------------------------------

The report MUST contain exactly these 15 numbered sections in this order,
plus two trailing unnumbered blocks:

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
Appendix: Scoring Methodology (unnumbered — see below)
Report Metadata (unnumbered)

There is no "Quality Index" section. It was removed (it duplicated the
At-a-Glance Scorecard table byte-for-byte); its one non-duplicate sentence
now lives at the end of Section 2. NEVER emit a "Quality Index" section.

--------------------------------------------------------------------
SECTION FORMAT REQUIREMENTS
--------------------------------------------------------------------

Each section MUST follow this exact format:

[Section Number]. [Section Name]

Description: [One-sentence description of the section's purpose]

Score: [Score]/100 ([Label])

Section 7 (Testing) MUST include, between "Score:" and "Key Findings:",
in this order: "Code Coverage:" then "Coverage Breakdown:". Extract from
@python_test_coverage artifact.

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
Do NOT add a Weight column to this table — weights appear ONLY in the
Appendix: Scoring Methodology block (see below), never in the scorecard.
Immediately below the table, in this exact order:
- Test Coverage: [X]% (lines) — full breakdown in the Testing section.
  Second line, same blockquote: fallback "Not measured (no coverage tool
  detected/configured)" when no coverage tool is detected.
- Scoring: Strong (85–100) · Fair (70–84) · Weak (0–69) (en dash inside
  each range, middle dot as separator — exact typography, no ASCII
  hyphens)
- [One-sentence interpretation of the Overall Score] (absorbed from the
  removed Quality Index section)

11. AI Harness & Adoption:
Description: [One-sentence description of the harness's state]
Score: [Score]/100 ([Label])
Maturity: [sin harness | harness básico | harness sólido | paved path]
Harness Coverage: one row per rubric dimension (CLAUDE.md, Rules, Permissions,
Hooks, Pre-push git hook, Agents, Commands / Skills, Advanced
orchestration, Lifecycle, Harness versioning) plus a bold Total row
Key Findings:
- [Finding 1]
- [Continue as needed]
Evidence:
- [File path or configuration reference]
- [Continue as needed]
Risks:
- [Risk item 1]
- [Continue as needed]
Actions to Raise the Score:
1. [+N] [Concrete how-to] -> dimension D, X/Y -> Y/Y.
2. [Continue, sorted by points recovered descending]
Counts & Metrics:
- [Metric name]: [Value]
- [Continue as needed]

12. Additional Metrics:
- Python version: [Version]
- Package manager: [pip/poetry/pipenv/uv]
- Framework: [Django/FastAPI/Flask/Starlette/etc]
- Python framework version: [Version]
- Total modules count: [Count]
- Total classes count: [Count]
- Total functions count: [Count]
- Total data models count: [Count]
- API type detected: [REST/GraphQL/Hybrid]
- OpenAPI/Swagger enabled: [Yes/No]
- Database ORM: [SQLAlchemy/Django ORM/Tortoise ORM/Pydantic/none]
- Authentication method: [JWT/OAuth2/Session/none]
- Type checking: [mypy/pyright/none]
NEVER restate a coverage percentage here (no "Coverage %" bullet, no
per-package coverage breakdown) — coverage lives only in the Test
Coverage line under the scorecard (Section 2) and the Code Coverage /
Coverage Breakdown fields in Testing (Section 7).

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

Appendix: Scoring Methodology (unnumbered, comes after Section 15 and
before Report Metadata):
- A "| Section | Weight |" Markdown table, one row per scorecard row in
  the same order, plus a bold Total row equal to 1.00.
- The weight VALUES are never re-typed here from memory — read them from
  `references/report-generator.md`, the single source of truth for the
  weights; this table is a read-only summary of what was applied.
- Followed by the rounding rule ("Standard mathematical rounding (0.5
  rounds up). No subjective adjustment.") and the scoring bands line
  ("Strong (85–100) · Fair (70–84) · Weak (0–69)").
- This appendix is the ONLY place in the report where weights may appear.
  The At-a-Glance Scorecard table (Section 2) NEVER carries a Weight
  column.

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

For monorepo repositories (using tools like poetry workspaces, setuptools, or tox):
1. Include app-specific metrics in Counts & Metrics
2. Report per-app coverage in the Testing section's Coverage Breakdown
   field and in the Test Coverage line under the scorecard — never in
   Additional Metrics
3. Include app-specific evidence in Evidence sections
4. Mention app names in descriptions where relevant
5. Report cross-app consistency in Key Findings

--------------------------------------------------------------------
VALIDATION CHECKLIST
--------------------------------------------------------------------

Before finalizing the report, verify:
✓ All 15 numbered sections are present, in order, with no "Quality Index"
  section
✓ The header carries both the project-metadata block and the Exclusions
  blockquote
✓ The "Test Coverage" line (with its fallback line in the same
  blockquote) sits directly under the At-a-Glance Scorecard table
✓ The Testing section has "Code Coverage:" and "Coverage Breakdown:"
  between "Score:" and "Key Findings:"
✓ The AI Harness & Adoption section uses "Harness Coverage:", not a bare
  "Coverage:"
✓ No coverage percentage is restated in Counts & Metrics or in Additional
  Metrics anywhere in the report
✓ The "Appendix: Scoring Methodology" block is present, after Section 15
  and before "Report Metadata"
✓ Weights appear ONLY in the Appendix: Scoring Methodology — never as a
  column in the At-a-Glance Scorecard table
✓ All sections follow the required format
✓ All scores are integers with proper labels
✓ All evidence references actual files
✓ All recommendations are actionable
✓ Markdown formatting is used consistently
✓ Monorepo metrics are included if applicable
✓ Overall score calculation is correct
✓ Report uses proper Markdown headings and formatting

Remember: This format ensures consistency, readability, and
professional presentation of Python project health audit results.
