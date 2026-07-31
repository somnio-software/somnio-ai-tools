# SOC 2 Readiness Scoring

> Compute a 0-100 readiness score per control family using additive evidence rubrics weighted toward platform-auditable controls, compute the weighted overall readiness score, and map it to a readiness band. This is the single source of truth for weights, rubrics, and bands.

---

Goal: Convert the evidence artifacts into per-family scores (0-100), a weighted
overall readiness score, and a readiness band. You MUST compute all scores from
artifact evidence BEFORE any report content is written. A report without
computed scores is INVALID.

SCORING PRINCIPLES:
- Additive: each family starts at Base 0 and accrues points for evidence found.
- Weighted toward platform-auditable controls: platform-auditable evidence
  carries the bulk of each family's points.
- Organizational controls contribute only limited partial credit based on
  artifact PRESENCE (policy file exists in-repo). Award roughly half of an
  item's points for a thin/placeholder artifact.
- CLIENT/CUEC controls are NEVER scored and never penalize the platform score.
- Family K (Evidence Artifacts / Trust Center) is NOT scored; report it as
  deliverable targets only.
- Clamp every family score to 0-100.
- If an expected artifact is missing, assign that family score 0 with the note
  "Insufficient data from [missing artifact]" (see report-generator rejection
  criteria). Never omit a scored family.

FAMILY WEIGHTS (sum = 1.00; platform-auditable families weighted highest):
- A. Governance & Program: 0.08
- B. Human Resources Security: 0.04
- C. Identity & Access Management: 0.18
- D. Data Protection & Confidentiality: 0.16
- E. Secure Development & Change Management: 0.16
- F. Infrastructure & Network Security: 0.14
- G. Vulnerability Management & Assurance: 0.08
- H. Incident Management, BCP/DR: 0.08
- I. Vendor / Third-Party Management: 0.04
- J. AI Governance: 0.04

READINESS BANDS (map from a 0-100 score):
- 0-40 = Not Ready
- 41-70 = Partially Ready
- 71-85 = Largely Ready
- 86-100 = Audit-Ready

PER-FAMILY ADDITIVE RUBRICS (Base 0; add points for evidence; cap 100):

A. Governance & Program (ORGANIZATIONAL-heavy; artifact-presence):
- Information security policy set present: +25
- Security leadership / ownership defined (CODEOWNERS or named owner): +20
- Risk assessment / risk register documented: +20
- Exception/waiver process documented: +15
- Code of conduct present: +10
- Multiple compliance/policy docs under docs/compliance or docs/policies: +10

B. Human Resources Security (ORGANIZATIONAL/CUEC):
- Security-awareness training material/policy present: +35
- Confidentiality/NDA clause referenced: +25
- Workstation/device (MDM) controls documented: +25
- Onboarding/offboarding checklist present: +15
- Background-check control is CUEC — excluded from score.

C. Identity & Access Management (PLATFORM-AUDITABLE):
- Authentication implemented: +15
- Authorization/RBAC enforced: +15
- MFA present (esp. admins): +15
- SSO/OIDC/SAML: +10
- Password standards (hashing + complexity/lockout): +12
- Session management (timeout/expiry/revocation): +12
- Least-privilege IAM in IaC (no wildcard actions): +11
- Access review / revocation evidence (ORGANIZATIONAL, partial): +10

D. Data Protection & Confidentiality (PLATFORM-AUDITABLE):
- TLS 1.2+ enforced in transit: +20
- Encryption at rest (KMS/AES-256): +20
- Tenant/data segregation: +15
- Retention + secure disposal/purge: +12
- Encrypted backups: +12
- DLP / secret-leakage prevention: +11
- Data classification scheme (ORGANIZATIONAL, partial): +10

E. Secure Development & Change Management (PLATFORM-AUDITABLE):
- PR review / branch protection: +18
- CI test gate (blocking): +15
- Dependency scanning in pipeline: +15
- SAST in pipeline: +12
- Secret scanning in pipeline: +10
- Dev/test/prod separation: +10
- Migration discipline: +10
- Documented SDLC / patching SLA (ORGANIZATIONAL, partial): +10

F. Infrastructure & Network Security (PLATFORM-AUDITABLE):
- Network segmentation / private subnets: +18
- WAF present: +14
- Control-plane audit logging (e.g. CloudTrail): +16
- Flow / edge access logs: +10
- Log retention over 30 days: +10
- Monitoring with security-event alerting: +16
- Managed secrets store with rotation: +16
- (No plaintext secrets in repo is a gate: if plaintext secrets found, cap F at 60.)

G. Vulnerability Management & Assurance (mixed):
- Vulnerability scanning present (CI or scheduled): +40
- Production/scheduled scan cadence evidence: +25
- External pentest attestation present (ORGANIZATIONAL, partial): +20
- Evidence-sharing readiness (scan/pentest artifacts in repo): +15

H. Incident Management, BCP/DR (mixed):
- Incident-response plan present: +25
- Postmortem process documented: +12
- Breach-notification SLA documented: +13
- BCP/DR plan present: +20
- RPO/RTO targets defined: +10
- Redundancy / multi-AZ / failover (PLATFORM): +12
- Restore-drill evidence (ORGANIZATIONAL, partial): +8

I. Vendor / Third-Party Management (ORGANIZATIONAL):
- Vendor risk-review process documented: +35
- Subprocessor list maintained: +30
- Subcontractor flow-down clauses referenced: +20
- Disclosure of outsourced development: +15

J. AI Governance (ORGANIZATIONAL):
- AI usage policy present: +40
- Statement on training data + PII removal: +35
- Human review of AI outputs for accuracy/bias documented: +25

OVERALL SCORE FORMULA:
overall = round(
  A*0.08 + B*0.04 + C*0.18 + D*0.16 + E*0.16
  + F*0.14 + G*0.08 + H*0.08 + I*0.04 + J*0.04)

All family scores must be clamped to 0-100 before applying the formula. The
Overall Readiness Score in the Scorecard (Section 1) and the Executive Summary
(Section 2) MUST match.

COMPUTATION STEPS (execute before writing the report):
Step A - Extract evidence per family from the step artifacts:
  - A/B/J from step_02_soc2_governance_program.md
  - C from step_03_soc2_access_management.md
  - D from step_04_soc2_data_protection.md
  - E from step_05_soc2_change_management.md
  - F from step_06_soc2_infrastructure_network.md
  - G/I (and K deliverable targets) from step_07_soc2_vulnerability_assurance.md
  - H from step_08_soc2_incident_resilience.md
Step B - Apply each family rubric (Base 0, add evidence points, apply any cap,
  clamp 0-100). Show every addition so the score is traceable to evidence.
Step C - Compute overall via the weighted formula above; round to an integer.
Step D - Map each family score and the overall to a readiness band.
Step E - Verify all 11 scores (10 families + overall) are computed before
  proceeding to report generation.

SCORE COMPARISON (if history exists):
If reports/.history/last_scores.json exists, read the previous overall score and
timestamp. After computing the new overall, record the delta
(current - previous) for the Executive Summary:
"Previous: [N]/100, Change: [+/-M] ([improving|declining|unchanged])".

ARTIFACT SAVE (optional but recommended):
The computed scores may be written to reports/.artifacts/step_09_soc2_scoring.md
for traceability, or held in memory for the report generator. Either way, the
score breakdown per family MUST appear in the final report's scored sections.
