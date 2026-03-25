# Security Report Format Enforcer

> Enforce plain-text formatting rules for the Security Audit report, ensuring Google Docs compatibility, consistent structure, valid scoring format, and no leaked generator instructions.

---

Goal: Validate and enforce plain-text formatting on the Security Audit
report before export.

STRUCTURAL VALIDATION (reject before formatting):

Before applying any formatting fixes, validate the report structure.
If any of these checks FAIL, STOP and output an error message instead
of the formatted report. Do NOT attempt to format an incomplete report.

Required structure checks:
1. Report must contain exactly 13 numbered sections
2. Section 1 must be "Security Scoring Breakdown" with 5 scored lines
   (each with weight) + Overall Score + Formula + Security Posture
3. Section 2 must be "Executive Summary" with Overall Score
4. Sections 3-7 must each contain "Score:" followed by
   [Score]/100 ([Label])
5. Sections 3-7 must each contain "Score Breakdown:" with
   Base and Final lines
6. Sections 3-7 must be ordered by score ascending (lowest first)
7. Scores in Section 1 must match the scores in their respective
   detail sections (3-7)

If ANY check fails, output:
  VALIDATION FAILED: [which check failed]
  The report generator must be re-run to include all mandatory scored
  sections before formatting can proceed.

Only proceed with formatting if ALL structural checks pass.

FORMATTING RULES TO ENFORCE:
- NO MARKDOWN SYNTAX: Remove any # headings, **bold**, *italic*,
  `code`, ```code blocks```, [links](url)
- SECTION HEADERS: Must use "X. Section Name" format (number + period)
- BULLET POINTS: Must use "- " prefix (dash + space)
- NUMBERED LISTS: Must use "1. " format (number + period + space)
- SEVERITY TAGS: Must use "[HIGH]:", "[MEDIUM]:", or "[LOW]:" prefix
- SCORE FORMAT: Must use "[Score]/100 ([Label])" where Label is one of
  Strong, Fair, Weak, or Critical
- NO UNICODE: Replace fancy quotes, dashes, and bullets with ASCII
- LINE LENGTH: No hard wrapping requirement, but ensure readability
- BLANK LINES: One blank line between sections, no triple+ blank lines

SCORE VALIDATION:
- Section 1 (Security Scoring Breakdown) must have 5 scored lines
  with weights + Overall Score + Formula + Security Posture
- Sections 3-7 must each contain a "Score:" line with format
  [Score]/100 ([Label])
- Valid labels by score range: 85-100 = Strong, 70-84 = Fair,
  50-69 = Weak, 0-49 = Critical
- Verify the label matches the score range
- Scores in Section 1 must match their respective detail sections (3-7)
- Executive Summary (Section 2) must include "Overall Score: [Score]/100 ([Label])"

EXCLUSION LEAK DETECTION:
- If the text "IMPORTANT EXCLUSIONS" appears in the report, remove it
  and any lines immediately following that are part of the exclusions
  block
- If "NEVER recommend CODEOWNERS" or "NEVER recommend operational
  documentation" appears in the report, remove those lines
- These are generator instructions that must not appear in the output

VALIDATION CHECKLIST:
- All 13 report sections present
- Section order: 1. Security Scoring Breakdown,
  2. Executive Summary,
  3-7. Scored Detail Sections (dynamic order by score ascending),
  8. Consolidated Findings by Severity,
  9. Remediation Priority Matrix, 10. Gemini AI Analysis,
  11. Project Detection Results, 12. Appendix: Evidence Index,
  13. Scan Metadata
- No markdown artifacts in final output
- Severity classifications use correct format
- Section 1 has 5 scored lines with weights + Overall + Formula + Posture
- Score lines use correct format in sections 3-7
- Sections 3-7 ordered by score ascending (lowest first)
- Scores in Section 1 match their respective detail sections (3-7)
- Evidence references include file paths
- Recommendations are numbered and prioritized
- Report starts with "Security Audit Report" title
- Report ends with "13. Scan Metadata" section
- No EXCLUSIONS block or generator instructions in output
- No duplicate score displays

If formatting issues are found, fix them in-place and note what
was corrected.

Output: The formatted report content ready for export to
./reports/security_audit.txt

JSON EXPORT (mandatory):
After validating and exporting the text report to reports/security_audit.txt,
extract the scores and findings from the validated report and write a valid
JSON file to reports/security_audit.json with this schema:

{
  "overallScore": [integer 0-100],
  "posture": "[Secure|Needs Attention|At Risk|Critical]",
  "scores": {
    "sensitiveFile": [0-100],
    "secretDetection": [0-100],
    "dependencySecurity": [0-100],
    "supplyChainIntegrity": [0-100],
    "securityAutomation": [0-100]
  },
  "findings": {
    "high": [integer],
    "medium": [integer],
    "low": [integer]
  },
  "timestamp": "[ISO8601 datetime, e.g. 2025-02-26T12:00:00Z]",
  "projectType": "[string from Section 11 Project Detection Results]"
}

If the report generator already produced reports/security_audit.json, validate
that the JSON is well-formed (valid syntax, required keys present). If invalid,
regenerate from the text report. Ensure reports/ directory exists.

SCORE HISTORY (mandatory after export):
After validating and exporting both reports/security_audit.txt and
reports/security_audit.json, write reports/.history/last_scores.json with
the same score and findings data for future score comparison. Format:
{ "overall": N, "timestamp": "ISO8601", "scores": {...}, "findings": {...},
  "projectType": "..." }
Run: mkdir -p reports/.history
