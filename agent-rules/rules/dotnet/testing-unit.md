---
description: xUnit unit-testing conventions — Fact/Theory, AAA structure, FluentAssertions, Moq/NSubstitute mocking discipline, test isolation, correct async testing. Applies to all C# unit test files.
globs: **/*Tests.cs
alwaysApply: false
---

# xUnit Unit Testing Conventions

How to write focused, deterministic unit tests with xUnit: naming that documents behavior, Arrange-Act-Assert structure, expressive assertions with FluentAssertions, disciplined mocking of true external dependencies, and correct handling of async code and shared fixtures.

## Purpose

Unit tests verify a single unit of behavior in isolation from its collaborators. They:
- Document the expected behavior of a method through their name and body
- Fail fast and precisely when a regression is introduced
- Run in milliseconds, with no I/O, network, or filesystem access
- Stay green across valid refactors because they assert on observable behavior, not implementation details

## Patterns

### Fact and Theory Tests

Use `[Fact]` for a single scenario with no inputs, and `[Theory]` with `[InlineData]`, `[MemberData]`, or `[ClassData]` when the same logic must be verified against multiple input/output pairs.

#### Good

```csharp
public class DiscountCalculatorTests
{
    [Fact]
    public void ApplyDiscount_WhenCustomerIsNotEligible_ReturnsOriginalPrice()
    {
        var calculator = new DiscountCalculator();

        var result = calculator.ApplyDiscount(price: 100m, isEligible: false);

        result.Should().Be(100m);
    }

    [Theory]
    [InlineData(100, 0.10, 90)]
    [InlineData(200, 0.25, 150)]
    [InlineData(50, 0, 50)]
    public void ApplyDiscount_WithVariousRates_ReturnsExpectedPrice(
        decimal price, decimal rate, decimal expected)
    {
        var calculator = new DiscountCalculator();

        var result = calculator.ApplyDiscount(price, rate);

        result.Should().Be(expected);
    }

    public static IEnumerable<object[]> InvalidPrices =>
        new List<object[]>
        {
            new object[] { -1m },
            new object[] { decimal.MinValue },
        };

    [Theory]
    [MemberData(nameof(InvalidPrices))]
    public void ApplyDiscount_WithNegativePrice_ThrowsArgumentOutOfRangeException(decimal price)
    {
        var calculator = new DiscountCalculator();

        Action act = () => calculator.ApplyDiscount(price, rate: 0.1m);

        act.Should().Throw<ArgumentOutOfRangeException>();
    }
}
```

#### Bad

```csharp
// Copy-pasted [Fact] methods instead of one parameterized Theory
[Fact]
public void ApplyDiscount_Rate10_Returns90() { /* ... */ }

[Fact]
public void ApplyDiscount_Rate25_Returns150() { /* ... */ }

// InlineData with a generic name and no indication of what's being verified
[Theory]
[InlineData(100, 0.10, 90)]
public void Test1(decimal a, decimal b, decimal c) =>
    new DiscountCalculator().ApplyDiscount(a, b).Should().Be(c);
```

### Test Naming: MethodName_Scenario_ExpectedBehavior

Name every test `MethodName_Scenario_ExpectedBehavior`. The name alone should tell a reader what broke without opening the test body.

#### Good

```csharp
public class UserServiceTests
{
    [Fact]
    public async Task GetUser_WhenNotFound_ThrowsNotFoundException()
    {
        var repository = Substitute.For<IUserRepository>();
        repository.GetByIdAsync(Arg.Any<Guid>()).Returns((User?)null);
        var sut = new UserService(repository);

        Func<Task> act = () => sut.GetUser(Guid.NewGuid());

        await act.Should().ThrowAsync<NotFoundException>()
            .WithMessage("*User*not found*");
    }

    [Fact]
    public async Task GetUser_WhenFound_ReturnsMappedUserDto()
    {
        var existing = new User { Id = Guid.NewGuid(), Email = "a@b.com" };
        var repository = Substitute.For<IUserRepository>();
        repository.GetByIdAsync(existing.Id).Returns(existing);
        var sut = new UserService(repository);

        var result = await sut.GetUser(existing.Id);

        result.Should().BeEquivalentTo(new UserDto(existing.Id, existing.Email));
    }
}
```

#### Bad

```csharp
[Fact]
public async Task Test_GetUser() { /* ambiguous — success or failure? */ }

[Fact]
public async Task GetUser_Works() { /* "works" is not a behavior */ }

[Fact]
public async Task Should_Throw() { /* which method? which scenario? */ }
```

### Arrange-Act-Assert Structure

Separate the three phases with a blank line so the shape of the test is visible at a glance. Never interleave setup, invocation, and assertions.

#### Good

```csharp
[Fact]
public void CalculateTotal_WithMultipleLineItems_SumsLineTotals()
{
    // Arrange
    var order = new Order();
    order.AddItem(new LineItem("SKU-1", quantity: 2, unitPrice: 10m));
    order.AddItem(new LineItem("SKU-2", quantity: 1, unitPrice: 5m));

    // Act
    var total = order.CalculateTotal();

    // Assert
    total.Should().Be(25m);
}
```

#### Bad

```csharp
[Fact]
public void CalculateTotal_WithMultipleLineItems_SumsLineTotals()
{
    var order = new Order();
    order.AddItem(new LineItem("SKU-1", quantity: 2, unitPrice: 10m));
    var total = order.CalculateTotal(); // Act mixed into Arrange, asserted mid-flow
    total.Should().Be(20m);
    order.AddItem(new LineItem("SKU-2", quantity: 1, unitPrice: 5m));
    order.CalculateTotal().Should().Be(25m);
}
```

### FluentAssertions Over Raw Asserts

Use FluentAssertions (`result.Should().Be(...)`, `.BeEquivalentTo(...)`, `act.Should().ThrowAsync<T>()`) instead of `Assert.Equal`/`Assert.True`. Fluent assertions read closer to natural language and produce far more diagnostic failure output, especially for object graphs.

#### Good

```csharp
[Fact]
public void MapToDto_WithNestedAddress_MapsAllFields()
{
    var customer = new Customer
    {
        Id = 1,
        Name = "Ada Lovelace",
        Address = new Address { City = "London", PostalCode = "W1" },
    };

    var dto = CustomerMapper.MapToDto(customer);

    dto.Should().BeEquivalentTo(new CustomerDto
    {
        Id = 1,
        Name = "Ada Lovelace",
        City = "London",
        PostalCode = "W1",
    });
}

[Fact]
public async Task Withdraw_WhenInsufficientFunds_ThrowsInsufficientFundsException()
{
    var account = new Account(balance: 50m);

    Func<Task> act = () => account.WithdrawAsync(100m);

    await act.Should().ThrowAsync<InsufficientFundsException>()
        .WithMessage("*insufficient funds*");
}
```

#### Bad

```csharp
[Fact]
public void MapToDto_WithNestedAddress_MapsAllFields()
{
    var customer = new Customer { Id = 1, Name = "Ada Lovelace" };

    var dto = CustomerMapper.MapToDto(customer);

    // Field-by-field Assert.Equal — verbose, and a failure only reports the first mismatch
    Assert.Equal(1, dto.Id);
    Assert.Equal("Ada Lovelace", dto.Name);
    Assert.True(dto.City == customer.Address.City);
}

[Fact]
public async Task Withdraw_WhenInsufficientFunds_ThrowsInsufficientFundsException()
{
    var account = new Account(balance: 50m);

    // No message assertion, and swallows the exception type distinction
    await Assert.ThrowsAsync<Exception>(() => account.WithdrawAsync(100m));
}
```

### Mocking with Moq or NSubstitute: Only True External Dependencies

Mock repositories, external HTTP clients, message publishers, clocks, and (when its calls are asserted) `ILogger<T>`. Never mock the class under test, and never mock simple value objects or DTOs — construct real instances instead.

#### Good

```csharp
public class OrderServiceTests
{
    private readonly IOrderRepository _repository = Substitute.For<IOrderRepository>();
    private readonly IPaymentGateway _paymentGateway = Substitute.For<IPaymentGateway>();
    private readonly OrderService _sut;

    public OrderServiceTests()
    {
        _sut = new OrderService(_repository, _paymentGateway);
    }

    [Fact]
    public async Task PlaceOrder_WhenPaymentSucceeds_PersistsConfirmedOrder()
    {
        var request = new PlaceOrderRequest("SKU-1", Quantity: 2);
        _paymentGateway.ChargeAsync(Arg.Any<decimal>()).Returns(PaymentResult.Success());

        var order = await _sut.PlaceOrder(request);

        order.Status.Should().Be(OrderStatus.Confirmed);
        await _repository.Received(1).SaveAsync(Arg.Is<Order>(o => o.Status == OrderStatus.Confirmed));
    }
}
```

With Moq, the equivalent setup uses `Mock<T>` and `Setup`/`Verify` instead of `Substitute.For<T>()` and `Returns`/`Received`:

```csharp
var paymentGateway = new Mock<IPaymentGateway>();
paymentGateway.Setup(g => g.ChargeAsync(It.IsAny<decimal>()))
    .ReturnsAsync(PaymentResult.Failure("card declined"));

var sut = new OrderService(repository.Object, paymentGateway.Object);
Func<Task> act = () => sut.PlaceOrder(new PlaceOrderRequest("SKU-1", Quantity: 1));

await act.Should().ThrowAsync<PaymentDeclinedException>();
repository.Verify(r => r.SaveAsync(It.IsAny<Order>()), Times.Never);
```

#### Bad

```csharp
// Mocking the class under test defeats the purpose of the test
var sutMock = new Mock<OrderService>();
sutMock.Setup(s => s.PlaceOrder(It.IsAny<PlaceOrderRequest>()))
    .ReturnsAsync(new Order());

// Mocking a plain DTO instead of just constructing one
var addressMock = new Mock<Address>();
addressMock.Setup(a => a.City).Returns("London");

// Real dependency swapped for a mock even though it has no I/O and is fast/deterministic
var calculatorMock = new Mock<ITaxCalculator>(); // ITaxCalculator is a pure function, just use the real one
```

### Strict vs Loose Mock Behavior

Understand the default: Moq mocks are loose by default (unconfigured members return default values instead of throwing), while `MockBehavior.Strict` throws on any call that wasn't explicitly set up. NSubstitute has no strict mode — unconfigured calls return type defaults. Prefer strict mocks for collaborators where an unexpected call indicates a real bug (e.g. a payment gateway that should never be invoked on validation failure); use loose (default) mocks for incidental dependencies like `ILogger<T>`.

#### Good

```csharp
[Fact]
public async Task PlaceOrder_WhenValidationFails_NeverCallsPaymentGateway()
{
    // Strict: any unconfigured call on the payment gateway throws MockException,
    // making an accidental charge attempt fail the test immediately.
    var paymentGateway = new Mock<IPaymentGateway>(MockBehavior.Strict);
    var repository = new Mock<IOrderRepository>();
    var logger = new Mock<ILogger<OrderService>>(); // loose: we don't care about log calls here

    var sut = new OrderService(repository.Object, paymentGateway.Object, logger.Object);
    var invalidRequest = new PlaceOrderRequest("", Quantity: -1);

    Func<Task> act = () => sut.PlaceOrder(invalidRequest);

    await act.Should().ThrowAsync<ValidationException>();
    paymentGateway.VerifyNoOtherCalls();
}
```

#### Bad

```csharp
// Loose mock hides the fact that PlaceOrder accidentally reaches the payment gateway —
// the unconfigured ChargeAsync call silently returns default(PaymentResult) (null)
// and the bug surfaces as a NullReferenceException three layers away, or not at all.
var paymentGateway = new Mock<IPaymentGateway>();
var sut = new OrderService(repository.Object, paymentGateway.Object);
await sut.PlaceOrder(invalidRequest); // swallows the real defect
```

### Test Isolation: No Shared Mutable State

Every test must be able to run alone, in any order, and repeatedly. Do not share mutable fields, static state, or in-memory collections across `[Fact]`/`[Theory]` methods — xUnit creates a new instance of the test class per test, so instance fields are already isolated; the risk is `static` fields and shared fixtures.

#### Good

```csharp
public class ShoppingCartTests
{
    // A fresh instance field per test — xUnit instantiates the class per test method.
    private readonly ShoppingCart _cart = new();

    [Fact]
    public void AddItem_IncreasesItemCount()
    {
        _cart.AddItem(new CartItem("SKU-1", 1));

        _cart.ItemCount.Should().Be(1);
    }

    [Fact]
    public void RemoveItem_WhenCartIsEmpty_ThrowsInvalidOperationException()
    {
        Action act = () => _cart.RemoveItem("SKU-1");

        act.Should().Throw<InvalidOperationException>();
    }
}
```

#### Bad

```csharp
public class ShoppingCartTests
{
    // Static state shared across every test instance and every test run —
    // test order now matters, and parallel test runners will race on it.
    private static readonly ShoppingCart SharedCart = new();

    [Fact]
    public void AddItem_IncreasesItemCount()
    {
        SharedCart.AddItem(new CartItem("SKU-1", 1));
        SharedCart.ItemCount.Should().Be(1); // fails if another test already added items
    }
}
```

### Class Fixtures and Collection Fixtures for Expensive Shared Setup

Use `IClassFixture<T>` to share one expensive object across all tests in a single class (xUnit creates the fixture once per class, disposes it after the last test). Use `ICollectionFixture<T>` with a `[Collection("...")]` attribute to share it across multiple test classes. Only reach for these when setup is genuinely expensive (e.g. spinning up a container or loading a large read-only dataset) — never to share mutable state as a shortcut.

#### Good

```csharp
// Created once per test class; the open SQLite connection is the expensive resource.
public class DatabaseSchemaFixture : IDisposable
{
    public SqliteConnection Connection { get; } = new("DataSource=:memory:");

    public DatabaseSchemaFixture()
    {
        Connection.Open();
        using var context = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(Connection).Options);
        context.Database.EnsureCreated(); // expensive; run once per class, not once per test
    }

    public void Dispose() => Connection.Dispose();
}

public class ProductRepositoryTests : IClassFixture<DatabaseSchemaFixture>
{
    private readonly AppDbContext _context;

    public ProductRepositoryTests(DatabaseSchemaFixture fixture)
    {
        _context = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(fixture.Connection).Options);
    }

    [Fact]
    public async Task GetById_WhenProductExists_ReturnsProduct()
    {
        _context.Products.Add(new Product { Id = 1, Name = "Widget" });
        await _context.SaveChangesAsync();
        var sut = new ProductRepository(_context);

        var result = await sut.GetById(1);

        result!.Name.Should().Be("Widget");
    }
}
```

#### Bad

```csharp
// Reusing a fixture to share mutable domain state between tests instead of
// just expensive setup — tests now depend on execution order.
public class OrderTestFixture
{
    public Order SharedOrder { get; } = new Order();
}

public class OrderTests : IClassFixture<OrderTestFixture>
{
    private readonly OrderTestFixture _fixture;
    public OrderTests(OrderTestFixture fixture) => _fixture = fixture;

    [Fact]
    public void Test1() => _fixture.SharedOrder.AddItem(new LineItem("SKU-1", 1, 10m));

    [Fact]
    public void Test2() => _fixture.SharedOrder.Items.Should().HaveCount(1); // depends on Test1 having run first
}
```

### Testing Async Code Correctly

Always `await` async operations under test. Never call `.Result` or `.Wait()` — both can deadlock in contexts with a synchronization context and, on failure, wrap the real exception in an `AggregateException`, hiding the actual assertion failure.

#### Good

```csharp
[Fact]
public async Task GetOrderTotal_ReturnsCalculatedTotal()
{
    var repository = Substitute.For<IOrderRepository>();
    repository.GetByIdAsync(1).Returns(new Order { Total = 42.50m });
    var sut = new OrderQueryService(repository);

    var total = await sut.GetOrderTotal(1);

    total.Should().Be(42.50m);
}

[Fact]
public async Task GetOrderTotal_WhenOrderMissing_ThrowsNotFoundException()
{
    var repository = Substitute.For<IOrderRepository>();
    repository.GetByIdAsync(Arg.Any<int>()).Returns((Order?)null);
    var sut = new OrderQueryService(repository);

    Func<Task> act = () => sut.GetOrderTotal(999);

    await act.Should().ThrowAsync<NotFoundException>();
}
```

#### Bad

```csharp
[Fact]
public void GetOrderTotal_ReturnsCalculatedTotal()
{
    var repository = Substitute.For<IOrderRepository>();
    repository.GetByIdAsync(1).Returns(new Order { Total = 42.50m });
    var sut = new OrderQueryService(repository);

    // .Result blocks the thread and can deadlock; on failure the real exception
    // is buried inside an AggregateException instead of surfacing directly.
    // Assert.Throws also does not work with Task-returning methods — it never
    // observes an exception thrown inside an async method.
    var total = sut.GetOrderTotal(1).Result;

    total.Should().Be(42.50m);
}
```

### Avoiding Over-Assertion on Mock Interactions

Assert on observable behavior — return values, thrown exceptions, state changes — rather than verifying every incidental call a collaborator makes. Reserve `Verify`/`Received` for interactions that are themselves part of the contract (e.g. "a confirmation email must be sent"), not implementation detail that a valid refactor could legitimately change.

#### Good

```csharp
[Fact]
public async Task PlaceOrder_WhenSuccessful_SendsOrderConfirmationEmail()
{
    var emailSender = Substitute.For<IEmailSender>();
    var sut = new OrderService(Substitute.For<IOrderRepository>(), emailSender);
    var request = new PlaceOrderRequest("SKU-1", Quantity: 1);

    var order = await sut.PlaceOrder(request);

    // The email being sent IS the contract being tested here.
    await emailSender.Received(1).SendOrderConfirmationAsync(order.Id);
}
```

#### Bad

```csharp
[Fact]
public async Task PlaceOrder_CallsRepositoryMethodsInExactOrder()
{
    var repository = new Mock<IOrderRepository>();
    var sut = new OrderService(repository.Object, Substitute.For<IEmailSender>());
    var request = new PlaceOrderRequest("SKU-1", Quantity: 1);

    await sut.PlaceOrder(request);

    // Over-specifying internal call sequence and count — breaks on any valid
    // refactor of PlaceOrder's internals even though behavior is unchanged.
    repository.Verify(r => r.BeginTransactionAsync(), Times.Once);
    repository.Verify(r => r.SaveAsync(It.IsAny<Order>()), Times.Once);
    repository.Verify(r => r.CommitAsync(), Times.Once);
    repository.VerifyNoOtherCalls();
}
```

## Best Practices

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

## Common Mistakes

- Writing near-duplicate `[Fact]` methods that a single `[Theory]` with `InlineData` would replace.
- Vague test names like `Test1`, `Should_Work`, or `GetUser_Works` that don't state the scenario or expected outcome.
- Interleaving arrange/act/assert without blank-line separation, obscuring what's being verified.
- Using `Assert.Equal`/`Assert.True` for object graphs instead of `Should().BeEquivalentTo()`, losing detailed diff output on failure.
- Mocking the system under test, or mocking simple DTOs/value objects that should just be constructed directly.
- Using loose mocks everywhere, including for collaborators where an unexpected call should fail the test (e.g. a payment gateway during a validation-failure test).
- Sharing `static` fields or a shared fixture's mutable state across tests, creating order dependency and parallel-run flakiness.
- Using `IClassFixture<T>` to share mutable domain objects instead of expensive, read-only resources.
- Calling `.Result` or `.Wait()` on a `Task` inside a test, risking deadlocks and burying the real exception inside an `AggregateException`.
- Verifying every mock call and its exact count (`Times.Once`, `VerifyNoOtherCalls()`) on incidental collaborators — brittle tests that fail on valid refactors.
