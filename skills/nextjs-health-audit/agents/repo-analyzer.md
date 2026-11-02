---
name: repo-analyzer
description: |
  Use this agent when inventorying a Next.js project's repository structure: router model (App Router, Pages Router or mixed), route conventions, special files (proxy/middleware, instrumentation), output mode, bundler, monorepo layout and deploy target hints, during a Next.js health audit.

  <example>
  Context: An orchestrator dispatches the repo-analyzer as part of Wave 1 of a Next.js health audit.
  user: "Run a Next.js health audit on this project."
  assistant: "I will locate every package that depends on next, detect App Router vs Pages Router per app, count pages, Route Handlers, route groups, parallel and intercepting routes, check for proxy.ts or the deprecated middleware.ts, instrumentation.ts, the output mode and deploy hints, and measure component file sizes. Findings will be saved to reports/.artifacts/nextjs-health-audit/step_01_repository_inventory.md."
  <commentary>
  Repository inventory is find/grep/count work with light classification — cheap tier is appropriate.
  </commentary>
  </example>

  <example>
  Context: A team is midway through moving from the Pages Router to the App Router.
  user: "How much of this app still lives in pages/?"
  assistant: "I will list both app/ and pages/ routes, mark the router model as Mixed, and report which routes remain under pages/ and whether pages/api handlers have App Router route.ts equivalents."
  <commentary>
  Counting and listing route files is mechanical discovery, cheap tier.
  </commentary>
  </example>
model: cheap
color: blue
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/repository-inventory.md`. That file is the single source of truth for this analysis.

After completing the analysis, save your complete structured findings to:

`reports/.artifacts/nextjs-health-audit/step_01_repository_inventory.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/nextjs-health-audit
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file.
