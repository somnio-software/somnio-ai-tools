# Architecture Audit Report Format Enforcer

> Enforce Markdown formatting and structural rules on the Architecture Audit report: the 10-section structure, the profile line, contour scores whose earned and possible points produce the total, a band consistent with the total, complete rule and anti-pattern tables, and an evidence-bound remediation plan that fits the profile. Read-only with respect to the audited repository.

---

Goal: Validate and enforce structure and Markdown formatting on the
Architecture Audit report before export.

STRUCTURAL VALIDATION (reject before formatting):
Before applying any formatting fixes, validate the report structure. The
report-writer fixes what it can in place first; this runs on the result.
If any check still FAILS, STOP and output an error message instead of the
formatted report.

Required structure checks:
1. The report contains exactly 10 numbered sections.
2. Section 1 is "Architecture Scoring Breakdown" with a **Profile** line
   (effective and measured profile, drivers), one row each for
   Structural, Integration, Composition and Control
   (`[earned]/[possible]`), a **Total Score** row, a **Maturity Band**
   line, the band legend and the profile comparability sentence.
3. Section 2 is "Executive Summary", contains
   "**Total Score:** [total]/100 ([band])" and names the effective profile.
4. Section 3 is "Contour Detail" with one block per contour, in that order,
   each with a check table and Findings.
5. Section 4 is "Quality Criteria Reading" with a status for every row.
6. Section 5 is "Rule Compliance" with all ten rules R1-R10.
7. Section 6 is "Anti-pattern Findings" with all five anti-patterns AP1-AP5.
8. Sections 7 (Module Map) and 8 (Remediation Plan) are present; Section 8
   has at most eight actions, each naming modules or files and a stage,
   or one line saying nothing needs restoring.
9. Section 9 is `## 9. Appendix: Evidence Index`, immediately before Section
   10 (Report Metadata), with the groups Module map, Dependency graph,
   Composition, Control and Change locality - evidence or an explicit
   "Not found", never blank.
10. The Total in Section 1 matches Section 2 and the JSON export.

If ANY check fails, output:
  VALIDATION FAILED: [which check failed]
  The report generator must be re-run to include all mandatory sections and
  scores before formatting can proceed.

Only proceed with formatting if ALL structural checks pass.

FORMATTING RULES TO ENFORCE:
- USE MARKDOWN SYNTAX: `#` headings, `**bold**`, `code`, tables, links.
- SECTION HEADERS: "## N. Section Name" (number + period).
- SCORE FORMAT: per check `[awarded]/[max]`, `N/A`, or
  `0/[max] Not measured`; per contour `[earned]/[possible]`; total
  `[total]/100`.
- POINT ARITHMETIC: no check exceeds its maximum (S1 8, S2 6, S3 5, S4 6,
  I1 7, I2 6, I3 4, I4 4, I5 4, C1 8, C2 7, C3 5, C4 5, K1 5, K2 10, K3 5,
  K4 5). A contour's earned points are the sum of its scored and
  not-measured checks; its possible points are the sum of the maxima of
  its checks that are not N/A. Total = round(100 × Σ earned ÷ Σ possible),
  rounding halves up (62.5 → 63).
- N/A WHITELIST: an N/A check names its condition, and only these hold:
  S2 (fewer than four features); I1 (Compact profile with fewer than two
  features); I2 (fewer than three modules); I3 (Compact profile, or no
  allowed cross-module edges); I4 (no navigation between features, or
  fewer than two features); C3 (file-system routing, or a single route);
  K2 (no rule class is required: Compact profile with fewer than two
  features and fewer than three modules); K3 (no class rated enforced or
  partial has existing violations inside the modules its check covers); K4 (Compact profile). S1, S3, S4, I5, C1, C2, C4
  and K1 are never N/A. Reject an N/A whose condition is not on this list
  or names a profile other than the effective one.
- ENFORCEMENT CAPS: when K2 is 0 or Not measured, the Total is at most 64;
  when K2 is 3, 6 or N/A, at most 84, so Governed modular requires K2 =
  10. When a cap lowers the Total, the uncapped value and the cap's reason
  are shown beside it.
- BAND-RANGE CHECK: Monolithic (0-39), Partially modular (40-64), Modular
  (65-84), Governed modular (85-100). The band label matches the Total.
- STATUS VOCABULARY: metrics and criteria Healthy / Watch / Risk / N/A /
  Not measured; rules
  Met / Partial / Violated / Not applicable; anti-patterns Confirmed /
  Warning / Not found / Not applicable.
- ORDERING: Section 3 contours in fixed order; Section 8 actions in stage
  order.
- PROFILE FIT: Section 8 recommends physical feature modules only in the
  Large profile or for code a named module driver (D1, D2, D4, or D3
  delivered as build modules) concerns.
- EVIDENCE DISCIPLINE: every check cites a metric value or a file; no score
  without evidence.
- NO UNICODE ARTIFACTS that break rendering; keep tables well-formed.
- BLANK LINES: one blank line between sections; no triple+ blank lines.

SECRET REDACTION CHECK (mandatory):
- The steps read configuration and wiring files that may quote secret
  values. Scan the report for anything resembling a live secret: AWS access
  keys (AKIA...), private-key headers (-----BEGIN ... KEY-----), bearer
  tokens, `sk_live_`/`sk_test_`, API keys, connection strings with embedded
  passwords.
- If any is present, REDACT it in place (keep the location, replace the
  value with "[REDACTED]").

EXCLUSION / LEAK DETECTION:
- Remove generator-instruction text that leaked into the output (e.g.
  "MANDATORY REPORT STRUCTURE", "VALIDATION CHECKLIST", rubric thresholds
  not tied to an evidence line).
- Remove any fabricated company, client, product or ticket names; the report
  names only what the audited repository contains.

VALIDATION CHECKLIST:
- All 10 sections present, in order
- Section 1: profile line + four contour rows + Total + Maturity Band +
  legend + comparability sentence
- Section 2 states "**Total Score:** [total]/100 ([band])"
- Point arithmetic holds at check, contour and total level, N/A checks
  excluded from possible points, halves rounded up
- Every N/A is on the whitelist for the effective profile
- The enforcement caps are applied: 64 when K2 earns 0, 84 when K2 is
  3, 6 or N/A
- Band label matches the Total's range
- Sections 5 and 6 complete; Section 8 has at most eight staged actions, none padded
- Section 9 immediately before Section 10, all five groups filled
- No secret values (all redacted)
- No leaked generator instructions or fabricated identifiers
- Report starts with the "# Architecture Audit Report" title
- Report ends with "10. Report Metadata" followed by the metadata block

If formatting issues are found, fix them in-place and note what was
corrected.

Output: The formatted Markdown report content ready for export to
./reports/<YYYY-MM-DD>-<project>-architecture-audit.md

JSON EXPORT (mandatory):
After validating and exporting the text report to
reports/<YYYY-MM-DD>-<project>-architecture-audit.md, ensure
reports/<YYYY-MM-DD>-<project>-architecture-audit.json exists and is
well-formed with the schema defined in references/report-generator.md. If
the generator did not produce it, extract the scores, band, metrics,
anti-pattern verdicts and remediation actions from the validated report and
write it. Ensure the reports/ directory exists.

SCORE HISTORY (mandatory after export):
After validating and exporting both reports/<YYYY-MM-DD>-<project>-architecture-audit.md and
reports/<YYYY-MM-DD>-<project>-architecture-audit.json, write
reports/.history/last_architecture_scores.json with the same total, band,
profile, contour scores and metrics (schema in report-generator.md).
Run: mkdir -p reports/.history
