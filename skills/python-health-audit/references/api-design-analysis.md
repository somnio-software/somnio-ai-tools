# Python API Design Analysis

> Analyze FastAPI / Django / Flask route design, Pydantic models, OpenAPI schema, status codes, error shape, versioning, and dependency injection. For libraries, analyze the public API surface and __all__ exports.

---

Goal: Analyze API design focusing on clarity, consistency, and
production-ready patterns. This is a 0.20-weight pillar.

IMPORTANT: Apply REASONABLE production standards. The bar is
consistency and correctness, not perfection. A well-structured
FastAPI app without every optional decorator still scores well.

FRAMEWORK DETECTION:

1. Identify framework from pyproject.toml / requirements files:
   - fastapi (+ starlette) → FastAPI
   - django / djangorestframework → Django / DRF
   - flask / quart → Flask / Quart
   - litestar → Litestar
   - aiohttp → aiohttp
   - No web framework → Library / CLI; switch to Library API Surface
     analysis section below

FASTAPI ANALYSIS:

1. Router Structure:
   - Check for APIRouter usage (modular routing)
   - Verify routers are registered on the main app via include_router()
   - Check for prefix and tags on routers (required for OpenAPI grouping)
   - Flag monolithic main.py with all routes inline (risk for large codebases)

2. Path Operation Design:
   - Verify HTTP verb semantics:
     * GET: read-only, idempotent
     * POST: create, returns 201
     * PUT: full replacement
     * PATCH: partial update
     * DELETE: removal, returns 204 or 200
   - Check URL naming: plural nouns (/users, /products), no verb URLs
     (/getUser, /createOrder)
   - Verify path parameters use correct types (int, UUID, not raw str where
     UUID is intended)

3. Request Validation (Pydantic Models):
   - Check for Pydantic BaseModel subclasses as request bodies
   - Verify field validators / field_validator (v2) or validator (v1) usage
     for non-trivial constraints
   - Check for model_config (v2) or class Config (v1) with:
     * str_strip_whitespace = True
     * populate_by_name / allow_population_by_field_name
   - Separate Create vs. Update vs. Response schemas (e.g., UserCreate,
     UserUpdate, UserResponse) — flag if a single schema is reused for all
   - CRITICAL: Verify passwords, secrets, tokens are excluded from
     response models (@field_serializer exclude or Field(exclude=True) /
     response_model_exclude)

4. Response Models:
   - Check response_model on path operations (enables output filtering
     and OpenAPI schema)
   - Verify status_code is explicit on non-200 operations (201, 204, etc.)
   - Check for generic response wrappers (e.g., ResponseEnvelope[T]) if used
     consistently; flag if used inconsistently

5. Dependency Injection (Depends):
   - Check for Depends() usage for auth, DB sessions, pagination params,
     feature flags
   - Verify DB sessions are yielded (generator dependencies with try/finally
     or contextmanager)
   - Flag direct db.SessionLocal() calls inside route functions as risks
     (session lifecycle not guaranteed)
   - Check for reusable common dependencies (get_current_user, get_db, etc.)

6. Exception Handling:
   - Check for HTTPException usage with appropriate status codes and detail
   - Check for global exception handlers
     (app.add_exception_handler / @app.exception_handler)
   - Verify consistent error response shape across all handlers
     (e.g., {"detail": "..."} or custom {"error": ..., "code": ...})
   - Flag mixing HTTPException with unhandled exceptions that return
     500 without a custom handler

7. OpenAPI / Swagger:
   - Verify app metadata: title, version, description in FastAPI() constructor
   - Check for tags_metadata list (tag descriptions)
   - Check for summary and description on path operations
   - Verify Pydantic models have field descriptions (Field(description=...))
   - Check for /docs and /redoc reachability (not disabled in production
     without intention)
   - Flag if openapi_url is set to None in production without alternative
     documentation

8. Versioning:
   - CRITICAL CHECK: API versioning strategy:
     * URL prefix: /api/v1/..., registered via include_router prefix
     * APIVersion header via starlette middleware (alternative)
     * No versioning: flag as risk for production APIs
   - Consistent: same version prefix on all routers
   - Inconsistent: mixed v1/v2 prefixes without deprecation markers

DJANGO / DRF ANALYSIS (if applicable):

1. URL Configuration:
   - Check urls.py for include() to separate app URL files
   - Check for API namespace (app_name) in included url confs
   - Verify URL patterns use path() over re_path() where possible
   - Check api/ or /api/v1/ prefix in root URL conf

2. ViewSet / APIView Design:
   - Check for ViewSet + Router (preferred for CRUD resources)
   - Verify permission_classes on all ViewSets and APIViews
   - Check for serializer_class (not inline dict responses)
   - Verify queryset and get_queryset() use select_related / prefetch_related

3. Serializers:
   - Check for ModelSerializer vs. Serializer; note which is used where
   - Verify read_only_fields for auto fields (id, created_at)
   - Check for validate_<field> and validate() methods
   - Flag serializers that expose sensitive fields (password hash, tokens)

4. OpenAPI (drf-spectacular / drf-yasg):
   - Check if drf-spectacular or drf-yasg is installed
   - Verify @extend_schema or @swagger_auto_schema usage on non-trivial views
   - Check for schema generation in CI (spectacular --validate)

FLASK ANALYSIS (if applicable):

1. Blueprint Structure:
   - Check for Blueprint usage for route grouping
   - Verify blueprints are registered with url_prefix
   - Flag all routes in app.py / main.py as a modularity risk

2. Request Validation:
   - Check for flask-pydantic, marshmallow, or wtforms for input validation
   - Flag direct request.json access without schema validation as a risk

3. Response Consistency:
   - Check for jsonify usage with consistent shape
   - Check for make_response or abort() with appropriate status codes
   - Flag returning plain dict without explicit status code (defaults to 200)

LIBRARY / NON-WEB API SURFACE (if no web framework):

1. Public API Definition:
   - Check __all__ in every public module; flag missing __all__
   - Verify __init__.py re-exports intended public symbols
   - Check for _private vs. public naming consistency

2. Function / Class Signatures:
   - Verify all public functions and methods have type annotations
   - Check for *args / **kwargs in public APIs without documented purpose
   - Flag Any type in public signatures as a risk

3. Deprecation Strategy:
   - Check for warnings.warn(DeprecationWarning) on deprecated symbols
   - Check for @deprecated decorator usage
   - Verify deprecated symbols are documented in CHANGELOG / docstrings

OUTPUT FORMAT:

Provide structured analysis:
- Framework detected: [FastAPI / Django DRF / Flask / Litestar / Library / None]
- Route/endpoint count: [N]
- Pydantic schema count (FastAPI) / Serializer count (DRF): [N]
- API versioning:
  * Strategy: [URL prefix /api/v1/ / Header / None]
  * Consistent: [Yes / No / N/A]
- HTTP verb compliance: [Good / Partial / Poor]
- URL naming conventions: [RESTful / Mixed / Verb-based / N/A]
- Request validation: [Pydantic / DRF Serializers / Schema library / None]
- Response model enforcement: [Yes / Partial / No]
- Dependency injection (FastAPI): [Used / Partial / Not used / N/A]
- OpenAPI/Swagger: [Configured / Basic / Disabled / N/A]
- Exception handling: [Consistent / Partial / None]
- Public API surface (__all__): [Defined / Partial / Missing / N/A]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Versioning present and consistent
- Request bodies validated via Pydantic / serializers
- Response models enforce output schema
- HTTP verbs and URL naming correct
- OpenAPI metadata complete
- DI used for sessions, auth, common deps (FastAPI)
- Consistent error shape

Fair (70-84):
- Global /api/ prefix but no versioning
- Mostly correct verbs and naming
- Validation present but incomplete (some routes unvalidated)
- OpenAPI enabled with minimal metadata
- Some inconsistency in error responses

Weak (0-69):
- No versioning, no /api/ prefix
- Verb-based URLs or incorrect HTTP verbs
- No request validation (direct request.json without schema)
- No response_model or serializer enforcement
- No OpenAPI or docs disabled silently
- Secrets leaked in response models
