# ISO 27001 Readiness Report Format Enforcer

> Enforce Markdown formatting and structural rules on the ISO/IEC 27001:2022 Readiness report, ensuring consistent structure, valid scoring format, present Status + Owner/lane on every control, a first-class SoA starter and ISMS clause coverage, no leaked generator instructions, and no secret values. Read-only with respect to the audited repository.

---

Goal: Validate and enforce structure and Markdown formatting on the ISO 27001
Readiness report before export.

STRUCTURAL VALIDATION (reject before formatting):
Before applying any formatting fixes, validate the report structure. If any
check FAILS, STOP and output an error message instead of the formatted report.

Required structure checks:
1. Report must contain exactly 20 numbered sections.
2. Section 1 must be "ISO 27001 Readiness Scoring Breakdown" with 11 scored
   category lines (A-K) + Overall Score + Readiness Band.
3. Section 2 must be "Executive Summary" with the Overall Readiness Score and
   its band.
4. Sections 3-13 must each contain a "Score:" line with [Score]/100 ([Band]),
   or "Not Applicable".
5. Sections 3-13 must each contain a "Score Breakdown:" traceable to the
   step_13 computation (base, per-status contributions, final).
6. Sections 3-13 must each contain a Control Status Roll-up where every control
   row carries an Annex A ref, a Status (Met/Partial/Gap/Organizational/N-A)
   and an Owner/lane (PLATFORM-AUDITABLE / ORGANIZATIONAL / CLIENT).
7. Sections 3-13 must be ordered by score ascending (lowest first), with
   Not-Applicable categories last.
8. Section 14 (Annex A Gap Register) must contain the columns: Annex A ref,
   evidence found, gap, remediation, priority.
9. Section 15 (Prioritized Remediation Plan), Section 16 (Statement of
   Applicability starter) and Section 17 (ISMS Clause Coverage, clauses 4-10)
   must be present. The SoA starter and the clause coverage are first-class -
   a report missing either is INVALID.
10. Scores in Section 1 must match the scores in their detail sections (3-13).

If ANY check fails, output:
  VALIDATION FAILED: [which check failed]
  The report generator must be re-run to include all mandatory scored
  sections before formatting can proceed.

Only proceed with formatting if ALL structural checks pass.

FORMATTING RULES TO ENFORCE:
- USE MARKDOWN SYNTAX: `#` headings, `**bold**`, `code`, tables, links.
- SECTION HEADERS: "## N. Section Name" (number + period).
- SCORE FORMAT: "[Score]/100 ([Band])" where Band is one of Not Ready,
  Partially Ready, Largely Ready, Certification-Ready.
- BAND-RANGE CHECK: Not Ready (0-40), Partially Ready (41-70), Largely Ready
  (71-85), Certification-Ready (86-100). Verify each band label matches its
  score.
- STATUS/LANE: every control row lists a Status and an Owner/lane.
- CLIENT-lane controls are listed but never counted against a score - verify
  none of them contributed a deduction.
- PRIORITY: gaps use P1/P2/P3.
- SoA rows use applicable? Yes/No/TBD and never carry an invented
  justification; unknown controls read "No evidence found; organization to
  confirm".
- NO UNICODE ARTIFACTS that break rendering; keep tables well-formed.
- BLANK LINES: one blank line between sections; no triple+ blank lines.

SECRET REDACTION CHECK (mandatory):
- Scan the report for anything resembling a live secret value: AWS access keys
  (AKIA...), private-key headers (-----BEGIN ... KEY-----), bearer tokens,
  `sk_live_`/`sk_test_`, connection strings with embedded passwords.
- If any is present, REDACT it in place (keep the location, replace the value
  with "[REDACTED]"). The report must never contain a live secret value.

EXCLUSION / LEAK DETECTION:
- Remove any generator-instruction text that leaked into the output (e.g.
  "MANDATORY REPORT STRUCTURE", "DYNAMIC ORDERING INSTRUCTION", rubric point
  values that are not tied to an actual evidence line).
- Remove any fabricated company/client/tenant/ticket names; the report must
  stay generic and evidence-bound.

VALIDATION CHECKLIST:
- All 20 sections present, in order
- Section 1: 11 scored category lines + Overall + Band
- Sections 3-13: Score + Score Breakdown + Control Status Roll-up (Status +
  Owner/lane) + Evidence + Gaps + Risks + Recommendations, ordered by score
  ascending with Not-Applicable last
- Section 14 gap register has all required columns incl. remediation +
  priority
- Sections 15 (Remediation Plan), 16 (SoA starter) and 17 (ISMS Clause
  Coverage, clauses 4-10) present and complete
- Scores in Section 1 match their detail sections
- Band labels match score ranges
- No secret values (all redacted)
- No leaked generator instructions or fabricated identifiers
- Report starts with the "ISO/IEC 27001:2022 Readiness Report" title
- Report ends with "20. Scan Metadata" followed by the metadata block

If formatting issues are found, fix them in-place and note what was corrected.

Output: The formatted Markdown report content ready for export to
./reports/<YYYY-MM-DD>-<project>-iso27001-audit.md

JSON EXPORT (mandatory):
After validating and exporting the text report to reports/<YYYY-MM-DD>-<project>-iso27001-audit.md,
ensure reports/<YYYY-MM-DD>-<project>-iso27001-audit.json exists and is well-formed with the schema
defined in references/report-generator.md. If the generator did not produce it,
extract the scores/gaps from the validated report and write it. Ensure the
reports/ directory exists.

SCORE HISTORY (mandatory after export):
After validating and exporting both reports/<YYYY-MM-DD>-<project>-iso27001-audit.md and
reports/<YYYY-MM-DD>-<project>-iso27001-audit.json, write reports/.history/last_iso27001_scores.json
with the same score and control-status data for future comparison (schema in
report-generator.md).
Run: mkdir -p reports/.history
