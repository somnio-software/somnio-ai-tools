# System Prompt — Somnio Coding Standards (Dotnet)

You are an expert software engineer. Follow these coding standards precisely when generating code.

### Route, verb, and endpoint conventions for ASP.NET Core Web APIs - controllers and minimal APIs - covering versioning, status codes, auth, and thin handlers.
> Applies to: `src/**/*Controller.cs, src/**/Endpoints/*.cs, src/**/*.Api/**/*.cs`

# ASP.NET Core Controller & Endpoint Patterns

How to structure HTTP entry points in an ASP.NET Core 8 Web API - whether using MVC controllers or minimal API endpoint groups - so routing, versioning, status codes, and authorization stay consistent across the codebase.

## Controllers vs Minimal APIs

Both are idiomatic in ASP.NET Core 8. Pick based on the shape of the surface, not personal preference, and be consistent within a project.

- **Prefer controllers** when a resource has many actions, needs model binding conventions (`[FromBody]`, `[FromRoute]`), benefits from `[ApiController]` behaviors, or the team is more comfortable with MVC-style organization.
- **Prefer minimal APIs** for small, focused services, for internal/BFF-style APIs with few endpoints, or when startup performance and a lower-ceremony style matter. Group related endpoints with `MapGroup` instead of one giant `Program.cs`.

Do not mix the two styles for the same resource (e.g., `UsersController` for reads and a parallel minimal `/users` group for writes) - pick one per resource area.

#### Good - Minimal API group per resource

#### Bad - Business logic inline in the endpoint, no versioning, no typed results

## Route Conventions

Use attribute routing with plural, resource-based nouns. Version the route prefix. Nest child resources under their parent when the child cannot exist independently.

## HTTP Verbs and Status Codes

Map verbs to intent and return the status code that matches what actually happened - not `200 OK` for every response.

| Verb | Intent | Typical success status |
|------|--------|-------------------------|
| `GET` | Read one or many | `200 OK` |
| `POST` | Create | `201 Created` (with `Location` header) |
| `PUT` | Full replace | `200 OK` or `204 No Content` |
| `PATCH` | Partial update | `200 OK` or `204 No Content` |
| `DELETE` | Remove | `204 No Content` |

#### Good - Controllers with `ActionResult<T>`

#### Bad - Everything returns 200, no `Location` header on create

## API Versioning

Use `Asp.Versioning.Http` (and `Asp.Versioning.Mvc` for controllers) rather than hand-rolled header parsing.

#### Bad - Version baked into a custom header parsed by hand, no fallback

## `[ApiController]` Benefits

Always decorate API controllers with `[ApiController]`. It automatically:
- Returns `400 Bad Request` with a `ValidationProblemDetails` body when `ModelState` is invalid - no manual `if (!ModelState.IsValid)` checks needed
- Infers binding sources (`[FromBody]`, `[FromRoute]`, `[FromQuery]`) from parameter shape
- Requires attribute routing (no convention-based routing fallback, which keeps routes explicit)

#### Bad - Missing `[ApiController]`, manual validation boilerplate repeated everywhere

## Authorization

Declare authorization at the route/controller level, not by checking claims manually inside handlers.

Minimal API equivalent:

#### Bad - Authorization logic reimplemented inside the handler

## Thin Controllers / Endpoint Handlers

Controllers and endpoint delegates should orchestrate, not implement. Delegate to a service, MediatR handler, or application-layer class. This keeps HTTP concerns (status codes, routing) separate from business rules, and makes the business logic unit-testable without spinning up ASP.NET Core.

#### Bad - Business rules, persistence, and even email sending inline in the controller

## Async All the Way

Every action/handler that does I/O must be `async` and awaited end-to-end. Never block on a `Task` with `.Result` or `.Wait()` - it deadlocks under load and wastes thread pool threads.

#### Bad - Synchronous blocking on async work

## OpenAPI / Swagger Annotations

Document responses explicitly so generated clients and Swagger UI reflect reality, not just the happy path.

#### Good - Controllers

#### Good - Minimal APIs

#### Bad - No response type metadata, generated clients assume every call returns `200`

## Rules

- **Choose controllers or minimal APIs per resource area and stay consistent** - do not mix styles for the same resource
- **Version every route** with `api/v{version:apiVersion}/...` and `Asp.Versioning.Http`/`Asp.Versioning.Mvc`
- **Use plural, resource-based nouns** in routes; nest child resources under their parent
- **Map verbs to correct status codes** - `201` + `Location` for create, `204` for delete, never blanket `200`
- **Always decorate API controllers with `[ApiController]`** to get automatic model validation and binding inference
- **Declare authorization declaratively** via `[Authorize]`/`[AllowAnonymous]`/policies, not manual claim checks
- **Keep controllers/endpoint delegates thin** - delegate to services or MediatR handlers
- **Make every I/O-bound action `async`** and never block with `.Result`/`.Wait()`
- **Annotate responses** with `[ProducesResponseType]` / `.Produces<T>()` / `.WithOpenApi()` for accurate OpenAPI docs
- **Use `TypedResults`/`Results<T1, T2>`** in minimal APIs instead of untyped `IResult` so response shapes are compile-time checked

- Avoid mixing controllers and minimal APIs for the same resource
- Avoid un-versioned routes, or versioning via a custom header instead of `Asp.Versioning`
- Avoid verb-in-path routes (`/getAllCustomers`) instead of resource nouns with proper HTTP verbs
- Avoid returning `200 OK` for creates/deletes instead of `201 Created`/`204 No Content`
- Avoid missing `[ApiController]`, leading to hand-rolled `ModelState.IsValid` checks in every action
- Avoid manually re-checking roles/claims inside a handler instead of using `[Authorize]`/policies
- Avoid business logic, persistence, or external calls (email, payment) written directly inside a controller action or endpoint delegate
- Avoid blocking async calls with `.Result` or `.Wait()`
- Avoid missing or inaccurate `[ProducesResponseType]`/`.Produces<T>()` annotations, causing generated clients to assume only the happy path
- Avoid returning EF Core entities directly from an action instead of a response DTO

---

### General C# / .NET 8 language conventions — naming, nullable reference types, records vs classes, pattern matching, LINQ discipline, required members, primary constructors, file-scoped namespaces, async void avoidance. Applies to all C# files.
> Applies to: `**/*.cs`

# C# / .NET 8 Best Practices

General-purpose C# 12 / .NET 8 conventions covering naming, nullability, data-modeling choices (records vs classes), pattern matching, LINQ discipline, modern boilerplate reduction (`required`, primary constructors), namespace style, and safe async usage. These apply across API projects, class libraries, and console tools alike.

## Patterns

### Naming Conventions

Use `PascalCase` for types, methods, properties, and all public members. Use `camelCase` for locals and parameters. Use `_camelCase` for private fields. This matches the official .NET naming conventions and is what analyzers (`.editorconfig` + Roslyn) enforce by default.

### Nullable Reference Types Enabled Project-Wide

Enable `<Nullable>enable</Nullable>` in every project file so the compiler tracks nullability of reference types. Treat a nullable warning as a signal to fix the underlying design — add a null check, make the parameter optional deliberately with `?`, or restructure the flow — not as license to suppress it with `!` (the null-forgiving operator) without justification.

### Records for Immutable Data vs Classes for Entities

Use `record` (or `record struct` for small, frequently copied values) for DTOs, request/response models, and value objects whose equality is based on their content and that should be immutable. Use `class` for entities that have identity (an `Id` that survives mutation), mutable state, or behavior beyond simple data transformation.

### Pattern Matching Over Long If/Else Chains

Use `switch` expressions and property patterns instead of chains of `if`/`else if` when branching on a value's type or shape. Pattern matching is more concise, exhaustive-checkable by the compiler, and reads as data rather than control flow.

### LINQ: Avoiding Multiple Enumeration and Count() > 0

Materialize a LINQ query with `.ToList()`/`.ToArray()` when the result will be enumerated more than once — re-enumerating an `IEnumerable<T>` backed by a database query or a generator re-runs the whole query (or, worse, produces different results if the underlying data changed). Use `.Any()` instead of `.Count() > 0`: `Any()` short-circuits on the first element, while `Count()` may have to enumerate the entire sequence.

### Required Members and Primary Constructors (C# 12)

Use `required` on properties that must be set at construction time instead of a constructor overload whose only job is to enforce that, and use primary constructors on classes whose constructor body would otherwise just assign parameters to fields. Both remove boilerplate without hiding intent.

### File-Scoped Namespaces

Use file-scoped namespace declarations (`namespace Foo.Bar;`) instead of the block-scoped form. They remove one indentation level from every file and are the default in `dotnet new` templates since .NET 6.

### Avoiding async void

Every async method should return `Task` or `Task<T>` so callers can await it, observe exceptions, and compose it with other async work. The only acceptable use of `async void` is a UI event handler whose signature is dictated by the framework — exceptions thrown from `async void` cannot be caught by the caller and crash the process instead.

## Rules

- Follow the official .NET naming conventions: `PascalCase` for types/methods/properties/public members, `camelCase` for locals/parameters, `_camelCase` for private fields.
- Enable `<Nullable>enable</Nullable>` in every project; treat nullable warnings as design signals to fix, never suppress with `!` without a comment justifying it.
- Model DTOs and value objects as `record`/`record struct`; model entities with identity and behavior as `class`.
- Prefer `switch` expressions and property patterns over long `if`/`else if` chains when branching on a value's shape or type.
- Materialize (`.ToList()`/`.ToArray()`) any `IEnumerable<T>`/`IQueryable<T>` that will be enumerated more than once.
- Use `.Any()` instead of `.Count() > 0` (or `== 0`) to check emptiness.
- Use `required` properties instead of constructor overloads whose only job is enforcing mandatory values.
- Use primary constructors (C# 12) for classes whose constructor body would otherwise only assign parameters to fields.
- Use file-scoped namespaces (`namespace Foo;`) in every new file.
- Every async method returns `Task`/`Task<T>`; never `async void` outside of framework-mandated event handlers.

- Avoid mixing case conventions — `PascalCase` locals, `camelCase` public properties, unprefixed private fields — inconsistent with `.editorconfig`/analyzer defaults.
- Avoid suppressing a nullable warning with `!` instead of adding a null check or making the nullability explicit in the signature.
- Avoid using a mutable `class` with public setters for a DTO that should be an immutable `record`.
- Avoid using a `record` for an entity that has identity and needs in-place mutation, encouraging `with`-expression copies that lose the original identity semantics.
- Avoid deeply nested `if`/`else if` chains where a `switch` expression with property patterns would be both shorter and exhaustive-checked.
- Avoid enumerating the same `IQueryable<T>`/lazy `IEnumerable<T>` multiple times, causing repeated database round-trips or inconsistent results.
- Avoid writing `.Count() > 0` (or `.Count() == 0`) instead of `.Any()`/`!.Any()`, forcing a full enumeration just to check emptiness.
- Avoid defaulting required properties to `string.Empty`/`0` instead of marking them `required`, silently allowing incomplete objects to be constructed.
- Avoid writing a boilerplate constructor purely to assign fields when a primary constructor would express the same thing with less code.
- Avoid using block-scoped `namespace Foo { ... }` in new files instead of the file-scoped form.
- Avoid declaring `async void` methods outside of UI event handlers, losing the ability to await completion or catch thrown exceptions.

---

### DTO shape and validation conventions for ASP.NET Core Web APIs - record DTOs, Data Annotations vs FluentValidation, and entity/DTO mapping.
> Applies to: `src/**/Dtos/*.cs, src/**/Contracts/*.cs, src/**/*Request.cs, src/**/*Response.cs, src/**/*Validator.cs`

# ASP.NET Core DTO & Validation Standards

How to shape request/response contracts and validate them in an ASP.NET Core 8 Web API, so entities never leak over the wire and invalid input never reaches a service or handler.

## DTOs as Records

Use C# `record` types for DTOs. Records give you value-based equality, concise positional syntax, and immutability by default - exactly what a request/response contract should be. Never reuse an EF Core entity as a DTO.

#### Bad - Mutable class DTO, and the EF Core entity itself used as a response

## Separate Create / Update / Response DTOs

Never share one DTO across create, update, and read. Each operation has a different required/optional shape, and collapsing them either forces nullable fields that aren't really optional, or lets clients set fields (like `Id`, `CreatedAt`) they should never control.

#### Bad - One DTO reused everywhere

## Validation: Data Annotations vs FluentValidation

Use **Data Annotations** for simple, per-property, non-conditional rules - they're integrated with `[ApiController]` and require no extra wiring. Use **FluentValidation** (`AbstractValidator<T>`) once rules become conditional, cross-field, asynchronous (e.g., uniqueness checks), or need to be unit tested independently of the model.

### Data Annotations - simple cases

With `[ApiController]` on the controller, an invalid `CreateUserRequest` automatically produces a `400 Bad Request` with a `ValidationProblemDetails` body - no manual checks needed.

#### Bad - Manual validation duplicating what Data Annotations already give you for free

### FluentValidation - complex/conditional rules

Prefer FluentValidation once you need cross-field rules, conditional requirements, or rules that call a service (e.g., "email must not already exist").

Register FluentValidation and wire it into the pipeline:

For MediatR pipelines, validate as a pipeline behavior so every command/query is validated the same way:

For minimal APIs, validate with an endpoint filter instead of hand-checking inside every handler:

#### Bad - Validation logic embedded in the service, untestable in isolation

## Mapping Between Entities and DTOs

Prefer **explicit manual mapping** for small-to-medium APIs - it's easy to read, easy to debug, and the compiler catches missing members when a DTO or entity changes shape. Reach for AutoMapper or Mapster only when the number of mappings is large enough that hand-writing them is a genuine maintenance burden, and the team accepts the debugging/readability trade-off.

#### Good - Explicit mapping method

#### Acceptable - AutoMapper for large, uniform mapping surfaces

#### Bad - Reflection-based "magic" mapping with silent property name mismatches

## Excluding Sensitive Fields from Response DTOs

A response DTO's shape is a deliberate allowlist, not "the entity minus whatever I remembered to remove." Never include password hashes, security stamps, refresh tokens, or other internal-only fields.

#### Bad - Serializing the entity, or a DTO that mirrors it 1:1

## Nullable Annotations Should Match Business Meaning

Enable nullable reference types project-wide (`<Nullable>enable</Nullable>`) and use nullability on DTO properties to communicate whether a field is genuinely optional - not just to satisfy the compiler.

#### Bad - Everything nullable "just in case", or required fields marked optional

## Rules

- **Use `record` types for all request/response DTOs** - immutable, concise, value-equality
- **Never expose EF Core entities directly** - always map to a purpose-built response DTO
- **One DTO per operation** - `CreateXRequest`, `UpdateXRequest`, `XResponse` are distinct types, not one shared shape
- **Use Data Annotations for simple, per-property rules**; move to FluentValidation once rules are conditional, cross-field, or async
- **Wire validation into the pipeline** (`[ApiController]` auto-validation, MediatR `ValidationBehavior`, or minimal API endpoint filter) rather than checking manually inside handlers/services
- **Prefer explicit manual mapping methods** for small/medium APIs; reserve AutoMapper/Mapster for large, uniform mapping surfaces
- **Treat response DTOs as an allowlist** - explicitly decide what's included, never "entity minus a few fields"
- **Make DTO nullability match business meaning** - required fields are non-nullable, optional fields are nullable, with nullable reference types enabled project-wide

- Avoid returning an EF Core entity (or a DTO that mirrors it 1:1) directly from an endpoint
- Avoid reusing a single DTO across create, update, and read operations
- Avoid letting a client set server-controlled fields (`Id`, `CreatedAt`, `Status`) through a request DTO
- Avoid hand-rolling `if (string.IsNullOrEmpty(...))` validation that Data Annotations already provide
- Avoid putting conditional or cross-field validation logic inside a service method instead of a validator
- Avoid serializing password hashes, security stamps, or tokens because they were never removed from the response type
- Avoid making every property nullable "to be safe," pushing null-checks into every consumer
- Avoid using reflection-based or JSON round-trip "mapping" instead of an explicit method or a mapping library
- Avoid skipping validation entirely on minimal API endpoints because there's no `[ApiController]` to auto-validate `ModelState`

---

### Centralized error handling for ASP.NET Core Web APIs - IExceptionHandler, ProblemDetails, domain exceptions, and structured logging.
> Applies to: `src/**/*Exception*.cs, src/**/*ExceptionHandler*.cs, src/**/Middleware/*.cs`

# ASP.NET Core Error Handling Standards

How to implement consistent, centralized error handling in an ASP.NET Core 8 Web API using `IExceptionHandler`, RFC 7807 `ProblemDetails`, and domain exceptions - instead of scattered try/catch blocks with inconsistent responses.

## Core Principle: Handle Errors in One Place

Do not scatter `try/catch` blocks through controllers, endpoint handlers, and services with each one building its own response shape. Throw domain-specific exceptions from business logic, and let a single, centralized handler translate them into HTTP responses.

**Never use magic strings or ad-hoc status codes** - map exception types to status codes in exactly one place.

## Domain Exceptions

Define a small hierarchy of exceptions that represent business-meaningful failure categories, not raw `Exception`.

Throw them from services with real context, not generic messages:

#### Bad - Generic exceptions with magic strings, no way to map to a status code centrally

## Centralized Handling via `IExceptionHandler`

ASP.NET Core 8 introduced `IExceptionHandler` specifically so exception-to-response mapping lives in one testable class instead of ad-hoc middleware.

Register it and enable `ProblemDetails` globally:

#### Bad - Try/catch repeated in every controller with an inconsistent shape

## RFC 7807 `ProblemDetails` as the Standard Shape

Always respond with `ProblemDetails` (or `ValidationProblemDetails` for field-level errors), never a bespoke error object. `[ApiController]` already returns `ValidationProblemDetails` for model-binding failures; `AddProblemDetails()` extends that same shape to every other error path (404s, unhandled exceptions, etc.).

## Exceptions vs a Result Pattern for Expected Outcomes

Reserve exceptions for truly exceptional, unexpected conditions. For **expected** business outcomes - a validation failure, "already exists," "insufficient balance" - consider a `Result`/`OneOf`-style return type instead, especially in hot paths where throwing is expensive or the failure is a normal, anticipated branch of the workflow. This is an advanced/optional pattern: adopt it deliberately and consistently, not as a one-off in a single method.

#### Optional pattern - `Result<T>` for expected failures

The endpoint then maps the `Result` to the appropriate status code explicitly, still funneling through the same `ProblemDetails` shape:

#### Bad - Using exceptions for routine, expected control flow

## Structured Logging at the Boundary

Log with `ILogger<T>` using structured (named) parameters, and log each error exactly once - at the boundary (the exception handler or middleware), not again at every layer it passes through.

#### Bad - Log-and-rethrow at every layer, producing duplicate log entries for one failure

## Hiding Internal Details in Production

Never let stack traces, connection strings, or raw exception messages reach a client outside Development.

#### Bad - Same verbose response in every environment

## Validate Before Mutating

Check existence and business rules before performing a write, and fail with the specific domain exception - don't let an EF Core `DbUpdateException` or a null-reference bubble up as an unhandled 500.

#### Bad - No existence/state check, lets the database throw

## Rules

- **Centralize exception-to-response mapping** in one `IExceptionHandler` (or equivalent middleware) - never scatter try/catch across controllers
- **Throw specific domain exceptions** (`NotFoundException`, `ConflictException`, `BusinessRuleViolationException`) instead of generic `Exception`/`InvalidOperationException`
- **Always respond with `ProblemDetails`/`ValidationProblemDetails`** - register with `AddProblemDetails()` so it applies to every error path, not just model binding
- **Reserve exceptions for exceptional cases**; consider a `Result`/`OneOf` pattern for expected, frequent business outcomes (optional, adopt consistently if used)
- **Log once, at the boundary**, with structured parameters and full exception context - never log-and-rethrow at every layer
- **Gate verbose errors behind `IsDevelopment()`** - Production 5xx responses must never include stack traces or internal messages
- **Validate existence and business rules before mutating** - fail fast with the correct domain exception rather than letting the database throw
- **Use distinct HTTP status codes per exception type** (404, 409, 422, 400) mapped centrally, not chosen ad hoc per endpoint

- Avoid try/catch blocks repeated in every controller/endpoint, each building a different error shape
- Avoid throwing generic `Exception` or `InvalidOperationException` instead of a specific domain exception
- Avoid bespoke JSON error objects instead of RFC 7807 `ProblemDetails`
- Avoid using exceptions to signal routine, expected outcomes (declined withdrawal, "already exists") in a hot path
- Avoid logging the same exception multiple times as it propagates up through layers
- Avoid returning full stack traces or raw exception messages to clients in Production
- Avoid missing existence/state checks before an update or delete, letting a `NullReferenceException` or `DbUpdateException` surface as an unhandled 500
- Avoid inconsistent status codes for the same logical error across different endpoints
- Avoid forgetting to register `AddProblemDetails()`, so non-exception error paths (404 route not found, 405 method not allowed) fall back to a plain-text or empty body

---

### Project/solution layering, dependency direction, and DI registration organization for ASP.NET Core Web API solutions.
> Applies to: `**/*.cs`

# .NET Module Structure

How to organize an ASP.NET Core Web API solution into layers with a clear dependency direction, consistent folder conventions, and composable dependency-injection registration.

## Solution Layering

### Clean Architecture (four projects)

Use this when the domain has real business rules worth protecting, the API will be long-lived, or multiple entry points (Web API, worker service, CLI) will share the same core logic.

### Pragmatic Three-Layer (smaller services)

For a small internal API, an admin backend, or a service with thin business rules, four projects add overhead without payoff. Use three:

The dependency rule stays the same — `Core` has no dependency on `Infrastructure` or `Api`; `Infrastructure` depends on `Core`; `Api` depends on both and wires them together. Do not reach for full Clean Architecture just because it looks more "proper" — a fourth project with one interface in it is a sign the split isn't paying for itself yet. Promote to four layers when `Core` becomes large enough that use-case orchestration and domain rules start stepping on each other.

## Dependency Direction

The rule that must never be violated: **dependencies point inward, toward the domain.**

- `Domain` (or `Core`'s domain half) has **zero** project references — no EF Core, no ASP.NET Core, no HTTP clients.
- `Application` depends only on `Domain`. It defines interfaces (`IOrderRepository`, `IEmailSender`) that outer layers implement.
- `Infrastructure` depends on `Application` (to implement its interfaces) and whatever external packages it needs (EF Core, HttpClient, cloud SDKs).
- `Api` depends on all three and is the only place a concrete `Infrastructure` type is ever registered with the DI container.

## Feature Folders vs Technical Folders

Both are valid within a layer. Pick one per project and stay consistent.

**Technical folders** (group by role):

**Feature folders** (group by capability):

Feature folders scale better once a project has dozens of endpoints, because everything related to "Orders" lives together instead of being scattered across three sibling directories. Technical folders are fine for small APIs where the whole controller list fits on one screen. Whichever you choose, don't mix both conventions in the same project — a codebase where half the features have their own folder and half live in a shared `Controllers/` is harder to navigate than either pure style.

## DI Registration Organization

Do not accumulate every service registration directly in `Program.cs`. Group registrations into `IServiceCollection` extension methods, one per layer/module.

## Options Pattern for Configuration

Bind configuration sections into strongly typed options classes instead of injecting `IConfiguration` and reading string keys throughout the codebase.

## Rules

- Choose Clean Architecture (`Domain`/`Application`/`Infrastructure`/`Api`) when the domain has real business rules or multiple entry points share it; choose the pragmatic three-layer split for small, simple services
- Keep `Domain` (or `Core`) free of every external package reference, including EF Core and ASP.NET Core
- Register services through one `IServiceCollection` extension method per layer, composed in `Program.cs`
- Bind configuration into `IOptions<T>` classes instead of reading `IConfiguration` keys directly in services
- Pick either feature folders or technical folders per project, and apply that choice consistently
- Add an `NetArchTest`-based architecture test suite once the solution has more than a couple of projects, so layering rules are enforced by CI, not by memory
- Keep `Program.cs` a short, readable composition root — if it's doing more than wiring things together, extract that logic

- Avoid domain entities referencing EF Core attributes, `DbContext`, or other infrastructure types
- Avoid a four-project Clean Architecture split for a five-endpoint internal tool that never needed the ceremony
- Avoid `Program.cs` accumulating hundreds of lines of inline service registrations
- Avoid `IConfiguration["Section:Key"]` string lookups scattered across services instead of bound options classes
- Avoid circular project references introduced by a "just this once" shortcut (e.g., `Infrastructure` referencing `Api` to reuse a DTO)
- Avoid mixing feature folders and technical folders inconsistently within the same project
- Avoid registering `Infrastructure` types (concrete repository classes, `DbContext`) from `Application` or `Domain` instead of the composition root
- Avoid no architecture tests, so layering violations are only caught in code review, if at all

---

### Repository pattern over EF Core, async query patterns, pagination, and Unit of Work for ASP.NET Core Web APIs.
> Applies to: `**/*Repository*.cs`

# .NET Repository Patterns

How to build a data access layer over EF Core 8 that stays testable, avoids N+1 queries, and keeps transaction boundaries at the right level.

## When to Introduce a Repository

Not every project needs a repository abstraction. `DbContext` and `DbSet<T>` are already a unit-of-work and a queryable repository — adding a wrapper around them is only worth it under certain conditions.

**Skip the repository, inject `DbContext` directly, when:**
- The API is small (a handful of entities, a handful of endpoints)
- There is exactly one persistence provider and no plan to swap it
- The team is comfortable writing EF Core queries directly in services, and tests run against a real (or in-memory/SQLite) test database anyway

**Introduce repositories when:**
- The domain is large enough that query logic needs a home separate from orchestration logic
- Tests need to mock data access without spinning up a database
- Multiple services share the same non-trivial queries and duplicating them is worse than an abstraction
- There's a genuine chance of swapping or wrapping the persistence provider (e.g., adding a cache layer in front of reads)

#### Good — small API, `DbContext` injected directly

#### Bad — repository abstraction with no consumers benefiting from it

## Avoid Generic Repository Interfaces

`IRepository<T>` looks appealing because it's reusable, but it tends to either leak `IQueryable<T>` (defeating the point of the abstraction) or force awkward generic method names (`FindAll`, `FindOne`, `Find(Expression<Func<T, bool>>)`) that don't say what the query actually does.

#### Good — specific repository, intention-revealing methods

#### Bad — generic repository leaking `IQueryable` and vague method names

## `AsNoTracking()` for Read-Only Queries

EF Core tracks entities by default so it can detect changes for `SaveChangesAsync()`. That tracking has a real cost (snapshotting, change detection) and is wasted work for queries that only read data.

## Avoiding N+1 Queries

Lazy loading and per-item queries in a loop generate one query per row. Use eager loading or projection instead.

#### Good — eager loading with `Include`/`ThenInclude`

#### Good — projection avoids loading full entities entirely

#### Bad — N+1: one query for orders, then one query per order for its lines

## Unit of Work: `SaveChangesAsync()` Once Per Business Operation

`SaveChangesAsync()` should be called once per business operation, at the boundary of the operation — not once per repository method. Repositories stage changes (`Add`, `Update`, `Remove`); the caller commits them together so the operation is atomic.

## Pagination

Never return an unbounded result set. Always page with `Skip()`/`Take()` and return a total count alongside the page.

## Async Everywhere

Every EF Core call in an async method should use its async counterpart. Mixing in synchronous calls (`ToList()`, `FirstOrDefault()`, `SaveChanges()`) inside async code blocks a thread pool thread and can deadlock under load.

## Rules

- Skip repositories for small APIs; inject `DbContext` directly when there's no testability or swappability need
- When you do introduce repositories, write specific, intention-revealing methods (`GetActiveOrdersForUserAsync`) instead of a generic `IRepository<T>`
- Never return `IQueryable<T>` from a repository — it leaks the ORM outside the data layer and hides what query actually executes
- Use `AsNoTracking()` for every read-only query; keep tracking only for entities that will be mutated and saved
- Use `Include()`/`ThenInclude()` or `Select()` projections to avoid N+1 queries — never query in a loop
- Call `SaveChangesAsync()` once per business operation; wrap multi-step operations in an explicit transaction if they span multiple saves
- Always paginate list endpoints with `Skip()`/`Take()` and return a total count; cap the maximum page size
- Use the async EF Core APIs (`ToListAsync`, `FirstOrDefaultAsync`, `SaveChangesAsync`) exclusively inside async methods, and thread a `CancellationToken` through every call

- Avoid introducing a generic `IRepository<T>` "for consistency" on a project with three entities and no test-mocking need
- Avoid repository methods that return `IQueryable<T>`, letting callers bolt on arbitrary LINQ
- Avoid missing `AsNoTracking()` on read-only queries, paying change-tracking cost for data that's never saved
- Avoid querying inside a `foreach` loop instead of eager-loading or projecting (N+1)
- Avoid calling `SaveChangesAsync()` inside every repository method instead of once at the operation boundary
- Avoid returning `List<T>` from a "get all" method with no `Skip()`/`Take()` and no upper bound on page size
- Avoid mixing synchronous EF Core calls (`.Result`, `.Wait()`, `ToList()`, `SaveChanges()`) into async code paths
- Avoid forgetting to pass `CancellationToken` through repository and query methods

---

### Application/service layer patterns for ASP.NET Core Web APIs including DI lifetimes, orchestration, and validation.
> Applies to: `**/*Service*.cs`

# .NET Service Patterns

How to structure the application/service layer in an ASP.NET Core Web API so business logic is testable, controllers stay thin, and dependency injection lifetimes don't create subtle bugs.

## Controllers Stay Thin, Services Hold Logic

A controller's job is to translate HTTP into a call to the service layer and translate the result back into HTTP. Business rules, validation, and orchestration belong in the service.

## Constructor Injection and DI Lifetimes

Use constructor injection (primary constructors in C# 12 keep this concise) for all dependencies. Choosing the right lifetime matters — it's not just boilerplate.

- **`AddScoped`** — one instance per HTTP request. Use for anything that depends on `DbContext` (which is itself scoped) or that holds per-request state.
- **`AddSingleton`** — one instance for the app's lifetime. Use for stateless, thread-safe services: caches, configuration wrappers, clients that are safe to share (e.g., a properly configured `HttpClient` via `IHttpClientFactory`).
- **`AddTransient`** — a new instance every time it's requested. Use for lightweight, stateless helpers with no meaningful per-request identity.

#### Bad — captive dependency

A **captive dependency** happens when a longer-lived service (singleton) holds a reference to a shorter-lived one (scoped or transient) captured at construction time. The captured instance then outlives its intended scope. The .NET DI container will throw an `InvalidOperationException` at startup if validation is enabled (`ValidateScopes = true`, on by default in `CreateBuilder` for Development), but it's still worth understanding why: always match a service's lifetime to its shortest-lived dependency, or resolve the dependency per-use via `IServiceScopeFactory` instead of injecting it directly.

## Splitting Orchestration Into Named Steps

A long monolithic method that validates, mutates, and notifies in one block is hard to read and hard to test in isolation. Split it into small private helpers called from one orchestration method.

## Validate Before Mutating, Fail Early with Specific Errors

Check entity existence and business rules before performing any mutation, and use exception types (or a result type) that callers can distinguish and map to the right HTTP status.

## Async/Await Without Unnecessary `ConfigureAwait(false)`

Use `async`/`await` consistently for I/O-bound work. A common piece of outdated advice carried over from ASP.NET Framework/desktop code is to append `.ConfigureAwait(false)` to every awaited call to avoid deadlocks. In ASP.NET Core there is no `SynchronizationContext` to resume on, so `ConfigureAwait(false)` has no effect on request-handling code and is unnecessary noise. It still matters in reusable library code that might run under a context (e.g., a NuGet package consumed by both ASP.NET Core and WPF), but not in application-layer services within a Web API project.

#### Unnecessary (not wrong, just noise in this context)

## MediatR as an Optional Organizational Pattern

For larger applications with many use cases, some teams organize the service layer as MediatR request/response handlers instead of interface-based service classes. This is optional — plain service classes work fine and MediatR should not be adopted just for its own sake.

#### Good — plain service class (the default, no extra dependency)

#### Good — MediatR handler (opt in for large apps that benefit from decoupled request/response pipelines)

Reach for MediatR when the number of use cases is large enough that a request/response pipeline (with shared behaviors like validation or logging via `IPipelineBehavior<,>`) pays for itself. Don't introduce it for a handful of endpoints — it adds indirection (command classes, handler classes, DI registration for each) that a plain service class avoids.

## Controlled Concurrency for Batch Processing

Processing a large batch with unbounded `Task.WhenAll` can exhaust database connections, thread pool capacity, or a downstream API's rate limit. Throttle concurrency explicitly.

## Rules

- Keep controllers thin: translate HTTP in, call one service method, translate the result back out
- Use constructor injection everywhere; prefer C# 12 primary constructors for conciseness
- Match DI lifetimes to actual dependencies: `AddScoped` for anything touching `DbContext`, `AddSingleton` for stateless/thread-safe services, `AddTransient` for lightweight stateless helpers
- Never inject a scoped or transient dependency directly into a singleton — use `IServiceScopeFactory` to create a scope per use if a singleton genuinely needs scoped data
- Split large orchestration methods into small, named private helpers (validate, execute, notify)
- Validate entity existence and business rules before mutating, and throw specific, catchable exception types
- Don't reflexively add `.ConfigureAwait(false)` in ASP.NET Core application code — there's no `SynchronizationContext` to avoid
- Treat MediatR as optional — adopt it when the number of use cases justifies a request/response pipeline, not by default
- Throttle concurrent batch work with a `SemaphoreSlim` (or similar) instead of firing unbounded `Task.WhenAll`

- Avoid controllers containing validation, persistence, or orchestration logic instead of delegating to a service
- Avoid registering a service as `AddSingleton` when it depends on scoped `DbContext` (captive dependency)
- Avoid one 100+ line method doing validation, mutation, and side effects with no named sub-steps
- Avoid mutating an entity before confirming it exists or satisfies business rules, resulting in null-reference exceptions or silently-wrong state changes
- Avoid throwing generic `Exception` instead of specific, catchable domain exceptions
- Avoid cargo-culting `.ConfigureAwait(false)` into every await in application code out of outdated habit
- Avoid introducing MediatR (or another mediator library) for a handful of endpoints where it only adds indirection
- Avoid unbounded `Task.WhenAll` over a large collection, exhausting connections or hitting downstream rate limits
- Avoid losing per-item error information when a batch operation fails partway through

---

### SOLID principles (SRP, OCP, LSP, ISP, DIP) applied to ASP.NET Core / C# services, plus cyclomatic complexity as a measurable proxy for SRP/OCP violations.
> Applies to: `**/*.cs`

# SOLID Principles for .NET / C#

The five SOLID principles are less a checklist than a shared vocabulary for describing *why* a design is hard to change. In an ASP.NET Core codebase they show up concretely: a service constructor with too many dependencies, a `switch` that has to be edited every sprint, an override that throws `NotSupportedException`, an interface no single caller fully uses, or a `new SmtpClient()` buried inside business logic. Each violation has a detectable shape, and each has a standard fix. This file works through all five principles with realistic C# 12 / .NET 8 examples, then covers cyclomatic complexity — the metric that most directly correlates with SRP and OCP violations and can be measured without adding any new tooling to the project.

## Single Responsibility Principle (SRP)

A class should have one reason to change. When a class's method list reads like a table of contents for three unrelated features, it has three reasons to change and will be touched by three unrelated teams/PRs.

### One Class Doing Validation, Persistence, Notification, and Logging

### Other SRP Smells to Watch For

- **6+ constructor dependencies.** A class injecting `IOrderRepository, ICustomerRepository, IInventoryService, INotificationService, IPricingEngine, ITaxCalculator, IReportExporter, IAuditLogger` is coordinating order creation, pricing, tax, reporting, *and* auditing in one place. Split it into `OrderService` (order creation) and `OrderReportingService` (reporting) so each has one cohesive job.
- **A single method over ~50 lines** mixing validation, I/O, business rules, and formatting in one block — a strong signal the method (and likely its containing class) has more than one reason to change. See the "Splitting Orchestration Into Named Steps" pattern in `service-patterns.md`.
- **Generic names as an SRP magnet.** `OrderManager`, `StringHelper`, `DataUtility` are not automatically wrong — a small, stateless `DateRangeHelper` with two tightly related methods (`GetStartOfWeek`, `GetEndOfWeek`) is fine. The smell is when an `OrderManager` that started with status transitions quietly grows methods for emailing, PDF generation, and shipping calculation because "it was already injected everywhere." The heuristic: if you can't summarize the class's job in one sentence without "and," split it.

## Open/Closed Principle (OCP)

A module should be open for extension but closed for modification — adding new behavior should mean adding new code, not editing code that already works and is already tested.

### Switch/If-Else Chains Over a Business Discriminator

The most common OCP violation in application code is a `switch` or `if/else if` chain over an `enum`/type discriminator that contains real business logic. Every new case requires editing an existing, already-shipped method — and if the same discriminator is switched over in more than one place, every new case means editing *all* of them.

#### Good — one strategy per case, resolved through DI

#### Bad — a switch that must be edited every time a new order type is added

Not every `switch` is an OCP violation — mapping an enum to a display string, or a simple one-to-one property translation, is fine as a `switch` expression (see `csharp.md`). The signal to watch for is business *logic* (calculations, branching side effects) inside the switch, duplicated across multiple files for the same discriminator.

## Liskov Substitution Principle (LSP)

A subtype must be usable anywhere its base type or interface is expected, without the caller needing to know which concrete type it got. If calling a method through the base contract can throw for some subtypes but not others, the contract is being violated, not fulfilled.

#### Good — the interface is split so a read-only implementation only implements what it actually supports

#### Bad — a fat interface forces an implementation to fake support it doesn't have

LSP is also violated more subtly, without an outright exception: an override with a **narrower precondition** (rejecting inputs the base type accepts — e.g. a `WireTransferProcessor : PaymentProcessor` whose override throws for any `amount < 500m` when the base `ChargeAsync` accepts any positive amount) or a **widened side effect** the caller wouldn't expect from the base contract. If a subtype genuinely can't support the base contract's full input range, it should not inherit from (or implement) that contract — model the constraint as a distinct type instead of a runtime surprise.

## Interface Segregation Principle (ISP)

Clients should depend only on the members they actually use. A fat interface forces every implementer — including test doubles — to provide (or fake) members that are irrelevant to most callers.

#### Good — split by client need

#### Bad — one fat interface every caller and every test double must fully implement

A strong ISP violation signal, tying back to LSP: if multiple implementations of an interface throw `NotImplementedException`/`NotSupportedException` for a subset of members, the interface is asking for more than any single implementer can honestly provide, and should be split.

## Dependency Inversion Principle (DIP)

High-level modules (business logic) should not depend on low-level modules (concrete infrastructure); both should depend on abstractions. In practice: constructor-inject interfaces, never `new` up a concrete collaborator inside a class that has business logic.

#### Good — the abstraction is injected, the concrete type is registered in DI

#### Bad — a concrete, side-effecting collaborator is instantiated inline

The clearest static-analysis signal for a DIP violation is `new ConcreteClassName()` appearing inside a class where an interface for that exact concern (`IPaymentGateway`, `IEmailSender`, `IOrderRepository`) already exists elsewhere in the codebase but isn't being used at this call site — e.g. a `RefundService(IOrderRepository orderRepository)` that reaches for `new StripePaymentGateway(...)` instead of accepting `IPaymentGateway` through the constructor, even though `IPaymentGateway` is already the standard abstraction used everywhere else. The abstraction exists — the class is simply choosing to bypass it.

Not every `new` is a DIP violation: instantiating simple value objects, DTOs, records, or framework-provided collection types (`new List<T>()`, `new OrderResponse(...)`, `new StringBuilder()`) has no side effects and no swappable behavior to abstract — only flag `new` of a class that behaves like a collaborator or service.

## Cyclomatic Complexity

Cyclomatic complexity (McCabe complexity) counts the linearly independent paths through a method: start at 1 and add 1 for every `if`, `else if`, `case` in a `switch`, loop (`for`/`foreach`/`while`/`do`), `&&`/`||`, `catch` clause, and ternary/null-coalescing branch. It is a direct, measurable proxy for how many SRP/OCP violations (long conditional chains, mixed concerns) have accumulated in one method — a method can't have runaway complexity without also having too many reasons to change.

### Thresholds

| Complexity | Risk | Guidance |
|---|---|---|
| 1–10 | Simple, low risk | Normal; no action needed |
| 11–20 | Moderate | Worth a second look during review; consider refactoring |
| 21–50 | Complex, high risk | Refactor before adding more logic to this method |
| 50+ | Untestable | Must refactor — the number of test cases needed to cover all paths is no longer practical |

### Measuring It Without Adding Tooling

.NET ships built-in Roslyn analyzers for exactly this, even when a project has no analyzer packages installed:

- **`CA1502`** — "Avoid excessive complexity." Fires when a method's cyclomatic complexity exceeds the default threshold of 25.
- **`CA1506`** — "Avoid excessive class coupling." Flags a class/method with too many dependencies on other types — a related but distinct smell from raw branching complexity.

These rules only fire when .NET analyzers are actually enabled — most projects don't turn them on by default. For a one-off audit of a codebase whose `.csproj`/`.editorconfig` doesn't already enable analyzers, force them on from the command line without permanently modifying any project file:

This surfaces `CA1502`, `CA1506`, and the rest of the built-in analyzer set as build warnings for that single build invocation, giving a concrete, tool-verified complexity signal to cross-reference against manual review — with no lasting change to the repository's own configuration.

### Refactoring Techniques to Reduce Complexity

**Guard clauses instead of nested conditionals** — return early on each disqualifying condition instead of nesting.

## Rules

- Keep each class to one reason to change; if its job needs "and" to describe, split it
- Treat 6+ constructor dependencies as a signal to split the class, not to keep adding parameters
- Watch generically-named classes (`Manager`, `Helper`, `Utility`) for unrelated methods accumulating over time
- Replace `switch`/`if-else` chains that carry business logic over an enum/type with one strategy class per case, resolved via DI
- Never let an override throw `NotSupportedException`/`NotImplementedException` for a member the base contract promises — split the interface instead
- Split fat interfaces into client-specific ones (`IUserReader`/`IUserWriter`) so implementers and test doubles only provide what they use
- Constructor-inject abstractions for anything with side effects or swappable behavior; never `new` up a concrete collaborator that already has an interface elsewhere in the codebase
- Reserve `new` for value objects, DTOs, records, and framework collection types — that's not a DIP violation
- Keep methods under a cyclomatic complexity of ~10; treat 11–20 as a refactor candidate and 21+ as a must-fix
- Use guard clauses, extract method, and named predicate methods to bring a method's complexity back down
- Turn on `CA1502`/`CA1506` for a one-off audit via `-p:EnableNETAnalyzers=true -p:AnalysisLevel=latest-all -p:AnalysisMode=All` instead of permanently editing the project's analyzer configuration

- Avoid a single service class inlining validation, persistence, notification, and logging instead of delegating each to a focused collaborator
- Avoid constructors accepting six or more dependencies, signaling a class doing the work of several
- Avoid a `Manager`/`Helper`/`Utility` class silently accumulating unrelated methods release after release
- Avoid a `switch` or `if/else if` chain over the same enum/type discriminator duplicated across multiple files, each requiring the same edit for every new case
- Avoid an override that throws `NotSupportedException`/`NotImplementedException` for a member its base type or interface promises to support
- Avoid an override with a narrower precondition (rejecting inputs the base type accepts) or a side effect the caller wouldn't expect from the base contract
- Avoid one fat interface with a dozen-plus members where most callers use two or three, forcing every test double to implement all of them
- Avoid multiple implementations of the same interface throwing `NotImplementedException` for different subsets of its members
- Avoid `new ConcreteClassName()` for a side-effecting collaborator inside a class, when an interface for that exact concern already exists and is used elsewhere in the codebase
- Avoid flagging `new List<T>()`, `new SomeDto()`, or other plain value/data construction as if it were a DIP violation
- Avoid methods with cyclomatic complexity well past 25 that have never been flagged because the project never enabled `EnableNETAnalyzers`
- Avoid deeply nested `if/else` chains where guard clauses or extracted predicate methods would cut the complexity substantially

---

### ASP.NET Core integration testing — WebApplicationFactory, CustomWebApplicationFactory, Testcontainers over EF Core InMemory, Respawn/transaction-rollback state resets, HttpClient-based assertions, collection fixtures. Applies to all C# integration test files.
> Applies to: `**/*IntegrationTests.cs`

# ASP.NET Core Integration Testing Conventions

How to write integration tests that exercise the real ASP.NET Core pipeline end-to-end: `WebApplicationFactory` for in-memory hosting, `Testcontainers` for a real database instead of the EF Core InMemory provider, disciplined state resets between tests, and assertions made through `HttpClient` rather than internal services.

## Patterns

### WebApplicationFactory for In-Memory Pipeline Tests

`WebApplicationFactory<TEntryPoint>` boots the full ASP.NET Core pipeline in-memory, including routing, middleware, filters, and DI — without binding a real socket. Use it as the base for every integration test class instead of hand-rolling a `TestServer`.

### CustomWebApplicationFactory: Overriding ConfigureWebHost

Subclass `WebApplicationFactory<TEntryPoint>` and override `ConfigureWebHost` to replace the production `DbContext` registration (and any other real infrastructure, like an outbound email sender) with a test double or a test-scoped connection — without touching `Program.cs`.

### Testcontainers Over the EF Core InMemory Provider

Use `Testcontainers.PostgreSql` (or the equivalent for your engine) to run tests against a real, disposable database instance. The EF Core InMemory provider does not enforce relational constraints (foreign keys, unique indexes, `NOT NULL`), silently allows queries that would fail against a real provider (e.g. certain `GroupBy` or raw SQL translations), and gives false confidence that passes in CI while the production database behaves differently.

### Resetting Database State: Respawn and Transaction Rollback

Reset the database to a known state between tests using either Respawn (deletes all data from all tables, respecting foreign-key order, and re-seeds nothing) or a per-test transaction that is rolled back instead of committed. Never let one test's data bleed into the next.

#### Good — Respawn, reset after every test in the collection

### Testing Through HttpClient, Not Internal Implementation

Drive tests through `factory.CreateClient()` and assert on the HTTP contract — status code, headers, response body shape — rather than reaching into the DI container to call a service or repository directly. Pulling a service out of `factory.Services` bypasses the middleware pipeline, model validation, and serialization you're supposed to be testing.

### Sharing One Testcontainer via Collection Fixtures

Spinning up a fresh Postgres container per test class (or per test) adds seconds of overhead per run. Use `ICollectionFixture<T>` with `[Collection("...")]` to start exactly one container and share it across every test class that needs a database, resetting only the *data* between tests via Respawn or per-test transactions.

### Seeding Minimal, Intention-Revealing Test Data

Seed only the rows a specific test needs, inline in the test (or in a small helper it calls explicitly), instead of relying on a large shared global fixture that every test implicitly depends on. Minimal, local seeding makes each test readable on its own and immune to unrelated seed-data changes.

## Rules

- Base every integration test class on `WebApplicationFactory<Program>` (or a `CustomWebApplicationFactory` subclass) so the real middleware pipeline, routing, and DI graph are exercised.
- Override `ConfigureWebHost`/`ConfigureServices` in a `CustomWebApplicationFactory` to swap real infrastructure (DB context, outbound email/SMS senders) for test-scoped or fake equivalents.
- Run database integration tests against `Testcontainers.PostgreSql` (or the matching engine), never the EF Core InMemory provider — it doesn't enforce relational constraints and produces false confidence.
- Run real EF Core migrations (`context.Database.MigrateAsync()`) against the container on fixture initialization so schema drift is caught by the same tests.
- Reset database state between tests with Respawn or a rolled-back transaction — never let one test's writes leak into the next.
- Assert exclusively through `factory.CreateClient()` and the HTTP contract (status code, headers, JSON body) — do not resolve services from the DI container to bypass the pipeline.
- Share one Testcontainer per test collection via `ICollectionFixture<T>` and `[Collection("...")]`; only reset data between tests, not the container itself.
- Seed the minimal, intention-revealing data each test needs, inline or via a small per-test helper — avoid large shared global seed fixtures.

- Avoid hand-rolling `TestServer`/`IWebHostBuilder` setup instead of using `WebApplicationFactory<TEntryPoint>`, drifting out of sync with the real `Program.cs`.
- Avoid mutating environment variables or static configuration to point at a test database instead of overriding service registration in `ConfigureWebHost`.
- Avoid using the EF Core InMemory provider for anything beyond the most trivial smoke test — it silently accepts constraint violations and unsupported query shapes that fail against a real engine.
- Avoid skipping database resets between tests, causing order-dependent assertions and increasingly flaky suites as more tests are added.
- Avoid resolving services or repositories directly from `factory.Services` instead of driving the test through `HttpClient`, bypassing model binding, validation, and serialization.
- Avoid spinning up a new Testcontainer per test class instead of sharing one via a collection fixture, inflating suite runtime unnecessarily.
- Avoid depending on a large shared/global seed dataset that every test implicitly relies on, making tests unreadable in isolation and fragile to unrelated seed changes.
- Avoid forgetting to run migrations against the test container, so schema mismatches between test and production go undetected.

---

### xUnit unit-testing conventions — Fact/Theory, AAA structure, FluentAssertions, Moq/NSubstitute mocking discipline, test isolation, correct async testing. Applies to all C# unit test files.
> Applies to: `**/*Tests.cs`

# xUnit Unit Testing Conventions

How to write focused, deterministic unit tests with xUnit: naming that documents behavior, Arrange-Act-Assert structure, expressive assertions with FluentAssertions, disciplined mocking of true external dependencies, and correct handling of async code and shared fixtures.

## Patterns

### Fact and Theory Tests

Use `[Fact]` for a single scenario with no inputs, and `[Theory]` with `[InlineData]`, `[MemberData]`, or `[ClassData]` when the same logic must be verified against multiple input/output pairs.

### Test Naming: MethodName_Scenario_ExpectedBehavior

Name every test `MethodName_Scenario_ExpectedBehavior`. The name alone should tell a reader what broke without opening the test body.

### Arrange-Act-Assert Structure

Separate the three phases with a blank line so the shape of the test is visible at a glance. Never interleave setup, invocation, and assertions.

### FluentAssertions Over Raw Asserts

Use FluentAssertions (`result.Should().Be(...)`, `.BeEquivalentTo(...)`, `act.Should().ThrowAsync<T>()`) instead of `Assert.Equal`/`Assert.True`. Fluent assertions read closer to natural language and produce far more diagnostic failure output, especially for object graphs.

### Mocking with Moq or NSubstitute: Only True External Dependencies

Mock repositories, external HTTP clients, message publishers, clocks, and (when its calls are asserted) `ILogger<T>`. Never mock the class under test, and never mock simple value objects or DTOs — construct real instances instead.

With Moq, the equivalent setup uses `Mock<T>` and `Setup`/`Verify` instead of `Substitute.For<T>()` and `Returns`/`Received`:

### Strict vs Loose Mock Behavior

Understand the default: Moq mocks are loose by default (unconfigured members return default values instead of throwing), while `MockBehavior.Strict` throws on any call that wasn't explicitly set up. NSubstitute has no strict mode — unconfigured calls return type defaults. Prefer strict mocks for collaborators where an unexpected call indicates a real bug (e.g. a payment gateway that should never be invoked on validation failure); use loose (default) mocks for incidental dependencies like `ILogger<T>`.

### Test Isolation: No Shared Mutable State

Every test must be able to run alone, in any order, and repeatedly. Do not share mutable fields, static state, or in-memory collections across `[Fact]`/`[Theory]` methods — xUnit creates a new instance of the test class per test, so instance fields are already isolated; the risk is `static` fields and shared fixtures.

### Class Fixtures and Collection Fixtures for Expensive Shared Setup

Use `IClassFixture<T>` to share one expensive object across all tests in a single class (xUnit creates the fixture once per class, disposes it after the last test). Use `ICollectionFixture<T>` with a `[Collection("...")]` attribute to share it across multiple test classes. Only reach for these when setup is genuinely expensive (e.g. spinning up a container or loading a large read-only dataset) — never to share mutable state as a shortcut.

### Testing Async Code Correctly

Always `await` async operations under test. Never call `.Result` or `.Wait()` — both can deadlock in contexts with a synchronization context and, on failure, wrap the real exception in an `AggregateException`, hiding the actual assertion failure.

### Avoiding Over-Assertion on Mock Interactions

Assert on observable behavior — return values, thrown exceptions, state changes — rather than verifying every incidental call a collaborator makes. Reserve `Verify`/`Received` for interactions that are themselves part of the contract (e.g. "a confirmation email must be sent"), not implementation detail that a valid refactor could legitimately change.

## Rules

- Use `[Fact]` for single-scenario tests and `[Theory]` with `InlineData`/`MemberData`/`ClassData` to cover multiple input/output pairs without duplicating test methods.
- Name every test `MethodName_Scenario_ExpectedBehavior` so failures are self-documenting in the test runner output.
- Structure every test body as Arrange / Act / Assert with a blank line between each section.
- Use FluentAssertions (`Should().Be`, `Should().BeEquivalentTo`, `Should().ThrowAsync<T>()`) instead of `Assert.Equal`/`Assert.True` for richer failure diagnostics.
- Mock only true external dependencies — repositories, HTTP/gRPC clients, message brokers, clocks, `ILogger<T>` when its calls matter. Never mock the class under test or plain data objects.
- Choose `MockBehavior.Strict` (Moq) when an unexpected call on a collaborator indicates a real bug; keep incidental dependencies loose.
- Keep test state in instance fields, not `static` fields, so tests are isolated and safe to run in parallel or in any order.
- Reach for `IClassFixture<T>`/`ICollectionFixture<T>` only for genuinely expensive, read-only shared setup — not as a shortcut to share mutable state.
- Always `await` async calls in tests; never call `.Result` or `.Wait()`.
- Assert on observable behavior (return values, exceptions, persisted state, messages sent) rather than exact mock call counts for incidental collaborators.

- Avoid writing near-duplicate `[Fact]` methods that a single `[Theory]` with `InlineData` would replace.
- Avoid vague test names like `Test1`, `Should_Work`, or `GetUser_Works` that don't state the scenario or expected outcome.
- Avoid interleaving arrange/act/assert without blank-line separation, obscuring what's being verified.
- Avoid using `Assert.Equal`/`Assert.True` for object graphs instead of `Should().BeEquivalentTo()`, losing detailed diff output on failure.
- Avoid mocking the system under test, or mocking simple DTOs/value objects that should just be constructed directly.
- Avoid using loose mocks everywhere, including for collaborators where an unexpected call should fail the test (e.g. a payment gateway during a validation-failure test).
- Avoid sharing `static` fields or a shared fixture's mutable state across tests, creating order dependency and parallel-run flakiness.
- Avoid using `IClassFixture<T>` to share mutable domain objects instead of expensive, read-only resources.
- Avoid calling `.Result` or `.Wait()` on a `Task` inside a test, risking deadlocks and burying the real exception inside an `AggregateException`.
- Avoid verifying every mock call and its exact count (`Times.Once`, `VerifyNoOtherCalls()`) on incidental collaborators — brittle tests that fail on valid refactors.

---
