### Application/service layer patterns for ASP.NET Core Web APIs including DI lifetimes, orchestration, and validation.
> Applies to: `**/*Service*.cs`
# .NET Service Patterns

How to structure the application/service layer in an ASP.NET Core Web API so business logic is testable, controllers stay thin, and dependency injection lifetimes don't create subtle bugs.

## Controllers Stay Thin, Services Hold Logic

A controller's job is to translate HTTP into a call to the service layer and translate the result back into HTTP. Business rules, validation, and orchestration belong in the service.

```csharp
[ApiController]
[Route("api/orders")]
public class OrdersController(IOrderService orderService) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<OrderResponse>> Create(
        CreateOrderRequest request, CancellationToken cancellationToken)
    {
        var order = await orderService.CreateOrderAsync(request, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = order.Id }, order);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<OrderResponse>> GetById(Guid id, CancellationToken cancellationToken)
    {
        var order = await orderService.GetByIdAsync(id, cancellationToken);
        return order is null ? NotFound() : Ok(order);
    }
}
```

## Constructor Injection and DI Lifetimes

Use constructor injection (primary constructors in C# 12 keep this concise) for all dependencies. Choosing the right lifetime matters — it's not just boilerplate.

- **`AddScoped`** — one instance per HTTP request. Use for anything that depends on `DbContext` (which is itself scoped) or that holds per-request state.
- **`AddSingleton`** — one instance for the app's lifetime. Use for stateless, thread-safe services: caches, configuration wrappers, clients that are safe to share (e.g., a properly configured `HttpClient` via `IHttpClientFactory`).
- **`AddTransient`** — a new instance every time it's requested. Use for lightweight, stateless helpers with no meaningful per-request identity.

```csharp
// Scoped: depends on AppDbContext, which is itself scoped
services.AddScoped<IOrderService, OrderService>();
services.AddScoped<IOrderRepository, OrderRepository>();

// Singleton: no per-request state, safe to share across all requests
services.AddSingleton<ICacheKeyBuilder, CacheKeyBuilder>();
services.AddSingleton<IClock, SystemClock>();

// Transient: cheap, stateless, no shared mutable state
services.AddTransient<IPasswordHasher, Pbkdf2PasswordHasher>();
```

#### Bad — captive dependency

```csharp
services.AddSingleton<IOrderService, OrderService>(); // Registered as singleton...

public class OrderService(AppDbContext dbContext) : IOrderService // ...but depends on scoped AppDbContext
{
    // The DbContext instance captured at first resolution is reused for the app's
    // entire lifetime instead of once per request. Concurrent requests now share
    // a single DbContext, which is not thread-safe and will throw or corrupt state.
}
```

A **captive dependency** happens when a longer-lived service (singleton) holds a reference to a shorter-lived one (scoped or transient) captured at construction time. The captured instance then outlives its intended scope. The .NET DI container will throw an `InvalidOperationException` at startup if validation is enabled (`ValidateScopes = true`, on by default in `CreateBuilder` for Development), but it's still worth understanding why: always match a service's lifetime to its shortest-lived dependency, or resolve the dependency per-use via `IServiceScopeFactory` instead of injecting it directly.

```csharp
// If a singleton genuinely needs a scoped dependency, create a scope per use
public class BackgroundOrderProcessor(IServiceScopeFactory scopeFactory) : IOrderProcessor
{
    public async Task ProcessAsync(Guid orderId, CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var orderService = scope.ServiceProvider.GetRequiredService<IOrderService>();
        await orderService.ProcessAsync(orderId, cancellationToken);
    }
}
```

## Splitting Orchestration Into Named Steps

A long monolithic method that validates, mutates, and notifies in one block is hard to read and hard to test in isolation. Split it into small private helpers called from one orchestration method.

```csharp
public class OrderService(
    IOrderRepository orderRepository,
    ICustomerRepository customerRepository,
    IInventoryService inventoryService,
    INotificationService notificationService,
    AppDbContext dbContext) : IOrderService
{
    public async Task<Order> CreateOrderAsync(CreateOrderRequest request, CancellationToken cancellationToken)
    {
        var customer = await ValidateCustomerAsync(request.CustomerId, cancellationToken);
        await ValidateInventoryAsync(request.Items, cancellationToken);

        var order = BuildOrder(customer.Id, request.Items);
        await orderRepository.AddAsync(order, cancellationToken);
        await inventoryService.ReserveStockAsync(request.Items, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        await NotifyCustomerAsync(customer, order, cancellationToken);

        return order;
    }

    private async Task<Customer> ValidateCustomerAsync(Guid customerId, CancellationToken cancellationToken)
    {
        var customer = await customerRepository.GetByIdAsync(customerId, cancellationToken);
        if (customer is null)
        {
            throw new NotFoundException($"Customer {customerId} not found.");
        }

        if (!customer.IsActive)
        {
            throw new BusinessRuleException("Cannot place an order for an inactive customer.");
        }

        return customer;
    }

    private async Task ValidateInventoryAsync(IReadOnlyList<OrderItemRequest> items, CancellationToken cancellationToken)
    {
        foreach (var item in items)
        {
            var available = await inventoryService.GetAvailableStockAsync(item.ProductId, cancellationToken);
            if (available < item.Quantity)
            {
                throw new BusinessRuleException($"Insufficient stock for product {item.ProductId}.");
            }
        }
    }

    private static Order BuildOrder(Guid customerId, IReadOnlyList<OrderItemRequest> items)
    {
        var order = Order.Create(customerId);
        foreach (var item in items)
        {
            order.AddLine(item.ProductId, item.Quantity, item.UnitPrice);
        }
        return order;
    }

    private async Task NotifyCustomerAsync(Customer customer, Order order, CancellationToken cancellationToken)
    {
        await notificationService.SendOrderConfirmationAsync(customer.Email, order.Id, cancellationToken);
    }
}
```

## Validate Before Mutating, Fail Early with Specific Errors

Check entity existence and business rules before performing any mutation, and use exception types (or a result type) that callers can distinguish and map to the right HTTP status.

```csharp
public async Task CancelOrderAsync(Guid orderId, CancellationToken cancellationToken)
{
    var order = await orderRepository.GetByIdAsync(orderId, cancellationToken)
        ?? throw new NotFoundException($"Order {orderId} not found.");

    if (order.Status is OrderStatus.Shipped or OrderStatus.Delivered)
    {
        throw new BusinessRuleException($"Cannot cancel an order in status {order.Status}.");
    }

    order.Cancel();
    await dbContext.SaveChangesAsync(cancellationToken);
}
```

```csharp
// A small hierarchy of domain-specific exceptions mapped centrally
// (e.g. in an exception-handling middleware) to HTTP status codes
public class NotFoundException(string message) : Exception(message);
public class BusinessRuleException(string message) : Exception(message);
```

## Async/Await Without Unnecessary `ConfigureAwait(false)`

Use `async`/`await` consistently for I/O-bound work. A common piece of outdated advice carried over from ASP.NET Framework/desktop code is to append `.ConfigureAwait(false)` to every awaited call to avoid deadlocks. In ASP.NET Core there is no `SynchronizationContext` to resume on, so `ConfigureAwait(false)` has no effect on request-handling code and is unnecessary noise. It still matters in reusable library code that might run under a context (e.g., a NuGet package consumed by both ASP.NET Core and WPF), but not in application-layer services within a Web API project.

```csharp
public async Task<Order?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
{
    return await orderRepository.GetByIdAsync(id, cancellationToken);
}
```

#### Unnecessary (not wrong, just noise in this context)

```csharp
public async Task<Order?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
{
    return await orderRepository.GetByIdAsync(id, cancellationToken).ConfigureAwait(false);
    // Harmless here, but adds no value in ASP.NET Core application code and
    // clutters every call site if applied as a blanket rule
}
```

## MediatR as an Optional Organizational Pattern

For larger applications with many use cases, some teams organize the service layer as MediatR request/response handlers instead of interface-based service classes. This is optional — plain service classes work fine and MediatR should not be adopted just for its own sake.

#### Good — plain service class (the default, no extra dependency)

```csharp
public interface IOrderService
{
    Task<Order> CreateOrderAsync(CreateOrderRequest request, CancellationToken cancellationToken);
}
```

#### Good — MediatR handler (opt in for large apps that benefit from decoupled request/response pipelines)

```csharp
public record CreateOrderCommand(Guid CustomerId, IReadOnlyList<OrderItemRequest> Items) : IRequest<Order>;

public class CreateOrderHandler(
    ICustomerRepository customerRepository,
    IOrderRepository orderRepository,
    AppDbContext dbContext) : IRequestHandler<CreateOrderCommand, Order>
{
    public async Task<Order> Handle(CreateOrderCommand request, CancellationToken cancellationToken)
    {
        var customer = await customerRepository.GetByIdAsync(request.CustomerId, cancellationToken)
            ?? throw new NotFoundException($"Customer {request.CustomerId} not found.");

        var order = Order.Create(customer.Id);
        foreach (var item in request.Items)
        {
            order.AddLine(item.ProductId, item.Quantity, item.UnitPrice);
        }

        await orderRepository.AddAsync(order, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return order;
    }
}

// Controller becomes a thin adapter over ISender
[HttpPost]
public async Task<ActionResult<OrderResponse>> Create(CreateOrderRequest request, ISender sender, CancellationToken cancellationToken)
{
    var order = await sender.Send(new CreateOrderCommand(request.CustomerId, request.Items), cancellationToken);
    return CreatedAtAction(nameof(GetById), new { id = order.Id }, order);
}
```

Reach for MediatR when the number of use cases is large enough that a request/response pipeline (with shared behaviors like validation or logging via `IPipelineBehavior<,>`) pays for itself. Don't introduce it for a handful of endpoints — it adds indirection (command classes, handler classes, DI registration for each) that a plain service class avoids.

## Controlled Concurrency for Batch Processing

Processing a large batch with unbounded `Task.WhenAll` can exhaust database connections, thread pool capacity, or a downstream API's rate limit. Throttle concurrency explicitly.

```csharp
public async Task<BatchResult> ImportOrdersAsync(
    IReadOnlyList<ImportOrderRequest> requests, CancellationToken cancellationToken)
{
    using var throttle = new SemaphoreSlim(initialCount: 8); // At most 8 concurrent operations
    var results = new ConcurrentBag<ImportOutcome>();

    var tasks = requests.Select(async request =>
    {
        await throttle.WaitAsync(cancellationToken);
        try
        {
            var order = await CreateOrderAsync(request, cancellationToken);
            results.Add(ImportOutcome.Success(order.Id));
        }
        catch (Exception ex)
        {
            results.Add(ImportOutcome.Failure(request, ex.Message));
        }
        finally
        {
            throttle.Release();
        }
    });

    await Task.WhenAll(tasks);

    return new BatchResult(results.Where(r => r.Succeeded).ToList(), results.Where(r => !r.Succeeded).ToList());
}
```

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
