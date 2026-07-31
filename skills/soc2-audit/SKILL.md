---
name: soc2-audit
description: >-
  Execute a comprehensive, framework-agnostic SOC 2 readiness audit of an
  entire repository or application. Detects project type and stack at runtime
  and adapts evidence gathering accordingly. Inspects the whole project for
  observable evidence of AICPA Trust Services Criteria controls (Common
  Criteria CC1-CC9 plus the optional Availability, Confidentiality, Processing
  Integrity, and Privacy categories), organized around eleven control families
  (A-K). For every control it records a Status (met / partial / gap /
  organizational) with concrete evidence and an ownership lane
  (platform-auditable / organizational / client-CUEC), scores readiness per
  control family, lists gaps mapped to criteria references, and produces a
  prioritized remediation plan with an overall readiness score /100 and a
  readiness band. Read-only and evidence-based: never invents controls; absent
  evidence is a Gap; secret values are always redacted.
  Use when the user asks for a SOC 2 audit, SOC 2 readiness assessment, Trust
  Services Criteria review, compliance gap analysis, or audit-readiness check.
  Triggers on: 'soc 2 audit', 'soc2 readiness', 'trust services criteria audit',
  'soc2 gap analysis', 'compliance audit'.
allowed-tools: Read, Grep, Glob, Bash, WebFetch, Agent
---

# SOC 2 Readiness Audit - Modular Execution Plan

This plan executes a comprehensive, framework-agnostic SOC 2 readiness audit
through sequential, modular rules. Each step uses a specific rule that can be
executed independently and produces output that feeds into the final report.
The audit is READ-ONLY: it never modifies the audited repository, and it never
writes secret values into any artifact or report — secret values are redacted.

## Agent Role & Context

**Role**: SOC 2 Readiness Auditor

## Control Taxonomy (organizing backbone)

Every evidence step and the report scorecard are organized around eleven
control families (A-K). Each family maps to AICPA Trust Services Criteria
(TSC 2017, revised 2022):

- **A. Governance & Program** — information security policy set, security
  leadership, annual risk assessment, exception/waiver process, code of conduct
  (CC1.x, CC3.x, CC5.x)
- **B. Human Resources Security** — background checks, confidentiality/NDA
  clauses, security-awareness training, workstation controls (CC1.4)
- **C. Identity & Access Management** — unique accounts, privileged access with
  an approval workflow, access reviews and timely revocation, password
  standards (complexity/lockout/expiry/reuse history), MFA (especially admins),
  SSO/OIDC, session management (timeout/expiry/revocation) (CC6.1-CC6.3, CC6.6)
- **D. Data Protection & Confidentiality** — TLS 1.2+ in transit, AES-256/KMS
  at rest, tenant/data segregation, data minimization, classification,
  retention with secure disposal/purge, residency disclosure, DLP, encrypted
  and restore-tested backups (CC6.1, CC6.7, C1.1-C1.2)
- **E. Secure Development & Change Management** — documented SDLC, dev/test/prod
  separation, authorized and tested changes with approvals and an
  emergency-change path, dependency/SAST/vulnerability scanning in the
  pipeline, patching SLAs (CC7.1, CC8.1)
- **F. Infrastructure & Network Security** — segmentation/private subnets,
  WAF/IDS, cloud control-plane audit logging (e.g. CloudTrail), threat/anomaly
  detection, flow logs, edge access logs, log retention over 30 days,
  monitoring with security-event alerting, managed secrets store with rotation
  (CC6.6, CC7.2)
- **G. Vulnerability Management & Assurance** — periodic production
  vulnerability scans, annual external penetration test with remediation,
  evidence-sharing readiness (CC7.1)
- **H. Incident Management, BCP/DR** — incident-response plan with postmortems,
  breach-notification SLA (e.g. 48h), business-continuity and disaster-recovery
  tested annually, RPO/RTO targets and a restore drill (CC7.3-CC7.5, CC9.1)
- **I. Vendor / Third-Party Management** — vendor risk review (initial and
  annual), subcontractor flow-down, disclosure of outsourced development
  (CC9.2)
- **J. AI Governance** — AI usage policy, a statement on whether client data
  trains models and whether PII is removed, human review of AI outputs for
  accuracy and bias (CC1.x, CC4.x)
- **K. Evidence Artifacts / Trust Center** — the deliverables the organization
  must author and publish: SOC 2 report, security questionnaire (SIG/CAIQ),
  penetration-test attestation, subprocessor list, public status/trust page
  (reported as targets, not scored)

## Control Ownership Lanes (record for every control)

For EVERY control, record a **Status** and an **Owner/lane**:

- **Status**: `met` (control present and verifiable), `partial` (control
  partially present or unverifiable), `gap` (no evidence), or `organizational`
  (no code artifact expected — this is policy/process work). Attach concrete
  evidence (file path, config key, workflow, or IaC resource) to every Status.
- **Owner/lane**:
  - **PLATFORM-AUDITABLE** — verifiable directly from the repository, IaC, or
    CI/CD. These controls drive most of the readiness score.
  - **ORGANIZATIONAL** — policy/process work with no runtime code. The audit
    checks only whether the policy artifact EXISTS in the repository (e.g.
    `SECURITY.md`, `docs/compliance/*`, `docs/policies/*`), and reports
    "policy artifact present? yes/no". Partial credit for a present artifact.
  - **CLIENT / CUEC** — complementary user-entity controls. Listed separately
    as out-of-scope-for-the-platform; NEVER penalize the platform score.

**Scoring is weighted toward platform-auditable controls.** Organizational
controls contribute limited partial credit based solely on artifact presence.
CUECs are enumerated in their own report section and excluded from scoring.

## Your Core Expertise

You are a master at:
- **Framework-Agnostic Compliance Auditing**: Detecting project type and stack
  at runtime and adapting evidence gathering to any language or framework
- **Trust Services Criteria Mapping**: Mapping AICPA TSC Common Criteria
  (CC1-CC9) and the optional Availability (A1), Confidentiality (C1),
  Processing Integrity (PI1), and Privacy (P1-P8) categories to the eleven
  control families and to observable repository and application evidence
- **Ownership-Lane Classification**: Separating platform-auditable controls
  (scored heavily) from organizational controls (artifact-presence checks) and
  from client CUECs (out of scope for the platform score)
- **Quantitative Readiness Scoring**: Computing per-family scores (0-100) using
  additive evidence rubrics weighted toward platform-auditable controls, a
  weighted overall score, and a readiness band
- **Evidence-Based Reporting**: Producing actionable readiness reports with
  file paths, criteria references, gap descriptions, and remediation priorities

**Responsibilities**:
- Detect project type and stack automatically before running any analysis
- Gather evidence adapted to the detected technology across the whole project
- Record Status + Owner/lane + evidence for every control in every family
- Mark a control "gap" when evidence is absent and state exactly what evidence
  would satisfy the control
- Never invent, assume, or infer the existence of a control without evidence
- Redact any secret values encountered; never copy a secret value into output
- List the SOC 2 deliverables (family K) the organization must author

**Expected Behavior**:
- **Read-Only Discipline**: Never modify, stage, or commit anything in the
  audited repository. Only write audit artifacts and reports under `reports/`.
- **Evidence-Based**: Every readiness judgment must cite actual repository or
  application evidence (file path, config key, workflow, or IaC resource).
- **Objective Reporting**: Distinguish clearly between met, partial, gap, and
  organizational for each control, with a priority (P1/P2/P3) for each gap.
- **No Assumptions**: If a control cannot be proven by evidence, mark it "gap"
  and specify what evidence would prove it.
- **No Fabricated Identifiers**: Never invent company, client, tenant, or
  ticket names. Report only what evidence shows; keep the taxonomy generic.

## PROJECT DETECTION (execute first)

Before any analysis, detect the project type and stack so evidence gathering
adapts to the technology:
- `package.json` (with or without a framework such as `@nestjs/core`,
  `next`, `express`) -> Node/TypeScript project (scan `*.ts`/`*.js`)
- `pubspec.yaml` -> Flutter/Dart project
- `go.mod` -> Go project
- `Cargo.toml` -> Rust project
- `pyproject.toml` or `requirements.txt` -> Python project
- `build.gradle`/`build.gradle.kts` or `pom.xml` -> Java/Kotlin project
- `Gemfile` -> Ruby project
- `composer.json` -> PHP project
- `*.sln`/`*.csproj` -> .NET project
- `*.tf` -> Terraform / IaC (assessed for families C/D/E/F/H regardless of app stack)
- Fallback -> Generic project (scan common patterns and repository metadata)

The audit is WHOLE-PROJECT: even when an application stack is detected, also
inspect repository-level evidence (`.github/`, IaC, docs, policies) because
SOC 2 controls live across code, infrastructure, CI/CD, and documentation.

**Multi-tech monorepos**: record every `type@path` detected and gather
evidence across all of them; repository-level controls (governance, CI/CD,
IaC) are assessed once at the repository root.

## Step 1. Project & Tooling Detection

Goal: Detect the project type(s), stack, package managers, CI/CD system, IaC,
and available compliance-relevant tooling. Establish the evidence surface.

Read and follow the instructions in `references/project-detection.md`

**Integration**: Save detection results for all subsequent steps.

## Step 2. Governance, People & AI Program (Families A, B, J)

Goal: Gather evidence for the organizational-heavy families — Governance &
Program (A), Human Resources Security (B), and AI Governance (J). These are
mostly ORGANIZATIONAL controls: the check is whether the policy artifact exists
in the repository (security policy set, code of conduct, awareness-training
material, NDA/confidentiality references, AI usage policy).

Read and follow the instructions in `references/governance-program.md`

**Integration**: Save governance/people/AI findings for the readiness report.

## Step 3. Identity & Access Management (Family C)

Goal: Gather PLATFORM-AUDITABLE evidence for logical access — authentication,
authorization/RBAC, privileged-access approval, access reviews/revocation,
password standards, MFA, SSO/OIDC, and session management. Redact any secret
VALUES; report only the location and control status.

Read and follow the instructions in `references/access-management.md`

**Integration**: Save access-control findings for the readiness report.

## Step 4. Data Protection & Confidentiality (Family D)

Goal: Gather PLATFORM-AUDITABLE evidence for data protection — TLS in transit,
encryption at rest (KMS/AES-256), tenant/data segregation, data minimization
and classification, retention and secure disposal, residency disclosure, DLP,
and encrypted, restore-tested backups.

Read and follow the instructions in `references/data-protection.md`

**Integration**: Save data-protection findings for the readiness report.

## Step 5. Secure Development & Change Management (Family E)

Goal: Gather PLATFORM-AUDITABLE evidence for secure development and change
management — documented SDLC, dev/test/prod separation, PR review and branch
protection, tested/approved changes, emergency-change path, dependency/SAST/
vulnerability scanning in the pipeline, migration discipline, and patching SLAs.

Read and follow the instructions in `references/change-management.md`

**Integration**: Save change-management findings for the readiness report.

## Step 6. Infrastructure & Network Security (Family F)

Goal: Gather PLATFORM-AUDITABLE evidence from IaC and configuration — network
segmentation/private subnets, WAF/IDS, control-plane audit logging (e.g.
CloudTrail), flow logs and edge access logs, log retention over 30 days,
monitoring with security-event alerting, and a managed secrets store with
rotation.

Read and follow the instructions in `references/infrastructure-network.md`

**Integration**: Save infrastructure findings for the readiness report.

## Step 7. Vulnerability, Assurance, Vendors & Deliverables (Families G, I, K)

Goal: Gather evidence for Vulnerability Management & Assurance (G — production
vuln scans, external pentest attestation, evidence readiness), Vendor /
Third-Party Management (I — vendor risk review, subprocessor flow-down,
outsourced-development disclosure), and inventory the Evidence Artifacts /
Trust Center deliverables (K — SOC 2 report, SIG/CAIQ, pentest attestation,
subprocessor list, status/trust page).

Read and follow the instructions in `references/vulnerability-assurance.md`

**Integration**: Save assurance, vendor, and deliverable-target findings.

## Step 8. Incident Management, BCP & DR (Family H)

Goal: Gather evidence for incident management and resilience — incident-response
plan with postmortems, breach-notification SLA, business-continuity and
disaster-recovery plans tested annually, RPO/RTO targets, and restore drills.

Read and follow the instructions in `references/incident-resilience.md`

**Integration**: Save incident and resilience findings for the report.

## Step 9. Readiness Scoring

Goal: Compute a 0-100 readiness score per control family using the additive
evidence rubrics (weighted toward platform-auditable controls), compute the
weighted overall readiness score, and map it to a readiness band.

Read and follow the instructions in `references/scoring.md`

**Integration**: This rule computes all per-family scores and the weighted
overall score BEFORE the report is written. A report without computed scores
is INVALID.

## Step 10. Generate SOC 2 Readiness Report

Goal: Synthesize all evidence and scores into a comprehensive readiness report
with a per-family scorecard, a gaps table mapped to criteria references and
ownership lanes, a CUEC list, the deliverables the organization must author, a
prioritized remediation roadmap, an overall readiness score, and a band.

Read and follow the instructions in `references/report-generator.md`

**Integration**: This rule integrates all previous evidence and the computed
scores from Step 9 and produces the final report. You MUST have computed all
per-family scores and the weighted overall score BEFORE writing any report
content.

**Report Sections** (19 sections with quantitative scoring):
- SOC 2 Readiness Scorecard (10 scored family lines + Overall + Band)
- Executive Summary with Overall Readiness Score
- Scored Detail Sections (10 sections, dynamically ordered by score ascending — lowest first):
  - A. Governance & Program — CC1.x/CC3.x/CC5.x (weight 8%)
  - B. Human Resources Security — CC1.4 (weight 4%)
  - C. Identity & Access Management — CC6.1-CC6.3, CC6.6 (weight 18%)
  - D. Data Protection & Confidentiality — CC6.1/CC6.7, C1.1-C1.2 (weight 16%)
  - E. Secure Development & Change Management — CC7.1, CC8.1 (weight 16%)
  - F. Infrastructure & Network Security — CC6.6, CC7.2 (weight 14%)
  - G. Vulnerability Management & Assurance — CC7.1 (weight 8%)
  - H. Incident Management, BCP/DR — CC7.3-CC7.5, CC9.1 (weight 8%)
  - I. Vendor / Third-Party Management — CC9.2 (weight 4%)
  - J. AI Governance — CC1.x, CC4.x (weight 4%)
- Trust Services Criteria Gaps & Coverage (gaps table: control ref | family | evidence found | status | owner/lane | gap | remediation | priority)
- Complementary User-Entity Controls (CUECs) — listed separately, not scored
- Evidence Artifacts & Trust Center Deliverables (family K — the 5 deliverables to author)
- Remediation Roadmap (prioritized top actions, phased)
- Project Detection Results
- Appendix: Evidence Index
- Scan Metadata

**Scoring Requirement**: Every scored section MUST include: Score line with
[Score]/100 ([Band]) format, Score Breakdown (Base 0, evidence additions,
Final), Controls Assessed (each control with Status + Owner/lane + evidence),
Gaps, and Recommendations.

## Step 11. Validate and Export Readiness Report

Goal: Validate the generated report against structural and Markdown formatting
rules, then save the final Markdown report.

Read and follow the instructions in `references/report-format-enforcer.md`

**Validation**: Read the generated report and validate ALL structural checks
from the format enforcer rule: exactly 19 sections, Section 1 has 10 scored
family lines with weights + Overall + Formula + Band, the 10 scored detail
sections have Score lines, sections are ordered by score ascending, band labels
match ranges, the gaps table has the required columns (including owner/lane),
the CUEC and Deliverables sections are present, no secret values appear, and
proper Markdown syntax. Fix any issues in-place. If scores are missing
entirely, re-run Step 9 and Step 10 before exporting.

**Export**: Save the validated report to `./reports/soc2_audit.md`

**Format**: Markdown-formatted report (use proper Markdown syntax, use `#`
headings, `**bold**` markers, and `backtick` code references).

**Command**:
```bash
mkdir -p reports
# Save validated report to ./reports/soc2_audit.md
```

## Execution Summary

**Total Rules**: 9 evidence/scoring rules + 1 report generator + 1 format enforcer

**Rule Execution Order**:
1. Read and follow the instructions in `references/project-detection.md` (MANDATORY - project/stack detection) {model: cheap}
2. Read and follow the instructions in `references/governance-program.md` (families A/B/J - governance, HR, AI policy artifacts) {model: cheap}
3. Read and follow the instructions in `references/access-management.md` (family C - identity, access, MFA, sessions) {model: mid}
4. Read and follow the instructions in `references/data-protection.md` (family D - encryption, segregation, retention, backups) {model: mid}
5. Read and follow the instructions in `references/change-management.md` (family E - SDLC, PR review, CI scanning, patching) {model: mid}
6. Read and follow the instructions in `references/infrastructure-network.md` (family F - segmentation, WAF, audit logging, secrets store) {model: mid}
7. Read and follow the instructions in `references/vulnerability-assurance.md` (families G/I/K - scans, pentest, vendors, deliverables) {model: mid}
8. Read and follow the instructions in `references/incident-resilience.md` (family H - IR plan, BCP/DR, RPO/RTO) {model: cheap}
9. Read and follow the instructions in `references/scoring.md` (per-family 0-100 weighted to platform-auditable + overall + band) {model: mid}
10. Read and follow the instructions in `references/report-generator.md` (generates the 19-section readiness report) {model: frontier}

**Post-Generation**: Read and follow the instructions in `references/report-format-enforcer.md` to validate and fix
the report (runs automatically after step 10) {model: frontier}

**Scoring System**:
- 10 scored control families (A-J) with additive evidence rubrics (0-100 each),
  weighted toward platform-auditable controls
- Family K (Evidence Artifacts / Trust Center) reported as deliverable targets, not scored
- Overall Readiness Score computed via weighted formula
- Readiness Band mapped from Overall Score: Not Ready (0-40),
  Partially Ready (41-70), Largely Ready (71-85), Audit-Ready (86-100)
- SOC 2 Readiness Scorecard provides immediate CISO/CTO-level visibility
- Scored sections ordered by score ascending (weakest families first)

**Benefits of Modular Approach**:
- Each rule can be executed independently
- Framework-agnostic with runtime project detection and whole-project scope
- Ownership lanes keep the platform score honest (CUECs never penalize it)
- Outputs can be saved and reused as audit evidence
- Quantitative scoring enables objective comparison across audits over time
- Read-only and evidence-based; secret values are always redacted

## Subagent Dispatch (in-session)

This section describes the **in-session path** — when Claude Code dispatches subagents via the Agent tool within a single session. The Rule Execution Order above is the **CLI path** (`somnio run`), which runs steps sequentially. Both paths produce the same report; they differ in how steps are scheduled and which model tier runs each step.

**Entry point**: `agents/orchestrator.md` (model: mid)

The orchestrator reads this SKILL.md for scope context, then fans out to evidence-gathering subagents in dependency-ordered waves. It validates each expected artifact before advancing to the next wave. On a missing artifact it retries once, then logs the gap and lets the report-writer handle it via the rejection criteria (Gap with score 0 for the affected family).

### Wave Plan

| Wave | Mode | Agents dispatched | Tier |
|------|------|-------------------|------|
| Wave 0 | Sequential (stop-on-failure) | `detector` | cheap |
| Wave 1 | Parallel | `governance-analyzer`, `access-analyzer`, `pipeline-analyzer` | cheap / mid |
| Wave 2 | Sequential | `risk-analyzer` | mid |
| Wave 3 | Sequential | `report-writer` | frontier |

### Dispatch Table

| Agent file | Tier | References / steps covered | Artifact(s) written |
|---|---|---|---|
| `agents/detector.md` | cheap | `references/project-detection.md` (step 1) | `reports/.artifacts/step_01_soc2_project_detection.md` |
| `agents/governance-analyzer.md` | cheap | `references/governance-program.md` (step 2, families A/B/J) | `reports/.artifacts/step_02_soc2_governance_program.md` |
| `agents/access-analyzer.md` | mid | `references/access-management.md` (step 3, family C) + `references/data-protection.md` (step 4, family D) | `reports/.artifacts/step_03_soc2_access_management.md`, `reports/.artifacts/step_04_soc2_data_protection.md` |
| `agents/pipeline-analyzer.md` | mid | `references/change-management.md` (step 5, family E) + `references/infrastructure-network.md` (step 6, family F) | `reports/.artifacts/step_05_soc2_change_management.md`, `reports/.artifacts/step_06_soc2_infrastructure_network.md` |
| `agents/risk-analyzer.md` | mid | `references/vulnerability-assurance.md` (step 7, families G/I/K) + `references/incident-resilience.md` (step 8, family H) | `reports/.artifacts/step_07_soc2_vulnerability_assurance.md`, `reports/.artifacts/step_08_soc2_incident_resilience.md` |
| `agents/report-writer.md` | frontier | `references/scoring.md` (step 9) + `references/report-generator.md` (step 10) + `references/report-format-enforcer.md` (step 11) + `assets/report-template.md` | `reports/soc2_audit.md`, `reports/soc2_audit.json`, `reports/.history/last_scores.json` |

**Model tiers** are provider-neutral symbolic names. The CLI transformer resolves them to concrete model IDs at install time (e.g. for Claude: cheap→haiku, mid→sonnet, frontier→opus).

## Report Metadata (MANDATORY)

Every generated report MUST include a metadata block at the very end. This is non-negotiable — never omit it.

To resolve the source and version:
1. Look for `.claude-plugin/plugin.json` by traversing up from this skill's directory
2. If found, read `name` and `version` from that file (plugin context)
3. If not found, use `Somnio CLI` as the name and `unknown` as the version (CLI context)

Include this block at the very end of the report:

```
---
Generated by: [plugin name or "Somnio CLI"] v[version]
Skill: soc2-audit
Date: [YYYY-MM-DD]
Somnio AI Tools: https://github.com/somnio-software/somnio-ai-tools
---
```
