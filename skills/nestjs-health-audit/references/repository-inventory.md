# NestJS Repository Inventory

> Detect repository structure, module organization, and feature structure for NestJS projects. Validates layered architecture and service file organization.

---

Goal: Detect repository structure, module organization, and
validate architecture patterns for clean, maintainable code.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 6 total tool calls for this entire analysis
- Use batch find/ls commands to inventory directory structure in one pass
- Read multiple package.json files per tool call using parallel reads
- Do NOT read individual source files to count them — use find + wc

IMPORTANT: Apply REASONABLE production standards. Focus on
clarity and maintainability, not perfection.

REPOSITORY STRUCTURE DETECTION:

1. Project Type Detection:
   - Standard NestJS app: src/ directory with modules
   - Monorepo detected if: apps/ directory OR nx.json OR
     turbo.json OR lerna.json exists
   - If monorepo detected:
     * NOTE in report: "Monorepo structure detected"
     * FOCUS analysis on the main/core application
     * Don't penalize for monorepo structure
     * Suggest analyzing each app separately if needed

2. Standard Project Structure:
   - Check for src/ directory
   - Check for main.ts entry point
   - Check for app.module.ts root module
   - List all modules in src/modules/ or src/

MODULE ORGANIZATION ANALYSIS:

1. Module Detection:
   - Find all *.module.ts files
   - List module names and locations
   - Count total modules
   - Check for feature-based organization (PREFERRED):
     * src/modules/users/
     * src/modules/products/
     * src/modules/orders/

2. Module Structure Verification:
   For each module, check for:
   - module.ts (required)
   - controller.ts (if HTTP endpoints exist)
   - service.ts (business logic)
   - dto/ directory (data transfer objects)
   - entities/ or schemas/ (if using ORM)

3. Shared/Common Modules:
   - Check for src/common/ or src/shared/
   - These should contain:
     * Guards
     * Interceptors
     * Pipes
     * Filters
     * Decorators
     * Utilities

LAYERED ARCHITECTURE VALIDATION:

CRITICAL CHECK - Controller → Service Communication:

1. Controllers MUST Only Inject Services:
   - Scan controller files for constructor injections
   - VALID: constructor(private userService: UserService)
   - INVALID: constructor(private userRepository: UserRepository)
   - INVALID: constructor(private prisma: PrismaService) in controller
   - Controllers should be THIN - only handle HTTP concerns:
     * Parse request data
     * Call service methods
     * Return responses
   - Flag any controller that injects repositories or ORM directly

2. Services Handle Business Logic:
   - Services can inject:
     * Other services (for composition)
     * Repositories (for data access)
     * ConfigService (for configuration)
     * External clients (HttpService, etc.)
   - Services should NOT:
     * Access Request/Response objects directly
     * Return HTTP-specific responses (use exceptions instead)

3. Repositories Handle Data Access Only:
   - If repository pattern is used:
     * Repositories should only contain queries
     * No business logic in repositories
     * No HTTP-related code

SERVICE FILE LENGTH ANALYSIS:

CRITICAL CHECK - Service File Size:

For each *.service.ts file, check line count:

1. Healthy (< 300 lines):
   - Single responsibility maintained
   - No action needed

2. Growing (300-500 lines):
   - Acceptable for complex domains
   - Note for future refactoring consideration

3. Large (500-800 lines):
   - FLAG for review
   - Likely handling multiple responsibilities
   - Recommend identifying logical splits

4. Oversized (> 800 lines):
   - CRITICAL FLAG
   - Recommend immediate refactoring
   - Split by:
     * Operation type (CRUD operations vs complex workflows)
     * Sub-domain (UserAuthService, UserProfileService)
     * Read vs Write operations (UserQueryService, UserCommandService)

Example splits for a large UserService:
- UserService (orchestration, < 200 lines)
- UserAuthService (login, register, password reset)
- UserProfileService (profile CRUD)
- UserNotificationService (email, push notifications)

DTO ORGANIZATION:

1. DTO Directory Structure:
   - Check for dto/ directory in each module
   - DTOs should be organized:
     * create-*.dto.ts (POST request bodies)
     * update-*.dto.ts (PUT/PATCH request bodies)
     * query-*.dto.ts (GET query parameters)
     * *-response.dto.ts (response shapes) - RECOMMENDED

2. DTO Naming Conventions:
   - CreateUserDto, UpdateUserDto, UserQueryDto
   - UserResponseDto or GetUserResponseDto
   - REASONABLE: Response DTOs are recommended but not required
     if using serialization with @Exclude decorators

CONFIGURATION STRUCTURE:

1. Config Module:
   - Check for src/config/ directory
   - Check for configuration files:
     * app.config.ts
     * database.config.ts
     * auth.config.ts (if applicable)
   - REASONABLE: Configuration can be in AppModule directly
     for smaller applications

2. Environment Setup:
   - Check for .env.example
   - Verify configuration uses ConfigService

ARCHITECTURAL PATTERNS DETECTION:

1. Feature-Based Organization (PREFERRED):
   - Each feature in its own module directory
   - Self-contained: controller, service, DTOs, entities
   - Easy to understand and maintain

2. Additional Patterns (OPTIONAL - don't require):
   - CQRS: commands/, queries/, handlers/
   - DDD: domain/, application/, infrastructure/
   - Event-driven: events/, listeners/
   - NOTE: These are advanced patterns, don't penalize absence

OUTPUT FORMAT:

Provide structured analysis:
- Project type: [Standard NestJS / Monorepo (type)]
- If monorepo: Note detected and recommend separate analysis
- Total modules count: [Number]
- Module list with locations
- Module organization: [Feature-based / Layer-based / Mixed]
- Layered architecture compliance:
  * Controllers inject services only: [Yes / No - list violations]
  * Services handle business logic: [Yes / Partial / No]
- Service file size analysis:
  * Files < 300 lines: [Count]
  * Files 300-500 lines: [Count] (acceptable)
  * Files 500-800 lines: [Count] (flag for review)
  * Files > 800 lines: [Count] (critical - list files)
- DTO organization: [Good / Partial / Missing]
- Common/shared modules: [Present / Missing]
- Configuration structure: [Good / Basic / Missing]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Clear module organization (feature-based preferred)
- Controllers only inject services (no repository injection)
- Service files reasonably sized (most < 500 lines)
- DTOs organized in dto/ directories
- Common/shared modules present

Fair (70-84):
- Modules exist but organization could improve
- Minor layering violations (1-2 controllers with direct repo)
- Some large service files (500-800 lines)
- DTOs present but organization inconsistent

Weak (0-69):
- No clear module structure
- Controllers frequently bypass services
- Multiple oversized service files (> 800 lines)
- Missing or disorganized DTOs
- Business logic scattered across layers

IMPORTANT: Be practical in assessment. A well-organized codebase
doesn't need every advanced pattern. Focus on:
- Can a new developer navigate the codebase easily?
- Is the separation of concerns clear?
- Are files reasonably sized for maintenance?
