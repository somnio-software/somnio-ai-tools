---
name: solid-compliance-analyzer
description: |
  Use this agent to assess SOLID principle adherence and measure real cyclomatic complexity (via a forced-on Roslyn analyzer build, no files modified) during a .NET health audit.

  <example>
  Context: An orchestrator dispatches the solid-compliance-analyzer as part of Wave 3 of a .NET health audit.
  user: "Run a .NET health audit on this project."
  assistant: "I will check for SRP/OCP/LSP/ISP/DIP violations using the heuristics in agent-rules/rules/dotnet/solid-principles.md, then run `dotnet build -p:EnableNETAnalyzers=true -p:AnalysisLevel=latest-all -p:AnalysisMode=All` to force CA1502/CA1506 warnings regardless of the repo's own analyzer settings, without modifying any file. Findings will be saved to reports/.artifacts/dotnet-health-audit/step_10_solid_compliance_analysis.md."
  <commentary>
  Judging SOLID violations requires code comprehension across files, and interpreting forced-analyzer output requires reasoning — mid tier is appropriate.
  </commentary>
  </example>

  <example>
  Context: A developer wants to know the real cyclomatic complexity of their codebase, even though analyzers are disabled in their .csproj.
  user: "What's the cyclomatic complexity of this project? We don't have analyzers enabled."
  assistant: "I will run a one-off `dotnet build` with -p:EnableNETAnalyzers=true -p:AnalysisLevel=latest-all forced on the command line — this doesn't touch your .csproj or .editorconfig, it only affects this single build invocation — and parse the resulting CA1502 warnings for real complexity numbers."
  <commentary>
  Interpreting forced analyzer output and correlating it with architecture findings requires reasoning, mid tier.
  </commentary>
  </example>
model: mid
color: green
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/solid-compliance-analysis.md`. That file is the single source of truth for this analysis, and it will direct you to validate against `agent-rules/rules/dotnet/solid-principles.md` (local-first, GitHub raw fallback).

After completing the analysis, save your complete structured findings to:

`reports/.artifacts/dotnet-health-audit/step_10_solid_compliance_analysis.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/dotnet-health-audit
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file. Remember: these findings feed into the existing Architecture report section — they do not create a new section.
