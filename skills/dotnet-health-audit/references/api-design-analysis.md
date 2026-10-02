# .NET Health Audit API Design Analysis

> Analyze ASP.NET Core Web API design, DTOs, validation patterns, OpenAPI/Swagger documentation, and API versioning for .NET projects.

---

Goal: Analyze API design focusing on clarity, consistency, and
production-ready patterns.

IMPORTANT: Apply REASONABLE production standards. Not every
endpoint needs every attribute. Focus on consistency and clarity.

PROJECT STRUCTURE:
- If a Clean Architecture solution is detected (separate Api/
  Application/Domain/Infrastructure projects): Note in report and
  focus this analysis on the Api (Web API) project's Controllers/
  Endpoints and the DTOs/Contracts referenced by them
- Standard single-project repo: Analyze the whole project

API STYLE DETECTION:

1. Identify API Style:
   - Controllers: classes inheriting `ControllerBase`, typically
     annotated `[ApiController]`, with `[Route("api/[controller]")]`
   - Minimal APIs: `app.MapGet/MapPost/MapPut/MapPatch/MapDelete` and
     `app.MapGroup(...)` calls in `Program.cs` or extension methods
   - Hybrid: both styles present
   - Note: both styles are valid and fully supported in .NET 8; flag
     Hybrid only if the mix looks unmotivated (see below)

REST API ANALYSIS:

1. Controller Design:
   - Find all `*Controller.cs` files
   - Analyze structure:
     * Route templates (`[Route("api/[controller]")]`, `[Route("api/v{version:apiVersion}/orders")]`)
     * `[ApiController]` presence (enables automatic model validation,
       binding source inference, 400 on invalid model state)
     * Action filter usage (`[Authorize]`, custom `IActionFilter`/
       `IAsyncActionFilter`)
     * Base class: `ControllerBase` (API-only, no view support) is
       preferred over `Controller` for Web APIs

2. Minimal API Design (if used):
   - Endpoint grouping via `MapGroup("/api/orders")` with shared
     `.WithTags()`, `.RequireAuthorization()`, filters applied to the
     group rather than repeated per endpoint
   - Route handlers kept thin — delegating to injected services rather
     than embedding business logic directly in the lambda
   - Endpoint filters (`IEndpointFilter`) used for cross-cutting
     concerns (validation, logging) instead of duplicated inline checks

3. HTTP Verb Usage (CRITICAL):
   - GET: Retrieve data (should NOT modify data)
     * `[HttpGet]` / `MapGet("/orders")` - list orders
     * `[HttpGet("{id}")]` / `MapGet("/orders/{id}")` - get specific order
   - POST: Create new resources
     * `[HttpPost]` / `MapPost("/orders")` - create order
     * Should return 201 Created via `CreatedAtAction(...)` or
       `TypedResults.Created(...)`
   - PUT: Full resource replacement
     * `[HttpPut("{id}")]` / `MapPut("/orders/{id}")` - replace entire order
   - PATCH: Partial update
     * `[HttpPatch("{id}")]` / `MapPatch("/orders/{id}")` - update specific fields
   - DELETE: Remove resource
     * `[HttpDelete("{id}")]` / `MapDelete("/orders/{id}")` - delete order
     * Returns 204 No Content via `NoContent()` / `TypedResults.NoContent()`

4. URL Naming Conventions:
   - GOOD: Resource-based, plural nouns
     * `/api/orders`, `/api/products`
     * `/api/orders/{id}/items` (nested resources)
   - BAD: Verb-based URLs
     * `/api/getOrder`, `/api/createProduct`, `/api/deleteOrder`
   - Query params for filtering: `/api/orders?status=active`

API VERSIONING (REQUIRED):

CRITICAL CHECK - API versioning should be implemented:

1. URL Segment Versioning (RECOMMENDED):
   - Check for `Asp.Versioning.Mvc` (Controllers) or
     `Asp.Versioning.Http` (Minimal APIs) package references
   - Check for `[ApiVersion("1.0")]` attributes on controllers
   - Check route templates for `api/v{version:apiVersion}/orders`
   - Check `Program.cs` for `AddApiVersioning()` / `.AddVersionedApiExplorer()`

2. Header/Query String Versioning (Alternative):
   - Check for `ApiVersionReader` configuration
     (`HeaderApiVersionReader`, `QueryStringApiVersionReader`,
     `MediaTypeApiVersionReader`)

3. Versioning Assessment:
   - Present and consistent: Good
   - Present but inconsistent (some controllers versioned, others not): Flag for review
   - Missing entirely: Flag as risk (breaking changes hard to manage)

REASONABLE EXPECTATION: At minimum, a global `/api/` prefix should
exist. Full versioning (`Asp.Versioning.*` with `/api/v1/`) is strongly
recommended for production APIs with external or long-lived consumers.

REQUEST/RESPONSE DTO ANALYSIS:

1. DTO Organization:
   - Check for `Dtos/` or `Contracts/` directories (feature-based or
     centralized, either is acceptable)
   - DTO types expected:
     * `Create*Request`/`Create*Dto` (POST bodies)
     * `Update*Request`/`Update*Dto` (PUT/PATCH bodies)
     * `*Response`/`*Dto` (response shapes) - RECOMMENDED, distinct
       from the response DTO returned to callers rather than exposing
       EF Core entities directly
   - CRITICAL: Flag entities (EF Core-tracked classes) returned
     directly from controllers/endpoints — this leaks persistence
     concerns (navigation properties, tracking state) into the API
     contract and risks over-posting on input

2. DTO Validation:
   - Data Annotations: `[Required]`, `[StringLength]`, `[Range]`,
     `[EmailAddress]`, `[RegularExpression]` on DTO properties
   - FluentValidation: `AbstractValidator<T>` classes registered via
     `AddFluentValidationAutoValidation()` / manually invoked
   - REASONABLE: Not every field needs every attribute
   - REQUIRED: User-facing inputs (Create/Update DTOs) should be
     validated by one mechanism or the other, consistently

3. `[ApiController]` Automatic Validation:
   - `[ApiController]` automatically returns 400 with `ValidationProblemDetails`
     when model state is invalid — verify this isn't disabled via
     `ApiBehaviorOptions.SuppressModelStateInvalidFilter = true`
     without a replacement validation mechanism in place
   - Minimal APIs do NOT get this automatically — verify validation is
     invoked explicitly (endpoint filter, FluentValidation call, or
     manual `TryValidateObject`)

OPENAPI/SWAGGER DOCUMENTATION:

1. Swagger/OpenAPI Setup (STRONGLY RECOMMENDED):
   - Check for `Swashbuckle.AspNetCore` package reference and
     `AddSwaggerGen()` / `UseSwagger()` / `UseSwaggerUI()` in `Program.cs`
   - Or `Microsoft.AspNetCore.OpenApi` (built-in .NET 8/9 OpenAPI
     document generation) with `AddOpenApi()` / `MapOpenApi()`
   - Or `NSwag.AspNetCore` as an alternative

2. Documentation Quality:
   - REQUIRED for production:
     * Endpoint grouping/tags (`[ApiExplorerSettings]`, `.WithTags()`)
     * `[ProducesResponseType(StatusCodes.Status200OK)]` /
       `.Produces<T>(200)` describing success responses
   - RECOMMENDED:
     * `[ProducesResponseType]` for error status codes (400, 404, 409)
     * XML doc comments surfaced via `IncludeXmlComments(...)` in
       `AddSwaggerGen()`, requiring `<GenerateDocumentationFile>true</GenerateDocumentationFile>`
       in the `.csproj`
   - NICE TO HAVE:
     * Example request/response bodies (`.WithSummary()`, `.WithDescription()`)
     * `AddSecurityDefinition`/`[Authorize]` reflected in Swagger UI (auth lock icon)

3. Assessment:
   - Swagger/OpenAPI enabled with basic config: Good
   - Swagger/OpenAPI enabled, well-documented (tags, response types, XML comments): Strong
   - Swagger/OpenAPI missing: Flag as risk

HTTP STATUS CODES:

1. Check for explicit status codes:
   - `[ProducesResponseType(StatusCodes.Status201Created)]` on POST
     handlers, paired with `CreatedAtAction(...)`/`TypedResults.Created(...)`
   - `[ProducesResponseType(StatusCodes.Status204NoContent)]` on DELETE
     handlers (no body), paired with `NoContent()`/`TypedResults.NoContent()`
   - `[ProducesResponseType(StatusCodes.Status404NotFound)]` where a
     lookup by id can fail
   - REASONABLE: Default status codes are acceptable for most cases;
     explicit `[ProducesResponseType]` annotations are better for
     Swagger accuracy but not required on every single action

ERROR HANDLING:

1. Check for consistent error responses:
   - `ProblemDetails` (RFC 7807) returned via `AddProblemDetails()`,
     exception handling middleware, or `IExceptionHandler` (.NET 8)
   - Custom exception-handling middleware producing a consistent shape
   - REASONABLE: The ASP.NET Core default `ProblemDetails` format is
     acceptable; cross-reference actual consistency with the error
     handling analysis if available

OUTPUT FORMAT:

Provide structured analysis:
- API style: [Controllers / Minimal APIs / Hybrid]
- Controllers or endpoint groups count: [Number]
- DTOs/Contracts count: [Number]
- API versioning:
  * Strategy: [URL segment (Asp.Versioning) / Header / Query string / None]
  * Consistent: [Yes / No]
- HTTP verb compliance: [Good / Partial / Poor]
- URL naming conventions: [RESTful / Mixed / Verb-based]
- Entities leaking through API responses: [Yes / No]
- DTO validation coverage: [Good / Partial / Missing]
- Swagger/OpenAPI:
  * Enabled: [Yes / No]
  * Package/mechanism: [Swashbuckle.AspNetCore / Microsoft.AspNetCore.OpenApi / NSwag]
  * Documentation quality: [Well-documented / Basic / Missing]
- HTTP status code annotations: [Explicit / Default only / Inconsistent]
- Error handling consistency: [Consistent ProblemDetails / Default / Inconsistent]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- API versioning present (URL segment or header) and consistent
- Proper HTTP verb usage across Controllers/Minimal APIs
- RESTful, resource-based URL naming
- DTOs used consistently for both requests and responses; no entities
  leaked to callers
- DTO validation present (Data Annotations or FluentValidation) on all
  user-facing inputs
- Swagger/OpenAPI enabled and well-documented (tags, response types)
- Consistent error handling via `ProblemDetails`

Fair (70-84):
- Global `/api/` prefix but no formal versioning strategy
- Mostly correct HTTP verb usage
- DTOs exist but validation incomplete on some endpoints
- Swagger/OpenAPI enabled with minimal configuration
- Some inconsistencies in naming or in Controllers-vs-Minimal-API usage

Weak (0-69):
- No API prefix or versioning
- Incorrect HTTP verb usage (e.g., POST for read operations)
- Verb-based URLs (`/api/getOrder`)
- EF Core entities returned directly from endpoints
- No DTO validation, or `[ApiController]`'s automatic validation
  disabled with nothing replacing it
- No Swagger/OpenAPI documentation

IMPORTANT: Be practical. A production ASP.NET Core Web API needs:
- Clear versioning strategy (even just an `/api/` prefix at minimum)
- Input validation on user-facing endpoints
- DTOs separating the wire contract from persistence entities
- Basic API documentation (Swagger/OpenAPI)
- Consistent patterns across endpoints, whether Controllers, Minimal
  APIs, or a deliberate mix of the two
