---
name: dto-validation-scanner
description: |
  Use this agent to evaluate conformance to agent-rules/rules/dotnet/dto-validation.md during a .NET best-practices micro-code audit.

  <example>
  Context: An orchestrator dispatches dto-validation-scanner as part of Wave 2 of a .NET best-practices audit.
  user: "Check this .NET project's DTO validation coverage."
  assistant: "I will scan DTO/Contracts folders for record-based immutability, Create/Update/Response separation, Data Annotations/FluentValidation coverage on inbound properties, and sensitive field exclusion from response DTOs."
  <commentary>
  Enumerating DTOs and checking validation attribute presence is a mostly mechanical scan — cheap tier is appropriate.
  </commentary>
  </example>

  <example>
  Context: A developer wants to know if any DTO leaks a sensitive field.
  user: "Do any response DTOs expose sensitive fields?"
  assistant: "I will check response DTOs for fields like PasswordHash, SecurityStamp, or raw tokens that should never be serialized to clients."
  <commentary>
  Checking for known sensitive field names in DTO definitions is a mechanical scan, cheap tier.
  </commentary>
  </example>
model: cheap
color: green
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/dto-validation.md`. That file is the single source of truth for this analysis, and it will direct you to validate against `agent-rules/rules/dotnet/dto-validation.md` (local-first, GitHub raw fallback).

After completing the analysis, save your complete structured findings (per-violation records: file, line, standard violated, severity, suggested fix) to:

`reports/.artifacts/dotnet-best-practices/step_05_dto_validation.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/dotnet-best-practices
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file.
