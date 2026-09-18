# AngularJS Health Audit Report Format Enforcer

> Enforce Markdown report format for the AngularJS Health Audit output. Ensures well-structured, readable reports.

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
    *   File paths: `` `path/to/file.js` `` (backtick-wrapped)
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

5.  **HEADER REQUIREMENTS**:
    - The header carries BOTH blocks, in order: the project-metadata block
      (`**Project:**` / `**Date:**` / `**Auditor:**` / `**Framework:**`) AND
      the `> **Exclusions:**` blockquote directly below it, before the `---`.

6.  **SCORECARD REQUIREMENTS (Section 2)**:
    - Directly under the At-a-Glance Scorecard table, in this exact order:
      a `> **Test Coverage:** [X]% (lines) — full breakdown in the Testing
      section.` line with its "no coverage tool" fallback as a second line
      inside the same blockquote; the `> **Scoring:** Strong (85–100) · Fair
      (70–84) · Weak (0–69)` legend (en dash, middle dot); then the
      one-sentence Overall Score interpretation.
    - NEVER a bare "Coverage" label here — always "Test Coverage" (a bare
      "Coverage" collides with the AI Harness & Adoption rubric heading).
    - NEVER add a Weight column to this table — weights appear ONLY in the
      unnumbered Appendix: Scoring Methodology (see item 9 below), never as
      a column in the scorecard.

7.  **SPECIAL SECTIONS**:
    - Section 6 (Testing) MUST include, between Score and Key Findings, the
      canonical `**Code Coverage:**` block and `**Coverage Breakdown:**`
      list (see `references/report-generator.md` for the exact wording).
    - Section 8 (Performance) reflects digest-cycle/`$watch`/one-way-binding
      hygiene plus `ng-repeat track by` and template/DOM patterns
    - Section 11 (AI Harness & Adoption) uses the richer shape: Description,
      Score, Maturity, a `### Harness Coverage` table (never a bare
      `### Coverage` — that heading is reserved for this rubric table only,
      to avoid colliding with the scorecard's "Test Coverage" line), Key
      Findings, Evidence, Risks, Actions to Raise the Score (each with a
      `[+N]` delta and a `-> dimension D, X/Y -> Y/Y` trace), Counts &
      Metrics
    - Section 12 (Additional Metrics) uses flat bullet list format and MUST
      NOT restate any coverage percentage
    - Counts & Metrics in ANY section MUST NOT restate a coverage
      percentage either — coverage appears EXACTLY TWICE in the whole
      report: the Section 2 scorecard line and the Section 6 Testing
      fields. Nowhere else.

8.  **TOTAL SECTIONS**: Report MUST have exactly 15 numbered sections, plus
    two trailing unnumbered blocks:
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
    Then, unnumbered, in order:
    - Appendix: Scoring Methodology
    - Report Metadata
    There is no "Quality Index" section — do not emit one. It was removed;
    its one non-duplicate sentence was absorbed into Section 2 (item 6
    above).

9.  **APPENDIX: SCORING METHODOLOGY REQUIREMENT**:
    - Must be present, unnumbered, between Section 15 (Appendix: Evidence
      Index) and Report Metadata.
    - It is the ONLY report-facing surface where weights may appear.
    - Weights are defined in `references/report-generator.md` — that file
      is the single source of truth; do not restate the numbers here. Read
      them from there when validating this appendix's table.

## WEIGHTED SCORE CALCULATION

Overall Score = round( sum of each of the 9 scored sections' score ×
its weight )

Weights are defined in `references/report-generator.md` — that file is
the single source of truth; do not restate the numbers here.

ROUNDING RULE: Use standard mathematical rounding (0.5 rounds up).
Do NOT apply subjective adjustments.

## VALIDATION CHECKLIST

Before finalizing the report, verify:
- All 15 numbered sections are present, in order (no gaps, no
  duplicates, no "Quality Index"), plus both trailing unnumbered blocks
- The header has both the project-metadata block and the Exclusions
  blockquote
- The scorecard has the Test Coverage line, the Scoring legend, and the
  interpretation sentence directly below the table, and no Weight column
- Section 6 (Testing) has the Code Coverage / Coverage Breakdown fields
  between Score and Key Findings
- Section 11 (AI Harness & Adoption) uses `### Harness Coverage`, not
  `### Coverage`
- No coverage percentage is restated in Counts & Metrics or Additional
  Metrics — coverage appears exactly twice, total
- The Appendix: Scoring Methodology block is present, before Report
  Metadata, and is the only place weights appear
- All sections follow the required format
- All scores are integers with proper labels
- All evidence references actual files
- All recommendations are actionable
- Markdown formatting is used consistently
- Overall score calculation is correct
- Report uses proper Markdown headings and formatting

ENFORCE THIS FORMAT FOR THE FINAL AUDIT REPORT.
