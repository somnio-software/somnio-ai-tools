---
description: >-
  Version-aware Next.js code quality audit (App Router, Server Components).
  Triggers: 'nextjs best practices', 'nextjs code review', 'app router best
  practices'.
---

# Next.js Best Practices Check

Execute the Next.js Micro-Code Audit through the orchestrator-driven multi-agent pipeline.
The orchestrator dispatches subagents in dependency-ordered waves and advances only after
confirming artifacts exist.

## Orchestrator Entry Point

Read `nextjs-best-practices/agents/orchestrator.md` and follow ALL instructions.
The orchestrator drives the full three-wave plan below.

---

## Wave 1 — Cheap Scanners (parallel) # model: cheap

Dispatched by the orchestrator simultaneously:

### Step 1: Project Scan # model: cheap

Read `nextjs-best-practices/agents/project-scanner.md` and follow ALL instructions.
Resolves the installed Next.js version and the version-matched docs source.
Writes: `reports/.artifacts/nextjs-best-practices/step_01_project_scan.md`

### Step 2: TypeScript Scan # model: cheap

Read `nextjs-best-practices/agents/typescript-scanner.md` and follow ALL instructions.
Writes: `reports/.artifacts/nextjs-best-practices/step_02_typescript_scan.md`

---

## Wave 2 — Reasoning Analyzers (parallel) # model: mid

Only starts after Wave 1 artifacts are confirmed. Dispatched simultaneously; each consumes
`step_01_project_scan.md` for the installed version and docs source:

### Step 3: App Router Architecture Analysis # model: mid

Read `nextjs-best-practices/agents/architecture-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/nextjs-best-practices/step_03_app_router_architecture.md`

### Step 4: Server & Client Components Analysis # model: mid

Read `nextjs-best-practices/agents/components-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/nextjs-best-practices/step_04_server_client_components.md`

### Step 5: Data Fetching & Caching Analysis # model: mid

Read `nextjs-best-practices/agents/data-fetching-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/nextjs-best-practices/step_05_data_fetching_caching.md`

### Step 6: Server Actions & Route Handlers Analysis # model: mid

Read `nextjs-best-practices/agents/actions-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/nextjs-best-practices/step_06_server_actions_route_handlers.md`

### Step 7: Rendering Performance Analysis # model: mid

Read `nextjs-best-practices/agents/performance-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/nextjs-best-practices/step_07_rendering_performance.md`

### Step 8: Testing Quality Analysis # model: mid

Read `nextjs-best-practices/agents/testing-analyzer.md` and follow ALL instructions.
Writes: `reports/.artifacts/nextjs-best-practices/step_08_testing_quality.md`

---

## Wave 3 — Report Writer (frontier) # model: frontier

Only starts after all Wave 2 artifacts are confirmed.

### Step 9: Report Generation # model: frontier

Read `nextjs-best-practices/agents/report-writer.md` and follow ALL instructions.
Reads: all eight step artifacts + `assets/report-template.md`
Writes: `reports/<YYYY-MM-DD>-<project>-nextjs-best-practices.md`
