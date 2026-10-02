---
description: "Centralized error handling for ASP.NET Core Web APIs - IExceptionHandler, ProblemDetails, domain exceptions, and structured logging."
paths:
  - "src/**/*Exception*.cs"
  - "src/**/*ExceptionHandler*.cs"
  - "src/**/Middleware/*.cs"
---

# ASP.NET Core Error Handling Standards

How to implement consistent, centralized error handling in an ASP.NET Core 8 Web API using `IExceptionHandler`, RFC 7807 `ProblemDetails`, and domain exceptions - instead of scattered try/catch blocks with inconsistent responses.

## Core Principle: Handle Errors in One Place

Do not scatter `try/catch` blocks through controllers, endpoint handlers, and services with each one building its own response shape. Throw domain-specific exceptions from business logic, and let a single, centralized handler translate them into HTTP responses.

**Never use magic strings or ad-hoc status codes** - map exception types to status codes in exactly one place.

## Domain Exceptions

Define a small hierarchy of exceptions that represent business-meaningful failure categories, not raw `Exception`.

```csharp
public abstract class AppException : Exception
{
    protected AppException(string message) : base(message) { }
}

public class NotFoundException : AppException
{
    public NotFoundException(string entityName, object key)
        : base($"{entityName} with id '{key}' was not found.") { }
}

public class ConflictException : AppException
{
    public ConflictException(string message) : base(message) { }
}

public class ValidationFailedException : AppException
{
    public IReadOnlyDictionary<string, string[]> Errors { get; }

    public ValidationFailedException(IReadOnlyDictionary<string, string[]> errors)
        : base("One or more validation errors occurred.")
    {
        Errors = errors;
    }
}

public class BusinessRuleViolationException : AppException
{
    public BusinessRuleViolationException(string message) : base(message) { }
}
```

Throw them from services with real context, not generic messages:

```csharp
public class OrderService : IOrderService
{
    public async Task<Order> GetByIdAsync(Guid id, CancellationToken cancellationToken)
    {
        var order = await _repository.FindAsync(id, cancellationToken);
        return order ?? throw new NotFoundException(nameof(Order), id);
    }

    public async Task CancelAsync(Guid id, CancellationToken cancellationToken)
    {
        var order = await GetByIdAsync(id, cancellationToken);

        if (order.Status == OrderStatus.Shipped)
        {
            throw new BusinessRuleViolationException(
                $"Order '{id}' cannot be cancelled because it has already shipped.");
        }

        order.Status = OrderStatus.Cancelled;
        await _repository.SaveChangesAsync(cancellationToken);
    }
}
```

## Centralized Handling via `IExceptionHandler`

ASP.NET Core 8 introduced `IExceptionHandler` specifically so exception-to-response mapping lives in one testable class instead of ad-hoc middleware.

```csharp
public class AppExceptionHandler : IExceptionHandler
{
    private readonly ILogger<AppExceptionHandler> _logger;
    private readonly IHostEnvironment _environment;

    public AppExceptionHandler(ILogger<AppExceptionHandler> logger, IHostEnvironment environment)
    {
        _logger = logger;
        _environment = environment;
    }

    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var (statusCode, title) = MapException(exception);

        // Log once, here, at the boundary - with full context and the correct level.
        if (statusCode >= StatusCodes.Status500InternalServerError)
        {
            _logger.LogError(exception, "Unhandled exception processing {Method} {Path}",
                httpContext.Request.Method, httpContext.Request.Path);
        }
        else
        {
            _logger.LogWarning("{Title}: {Message} ({Method} {Path})",
                title, exception.Message, httpContext.Request.Method, httpContext.Request.Path);
        }

        var problemDetails = new ProblemDetails
        {
            Status = statusCode,
            Title = title,
            Detail = _environment.IsDevelopment() || statusCode < 500
                ? exception.Message
                : "An unexpected error occurred. Please try again later.",
            Instance = httpContext.Request.Path,
        };

        if (exception is ValidationFailedException validationException)
        {
            var validationProblem = new ValidationProblemDetails(validationException.Errors)
            {
                Status = statusCode,
                Title = title,
                Instance = httpContext.Request.Path,
            };
            httpContext.Response.StatusCode = statusCode;
            await httpContext.Response.WriteAsJsonAsync(validationProblem, cancellationToken);
            return true;
        }

        httpContext.Response.StatusCode = statusCode;
        await httpContext.Response.WriteAsJsonAsync(problemDetails, cancellationToken);
        return true;
    }

    private static (int StatusCode, string Title) MapException(Exception exception) => exception switch
    {
        NotFoundException => (StatusCodes.Status404NotFound, "Resource not found"),
        ConflictException => (StatusCodes.Status409Conflict, "Conflict"),
        ValidationFailedException => (StatusCodes.Status400BadRequest, "Validation failed"),
        BusinessRuleViolationException => (StatusCodes.Status422UnprocessableEntity, "Business rule violation"),
        _ => (StatusCodes.Status500InternalServerError, "An unexpected error occurred"),
    };
}
```

Register it and enable `ProblemDetails` globally:

```csharp
// Program.cs
builder.Services.AddExceptionHandler<AppExceptionHandler>();
builder.Services.AddProblemDetails(); // Ensures ProblemDetails is used for all unhandled errors, incl. 404/405 etc.

var app = builder.Build();

app.UseExceptionHandler(); // No lambda needed - delegates to the registered IExceptionHandler(s)

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage(); // Detailed stack traces only in Development
}
```

## RFC 7807 `ProblemDetails` as the Standard Shape

Always respond with `ProblemDetails` (or `ValidationProblemDetails` for field-level errors), never a bespoke error object. `[ApiController]` already returns `ValidationProblemDetails` for model-binding failures; `AddProblemDetails()` extends that same shape to every other error path (404s, unhandled exceptions, etc.).

```json
// Standard error
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.5.4",
  "title": "Resource not found",
  "status": 404,
  "detail": "Order with id '3fa85f64-5717-4562-b3fc-2c963f66afa6' was not found.",
  "instance": "/api/v1/orders/3fa85f64-5717-4562-b3fc-2c963f66afa6"
}

// Validation error
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.5.1",
  "title": "Validation failed",
  "status": 400,
  "errors": {
    "Email": ["'Email' is not a valid email address."],
    "Quantity": ["'Quantity' must be greater than 0."]
  }
}
```

## Exceptions vs a Result Pattern for Expected Outcomes

Reserve exceptions for truly exceptional, unexpected conditions. For **expected** business outcomes - a validation failure, "already exists," "insufficient balance" - consider a `Result`/`OneOf`-style return type instead, especially in hot paths where throwing is expensive or the failure is a normal, anticipated branch of the workflow. This is an advanced/optional pattern: adopt it deliberately and consistently, not as a one-off in a single method.

#### Optional pattern - `Result<T>` for expected failures

```csharp
public readonly struct Result<T>
{
    public bool IsSuccess { get; }
    public T? Value { get; }
    public string? Error { get; }

    private Result(bool isSuccess, T? value, string? error) =>
        (IsSuccess, Value, Error) = (isSuccess, value, error);

    public static Result<T> Success(T value) => new(true, value, null);
    public static Result<T> Failure(string error) => new(false, default, error);
}

public class WithdrawalService
{
    public async Task<Result<Transaction>> WithdrawAsync(Guid accountId, decimal amount, CancellationToken cancellationToken)
    {
        var account = await _repository.FindAsync(accountId, cancellationToken);
        if (account is null)
        {
            return Result<Transaction>.Failure("Account not found."); // Not exceptional - a routine "not found" outcome
        }

        if (account.Balance < amount)
        {
            return Result<Transaction>.Failure("Insufficient balance."); // Expected, frequent outcome - not exception-worthy
        }

        var transaction = await _repository.WithdrawAsync(accountId, amount, cancellationToken);
        return Result<Transaction>.Success(transaction);
    }
}
```

The endpoint then maps the `Result` to the appropriate status code explicitly, still funneling through the same `ProblemDetails` shape:

```csharp
[HttpPost("{id:guid}/withdraw")]
public async Task<IActionResult> Withdraw(Guid id, WithdrawRequest request, CancellationToken cancellationToken)
{
    var result = await _withdrawalService.WithdrawAsync(id, request.Amount, cancellationToken);

    return result.IsSuccess
        ? Ok(result.Value)
        : Problem(detail: result.Error, statusCode: StatusCodes.Status400BadRequest);
}
```

## Structured Logging at the Boundary

Log with `ILogger<T>` using structured (named) parameters, and log each error exactly once - at the boundary (the exception handler or middleware), not again at every layer it passes through.

```csharp
public class AppExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        _logger.LogError(exception,
            "Request {Method} {Path} failed with {ExceptionType}",
            httpContext.Request.Method,
            httpContext.Request.Path,
            exception.GetType().Name);

        // ... build and write ProblemDetails
        return true;
    }
}

// Deeper in the call stack: let it propagate, do not log again
public async Task<Order> GetByIdAsync(Guid id, CancellationToken cancellationToken)
{
    var order = await _repository.FindAsync(id, cancellationToken);
    return order ?? throw new NotFoundException(nameof(Order), id); // No logging here - handled once at the boundary
}
```

## Hiding Internal Details in Production

Never let stack traces, connection strings, or raw exception messages reach a client outside Development.

```csharp
// Program.cs
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage(); // Full stack traces - Development only
}
else
{
    app.UseExceptionHandler(); // Routes through AppExceptionHandler, which redacts 5xx details in Production
}
```

```csharp
// Inside the handler
Detail = _environment.IsDevelopment() || statusCode < 500
    ? exception.Message           // Safe to show: validation/not-found/conflict messages are user-facing by design
    : "An unexpected error occurred. Please try again later.", // 5xx: never leak internals
```

## Validate Before Mutating

Check existence and business rules before performing a write, and fail with the specific domain exception - don't let an EF Core `DbUpdateException` or a null-reference bubble up as an unhandled 500.

```csharp
public async Task UpdateAsync(Guid id, UpdateInvoiceRequest request, CancellationToken cancellationToken)
{
    var invoice = await _repository.FindAsync(id, cancellationToken)
        ?? throw new NotFoundException(nameof(Invoice), id);

    if (invoice.Status == InvoiceStatus.Paid)
    {
        throw new BusinessRuleViolationException($"Invoice '{id}' is already paid and cannot be modified.");
    }

    invoice.Amount = request.Amount;
    invoice.DueDate = request.DueDate;
    await _repository.SaveChangesAsync(cancellationToken);
}
```

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
