# React Health Audit Report Format Enforcer

> Enforce Markdown report format for the React Health Audit output. Ensures well-structured, readable reports.

---

## FORMAT REQUIREMENTS

**CRITICAL**: The final health audit report MUST follow these rules:

1.  **USE MARKDOWN FORMATTING**:
    *   `#` for main title, `##` for sections, `###` for subsections
    *   `**bold**` for scores, labels, and key terms
    *   Backticks for file paths and code references
    *   `- ` for bullet points

2.  **MARKDOWN STRUCTURE**:
    *   Section headers: `## X. Section Name` (numbered)
    *   Sub-headers: `### Key Findings`, `### Evidence`, `### Risks`, etc.
    *   Lists: `- ` prefix for all bullet points
    *   Numbered lists: `1. `, `2. ` format
    *   File paths: `` `path/to/file.ts` `` (backtick-wrapped)
    *   Scores: **[Score]/100 ([Label])**

3.  **MANDATORY SECTION FORMAT**:
    Each section must include in order:
    - Section number and name
    - Description (one sentence)
    - Score: [XX]/100 ([Label])
    - Key Findings (3-7 bullet points)
    - Evidence (file paths and configs)
    - Risks
    - Recommendations
    - Counts & Metrics

4.  **SCORING LABELS**:
    - Strong: 85-100
    - Fair: 70-84
    - Weak: 0-69

5.  **SPECIAL SECTIONS**:
    - Section 2 (At-a-Glance Scorecard) MUST be followed by the
      `> **Test Coverage:**` blockquote (with its no-tool fallback line
      inside the same blockquote), then the `> **Scoring:**` legend,
      then a one-sentence interpretation of the Overall Score. No
      Weight column on the scorecard table itself.
    - Section 6 (Testing) MUST include the `**Code Coverage:**` and
      `**Coverage Breakdown:**` fields between Score and Key Findings
    - Section 11 (AI Harness & Adoption) uses the richer shape: Description,
      Score, Maturity, `### Harness Coverage` table (not a bare
      `### Coverage` — that word is the Section 2 scorecard label),
      Key Findings, Evidence, Risks, Actions to Raise the Score (each
      with a `[+N]` delta and a `→ dimension D, X/Y → Y/Y` trace),
      Counts & Metrics
    - Section 12 (Additional Metrics) uses flat bullet list format;
      it must NOT restate any coverage percentage
    - There is no "Quality Index" section. Never emit one.

6.  **TOTAL SECTIONS**: Report MUST have exactly 15 numbered sections,
    followed by two unnumbered blocks:
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
    - `## Appendix: Scoring Methodology` (unnumbered)
    - `## Report Metadata` (unnumbered)

## WEIGHTED SCORE CALCULATION

Weights are defined in `references/report-generator.md` — that file is
the single source of truth; do not restate the numbers here.

Overall Score = round( Σ (section_score × weight) )

ROUNDING RULE: Use standard mathematical rounding (0.5 rounds up).
Do NOT apply subjective adjustments.

## VALIDATION CHECKLIST

Before finalizing the report, verify:
- Exactly 15 numbered `## N.` sections are present, 1 through 15, no
  gaps or duplicates, and no "Quality Index" heading anywhere
- The header carries both the project-metadata block (Project / Date /
  Auditor / Framework) AND the Exclusions blockquote
- The `> **Test Coverage:**` line appears directly under the
  At-a-Glance Scorecard table, with its no-coverage-tool fallback as a
  second line inside the same blockquote
- The Testing section carries the canonical `**Code Coverage:**` and
  `**Coverage Breakdown:**` fields between Score and Key Findings
- The AI Harness & Adoption section uses `### Harness Coverage`, never
  a bare `### Coverage`
- No coverage percentage is restated in Counts & Metrics or Additional
  Metrics anywhere in the report — coverage appears exactly twice: the
  Section 2 Test Coverage line and the Section 6 Testing fields
- The `## Appendix: Scoring Methodology` block is present, before
  `## Report Metadata`, with weights summing to 1.00
- Weights appear ONLY in the Appendix: Scoring Methodology — never as a
  column in the At-a-Glance Scorecard table or anywhere else
- All sections follow the required format
- All scores are integers with proper labels
- All evidence references actual files
- All recommendations are actionable
- Markdown formatting is used consistently
- Overall score calculation is correct
- Report uses proper Markdown headings and formatting

ENFORCE THIS FORMAT FOR THE FINAL AUDIT REPORT.
