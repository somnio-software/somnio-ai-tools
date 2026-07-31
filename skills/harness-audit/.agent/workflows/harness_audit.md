---
description: >-
  Execute a comprehensive, framework-agnostic AI Harness Audit. Locates every
  harness piece at runtime (CLAUDE.md, rules, settings.json permissions and
  hooks, commands/skills, agents, and the autotest-to-PR lifecycle), scores them
  against a fixed 7-piece / 100-point rubric, and produces a scored report with a
  maturity band and a top-3 action plan. Read-only: never modifies the audited
  repository.
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

Save the report to `./reports/harness_audit.md`
