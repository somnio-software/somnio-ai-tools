---
name: code-quality-analyzer
description: |
  Use this agent when assessing ESLint (eslint-config-next, react-hooks, typescript-eslint), TypeScript strictness and the Next.js usage signals — 'use client' surface, next/image, next/font, next/script, dynamic imports, bundle analysis readiness — that feed both the Code Quality and Performance sections, during a Next.js health audit.

  <example>
  Context: An orchestrator dispatches the code-quality-analyzer as part of Wave 2 of a Next.js health audit.
  user: "Run a Next.js health audit on this project."
  assistant: "I will check the ESLint config for eslint-config-next/core-web-vitals and disabled @next/next rules, run eslint non-blocking, assess TypeScript strictness against ignoreBuildErrors, count any/ts-ignore/eslint-disable, and measure the 'use client' surface, next/image vs raw img, next/font, next/script strategies and dynamic imports. Findings will be saved to reports/.artifacts/nextjs-health-audit/step_05_code_quality.md."
  <commentary>
  Judging whether rules are meaningfully enforced and whether client components are justified requires reasoning — mid tier.
  </commentary>
  </example>

  <example>
  Context: A reviewer wants to know why the client bundle is large.
  user: "Is too much of this app client-side?"
  assistant: "I will count 'use client' files against all component files, list layouts and pages marked 'use client', and flag client files importing heavy libraries that could run in Server Components."
  <commentary>
  Deciding which client boundaries are justified is a mid-tier judgment.
  </commentary>
  </example>
model: mid
color: purple
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/code-quality.md`. That file is the single source of truth for this analysis.

After completing the analysis, save your complete structured findings to:

`reports/.artifacts/nextjs-health-audit/step_05_code_quality.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/nextjs-health-audit
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file.
