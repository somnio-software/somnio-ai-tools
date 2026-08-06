---
name: cicd-analyzer
description: |
  Use this agent to analyze CI/CD pipeline definitions (GitHub Actions, Azure Pipelines, GitLab CI) and Docker setup for a .NET build, during a .NET health audit.

  <example>
  Context: An orchestrator dispatches the cicd-analyzer as part of Wave 2 of a .NET health audit.
  user: "Run a .NET health audit on this project."
  assistant: "I will read the CI pipeline definition, verify it runs dotnet restore/build/test with coverage collection, check for setup-dotnet SDK pinning and NuGet caching, and inspect the Dockerfile for a proper multi-stage SDK/runtime build. Findings will be saved to reports/.artifacts/dotnet-health-audit/step_03_cicd_analysis.md."
  <commentary>
  CI/CD compliance requires judging whether pipeline steps and gates are adequate, not just detecting presence — mid tier is appropriate.
  </commentary>
  </example>

  <example>
  Context: A developer wants to know if their Docker setup follows best practices.
  user: "Is this project's Dockerfile following .NET best practices?"
  assistant: "I will check whether it uses a multi-stage build with mcr.microsoft.com/dotnet/sdk for building and mcr.microsoft.com/dotnet/aspnet for the runtime image, flagging single-stage SDK-image-as-runtime as bloated."
  <commentary>
  Judging Dockerfile quality against known best practices requires reasoning about tradeoffs — mid tier.
  </commentary>
  </example>
model: mid
color: yellow
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/cicd-analysis.md`. That file is the single source of truth for this analysis.

After completing the analysis, save your complete structured findings to:

`reports/.artifacts/dotnet-health-audit/step_04_cicd_analysis.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/dotnet-health-audit
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file.
