---
name: solid-compliance-analyzer
description: |
  Use this agent to evaluate conformance to agent-rules/rules/dotnet/solid-principles.md during a .NET best-practices micro-code audit, including real cyclomatic complexity measurement via a forced-on analyzer build.

  <example>
  Context: An orchestrator dispatches solid-compliance-analyzer as part of Wave 1 of a .NET best-practices audit.
  user: "Check this .NET project's SOLID compliance."
  assistant: "I will scan for SRP (god-object constructors), OCP (type-switch chains with business logic), LSP (NotImplementedException overrides), ISP (fat interfaces), and DIP (new ConcreteClass() bypassing an existing abstraction), then run `dotnet build -p:EnableNETAnalyzers=true -p:AnalysisLevel=latest-all -p:AnalysisMode=All --no-restore` to force CA1502/CA1506 warnings regardless of the repo's own analyzer settings, without modifying any file."
  <commentary>
  Judging SOLID violations requires code comprehension across files and interpreting forced-analyzer output requires reasoning — mid tier is appropriate.
  </commentary>
  </example>

  <example>
  Context: A developer wants to know if a class violates the Dependency Inversion Principle.
  user: "Does this class violate DIP?"
  assistant: "I will check whether the class does `new ConcreteServiceClass()` internally when an interface for that same concern already exists and is used via DI elsewhere in the codebase — that's the detectable DIP violation signal, as opposed to instantiating simple DTOs or framework collection types."
  <commentary>
  Distinguishing a genuine DIP violation from benign `new` usage (DTOs, collections) requires judgment, mid tier.
  </commentary>
  </example>
model: mid
color: yellow
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/solid-compliance.md`. That file is the single source of truth for this analysis, and it will direct you to validate against `agent-rules/rules/dotnet/solid-principles.md` (local-first, GitHub raw fallback).

After completing the analysis, save your complete structured findings (per-violation records: file, line, SOLID principle violated, severity, suggested fix) to:

`reports/.artifacts/dotnet-best-practices/step_03_solid_compliance.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/dotnet-best-practices
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file.
