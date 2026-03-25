# NestJS Documentation Analysis

> Review technical documentation, API documentation, build instructions, and environment setup (no operational/runbook content).

---

Goal: Review technical documentation, API documentation, build
instructions, and environment setup for single app or monorepo
repositories.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 6 total tool calls for this entire analysis
- Read multiple README/doc files per tool call using parallel reads
- Use batch find commands to locate all documentation files at once
- Reference cached artifacts from previous steps when available

IMPORTANT EXCLUSIONS:
- Do NOT check for operational documentation (runbooks,
  troubleshooting, deployment procedures, monitoring)
- Do NOT recommend CODEOWNERS or SECURITY.md files - these are
  governance decisions
- Focus ONLY on technical setup and API documentation

MONOREPO DETECTION:
- First detect repository structure: single app or monorepo
- If apps/ directory exists, analyze each app individually
- If packages/ or libs/ directory exists, analyze each package/library
  individually

README.MD ANALYSIS:

1. Root README:
   - Check for README.md in root
   - Verify essential sections:
     * Project description and purpose
     * Tech stack (Node.js, NestJS, database, etc.)
     * Prerequisites (Node.js version, npm/yarn/pnpm)
     * Installation instructions
     * Environment setup (.env configuration)
     * Running the application (dev, prod)
     * Running tests
     * Building the application
     * API documentation link
     * Project structure overview
   - Check for code examples (basic usage)
   - Verify links are not broken (if possible)
   
2. Multi-App README (if monorepo):
   - Check for root README explaining monorepo structure
   - Check for per-app README in apps/<app_name>/
   - Verify each app README includes:
     * App-specific description
     * App-specific installation
     * App-specific configuration
     * App-specific API endpoints
   
3. Package/Library README (if applicable):
   - Check for README in each package/library
   - Verify package README includes:
     * Package purpose
     * Installation instructions
     * Usage examples
     * API documentation (exported functions/classes)
     * Dependencies

ENVIRONMENT CONFIGURATION DOCUMENTATION:

1. .env.example:
   - Check for .env.example file
   - Verify it includes all required variables:
     * NODE_ENV
     * PORT
     * Database connection variables
     * JWT_SECRET or SESSION_SECRET
     * API keys placeholders (no actual values)
     * External service configurations
   - Check for comments explaining each variable
   - Verify no actual secrets in .env.example
   
2. Configuration Documentation:
   - Check for docs/configuration.md or similar
   - Verify documentation of environment variables
   - Check for configuration schema documentation
   - Verify default values are documented

API DOCUMENTATION:

1. OpenAPI/Swagger Documentation:
   - Check if Swagger UI is set up (main.ts)
   - Verify Swagger endpoint is documented in README
   - Check for @ApiTags, @ApiOperation usage
   - Verify DTOs have @ApiProperty decorators
   - Check for response examples
   - Verify error responses are documented
   
2. GraphQL Documentation (if applicable):
   - Check for GraphQL playground/sandbox
   - Verify schema is generated
   - Check for type descriptions
   - Verify query/mutation documentation
   
3. API Documentation Files:
   - Check for docs/api/ directory
   - Check for Postman collection
   - Check for OpenAPI spec file (swagger.json/yaml)
   - Check for API versioning documentation

BUILD AND DEPLOYMENT DOCUMENTATION:

1. Build Instructions:
   - Verify README includes build commands
   - Check for build script documentation (package.json)
   - Verify production build instructions
   - Check for optimization documentation
   
2. Docker Documentation:
   - Check for Docker instructions in README
   - Verify docker-compose usage is documented
   - Check for Docker build commands
   - Verify environment variables for Docker
   
3. Installation Steps:
   - Verify step-by-step installation guide
   - Check for dependency installation commands
   - Verify database setup instructions
   - Check for migration commands documentation

PROJECT STRUCTURE DOCUMENTATION:

1. Architecture Documentation:
   - Check for docs/architecture.md or ARCHITECTURE.md
   - Check for module structure explanation
    - Verify layer responsibilities documented
      (controller, service, repository)
   - Check for dependency injection patterns documentation
   
2. Folder Structure:
   - Check for folder structure explanation in README
   - Verify src/ directory structure is documented
   - Check for module organization explanation
   - Verify shared/common modules are documented
   
3. Naming Conventions:
   - Check for naming conventions documentation
   - Verify file naming patterns are explained
   - Check for class/interface naming conventions

CHANGELOG AND VERSIONING:

1. CHANGELOG.md:
   - Check for CHANGELOG.md file
   - Verify it follows Keep a Changelog format
   - Check for version history
   - Verify recent changes are documented
   - (NEUTRAL if missing - not required)
   
2. Version Documentation:
   - Check package.json version
   - Verify semantic versioning usage
   - Check for version tagging strategy

CONTRIBUTING GUIDELINES:

1. CONTRIBUTING.md:
   - Check for CONTRIBUTING.md file
   - Verify it includes:
     * Code style guide reference
     * Branch naming conventions
     * Commit message conventions
     * Pull request process
     * Testing requirements
   - (NEUTRAL if missing - not required)

CODE DOCUMENTATION:

1. Inline Documentation Philosophy:
    - CRITICAL: Documentation should follow
      "document only non-obvious code" principle
   - Good code should be self-documenting through:
     * Clear, descriptive function/method names
     * Well-named variables
     * Obvious logic flow
   - When to document (necessary documentation):
     * Complex algorithms or business rules
     * Non-obvious workarounds or technical decisions
     * Public APIs and library interfaces
     * Configuration and integration points
     * WHY something is done (not WHAT - code shows what)
   - When NOT to document (unnecessary documentation):
     * Self-explanatory code: const userId = user.id // Gets user ID ❌
     * Obvious getters/setters
     * Simple CRUD operations
     * Code that explains itself through naming
   - Anti-patterns to avoid:
     * Commenting every line
     * Redundant comments that repeat the code
     * Outdated comments that don't match current code
     * Comments explaining obvious language features
   - Check for TSDoc/JSDoc on:
     * Public APIs exported from modules
     * Complex business logic methods
     * Non-standard implementations
   - Verify inline comments explain WHY, not WHAT:
     * Good: // Using setTimeout to avoid race condition with DB
       connection
     * Bad: // Call the function to get data
   
2. Generated Documentation:
   - Check for TypeDoc configuration (typedoc.json)
   - Check for Compodoc configuration (if using)
   - Verify documentation generation scripts
   - Check for hosted documentation

TESTING DOCUMENTATION:

1. Test Instructions:
   - Verify README includes test commands
   - Check for test coverage commands
   - Verify E2E test instructions
   - Check for test environment setup
   
2. Test Strategy Documentation:
   - Check for docs/testing.md
   - Verify testing patterns are documented
   - Check for mocking strategy documentation
   - Verify test data management explanation

MULTI-APP MONOREPO DOCUMENTATION:

1. Monorepo Structure:
   - Verify root README explains monorepo layout
   - Check for workspace configuration documentation
   - Verify inter-app dependencies are documented
   - Check for shared libraries documentation
   
2. Per-App Documentation:
   - Check for README in each app
   - Verify app-specific setup
   - Check for app-specific API docs
   - Verify app-specific configuration
   
3. Development Workflow:
   - Check for monorepo workflow documentation
   - Verify build order documentation
   - Check for affected commands documentation (nx, lerna)
   - Verify development scripts are documented

LICENSE:

1. LICENSE File:
   - Check for LICENSE or LICENSE.md file
   - Verify license type is appropriate
   - Check license matches package.json
   - (NEUTRAL for internal projects)

Output format:
- Repository structure type (single app / monorepo)
- README.md completeness score (per app if monorepo)
- Environment configuration documentation status (per app if monorepo)
- API documentation quality (per app if monorepo)
- Build and deployment documentation status (per app if monorepo)
- Project structure documentation status (per app if monorepo)
- CHANGELOG presence and quality (neutral if missing)
- Contributing guidelines presence (neutral if missing)
- Code documentation quality (per app if monorepo)
- Testing documentation status (per app if monorepo)
- Monorepo-specific documentation (if monorepo)
- License information
- Missing documentation items (per app if monorepo)
- Documentation consistency across apps (if monorepo)
- Recommendations for improvement (per app if monorepo)
