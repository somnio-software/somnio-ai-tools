---
name: code-standards-analyzer
description: |
  Use this agent to evaluate conformance to agent-rules/rules/dotnet/csharp.md and controller-patterns.md during a .NET best-practices micro-code audit.

  <example>
  Context: An orchestrator dispatches code-standards-analyzer as part of Wave 1 of a .NET best-practices audit.
  user: "Check this .NET project's code standards."
  assistant: "I will validate naming conventions, nullable reference type discipline (flagging excessive null-forgiving operator use), records vs classes usage, LINQ correctness, and controller thinness against csharp.md and controller-patterns.md."
  <commentary>
  Judging idiomatic C# usage and controller thinness requires code comprehension — mid tier.
  </commentary>
  </example>

  <example>
  Context: A developer wants to know if their code fights nullable reference types.
  user: "Is this codebase actually respecting nullable reference types?"
  assistant: "I will grep for the null-forgiving operator (!) and check whether it's used sparingly and justifiably, or pervasively as a way to silence the compiler."
  <commentary>
  Distinguishing justified use from "fighting" nullable requires judgment across many call sites, mid tier.
  </commentary>
  </example>
model: mid
color: yellow
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/code-standards.md`. That file is the single source of truth for this analysis, and it will direct you to validate against `agent-rules/rules/dotnet/csharp.md` and `controller-patterns.md` (local-first, GitHub raw fallback).

After completing the analysis, save your complete structured findings (per-violation records: file, line, standard violated, severity, suggested fix) to:

`reports/.artifacts/dotnet-best-practices/step_04_code_standards.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/dotnet-best-practices
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file.
