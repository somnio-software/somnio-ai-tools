# .NET SOLID Compliance Analysis

> Analyze C# code for SOLID principle violations (SRP, OCP, LSP, ISP, DIP) at the per-file/per-class level, and measure real cyclomatic complexity/coupling via a forced analyzer build.

---

Goal: Analyze the ASP.NET Core Web API codebase for concrete, per-file SOLID
principle violations — not project/solution scaffolding — and surface real
complexity/coupling measurements from a forced Roslyn analyzer build.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/dotnet/solid-principles.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/dotnet/solid-principles.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve the rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to that rule.
3. This is a MICRO-level audit: judge individual classes, methods, and
   interfaces for correctness — not whether the solution's overall
   architecture pattern is well-chosen.

ANALYSIS TARGETS:

1.  **Single Responsibility Principle** (`solid-principles.md` — Single
    Responsibility Principle):
    *   Flag classes whose constructor injects 6 or more dependencies (God
        Object smell) — count comma-separated constructor parameters in
        `public ClassName(...)`.
    *   Flag methods over ~50 lines that mix input validation, I/O
        (HTTP/DB/file/queue calls), and business-rule branching in the same
        method body.
    *   Flag `*Manager`, `*Helper`, or `*Utility` classes that have
        accumulated 10 or more unrelated public methods.

2.  **Open/Closed Principle** (`solid-principles.md` — Open/Closed Principle):
    *   Flag `switch` statements/expressions or `if-else if` chains that
        branch on an `enum` value or type discriminator and contain business
        logic.
    *   **Escalate to a higher-severity finding** when the same
        enum/discriminator is switched on in more than one location across
        the codebase — this is the concrete OCP violation: adding a new case
        requires touching every duplicated location instead of one
        polymorphic extension point. Cite both (or all) locations in the
        finding.

3.  **Liskov Substitution Principle** (`solid-principles.md` — Liskov
    Substitution Principle):
    *   Flag any overridden interface member or base-class member (including
        explicit interface implementations) whose body throws
        `NotImplementedException` or `NotSupportedException` — the
        implementation cannot be substituted for its contract without
        breaking caller expectations.

4.  **Interface Segregation Principle** (`solid-principles.md` — Interface
    Segregation Principle):
    *   Flag interfaces with 8 or more members where at least one
        implementation throws `NotImplementedException`/`NotSupportedException`
        for a subset of those members.
    *   Flag interfaces with 8 or more members where call-site usage shows
        most consumers depend on only 1-2 of the available members —
        recommend splitting by client-specific usage (role interfaces).

5.  **Dependency Inversion Principle** (`solid-principles.md` — Dependency
    Inversion Principle):
    *   Flag `new ConcreteServiceClass()` / `new ConcreteRepositoryClass()`
        instantiated inside another class's method or field initializer
        (excluding `Program.cs`, composition-root code, and factory classes,
        where concrete construction is expected).
    *   Only flag it where an interface for that same concern already exists
        elsewhere in the codebase and is used via DI in other classes — the
        detectable "abstraction exists but isn't used here" pattern. Cite the
        existing interface and where it's correctly used via DI.
    *   Do **not** flag `new` of DTOs, value objects, records, POCOs,
        exceptions, or framework/BCL collection types (`List<T>`,
        `Dictionary<K,V>`, etc.) — these are normal object construction, not
        DIP violations.

6.  **Cyclomatic Complexity / Coupling** (`solid-principles.md` — Cyclomatic
    Complexity):
    *   This requires actually compiling the code — grep alone cannot measure
        true cyclomatic complexity. Run a build with the built-in .NET
        analyzers forced on for THIS audit run only, regardless of whether
        the target repo's `.csproj` / `Directory.Build.props` /
        `.editorconfig` currently enable them or suppress these rules:
        ```
        dotnet build <solution-or-project> -p:EnableNETAnalyzers=true -p:AnalysisLevel=latest-all -p:AnalysisMode=All --no-restore 2>&1 | grep -E "CA1502|CA1506"
        ```
        (use `findstr` in place of `grep` on a Windows shell without a POSIX
        grep available)
    *   This is a command-line MSBuild property override only for this one
        invocation — it does **not** modify any file in the repo (no
        `.csproj`, `Directory.Build.props`, or `.editorconfig` is touched or
        persisted).
    *   Record every **CA1502** (excessive cyclomatic complexity, default
        threshold 25) warning as a violation, with the exact method and
        file:line the compiler reports.
    *   Record every **CA1506** (excessive class coupling) warning as a
        violation, with the exact class and file:line the compiler reports.
    *   Cross-reference large-file findings already available from other
        audit steps as corroborating context in the "Issue" description, but
        never substitute file size for an actual CA1502/CA1506 hit.

OUTPUT FORMAT:

Produce one entry per violation found:
*   **File**: `path/to/File.cs:42`
*   **Line**: best-effort line number (or line range) of the offending code
*   **Standard Violated**: `solid-principles.md` — cite the specific
    section: `Single Responsibility Principle`, `Open/Closed Principle`,
    `Liskov Substitution Principle`, `Interface Segregation Principle`,
    `Dependency Inversion Principle`, or `Cyclomatic Complexity`
*   **Severity**: `Critical` | `Major` | `Minor`
    *   `Critical`: LSP violation (`NotImplementedException`/
        `NotSupportedException` in an override), a duplicated OCP
        discriminator chain appearing in 3+ locations, or a CA1502 hit on a
        method in a controller/service on a critical request path
    *   `Major`: SRP God Object constructor/class, a single OCP discriminator
        chain with business logic, a fat ISP interface with partial
        implementation, a genuine DIP violation (abstraction exists but
        bypassed), any other CA1502/CA1506 hit
    *   `Minor`: a Manager/Helper/Utility class approaching but not yet over
        the 10-method threshold, a moderately long method not yet mixing all
        three concerns, an ISP interface with light, non-throwing underuse
*   **Suggested Fix**: one line, concrete and actionable

Example:

```
- File: src/MyApp.Application/Services/PaymentService.cs
  Line: 88
  Standard Violated: solid-principles.md — Dependency Inversion Principle
  Severity: Major
  Suggested Fix: Inject IInvoiceGenerator (already used via DI in ReportService.cs) instead of instantiating new InvoiceGenerator() directly.
```

Group violations by category (`[SRP]`, `[OCP]`, `[LSP]`, `[ISP]`, `[DIP]`,
`[Complexity]`) before listing the per-violation records.

After the violation list, include:
*   **Compliance**: notable examples of correct SOLID application already
    present in the codebase (e.g. a discriminator properly replaced with
    polymorphism, a role interface correctly split, DI used consistently for
    an abstraction elsewhere in the same module).
*   **Recommendations**: concrete refactoring advice grouped by principle
    (SRP, OCP, LSP, ISP, DIP, Complexity).

SCORING GUIDANCE:

*   **Strong (85-100)**: No SRP God Object constructors or bloated Manager/
    Helper/Utility classes; no duplicated OCP discriminator chains; zero LSP
    violations; no fat ISP interfaces with partial implementations; DIP
    respected everywhere an abstraction already exists; zero or near-zero
    CA1502/CA1506 hits from the forced analyzer build. At most a few Minor
    findings.
*   **Fair (70-84)**: Isolated SRP, ISP, or DIP violations not yet
    widespread; at most one duplicated OCP discriminator chain; no more than
    one or two isolated LSP violations; a moderate number of CA1502/CA1506
    hits concentrated in non-critical code. No Critical findings.
*   **Weak (0-69)**: One or more Critical findings (LSP violation, an OCP
    discriminator duplicated across 3+ locations, or a CA1502 hit in a
    critical-path controller/service), or Major findings (SRP God Objects,
    fat ISP interfaces, genuine DIP violations) pervasive across most
    classes/services.
