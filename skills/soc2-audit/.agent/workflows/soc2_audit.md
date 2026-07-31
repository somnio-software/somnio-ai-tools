---
description: >-
  Execute a comprehensive, framework-agnostic SOC 2 readiness audit of an entire
  repository or application. Detects project type and stack at runtime and
  adapts evidence gathering. Assesses AICPA Trust Services Criteria controls
  across eleven control families (A-K), records each control's Status and
  ownership lane (platform-auditable / organizational / client-CUEC), scores
  readiness per family, and produces a prioritized remediation plan with an
  overall readiness score and band. Read-only; secret values redacted.
---

# SOC 2 Readiness Audit

Execute the SOC 2 readiness audit through sequential, modular rules. Detects the
project type at runtime and adapts all evidence gathering accordingly. Read-only.

## Step 1: Project & Tooling Detection (MANDATORY)

Read `soc2-audit/references/project-detection.md` and follow ALL instructions in the prompt field

## Step 2: Governance, People & AI Program (Families A, B, J)

Read `soc2-audit/references/governance-program.md` and follow ALL instructions in the prompt field

## Step 3: Identity & Access Management (Family C)

Read `soc2-audit/references/access-management.md` and follow ALL instructions in the prompt field

## Step 4: Data Protection & Confidentiality (Family D)

Read `soc2-audit/references/data-protection.md` and follow ALL instructions in the prompt field

## Step 5: Secure Development & Change Management (Family E)

Read `soc2-audit/references/change-management.md` and follow ALL instructions in the prompt field

## Step 6: Infrastructure & Network Security (Family F)

Read `soc2-audit/references/infrastructure-network.md` and follow ALL instructions in the prompt field

## Step 7: Vulnerability, Assurance, Vendors & Deliverables (Families G, I, K)

Read `soc2-audit/references/vulnerability-assurance.md` and follow ALL instructions in the prompt field

## Step 8: Incident Management, BCP & DR (Family H)

Read `soc2-audit/references/incident-resilience.md` and follow ALL instructions in the prompt field

## Step 9: Readiness Scoring

Read `soc2-audit/references/scoring.md` and follow ALL instructions in the prompt field

## Step 10: Generate SOC 2 Readiness Report

Read `soc2-audit/references/report-generator.md` and follow ALL instructions in the prompt field

## Step 11: Validate and Export Report

Read `soc2-audit/references/report-format-enforcer.md` and follow ALL instructions in the prompt field

Save the validated report to `./reports/soc2_audit.md`
