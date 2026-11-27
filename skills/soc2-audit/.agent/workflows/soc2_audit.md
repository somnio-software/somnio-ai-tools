---
description: >-
  Read-only SOC 2 readiness audit against the Trust Services Criteria, /100
  score. Triggers: 'soc 2 audit', 'soc2 readiness', 'soc2 gap analysis',
  'compliance audit'.
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

Save the validated report to `./reports/<YYYY-MM-DD>-<project>-soc2-audit.md`
