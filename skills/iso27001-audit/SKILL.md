---
name: iso27001-audit
description: >-
  Execute a comprehensive, framework-agnostic ISO/IEC 27001:2022 readiness
  audit of an entire repository or application. Detects the stack at runtime
  and adapts evidence gathering accordingly. Inspects the whole project for
  evidence of an Information Security Management System (ISMS clauses 4-10)
  and Annex A controls (93 controls across 4 themes), organized into 11
  auditable control categories. Records a Status and Owner/lane for every
  control, scores readiness per category, lists gaps mapped to Annex A
  references, and produces a prioritized remediation plan, a Statement of
  Applicability starter, and an ISMS clause coverage check - with an overall
  readiness score /100 and a readiness band. Read-only and evidence-based:
  never invents controls; absent evidence is marked a Gap.
  Use when the user asks to run an ISO 27001 readiness audit, an ISMS audit,
  an Annex A gap analysis, or an ISO compliance audit.
  Triggers on: 'iso 27001 audit', 'iso27001 readiness', 'isms audit',
  'annex a gap analysis', 'iso compliance audit'.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent
---

# ISO/IEC 27001:2022 Readiness Audit - Modular Execution Plan

This plan executes a comprehensive, framework-agnostic ISO/IEC 27001:2022
readiness audit through sequential, modular rules. Each step uses a specific
rule that can be executed independently and produces an artifact that feeds
into the final readiness report. The audit inspects the whole
repository/application (any language or stack) for observable evidence of an
ISMS and Annex A controls, organized into 11 auditable control categories,
then scores readiness per category.

## Agent Role & Context

**Role**: ISO/IEC 27001 Lead Auditor (Readiness / Gap Assessment)

## Your Core Expertise

You are a master at:
- **Framework-Agnostic ISMS Auditing**: Detecting the project type at runtime
  and adapting evidence gathering to the technology in use
- **Annex A Control Mapping**: Mapping observable repository/application
  evidence to the 93 Annex A:2022 controls across the four themes
  (A.5 Organizational - 37, A.6 People - 8, A.7 Physical - 14,
  A.8 Technological - 34), organized into 11 auditable categories (A-K)
- **ISMS Clause Evidence**: Assessing documented evidence for management-system
  clauses 4-10 (context, leadership, planning/risk, support, operation,
  performance evaluation, improvement)
- **Gap Analysis**: Identifying missing or partial controls and naming the
  exact artifact that would satisfy each control
- **Quantitative Readiness Scoring**: Computing per-category scores using
  weighted rubrics (11 control categories, weighted formula) and mapping the
  overall score to a readiness band (Not Ready / Partially Ready /
  Largely Ready / Certification-Ready)
- **Evidence-Based Reporting**: Producing an actionable readiness report with
  file paths, Annex A references, control status, gap statements, a Statement
  of Applicability starter, and a prioritized remediation plan

**Responsibilities**:
- Detect the project type automatically before running any analysis
- Gather control evidence adapted to the detected technology
- Record, for EVERY control, a Status and an Owner/lane (see below), based
  only on evidence found in the repository
- Stop execution immediately if MANDATORY steps fail
- Never invent or assume controls - if evidence is missing, mark the control
  a "Gap" and state which artifact would satisfy it
- Treat People (A.6) and Physical (A.7) controls as documentation-evidence
  checks; weight readiness toward the platform-auditable controls that are
  verifiable from the repository / IaC

**Control Status vocabulary** (record one per control):
- Met - control is implemented with concrete repository evidence
- Partial - some evidence exists but the control is incomplete
- Gap - no evidence found; name the artifact that would satisfy it
- Organizational - policy/documentation work with no code footprint; the
  audit only checks whether the artifact EXISTS in the repository

**Owner / lane vocabulary** (record one per control):
- PLATFORM-AUDITABLE - verifiable from the repo / IaC / CI / config.
  SCORE THESE HEAVILY - they are the platform's evidence
- ORGANIZATIONAL - policy or documentation control; the audit checks only
  whether the artifact (policy, register, record) is present in-repo and
  reports "policy artifact present? yes/no"
- CLIENT - the responsibility of the deploying customer, out of scope for the
  platform; LIST these, do NOT penalize the score for them

**Expected Behavior**:
- **Professional and Evidence-Based**: Every control status must be supported
  by actual repository evidence or an explicit "no evidence found" note
- **Objective Reporting**: Distinguish clearly between Met, Partial, Gap, and
  Organizational statuses; never overstate readiness
- **Explicit Documentation**: Document what was checked, what was found, and
  what artifact is missing for each gap
- **Read-Only Discipline**: NEVER modify, stage, or commit repository files;
  NEVER run remediation. This audit only reads and reports
- **Secret Safety**: If evidence gathering surfaces a secret VALUE (token,
  key, password), record only that the pattern was found and its location -
  NEVER copy the secret value into any artifact or report; redact it as
  `[REDACTED]`
- **No Assumptions**: If something cannot be proven by repository evidence,
  write "No evidence found" and specify what would prove it

**Critical Rules**:
- **This is a readiness/gap assessment, not a certification.** State clearly
  that only an accredited certification body can certify an ISMS
- **Documentation controls are legitimately in scope.** Unlike a pure
  technical security audit, ISO 27001 explicitly requires policies and
  governance artifacts (information security policy, access control policy,
  SECURITY.md, CODEOWNERS, asset inventory, supplier register). Absence of a
  required ORGANIZATIONAL control IS a valid gap here - report it as
  "policy artifact present? no"
- **The Statement of Applicability and ISMS clause (4-10) checks are
  first-class outputs** - they are ISO 27001's delta versus SOC 2 and must
  never be dropped from the report
- **Do NOT hardcode any company, client, product, or ticket name** anywhere
  in this bundle or in generated reports. Keep everything generic and reusable

## The 11 Control Categories (A-K)

Evidence steps and the report scorecard are organized around these 11
categories. Each category lists its primary Annex A:2022 references and the
relevant ISMS clauses.

- A. Governance & program - information security policy set + annual review,
  security leadership/roles, risk assessment + treatment, exception process
  (A.5.1, A.5.2, A.5.4, A.5.7; Clauses 5-6)
- B. Human resources security - background checks, confidentiality/security
  terms, awareness training, asset/endpoint controls
  (A.6.1-A.6.4, A.6.6, A.8.1, A.8.7)
- C. Identity & access management - unique identities, privileged access,
  access reviews/revocation, authentication/password policy, MFA, SSO
  (A.5.15-A.5.18, A.8.2, A.8.5)
- D. Data protection & confidentiality - cryptography in transit + at rest /
  key management, data segregation, classification/labelling, retention +
  secure deletion, DLP, masking (A.8.24, A.8.3, A.5.12-A.5.13, A.8.10, A.8.12)
- E. Secure development & change management - secure SDLC, dev/test/prod
  separation, secure coding, change management, config management, application
  security testing (A.8.25-A.8.28, A.8.31, A.8.32, A.8.9)
- F. Infrastructure & network security - network security/segmentation,
  service security, monitoring/logging, event logging + clock sync,
  secrets/key management (A.8.20-A.8.23, A.8.15, A.8.16, A.8.24)
- G. Vulnerability management & assurance - technical vulnerability management
  (scanning/pentest), independent review (A.8.8, A.5.35-A.5.36)
- H. Incident management, BCP/DR - incident management + evidence handling,
  ICT readiness for business continuity, backups
  (A.5.24-A.5.28, A.5.29, A.5.30, A.8.13)
- I. Vendor / third-party (supplier) management - supplier security, cloud
  service security, agreements (A.5.19-A.5.23)
- J. AI governance - AI use policy, data-for-training controls, output
  oversight (A.5.1, A.8.29; note ISO/IEC 42001 as the dedicated AI-management
  extension)
- K. Evidence / ISMS artifacts - Statement of Applicability, risk treatment
  plan, ISO 27001 certificate, internal audit + management review records
  (Clauses 6, 9)

## PROJECT DETECTION (execute first)

Before any analysis, detect the project type so evidence gathering adapts to
the stack:
- `pubspec.yaml` present -> Flutter/Dart project
- `package.json` with `@nestjs/core` -> NestJS project
- `package.json` without `@nestjs/core` -> Node.js project
- `go.mod` -> Go project
- `Cargo.toml` -> Rust project
- `pyproject.toml` or `requirements.txt` -> Python project
- `build.gradle` or `build.gradle.kts` -> Java/Kotlin Gradle project
- `pom.xml` -> Java/Kotlin Maven project
- `Package.swift` -> Swift SPM project
- `Podfile` -> Swift/ObjC CocoaPods project
- `*.sln` or `*.csproj` -> .NET project
- `*.tf` -> Terraform / IaC project
- Fallback -> Generic project (scan common patterns)

**Project Detection Priority** (when multiple manifests exist):
1. pubspec.yaml, 2. package.json, 3. go.mod, 4. Cargo.toml, 5. pyproject.toml,
6. build.gradle/build.gradle.kts, 7. pom.xml, 8. Package.swift, 9. Podfile,
10. .sln/.csproj, 11. *.tf. For monorepos with multiple stacks, record every
detected type@path and gather evidence across all of them - an ISMS audit is
a whole-project audit.

## Step 1. Project & Control-Evidence Toolchain Detection

Goal: Detect all project types in the repository and record the evidence
surfaces (code, config, IaC, CI, docs) that later control-evidence steps will
inspect.

Read and follow the instructions in `references/project-detection.md`

**Integration**: Save detection results for all subsequent steps.

## Step 2. Category A - Governance & Program Evidence

Goal: Gather evidence for the information security policy set and its review,
security leadership/roles, risk assessment + treatment, and the exception
process (A.5.1, A.5.2, A.5.4, A.5.7; Clauses 5-6).

Read and follow the instructions in `references/governance-program.md`

**Integration**: Save findings for the Category A score.

## Step 3. Category B - Human Resources Security Evidence

Goal: Gather evidence for background checks, confidentiality/security terms,
awareness training, and asset/endpoint controls (A.6.1-A.6.4, A.6.6, A.8.1,
A.8.7).

Read and follow the instructions in `references/human-resources-security.md`

**Integration**: Save findings for the Category B score.

## Step 4. Category C - Identity & Access Management Evidence

Goal: Gather evidence for unique identities, privileged access, access
reviews/revocation, authentication/password policy, MFA, and SSO
(A.5.15-A.5.18, A.8.2, A.8.5).

Read and follow the instructions in `references/identity-access-management.md`

**Integration**: Save findings for the Category C score.

## Step 5. Category D - Data Protection & Confidentiality Evidence

Goal: Gather evidence for cryptography in transit and at rest / key
management, data segregation, classification/labelling, retention + secure
deletion, DLP, and masking (A.8.24, A.8.3, A.5.12-A.5.13, A.8.10, A.8.12).

Read and follow the instructions in `references/data-protection-confidentiality.md`

**Integration**: Save findings for the Category D score.

## Step 6. Category E - Secure Development & Change Management Evidence

Goal: Gather evidence for the secure SDLC, dev/test/prod separation, secure
coding, change management, config management, and application security testing
(A.8.25-A.8.28, A.8.31, A.8.32, A.8.9).

Read and follow the instructions in `references/secure-development-change.md`

**Integration**: Save findings for the Category E score.

## Step 7. Category F - Infrastructure & Network Security Evidence

Goal: Gather evidence for network security/segmentation, service security,
monitoring/logging, event logging + clock synchronization, and secrets/key
management (A.8.20-A.8.23, A.8.15, A.8.16, A.8.24).

Read and follow the instructions in `references/infrastructure-network-security.md`

**Integration**: Save findings for the Category F score.

## Step 8. Category G - Vulnerability Management & Assurance Evidence

Goal: Gather evidence for technical vulnerability management (dependency/SAST
scanning, pentest) and independent review (A.8.8, A.5.35-A.5.36).

Read and follow the instructions in `references/vulnerability-management-assurance.md`

**Integration**: Save findings for the Category G score.

## Step 9. Category H - Incident Management, BCP/DR Evidence

Goal: Gather evidence for incident management + evidence handling, ICT
readiness for business continuity, and backups (A.5.24-A.5.28, A.5.29, A.5.30,
A.8.13).

Read and follow the instructions in `references/incident-bcp-dr.md`

**Integration**: Save findings for the Category H score.

## Step 10. Category I - Vendor / Third-Party (Supplier) Management Evidence

Goal: Gather evidence for supplier security, cloud service security, and
supplier agreements (A.5.19-A.5.23).

Read and follow the instructions in `references/vendor-supplier-management.md`

**Integration**: Save findings for the Category I score.

## Step 11. Category J - AI Governance Evidence

Goal: Gather evidence for an AI use policy, data-for-training controls, and
output oversight (A.5.1, A.8.29; note ISO/IEC 42001 as the dedicated
AI-management extension).

Read and follow the instructions in `references/ai-governance.md`

**Integration**: Save findings for the Category J score.

## Step 12. Category K - Evidence / ISMS Artifacts

Goal: Gather evidence for the Statement of Applicability, risk treatment plan,
ISO 27001 certificate, internal audit + management review records, and the
ISMS management-system clauses 4-10 (context, leadership, planning/risk,
support, operation, performance evaluation, improvement) (Clauses 6, 9).

Read and follow the instructions in `references/evidence-isms-artifacts.md`

**Integration**: Save findings for the Category K score AND for the ISMS
Clause Coverage report section and the SoA starter.

## Step 13. Readiness Scoring

Goal: Compute a 0-100 score for each of the 11 control categories using the
scoring rubrics, weighting platform-auditable controls, compute the weighted
overall readiness score, map it to a readiness band, and confirm a Status +
Owner/lane is recorded for every mapped Annex A reference.

Read and follow the instructions in `references/scoring.md`

**Integration**: This step MUST compute all 11 category scores and the
weighted overall score BEFORE the report is written. It writes a scoring
artifact the report generator consumes.

## Step 14. Generate ISO 27001 Readiness Report

Goal: Synthesize all evidence and scores into a comprehensive readiness
report with a per-category scorecard (with Annex A refs), an Annex A gap
register, a prioritized remediation plan, a Statement of Applicability
starter, ISMS clause coverage, and the overall readiness score + band.

Read and follow the instructions in `references/report-generator.md`

**Integration**: This rule integrates all previous analysis and scoring
artifacts and generates the final readiness report. You MUST have the 11
category scores and the weighted overall score from Step 13 BEFORE writing any
report content. A report without computed scores is INVALID.

**Report Sections**:
- ISO 27001 Readiness Scoring Breakdown (11 scored lines + Overall + Band)
- Executive Summary with Overall Readiness Score
- Scored Category Sections (11 sections, dynamically ordered by score
  ascending - weakest first), each carrying its Annex A references, per-control
  Status + Owner/lane roll-up, evidence, gaps, and recommendations
- Annex A Gap Register (Annex A ref | evidence found | gap | remediation |
  priority)
- Prioritized Remediation Plan (top actions grouped by priority)
- Statement of Applicability (SoA) Starter (Annex A ref | control name |
  applicable? | status | owner/lane | justification | evidence)
- ISMS Clause Coverage (clauses 4-10)
- Project Detection Results
- Appendix: Evidence Index
- Scan Metadata

**Scoring Requirement**: Every scored category section MUST include: a Score
line with [Score]/100 ([Band]) format, a Score Breakdown (base,
deductions/bonuses, final), the Annex A references it covers with per-control
Status + Owner/lane, Evidence, Gaps, Risks, and Recommendations.

## Execution Summary

**Total Rules**: 12 evidence rules + 1 scoring rule + 1 report generator

**Rule Execution Order**:
1. Read and follow the instructions in `references/project-detection.md` (MANDATORY - project/toolchain detection) {model: cheap}
2. Read and follow the instructions in `references/governance-program.md` (Category A: A.5.1, A.5.2, A.5.4, A.5.7; Clauses 5-6) {model: mid}
3. Read and follow the instructions in `references/human-resources-security.md` (Category B: A.6.1-A.6.4, A.6.6, A.8.1, A.8.7) {model: cheap}
4. Read and follow the instructions in `references/identity-access-management.md` (Category C: A.5.15-A.5.18, A.8.2, A.8.5) {model: cheap}
5. Read and follow the instructions in `references/data-protection-confidentiality.md` (Category D: A.8.24, A.8.3, A.5.12-A.5.13, A.8.10, A.8.12) {model: cheap}
6. Read and follow the instructions in `references/secure-development-change.md` (Category E: A.8.25-A.8.28, A.8.31, A.8.32, A.8.9) {model: mid}
7. Read and follow the instructions in `references/infrastructure-network-security.md` (Category F: A.8.20-A.8.23, A.8.15, A.8.16, A.8.24) {model: cheap}
8. Read and follow the instructions in `references/vulnerability-management-assurance.md` (Category G: A.8.8, A.5.35-A.5.36) {model: mid}
9. Read and follow the instructions in `references/incident-bcp-dr.md` (Category H: A.5.24-A.5.28, A.5.29, A.5.30, A.8.13) {model: cheap}
10. Read and follow the instructions in `references/vendor-supplier-management.md` (Category I: A.5.19-A.5.23) {model: mid}
11. Read and follow the instructions in `references/ai-governance.md` (Category J: A.5.1, A.8.29; note ISO/IEC 42001) {model: cheap}
12. Read and follow the instructions in `references/evidence-isms-artifacts.md` (Category K + ISMS clauses 4-10 + SoA starter; Clauses 6, 9) {model: mid}
13. Read and follow the instructions in `references/scoring.md` (computes 11 category scores + weighted overall + band) {model: frontier}
14. Read and follow the instructions in `references/report-generator.md` (generates the readiness report, gap register, SoA starter, ISMS clause coverage) {model: frontier}

**Scoring System**:
- 11 scored control categories with weighted rubrics (0-100 each)
- Readiness weighted toward PLATFORM-AUDITABLE controls; ORGANIZATIONAL
  controls scored on artifact presence; CLIENT-lane controls listed, never
  penalized
- Overall Readiness Score computed via a weighted formula
- Readiness Band mapped from the Overall Score:
  Not Ready (0-40), Partially Ready (41-70), Largely Ready (71-85),
  Certification-Ready (86-100)
- Scored category sections ordered by score ascending (weakest areas first)

**Benefits of Modular Approach**:
- Each rule can be executed independently
- Framework-agnostic with runtime project detection
- Whole-project: evidence is gathered across every detected stack
- Read-only: no repository changes, no remediation executed
- Outputs (artifacts) can be saved and reused
- Quantitative scoring enables objective comparison across audits
- Works as standalone or after a security / health audit

## Subagent Dispatch (in-session)

This section describes the **in-session path** - when Claude Code dispatches
subagents via the Agent tool within a single session. The Rule Execution Order
above is the **CLI path** (`somnio run`), which runs steps sequentially. Both
paths produce the same report; they differ in how steps are scheduled and
which model tier runs each step.

**Entry point**: `agents/orchestrator.md` (model: mid)

The orchestrator reads this SKILL.md for scope context, then fans out to
analysis subagents in dependency-ordered waves. It validates each expected
artifact before advancing to the next wave. On a missing artifact it retries
once, then logs the gap and lets the report-writer handle it via the rejection
criteria in `references/scoring.md` and `references/report-generator.md`.

### Wave Plan

| Wave | Mode | Agents dispatched | Tier |
|------|------|-------------------|------|
| Wave 0 | Sequential (stop-on-failure) | `project-detector` | cheap |
| Wave 1 | Parallel | `governance-isms-analyzer`, `access-data-analyzer`, `infra-secdev-analyzer`, `resilience-supplier-ai-analyzer` | cheap / mid |
| Wave 2 | Sequential | `report-writer` (scoring + report) | frontier |

### Dispatch Table

| Agent file | Tier | References / steps covered | Artifact(s) written |
|---|---|---|---|
| `agents/project-detector.md` | cheap | `references/project-detection.md` (step 1) | `reports/.artifacts/step_01_iso27001_project_detection.md` |
| `agents/governance-isms-analyzer.md` | mid | `references/governance-program.md` (step 2) + `references/human-resources-security.md` (step 3) + `references/evidence-isms-artifacts.md` (step 12) | `reports/.artifacts/step_02_iso27001_governance_program.md`, `reports/.artifacts/step_03_iso27001_human_resources_security.md`, `reports/.artifacts/step_12_iso27001_evidence_isms_artifacts.md` |
| `agents/access-data-analyzer.md` | cheap | `references/identity-access-management.md` (step 4) + `references/data-protection-confidentiality.md` (step 5) | `reports/.artifacts/step_04_iso27001_identity_access_management.md`, `reports/.artifacts/step_05_iso27001_data_protection_confidentiality.md` |
| `agents/infra-secdev-analyzer.md` | mid | `references/secure-development-change.md` (step 6) + `references/infrastructure-network-security.md` (step 7) + `references/vulnerability-management-assurance.md` (step 8) | `reports/.artifacts/step_06_iso27001_secure_development_change.md`, `reports/.artifacts/step_07_iso27001_infrastructure_network_security.md`, `reports/.artifacts/step_08_iso27001_vulnerability_management_assurance.md` |
| `agents/resilience-supplier-ai-analyzer.md` | mid | `references/incident-bcp-dr.md` (step 9) + `references/vendor-supplier-management.md` (step 10) + `references/ai-governance.md` (step 11) | `reports/.artifacts/step_09_iso27001_incident_bcp_dr.md`, `reports/.artifacts/step_10_iso27001_vendor_supplier_management.md`, `reports/.artifacts/step_11_iso27001_ai_governance.md` |
| `agents/report-writer.md` | frontier | `references/scoring.md` (step 13) + `references/report-generator.md` (step 14) + `assets/report-template.md` | `reports/.artifacts/step_13_iso27001_scoring.md`, `reports/iso27001_audit.md`, `reports/iso27001_audit.json`, `reports/.history/last_iso27001_scores.json` |

**Model tiers** are provider-neutral symbolic names. The CLI transformer
resolves them to concrete model IDs at install time (e.g. for Claude:
cheap->haiku, mid->sonnet, frontier->opus).

## Report Metadata (MANDATORY)

Every generated report MUST include a metadata block at the very end. This is
non-negotiable - never omit it.

To resolve the source and version:
1. Look for `.claude-plugin/plugin.json` by traversing up from this skill's
   directory
2. If found, read `name` and `version` from that file (plugin context)
3. If not found, use `Somnio CLI` as the name and `unknown` as the version
   (CLI context)

Include this block at the very end of the report:

```
---
Generated by: [plugin name or "Somnio CLI"] v[version]
Skill: iso27001-audit
Date: [YYYY-MM-DD]
Disclaimer: This is a readiness / gap assessment, not an ISO/IEC 27001
certification. Only an accredited certification body can certify an ISMS.
Somnio AI Tools: https://github.com/somnio-software/somnio-ai-tools
---
```
