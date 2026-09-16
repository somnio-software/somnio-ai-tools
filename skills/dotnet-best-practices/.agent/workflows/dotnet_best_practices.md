---
description: >-
  Execute a micro-level .NET / ASP.NET Core code quality audit. Validates
  code against live GitHub standards for testing, architecture compliance,
  SOLID principles, cyclomatic complexity, code standards, DTO validation,
  and error handling. Produces a detailed violations report with
  prioritized action plan.
---

# .NET Micro-Code Audit

Execute a deep-dive analysis of the .NET / ASP.NET Core codebase focusing
on micro-level code quality and adherence to specific standards.

## Execution Discipline (NON-NEGOTIABLE)

- NEVER skip, combine, or abbreviate any step
- NEVER summarize a reference file instead of executing it
- ALWAYS read each reference file completely, then follow ALL its instructions
- ALWAYS log completion after each step: "STEP N COMPLETED: [result summary]"
- NEVER proceed to the next step without completing the current one
- If a step fails: document the failure and attempt recovery before moving on

## Wave 1: Reasoning Analysis (Parallelizable) # model: mid

Read `dotnet-best-practices/references/testing-quality.md` and follow ALL instructions in the prompt field
STEP 1 COMPLETED: [log result] # model: mid

Read `dotnet-best-practices/references/architecture-compliance.md` and follow ALL instructions in the prompt field
STEP 2 COMPLETED: [log result] # model: mid

Read `dotnet-best-practices/references/solid-compliance.md` and follow ALL instructions in the prompt field
STEP 3 COMPLETED: [log result] # model: mid

Read `dotnet-best-practices/references/code-standards.md` and follow ALL instructions in the prompt field
STEP 4 COMPLETED: [log result] # model: mid

## Wave 2: Mechanical Scans (Parallelizable) # model: cheap

Read `dotnet-best-practices/references/dto-validation.md` and follow ALL instructions in the prompt field
STEP 5 COMPLETED: [log result] # model: cheap

Read `dotnet-best-practices/references/error-handling.md` and follow ALL instructions in the prompt field
STEP 6 COMPLETED: [log result] # model: cheap

## Wave 3: Report Generation (Sequential - Requires ALL previous results) # model: frontier

Read `dotnet-best-practices/references/best-practices-format-enforcer.md` and follow ALL instructions in the prompt field
STEP 7 COMPLETED: [log result] # model: frontier

Read `dotnet-best-practices/references/best-practices-generator.md` and follow ALL instructions in the prompt field
STEP 8 COMPLETED: [log result] # model: frontier

Save the final Markdown report to `./reports/dotnet-best-practices-report.md`
STEP 9 COMPLETED: Report exported # model: frontier
