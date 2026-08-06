---
name: dependency-security-analyzer
description: |
  Use this agent to identify vulnerable and outdated NuGet packages via `dotnet list package --vulnerable`/`--outdated`, during a .NET health audit.

  <example>
  Context: An orchestrator dispatches the dependency-security-analyzer as part of Wave 2 of a .NET health audit.
  user: "Run a .NET health audit on this project."
  assistant: "I will run dotnet list package --vulnerable --include-transitive and --outdated --include-transitive against the solution, parse severity and version-drift, and prioritize direct Critical/High findings first. Findings will be saved to reports/.artifacts/dotnet-health-audit/step_07_dependency_security_analysis.md."
  <commentary>
  Interpreting severity and prioritizing direct vs transitive fixes requires judgment — mid tier is appropriate.
  </commentary>
  </example>

  <example>
  Context: A developer wants to know if any of their NuGet packages are known-vulnerable.
  user: "Does this .NET project have any vulnerable dependencies?"
  assistant: "I will run dotnet list package --vulnerable --include-transitive and report each finding with its severity, GHSA advisory, and whether it's direct or transitive."
  <commentary>
  Parsing structured CLI output and judging severity/fix-path requires reasoning, mid tier.
  </commentary>
  </example>
model: mid
color: yellow
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/dependency-security-analysis.md`. That file is the single source of truth for this analysis.

After completing the analysis, save your complete structured findings to:

`reports/.artifacts/dotnet-health-audit/step_07_dependency_security_analysis.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/dotnet-health-audit
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file. Remember: these findings feed into the existing Tech Stack report section — they do not create a new section. For deeper security analysis, note that the standalone Security Audit skill (`/somnio:security-audit`) is available.
