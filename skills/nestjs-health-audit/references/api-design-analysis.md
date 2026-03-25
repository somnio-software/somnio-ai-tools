# NestJS API Design Analysis

> Analyze REST/GraphQL API design, DTOs, validation patterns, OpenAPI/Swagger documentation, and API versioning for NestJS projects.

---

Goal: Analyze API design focusing on clarity, consistency, and
production-ready patterns.

IMPORTANT: Apply REASONABLE production standards. Not every
endpoint needs every decorator. Focus on consistency and clarity.

PROJECT STRUCTURE:
- If monorepo detected (apps/ directory): Note in report and
  focus analysis on main application
- Standard project: Analyze src/ directory

API TYPE DETECTION:

1. Identify API Type:
   - REST API: Controllers with @Get, @Post, @Put, @Delete, @Patch
   - GraphQL API: Resolvers with @Query, @Mutation
   - Hybrid: Both REST and GraphQL
   - Note: Most NestJS apps are REST - this is the focus

REST API ANALYSIS:

1. Controller Design:
   - Find all *.controller.ts files
   - Analyze structure:
     * Route prefixes (@Controller('users'))
     * HTTP method handlers
     * Guard usage (@UseGuards)
     * Interceptor usage (@UseInterceptors)

2. HTTP Verb Usage (CRITICAL):
   - GET: Retrieve data (should NOT modify data)
     * GET /users - list users
     * GET /users/:id - get specific user
   - POST: Create new resources
     * POST /users - create user
     * Should return 201 Created
   - PUT: Full resource replacement
     * PUT /users/:id - replace entire user
   - PATCH: Partial update
     * PATCH /users/:id - update specific fields
   - DELETE: Remove resource
     * DELETE /users/:id - delete user
     * Returns 204 No Content or 200 OK

3. URL Naming Conventions:
   - GOOD: Resource-based, plural nouns
     * /users, /products, /orders
     * /users/:id/orders (nested resources)
   - BAD: Verb-based URLs
     * /getUser, /createProduct, /deleteOrder
   - Query params for filtering: /users?status=active

API VERSIONING (REQUIRED):

CRITICAL CHECK - API versioning should be implemented:

1. URI Versioning (RECOMMENDED):
   - Check for /api/v1/ prefix in routes
   - Check main.ts for global prefix: app.setGlobalPrefix('api/v1')
   - Check controllers for version in path: @Controller('v1/users')

2. Header Versioning (Alternative):
   - Check for @Version() decorator usage
   - Check main.ts for versioning config:
     app.enableVersioning({ type: VersioningType.HEADER })

3. Versioning Assessment:
   - Present and consistent: Good
   - Present but inconsistent: Flag for review
   - Missing entirely: Flag as risk (breaking changes hard to manage)

REASONABLE EXPECTATION: At minimum, a global /api/ prefix should
exist. Full versioning (/api/v1/) is strongly recommended for
production APIs.

DTO ANALYSIS:

1. DTO Organization:
   - Check for dto/ directories in modules
   - DTO types expected:
     * create-*.dto.ts (POST bodies)
     * update-*.dto.ts (PUT/PATCH bodies)
     * query-*.dto.ts (GET query params) - RECOMMENDED
     * *-response.dto.ts (responses) - RECOMMENDED

2. DTO Validation (class-validator):
   - Check for validation decorators:
     * @IsString(), @IsNumber(), @IsBoolean()
     * @IsEmail(), @IsUUID()
     * @IsNotEmpty(), @IsOptional()
     * @Min(), @Max(), @Length()
   - REASONABLE: Not every field needs every decorator
   - REQUIRED: User-facing inputs should be validated

3. DTO Transformation (class-transformer):
   - Check for @Exclude() on sensitive fields (passwords)
   - Check for @Transform() for data formatting
   - REASONABLE: Basic transformation is sufficient

VALIDATION PIPELINE:

1. Global ValidationPipe (REQUIRED):
   - Check main.ts for:
     ```
     app.useGlobalPipes(new ValidationPipe({
       whitelist: true,
       transform: true
     }))
     ```
   - REQUIRED options:
     * whitelist: true (strips unknown properties)
     * transform: true (auto-transforms types)
   - RECOMMENDED options:
     * forbidNonWhitelisted: true (throws on unknown)

OPENAPI/SWAGGER DOCUMENTATION:

1. Swagger Setup (STRONGLY RECOMMENDED):
   - Check for @nestjs/swagger in dependencies
   - Check main.ts for SwaggerModule.setup()
   - Check for DocumentBuilder configuration

2. Documentation Quality:
   - REQUIRED for production:
     * @ApiTags() on controllers (grouping)
     * @ApiOperation() on endpoints (description)
   - RECOMMENDED:
     * @ApiResponse() for responses
     * @ApiProperty() on DTO fields
   - NICE TO HAVE:
     * Examples in documentation
     * @ApiBearerAuth() for auth

3. Assessment:
   - Swagger enabled with basic config: Good
   - Swagger enabled, well-documented: Strong
   - Swagger missing: Flag as risk

HTTP STATUS CODES:

1. Check for explicit status codes:
   - @HttpCode(201) on POST handlers
   - @HttpCode(204) on DELETE handlers (if no body)
   - REASONABLE: Default status codes are acceptable
     for most cases, explicit is better

ERROR HANDLING:

1. Check for consistent error responses:
   - Custom exception filters
   - Standard error format (message, statusCode, error)
   - REASONABLE: NestJS default error format is acceptable

GRAPHQL ANALYSIS (if applicable):

1. If GraphQL detected:
   - Check for resolver files (*.resolver.ts)
   - Verify @Query and @Mutation handlers
   - Check for input types (@InputType)
   - Check for object types (@ObjectType)
   - NOTE: GraphQL is self-documenting, less Swagger needed

OUTPUT FORMAT:

Provide structured analysis:
- API type: [REST / GraphQL / Hybrid]
- Controllers count: [Number]
- DTOs count: [Number]
- API versioning:
  * Strategy: [URI /api/v1/ / Header / None]
  * Consistent: [Yes / No]
- HTTP verb compliance: [Good / Partial / Poor]
- URL naming conventions: [RESTful / Mixed / Verb-based]
- ValidationPipe configured: [Yes with options / Basic / No]
- Swagger/OpenAPI:
  * Enabled: [Yes / No]
  * Documentation quality: [Well-documented / Basic / Missing]
- DTO validation coverage: [Good / Partial / Missing]
- Error handling: [Custom filters / Default / Inconsistent]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- API versioning present (URI or header)
- Proper HTTP verb usage
- RESTful URL naming
- ValidationPipe with whitelist: true
- Swagger enabled and configured
- DTOs with validation decorators
- Consistent error handling

Fair (70-84):
- Global /api/ prefix but no versioning
- Mostly correct HTTP verb usage
- DTOs exist but validation incomplete
- Swagger enabled with minimal config
- Some inconsistencies in naming

Weak (0-69):
- No API prefix or versioning
- Incorrect HTTP verb usage (POST for GET operations)
- Verb-based URLs (/getUser)
- No ValidationPipe or whitelist: false
- No Swagger documentation
- Missing or unvalidated DTOs

IMPORTANT: Be practical. A production API needs:
- Clear versioning strategy (even just /api/ prefix)
- Input validation on user-facing endpoints
- Basic API documentation
- Consistent patterns across endpoints
