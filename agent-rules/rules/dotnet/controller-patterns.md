---
description: Route, verb, and endpoint conventions for ASP.NET Core Web APIs - controllers and minimal APIs - covering versioning, status codes, auth, and thin handlers.
globs: src/**/*Controller.cs, src/**/Endpoints/*.cs, src/**/*.Api/**/*.cs
alwaysApply: false
---

# ASP.NET Core Controller & Endpoint Patterns

How to structure HTTP entry points in an ASP.NET Core 8 Web API - whether using MVC controllers or minimal API endpoint groups - so routing, versioning, status codes, and authorization stay consistent across the codebase.

## Purpose

Consistent controller/endpoint patterns ensure:
- Predictable, resource-oriented URLs that clients can navigate without reading docs
- Correct HTTP semantics (verbs, status codes) instead of ad-hoc `200 OK` for everything
- Business logic stays in services/handlers, not scattered across HTTP entry points
- API versioning and OpenAPI documentation are wired in from day one, not bolted on later
- Authorization is declared once, close to the route, instead of re-checked inside handlers

## Controllers vs Minimal APIs

Both are idiomatic in ASP.NET Core 8. Pick based on the shape of the surface, not personal preference, and be consistent within a project.

- **Prefer controllers** when a resource has many actions, needs model binding conventions (`[FromBody]`, `[FromRoute]`), benefits from `[ApiController]` behaviors, or the team is more comfortable with MVC-style organization.
- **Prefer minimal APIs** for small, focused services, for internal/BFF-style APIs with few endpoints, or when startup performance and a lower-ceremony style matter. Group related endpoints with `MapGroup` instead of one giant `Program.cs`.

Do not mix the two styles for the same resource (e.g., `UsersController` for reads and a parallel minimal `/users` group for writes) - pick one per resource area.

#### Good - Minimal API group per resource

```csharp
public static class OrderEndpoints
{
    public static IEndpointRouteBuilder MapOrderEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/v{version:apiVersion}/orders")
            .WithApiVersionSet(app.NewApiVersionSet().HasApiVersion(new ApiVersion(1)).Build())
            .WithTags("Orders")
            .RequireAuthorization();

        group.MapGet("/{id:guid}", GetById)
            .WithName("GetOrderById")
            .Produces<OrderResponse>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status404NotFound);

        group.MapGet("/", GetAll)
            .Produces<PagedResponse<OrderResponse>>(StatusCodes.Status200OK);

        group.MapPost("/", Create)
            .Produces<OrderResponse>(StatusCodes.Status201Created)
            .ProducesValidationProblem();

        return app;
    }

    private static async Task<Results<Ok<OrderResponse>, NotFound>> GetById(
        Guid id,
        IOrderService orderService,
        CancellationToken cancellationToken)
    {
        var order = await orderService.GetByIdAsync(id, cancellationToken);
        return order is null
            ? TypedResults.NotFound()
            : TypedResults.Ok(order);
    }

    private static async Task<Ok<PagedResponse<OrderResponse>>> GetAll(
        [AsParameters] OrderQuery query,
        IOrderService orderService,
        CancellationToken cancellationToken)
    {
        var result = await orderService.GetAllAsync(query, cancellationToken);
        return TypedResults.Ok(result);
    }

    private static async Task<Results<Created<OrderResponse>, ValidationProblem>> Create(
        CreateOrderRequest request,
        IOrderService orderService,
        CancellationToken cancellationToken)
    {
        var created = await orderService.CreateAsync(request, cancellationToken);
        return TypedResults.Created($"/api/v1/orders/{created.Id}", created);
    }
}
```

#### Bad - Business logic inline in the endpoint, no versioning, no typed results

```csharp
app.MapPost("/orders", async (CreateOrderRequest request, AppDbContext db) =>
{
    // Validation, mapping, and persistence all inline - untestable, unversioned
    if (string.IsNullOrEmpty(request.CustomerId))
        return Results.BadRequest("CustomerId required");

    var order = new Order { CustomerId = request.CustomerId, Total = request.Items.Sum(i => i.Price * i.Qty) };
    db.Orders.Add(order);
    await db.SaveChangesAsync();

    return Results.Ok(order); // Should be 201 Created with a Location header
});
```

## Route Conventions

Use attribute routing with plural, resource-based nouns. Version the route prefix. Nest child resources under their parent when the child cannot exist independently.

#### Good

```csharp
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/[controller]")]
public class CustomersController : ControllerBase
{
    // GET api/v1/customers
    [HttpGet]
    public async Task<ActionResult<PagedResponse<CustomerResponse>>> GetAll(
        [FromQuery] CustomerQuery query,
        CancellationToken cancellationToken) { /* ... */ }

    // GET api/v1/customers/{id}
    [HttpGet("{id:guid}")]
    public async Task<ActionResult<CustomerResponse>> GetById(
        Guid id,
        CancellationToken cancellationToken) { /* ... */ }

    // Nested resource: a customer's addresses cannot exist without the customer
    // GET api/v1/customers/{customerId}/addresses
    [HttpGet("{customerId:guid}/addresses")]
    public async Task<ActionResult<IReadOnlyList<AddressResponse>>> GetAddresses(
        Guid customerId,
        CancellationToken cancellationToken) { /* ... */ }
}
```

#### Bad

```csharp
[Route("api/customer")]           // Singular noun, no version segment
public class CustomerController : ControllerBase
{
    [HttpGet("getAllCustomers")]  // Verb baked into the route ("RPC-style")
    public async Task<IActionResult> GetAllCustomers() { /* ... */ }

    [HttpGet("getAddressesForCustomer/{customerId}")] // Not nested, verb in path
    public async Task<IActionResult> GetAddressesForCustomer(string customerId) { /* ... */ }
}
```

## HTTP Verbs and Status Codes

Map verbs to intent and return the status code that matches what actually happened - not `200 OK` for every response.

| Verb | Intent | Typical success status |
|------|--------|-------------------------|
| `GET` | Read one or many | `200 OK` |
| `POST` | Create | `201 Created` (with `Location` header) |
| `PUT` | Full replace | `200 OK` or `204 No Content` |
| `PATCH` | Partial update | `200 OK` or `204 No Content` |
| `DELETE` | Remove | `204 No Content` |

#### Good - Controllers with `ActionResult<T>`

```csharp
[HttpPost]
public async Task<ActionResult<CustomerResponse>> Create(
    CreateCustomerRequest request,
    CancellationToken cancellationToken)
{
    var created = await _customerService.CreateAsync(request, cancellationToken);
    return CreatedAtAction(nameof(GetById), new { id = created.Id, version = "1.0" }, created);
}

[HttpPut("{id:guid}")]
public async Task<IActionResult> Update(
    Guid id,
    UpdateCustomerRequest request,
    CancellationToken cancellationToken)
{
    await _customerService.UpdateAsync(id, request, cancellationToken);
    return NoContent();
}

[HttpDelete("{id:guid}")]
public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
{
    await _customerService.DeleteAsync(id, cancellationToken);
    return NoContent();
}
```

#### Bad - Everything returns 200, no `Location` header on create

```csharp
[HttpPost]
public async Task<IActionResult> Create(CreateCustomerRequest request)
{
    var created = await _customerService.CreateAsync(request);
    return Ok(created); // Should be 201 Created with Location
}

[HttpDelete("{id}")]
public async Task<IActionResult> Delete(string id)
{
    await _customerService.DeleteAsync(id);
    return Ok(); // Should be 204 No Content
}
```

## API Versioning

Use `Asp.Versioning.Http` (and `Asp.Versioning.Mvc` for controllers) rather than hand-rolled header parsing.

#### Good

```csharp
// Program.cs
builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(1, 0);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ReportApiVersions = true;
    options.ApiVersionReader = new UrlSegmentApiVersionReader();
})
.AddMvc()
.AddApiExplorer(options =>
{
    options.GroupNameFormat = "'v'VVV";
    options.SubstituteApiVersionInUrl = true;
});
```

```csharp
[ApiController]
[ApiVersion("1.0")]
[ApiVersion("2.0")]
[Route("api/v{version:apiVersion}/[controller]")]
public class ProductsController : ControllerBase
{
    [HttpGet("{id:guid}")]
    [MapToApiVersion("1.0")]
    public async Task<ActionResult<ProductResponseV1>> GetByIdV1(Guid id) { /* ... */ }

    [HttpGet("{id:guid}")]
    [MapToApiVersion("2.0")]
    public async Task<ActionResult<ProductResponseV2>> GetByIdV2(Guid id) { /* ... */ }
}
```

#### Bad - Version baked into a custom header parsed by hand, no fallback

```csharp
[HttpGet("{id}")]
public IActionResult GetById(string id)
{
    var version = Request.Headers["X-Api-Version"].FirstOrDefault() ?? "1";
    // Manual branching per version scattered through the method body
    if (version == "2") { /* ... */ }
    return Ok();
}
```

## `[ApiController]` Benefits

Always decorate API controllers with `[ApiController]`. It automatically:
- Returns `400 Bad Request` with a `ValidationProblemDetails` body when `ModelState` is invalid - no manual `if (!ModelState.IsValid)` checks needed
- Infers binding sources (`[FromBody]`, `[FromRoute]`, `[FromQuery]`) from parameter shape
- Requires attribute routing (no convention-based routing fallback, which keeps routes explicit)

#### Good

```csharp
[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
public class InvoicesController : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<InvoiceResponse>> Create(CreateInvoiceRequest request)
    {
        // No manual ModelState check needed - [ApiController] returns 400 automatically
        // if CreateInvoiceRequest fails Data Annotation validation.
        var invoice = await _invoiceService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = invoice.Id }, invoice);
    }
}
```

#### Bad - Missing `[ApiController]`, manual validation boilerplate repeated everywhere

```csharp
[Route("api/invoices")]
public class InvoicesController : Controller // Plain Controller, not ControllerBase + [ApiController]
{
    [HttpPost]
    public async Task<IActionResult> Create(CreateInvoiceRequest request)
    {
        if (!ModelState.IsValid) // Repeated in every action across every controller
        {
            return BadRequest(ModelState);
        }

        var invoice = await _invoiceService.CreateAsync(request);
        return Ok(invoice);
    }
}
```

## Authorization

Declare authorization at the route/controller level, not by checking claims manually inside handlers.

#### Good

```csharp
[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
[Authorize] // Default: any authenticated user
public class AccountsController : ControllerBase
{
    [HttpGet("{id:guid}")]
    [Authorize(Policy = "AccountOwnerOrAdmin")]
    public async Task<ActionResult<AccountResponse>> GetById(Guid id) { /* ... */ }

    [HttpGet("public-summary")]
    [AllowAnonymous]
    public async Task<ActionResult<PublicSummaryResponse>> GetPublicSummary() { /* ... */ }

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(Guid id) { /* ... */ }
}
```

Minimal API equivalent:

```csharp
group.MapGet("/{id:guid}", GetById)
    .RequireAuthorization("AccountOwnerOrAdmin");

group.MapGet("/public-summary", GetPublicSummary)
    .AllowAnonymous();
```

#### Bad - Authorization logic reimplemented inside the handler

```csharp
[HttpDelete("{id}")]
public async Task<IActionResult> Delete(Guid id)
{
    var role = User.FindFirst(ClaimTypes.Role)?.Value;
    if (role != "Admin") // Reimplements what [Authorize(Roles = "Admin")] already does, easy to get wrong
    {
        return Forbid();
    }

    await _accountService.DeleteAsync(id);
    return NoContent();
}
```

## Thin Controllers / Endpoint Handlers

Controllers and endpoint delegates should orchestrate, not implement. Delegate to a service, MediatR handler, or application-layer class. This keeps HTTP concerns (status codes, routing) separate from business rules, and makes the business logic unit-testable without spinning up ASP.NET Core.

#### Good

```csharp
[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
public class ShipmentsController : ControllerBase
{
    private readonly ISender _mediator;

    public ShipmentsController(ISender mediator) => _mediator = mediator;

    [HttpPost("{id:guid}/dispatch")]
    public async Task<ActionResult<ShipmentResponse>> Dispatch(
        Guid id,
        CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new DispatchShipmentCommand(id), cancellationToken);
        return Ok(result);
    }
}
```

#### Bad - Business rules, persistence, and even email sending inline in the controller

```csharp
[HttpPost("{id}/dispatch")]
public async Task<IActionResult> Dispatch(Guid id)
{
    var shipment = await _db.Shipments.FindAsync(id);
    if (shipment is null) return NotFound();

    if (shipment.Status != ShipmentStatus.Ready)
        return BadRequest("Shipment is not ready to dispatch");

    shipment.Status = ShipmentStatus.Dispatched;
    shipment.DispatchedAt = DateTime.UtcNow;
    await _db.SaveChangesAsync();

    await _emailSender.SendAsync(shipment.CustomerEmail, "Your order has shipped"); // Business logic in the controller

    return Ok(shipment);
}
```

## Async All the Way

Every action/handler that does I/O must be `async` and awaited end-to-end. Never block on a `Task` with `.Result` or `.Wait()` - it deadlocks under load and wastes thread pool threads.

#### Good

```csharp
[HttpGet("{id:guid}")]
public async Task<ActionResult<OrderResponse>> GetById(Guid id, CancellationToken cancellationToken)
{
    var order = await _orderService.GetByIdAsync(id, cancellationToken);
    return order is null ? NotFound() : Ok(order);
}
```

#### Bad - Synchronous blocking on async work

```csharp
[HttpGet("{id}")]
public ActionResult<OrderResponse> GetById(Guid id)
{
    var order = _orderService.GetByIdAsync(id).Result; // Blocks a thread pool thread, risks deadlock
    return order is null ? NotFound() : Ok(order);
}
```

## OpenAPI / Swagger Annotations

Document responses explicitly so generated clients and Swagger UI reflect reality, not just the happy path.

#### Good - Controllers

```csharp
[HttpGet("{id:guid}")]
[ProducesResponseType(typeof(OrderResponse), StatusCodes.Status200OK)]
[ProducesResponseType(StatusCodes.Status404NotFound)]
public async Task<ActionResult<OrderResponse>> GetById(Guid id, CancellationToken cancellationToken)
{
    var order = await _orderService.GetByIdAsync(id, cancellationToken);
    return order is null ? NotFound() : Ok(order);
}
```

#### Good - Minimal APIs

```csharp
group.MapGet("/{id:guid}", GetById)
    .WithName("GetOrderById")
    .WithSummary("Gets an order by id")
    .Produces<OrderResponse>(StatusCodes.Status200OK)
    .Produces(StatusCodes.Status404NotFound)
    .WithOpenApi();
```

#### Bad - No response type metadata, generated clients assume every call returns `200`

```csharp
[HttpGet("{id}")]
public async Task<IActionResult> GetById(Guid id)
{
    var order = await _orderService.GetByIdAsync(id);
    return order is null ? NotFound() : Ok(order);
}
```

## Best Practices

- **Choose controllers or minimal APIs per resource area and stay consistent** - do not mix styles for the same resource
- **Version every route** with `api/v{version:apiVersion}/...` and `Asp.Versioning.Http`/`Asp.Versioning.Mvc`
- **Use plural, resource-based nouns** in routes; nest child resources under their parent
- **Map verbs to correct status codes** - `201` + `Location` for create, `204` for delete, never blanket `200`
- **Always decorate API controllers with `[ApiController]`** to get automatic model validation and binding inference
- **Declare authorization declaratively** via `[Authorize]`/`[AllowAnonymous]`/policies, not manual claim checks
- **Keep controllers/endpoint delegates thin** - delegate to services or MediatR handlers
- **Make every I/O-bound action `async`** and never block with `.Result`/`.Wait()`
- **Annotate responses** with `[ProducesResponseType]` / `.Produces<T>()` / `.WithOpenApi()` for accurate OpenAPI docs
- **Use `TypedResults`/`Results<T1, T2>`** in minimal APIs instead of untyped `IResult` so response shapes are compile-time checked

## Common Mistakes

- Mixing controllers and minimal APIs for the same resource
- Un-versioned routes, or versioning via a custom header instead of `Asp.Versioning`
- Verb-in-path routes (`/getAllCustomers`) instead of resource nouns with proper HTTP verbs
- Returning `200 OK` for creates/deletes instead of `201 Created`/`204 No Content`
- Missing `[ApiController]`, leading to hand-rolled `ModelState.IsValid` checks in every action
- Manually re-checking roles/claims inside a handler instead of using `[Authorize]`/policies
- Business logic, persistence, or external calls (email, payment) written directly inside a controller action or endpoint delegate
- Blocking async calls with `.Result` or `.Wait()`
- Missing or inaccurate `[ProducesResponseType]`/`.Produces<T>()` annotations, causing generated clients to assume only the happy path
- Returning EF Core entities directly from an action instead of a response DTO
