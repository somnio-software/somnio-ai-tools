---
description: >-
  Execute a micro-level React code quality audit. Validates code against live
  GitHub standards for testing, component architecture, hooks patterns, state
  management, performance, and TypeScript. Produces a detailed violations
  report with prioritized action plan.
---

# React Best Practices Check

Execute the React Micro-Code Audit through the orchestrator-driven multi-agent pipeline.
The orchestrator dispatches subagents in dependency-ordered waves and advances only after
confirming artifacts exist.

## Orchestrator Entry Point

Read `react-best-practices/agents/orchestrator.md` and follow ALL instructions.
The orchestrator drives the full three-wave plan below.

---

## Wave 1 — Cheap Scanners (parallel) # model: cheap

Dispatched by the orchestrator simultaneously:

### Step 1: TypeScript Scan # model: cheap

Read `react-best-practices/agents/typescript-scanner.md` and follow ALL instructions.
Writes: `reports/.artifacts/react-best-practices/step_01_typescript_scan.md`

### Step 2: Architecture Scan # model: cheap

Read `react-best-practices/agents/architecture-scanner.md` and follow ALL instructions.
Writes: `reports/.artifacts/react-best-practices/step_02_architecture_scan.md`

---

## Wave 2 — Reasoning Analyzers (parallel) # model: mid

Only starts after Wave 1 artifacts are confirmed. Dispatched simultaneously:

### Step 3: Testing Quality Analysis # model: mid

Read `react-best-practices/agents/testing-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/react-best-practices/step_03_testing_quality.md`

### Step 4: Architecture Analysis # model: mid

Read `react-best-practices/agents/architecture-analyzer.md` and follow ALL instructions.
Consumes: `step_02_architecture_scan.md`
Writes: `reports/.artifacts/react-best-practices/step_04_architecture_analysis.md`

### Step 5: Hooks Patterns Analysis # model: mid

Read `react-best-practices/agents/hooks-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/react-best-practices/step_05_hooks_analysis.md`

### Step 6: State Management Analysis # model: mid

Read `react-best-practices/agents/state-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/react-best-practices/step_06_state_analysis.md`

### Step 7: Performance Analysis # model: mid

Read `react-best-practices/agents/performance-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/react-best-practices/step_07_performance_analysis.md`

---

## Wave 3 — Report Writer (frontier) # model: frontier

Only starts after all Wave 2 artifacts are confirmed.

### Step 8: Report Generation # model: frontier

Read `react-best-practices/agents/report-writer.md` and follow ALL instructions.
Reads: all seven step artifacts + `assets/report-template.md`
Writes: `reports/react-best-practices-report.md`
