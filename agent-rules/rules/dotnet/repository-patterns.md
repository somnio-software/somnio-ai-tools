---
description: Repository pattern over EF Core, async query patterns, pagination, and Unit of Work for ASP.NET Core Web APIs.
globs: **/*Repository*.cs
alwaysApply: false
---

# .NET Repository Patterns

How to build a data access layer over EF Core 8 that stays testable, avoids N+1 queries, and keeps transaction boundaries at the right level.

## Purpose

The data access layer sits between business logic and the database. Done well, it:
- Lets services be unit tested without a real database
- Prevents ORM-specific query shapes (`IQueryable<T>`, tracked entities) from leaking into business logic
- Keeps query performance predictable — no accidental N+1s, no unbounded result sets
- Makes the transaction boundary ("what happens atomically") explicit instead of implicit

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

```csharp
public class ProductsController(AppDbContext dbContext) : ControllerBase
{
    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ProductResponse>> GetById(Guid id, CancellationToken cancellationToken)
    {
        var product = await dbContext.Products
            .AsNoTracking()
            .Where(p => p.Id == id)
            .Select(p => new ProductResponse(p.Id, p.Name, p.Price))
            .FirstOrDefaultAsync(cancellationToken);

        return product is null ? NotFound() : Ok(product);
    }
}
```

#### Bad — repository abstraction with no consumers benefiting from it

```csharp
// A generic pass-through that adds a layer of indirection without adding value
public interface IProductRepository
{
    Task<Product?> GetByIdAsync(Guid id);
}

public class ProductRepository(AppDbContext dbContext) : IProductRepository
{
    public Task<Product?> GetByIdAsync(Guid id)
        => dbContext.Products.FirstOrDefaultAsync(p => p.Id == id);
    // One method, one caller, never mocked, never swapped. Pure ceremony.
}
```

## Avoid Generic Repository Interfaces

`IRepository<T>` looks appealing because it's reusable, but it tends to either leak `IQueryable<T>` (defeating the point of the abstraction) or force awkward generic method names (`FindAll`, `FindOne`, `Find(Expression<Func<T, bool>>)`) that don't say what the query actually does.

#### Good — specific repository, intention-revealing methods

```csharp
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<Order>> GetActiveOrdersForUserAsync(Guid userId, CancellationToken cancellationToken);
    Task<(IReadOnlyList<Order> Items, int TotalCount)> GetPagedAsync(
        int page, int pageSize, CancellationToken cancellationToken);
    Task AddAsync(Order order, CancellationToken cancellationToken);
}

public class OrderRepository(AppDbContext dbContext) : IOrderRepository
{
    public Task<Order?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
        => dbContext.Orders
            .Include(o => o.Lines)
            .FirstOrDefaultAsync(o => o.Id == id, cancellationToken);

    public async Task<IReadOnlyList<Order>> GetActiveOrdersForUserAsync(Guid userId, CancellationToken cancellationToken)
    {
        return await dbContext.Orders
            .AsNoTracking()
            .Where(o => o.CustomerId == userId && o.Status != OrderStatus.Completed)
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    public async Task<(IReadOnlyList<Order> Items, int TotalCount)> GetPagedAsync(
        int page, int pageSize, CancellationToken cancellationToken)
    {
        var query = dbContext.Orders.AsNoTracking().OrderByDescending(o => o.CreatedAt);

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return (items, totalCount);
    }

    public async Task AddAsync(Order order, CancellationToken cancellationToken)
    {
        await dbContext.Orders.AddAsync(order, cancellationToken);
    }
}
```

#### Bad — generic repository leaking `IQueryable` and vague method names

```csharp
public interface IRepository<T> where T : class
{
    IQueryable<T> FindAll(); // Leaks EF's IQueryable outside the data layer
    Task<T?> FindOne(Expression<Func<T, bool>> predicate); // Any predicate — no intent, no reuse
}

public class Repository<T>(AppDbContext dbContext) : IRepository<T> where T : class
{
    public IQueryable<T> FindAll() => dbContext.Set<T>(); // Caller now writes LINQ against a "repository"

    public Task<T?> FindOne(Expression<Func<T, bool>> predicate)
        => dbContext.Set<T>().FirstOrDefaultAsync(predicate);
}

// Consumer ends up writing raw query logic anyway, defeating the abstraction:
var activeOrders = orderRepository.FindAll()
    .Where(o => o.CustomerId == userId && o.Status != OrderStatus.Completed)
    .ToList(); // synchronous enumeration of an IQueryable — also blocks a thread
```

## `AsNoTracking()` for Read-Only Queries

EF Core tracks entities by default so it can detect changes for `SaveChangesAsync()`. That tracking has a real cost (snapshotting, change detection) and is wasted work for queries that only read data.

#### Good

```csharp
public async Task<IReadOnlyList<OrderSummaryResponse>> GetRecentOrdersAsync(
    Guid customerId, CancellationToken cancellationToken)
{
    return await dbContext.Orders
        .AsNoTracking() // Read-only: skip change tracking overhead
        .Where(o => o.CustomerId == customerId)
        .OrderByDescending(o => o.CreatedAt)
        .Take(20)
        .Select(o => new OrderSummaryResponse(o.Id, o.Status, o.Total))
        .ToListAsync(cancellationToken);
}

public async Task UpdateStatusAsync(Guid orderId, OrderStatus status, CancellationToken cancellationToken)
{
    // Tracking required: this entity will be mutated and saved
    var order = await dbContext.Orders.FirstOrDefaultAsync(o => o.Id == orderId, cancellationToken)
        ?? throw new NotFoundException($"Order {orderId} not found.");

    order.UpdateStatus(status);
    await dbContext.SaveChangesAsync(cancellationToken);
}
```

#### Bad

```csharp
public async Task<IReadOnlyList<OrderSummaryResponse>> GetRecentOrdersAsync(
    Guid customerId, CancellationToken cancellationToken)
{
    // No AsNoTracking() — every entity is snapshotted for change detection
    // even though the result is immediately mapped to a read-only DTO and discarded
    var orders = await dbContext.Orders
        .Where(o => o.CustomerId == customerId)
        .OrderByDescending(o => o.CreatedAt)
        .Take(20)
        .ToListAsync(cancellationToken);

    return orders.Select(o => new OrderSummaryResponse(o.Id, o.Status, o.Total)).ToList();
}
```

## Avoiding N+1 Queries

Lazy loading and per-item queries in a loop generate one query per row. Use eager loading or projection instead.

#### Good — eager loading with `Include`/`ThenInclude`

```csharp
public Task<Order?> GetWithDetailsAsync(Guid id, CancellationToken cancellationToken)
    => dbContext.Orders
        .Include(o => o.Lines)
            .ThenInclude(l => l.Product)
        .Include(o => o.Customer)
        .AsNoTracking()
        .FirstOrDefaultAsync(o => o.Id == id, cancellationToken);
```

#### Good — projection avoids loading full entities entirely

```csharp
public Task<List<OrderLineResponse>> GetLineSummariesAsync(Guid orderId, CancellationToken cancellationToken)
    => dbContext.OrderLines
        .AsNoTracking()
        .Where(l => l.OrderId == orderId)
        .Select(l => new OrderLineResponse(l.ProductId, l.Product.Name, l.Quantity, l.UnitPrice))
        .ToListAsync(cancellationToken);
```

#### Bad — N+1: one query for orders, then one query per order for its lines

```csharp
public async Task<List<OrderResponse>> GetOrdersWithLineCountAsync(CancellationToken cancellationToken)
{
    var orders = await dbContext.Orders.ToListAsync(cancellationToken);
    var result = new List<OrderResponse>();

    foreach (var order in orders)
    {
        // Executes a separate round trip to the database for every single order
        var lineCount = await dbContext.OrderLines.CountAsync(l => l.OrderId == order.Id, cancellationToken);
        result.Add(new OrderResponse(order.Id, lineCount));
    }

    return result;
}
```

## Unit of Work: `SaveChangesAsync()` Once Per Business Operation

`SaveChangesAsync()` should be called once per business operation, at the boundary of the operation — not once per repository method. Repositories stage changes (`Add`, `Update`, `Remove`); the caller commits them together so the operation is atomic.

#### Good

```csharp
public class OrderRepository(AppDbContext dbContext) : IOrderRepository
{
    public async Task AddAsync(Order order, CancellationToken cancellationToken)
    {
        await dbContext.Orders.AddAsync(order, cancellationToken);
        // No SaveChangesAsync here — the caller decides when the unit of work commits
    }
}

public class CreateOrderService(
    IOrderRepository orderRepository,
    IInventoryRepository inventoryRepository,
    AppDbContext dbContext) : ICreateOrderService
{
    public async Task<Order> ExecuteAsync(CreateOrderRequest request, CancellationToken cancellationToken)
    {
        var order = Order.Create(request.CustomerId);
        foreach (var item in request.Items)
        {
            order.AddLine(item.ProductId, item.Quantity, item.UnitPrice);
        }

        await orderRepository.AddAsync(order, cancellationToken);
        await inventoryRepository.ReserveStockAsync(request.Items, cancellationToken);

        // One commit for the whole business operation — both changes succeed or fail together
        await dbContext.SaveChangesAsync(cancellationToken);

        return order;
    }
}
```

#### Bad

```csharp
public class OrderRepository(AppDbContext dbContext) : IOrderRepository
{
    public async Task AddAsync(Order order, CancellationToken cancellationToken)
    {
        await dbContext.Orders.AddAsync(order, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken); // Commits immediately
    }
}

public class InventoryRepository(AppDbContext dbContext) : IInventoryRepository
{
    public async Task ReserveStockAsync(IEnumerable<OrderItem> items, CancellationToken cancellationToken)
    {
        // ...
        await dbContext.SaveChangesAsync(cancellationToken); // A second, separate commit
    }
}

// If ReserveStockAsync fails, the order was already committed by the first SaveChangesAsync —
// there is no way to roll both operations back together without an explicit transaction.
```

For operations spanning multiple `SaveChangesAsync()` calls that must be atomic, wrap them in an explicit transaction instead of relying on call order:

```csharp
await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
try
{
    await orderRepository.AddAsync(order, cancellationToken);
    await dbContext.SaveChangesAsync(cancellationToken);

    await inventoryRepository.ReserveStockAsync(request.Items, cancellationToken);
    await dbContext.SaveChangesAsync(cancellationToken);

    await transaction.CommitAsync(cancellationToken);
}
catch
{
    await transaction.RollbackAsync(cancellationToken);
    throw;
}
```

## Pagination

Never return an unbounded result set. Always page with `Skip()`/`Take()` and return a total count alongside the page.

#### Good

```csharp
public record PagedResult<T>(IReadOnlyList<T> Items, int Page, int PageSize, int TotalCount);

public async Task<PagedResult<OrderSummaryResponse>> GetPagedAsync(
    int page, int pageSize, CancellationToken cancellationToken)
{
    page = Math.Max(page, 1);
    pageSize = Math.Clamp(pageSize, 1, 100); // Cap page size to prevent abuse

    var query = dbContext.Orders.AsNoTracking().OrderByDescending(o => o.CreatedAt);

    var totalCount = await query.CountAsync(cancellationToken);
    var items = await query
        .Skip((page - 1) * pageSize)
        .Take(pageSize)
        .Select(o => new OrderSummaryResponse(o.Id, o.Status, o.Total))
        .ToListAsync(cancellationToken);

    return new PagedResult<OrderSummaryResponse>(items, page, pageSize, totalCount);
}
```

#### Bad

```csharp
public Task<List<Order>> GetAllOrdersAsync(CancellationToken cancellationToken)
    => dbContext.Orders.ToListAsync(cancellationToken);
    // No limit, no paging — fine with 50 rows, an outage with 5 million
```

## Async Everywhere

Every EF Core call in an async method should use its async counterpart. Mixing in synchronous calls (`ToList()`, `FirstOrDefault()`, `SaveChanges()`) inside async code blocks a thread pool thread and can deadlock under load.

#### Good

```csharp
public async Task<Order?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
{
    return await dbContext.Orders
        .AsNoTracking()
        .FirstOrDefaultAsync(o => o.Id == id, cancellationToken);
}
```

#### Bad

```csharp
public async Task<Order?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
{
    // Synchronous EF Core call inside an async method — blocks a thread waiting on I/O
    return dbContext.Orders.FirstOrDefault(o => o.Id == id);
}

public async Task SaveAsync(Order order)
{
    dbContext.Orders.Update(order);
    dbContext.SaveChanges(); // Should be SaveChangesAsync
}
```

Always accept and forward a `CancellationToken` through repository methods so a cancelled HTTP request can actually cancel the underlying query instead of running to completion needlessly.

## Best Practices

- Skip repositories for small APIs; inject `DbContext` directly when there's no testability or swappability need
- When you do introduce repositories, write specific, intention-revealing methods (`GetActiveOrdersForUserAsync`) instead of a generic `IRepository<T>`
- Never return `IQueryable<T>` from a repository — it leaks the ORM outside the data layer and hides what query actually executes
- Use `AsNoTracking()` for every read-only query; keep tracking only for entities that will be mutated and saved
- Use `Include()`/`ThenInclude()` or `Select()` projections to avoid N+1 queries — never query in a loop
- Call `SaveChangesAsync()` once per business operation; wrap multi-step operations in an explicit transaction if they span multiple saves
- Always paginate list endpoints with `Skip()`/`Take()` and return a total count; cap the maximum page size
- Use the async EF Core APIs (`ToListAsync`, `FirstOrDefaultAsync`, `SaveChangesAsync`) exclusively inside async methods, and thread a `CancellationToken` through every call

## Common Mistakes

- Introducing a generic `IRepository<T>` "for consistency" on a project with three entities and no test-mocking need
- Repository methods that return `IQueryable<T>`, letting callers bolt on arbitrary LINQ
- Missing `AsNoTracking()` on read-only queries, paying change-tracking cost for data that's never saved
- Querying inside a `foreach` loop instead of eager-loading or projecting (N+1)
- Calling `SaveChangesAsync()` inside every repository method instead of once at the operation boundary
- Returning `List<T>` from a "get all" method with no `Skip()`/`Take()` and no upper bound on page size
- Mixing synchronous EF Core calls (`.Result`, `.Wait()`, `ToList()`, `SaveChanges()`) into async code paths
- Forgetting to pass `CancellationToken` through repository and query methods
