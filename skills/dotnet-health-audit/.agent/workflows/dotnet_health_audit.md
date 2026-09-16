---
description: >-
  Execute a comprehensive .NET Project Health Audit. Analyzes tech stack
  (including .NET support lifecycle and dependency vulnerabilities),
  architecture (including SOLID compliance and cyclomatic complexity), API
  design, data layer, testing, code quality, CI/CD, and documentation.
  Produces a Google Docs-ready report with section scores and weighted
  overall score.
---

# .NET Project Health Audit

Execute the .NET Project Health Audit through modular rules organized in
execution waves. Each rule produces output that feeds into the final report.

## Execution Discipline (NON-NEGOTIABLE)

- NEVER skip, combine, or abbreviate any step
- NEVER summarize a reference file instead of executing it
- ALWAYS read each reference file completely, then follow ALL its instructions
- ALWAYS log completion after each step: "STEP N COMPLETED: [result summary]"
- NEVER proceed to the next step without completing the current one
- If a step fails: document the failure and attempt recovery before moving on

## Wave 0: Environment Setup (MANDATORY on restore/build failure only - Sequential) # model: cheap

Read `dotnet-health-audit/references/tool-installer.md` and follow ALL instructions in the prompt field
STEP 0a COMPLETED: [log result] # model: cheap

Read `dotnet-health-audit/references/version-alignment.md` and follow ALL instructions in the prompt field
STEP 0b COMPLETED: [log result] # model: cheap

Read `dotnet-health-audit/references/version-validator.md` and follow ALL instructions in the prompt field
STEP 0c COMPLETED: [log result] # model: cheap

Read `dotnet-health-audit/references/test-coverage.md` and follow ALL instructions in the prompt field
STEP 0d COMPLETED: [log result] # model: cheap

CRITICAL: If `dotnet restore`/`dotnet build` fails, STOP execution and provide resolution steps. An SDK version mismatch alone does NOT stop execution.

## Wave 1: Structure Analysis (Parallelizable) # model: cheap

These steps are independent and can be executed in parallel if supported:

Read `dotnet-health-audit/references/repository-inventory.md` and follow ALL instructions in the prompt field
STEP 1 COMPLETED: [log result] # model: cheap

Read `dotnet-health-audit/references/config-analysis.md` and follow ALL instructions in the prompt field
STEP 2 COMPLETED: [log result] # model: cheap

Read `dotnet-health-audit/references/support-lifecycle-analysis.md` and follow ALL instructions in the prompt field
STEP 3 COMPLETED: [log result] # model: cheap

## Wave 2: Infrastructure Analysis (Parallelizable)

These steps are independent and can be executed in parallel if supported:

Read `dotnet-health-audit/references/cicd-analysis.md` and follow ALL instructions in the prompt field
STEP 4 COMPLETED: [log result] # model: mid

Read `dotnet-health-audit/references/testing-analysis.md` and follow ALL instructions in the prompt field
STEP 5 COMPLETED: [log result] # model: mid

Read `dotnet-health-audit/references/code-quality.md` and follow ALL instructions in the prompt field
STEP 6 COMPLETED: [log result] # model: mid

Read `dotnet-health-audit/references/dependency-security-analysis.md` and follow ALL instructions in the prompt field
STEP 7 COMPLETED: [log result] # model: mid

## Wave 3: Domain Analysis (Parallelizable)

These steps are independent and can be executed in parallel if supported:

Read `dotnet-health-audit/references/api-design-analysis.md` and follow ALL instructions in the prompt field
STEP 8 COMPLETED: [log result] # model: mid

Read `dotnet-health-audit/references/data-layer-analysis.md` and follow ALL instructions in the prompt field
STEP 9 COMPLETED: [log result] # model: mid

Read `dotnet-health-audit/references/solid-compliance-analysis.md` and follow ALL instructions in the prompt field
STEP 10 COMPLETED: [log result] # model: mid

## Wave 4: Documentation Analysis (Sequential)

Read `dotnet-health-audit/references/documentation-analysis.md` and follow ALL instructions in the prompt field
STEP 11 COMPLETED: [log result] # model: cheap

## Wave 5: Report Format Enforcement (Sequential) # model: frontier

Read `dotnet-health-audit/references/report-format-enforcer.md` and follow ALL instructions in the prompt field
STEP 12 COMPLETED: [log result] # model: frontier

## Wave 6: Report (Sequential - Requires ALL previous results) # model: frontier

Read `dotnet-health-audit/references/report-generator.md` and follow ALL instructions in the prompt field
STEP 13 COMPLETED: [log result] # model: frontier

Save the final Markdown report to `./reports/dotnet_audit.md`
STEP 14 COMPLETED: Report exported # model: frontier
