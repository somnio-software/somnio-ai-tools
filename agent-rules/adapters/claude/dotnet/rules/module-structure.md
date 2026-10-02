### Project/solution layering, dependency direction, and DI registration organization for ASP.NET Core Web API solutions.
> Applies to: `**/*.cs`
# .NET Module Structure

How to organize an ASP.NET Core Web API solution into layers with a clear dependency direction, consistent folder conventions, and composable dependency-injection registration.

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

## Options Pattern for Configuration

Bind configuration sections into strongly typed options classes instead of injecting `IConfiguration` and reading string keys throughout the codebase.

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
