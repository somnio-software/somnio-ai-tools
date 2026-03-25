# NestJS Configuration Analysis

> Read and analyze NestJS/Node.js configuration files for version info, dependencies, TypeScript setup, and environment configuration (single app or monorepo).

---

Goal: Read and analyze NestJS/Node.js configuration files for single
app or monorepo repositories.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire analysis
- Read multiple config files per tool call using parallel reads (3-5 files per response)
- Use batch grep commands instead of reading files one by one
- Pipe dependency list outputs through `| head -50` (e.g., npm outdated, npm audit)
- Reference cached artifacts from previous steps when available

MONOREPO DETECTION:
- First detect repository structure: single app or monorepo
  (nx, turborepo, lerna, apps/ structure)
- If apps/ directory exists, analyze each app individually
- If packages/ or libs/ directory exists, analyze each package/library
  individually

SINGLE APP ANALYSIS:
- Read completely and analyze:
  * package.json (Node.js version, NestJS version, dependencies,
    dev_dependencies, scripts)
  * tsconfig.json (TypeScript configuration, compiler options,
    strict mode)
  * tsconfig.build.json (Build-specific TypeScript configuration)
  * nest-cli.json (NestJS CLI configuration, monorepo settings)
  * .nvmrc or .node-version (Node.js version management)
  * .env.example (Environment variable template)
  * src/config/ files (Configuration modules and services)

CRITICAL DEPENDENCY ANALYSIS:
- NestJS core packages:
  * @nestjs/core - Core framework
  * @nestjs/common - Common utilities
  * @nestjs/platform-express or @nestjs/platform-fastify - HTTP platform
- Database packages:
  * @nestjs/typeorm, typeorm - TypeORM integration
  * @nestjs/mongoose, mongoose - Mongoose integration
  * @nestjs/sequelize, sequelize - Sequelize integration
  * @prisma/client, prisma - Prisma integration
- Validation and transformation:
  * class-validator - DTO validation
  * class-transformer - Object transformation
- Configuration management:
  * @nestjs/config - Configuration module
  * dotenv - Environment variables
  * joi or @hapi/joi - Environment variable validation (CRITICAL)
  * class-validator with @nestjs/config - Alternative validation approach
- API documentation:
  * @nestjs/swagger - OpenAPI/Swagger integration
- Testing:
  * @nestjs/testing - Testing utilities
  * jest - Test framework
  * supertest - HTTP testing

TYPESCRIPT CONFIGURATION ANALYSIS:
- Compiler options:
  * strict mode enabled (strict: true)
  * strictNullChecks enabled
  * strictFunctionTypes enabled
  * noImplicitAny enabled
  * esModuleInterop enabled
  * emitDecoratorMetadata enabled (required for NestJS)
  * experimentalDecorators enabled (required for NestJS)
  * target (ES2021 or higher recommended)
  * module (commonjs for Node.js)
  * moduleResolution (node)
  * skipLibCheck (performance optimization)
  * forceConsistentCasingInFileNames (cross-platform compatibility)

NEST CLI CONFIGURATION ANALYSIS:
- Monorepo configuration (if applicable)
- Source root configuration
- Compiler options (webpack, tsc)
- Asset handling
- Watch mode configuration
- Generate options

MULTI-APP MONOREPO ANALYSIS:
- For each app in apps/ directory:
  * Read apps/<app_name>/package.json
  * Read apps/<app_name>/tsconfig.json
  * Read apps/<app_name>/nest-cli.json
  * Check for app-specific .nvmrc or .node-version
  * Check for app-specific .env.example
  * Analyze app-specific configuration modules
- Root-level configuration:
  * Read root package.json (workspace configuration)
  * Read root tsconfig.json (base configuration)
  * Read root nest-cli.json (monorepo settings)
  * Check for root .nvmrc or .node-version
  * Workspace configuration: nx.json, turbo.json, lerna.json,
    pnpm-workspace.yaml
- Compare configurations across apps:
  * Node.js/NestJS version consistency
  * Dependency version alignment
  * TypeScript configuration consistency
  * Environment variable patterns

PACKAGE/LIBRARY ANALYSIS (if libs/ or packages/ exists):
- For each package/library:
  * Read packages/<package_name>/package.json
  * Read packages/<package_name>/tsconfig.json
  * Check for buildable vs non-buildable libraries (nx-specific)
  * Analyze exports and public API

SCRIPT ANALYSIS:
- Build scripts: build, build:prod
- Development scripts: start, start:dev, start:debug
- Test scripts: test, test:watch, test:cov, test:e2e
- Linting scripts: lint, format
- Database scripts: migration:run, migration:revert, seed
- Documentation scripts: docs, docs:serve

ENVIRONMENT CONFIGURATION ANALYSIS:
- Check for .env files (should NOT be in repo)
- Verify .env.example exists with all required variables
- Analyze environment variable usage in src/config/
- Check for environment-specific configs: .env.development,
  .env.production
- Verify .env is in .gitignore
- CRITICAL: Check for environment variable validation:
  * ConfigModule with validationSchema (Joi)
  * ConfigModule with validate function (custom validation)
  * Check for typed configuration classes/interfaces
  * Verify type safety when accessing config (no direct process.env usage)
  * Example: ConfigModule.forRoot({ validationSchema: Joi.object({...}) })
- Verify ConfigService usage pattern:
  * Services should inject ConfigService for type-safe access
  * Avoid direct process.env access throughout codebase
  * Check for config namespaces/nested configs

Output format:
- Repository structure type (single app / monorepo with type)
- Extract exact Node.js and NestJS versions (per app if monorepo)
- List all critical dependencies and versions (per app if monorepo)
- TypeScript configuration analysis (per app if monorepo)
- Nest CLI configuration (per app if monorepo)
- Script availability and completeness (per app if monorepo)
- Environment configuration status (per app if monorepo)
- Identify any missing configuration files (per app if monorepo)
- Version consistency across apps/packages (if monorepo)
- Configuration inheritance patterns (if monorepo)
- Recommendations for configuration improvements
