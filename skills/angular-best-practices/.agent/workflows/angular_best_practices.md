---
description: >-
  Execute a micro-level modern Angular (2+/Angular CLI, TypeScript) code quality
  audit. Validates code against live GitHub standards for testing, component &
  module architecture, lifecycle & DI patterns, services & RxJS/signals state,
  change detection & performance, and TypeScript. Produces a detailed violations
  report with prioritized action plan. NOT for AngularJS 1.x.
---

# Angular Best Practices Check

Execute the Angular Micro-Code Audit through the orchestrator-driven multi-agent pipeline.
The orchestrator dispatches subagents in dependency-ordered waves and advances only after
confirming artifacts exist. Targets modern Angular 2+ (components, modules/standalone, DI,
RxJS/signals) — NOT legacy AngularJS 1.x.

## Orchestrator Entry Point

Read `angular-best-practices/agents/orchestrator.md` and follow ALL instructions.
The orchestrator drives the full three-wave plan below.

---

## Wave 1 — Cheap Scanners (parallel) # model: cheap

Dispatched by the orchestrator simultaneously:

### Step 1: TypeScript Scan # model: cheap

Read `angular-best-practices/agents/typescript-scanner.md` and follow ALL instructions.
Writes: `reports/.artifacts/angular-best-practices/step_01_typescript_scan.md`

### Step 2: Architecture Scan # model: cheap

Read `angular-best-practices/agents/architecture-scanner.md` and follow ALL instructions.
Writes: `reports/.artifacts/angular-best-practices/step_02_architecture_scan.md`

---

## Wave 2 — Reasoning Analyzers (parallel) # model: mid

Only starts after Wave 1 artifacts are confirmed. Dispatched simultaneously:

### Step 3: Testing Quality Analysis # model: mid

Read `angular-best-practices/agents/testing-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/angular-best-practices/step_03_testing_quality.md`

### Step 4: Architecture Analysis # model: mid

Read `angular-best-practices/agents/architecture-analyzer.md` and follow ALL instructions.
Consumes: `step_02_architecture_scan.md`
Writes: `reports/.artifacts/angular-best-practices/step_04_architecture_analysis.md`

### Step 5: Lifecycle & DI Patterns Analysis # model: mid

Read `angular-best-practices/agents/hooks-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/angular-best-practices/step_05_hooks_analysis.md`

### Step 6: Services & State Management Analysis # model: mid

Read `angular-best-practices/agents/state-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/angular-best-practices/step_06_state_analysis.md`

### Step 7: Change Detection & Performance Analysis # model: mid

Read `angular-best-practices/agents/performance-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/angular-best-practices/step_07_performance_analysis.md`

---

## Wave 3 — Report Writer (frontier) # model: frontier

Only starts after all Wave 2 artifacts are confirmed.

### Step 8: Report Generation # model: frontier

Read `angular-best-practices/agents/report-writer.md` and follow ALL instructions.
Reads: all seven step artifacts + `assets/report-template.md`
Writes: `reports/angular-best-practices-report.md`
