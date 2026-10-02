# .NET Error Handling Analysis

> Analyze error handling patterns, exception middleware, ProblemDetails usage, and error response consistency.

---

Goal: Analyze error handling patterns for consistency and best practices.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/dotnet/error-handling.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/dotnet/error-handling.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **Centralized Exception Handling**:
    *   **`IExceptionHandler`**: Check for one or more `IExceptionHandler`
        implementations registered via `AddExceptionHandler<T>()` /
        `UseExceptionHandler()` (ASP.NET Core 8+), or an equivalent global
        exception-handling middleware, as the single place exceptions are
        translated into HTTP responses.
    *   **Scattered Try/Catch**: Flag repeated `try { ... } catch
        (Exception ex) { return StatusCode(500, ...) }` blocks duplicated
        across controllers/endpoints with inconsistent response shapes —
        this indicates error handling has not actually been centralized,
        even if a global handler also exists.
    *   **Middleware Order**: Verify the exception-handling middleware is
        registered early in the pipeline (before routing/endpoint
        execution) so it can catch exceptions from downstream middleware.

2.  **`ProblemDetails` Response Shape**:
    *   **Standard Shape**: Check that error responses use
        `ProblemDetails` / `ValidationProblemDetails` (RFC 9457) as the
        standard shape, populated via `IProblemDetailsService` or
        `Results.Problem(...)` / `ControllerBase.Problem(...)`, rather than
        ad hoc anonymous objects (`new { error = "..." }`) that vary
        controller to controller.
    *   **`AddProblemDetails()`**: Check that
        `builder.Services.AddProblemDetails(...)` is registered so
        unhandled exceptions and non-2xx status codes automatically
        produce a `ProblemDetails` body.
    *   **Validation Errors**: Verify model-validation failures surface as
        `ValidationProblemDetails` with a populated `Errors` dictionary
        (the default ASP.NET Core behavior for `[ApiController]`) rather
        than a custom, inconsistent shape.

3.  **Custom Domain Exceptions**:
    *   **Specific Exception Types**: Check for domain-specific exception
        types (e.g. `NotFoundException`, `ConflictException`,
        `ValidationException`, `ForbiddenException`) instead of throwing
        or catching the generic `System.Exception` or `ApplicationException`.
    *   **Exception Content**: Verify custom exceptions carry enough
        context to build a meaningful response (an error code, the
        offending id/field, HTTP status mapping) rather than just a
        free-text message.
    *   **Mapping to Status Codes**: Check that the global exception
        handler maps each custom exception type to the correct HTTP status
        code (e.g. `NotFoundException` → 404, `ConflictException` → 409)
        rather than defaulting everything to 500.

4.  **Centralized Error Definitions**:
    *   **No Magic Strings**: Flag error messages/codes duplicated as
        inline string literals scattered across services and controllers.
    *   **Centralized Source**: Check for a centralized source of error
        definitions — an `enum` of error codes, a static class of
        constants, or a resource/message-map keyed by code — that
        services and the exception handler both reference.

5.  **Structured Logging**:
    *   **`ILogger<T>` at the Boundary**: Check that exceptions are
        logged once, with structured parameters (`_logger.LogError(ex,
        "Failed to update order {OrderId}", orderId)`), at the boundary
        where they are handled (the global exception handler or
        middleware) — not scattered ad hoc across the codebase.
    *   **No Log-and-Rethrow**: Flag the log-and-rethrow anti-pattern —
        `catch (Exception ex) { _logger.LogError(ex, ...); throw; }`
        followed by the same exception being logged again further up the
        call stack — which produces duplicate log entries for a single
        failure.
    *   **Appropriate Log Level**: Check that expected/handled conditions
        (e.g. a `NotFoundException` for a bad id) are logged at `Warning`
        or below, reserving `Error`/`Critical` for unexpected failures.

6.  **Production Safety**:
    *   **`IsDevelopment()` Gating**: Verify detailed exception
        information (stack traces, exception messages, inner exceptions)
        is only included in responses when `IWebHostEnvironment
        .IsDevelopment()` is true — check for `UseDeveloperExceptionPage()`
        restricted to development and a generic `ProblemDetails` body used
        otherwise.
    *   **No Stack Leakage**: Flag any response path (custom middleware,
        exception handler, or fallback) that serializes `ex.ToString()`,
        `ex.StackTrace`, or inner exception messages into the client
        response regardless of environment.

7.  **Pre-Mutation Validation**:
    *   **Existence Checks First**: Check that update/delete operations
        first validate the target entity exists (e.g. via a repository
        `GetByIdAsync` followed by a `NotFoundException` throw) before
        attempting the mutation, rather than letting EF Core throw a raw
        `DbUpdateConcurrencyException` or similar low-level error.
    *   **Business Rule Validation**: Verify business invariants (e.g.
        "cannot cancel an already-shipped order") are checked and thrown
        as a specific domain exception before the mutating operation
        executes, not discovered only via a downstream database
        constraint violation.

OUTPUT FORMAT:

Produce one entry per violation found:
*   **File**: `path/to/File.cs:88`
*   **Standard Violated**: `error-handling.md`
*   **Severity**: `Critical` | `Major` | `Minor`
*   **Issue**: One-line description of the violation.
*   **Suggested Fix**: One-line recommended remediation.

Group violations by category (`[Centralization Issue]`,
`[Response Shape Issue]`, `[Exception Type Issue]`,
`[Magic String Issue]`, `[Logging Issue]`, `[Security Issue]`,
`[Pre-Mutation Validation Issue]`) before listing the per-violation
records. Treat any stack-trace/internal-detail leakage outside of
`IsDevelopment()` as `Critical`.

SCORING GUIDANCE:

*   **Strong (85-100)**: Errors are handled centrally via
    `IExceptionHandler`/global middleware, all error responses are
    `ProblemDetails`/`ValidationProblemDetails`, custom domain exceptions
    are used consistently and mapped to correct status codes, error
    codes/messages are centralized, logging is structured and occurs
    exactly once at the boundary, no internal details leak outside
    `IsDevelopment()`, and mutating operations validate existence/business
    rules before acting.
*   **Fair (70-84)**: A centralized handler exists and is used for most
    paths, but with isolated gaps — a controller with a leftover ad hoc
    try/catch, a handful of magic-string error messages, or one operation
    that mutates before validating — without systemic inconsistency or any
    production information leak.
*   **Weak (0-69)**: Error handling is scattered across controllers with
    inconsistent response shapes, generic `Exception` is thrown/caught
    broadly, stack traces or internal details leak to clients regardless
    of environment, logging is duplicated or missing at the boundary, or
    mutating operations run before existence/business-rule checks.
