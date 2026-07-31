# ISO 27001 Readiness Report Generator

> Synthesize all control-evidence artifacts and the scoring artifact into a comprehensive ISO/IEC 27001:2022 readiness report. MUST follow the section structure from assets/report-template.md. Every section is MANDATORY. The Statement of Applicability starter and the ISMS Clause Coverage section are first-class and must never be dropped. Scored category sections are dynamically ordered by score ascending (weakest first). Read-only; redact secret values.

---

Goal: Generate the final ISO 27001 Readiness Report by integrating all
analysis and scoring artifacts using the standardized structure in
`assets/report-template.md`.

PREREQUISITE: The 11 category scores and the weighted overall score MUST
already be computed and present in
`reports/.artifacts/step_13_iso27001_scoring.md`. If that artifact is missing
or lacks scores, STOP and (re-)run `references/scoring.md` first. A report
without computed scores is INVALID.

ARTIFACT INTEGRATION:
Read every step artifact under `reports/.artifacts/`:
- step_01_* project detection -> Project Detection Results section
- step_02_* .. step_12_* -> the 11 category sections, gap register, SoA rows
- step_12_* -> ISMS Clause Coverage section + SoA seeding
- step_13_* -> all category scores + overall score + band + status/lane
  roll-ups
If an expected artifact is absent, note it as missing and use the scoring
rejection behavior (category score 0 / Not Ready with the missing-artifact
note).

MANDATORY REPORT STRUCTURE (see assets/report-template.md):
1. ISO 27001 Readiness Scoring Breakdown (11 scored lines + Overall + Band)
2. Executive Summary (Overall Readiness Score + top gaps + priority actions)
3-13. Scored Category Sections (DYNAMIC ORDER - sorted by category_score
   ascending, lowest first; 11 sections A-K). A category marked Not Applicable
   is placed last and shown as "Not Applicable (excluded from overall)".
14. Annex A Gap Register
15. Prioritized Remediation Plan
16. Statement of Applicability (SoA) Starter
17. ISMS Clause Coverage (clauses 4-10)
18. Project Detection Results
19. Appendix: Evidence Index
20. Scan Metadata

DYNAMIC ORDERING INSTRUCTION:
After reading the scores from step_13, sort the 11 scored category sections by
score ascending. The lowest-scoring category is presented first so the reader
sees the weakest areas first. On tied scores, order by category weight
descending (heavier category first). Not-Applicable categories go last.

READINESS BAND MAPPING (per category and overall):
- 0-40 = Not Ready
- 41-70 = Partially Ready
- 71-85 = Largely Ready
- 86-100 = Certification-Ready

SECTION FORMAT REQUIREMENTS (each scored category section 3-13):
- Category letter + name (A-K) and the Annex A references it covers
- Score: [Score]/100 ([Band])  (or "Not Applicable")
- Score Breakdown: base, per-status contributions, final clamped score
  (traceable to step_13 computation trace)
- Control Status Roll-up: a table of the category's controls -
  Annex A ref | control name | Status (Met/Partial/Gap/Organizational/N-A) |
  Owner/lane (PLATFORM-AUDITABLE/ORGANIZATIONAL/CLIENT) | evidence (path) or
  "No evidence found"
- Evidence: concrete file/config paths (secret VALUES REDACTED)
- Gaps: for each Gap, the missing artifact that would satisfy the control
- Risks: what could go wrong if the gaps are not addressed
- Recommendations: numbered, prioritized actions

ANNEX A GAP REGISTER (section 14) - one row per Gap or Partial control across
ALL categories:
Annex A ref | evidence found | gap | remediation | priority (P1/P2/P3)
- Sort by priority then Annex A ref. Do not list Met or CLIENT-lane controls.

PRIORITIZED REMEDIATION PLAN (section 15):
Group the top actions by priority band:
- Immediate (P1): highest-impact platform-auditable gaps + missing mandatory
  ISMS artifacts (SoA, risk treatment plan)
- Short-term (P2)
- Medium-term (P3)
Each item: action, the control(s) it satisfies, the owning lane.

STATEMENT OF APPLICABILITY (SoA) STARTER (section 16) - FIRST-CLASS:
A starter SoA table the organization can complete:
Annex A ref | control name | applicable? (Yes/No/TBD) | status
(Met/Partial/Gap/Organizational/N-A) | owner/lane | justification | evidence
(path) or "No evidence found"
- Seed from step_12 SoA seeding plus every mapped control across the category
  artifacts. Mark controls with no repository footprint as
  "applicable? TBD" for the organization to confirm. Never invent
  justifications - use "No evidence found; organization to confirm".

ISMS CLAUSE COVERAGE (section 17) - FIRST-CLASS:
Reproduce the clause 4-10 table from step_12:
Clause | expected artifact(s) | present? (Yes/No) | evidence path | gap
Cover clauses 4 (context/scope), 5 (leadership/policy), 6 (planning/risk +
SoA), 7 (support/competence/documented info), 8 (operation), 9 (performance
evaluation/internal audit/management review), 10 (improvement/nonconformity).

STATUS + OWNER/LANE DISCIPLINE:
- Every control shown carries a Status AND an Owner/lane.
- CLIENT-lane controls are LISTED (in category sections and SoA) but NEVER
  counted against the score.
- ORGANIZATIONAL controls are reported as "policy/artifact present? yes/no".

READ-ONLY + SECRET SAFETY:
- Never modify repository files. If any evidence contains a secret VALUE,
  redact it as `[REDACTED]` - never reproduce it in the output.
- Do NOT include any company, client, product, or ticket name - keep the
  output generic.

FORMATTING RULES:
- Use Markdown: # headers, **bold**, `backtick` for paths, and Markdown
  tables for the scorecard, control roll-ups, gap register, SoA, and clause
  coverage.
- Priority always formatted consistently (P1/P2/P3).
- Scores always formatted as "[Score]/100 ([Band])".
- Output starts with the title "ISO/IEC 27001:2022 Readiness Report".

VALIDATION CHECKLIST (verify before finalizing):
- All 20 sections present in order
- Section 1 has 11 scored lines + Overall + Band
- All 11 category sections have a Score line (or "Not Applicable")
- Category sections ordered by score ascending (Not-Applicable last)
- Scores in Section 1 match the category detail sections and step_13
- Executive Summary includes the Overall Readiness Score + band
- Every control row has Status AND Owner/lane
- Annex A Gap Register present with remediation + priority per row
- SoA Starter present and first-class
- ISMS Clause Coverage present (clauses 4-10) and first-class
- No secret values; no company/client/ticket names
- Metadata block (from SKILL.md) appended at the very end

JSON EXPORT (mandatory):
After writing the output, write `reports/iso27001_audit.json`:
{
  "overallScore": [integer 0-100],
  "band": "[Not Ready|Partially Ready|Largely Ready|Certification-Ready]",
  "scores": {
    "A_governance": [0-100 or "N/A"],
    "B_humanResources": [0-100 or "N/A"],
    "C_identityAccess": [0-100 or "N/A"],
    "D_dataProtection": [0-100 or "N/A"],
    "E_secureDevelopment": [0-100 or "N/A"],
    "F_infrastructureNetwork": [0-100 or "N/A"],
    "G_vulnerabilityAssurance": [0-100 or "N/A"],
    "H_incidentBcpDr": [0-100 or "N/A"],
    "I_vendorSupplier": [0-100 or "N/A"],
    "J_aiGovernance": [0-100 or "N/A"],
    "K_ismsArtifacts": [0-100 or "N/A"]
  },
  "controlStatus": {
    "met": [int], "partial": [int], "gap": [int],
    "organizational": [int], "notApplicable": [int]
  },
  "annexAGaps": [integer count of Gap+Partial controls],
  "timestamp": "[ISO8601 datetime]",
  "projectType": "[detected type string]"
}
Run before saving: mkdir -p reports

SCORE HISTORY (mandatory after writing the output and JSON):
Write `reports/.history/last_iso27001_scores.json` with:
{ "overall": [overall], "band": "[band]", "timestamp": "[ISO8601]",
  "scores": { ...same keys as JSON export... },
  "controlStatus": { ... }, "projectType": "[string]" }
Run: mkdir -p reports/.history
