# Next.js Security Report Format Enforcer

> Enforce Markdown formatting rules for the Next.js Security Audit report, ensuring consistent structure, valid scoring format, framework findings first, and no leaked generator instructions.

---

Goal: Validate and enforce Markdown formatting on the Next.js Security
Audit report before export.

STRUCTURAL VALIDATION (reject before formatting):

Before applying any formatting fixes, validate the report structure.
If any of these checks FAIL, STOP and output an error message instead
of the formatted report. Do NOT attempt to format an incomplete report.

Required structure checks:
1. Report must contain exactly 12 numbered sections
2. Section 1 must be "Security Scoring Breakdown": a `| Area | Score |`
   table with 5 area rows (Sensitive File & Env Protection, Secret
   Detection, Framework & Dependency Security, Supply Chain Integrity,
   Next.js App Security) + the `| **Overall Score** | **N/100 (Label)** |`
   row, followed by the `**Security Posture:**` line
3. Section 2 must be "Executive Summary" with Overall Score
4. Sections 3-7 must each contain "Score:" followed by
   [Score]/100 ([Label])
5. Sections 3-7 must each contain "Score Breakdown:" with
   Base and Final lines
6. Sections 3-7 must be ordered by score ascending (lowest first)
7. Scores in Section 1 must match the scores in their respective
   detail sections (3-7)
8. The Framework & Dependency Security section must contain the
   "Framework Version Status" table

If ANY check fails, output:
  VALIDATION FAILED: [which check failed]
  The report generator must be re-run to include all mandatory scored
  sections before formatting can proceed.

Only proceed with formatting if ALL structural checks pass.

FRAMEWORK FINDINGS ORDER (fix in place):
- If the step_03 artifact lists HIGH framework findings (`TOP_FINDINGS`),
  they must be the first items of the Executive Summary "Top Findings",
  the first items under "🔴 [HIGH]" in Section 8, and priority 1 (and
  following) in Section 9 — advisory findings before the EOL finding.
  Reorder if needed.
- Each must quote the advisory IDs and the patched version from the
  artifact. If a version or advisory ID in the report does not appear in
  any step artifact, remove it and write "Unknown" instead.

FORMATTING RULES TO ENFORCE:
- USE MARKDOWN SYNTAX: Ensure # headings, **bold**, *italic*,
  `code`, ```code blocks```, [links](url)
- SECTION HEADERS: Must use "## X. Section Name" Markdown format (number + period)
- BULLET POINTS: Must use "- " prefix (dash + space)
- NUMBERED LISTS: Must use "1. " format (number + period + space)
- SEVERITY TAGS: Must use the template's "**[HIGH]** —", "**[MEDIUM]** —" or "**[LOW]** —" prefix
- SCORE FORMAT: Must use "[Score]/100 ([Label])" where Label is one of
  Strong, Fair, Weak, or Critical
- ALLOWED NON-ASCII: Exactly the characters the template uses: en dash
  (–), middle dot (·), em dash (—), and the emoji 🔴 🟡 🟢. Replace
  fancy quotes, other dashes, other bullets and any other non-ASCII
  character with ASCII
- BOLD: Bold the field label only; never bold the numeric value after
  `**Score:**`
- NO EXTRA COLUMNS: No table may have a column beyond the template's.
  Never add Weight, Previous, Baseline, Change or Delta columns; trend
  data goes only in the Executive Summary `**Trend:**` line
- SECRETS: No secret value may appear; replace any with a redacted form
  (first 4 characters and `…`)
- BLANK LINES: One blank line between sections, no triple+ blank lines

SCORE VALIDATION:
- Section 1 (Security Scoring Breakdown) must be the `| Area | Score |`
  table (5 area rows + the Overall Score row) followed by Security
  Posture. Weights and the formula belong only in the unnumbered
  "## Appendix: Scoring Methodology", placed between
  "11. Appendix: Evidence Index" and "12. Report Metadata"
- Sections 3-7 must each contain a "Score:" line with format
  [Score]/100 ([Label])
- Valid labels by score range: 85-100 = Strong, 70-84 = Fair,
  50-69 = Weak, 0-49 = Critical
- Verify the label matches the score range
- Verify the Overall Score equals round(file_env*0.15 + secret_detection*0.20
  + framework_dependency*0.30 + supply_chain*0.15 + nextjs_app*0.20)
- Scores in Section 1 must match their respective detail sections (3-7)
- Executive Summary (Section 2) must include "Overall Score: [Score]/100 ([Label])" and one `**Trend:**` line (`Previous N/100, change +/-M (improving|declining|unchanged)` or `first run`)

EXCLUSION LEAK DETECTION:
- If the text "IMPORTANT EXCLUSIONS" appears in the report, remove it
  and any lines immediately following that are part of the exclusions
  block
- If "NEVER recommend CODEOWNERS", "NEVER recommend operational
  documentation" or "NEVER write a vulnerable or patched version" appears
  in the report, remove those lines
- These are generator instructions that must not appear in the output

VALIDATION CHECKLIST:
- All 12 report sections present
- Section order: 1. Security Scoring Breakdown,
  2. Executive Summary,
  3-7. Scored Detail Sections (dynamic order by score ascending),
  8. Consolidated Findings by Severity,
  9. Remediation Priority Matrix,
  10. Project Detection Results, 11. Appendix: Evidence Index,
  Appendix: Scoring Methodology (unnumbered), 12. Report Metadata
- Markdown formatting applied correctly throughout
- Severity classifications use correct format
- Framework HIGH findings first where required
- Score lines use correct format in sections 3-7
- Sections 3-7 ordered by score ascending (lowest first)
- Evidence references include file paths, advisory IDs and source URLs
- Recommendations are numbered and prioritized
- Report starts with "Next.js Security Audit Report" title
- Report ends with "12. Report Metadata" section, whose `Generated by` row
  is exactly as in the template
- No EXCLUSIONS block or generator instructions in output
- No duplicate score displays

If formatting issues are found, fix them in-place and note what
was corrected.

Output: The formatted Markdown report content ready for export to
./reports/<YYYY-MM-DD>-<project>-nextjs-security-audit.md

SCORE HISTORY (mandatory after export):
After validating and exporting reports/<YYYY-MM-DD>-<project>-nextjs-security-audit.md,
write reports/.history/last_nextjs_security_scores.json using the scores and
findings computed for this report, in the exact schema given in
references/report-generator.md's SCORE HISTORY block, for future score
comparison. Format:
{ "overall": N, "timestamp": "ISO8601", "scores": {...}, "findings": {...},
  "nextVersions": {...}, "projectType": "nextjs" }
Run: mkdir -p reports/.history
