# SOC 2 Readiness Report Generator

> Synthesize all SOC 2 evidence and the computed scores into a comprehensive readiness report with a per-family scorecard, a gaps table mapped to criteria references and ownership lanes, a CUEC list, the deliverables the organization must author, and a prioritized remediation roadmap. MUST follow the exact 19-section structure from assets/report-template.md. Every section is MANDATORY. Scored detail sections (3-12) MUST be dynamically ordered by score ascending. Read-only; secret values redacted.

---

Goal: Generate the final SOC 2 Readiness report by integrating all evidence
artifacts and the scores computed via references/scoring.md, using the
standardized structure from assets/report-template.md.

STEP ARTIFACT INTEGRATION:
Read ALL step artifacts under the run's artifacts directory
(reports/.artifacts/ for in-session subagent dispatch;
reports/.artifacts/soc2_audit/ for `somnio run`). Match each artifact by its
step-number prefix:
- step_01_* (project/tooling detection; PROJECT_DETECTION_RESULTS; Project Detection section)
- step_02_* (families A/B/J governance, HR, AI evidence)
- step_03_* (family C access management)
- step_04_* (family D data protection)
- step_05_* (family E secure development / change management)
- step_06_* (family F infrastructure & network)
- step_07_* (families G/I evidence + family K deliverable targets)
- step_08_* (family H incident management / BCP-DR)
- step_09_* (scoring, if written; otherwise recompute from scoring.md)

If an expected step_NN_* artifact is absent, note it as missing rather than
searching other directories, and apply the rejection criteria below.

SCORING (authoritative source: references/scoring.md):
Reproduce the family weights, additive rubrics, overall formula, and readiness
bands exactly from references/scoring.md. Compute all 10 family scores and the
overall BEFORE writing any report content.

Weights: A 0.08, B 0.04, C 0.18, D 0.16, E 0.16, F 0.14, G 0.08, H 0.08,
I 0.04, J 0.04.
Overall = round(A*0.08 + B*0.04 + C*0.18 + D*0.16 + E*0.16 + F*0.14 + G*0.08
          + H*0.08 + I*0.04 + J*0.04).
Bands: Not Ready (0-40), Partially Ready (41-70), Largely Ready (71-85),
Audit-Ready (86-100).

MANDATORY REPORT STRUCTURE (19 sections):
1. SOC 2 Readiness Scorecard (10 scored family lines + Overall + Band)
2. Executive Summary (Overall Readiness Score + top gaps + priority recommendations)
3-12. Scored Detail Sections (DYNAMIC ORDER — sorted by score ascending, lowest first):
   - A. Governance & Program
   - B. Human Resources Security
   - C. Identity & Access Management
   - D. Data Protection & Confidentiality
   - E. Secure Development & Change Management
   - F. Infrastructure & Network Security
   - G. Vulnerability Management & Assurance
   - H. Incident Management, BCP/DR
   - I. Vendor / Third-Party Management
   - J. AI Governance
13. Trust Services Criteria Gaps & Coverage (gaps table)
14. Complementary User-Entity Controls (CUECs)
15. Evidence Artifacts & Trust Center Deliverables (family K)
16. Remediation Roadmap
17. Project Detection Results
18. Appendix: Evidence Index
19. Scan Metadata

DYNAMIC ORDERING INSTRUCTION:
After computing all 10 family scores, sort the scored detail sections (3-12) by
score ascending. The family with the LOWEST score is Section 3; the highest is
Section 12. This surfaces the weakest families first. Tiebreaker order when
scores are equal (weakest platform-auditable first): C, D, E, F, A, G, H, B,
I, J.

OWNERSHIP LANE HANDLING:
- Each control in every scored section MUST display its Owner/lane:
  PLATFORM-AUDITABLE, ORGANIZATIONAL, or CLIENT-CUEC.
- Score weighting favors platform-auditable evidence (per references/scoring.md).
- Organizational controls report "policy artifact present? yes/no" and earn
  only limited partial credit.
- CUEC controls are excluded from scoring and are listed in Section 14; NEVER
  let a CUEC reduce a family score.

SECTION FORMAT REQUIREMENTS (scored sections 3-12):
Each scored section MUST follow this format:
- Family header: "[N]. [Letter]. [Family Name]" with the mapped criteria refs
- Description: Brief explanation of what this family evaluates
- Score: [Score]/100 ([Band])
- Score Breakdown: Base 0, each evidence addition with its value, any cap
  applied, and the final clamped score. Example:
    Base: 0
    + Authentication implemented: +15
    + Authorization/RBAC enforced: +15
    + MFA present: +15
    Final: 45/100 (Partially Ready)
- Controls Assessed: bullet list; each item shows control ref, criterion,
  Status (met/partial/gap/organizational), Owner/lane, and Evidence (path)
- Gaps: bullet list of gaps with the exact evidence that would satisfy each
- Recommendations: numbered, prioritized actions to improve

GAPS TABLE (Section 13) — required columns:
| Control Ref | Family | Criterion | Evidence Found | Status | Owner/Lane | Gap | Remediation | Priority |
- Priority: P1 (critical / blocks audit), P2 (important), P3 (best-effort).
- One row per material control across all families. Redact any secret values.

CUEC SECTION (Section 14):
List every control marked CLIENT-CUEC (e.g. background checks, customer-side
account hygiene). State they are the responsibility of the user entity and are
out of scope for the platform readiness score.

DELIVERABLES SECTION (Section 15 — family K):
List the deliverables the organization must author/publish, with present? (yes/no):
1. SOC 2 report (Type I then Type II)
2. Security questionnaire (SIG / CAIQ) response
3. Penetration-test attestation / summary
4. Subprocessor list (public, versioned)
5. Public status page + trust center (with the security policy set)

REMEDIATION ROADMAP (Section 16):
Group prioritized actions into phases:
- Phase 1 — Immediate (P1, platform-auditable gaps that block audit)
- Phase 2 — Short-term (P2, within ~30-60 days)
- Phase 3 — Program build-out (P3 + organizational policy authoring + deliverables)

REJECTION CRITERIA:
If a family score cannot be computed due to a missing artifact, assign score 0
and note "Score: 0/100 (Not Ready) - Insufficient data from [missing artifact]".
Never omit a scored family.

FORMATTING RULES:
- USE MARKDOWN SYNTAX: `#` headers, `**bold**`, `backtick` paths, tables for
  the scorecard and gaps table.
- SECTION HEADERS: "## N. Section Name" format.
- STATUS/LANE: display consistently, e.g. "Status: gap · Lane: PLATFORM-AUDITABLE".
- SCORES: always "[Score]/100 ([Band])" where Band is Not Ready / Partially
  Ready / Largely Ready / Audit-Ready.
- REDACTION: never print a secret value; show location + "[REDACTED]".
- Output starts with the title "SOC 2 Readiness Audit Report".

VALIDATION CHECKLIST (before finalizing):
- All 19 sections present
- Section 1 has 10 scored family lines + Overall + Band + Formula
- Scored sections (3-12) each have Score line + Score Breakdown + Controls
  Assessed (with Status + Owner/lane) + Gaps + Recommendations
- Scored sections ordered by score ascending
- Scores in Section 1 match their detail sections
- Gaps table (Section 13) has all required columns including Owner/Lane and Priority
- CUEC section (14) and Deliverables section (15) present
- Band label matches the Overall Score range
- No secret values anywhere (redacted)
- No fabricated company/client/ticket names

JSON EXPORT (mandatory):
After writing the readiness output, write reports/soc2_audit.json:
{
  "overallScore": [integer 0-100],
  "band": "[Not Ready|Partially Ready|Largely Ready|Audit-Ready]",
  "scores": {
    "A_governance": [0-100],
    "B_humanResources": [0-100],
    "C_accessManagement": [0-100],
    "D_dataProtection": [0-100],
    "E_changeManagement": [0-100],
    "F_infrastructure": [0-100],
    "G_vulnerabilityAssurance": [0-100],
    "H_incidentResilience": [0-100],
    "I_vendorManagement": [0-100],
    "J_aiGovernance": [0-100]
  },
  "gaps": { "p1": [integer], "p2": [integer], "p3": [integer] },
  "deliverablesPresent": [integer 0-5],
  "timestamp": "[ISO8601 datetime]",
  "projectType": "[detected type string]"
}
Run before saving: mkdir -p reports

SCORE HISTORY (mandatory after output + JSON):
Write reports/.history/last_scores.json with:
{ "overall": [current overall], "band": "[band]", "timestamp": "[ISO8601]",
  "scores": { "A_governance": N, "B_humanResources": N, "C_accessManagement": N,
    "D_dataProtection": N, "E_changeManagement": N, "F_infrastructure": N,
    "G_vulnerabilityAssurance": N, "H_incidentResilience": N,
    "I_vendorManagement": N, "J_aiGovernance": N },
  "gaps": { "p1": N, "p2": N, "p3": N },
  "projectType": "[string]" }
Run: mkdir -p reports/.history
