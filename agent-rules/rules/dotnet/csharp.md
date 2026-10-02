---
description: General C# / .NET 8 language conventions — naming, nullable reference types, records vs classes, pattern matching, LINQ discipline, required members, primary constructors, file-scoped namespaces, async void avoidance. Applies to all C# files.
globs: **/*.cs
alwaysApply: false
---

# C# / .NET 8 Best Practices

General-purpose C# 12 / .NET 8 conventions covering naming, nullability, data-modeling choices (records vs classes), pattern matching, LINQ discipline, modern boilerplate reduction (`required`, primary constructors), namespace style, and safe async usage. These apply across API projects, class libraries, and console tools alike.

## Purpose

Consistent language-level conventions keep a C# codebase predictable to read and safe to refactor:
- Naming that follows the official .NET conventions so IntelliSense, code review, and onboarding all match expectations
- Nullable reference types that make "can this be null?" a compile-time question instead of a runtime surprise
- Deliberate choice between records and classes based on identity vs. value semantics
- Pattern matching and LINQ used precisely, without the subtle bugs multiple enumeration or `Count() > 0` introduce
- Modern C# 12 features (`required`, primary constructors) applied where they remove real boilerplate, not as novelty

## Patterns

### Naming Conventions

Use `PascalCase` for types, methods, properties, and all public members. Use `camelCase` for locals and parameters. Use `_camelCase` for private fields. This matches the official .NET naming conventions and is what analyzers (`.editorconfig` + Roslyn) enforce by default.

#### Good

```csharp
public class OrderProcessor
{
    private readonly IOrderRepository _orderRepository;
    private readonly ILogger<OrderProcessor> _logger;

    public OrderProcessor(IOrderRepository orderRepository, ILogger<OrderProcessor> logger)
    {
        _orderRepository = orderRepository;
        _logger = logger;
    }

    public int MaxRetryCount { get; init; } = 3;

    public async Task<OrderResult> ProcessOrderAsync(Guid orderId, CancellationToken cancellationToken)
    {
        var order = await _orderRepository.GetByIdAsync(orderId, cancellationToken);
        var retryCount = 0;

        return await ExecuteWithRetryAsync(order, retryCount, cancellationToken);
    }
}
```

#### Bad

```csharp
public class orderprocessor // type names must be PascalCase
{
    private readonly IOrderRepository OrderRepository; // public-looking name for a private field
    public IOrderRepository orderRepo; // camelCase on a public member; field exposed directly

    public async Task<OrderResult> process_order_async(Guid OrderId) // method and parameter both wrong case
    {
        var Order = await OrderRepository.GetByIdAsync(OrderId); // local variable in PascalCase
        return await ExecuteWithRetryAsync(Order);
    }
}
```

### Nullable Reference Types Enabled Project-Wide

Enable `<Nullable>enable</Nullable>` in every project file so the compiler tracks nullability of reference types. Treat a nullable warning as a signal to fix the underlying design — add a null check, make the parameter optional deliberately with `?`, or restructure the flow — not as license to suppress it with `!` (the null-forgiving operator) without justification.

```xml
<PropertyGroup>
  <TargetFramework>net8.0</TargetFramework>
  <Nullable>enable</Nullable>
  <ImplicitUsings>enable</ImplicitUsings>
  <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
</PropertyGroup>
```

#### Good

```csharp
public class UserProfileService
{
    private readonly IUserRepository _userRepository;

    public UserProfileService(IUserRepository userRepository) => _userRepository = userRepository;

    public async Task<UserProfile> GetProfileAsync(Guid userId)
    {
        var user = await _userRepository.GetByIdAsync(userId);

        if (user is null)
        {
            throw new NotFoundException($"User {userId} not found");
        }

        return new UserProfile(user.Id, user.DisplayName);
    }

    // Nullable return is explicit and forces callers to handle the absence case.
    public async Task<UserProfile?> TryGetProfileAsync(Guid userId)
    {
        var user = await _userRepository.GetByIdAsync(userId);
        return user is null ? null : new UserProfile(user.Id, user.DisplayName);
    }
}
```

#### Bad

```csharp
public class UserProfileService
{
    public async Task<UserProfile> GetProfileAsync(Guid userId)
    {
        var user = await _userRepository.GetByIdAsync(userId);

        // Suppressing a real compiler warning instead of handling the null case —
        // this throws a NullReferenceException at runtime with no useful message.
        return new UserProfile(user!.Id, user.DisplayName);
    }
}
```

### Records for Immutable Data vs Classes for Entities

Use `record` (or `record struct` for small, frequently copied values) for DTOs, request/response models, and value objects whose equality is based on their content and that should be immutable. Use `class` for entities that have identity (an `Id` that survives mutation), mutable state, or behavior beyond simple data transformation.

#### Good

```csharp
// DTO — immutable, value-based equality, ideal for API contracts.
public record CreateOrderRequest(string Sku, int Quantity, decimal UnitPrice);

public record OrderDto(Guid Id, string CustomerName, decimal Total, OrderStatus Status);

// Value object — two instances with the same coordinates are equal.
public readonly record struct GeoCoordinate(double Latitude, double Longitude);

// Entity — identity persists across mutation; behavior lives on the type.
public class Order
{
    public Guid Id { get; }
    public OrderStatus Status { get; private set; } = OrderStatus.Pending;
    private readonly List<LineItem> _items = new();
    public IReadOnlyList<LineItem> Items => _items;

    public Order(Guid id) => Id = id;

    public void AddItem(LineItem item) => _items.Add(item);

    public void MarkAsShipped()
    {
        if (Status != OrderStatus.Confirmed)
        {
            throw new InvalidOperationException("Only confirmed orders can be shipped.");
        }
        Status = OrderStatus.Shipped;
    }
}
```

#### Bad

```csharp
// Mutable class used as a DTO — loses value-based equality and immutability
// guarantees that make request/response models safe to pass around.
public class CreateOrderRequest
{
    public string Sku { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
}

// Record used for an entity with identity and behavior — records encourage
// `with`-expression copies, which is the wrong mental model for something
// that should be mutated in place and tracked by a single identity.
public record Order(Guid Id, OrderStatus Status)
{
    public void MarkAsShipped() { /* mutating a record's "identity" this way is a smell */ }
}
```

### Pattern Matching Over Long If/Else Chains

Use `switch` expressions and property patterns instead of chains of `if`/`else if` when branching on a value's type or shape. Pattern matching is more concise, exhaustive-checkable by the compiler, and reads as data rather than control flow.

#### Good

```csharp
public static decimal CalculateShippingCost(Order order) => order switch
{
    { Total: >= 100m } => 0m,
    { Items.Count: 0 } => throw new InvalidOperationException("Order has no items"),
    { ShippingMethod: ShippingMethod.Express } => 25m,
    { ShippingMethod: ShippingMethod.Standard, Total: >= 50m } => 5m,
    _ => 10m,
};

public static string Describe(object value) => value switch
{
    int n when n < 0 => "negative integer",
    int => "integer",
    string s when string.IsNullOrWhiteSpace(s) => "blank string",
    string => "string",
    null => "null",
    _ => "unknown",
};
```

#### Bad

```csharp
public static decimal CalculateShippingCost(Order order)
{
    if (order.Total >= 100m)
    {
        return 0m;
    }
    else
    {
        if (order.Items.Count == 0)
        {
            throw new InvalidOperationException("Order has no items");
        }
        else
        {
            if (order.ShippingMethod == ShippingMethod.Express)
            {
                return 25m;
            }
            else if (order.ShippingMethod == ShippingMethod.Standard && order.Total >= 50m)
            {
                return 5m;
            }
            else
            {
                return 10m;
            }
        }
    }
}
```

### LINQ: Avoiding Multiple Enumeration and Count() > 0

Materialize a LINQ query with `.ToList()`/`.ToArray()` when the result will be enumerated more than once — re-enumerating an `IEnumerable<T>` backed by a database query or a generator re-runs the whole query (or, worse, produces different results if the underlying data changed). Use `.Any()` instead of `.Count() > 0`: `Any()` short-circuits on the first element, while `Count()` may have to enumerate the entire sequence.

#### Good

```csharp
public async Task<OrderSummary> BuildSummaryAsync(int customerId)
{
    // Materialized once; both the Sum and the foreach below reuse the same list
    // instead of re-querying the database twice.
    var orders = await _dbContext.Orders
        .Where(o => o.CustomerId == customerId)
        .ToListAsync();

    if (!orders.Any())
    {
        return OrderSummary.Empty;
    }

    var total = orders.Sum(o => o.Total);
    var skus = new List<string>();
    foreach (var order in orders)
    {
        skus.AddRange(order.Items.Select(i => i.Sku));
    }

    return new OrderSummary(total, skus);
}
```

#### Bad

```csharp
public async Task<OrderSummary> BuildSummaryAsync(int customerId)
{
    // IQueryable is never materialized — each use below re-executes the SQL query.
    var orders = _dbContext.Orders.Where(o => o.CustomerId == customerId);

    if (orders.Count() == 0) // full enumeration just to check emptiness
    {
        return OrderSummary.Empty;
    }

    var total = orders.Sum(o => o.Total);      // query execution #1
    var skuList = orders.SelectMany(o => o.Items.Select(i => i.Sku)).ToList(); // query execution #2

    return new OrderSummary(total, skuList);
}
```

### Required Members and Primary Constructors (C# 12)

Use `required` on properties that must be set at construction time instead of a constructor overload whose only job is to enforce that, and use primary constructors on classes whose constructor body would otherwise just assign parameters to fields. Both remove boilerplate without hiding intent.

#### Good

```csharp
public class CreateProductCommand
{
    public required string Name { get; init; }
    public required decimal Price { get; init; }
    public string? Description { get; init; }
}

// Usage forces every required property to be set, checked at compile time:
var command = new CreateProductCommand { Name = "Widget", Price = 9.99m };

// Primary constructor — no hand-written constructor body needed for simple field assignment.
public class ProductService(IProductRepository repository, ILogger<ProductService> logger)
{
    public async Task<Product> GetByIdAsync(Guid id)
    {
        logger.LogInformation("Fetching product {ProductId}", id);
        return await repository.GetByIdAsync(id)
            ?? throw new NotFoundException($"Product {id} not found");
    }
}
```

#### Bad

```csharp
public class CreateProductCommand
{
    public string Name { get; set; } = string.Empty; // silently defaults instead of enforcing a value
    public decimal Price { get; set; }
    public string? Description { get; set; }
}

// Boilerplate constructor that only assigns fields — a primary constructor
// would express the same thing with no loss of clarity.
public class ProductService
{
    private readonly IProductRepository _repository;
    private readonly ILogger<ProductService> _logger;

    public ProductService(IProductRepository repository, ILogger<ProductService> logger)
    {
        _repository = repository;
        _logger = logger;
    }
}
```

### File-Scoped Namespaces

Use file-scoped namespace declarations (`namespace Foo.Bar;`) instead of the block-scoped form. They remove one indentation level from every file and are the default in `dotnet new` templates since .NET 6.

#### Good

```csharp
namespace SomnioApi.Orders;

public class Order
{
    public Guid Id { get; init; }
    public OrderStatus Status { get; private set; }
}
```

#### Bad

```csharp
namespace SomnioApi.Orders
{
    public class Order
    {
        public Guid Id { get; init; }
        public OrderStatus Status { get; private set; }
    }
}
```

### Avoiding async void

Every async method should return `Task` or `Task<T>` so callers can await it, observe exceptions, and compose it with other async work. The only acceptable use of `async void` is a UI event handler whose signature is dictated by the framework — exceptions thrown from `async void` cannot be caught by the caller and crash the process instead.

#### Good

```csharp
public class OrderNotifier
{
    private readonly IEmailSender _emailSender;

    public OrderNotifier(IEmailSender emailSender) => _emailSender = emailSender;

    public async Task NotifyOrderConfirmedAsync(Order order)
    {
        await _emailSender.SendAsync(order.CustomerEmail, "Order confirmed", BuildBody(order));
    }
}

// Caller can await and handle failures:
try
{
    await notifier.NotifyOrderConfirmedAsync(order);
}
catch (EmailDeliveryException ex)
{
    logger.LogWarning(ex, "Failed to notify customer for order {OrderId}", order.Id);
}
```

#### Bad

```csharp
public class OrderNotifier
{
    // async void — the caller has no Task to await, so it cannot know when
    // this completes or catch any exception it throws. An unhandled
    // exception here crashes the process instead of propagating to the caller.
    public async void NotifyOrderConfirmed(Order order)
    {
        await _emailSender.SendAsync(order.CustomerEmail, "Order confirmed", BuildBody(order));
    }
}

// Fire-and-forget call site with no way to observe failure:
notifier.NotifyOrderConfirmed(order);
```

## Best Practices

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

## Common Mistakes

- Mixing case conventions — `PascalCase` locals, `camelCase` public properties, unprefixed private fields — inconsistent with `.editorconfig`/analyzer defaults.
- Suppressing a nullable warning with `!` instead of adding a null check or making the nullability explicit in the signature.
- Using a mutable `class` with public setters for a DTO that should be an immutable `record`.
- Using a `record` for an entity that has identity and needs in-place mutation, encouraging `with`-expression copies that lose the original identity semantics.
- Deeply nested `if`/`else if` chains where a `switch` expression with property patterns would be both shorter and exhaustive-checked.
- Enumerating the same `IQueryable<T>`/lazy `IEnumerable<T>` multiple times, causing repeated database round-trips or inconsistent results.
- Writing `.Count() > 0` (or `.Count() == 0`) instead of `.Any()`/`!.Any()`, forcing a full enumeration just to check emptiness.
- Defaulting required properties to `string.Empty`/`0` instead of marking them `required`, silently allowing incomplete objects to be constructed.
- Writing a boilerplate constructor purely to assign fields when a primary constructor would express the same thing with less code.
- Using block-scoped `namespace Foo { ... }` in new files instead of the file-scoped form.
- Declaring `async void` methods outside of UI event handlers, losing the ability to await completion or catch thrown exceptions.
