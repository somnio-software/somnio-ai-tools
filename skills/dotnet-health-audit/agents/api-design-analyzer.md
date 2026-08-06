---
name: api-design-analyzer
description: |
  Use this agent to analyze Controllers/Minimal API design, DTOs, validation patterns, OpenAPI/Swagger documentation, and API versioning, during a .NET health audit.

  <example>
  Context: An orchestrator dispatches the api-design-analyzer as part of Wave 3 of a .NET health audit.
  user: "Run a .NET health audit on this project."
  assistant: "I will detect whether the API uses Controllers or Minimal APIs, verify HTTP verb usage and RESTful URL naming, check for Asp.Versioning usage, DTO validation coverage, and Swagger/Swashbuckle configuration. Findings will be saved to reports/.artifacts/dotnet-health-audit/step_06_api_design_analysis.md."
  <commentary>
  Judging API design quality (versioning consistency, RESTful conventions, validation coverage) requires reasoning about production-readiness — mid tier.
  </commentary>
  </example>

  <example>
  Context: A developer wants to know if their API follows REST conventions.
  user: "Does this ASP.NET Core API follow RESTful conventions?"
  assistant: "I will check HTTP verb-to-action mapping, resource-based URL naming, and whether a versioning strategy (URI or header-based) is consistently applied across controllers."
  <commentary>
  Evaluating convention compliance and consistency across many endpoints requires judgment, mid tier is appropriate.
  </commentary>
  </example>
model: mid
color: green
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/api-design-analysis.md`. That file is the single source of truth for this analysis.

After completing the analysis, save your complete structured findings to:

`reports/.artifacts/dotnet-health-audit/step_08_api_design_analysis.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/dotnet-health-audit
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file.
