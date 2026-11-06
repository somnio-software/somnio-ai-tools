---
description: >-
  Read-only AI harness audit: scores CLAUDE.md, rules, hooks and agents out of
  100. Triggers: 'harness audit', 'ai harness', 'claude harness score'.
---

# AI Harness Audit

Execute the AI Harness Audit through sequential, modular rules. Detects the
harness surface at runtime and scores how much of the quality path is paved into
the harness versus left to the model to improvise. This audit is strictly
read-only against the audited repository.

## Step 1: Harness Inventory (read-only)

Read `harness-audit/references/harness-inventory.md` and follow ALL instructions in the prompt field

## Step 2: Harness Scoring

Read `harness-audit/references/harness-scoring.md` and follow ALL instructions in the prompt field

## Step 3: Generate Harness Audit Report

Read `harness-audit/references/report-generator.md` and follow ALL instructions in the prompt field

## Step 4: Validate and Export Report

Read `harness-audit/references/report-format-enforcer.md` and follow ALL instructions in the prompt field

Save the validated report to `./reports/<YYYY-MM-DD>-<project>-harness-audit.md`
