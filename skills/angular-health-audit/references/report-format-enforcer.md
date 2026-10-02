# Angular Health Audit Report Format Enforcer

> Enforce Markdown report format for the Angular Health Audit output. Ensures well-structured, readable reports.

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
    - Section 6 (Testing) MUST include, between Score and Key Findings,
      BOTH canonical coverage fields: `**Code Coverage:**` (with its
      multi-dimension / monorepo / no-tool fallback sub-lines) and
      `**Coverage Breakdown:**` (with its per-module bullets and
      single-package / no-data fallback lines) — see
      assets/report-template.md for the exact wording
    - Section 11 (AI Harness & Adoption) uses the richer shape: Description,
      Score, Maturity, `### Harness Coverage` table (or bullet list —
      never a bare `### Coverage`, which would collide with the Test/
      Code Coverage terminology), Key Findings, Evidence, Risks, Actions
      to Raise the Score (each with a `[+N]` delta and a
      `→ dimension D, X/Y → Y/Y` trace), Counts & Metrics
    - Section 12 (Additional Metrics) uses flat bullet list format and
      MUST NOT restate a coverage percentage in any form
    - Section 15 (Appendix: Evidence Index) is the last NUMBERED
      section; it is followed by two UNNUMBERED trailing blocks —
      Appendix: Scoring Methodology, then Report Metadata

6.  **TOTAL SECTIONS**: Report MUST have exactly 15 numbered sections
    (plus the two trailing unnumbered blocks above):
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

    There is no "Quality Index" section — it was removed. Do not emit
    one, and do not re-derive the old 16-section count anywhere.

## WEIGHTED SCORE CALCULATION

Weights are defined in `references/report-generator.md` — that file is
the single source of truth; do not restate the numbers here. Apply
them as:

Overall Score = round( Σ (section score × its weight from
references/report-generator.md) )

ROUNDING RULE: Use standard mathematical rounding (0.5 rounds up).
Do NOT apply subjective adjustments.

## VALIDATION CHECKLIST

Before finalizing the report, verify:
- All 15 numbered sections are present, in order, with no gaps or
  duplicates, and no "Quality Index" section
- The header carries BOTH the project-metadata block (Project / Date /
  Auditor / Framework) AND the Exclusions blockquote, in that order
- The `> **Test Coverage:**` line (with its fallback sub-line) appears
  directly under the At-a-Glance Scorecard table, immediately followed
  by the `> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)`
  blockquote and the one-sentence Overall Score interpretation
- The Testing section (Section 6) has the canonical `**Code Coverage:**`
  and `**Coverage Breakdown:**` fields between `**Score:**` and
  `### Key Findings`
- The AI Harness & Adoption section (Section 11) uses `### Harness
  Coverage`, never a bare `### Coverage`
- NO coverage percentage is restated anywhere in Counts & Metrics or in
  Additional Metrics (Section 12) — coverage appears exactly twice in
  the whole report: the Section 2 scorecard line and the Section 6
  Testing fields
- The `## Appendix: Scoring Methodology` block is present, unnumbered,
  between `## 15. Appendix: Evidence Index` and `## Report Metadata`
- WEIGHTS APPEAR ONLY in the Appendix: Scoring Methodology block —
  never as a column in the Section 2 scorecard table, and never
  restated inline in any numbered section
- All sections follow the required format
- All scores are integers with proper labels
- All evidence references actual files
- All recommendations are actionable
- Markdown formatting is used consistently
- Overall score calculation is correct
- Report uses proper Markdown headings and formatting

ENFORCE THIS FORMAT FOR THE FINAL AUDIT REPORT.
