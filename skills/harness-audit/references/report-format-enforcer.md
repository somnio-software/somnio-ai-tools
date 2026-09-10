# Harness Audit Report Format Enforcer

> Enforce Markdown formatting and structural rules on the AI Harness Audit report, ensuring the 7-section structure, a complete per-piece score table, a total that matches every place it appears, a band consistent with the total, and exactly three evidence-bound next steps. Read-only with respect to the audited repository.

---

Goal: Validate and enforce structure and Markdown formatting on the AI Harness
Audit report before export.

STRUCTURAL VALIDATION (reject before formatting):
Before applying any formatting fixes, validate the report structure. If any
check FAILS, STOP and output an error message instead of the formatted report.

Required structure checks:
1. Report must contain exactly 7 numbered sections.
2. Section 1 must be "Harness Scoring Breakdown" with one table row per harness
   piece (CLAUDE.md, Rules, Permissions, Commands / Skills, Hooks, Agents,
   Autotest -> PR), a **Total Score** row, a **Maturity Band** line, and the
   band legend.
3. Section 2 must be "Executive Summary" containing
   "Total Score: [total]/100 ([band])".
4. Section 3 must be "Harness Piece Detail" with one entry per rubric piece,
   each carrying Piece, Status (Present/Weak/Missing), Score `[awarded]/[max]`,
   Evidence, Why it matters, and Recommendation.
5. Section 4 must be "Top 3 Highest-Impact Next Steps" with exactly three
   ranked items, each naming an exact file to create or edit and the points it
   recovers.
6. Sections 5 (Maturity Band Reading), 6 (Harness Detection Results) and 7
   (Scan Metadata) must be present.
7. The Total in Section 1 must match the Total in Section 2, Section 5 and the
   JSON export.

If ANY check fails, output:
  VALIDATION FAILED: [which check failed]
  The report generator must be re-run to include all mandatory sections and
  scores before formatting can proceed.

Only proceed with formatting if ALL structural checks pass.

FORMATTING RULES TO ENFORCE:
- USE MARKDOWN SYNTAX: `#` headings, `**bold**`, `code`, tables, links.
- SECTION HEADERS: "## N. Section Name" (number + period).
- SCORE FORMAT: per piece `[awarded]/[max]`; total `[total]/100`.
- STATUS: every piece is exactly one of Present / Weak / Missing.
- BAND-RANGE CHECK: No harness (0-30), Basic harness (31-60), Solid harness
  (61-85), Paved path (86-100). Verify the band label matches the total.
- POINT ARITHMETIC: the per-piece scores in Section 1 must sum to the Total,
  and no piece may exceed its maximum (CLAUDE.md 20, Rules 10, Permissions 15,
  Commands / Skills 15, Hooks 20, Agents 10, Autotest -> PR 10).
- ORDERING: Section 3 entries are ordered by points recoverable descending
  (biggest gaps first).
- EVIDENCE DISCIPLINE: every Present piece cites a real path/line count from
  the inventory artifact; every Weak/Missing piece names the file that would
  fix it. No score is awarded without evidence.
- NO UNICODE ARTIFACTS that break rendering; keep tables well-formed.
- BLANK LINES: one blank line between sections; no triple+ blank lines.

SECRET REDACTION CHECK (mandatory):
- The inventory reads settings files that may quote secret values. Scan the
  report for anything resembling a live secret: AWS access keys (AKIA...),
  private-key headers (-----BEGIN ... KEY-----), bearer tokens,
  `sk_live_`/`sk_test_`, connection strings with embedded passwords.
- If any is present, REDACT it in place (keep the location, replace the value
  with "[REDACTED]"). The report must never contain a live secret value.

EXCLUSION / LEAK DETECTION:
- Remove any generator-instruction text that leaked into the output (e.g.
  "MANDATORY REPORT STRUCTURE", "VALIDATION CHECKLIST", rubric point values
  that are not tied to an actual evidence line).
- Remove any fabricated company/client/product/ticket names; the report must
  stay generic and evidence-bound.

VALIDATION CHECKLIST:
- All 7 sections present, in order
- Section 1: one row per harness piece + Total + Maturity Band + band legend
- Section 2 states "Total Score: [total]/100 ([band])"
- Section 3 covers every piece, ordered by points recoverable descending
- Section 4 lists exactly three next steps, each naming an exact file
- Sections 5, 6 and 7 present
- Per-piece scores sum to the Total; no piece over its maximum
- Band label matches the total's range
- No secret values (all redacted)
- No leaked generator instructions or fabricated identifiers
- Report starts with the "# AI Harness Audit Report" title
- Report ends with "7. Scan Metadata" followed by the metadata block

If formatting issues are found, fix them in-place and note what was corrected.

Output: The formatted Markdown report content ready for export to
./reports/<YYYY-MM-DD>-<project>-harness-audit.md

JSON EXPORT (mandatory):
After validating and exporting the text report to reports/<YYYY-MM-DD>-<project>-harness-audit.md,
ensure reports/<YYYY-MM-DD>-<project>-harness-audit.json exists and is well-formed with the schema
defined in references/report-generator.md. If the generator did not produce it,
extract the per-piece scores, band and top-3 next steps from the validated
report and write it. Ensure the reports/ directory exists.

SCORE HISTORY (mandatory after export):
After validating and exporting both reports/<YYYY-MM-DD>-<project>-harness-audit.md and
reports/<YYYY-MM-DD>-<project>-harness-audit.json, write reports/.history/last_scores.json with the
same total, band and per-piece data for future comparison (schema in
report-generator.md).
Run: mkdir -p reports/.history
