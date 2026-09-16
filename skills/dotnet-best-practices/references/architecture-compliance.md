# .NET Architecture Compliance Analysis

> Analyze codebase for adherence to layered architecture, dependency injection correctness, repository pattern quality, and service composition.

---

Goal: Analyze the ASP.NET Core Web API codebase for strict adherence to
layer boundaries, dependency direction, and separation of concerns at
the MICRO (code-quality) level — not project/solution scaffolding.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/dotnet/module-structure.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/dotnet/module-structure.md
- local: `agent-rules/rules/dotnet/repository-patterns.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/dotnet/repository-patterns.md
- local: `agent-rules/rules/dotnet/service-patterns.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/dotnet/service-patterns.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.
3. This is a MICRO-level audit: judge individual classes, methods, and
   registrations for correctness — not whether the solution chose
   Clean Architecture vs. a pragmatic three-layer split.

LAYER DEFINITIONS:

1.  **Domain** (or `Core`'s domain half): entities, value objects, domain
    events, domain-owned interfaces. Zero outward dependencies.
2.  **Application**: use cases/services, DTOs, application-owned
    interfaces (`IOrderRepository`, `IEmailSender`). Depends only on
    Domain.
3.  **Infrastructure**: EF Core `DbContext`, repository implementations,
    external clients (HTTP, message brokers, cloud SDKs). Implements
    Application-defined interfaces.
4.  **Api**: controllers/minimal-API endpoints, `Program.cs`,
    middleware, DI composition. May reference all inner layers but is
    the only place concrete `Infrastructure` types are registered.

ANALYSIS TARGETS:

1.  **Layer Boundary Violations** (`module-structure.md`):
    *   **CRITICAL**: Domain type referencing EF Core, ASP.NET Core, or
        any `Infrastructure`/`Api` type (e.g. `[Column]`/`[Table]`
        attributes on a domain entity, a domain method taking a
        `DbContext` parameter, a domain class implementing
        `IActionFilter`).
    *   **CRITICAL**: Controller referencing `Infrastructure` directly
        (a concrete repository class, `DbContext`, an EF Core
        `DbSet<T>`) instead of going through an Application-layer
        service/interface.
    *   Flag Application-layer code referencing `Infrastructure` types
        directly (e.g. a service class newing up an EF Core query)
        instead of depending on an interface it owns.
    *   Flag business logic embedded in a controller action (validation
        beyond model binding, branching business rules, direct data
        mutation) instead of delegated to a service.

2.  **Dependency Injection Correctness**:
    *   Verify constructor injection (including C# primary-constructor
        syntax, e.g. `class OrderService(IOrderRepository repo)`) is
        used consistently; flag `new SomeService()`/`new
        SomeRepository()` instantiated inside another class instead of
        injected.
    *   **CRITICAL — Captive Dependency**: flag a `Scoped` or
        `Transient` service (e.g. `AppDbContext`, a
        `Scoped`-registered repository) injected into a `Singleton`
        (constructor-captured, not resolved per-use via
        `IServiceScopeFactory`/`IServiceProvider`) — the scoped instance
        gets captured for the app's lifetime, causing stale
        `DbContext`/state and, with EF Core, `ObjectDisposedException`
        or cross-request data corruption.
    *   Verify DI lifetimes match usage: `AddDbContext` types and
        anything holding a `DbContext` should be `Scoped`; stateless
        services can be `Singleton`; verify `AddScoped`/`AddSingleton`/
        `AddTransient` calls match the actual statefulness of the type
        being registered.
    *   Flag service locator usage (`IServiceProvider.GetService<T>()`
        resolved deep inside business logic) in place of constructor
        injection, except where required (factories, multi-implementation
        resolution).

3.  **Repository Pattern Implementation Quality** (`repository-patterns.md`,
    only where repositories are actually used — see the standard's
    guidance on when a repository is warranted at all):
    *   Flag generic `IRepository<T>` interfaces with vague methods
        (`FindAll()`, `FindOne(Expression<Func<T,bool>>)`) instead of
        specific, intention-revealing methods
        (`GetActiveOrdersForUserAsync`, `GetPagedAsync`).
    *   **CRITICAL**: flag a repository method returning `IQueryable<T>`
        to its caller — this leaks the ORM outside the data layer.
    *   Flag read-only query methods missing `AsNoTracking()`.
    *   Flag query-in-a-loop patterns (N+1) instead of `Include()`/
        `ThenInclude()` or projection.
    *   Flag business logic (validation, branching business rules,
        cross-entity orchestration) implemented inside a repository
        method instead of the service/application layer — a repository
        should only stage/retrieve data.
    *   Flag `SaveChangesAsync()` called inside every repository method
        instead of once per business operation at the caller's
        boundary (or inside an explicit transaction for multi-step
        operations).
    *   Flag list-returning repository methods with no pagination
        (`Skip()`/`Take()`) and no upper bound on result size.
    *   Flag synchronous EF Core calls (`.Result`, `.Wait()`,
        `ToList()`, `SaveChanges()`, `FirstOrDefault()`) inside an
        `async` method instead of their async counterparts.

4.  **Service Layer Composition** (`service-patterns.md`):
    *   Verify controllers are thin: parse/validate the request, call
        exactly one (or few) service methods, map the result to a
        response — flag controllers doing orchestration across multiple
        services/repositories that belongs in an application service.
    *   Flag services performing HTTP-concerns work (reading
        `HttpContext`, setting response headers/status codes, accessing
        `ControllerBase` members) — that belongs in the Api layer.
    *   Flag large, monolithic service methods that mix multiple
        responsibilities (validation + orchestration + mapping +
        side-effects) and should be split into smaller, named steps or
        collaborating services.
    *   Flag excessive service-to-service dependency chains (a service
        constructor with many injected service dependencies) that
        signal a missing decomposition or a "God service."
    *   Verify a service depends on interfaces (`IOrderRepository`,
        `IEmailSender`) rather than concrete Infrastructure
        implementations.

5.  **DI Registration Organization**:
    *   Flag service/repository registrations accumulating directly in
        `Program.cs` instead of grouped into `IServiceCollection`
        extension methods (`AddApplicationServices`,
        `AddInfrastructureServices`), one per layer/module.
    *   Verify `Program.cs` stays a short composition root that calls
        the extension methods rather than containing registration logic
        itself.
    *   Flag `Infrastructure` concrete types (repository classes,
        `DbContext`) registered from an `Application`/`Domain` project
        instead of from the composition root or the `Infrastructure`
        layer's own extension method.

OUTPUT FORMAT:

Produce a list of violation records, one per finding:

*   **File**: relative file path
*   **Line**: best-effort line number (or line range) of the offending
    code
*   **Standard Violated**: exact filename — `module-structure.md`,
    `repository-patterns.md`, or `service-patterns.md`
*   **Severity**: `Critical` | `Major` | `Minor`
    *   `Critical`: Domain depending outward, controller bypassing the
        service layer to hit Infrastructure directly, captive
        dependency (Scoped/Transient into Singleton), repository
        leaking `IQueryable<T>`
    *   `Major`: generic/vague repository interfaces, business logic in
        a repository or controller, HTTP concerns in a service,
        `Program.cs` registration sprawl, wrong DI lifetime for a
        stateful type
    *   `Minor`: missing `AsNoTracking()`, missing pagination, minor
        service decomposition opportunities, missing `CancellationToken`
        threading
*   **Suggested Fix**: one line, concrete and actionable

Example:

```
- File: src/MyApp.Api/Controllers/OrdersController.cs
  Line: 27
  Standard Violated: module-structure.md
  Severity: Critical
  Suggested Fix: Inject IOrderService instead of AppDbContext into OrdersController; move the query into an application service.
```

After the violation list, include:
*   **Compliance**: notable examples of correct layering, DI, or
    repository/service design already present in the codebase.
*   **Recommendations**: concrete refactoring advice grouped by theme
    (layer boundaries, DI lifetimes, repository design, service
    composition, registration organization).

SCORING GUIDANCE:

Score this dimension 0-100 based on the density and severity of
violations relative to the number of files analyzed:

*   **Strong (85-100)**: Dependency direction strictly inward (Domain
    has zero outward references), controllers only call
    services/interfaces, DI lifetimes correct with no captive
    dependencies, repositories (where present) expose intention-revealing
    async methods with `AsNoTracking()` on reads and no leaked
    `IQueryable<T>`, services are thin and single-purpose, registrations
    are grouped into per-layer extension methods. At most a few Minor
    findings.
*   **Fair (70-84)**: Layering mostly respected with isolated gaps —
    e.g. one controller reaching past a service, a few missing
    `AsNoTracking()` calls, a moderately oversized service method, or
    `Program.cs` accumulating some inline registrations. No Critical
    findings.
*   **Weak (0-69)**: One or more Critical findings (Domain referencing
    Infrastructure/EF Core, a controller directly using `DbContext` or a
    concrete repository, a captive Scoped/Transient dependency inside a
    Singleton, a repository returning `IQueryable<T>`), or Major findings
    pervasive across most controllers/services.
