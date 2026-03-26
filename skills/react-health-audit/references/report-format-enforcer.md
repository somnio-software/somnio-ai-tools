# React Health Audit Report Format Enforcer

> Enforce plain-text report format for the React Health Audit output. Ensures Google Docs-ready reports.

---

## FORMAT REQUIREMENTS

**CRITICAL**: The final health audit report MUST follow these rules:

1.  **NO MARKDOWN SYNTAX**:
    *   NO hash symbols for headers (# ## ###)
    *   NO asterisks for bold (**text**)
    *   NO code fences (``` blocks)
    *   NO bullet points with asterisks (* item)

2.  **USE PLAIN TEXT FORMATTING**:
    *   Section headers: Use "X. Section Name" format (numbered)
    *   Sub-headers: Use "Description:", "Score:", "Key Findings:", etc.
    *   Lists: Use "- " prefix for all bullet points
    *   Numbered lists: Use "1. ", "2. " format
    *   File paths: Bare text (no quotes needed for health audit)
    *   Scores: Always "[Score]/100 ([Label])"

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
    - Section 11 (Additional Metrics) uses flat bullet list format
    - Section 12 (Quality Index) repeats all scores then overall

6.  **TOTAL SECTIONS**: Report MUST have exactly 15 sections:
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
    11. Additional Metrics
    12. Quality Index
    13. Risks & Opportunities
    14. Recommendations
    15. Appendix: Evidence Index

## WEIGHTED SCORE CALCULATION

Overall Score = round(
  Tech Stack × 0.20 +
  Architecture × 0.20 +
  State Management × 0.15 +
  Testing × 0.15 +
  Code Quality × 0.15 +
  Performance × 0.10 +
  Documentation × 0.035 +
  CI/CD × 0.035
)

ROUNDING RULE: Use standard mathematical rounding (0.5 rounds up).
Do NOT apply subjective adjustments.

## VALIDATION CHECKLIST

Before finalizing the report, verify:
- All 15 sections are present
- All sections follow the required format
- All scores are integers with proper labels
- All evidence references actual files
- All recommendations are actionable
- No markdown syntax is used
- Overall score calculation is correct
- Report is ready for Google Docs copy-paste

ENFORCE THIS FORMAT FOR THE FINAL AUDIT REPORT.
