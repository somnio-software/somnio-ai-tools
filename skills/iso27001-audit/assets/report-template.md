# ISO/IEC 27001:2022 Readiness Report

---

## 1. ISO 27001 Readiness Scoring Breakdown

| Category | Annex A refs | Score |
|----------|--------------|-------|
| A. Governance & Program | A.5.1, A.5.2, A.5.4, A.5.7 | [Score]/100 ([Band]) |
| B. Human Resources Security | A.6.1-A.6.4, A.6.6, A.8.1, A.8.7 | [Score]/100 ([Band]) |
| C. Identity & Access Management | A.5.15-A.5.18, A.8.2, A.8.5 | [Score]/100 ([Band]) |
| D. Data Protection & Confidentiality | A.8.24, A.8.3, A.5.12-A.5.13, A.8.10, A.8.12 | [Score]/100 ([Band]) |
| E. Secure Development & Change Mgmt | A.8.25-A.8.28, A.8.31, A.8.32, A.8.9 | [Score]/100 ([Band]) |
| F. Infrastructure & Network Security | A.8.20-A.8.23, A.8.15, A.8.16, A.8.24 | [Score]/100 ([Band]) |
| G. Vulnerability Mgmt & Assurance | A.8.8, A.5.35-A.5.36 | [Score]/100 ([Band]) |
| H. Incident Management, BCP/DR | A.5.24-A.5.30, A.8.13 | [Score]/100 ([Band]) |
| I. Vendor / Third-Party Management | A.5.19-A.5.23 | [Score]/100 ([Band]) |
| J. AI Governance | A.5.1, A.8.29 (ISO/IEC 42001) | [Score]/100 ([Band]) or N/A |
| K. Evidence / ISMS Artifacts | Clauses 6, 9 | [Score]/100 ([Band]) |
| **Overall Readiness** | Weighted | **[Score]/100 ([Band])** |

**Readiness Band:** [Not Ready / Partially Ready / Largely Ready / Certification-Ready]

> **Bands:** Not Ready (0-40) - Partially Ready (41-70) - Largely Ready (71-85) - Certification-Ready (86-100)

> Readiness is weighted toward PLATFORM-AUDITABLE controls. ORGANIZATIONAL controls are scored on artifact presence; CLIENT-lane controls are listed but never penalize the score.

> This is a readiness / gap assessment, not an ISO/IEC 27001 certification.

---

## 2. Executive Summary

**Description:** ISO/IEC 27001:2022 readiness assessment of the [project type] project ([N] project type(s) detected).

**Overall Readiness Score:** [Score]/100 ([Band])

[If history exists:] **Previous:** [N]/100, **Change:** [+/-M] ([improving/declining/unchanged])

**Control Status Roll-up:** [X] Met - [X] Partial - [X] Gap - [X] Organizational (present/absent) - [X] Not Applicable

**Top Gaps:**
- [Gap 1 with Annex A ref and priority]
- [Gap 2 with Annex A ref and priority]
- [Gap 3 with Annex A ref and priority]

**Priority Actions:**
1. [Action 1]
2. [Action 2]
3. [Action 3]

---

> **Sections 3-13** are the 11 scored category sections, dynamically ordered by score ascending (lowest first). Not-Applicable categories go last.

---

## [N]. Category [Letter] - [Category Name]

**Annex A references:** [list]

**Score:** [Score]/100 ([Band])   _(or "Not Applicable - excluded from overall")_

**Score Breakdown:**
- In-scope controls: [count] (CLIENT-lane and N/A excluded)
- Sum(lane_weight * status_credit): [value] / denominator [value]
- **Final:** [Score]/100 ([Band])

### Control Status Roll-up

| Annex A ref | Control | Status | Owner/lane | Evidence |
|-------------|---------|--------|-----------|----------|
| [ref] | [name] | [Met/Partial/Gap/Organizational/N-A] | [PLATFORM-AUDITABLE/ORGANIZATIONAL/CLIENT] | `[path]` or No evidence found |

### Evidence
- `[File/config path]` (secret values REDACTED)

### Gaps
- [Gap] - Missing artifact that would satisfy it: [artifact]

### Risks
- [Risk]

### Recommendations
1. [Recommendation]

---

## 14. Annex A Gap Register

| Annex A ref | Evidence found | Gap | Remediation | Priority |
|-------------|----------------|-----|-------------|----------|
| [ref] | [evidence or None] | [gap statement] | [remediation] | [P1/P2/P3] |

---

## 15. Prioritized Remediation Plan

**Immediate (P1):**
- [Action] - satisfies [control(s)] - lane: [lane]

**Short-term (P2):**
- [Action] - satisfies [control(s)] - lane: [lane]

**Medium-term (P3):**
- [Action] - satisfies [control(s)] - lane: [lane]

---

## 16. Statement of Applicability (SoA) Starter

| Annex A ref | Control | Applicable? | Status | Owner/lane | Justification | Evidence |
|-------------|---------|-------------|--------|-----------|---------------|----------|
| [ref] | [name] | [Yes/No/TBD] | [Met/Partial/Gap/Organizational/N-A] | [lane] | [justification or "organization to confirm"] | `[path]` or No evidence found |

> Complete the Applicable? and Justification columns to turn this starter into a full SoA (ISO 27001 Clause 6.1.3 d).

---

## 17. ISMS Clause Coverage (Clauses 4-10)

| Clause | Expected artifact(s) | Present? | Evidence | Gap |
|--------|----------------------|----------|----------|-----|
| 4. Context & ISMS scope | Scope statement, interested parties | [Yes/No] | `[path]` | [gap] |
| 5. Leadership | Information security policy, roles, mgmt commitment | [Yes/No] | `[path]` | [gap] |
| 6. Planning | Risk assessment + treatment plan, SoA, objectives | [Yes/No] | `[path]` | [gap] |
| 7. Support | Competence/awareness, documented information control | [Yes/No] | `[path]` | [gap] |
| 8. Operation | Operational controls, operational risk assessments | [Yes/No] | `[path]` | [gap] |
| 9. Performance evaluation | Monitoring, internal audit, management review | [Yes/No] | `[path]` | [gap] |
| 10. Improvement | Nonconformity & corrective action, continual improvement | [Yes/No] | `[path]` | [gap] |

---

## 18. Project Detection Results

- **Detected project type(s):** [Type or "N types: X, Y, Z"]
- **Project paths:** [path per type]
- **Framework/runtime:** [version]
- **Package manager(s):** [manager]
- **Repository structure:** [single app / monorepo / multi-tech monorepo]
- **Evidence surfaces:** [IaC / CI / governance docs / config found]

---

## 19. Appendix: Evidence Index

**Governance / ISMS artifacts:**
- [path]

**Identity & Access:**
- [path]

**Data Protection & Cryptography:**
- [path]

**Secure Development & Change:**
- [path]

**Infrastructure & Network:**
- [path]

**Vulnerability & Assurance:**
- [path]

**Incident / BCP / DR:**
- [path]

**Vendor / Supplier / Cloud:**
- [path]

**AI Governance:**
- [path or "AI footprint: none"]

---

## 20. Scan Metadata

| Field | Value |
|-------|-------|
| Scan date | [Date] |
| Project path | [Path] |
| Project type | [Detected type] |
| Standard | ISO/IEC 27001:2022 (Annex A 93 controls, ISMS clauses 4-10) |
| Categories scored | 11 (A-K) |
| Overall readiness | [Score]/100 ([Band]) |
| Total gaps (Gap + Partial) | [Count] |
| Generated by | [Plugin Name] v[Plugin Version] |
| Skill | iso27001-audit |
| Disclaimer | Readiness / gap assessment, not a certification |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
