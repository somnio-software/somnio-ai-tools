# .NET Code Standards & Best Practices Analysis

> Analyze C# code quality, ASP.NET Core patterns, naming conventions, and general coding standards.

---

Goal: Analyze the ASP.NET Core Web API codebase for specific code standards and
C# best practices.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/dotnet/csharp.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/dotnet/csharp.md
- local: `agent-rules/rules/dotnet/controller-patterns.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/dotnet/controller-patterns.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **Naming Conventions**:
    *   **PascalCase**: Classes, records, structs, interfaces, enums,
        methods, properties, events, and namespaces.
    *   **Interface Prefix**: Interfaces should be prefixed with `I`
        (e.g. `IUserRepository`).
    *   **camelCase**: Local variables and method parameters.
    *   **Private Fields**: Private fields should use `_camelCase`
        (leading underscore).
    *   **Constants**: `const` and `static readonly` fields should use
        PascalCase, not `UPPER_CASE`.

2.  **Nullable Reference Types**:
    *   **Enabled**: Check that `<Nullable>enable</Nullable>` is set in
        the project file and genuinely respected, not disabled per-file
        with `#nullable disable`.
    *   **Null-Forgiving Overuse**: Flag excessive use of the `!`
        null-forgiving operator — this is "fighting" the nullable
        annotation system instead of embracing it (proper narrowing,
        `ArgumentNullException.ThrowIfNull`, or redesigning the API to
        avoid the null state).
    *   **Guard Clauses**: Verify public API entry points validate
        required parameters with `ArgumentNullException.ThrowIfNull` or
        equivalent instead of relying on the runtime NullReferenceException.

3.  **Records vs. Classes**:
    *   **Records for Immutable Data**: Check that DTOs and value
        objects are implemented as `record` or `record struct` types
        where identity is defined by value, not reference.
    *   **Classes for Entities**: Check that EF Core entities (identity
        defined by a key, mutable over their lifetime) are implemented
        as `class`, not `record` — flag entities modeled as records
        (value-equality semantics mismatch identity semantics).

4.  **Pattern Matching**:
    *   **Switch Expressions**: Check for `switch` expressions and
        property/relational patterns used in place of long `if`/`else if`
        chains or verbose `switch` statements.
    *   **Type Patterns**: Check for `is` pattern matching (including
        `is not null`) instead of `== null` comparisons combined with casts.

5.  **LINQ Correctness**:
    *   **Multiple Enumeration**: Flag `IEnumerable<T>` parameters or
        locals that are enumerated more than once (e.g. a `.Count()`
        followed by a `foreach`) without materializing via `.ToList()` /
        `.ToArray()` first — each enumeration may re-run the query
        (especially costly against `IQueryable<T>`/EF Core).
    *   **Existence Checks**: Flag `.Count() > 0` / `.Count() == 0` used
        for existence checks — should be `.Any()` / `!.Any()`.

6.  **Namespace Style**:
    *   **File-Scoped Namespaces**: Check for file-scoped namespace
        declarations (`namespace Foo.Bar;`) rather than block-scoped
        (`namespace Foo.Bar { ... }`), and flag inconsistency across the
        codebase (mixing both styles).

7.  **Async Patterns**:
    *   **No `async void`**: Flag `async void` methods except true
        event handlers (e.g. UI event handlers) — everything else should
        return `async Task` / `async Task<T>` so exceptions propagate and
        callers can await completion.
    *   **Async Naming**: Check that asynchronous methods are suffixed
        with `Async` (e.g. `GetUserAsync`).
    *   **Awaiting, Not Blocking**: Flag `.Result`, `.Wait()`, or
        `.GetAwaiter().GetResult()` used to synchronously block on a
        Task — a deadlock and thread-starvation risk.

8.  **Controller Thinness**:
    *   **No Business Logic in Actions**: Controller actions and
        minimal API handlers should only bind/validate input, delegate to
        a service/mediator, and shape the HTTP response. Flag direct
        `DbContext` queries, business rule evaluation, or multi-step
        orchestration embedded directly in an action method or handler
        delegate — this belongs in the service layer.

OUTPUT FORMAT:

Produce one entry per violation found:
*   **File**: `path/to/File.cs:42`
*   **Standard Violated**: `csharp.md` or `controller-patterns.md`
    (exact filename under `agent-rules/rules/dotnet/`)
*   **Severity**: `Critical` | `Major` | `Minor`
*   **Issue**: One-line description of the violation.
*   **Suggested Fix**: One-line recommended remediation.

Group violations by category (`[Naming Issue]`, `[Nullable Issue]`,
`[Record/Class Issue]`, `[Pattern Matching Issue]`, `[LINQ Issue]`,
`[Namespace Issue]`, `[Async Issue]`, `[Controller Issue]`) before listing
the per-violation records.

SCORING GUIDANCE:

*   **Strong (85-100)**: Naming is consistent throughout, nullable
    reference types are enabled and genuinely enforced (no meaningful `!`
    overuse), records and classes are used per their identity semantics,
    LINQ is free of multiple-enumeration and `.Count() > 0` anti-patterns,
    namespace style is consistent, `async void` appears nowhere outside
    event handlers, and controllers are thin pass-throughs to services.
*   **Fair (70-84)**: Mostly compliant with isolated violations —
    a handful of null-forgiving operators used defensively rather than
    correctly, occasional naming inconsistencies, or a controller with
    minor logic creep — but no systemic pattern of violations.
*   **Weak (0-69)**: Naming conventions are inconsistently applied,
    nullable reference types are disabled or routinely bypassed with `!`,
    entities and DTOs conflate record/class semantics, LINQ correctness
    issues are widespread, `async void` is used outside event handlers, or
    controllers contain substantial business logic.
