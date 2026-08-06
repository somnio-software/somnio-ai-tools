---
name: repo-analyzer
description: |
  Use this agent when inventorying a .NET solution's structure, detecting project types (Web API, Blazor, Worker Service, class library), analyzing layering patterns, and producing the repository inventory artifact during a .NET health audit.

  <example>
  Context: An orchestrator dispatches the repo-analyzer as part of Wave 1 of a .NET health audit.
  user: "Run a .NET health audit on this project."
  assistant: "I will detect the solution/project structure, identify project types from each .csproj's SDK attribute, count controllers/endpoint groups, and analyze Clean Architecture vs flat layering. Findings will be saved to reports/.artifacts/dotnet-health-audit/step_01_repository_inventory.md."
  <commentary>
  Repository inventory is a filesystem scan — SDK attribute detection from .csproj, directory enumeration, controller counts — requiring no judgment. This is a cheap-tier mechanical task.
  </commentary>
  </example>

  <example>
  Context: A developer wants to know the layering pattern of their .NET solution.
  user: "What is the project layering of this .NET solution?"
  assistant: "I will read each .csproj and list directory contents to detect whether the solution uses Clean Architecture (Domain/Application/Infrastructure/Api) or a flat single-project structure, and count controllers/services/repositories per project."
  <commentary>
  Layering detection is a find/ls + grep operation, not a reasoning task — cheap tier is appropriate.
  </commentary>
  </example>
model: cheap
color: blue
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/repository-inventory.md`. That file is the single source of truth for this analysis.

After completing the analysis, save your complete structured findings to:

`reports/.artifacts/dotnet-health-audit/step_01_repository_inventory.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/dotnet-health-audit
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file.
