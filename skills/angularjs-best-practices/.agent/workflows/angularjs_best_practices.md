---
description: >-
  Execute a micro-level AngularJS (Angular 1.x) code quality audit. Validates
  code against live GitHub standards for testing, module/component
  architecture, scope & binding patterns, services & data flow, digest
  performance, and minification-safe JavaScript standards. Produces a detailed
  violations report with prioritized action plan.
---

# AngularJS Best Practices Check

Execute the AngularJS Micro-Code Audit through the orchestrator-driven multi-agent pipeline.
The orchestrator dispatches subagents in dependency-ordered waves and advances only after
confirming artifacts exist.

## Orchestrator Entry Point

Read `angularjs-best-practices/agents/orchestrator.md` and follow ALL instructions.
The orchestrator drives the full three-wave plan below.

---

## Wave 1 — Cheap Scanners (parallel) # model: cheap

Dispatched by the orchestrator simultaneously:

### Step 1: JavaScript Scan # model: cheap

Read `angularjs-best-practices/agents/typescript-scanner.md` and follow ALL instructions.
Writes: `reports/.artifacts/angularjs-best-practices/step_01_javascript_scan.md`

### Step 2: Architecture Scan # model: cheap

Read `angularjs-best-practices/agents/architecture-scanner.md` and follow ALL instructions.
Writes: `reports/.artifacts/angularjs-best-practices/step_02_architecture_scan.md`

---

## Wave 2 — Reasoning Analyzers (parallel) # model: mid

Only starts after Wave 1 artifacts are confirmed. Dispatched simultaneously:

### Step 3: Testing Quality Analysis # model: mid

Read `angularjs-best-practices/agents/testing-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/angularjs-best-practices/step_03_testing_quality.md`

### Step 4: Architecture Analysis # model: mid

Read `angularjs-best-practices/agents/architecture-analyzer.md` and follow ALL instructions.
Consumes: `step_02_architecture_scan.md`
Writes: `reports/.artifacts/angularjs-best-practices/step_04_architecture_analysis.md`

### Step 5: Scope & Binding Patterns Analysis # model: mid

Read `angularjs-best-practices/agents/hooks-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/angularjs-best-practices/step_05_scope_binding_analysis.md`

### Step 6: State Management Analysis # model: mid

Read `angularjs-best-practices/agents/state-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/angularjs-best-practices/step_06_state_analysis.md`

### Step 7: Performance Analysis # model: mid

Read `angularjs-best-practices/agents/performance-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/angularjs-best-practices/step_07_performance_analysis.md`

---

## Wave 3 — Report Writer (frontier) # model: frontier

Only starts after all Wave 2 artifacts are confirmed.

### Step 8: Report Generation # model: frontier

Read `angularjs-best-practices/agents/report-writer.md` and follow ALL instructions.
Reads: all seven step artifacts + `assets/report-template.md`
Writes: `reports/angularjs-best-practices-report.md`
