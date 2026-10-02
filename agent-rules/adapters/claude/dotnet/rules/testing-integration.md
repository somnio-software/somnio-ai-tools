### ASP.NET Core integration testing — WebApplicationFactory, CustomWebApplicationFactory, Testcontainers over EF Core InMemory, Respawn/transaction-rollback state resets, HttpClient-based assertions, collection fixtures. Applies to all C# integration test files.
> Applies to: `**/*IntegrationTests.cs`
# ASP.NET Core Integration Testing Conventions

How to write integration tests that exercise the real ASP.NET Core pipeline end-to-end: `WebApplicationFactory` for in-memory hosting, `Testcontainers` for a real database instead of the EF Core InMemory provider, disciplined state resets between tests, and assertions made through `HttpClient` rather than internal services.

## Patterns

### WebApplicationFactory for In-Memory Pipeline Tests

`WebApplicationFactory<TEntryPoint>` boots the full ASP.NET Core pipeline in-memory, including routing, middleware, filters, and DI — without binding a real socket. Use it as the base for every integration test class instead of hand-rolling a `TestServer`.

```csharp
public class HealthCheckTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public HealthCheckTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetHealth_ReturnsOkWithHealthyStatus()
    {
        var response = await _client.GetAsync("/health");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var body = await response.Content.ReadFromJsonAsync<HealthResponse>();
        body!.Status.Should().Be("Healthy");
    }
}
```

### CustomWebApplicationFactory: Overriding ConfigureWebHost

Subclass `WebApplicationFactory<TEntryPoint>` and override `ConfigureWebHost` to replace the production `DbContext` registration (and any other real infrastructure, like an outbound email sender) with a test double or a test-scoped connection — without touching `Program.cs`.

```csharp
public class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    public string ConnectionString { get; set; } = string.Empty;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor is not null)
            {
                services.Remove(descriptor);
            }

            services.AddDbContext<AppDbContext>(options =>
                options.UseNpgsql(ConnectionString));

            // Replace outbound infrastructure with a fake — no real emails sent in tests.
            services.RemoveAll<IEmailSender>();
            services.AddSingleton<IEmailSender, FakeEmailSender>();
        });
    }
}
```

### Testcontainers Over the EF Core InMemory Provider

Use `Testcontainers.PostgreSql` (or the equivalent for your engine) to run tests against a real, disposable database instance. The EF Core InMemory provider does not enforce relational constraints (foreign keys, unique indexes, `NOT NULL`), silently allows queries that would fail against a real provider (e.g. certain `GroupBy` or raw SQL translations), and gives false confidence that passes in CI while the production database behaves differently.

```csharp
public class PostgresApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder()
        .WithImage("postgres:16-alpine")
        .WithDatabase("app_test")
        .WithUsername("test")
        .WithPassword("test")
        .Build();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.AddDbContext<AppDbContext>(options =>
                options.UseNpgsql(_container.GetConnectionString()));
        });
    }

    public async Task InitializeAsync()
    {
        await _container.StartAsync();

        using var scope = Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await context.Database.MigrateAsync(); // real migrations run against a real engine
    }

    public new async Task DisposeAsync() => await _container.DisposeAsync();
}
```

### Resetting Database State: Respawn and Transaction Rollback

Reset the database to a known state between tests using either Respawn (deletes all data from all tables, respecting foreign-key order, and re-seeds nothing) or a per-test transaction that is rolled back instead of committed. Never let one test's data bleed into the next.

#### Good — Respawn, reset after every test in the collection

```csharp
[CollectionDefinition("Database collection")]
public class DatabaseCollection : ICollectionFixture<PostgresApiFactory> { }

[Collection("Database collection")]
public class OrderApiTests : IAsyncLifetime
{
    private readonly PostgresApiFactory _factory;
    private readonly HttpClient _client;
    private Respawner _respawner = null!;

    public OrderApiTests(PostgresApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    public async Task InitializeAsync()
    {
        await using var connection = new NpgsqlConnection(_factory.ConnectionString);
        await connection.OpenAsync();
        _respawner = await Respawner.CreateAsync(connection, new RespawnerOptions
        {
            SchemasToInclude = new[] { "public" },
            DbAdapter = DbAdapter.Postgres,
        });
    }

    public async Task DisposeAsync()
    {
        await using var connection = new NpgsqlConnection(_factory.ConnectionString);
        await connection.OpenAsync();
        await _respawner.ResetAsync(connection); // wipes state so the next test starts clean
    }

    [Fact]
    public async Task PostOrder_WithValidPayload_ReturnsCreatedWithLocation()
    {
        var payload = new CreateOrderRequest("SKU-1", Quantity: 2);

        var response = await _client.PostAsJsonAsync("/api/orders", payload);

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        response.Headers.Location.Should().NotBeNull();
    }
}
```

### Testing Through HttpClient, Not Internal Implementation

Drive tests through `factory.CreateClient()` and assert on the HTTP contract — status code, headers, response body shape — rather than reaching into the DI container to call a service or repository directly. Pulling a service out of `factory.Services` bypasses the middleware pipeline, model validation, and serialization you're supposed to be testing.

```csharp
public class ProductsControllerTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public ProductsControllerTests(CustomWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetProduct_WhenIdDoesNotExist_ReturnsNotFound()
    {
        var response = await _client.GetAsync("/api/products/999999");

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task PostProduct_WithMissingName_ReturnsBadRequestWithValidationError()
    {
        var payload = new { Name = "", Price = 10.00m };

        var response = await _client.PostAsJsonAsync("/api/products", payload);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var problem = await response.Content.ReadFromJsonAsync<ValidationProblemDetails>();
        problem!.Errors.Should().ContainKey("Name");
    }
}
```

### Sharing One Testcontainer via Collection Fixtures

Spinning up a fresh Postgres container per test class (or per test) adds seconds of overhead per run. Use `ICollectionFixture<T>` with `[Collection("...")]` to start exactly one container and share it across every test class that needs a database, resetting only the *data* between tests via Respawn or per-test transactions.

```csharp
[CollectionDefinition("Postgres collection")]
public class PostgresCollection : ICollectionFixture<PostgresApiFactory>
{
    // No code needed — this class only ties the fixture to the collection name.
}

[Collection("Postgres collection")]
public class OrdersEndpointTests
{
    private readonly HttpClient _client;

    public OrdersEndpointTests(PostgresApiFactory factory) => _client = factory.CreateClient();

    [Fact]
    public async Task ListOrders_ReturnsEmptyArray_WhenNoOrdersSeeded()
    {
        var response = await _client.GetAsync("/api/orders");

        var orders = await response.Content.ReadFromJsonAsync<List<OrderDto>>();
        orders.Should().BeEmpty();
    }
}

[Collection("Postgres collection")]
public class ProductsEndpointTests
{
    private readonly HttpClient _client;

    public ProductsEndpointTests(PostgresApiFactory factory) => _client = factory.CreateClient();

    // Shares the same running container as OrdersEndpointTests — one startup cost total.
}
```

### Seeding Minimal, Intention-Revealing Test Data

Seed only the rows a specific test needs, inline in the test (or in a small helper it calls explicitly), instead of relying on a large shared global fixture that every test implicitly depends on. Minimal, local seeding makes each test readable on its own and immune to unrelated seed-data changes.

```csharp
[Fact]
public async Task GetOrder_ReturnsOrderWithItsLineItems()
{
    using var scope = _factory.Services.CreateScope();
    var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

    var order = new Order { CustomerName = "Ada Lovelace" };
    order.Items.Add(new LineItem("SKU-1", Quantity: 2, UnitPrice: 10m));
    context.Orders.Add(order);
    await context.SaveChangesAsync();

    var response = await _client.GetAsync($"/api/orders/{order.Id}");

    var dto = await response.Content.ReadFromJsonAsync<OrderDto>();
    dto!.Items.Should().ContainSingle(i => i.Sku == "SKU-1" && i.Quantity == 2);
}
```

## Rules

- Base every integration test class on `WebApplicationFactory<Program>` (or a `CustomWebApplicationFactory` subclass) so the real middleware pipeline, routing, and DI graph are exercised.
- Override `ConfigureWebHost`/`ConfigureServices` in a `CustomWebApplicationFactory` to swap real infrastructure (DB context, outbound email/SMS senders) for test-scoped or fake equivalents.
- Run database integration tests against `Testcontainers.PostgreSql` (or the matching engine), never the EF Core InMemory provider — it doesn't enforce relational constraints and produces false confidence.
- Run real EF Core migrations (`context.Database.MigrateAsync()`) against the container on fixture initialization so schema drift is caught by the same tests.
- Reset database state between tests with Respawn or a rolled-back transaction — never let one test's writes leak into the next.
- Assert exclusively through `factory.CreateClient()` and the HTTP contract (status code, headers, JSON body) — do not resolve services from the DI container to bypass the pipeline.
- Share one Testcontainer per test collection via `ICollectionFixture<T>` and `[Collection("...")]`; only reset data between tests, not the container itself.
- Seed the minimal, intention-revealing data each test needs, inline or via a small per-test helper — avoid large shared global seed fixtures.

- Avoid hand-rolling `TestServer`/`IWebHostBuilder` setup instead of using `WebApplicationFactory<TEntryPoint>`, drifting out of sync with the real `Program.cs`.
- Avoid mutating environment variables or static configuration to point at a test database instead of overriding service registration in `ConfigureWebHost`.
- Avoid using the EF Core InMemory provider for anything beyond the most trivial smoke test — it silently accepts constraint violations and unsupported query shapes that fail against a real engine.
- Avoid skipping database resets between tests, causing order-dependent assertions and increasingly flaky suites as more tests are added.
- Avoid resolving services or repositories directly from `factory.Services` instead of driving the test through `HttpClient`, bypassing model binding, validation, and serialization.
- Avoid spinning up a new Testcontainer per test class instead of sharing one via a collection fixture, inflating suite runtime unnecessarily.
- Avoid depending on a large shared/global seed dataset that every test implicitly relies on, making tests unreadable in isolation and fragile to unrelated seed changes.
- Avoid forgetting to run migrations against the test container, so schema mismatches between test and production go undetected.
