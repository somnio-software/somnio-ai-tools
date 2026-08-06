# .NET Health Audit Report Format Enforcer

> Enforce Markdown report format for the .NET Health Audit output. Ensures well-structured, readable reports.

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
    *   File paths: `` `path/to/File.cs` `` (backtick-wrapped)
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
    - Section 7 (Testing) MUST include "Code Coverage:" line after Score
    - Section 11 (Additional Metrics) uses flat bullet list format
    - Section 12 (Quality Index) repeats all scores then overall

6.  **TOTAL SECTIONS**: Report MUST have exactly 15 sections:
    1. Executive Summary
    2. At-a-Glance Scorecard
    3. Tech Stack
    4. Architecture
    5. API Design
    6. Data Layer
    7. Testing
    8. Code Quality (Analyzers & Warnings)
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
  API Design × 0.20 +
  Data Layer × 0.11 +
  Testing × 0.11 +
  Code Quality × 0.11 +
  Documentation & Operations × 0.035 +
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
- Markdown formatting is used consistently
- Overall score calculation is correct
- Report uses proper Markdown headings and formatting

ENFORCE THIS FORMAT FOR THE FINAL AUDIT REPORT.
