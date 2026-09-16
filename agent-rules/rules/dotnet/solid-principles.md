---
description: SOLID principles (SRP, OCP, LSP, ISP, DIP) applied to ASP.NET Core / C# services, plus cyclomatic complexity as a measurable proxy for SRP/OCP violations.
globs: **/*.cs
alwaysApply: false
---

# SOLID Principles for .NET / C#

The five SOLID principles are less a checklist than a shared vocabulary for describing *why* a design is hard to change. In an ASP.NET Core codebase they show up concretely: a service constructor with too many dependencies, a `switch` that has to be edited every sprint, an override that throws `NotSupportedException`, an interface no single caller fully uses, or a `new SmtpClient()` buried inside business logic. Each violation has a detectable shape, and each has a standard fix. This file works through all five principles with realistic C# 12 / .NET 8 examples, then covers cyclomatic complexity — the metric that most directly correlates with SRP and OCP violations and can be measured without adding any new tooling to the project.

## Purpose

Applying SOLID deliberately, rather than as folklore, matters because:
- It keeps classes small enough to unit test without standing up half the application
- It lets new business rules (a new order type, a new notification channel) be added by adding a class, not editing five existing ones
- It prevents "successful-looking" abstractions (base classes, fat interfaces) from quietly lying about what they support
- It keeps mocking and stubbing in tests cheap — a 2-method interface is trivial to fake, a 15-method one is not
- It keeps the object graph loosely coupled enough to swap an implementation (a different email provider, a different payment gateway) without touching callers
- It gives a concrete, measurable early-warning signal (cyclomatic complexity) before a class becomes unreadable, rather than relying on gut feel during review

## Single Responsibility Principle (SRP)

A class should have one reason to change. When a class's method list reads like a table of contents for three unrelated features, it has three reasons to change and will be touched by three unrelated teams/PRs.

### One Class Doing Validation, Persistence, Notification, and Logging

#### Good

```csharp
public interface IUserValidator
{
    void EnsureValid(CreateUserRequest request);
}

public class UserValidator : IUserValidator
{
    public void EnsureValid(CreateUserRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || !request.Email.Contains('@'))
        {
            throw new ValidationException("A valid email address is required.");
        }
        if (request.Password.Length < 8)
        {
            throw new ValidationException("Password must be at least 8 characters.");
        }
    }
}

// Thin orchestrator: each concern is delegated to a collaborator built for it.
public class UserService(
    IUserValidator validator,
    IUserRepository userRepository,
    IEmailSender emailSender,
    ILogger<UserService> logger) : IUserService
{
    public async Task<User> RegisterAsync(CreateUserRequest request, CancellationToken cancellationToken)
    {
        validator.EnsureValid(request);

        if (await userRepository.EmailExistsAsync(request.Email, cancellationToken))
        {
            throw new BusinessRuleException($"Email {request.Email} is already registered.");
        }

        var user = User.Create(request.Email, request.Password);
        await userRepository.AddAsync(user, cancellationToken);
        await emailSender.SendWelcomeEmailAsync(user.Email, cancellationToken);

        logger.LogInformation("Registered user {UserId}", user.Id);
        return user;
    }
}
```

#### Bad

```csharp
// One class doing validation, persistence, email delivery, and logging inline —
// four unrelated reasons for this class to change.
public class UserService(AppDbContext dbContext, IConfiguration configuration)
{
    public async Task<User> RegisterAsync(CreateUserRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || !request.Email.Contains('@'))
        {
            throw new Exception("Invalid email");
        }
        if (request.Password.Length < 8)
        {
            throw new Exception("Password too short");
        }

        if (await dbContext.Users.AnyAsync(u => u.Email == request.Email))
        {
            throw new Exception("Email already registered");
        }

        var user = new User { Email = request.Email, PasswordHash = Hash(request.Password) };
        dbContext.Users.Add(user);
        await dbContext.SaveChangesAsync();

        // Raw SMTP wiring embedded directly instead of delegating to IEmailSender
        using var client = new System.Net.Mail.SmtpClient(configuration["Smtp:Host"]);
        client.Send(new System.Net.Mail.MailMessage("noreply@app.com", user.Email, "Welcome", "Thanks for signing up"));

        // Logging embedded directly to a file, bypassing the app's logging abstraction
        await File.AppendAllTextAsync("audit.log", $"{DateTime.UtcNow}: Registered {user.Email}\n");

        return user;
    }

    private static string Hash(string password) => Convert.ToBase64String(
        System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(password)));
}
```

### Other SRP Smells to Watch For

- **6+ constructor dependencies.** A class injecting `IOrderRepository, ICustomerRepository, IInventoryService, INotificationService, IPricingEngine, ITaxCalculator, IReportExporter, IAuditLogger` is coordinating order creation, pricing, tax, reporting, *and* auditing in one place. Split it into `OrderService` (order creation) and `OrderReportingService` (reporting) so each has one cohesive job.
- **A single method over ~50 lines** mixing validation, I/O, business rules, and formatting in one block — a strong signal the method (and likely its containing class) has more than one reason to change. See the "Splitting Orchestration Into Named Steps" pattern in `service-patterns.md`.
- **Generic names as an SRP magnet.** `OrderManager`, `StringHelper`, `DataUtility` are not automatically wrong — a small, stateless `DateRangeHelper` with two tightly related methods (`GetStartOfWeek`, `GetEndOfWeek`) is fine. The smell is when an `OrderManager` that started with status transitions quietly grows methods for emailing, PDF generation, and shipping calculation because "it was already injected everywhere." The heuristic: if you can't summarize the class's job in one sentence without "and," split it.

## Open/Closed Principle (OCP)

A module should be open for extension but closed for modification — adding new behavior should mean adding new code, not editing code that already works and is already tested.

### Switch/If-Else Chains Over a Business Discriminator

The most common OCP violation in application code is a `switch` or `if/else if` chain over an `enum`/type discriminator that contains real business logic. Every new case requires editing an existing, already-shipped method — and if the same discriminator is switched over in more than one place, every new case means editing *all* of them.

#### Good — one strategy per case, resolved through DI

```csharp
public interface IDiscountStrategy
{
    OrderType AppliesTo { get; }
    decimal Calculate(Order order);
}

public class RetailDiscountStrategy : IDiscountStrategy
{
    public OrderType AppliesTo => OrderType.Retail;
    public decimal Calculate(Order order) => order.Subtotal >= 100m ? order.Subtotal * 0.05m : 0m;
}

public class WholesaleDiscountStrategy : IDiscountStrategy
{
    public OrderType AppliesTo => OrderType.Wholesale;
    public decimal Calculate(Order order) => order.Subtotal * 0.15m;
}

// Resolved via a dictionary built from all registered strategies — adding a new
// order type means adding a new IDiscountStrategy implementation, nothing else.
public class DiscountCalculator(IEnumerable<IDiscountStrategy> strategies)
{
    private readonly IReadOnlyDictionary<OrderType, IDiscountStrategy> _strategies =
        strategies.ToDictionary(s => s.AppliesTo);

    public decimal Calculate(Order order)
    {
        if (!_strategies.TryGetValue(order.Type, out var strategy))
        {
            throw new NotSupportedException($"No discount strategy registered for {order.Type}.");
        }
        return strategy.Calculate(order);
    }
}

// Registration — adding OrderType.Government tomorrow means adding one class
// and one line here, not touching DiscountCalculator or any existing strategy.
services.AddSingleton<IDiscountStrategy, RetailDiscountStrategy>();
services.AddSingleton<IDiscountStrategy, WholesaleDiscountStrategy>();
services.AddSingleton<DiscountCalculator>();
```

#### Bad — a switch that must be edited every time a new order type is added

```csharp
public class DiscountCalculator
{
    public decimal Calculate(Order order)
    {
        switch (order.Type)
        {
            case OrderType.Retail:
                return order.Subtotal >= 100m ? order.Subtotal * 0.05m : 0m;
            case OrderType.Wholesale:
                return order.Subtotal * 0.15m;
            // Every new OrderType requires editing this already-shipped, already-tested
            // method — and if OrderType is also switched over in ShippingCalculator and
            // InvoiceFormatter, all three need the same edit.
            default:
                return 0m;
        }
    }
}
```

Not every `switch` is an OCP violation — mapping an enum to a display string, or a simple one-to-one property translation, is fine as a `switch` expression (see `csharp.md`). The signal to watch for is business *logic* (calculations, branching side effects) inside the switch, duplicated across multiple files for the same discriminator.

## Liskov Substitution Principle (LSP)

A subtype must be usable anywhere its base type or interface is expected, without the caller needing to know which concrete type it got. If calling a method through the base contract can throw for some subtypes but not others, the contract is being violated, not fulfilled.

#### Good — the interface is split so a read-only implementation only implements what it actually supports

```csharp
public interface IReadRepository<T>
{
    Task<T?> GetByIdAsync(Guid id, CancellationToken cancellationToken);
}

public interface IRepository<T> : IReadRepository<T>
{
    Task AddAsync(T entity, CancellationToken cancellationToken);
    Task DeleteAsync(Guid id, CancellationToken cancellationToken);
}

// A read-only view over an external, non-owned data source only implements
// IReadRepository<T> — it makes no promise it can't keep.
public class ArchivedOrderReadRepository(AppDbContext dbContext) : IReadRepository<Order>
{
    public Task<Order?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
        => dbContext.ArchivedOrders.FirstOrDefaultAsync(o => o.Id == id, cancellationToken)!;
}

// A mutable repository implements the full IRepository<T> and can genuinely honor it.
public class OrderRepository(AppDbContext dbContext) : IRepository<Order>
{
    public Task<Order?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
        => dbContext.Orders.FirstOrDefaultAsync(o => o.Id == id, cancellationToken);

    public async Task AddAsync(Order entity, CancellationToken cancellationToken)
        => await dbContext.Orders.AddAsync(entity, cancellationToken);

    public async Task DeleteAsync(Guid id, CancellationToken cancellationToken)
    {
        var order = await GetByIdAsync(id, cancellationToken)
            ?? throw new NotFoundException($"Order {id} not found.");
        dbContext.Orders.Remove(order);
    }
}
```

#### Bad — a fat interface forces an implementation to fake support it doesn't have

```csharp
public interface IRepository<T>
{
    Task<T?> GetByIdAsync(Guid id, CancellationToken cancellationToken);
    Task AddAsync(T entity, CancellationToken cancellationToken);
    Task DeleteAsync(Guid id, CancellationToken cancellationToken);
}

// A read-only view is forced to implement Delete because the interface promises it —
// any caller programming against IRepository<Order> can call Delete and get a runtime
// crash instead of a compile-time signal that this operation isn't supported.
public class ArchivedOrderReadRepository(AppDbContext dbContext) : IRepository<Order>
{
    public Task<Order?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
        => dbContext.ArchivedOrders.FirstOrDefaultAsync(o => o.Id == id, cancellationToken)!;

    public Task AddAsync(Order entity, CancellationToken cancellationToken)
        => throw new NotSupportedException("Archived orders are read-only.");

    public Task DeleteAsync(Guid id, CancellationToken cancellationToken)
        => throw new NotSupportedException("Archived orders are read-only.");
    // This type is not substitutable for IRepository<Order> — code that works
    // correctly against OrderRepository breaks at runtime against this one.
}
```

LSP is also violated more subtly, without an outright exception: an override with a **narrower precondition** (rejecting inputs the base type accepts — e.g. a `WireTransferProcessor : PaymentProcessor` whose override throws for any `amount < 500m` when the base `ChargeAsync` accepts any positive amount) or a **widened side effect** the caller wouldn't expect from the base contract. If a subtype genuinely can't support the base contract's full input range, it should not inherit from (or implement) that contract — model the constraint as a distinct type instead of a runtime surprise.

## Interface Segregation Principle (ISP)

Clients should depend only on the members they actually use. A fat interface forces every implementer — including test doubles — to provide (or fake) members that are irrelevant to most callers.

#### Good — split by client need

```csharp
public interface IUserReader
{
    Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<User>> SearchAsync(string query, CancellationToken cancellationToken);
}

public interface IUserWriter
{
    Task<User> CreateAsync(CreateUserRequest request, CancellationToken cancellationToken);
    Task UpdateAsync(Guid id, UpdateUserRequest request, CancellationToken cancellationToken);
}

// A profile page only needs reads — its test double implements two methods, not a dozen.
public class UserProfileController(IUserReader userReader) : ControllerBase
{
    [HttpGet("{id:guid}")]
    public async Task<ActionResult<User>> GetById(Guid id, CancellationToken cancellationToken)
    {
        var user = await userReader.GetByIdAsync(id, cancellationToken);
        return user is null ? NotFound() : Ok(user);
    }
}
```

#### Bad — one fat interface every caller and every test double must fully implement

```csharp
public interface IUserService
{
    Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<User>> SearchAsync(string query, CancellationToken cancellationToken);
    Task<User> CreateAsync(CreateUserRequest request, CancellationToken cancellationToken);
    Task UpdateAsync(Guid id, UpdateUserRequest request, CancellationToken cancellationToken);
    Task DeleteAsync(Guid id, CancellationToken cancellationToken);
    Task SendWelcomeEmailAsync(Guid userId, CancellationToken cancellationToken);
    Task<bool> VerifyPasswordAsync(Guid userId, string password, CancellationToken cancellationToken);
    Task LockAccountAsync(Guid userId, CancellationToken cancellationToken);
    Task<IReadOnlyList<string>> GetRolesAsync(Guid userId, CancellationToken cancellationToken);
}

// A controller that only reads a profile is still coupled to all nine members —
// and any unit test needs a mock/stub implementing every single one, even the
// eight it never calls.
public class UserProfileController(IUserService userService) : ControllerBase
{
    [HttpGet("{id:guid}")]
    public async Task<ActionResult<User>> GetById(Guid id, CancellationToken cancellationToken)
    {
        var user = await userService.GetByIdAsync(id, cancellationToken);
        return user is null ? NotFound() : Ok(user);
    }
}
```

A strong ISP violation signal, tying back to LSP: if multiple implementations of an interface throw `NotImplementedException`/`NotSupportedException` for a subset of members, the interface is asking for more than any single implementer can honestly provide, and should be split.

## Dependency Inversion Principle (DIP)

High-level modules (business logic) should not depend on low-level modules (concrete infrastructure); both should depend on abstractions. In practice: constructor-inject interfaces, never `new` up a concrete collaborator inside a class that has business logic.

#### Good — the abstraction is injected, the concrete type is registered in DI

```csharp
public interface IEmailSender
{
    Task SendAsync(string to, string subject, string body, CancellationToken cancellationToken);
}

public class SmtpEmailSender(IOptions<SmtpOptions> options) : IEmailSender
{
    public async Task SendAsync(string to, string subject, string body, CancellationToken cancellationToken)
    {
        using var client = new SmtpClient(options.Value.Host, options.Value.Port);
        using var message = new MailMessage(options.Value.From, to, subject, body);
        await client.SendMailAsync(message, cancellationToken);
    }
}

public class OrderNotificationService(IEmailSender emailSender) : IOrderNotificationService
{
    public Task NotifyOrderConfirmedAsync(Order order, CancellationToken cancellationToken)
        => emailSender.SendAsync(order.CustomerEmail, "Order confirmed", $"Order {order.Id} is confirmed.", cancellationToken);
}

// Registration — swapping SmtpEmailSender for a SendGrid-based sender later
// touches one line here, not OrderNotificationService or any of its callers.
services.AddScoped<IEmailSender, SmtpEmailSender>();
services.AddScoped<IOrderNotificationService, OrderNotificationService>();
```

#### Bad — a concrete, side-effecting collaborator is instantiated inline

```csharp
public class OrderNotificationService
{
    public async Task NotifyOrderConfirmedAsync(Order order)
    {
        // Instantiates a concrete SmtpClient directly inside business logic. This class
        // cannot be unit tested without actually sending an email, cannot be reused with
        // a different email provider, and hardcodes infrastructure config inline.
        using var client = new SmtpClient("smtp.internal.somniosoftware.com", 587);
        using var message = new MailMessage("noreply@somniosoftware.com", order.CustomerEmail,
            "Order confirmed", $"Order {order.Id} is confirmed.");
        await client.SendMailAsync(message);
    }
}
```

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

```bash
dotnet build -p:EnableNETAnalyzers=true -p:AnalysisLevel=latest-all -p:AnalysisMode=All
```

This surfaces `CA1502`, `CA1506`, and the rest of the built-in analyzer set as build warnings for that single build invocation, giving a concrete, tool-verified complexity signal to cross-reference against manual review — with no lasting change to the repository's own configuration.

### Refactoring Techniques to Reduce Complexity

**Guard clauses instead of nested conditionals** — return early on each disqualifying condition instead of nesting.

#### Good

```csharp
public decimal CalculateShippingCost(Order order)
{
    if (order.Items.Count == 0)
    {
        return 0m;
    }
    if (order.ShippingMethod == ShippingMethod.Express)
    {
        return 25m;
    }
    if (order.Total >= 100m)
    {
        return 0m;
    }
    return order.ShippingMethod == ShippingMethod.Standard && order.Total >= 50m ? 5m : 10m;
}
```

#### Bad

```csharp
public decimal CalculateShippingCost(Order order)
{
    // Every additional case adds another level of nesting and another decision
    // point, pushing this method's cyclomatic complexity higher with each change.
    if (order.Items.Count > 0)
    {
        if (order.ShippingMethod == ShippingMethod.Express)
        {
            return 25m;
        }
        else if (order.Total >= 100m)
        {
            return 0m;
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
    else
    {
        return 0m;
    }
}
```

Three other techniques compound well with guard clauses:

- **Extract method** for independent sub-checks: replace one 40-line `EnsureValid` with a top-level method that calls `EnsureHasItems`, `EnsureQuantitiesArePositive`, `EnsureCustomerIsSpecified` — the total branch count in the class is unchanged, but complexity is measured per-method, so each piece is now independently readable and testable.
- **Replace conditional logic with polymorphism** — the same fix as the Open/Closed example above. A `switch`/`if-else` chain branching on type or discriminator is both an OCP violation and a complexity hot spot; replacing it with one small strategy class per case removes the branching entirely.
- **Extract complex boolean expressions into named predicates**: `order.Total >= 75m && (order.ShippingMethod == ShippingMethod.Standard || order.ShippingMethod == ShippingMethod.Express) && !order.IsBackordered` becomes `HasQualifyingTotal(order) && IsStandardOrExpress(order) && !order.IsBackordered` — same number of decision points, but each one now has a name that documents what it checks.

## Best Practices

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

## Common Mistakes

- A single service class inlining validation, persistence, notification, and logging instead of delegating each to a focused collaborator
- Constructors accepting six or more dependencies, signaling a class doing the work of several
- A `Manager`/`Helper`/`Utility` class silently accumulating unrelated methods release after release
- A `switch` or `if/else if` chain over the same enum/type discriminator duplicated across multiple files, each requiring the same edit for every new case
- An override that throws `NotSupportedException`/`NotImplementedException` for a member its base type or interface promises to support
- An override with a narrower precondition (rejecting inputs the base type accepts) or a side effect the caller wouldn't expect from the base contract
- One fat interface with a dozen-plus members where most callers use two or three, forcing every test double to implement all of them
- Multiple implementations of the same interface throwing `NotImplementedException` for different subsets of its members
- `new ConcreteClassName()` for a side-effecting collaborator inside a class, when an interface for that exact concern already exists and is used elsewhere in the codebase
- Flagging `new List<T>()`, `new SomeDto()`, or other plain value/data construction as if it were a DIP violation
- Methods with cyclomatic complexity well past 25 that have never been flagged because the project never enabled `EnableNETAnalyzers`
- Deeply nested `if/else` chains where guard clauses or extracted predicate methods would cut the complexity substantially
