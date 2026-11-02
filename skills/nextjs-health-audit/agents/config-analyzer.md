---
name: config-analyzer
description: |
  Use this agent when extracting and tabulating configuration from a Next.js project's package.json, next.config.*, tsconfig.json, ESLint (eslint-config-next / @next/eslint-plugin-next), Prettier and .env files, and flagging configuration that hides errors, during a Next.js health audit.

  <example>
  Context: An orchestrator dispatches the config-analyzer as part of Wave 1 of a Next.js health audit.
  user: "Run a Next.js health audit on this project."
  assistant: "I will read package.json, next.config.*, tsconfig.json, the ESLint config and the .env templates, record the declared next/react ranges, the output mode, experimental flags, caching flags and security headers, and flag red flags such as typescript.ignoreBuildErrors or an eslint key. Findings will be saved to reports/.artifacts/nextjs-health-audit/step_02_config_analysis.md."
  <commentary>
  Reading configuration files and tabulating values against a checklist is extraction work — cheap tier.
  </commentary>
  </example>

  <example>
  Context: A reviewer suspects the build hides type errors.
  user: "Does next build skip type checking here?"
  assistant: "I will read next.config.* for typescript.ignoreBuildErrors and report the file and line, together with whether a separate typecheck script exists."
  <commentary>
  A key lookup in a config file — cheap tier.
  </commentary>
  </example>
model: cheap
color: green
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/config-analysis.md`. That file is the single source of truth for this analysis.

After completing the analysis, save your complete structured findings to:

`reports/.artifacts/nextjs-health-audit/step_02_config_analysis.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/nextjs-health-audit
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file.
