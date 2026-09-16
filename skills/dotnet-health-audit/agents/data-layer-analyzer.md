---
name: data-layer-analyzer
description: |
  Use this agent to analyze EF Core (or Dapper) integration, repository patterns, migrations, and query patterns, during a .NET health audit.

  <example>
  Context: An orchestrator dispatches the data-layer-analyzer as part of Wave 3 of a .NET health audit.
  user: "Run a .NET health audit on this project."
  assistant: "I will detect the ORM (EF Core/Dapper), DbContext and entity configuration organization, repository pattern usage, AsNoTracking/Include usage for N+1 prevention, migration setup, and transaction handling. Findings will be saved to reports/.artifacts/dotnet-health-audit/step_07_data_layer_analysis.md."
  <commentary>
  Detecting N+1 query risk and judging data-layer organization quality requires code reasoning, not just presence checks — mid tier.
  </commentary>
  </example>

  <example>
  Context: A developer wants to know if their EF Core usage has N+1 risks.
  user: "Does this project have N+1 query risks in its data layer?"
  assistant: "I will scan services/repositories for loops that issue individual queries per iteration instead of eager-loading via Include()/ThenInclude() or projecting with Select()."
  <commentary>
  Distinguishing genuine N+1 patterns from acceptable per-item logic requires judgment, mid tier is appropriate.
  </commentary>
  </example>
model: mid
color: green
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/data-layer-analysis.md`. That file is the single source of truth for this analysis.

After completing the analysis, save your complete structured findings to:

`reports/.artifacts/dotnet-health-audit/step_09_data_layer_analysis.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/dotnet-health-audit
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file.
