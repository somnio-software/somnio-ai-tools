---
description: >-
  Next.js project health audit (versions, App Router, caching, CI/CD), scored
  report. Triggers: 'nextjs audit', 'nextjs health', 'app router audit'.
---

# Next.js Project Health Audit

Execute the Next.js Project Health Audit through modular rules organized in
execution waves. Each rule produces output that feeds into the final report.

## Execution Discipline (NON-NEGOTIABLE)

- NEVER skip, combine, or abbreviate any step
- NEVER summarize a reference file instead of executing it
- ALWAYS read each reference file completely, then follow ALL its instructions
- ALWAYS log completion after each step: "STEP N COMPLETED: [result summary]"
- NEVER proceed to the next step without completing the current one
- If a step fails: document the failure and attempt recovery before moving on

## Wave 0: Environment Setup (MANDATORY - Sequential) # model: cheap

Read `nextjs-health-audit/references/tool-installer.md` and follow ALL instructions in the prompt field
STEP 0a COMPLETED: [log result] # model: cheap

Read `nextjs-health-audit/references/version-alignment.md` and follow ALL instructions in the prompt field
STEP 0b COMPLETED: [log result] # model: cheap

Read `nextjs-health-audit/references/version-validator.md` and follow ALL instructions in the prompt field
STEP 0c COMPLETED: [log result] # model: cheap

Read `nextjs-health-audit/references/test-coverage.md` and follow ALL instructions in the prompt field
STEP 0d COMPLETED: [log result] # model: cheap

CRITICAL: If version-alignment fails, STOP execution and provide resolution steps.
Package manager: pnpm first (`corepack enable && pnpm install --frozen-lockfile`); with npm/yarn install with what the repo uses and record "not using pnpm". Never delete or regenerate a lockfile.

## Wave 1: Structure Analysis (Parallelizable) # model: cheap

These steps are independent and can be executed in parallel if supported:

Read `nextjs-health-audit/references/repository-inventory.md` and follow ALL instructions in the prompt field
STEP 1 COMPLETED: [log result] # model: cheap

Read `nextjs-health-audit/references/config-analysis.md` and follow ALL instructions in the prompt field
STEP 2 COMPLETED: [log result] # model: cheap

## Wave 2: Infrastructure Analysis (Parallelizable)

These steps are independent and can be executed in parallel if supported:

Read `nextjs-health-audit/references/cicd-analysis.md` and follow ALL instructions in the prompt field
STEP 3 COMPLETED: [log result] # model: cheap

Read `nextjs-health-audit/references/testing-analysis.md` and follow ALL instructions in the prompt field
STEP 4 COMPLETED: [log result] # model: mid

Read `nextjs-health-audit/references/code-quality.md` and follow ALL instructions in the prompt field
STEP 5 COMPLETED: [log result] # model: mid

Read `nextjs-health-audit/references/harness-analysis.md` and follow ALL instructions in the prompt field
STEP 8 COMPLETED: [log result] # model: mid

## Wave 3: Domain Analysis (Parallelizable)

These steps are independent and can be executed in parallel if supported:

Read `nextjs-health-audit/references/state-management-analysis.md` and follow ALL instructions in the prompt field
STEP 6 COMPLETED: [log result] # model: mid

Read `nextjs-health-audit/references/documentation-analysis.md` and follow ALL instructions in the prompt field
STEP 7 COMPLETED: [log result] # model: cheap

Read `nextjs-health-audit/references/dependency-security-analysis.md` and follow ALL instructions in the prompt field (it requires `nextjs-health-audit/references/live-vulnerability-sources.md`; never state a vulnerable or patched version from memory)
STEP 9 COMPLETED: [log result] # model: mid

## Wave 4: Report Format Enforcement (Sequential) # model: frontier

Read `nextjs-health-audit/references/report-format-enforcer.md` and follow ALL instructions in the prompt field
STEP 10 COMPLETED: [log result] # model: frontier

## Wave 5: Report (Sequential - Requires ALL previous results) # model: frontier

Read `nextjs-health-audit/references/report-generator.md` and follow ALL instructions in the prompt field
STEP 11 COMPLETED: [log result] # model: frontier

Save the final Markdown report to `./reports/<YYYY-MM-DD>-<project>-nextjs-health-audit.md`
STEP 12 COMPLETED: Report exported # model: frontier
