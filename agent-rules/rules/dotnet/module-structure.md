---
description: Project/solution layering, dependency direction, and DI registration organization for ASP.NET Core Web API solutions.
globs: **/*.cs
alwaysApply: false
---

# .NET Module Structure

How to organize an ASP.NET Core Web API solution into layers with a clear dependency direction, consistent folder conventions, and composable dependency-injection registration.

## Purpose

Module structure determines how easily a codebase can grow. Getting it right:
- Keeps business logic testable without spinning up a database or web host
- Makes the blast radius of a change predictable (a UI change can't leak into domain rules)
- Prevents circular references between projects, which otherwise force awkward workarounds
- Lets `Program.cs` stay a short composition root instead of a 300-line junk drawer
- Makes it obvious where new code belongs, which keeps a growing team consistent

## Solution Layering

### Clean Architecture (four projects)

Use this when the domain has real business rules worth protecting, the API will be long-lived, or multiple entry points (Web API, worker service, CLI) will share the same core logic.

```
src/
├── MyApp.Domain/            # Entities, value objects, domain events, domain interfaces
├── MyApp.Application/       # Use cases, DTOs, application interfaces (IOrderRepository, IEmailSender)
├── MyApp.Infrastructure/    # EF Core DbContext, repository implementations, external clients
└── MyApp.Api/                # Controllers/endpoints, Program.cs, middleware, DI composition
```

#### Good

```csharp
// MyApp.Domain/Entities/Order.cs — zero dependencies on other projects
namespace MyApp.Domain.Entities;

public class Order
{
    public Guid Id { get; private set; }
    public Guid CustomerId { get; private set; }
    public OrderStatus Status { get; private set; }
    private readonly List<OrderLine> _lines = new();
    public IReadOnlyList<OrderLine> Lines => _lines;

    public static Order Create(Guid customerId)
        => new() { Id = Guid.NewGuid(), CustomerId = customerId, Status = OrderStatus.Pending };

    public void AddLine(Guid productId, int quantity, decimal unitPrice)
    {
        if (Status != OrderStatus.Pending)
        {
            throw new InvalidOperationException("Cannot modify a submitted order.");
        }

        _lines.Add(new OrderLine(productId, quantity, unitPrice));
    }
}
```

```csharp
// MyApp.Application/Orders/IOrderRepository.cs — Application depends only on Domain
using MyApp.Domain.Entities;

namespace MyApp.Application.Orders;

public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(Guid id, CancellationToken cancellationToken);
    Task AddAsync(Order order, CancellationToken cancellationToken);
}
```

```csharp
// MyApp.Infrastructure/Persistence/OrderRepository.cs — implements the Application interface
using Microsoft.EntityFrameworkCore;
using MyApp.Application.Orders;
using MyApp.Domain.Entities;

namespace MyApp.Infrastructure.Persistence;

public class OrderRepository(AppDbContext dbContext) : IOrderRepository
{
    public Task<Order?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
        => dbContext.Orders.FirstOrDefaultAsync(o => o.Id == id, cancellationToken);

    public async Task AddAsync(Order order, CancellationToken cancellationToken)
    {
        await dbContext.Orders.AddAsync(order, cancellationToken);
    }
}
```

#### Bad

```csharp
// MyApp.Domain/Entities/Order.cs — domain entity referencing EF Core and Infrastructure
using Microsoft.EntityFrameworkCore; // Domain must never depend on persistence concerns
using MyApp.Infrastructure.Persistence;

namespace MyApp.Domain.Entities;

public class Order
{
    [Column("order_id")] // EF attributes leaking into the domain model
    public Guid Id { get; set; }

    public void Save(AppDbContext context) // Domain entity calling infrastructure directly
    {
        context.Orders.Update(this);
        context.SaveChanges();
    }
}
```

### Pragmatic Three-Layer (smaller services)

For a small internal API, an admin backend, or a service with thin business rules, four projects add overhead without payoff. Use three:

```
src/
├── MyApp.Api/            # Controllers, Program.cs, middleware
├── MyApp.Core/           # Entities, services, interfaces (Domain + Application merged)
└── MyApp.Infrastructure/ # DbContext, repository implementations, external clients
```

The dependency rule stays the same — `Core` has no dependency on `Infrastructure` or `Api`; `Infrastructure` depends on `Core`; `Api` depends on both and wires them together. Do not reach for full Clean Architecture just because it looks more "proper" — a fourth project with one interface in it is a sign the split isn't paying for itself yet. Promote to four layers when `Core` becomes large enough that use-case orchestration and domain rules start stepping on each other.

## Dependency Direction

The rule that must never be violated: **dependencies point inward, toward the domain.**

```
Api  --->  Infrastructure  --->  Application  --->  Domain
 |                                                    ^
 └----------------------------------------------------┘
        (Api may also reference Application/Domain directly)
```

- `Domain` (or `Core`'s domain half) has **zero** project references — no EF Core, no ASP.NET Core, no HTTP clients.
- `Application` depends only on `Domain`. It defines interfaces (`IOrderRepository`, `IEmailSender`) that outer layers implement.
- `Infrastructure` depends on `Application` (to implement its interfaces) and whatever external packages it needs (EF Core, HttpClient, cloud SDKs).
- `Api` depends on all three and is the only place a concrete `Infrastructure` type is ever registered with the DI container.

#### Good

```xml
<!-- MyApp.Application.csproj -->
<ItemGroup>
  <ProjectReference Include="..\MyApp.Domain\MyApp.Domain.csproj" />
</ItemGroup>
```

```xml
<!-- MyApp.Infrastructure.csproj -->
<ItemGroup>
  <ProjectReference Include="..\MyApp.Application\MyApp.Application.csproj" />
</ItemGroup>
```

#### Bad

```xml
<!-- MyApp.Domain.csproj — Domain referencing Infrastructure creates a cycle risk
     and lets persistence concerns leak into entities -->
<ItemGroup>
  <ProjectReference Include="..\MyApp.Infrastructure\MyApp.Infrastructure.csproj" />
</ItemGroup>
```

Enforce this mechanically, don't rely on code review alone. Add an architecture test project using `NetArchTest.Rules`:

```csharp
[Fact]
public void Domain_Should_Not_Depend_On_Infrastructure()
{
    var result = Types.InAssembly(typeof(Order).Assembly)
        .Should()
        .NotHaveDependencyOn("MyApp.Infrastructure")
        .GetResult();

    Assert.True(result.IsSuccessful, string.Join(", ", result.FailingTypeNames ?? []));
}
```

## Feature Folders vs Technical Folders

Both are valid within a layer. Pick one per project and stay consistent.

**Technical folders** (group by role):

```
MyApp.Api/
├── Controllers/
│   ├── OrdersController.cs
│   └── CustomersController.cs
├── Filters/
└── Middleware/
```

**Feature folders** (group by capability):

```
MyApp.Api/
├── Features/
│   ├── Orders/
│   │   ├── OrdersController.cs
│   │   ├── CreateOrderRequest.cs
│   │   └── OrderResponse.cs
│   └── Customers/
│       ├── CustomersController.cs
│       └── CustomerResponse.cs
```

Feature folders scale better once a project has dozens of endpoints, because everything related to "Orders" lives together instead of being scattered across three sibling directories. Technical folders are fine for small APIs where the whole controller list fits on one screen. Whichever you choose, don't mix both conventions in the same project — a codebase where half the features have their own folder and half live in a shared `Controllers/` is harder to navigate than either pure style.

## DI Registration Organization

Do not accumulate every service registration directly in `Program.cs`. Group registrations into `IServiceCollection` extension methods, one per layer/module.

#### Good

```csharp
// MyApp.Application/DependencyInjection.cs
using Microsoft.Extensions.DependencyInjection;

namespace MyApp.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplicationServices(this IServiceCollection services)
    {
        services.AddScoped<IOrderService, OrderService>();
        services.AddScoped<ICustomerService, CustomerService>();
        services.AddValidatorsFromAssemblyContaining<CreateOrderValidator>();
        return services;
    }
}
```

```csharp
// MyApp.Infrastructure/DependencyInjection.cs
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace MyApp.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddDbContext<AppDbContext>(options =>
            options.UseSqlServer(configuration.GetConnectionString("Default")));

        services.AddScoped<IOrderRepository, OrderRepository>();
        services.AddScoped<ICustomerRepository, CustomerRepository>();
        services.Configure<EmailOptions>(configuration.GetSection("Email"));
        return services;
    }
}
```

```csharp
// MyApp.Api/Program.cs — the composition root stays short and declarative
var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddApplicationServices()
    .AddInfrastructureServices(builder.Configuration);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();
app.MapControllers();
app.Run();
```

#### Bad

```csharp
// Program.cs — every registration inlined, growing without bound
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddScoped<IOrderService, OrderService>();
builder.Services.AddScoped<ICustomerService, CustomerService>();
builder.Services.AddScoped<IOrderRepository, OrderRepository>();
builder.Services.AddScoped<ICustomerRepository, CustomerRepository>();
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Default")));
builder.Services.AddScoped<IEmailSender, SmtpEmailSender>();
builder.Services.AddHttpClient<IPaymentGateway, StripePaymentGateway>();
// ...50 more lines, no grouping, no ownership boundary
```

## Options Pattern for Configuration

Bind configuration sections into strongly typed options classes instead of injecting `IConfiguration` and reading string keys throughout the codebase.

#### Good

```csharp
public class EmailOptions
{
    public const string SectionName = "Email";

    public required string SmtpHost { get; init; }
    public int SmtpPort { get; init; } = 587;
    public required string FromAddress { get; init; }
}
```

```csharp
// Registration
services.Configure<EmailOptions>(configuration.GetSection(EmailOptions.SectionName));
```

```csharp
// Consumption — no magic strings, compiler-checked, easy to unit test with Options.Create
public class SmtpEmailSender(IOptions<EmailOptions> options) : IEmailSender
{
    private readonly EmailOptions _options = options.Value;

    public Task SendAsync(string to, string subject, string body)
    {
        // use _options.SmtpHost, _options.SmtpPort, _options.FromAddress
        return Task.CompletedTask;
    }
}
```

#### Bad

```csharp
// IConfiguration sprinkled through services with magic string keys
public class SmtpEmailSender(IConfiguration configuration) : IEmailSender
{
    public Task SendAsync(string to, string subject, string body)
    {
        var host = configuration["Email:SmtpHost"];       // typo-prone, no compile-time check
        var port = int.Parse(configuration["Email:SmtpPort"] ?? "587");
        var from = configuration["Email:FromAddress"];
        // ...
        return Task.CompletedTask;
    }
}
```

Prefer `IOptionsSnapshot<T>` over `IOptions<T>` for scoped services that need config to reload per-request in development, and `IOptionsMonitor<T>` for singletons that need to react to config changes at runtime. Plain `IOptions<T>` is fine for values that never change after startup.

## Best Practices

- Choose Clean Architecture (`Domain`/`Application`/`Infrastructure`/`Api`) when the domain has real business rules or multiple entry points share it; choose the pragmatic three-layer split for small, simple services
- Keep `Domain` (or `Core`) free of every external package reference, including EF Core and ASP.NET Core
- Register services through one `IServiceCollection` extension method per layer, composed in `Program.cs`
- Bind configuration into `IOptions<T>` classes instead of reading `IConfiguration` keys directly in services
- Pick either feature folders or technical folders per project, and apply that choice consistently
- Add an `NetArchTest`-based architecture test suite once the solution has more than a couple of projects, so layering rules are enforced by CI, not by memory
- Keep `Program.cs` a short, readable composition root — if it's doing more than wiring things together, extract that logic

## Common Mistakes

- Domain entities referencing EF Core attributes, `DbContext`, or other infrastructure types
- A four-project Clean Architecture split for a five-endpoint internal tool that never needed the ceremony
- `Program.cs` accumulating hundreds of lines of inline service registrations
- `IConfiguration["Section:Key"]` string lookups scattered across services instead of bound options classes
- Circular project references introduced by a "just this once" shortcut (e.g., `Infrastructure` referencing `Api` to reuse a DTO)
- Mixing feature folders and technical folders inconsistently within the same project
- Registering `Infrastructure` types (concrete repository classes, `DbContext`) from `Application` or `Domain` instead of the composition root
- No architecture tests, so layering violations are only caught in code review, if at all
