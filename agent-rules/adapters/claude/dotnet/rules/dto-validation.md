---
description: "DTO shape and validation conventions for ASP.NET Core Web APIs - record DTOs, Data Annotations vs FluentValidation, and entity/DTO mapping."
paths:
  - "src/**/Dtos/*.cs"
  - "src/**/Contracts/*.cs"
  - "src/**/*Request.cs"
  - "src/**/*Response.cs"
  - "src/**/*Validator.cs"
---

# ASP.NET Core DTO & Validation Standards

How to shape request/response contracts and validate them in an ASP.NET Core 8 Web API, so entities never leak over the wire and invalid input never reaches a service or handler.

## DTOs as Records

Use C# `record` types for DTOs. Records give you value-based equality, concise positional syntax, and immutability by default - exactly what a request/response contract should be. Never reuse an EF Core entity as a DTO.

```csharp
// Request DTOs - immutable, one per operation
public record CreateCustomerRequest(
    string FirstName,
    string LastName,
    string Email,
    string? PhoneNumber);

public record UpdateCustomerRequest(
    string FirstName,
    string LastName,
    string? PhoneNumber);

// Response DTO - shaped for what the client needs, nothing more
public record CustomerResponse(
    Guid Id,
    string FullName,
    string Email,
    string? PhoneNumber,
    DateTimeOffset CreatedAt);
```

## Separate Create / Update / Response DTOs

Never share one DTO across create, update, and read. Each operation has a different required/optional shape, and collapsing them either forces nullable fields that aren't really optional, or lets clients set fields (like `Id`, `CreatedAt`) they should never control.

```csharp
public record CreateProductRequest(
    string Name,
    string Sku,
    decimal Price,
    int InitialStock);

public record UpdateProductRequest(
    string Name,
    decimal Price); // Sku and stock are not updatable through this endpoint

public record ProductResponse(
    Guid Id,
    string Name,
    string Sku,
    decimal Price,
    int StockOnHand,
    DateTimeOffset CreatedAt,
    DateTimeOffset? LastRestockedAt);
```

## Validation: Data Annotations vs FluentValidation

Use **Data Annotations** for simple, per-property, non-conditional rules - they're integrated with `[ApiController]` and require no extra wiring. Use **FluentValidation** (`AbstractValidator<T>`) once rules become conditional, cross-field, asynchronous (e.g., uniqueness checks), or need to be unit tested independently of the model.

### Data Annotations - simple cases

```csharp
public record CreateUserRequest(
    [property: Required, MaxLength(100)] string FullName,
    [property: Required, EmailAddress] string Email,
    [property: Required, MinLength(8), MaxLength(128)] string Password);
```

With `[ApiController]` on the controller, an invalid `CreateUserRequest` automatically produces a `400 Bad Request` with a `ValidationProblemDetails` body - no manual checks needed.

### FluentValidation - complex/conditional rules

Prefer FluentValidation once you need cross-field rules, conditional requirements, or rules that call a service (e.g., "email must not already exist").

```csharp
public class CreateOrderRequestValidator : AbstractValidator<CreateOrderRequest>
{
    public CreateOrderRequestValidator(IProductAvailabilityService availability)
    {
        RuleFor(x => x.CustomerId).NotEmpty();

        RuleFor(x => x.Items)
            .NotEmpty()
            .WithMessage("An order must contain at least one item.");

        RuleForEach(x => x.Items).ChildRules(item =>
        {
            item.RuleFor(i => i.Quantity).GreaterThan(0);
            item.RuleFor(i => i.ProductId).NotEmpty();
        });

        // Conditional rule: only required when a discount code is present
        RuleFor(x => x.DiscountCode)
            .MinimumLength(4)
            .When(x => !string.IsNullOrEmpty(x.DiscountCode));

        // Async rule calling a service - not expressible with Data Annotations
        RuleForEach(x => x.Items)
            .MustAsync(async (item, cancellationToken) =>
                await availability.IsInStockAsync(item.ProductId, item.Quantity, cancellationToken))
            .WithMessage("One or more items are out of stock.");
    }
}
```

Register FluentValidation and wire it into the pipeline:

```csharp
// Program.cs
builder.Services.AddValidatorsFromAssemblyContaining<CreateOrderRequestValidator>();

// MVC: automatic validation via a filter
builder.Services.AddFluentValidationAutoValidation();
```

For MediatR pipelines, validate as a pipeline behavior so every command/query is validated the same way:

```csharp
public class ValidationBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    private readonly IEnumerable<IValidator<TRequest>> _validators;

    public ValidationBehavior(IEnumerable<IValidator<TRequest>> validators) => _validators = validators;

    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        if (!_validators.Any())
        {
            return await next();
        }

        var context = new ValidationContext<TRequest>(request);
        var failures = (await Task.WhenAll(_validators.Select(v => v.ValidateAsync(context, cancellationToken))))
            .SelectMany(result => result.Errors)
            .Where(failure => failure is not null)
            .ToList();

        if (failures.Count != 0)
        {
            throw new ValidationException(failures);
        }

        return await next();
    }
}
```

For minimal APIs, validate with an endpoint filter instead of hand-checking inside every handler:

```csharp
public class ValidationFilter<T> : IEndpointFilter
{
    private readonly IValidator<T> _validator;

    public ValidationFilter(IValidator<T> validator) => _validator = validator;

    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next)
    {
        var argument = context.Arguments.OfType<T>().FirstOrDefault();
        if (argument is null)
        {
            return Results.BadRequest();
        }

        var result = await _validator.ValidateAsync(argument);
        if (!result.IsValid)
        {
            return Results.ValidationProblem(result.ToDictionary());
        }

        return await next(context);
    }
}

// Usage
group.MapPost("/", Create)
    .AddEndpointFilter<ValidationFilter<CreateOrderRequest>>();
```

## Mapping Between Entities and DTOs

Prefer **explicit manual mapping** for small-to-medium APIs - it's easy to read, easy to debug, and the compiler catches missing members when a DTO or entity changes shape. Reach for AutoMapper or Mapster only when the number of mappings is large enough that hand-writing them is a genuine maintenance burden, and the team accepts the debugging/readability trade-off.

```csharp
public static class CustomerMappings
{
    public static CustomerResponse ToResponse(this Customer customer) =>
        new(
            customer.Id,
            $"{customer.FirstName} {customer.LastName}",
            customer.Email,
            customer.PhoneNumber,
            customer.CreatedAt);

    public static Customer ToEntity(this CreateCustomerRequest request) =>
        new()
        {
            Id = Guid.NewGuid(),
            FirstName = request.FirstName,
            LastName = request.LastName,
            Email = request.Email,
            PhoneNumber = request.PhoneNumber,
            CreatedAt = DateTimeOffset.UtcNow,
        };
}

// Usage
var customer = request.ToEntity();
await _db.Customers.AddAsync(customer);
await _db.SaveChangesAsync();
return customer.ToResponse();
```

#### Acceptable - AutoMapper for large, uniform mapping surfaces

```csharp
public class CustomerProfile : Profile
{
    public CustomerProfile()
    {
        CreateMap<Customer, CustomerResponse>()
            .ForMember(dest => dest.FullName, opt => opt.MapFrom(src => $"{src.FirstName} {src.LastName}"));

        CreateMap<CreateCustomerRequest, Customer>();
    }
}
```

## Excluding Sensitive Fields from Response DTOs

A response DTO's shape is a deliberate allowlist, not "the entity minus whatever I remembered to remove." Never include password hashes, security stamps, refresh tokens, or other internal-only fields.

```csharp
public record UserResponse(
    Guid Id,
    string Email,
    string DisplayName,
    DateTimeOffset CreatedAt);
// Notice: no PasswordHash, no SecurityStamp, no RefreshToken - they simply don't exist on this type

public static UserResponse ToResponse(this User user) =>
    new(user.Id, user.Email, user.DisplayName, user.CreatedAt);
```

## Nullable Annotations Should Match Business Meaning

Enable nullable reference types project-wide (`<Nullable>enable</Nullable>`) and use nullability on DTO properties to communicate whether a field is genuinely optional - not just to satisfy the compiler.

```csharp
public record CreateEmployeeRequest(
    string FirstName,          // Required - non-nullable
    string LastName,           // Required - non-nullable
    string? MiddleName,        // Genuinely optional
    DateOnly HireDate,         // Required
    DateOnly? TerminationDate, // Optional - most employees don't have one yet
    string Email,              // Required
    string? ManagerEmail);     // Optional - not everyone has a manager
```

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
