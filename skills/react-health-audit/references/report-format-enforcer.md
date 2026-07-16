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
    - Section 6 (Testing) MUST include "Code Coverage:" line after Score
    - Section 11 (AI Harness & Adoption) uses the richer shape: Description,
      Score, Maturity, Coverage table (or bullet list), Key Findings,
      Evidence, Risks, Actions to Raise the Score (each with a `[+N]`
      delta and a `→ dimension D, X/Y → Y/Y` trace), Counts & Metrics
    - Section 12 (Additional Metrics) uses flat bullet list format
    - Section 13 (Quality Index) repeats all scores then overall

6.  **TOTAL SECTIONS**: Report MUST have exactly 16 sections:
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
    13. Quality Index
    14. Risks & Opportunities
    15. Recommendations
    16. Appendix: Evidence Index

## WEIGHTED SCORE CALCULATION

Overall Score = round(
  Tech Stack × 0.18 +
  Architecture × 0.18 +
  State Management × 0.135 +
  Testing × 0.135 +
  Code Quality × 0.135 +
  Performance × 0.075 +
  Documentation × 0.03 +
  CI/CD × 0.03 +
  AI Harness & Adoption × 0.10
)

ROUNDING RULE: Use standard mathematical rounding (0.5 rounds up).
Do NOT apply subjective adjustments.

## VALIDATION CHECKLIST

Before finalizing the report, verify:
- All 16 sections are present
- All sections follow the required format
- All scores are integers with proper labels
- All evidence references actual files
- All recommendations are actionable
- Markdown formatting is used consistently
- Overall score calculation is correct
- Report uses proper Markdown headings and formatting

ENFORCE THIS FORMAT FOR THE FINAL AUDIT REPORT.
