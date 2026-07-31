# SOC 2 Readiness Report Format Enforcer

> Enforce Markdown formatting and structural rules on the SOC 2 Readiness report, ensuring consistent structure, valid scoring format, present ownership lanes, no leaked generator instructions, and no secret values. Read-only with respect to the audited repository.

---

Goal: Validate and enforce structure and Markdown formatting on the SOC 2
Readiness report before export.

STRUCTURAL VALIDATION (reject before formatting):
Before applying any formatting fixes, validate the report structure. If any
check FAILS, STOP and output an error message instead of the formatted report.

Required structure checks:
1. Report must contain exactly 19 numbered sections.
2. Section 1 must be "SOC 2 Readiness Scorecard" with 10 scored family lines
   (A-J) + Overall Score + Readiness Band + Formula.
3. Section 2 must be "Executive Summary" with the Overall Readiness Score.
4. Sections 3-12 must each contain a "Score:" line with [Score]/100 ([Band]).
5. Sections 3-12 must each contain a "Score Breakdown:" with Base 0 and Final.
6. Sections 3-12 must each contain a "Controls Assessed" block where every
   control shows a Status (met/partial/gap/organizational) and an Owner/lane
   (PLATFORM-AUDITABLE / ORGANIZATIONAL / CLIENT-CUEC).
7. Sections 3-12 must be ordered by score ascending (lowest first).
8. Section 13 (gaps table) must contain the columns: Control Ref, Family,
   Criterion, Evidence Found, Status, Owner/Lane, Gap, Remediation, Priority.
9. Section 14 (CUECs) and Section 15 (Evidence Artifacts & Trust Center
   Deliverables) must be present.
10. Scores in Section 1 must match the scores in their detail sections (3-12).

If ANY check fails, output:
  VALIDATION FAILED: [which check failed]
  The report generator must be re-run to include all mandatory scored
  sections before formatting can proceed.

Only proceed with formatting if ALL structural checks pass.

FORMATTING RULES TO ENFORCE:
- USE MARKDOWN SYNTAX: `#` headings, `**bold**`, `code`, tables, links.
- SECTION HEADERS: "## N. Section Name" (number + period).
- SCORE FORMAT: "[Score]/100 ([Band])" where Band is one of Not Ready,
  Partially Ready, Largely Ready, Audit-Ready.
- BAND-RANGE CHECK: Not Ready (0-40), Partially Ready (41-70), Largely Ready
  (71-85), Audit-Ready (86-100). Verify each band label matches its score.
- STATUS/LANE: every control lists a Status and an Owner/lane.
- PRIORITY: gaps use P1/P2/P3.
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
  "MANDATORY REPORT STRUCTURE", "REJECTION CRITERIA", rubric point values that
  are not tied to an actual evidence line).
- Remove any fabricated company/client/tenant/ticket names; the report must
  stay generic and evidence-bound.

VALIDATION CHECKLIST:
- All 19 sections present, in order
- Section 1: 10 scored family lines + Overall + Band + Formula
- Sections 3-12: Score + Score Breakdown + Controls Assessed (Status + Lane) +
  Gaps + Recommendations, ordered by score ascending
- Section 13 gaps table has all required columns incl. Owner/Lane + Priority
- Sections 14 (CUECs) and 15 (Deliverables) present
- Scores in Section 1 match their detail sections
- Band labels match score ranges
- No secret values (all redacted)
- No leaked generator instructions or fabricated identifiers
- Report starts with "SOC 2 Readiness Audit Report" title
- Report ends with "19. Scan Metadata" section

If formatting issues are found, fix them in-place and note what was corrected.

Output: The formatted Markdown report content ready for export to
./reports/soc2_audit.md

JSON EXPORT (mandatory):
After validating and exporting the text report to reports/soc2_audit.md,
ensure reports/soc2_audit.json exists and is well-formed with the schema
defined in references/report-generator.md. If the generator did not produce it,
extract the scores/gaps from the validated report and write it. Ensure the
reports/ directory exists.

SCORE HISTORY (mandatory after export):
After validating and exporting both reports/soc2_audit.md and
reports/soc2_audit.json, write reports/.history/last_scores.json with the same
score and gap data for future comparison (schema in report-generator.md).
Run: mkdir -p reports/.history
