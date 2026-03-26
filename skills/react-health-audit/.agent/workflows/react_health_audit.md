---
description: >-
  Execute a comprehensive React Project Health Audit. Analyzes tech stack,
  architecture, state management, testing, code quality, performance, CI/CD,
  and documentation. Produces a Google Docs-ready report with section scores
  and weighted overall score.
---

# React Project Health Audit

Execute the React Project Health Audit through modular rules organized in
execution waves. Each rule produces output that feeds into the final report.

## Execution Discipline (NON-NEGOTIABLE)

- NEVER skip, combine, or abbreviate any step
- NEVER summarize a reference file instead of executing it
- ALWAYS read each reference file completely, then follow ALL its instructions
- ALWAYS log completion after each step: "STEP N COMPLETED: [result summary]"
- NEVER proceed to the next step without completing the current one
- If a step fails: document the failure and attempt recovery before moving on

## Wave 0: Environment Setup (MANDATORY - Sequential)

Read `react-health-audit/references/tool-installer.md` and follow ALL instructions in the prompt field
STEP 0a COMPLETED: [log result]

Read `react-health-audit/references/version-alignment.md` and follow ALL instructions in the prompt field
STEP 0b COMPLETED: [log result]

Read `react-health-audit/references/version-validator.md` and follow ALL instructions in the prompt field
STEP 0c COMPLETED: [log result]

Read `react-health-audit/references/test-coverage.md` and follow ALL instructions in the prompt field
STEP 0d COMPLETED: [log result]

CRITICAL: If version-alignment fails, STOP execution and provide resolution steps.

## Wave 1: Structure Analysis (Parallelizable)

These steps are independent and can be executed in parallel if supported:

Read `react-health-audit/references/repository-inventory.md` and follow ALL instructions in the prompt field
STEP 1 COMPLETED: [log result]

Read `react-health-audit/references/config-analysis.md` and follow ALL instructions in the prompt field
STEP 2 COMPLETED: [log result]

## Wave 2: Infrastructure Analysis (Parallelizable)

These steps are independent and can be executed in parallel if supported:

Read `react-health-audit/references/cicd-analysis.md` and follow ALL instructions in the prompt field
STEP 3 COMPLETED: [log result]

Read `react-health-audit/references/testing-analysis.md` and follow ALL instructions in the prompt field
STEP 4 COMPLETED: [log result]

Read `react-health-audit/references/code-quality.md` and follow ALL instructions in the prompt field
STEP 5 COMPLETED: [log result]

## Wave 3: Domain Analysis (Parallelizable)

These steps are independent and can be executed in parallel if supported:

Read `react-health-audit/references/state-management-analysis.md` and follow ALL instructions in the prompt field
STEP 6 COMPLETED: [log result]

Read `react-health-audit/references/documentation-analysis.md` and follow ALL instructions in the prompt field
STEP 7 COMPLETED: [log result]

## Wave 4: Report Format Enforcement (Sequential)

Read `react-health-audit/references/report-format-enforcer.md` and follow ALL instructions in the prompt field
STEP 8 COMPLETED: [log result]

## Wave 5: Report (Sequential - Requires ALL previous results)

Read `react-health-audit/references/report-generator.md` and follow ALL instructions in the prompt field
STEP 9 COMPLETED: [log result]

Save the final Google Docs-ready plain-text report to `./reports/react_audit.txt`
STEP 10 COMPLETED: Report exported
