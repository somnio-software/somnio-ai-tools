# NestJS Code Quality Analysis

> Analyze ESLint configuration, Prettier setup, TypeScript strict mode, and code quality enforcement for NestJS projects.

---

Goal: Analyze ESLint configuration, Prettier setup, TypeScript strict
mode, and code quality enforcement for single app or monorepo
repositories.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire analysis
- Read 3-5 files per tool call using parallel reads
- Use batch grep commands to find lint suppressions across all files at once
- Group file reads by directory
- Pipe large outputs through `| head -50`

MONOREPO DETECTION:
- First detect repository structure: single app or monorepo
- If apps/ directory exists, analyze each app individually
- If packages/ or libs/ directory exists, analyze each package/library
  individually

ESLINT CONFIGURATION ANALYSIS:

1. ESLint Setup:
   - Check for .eslintrc.js, .eslintrc.json, or .eslintrc.yml
   - Verify @typescript-eslint/parser is configured
   - Check for extends configurations:
     * plugin:@typescript-eslint/recommended
     * plugin:@typescript-eslint/recommended-requiring-type-checking
     * plugin:prettier/recommended
   - Verify parserOptions:
     * project: './tsconfig.json' (for type-aware rules)
     * sourceType: 'module'
     * ecmaVersion: 2021 or higher
   
2. ESLint Rules Analysis:
   - TypeScript-specific rules:
     * @typescript-eslint/explicit-function-return-type
     * @typescript-eslint/explicit-module-boundary-types
     * @typescript-eslint/no-explicit-any
     * @typescript-eslint/no-unused-vars
     * @typescript-eslint/no-floating-promises
     * @typescript-eslint/await-thenable
    - NestJS-specific rules
      (if using @darraghor/eslint-plugin-nestjs-typed):
     * @darraghor/nestjs-typed/injectable-should-be-provided
     * @darraghor/nestjs-typed/controllers-should-supply-api-tags
     * @darraghor/nestjs-typed/use-validation-pipe
   - General code quality rules:
     * no-console (warn for production)
     * no-debugger (error)
     * no-unused-vars (error)
     * prefer-const (error)
     * no-var (error)
   
3. ESLint Ignore Patterns:
   - Check .eslintignore file
   - Verify ignore patterns:
     * node_modules (should be ignored)
     * dist (build output)
     * coverage (test coverage)
     * .eslintrc.js (configuration file)
   - Analyze if ignores are justified
   - Flag any source code being ignored

PRETTIER CONFIGURATION ANALYSIS:

1. Prettier Setup:
   - Check for .prettierrc, .prettierrc.json, or .prettierrc.js
   - Verify prettier is in devDependencies
   - Check for eslint-config-prettier (prevents conflicts)
   - Check for eslint-plugin-prettier
   
2. Prettier Rules:
   - Analyze formatting configuration:
     * printWidth (80 or 100 recommended)
     * tabWidth (2 or 4)
     * useTabs (false recommended)
     * semi (true for TypeScript)
     * singleQuote (true or false, be consistent)
     * trailingComma (all or es5)
     * bracketSpacing (true recommended)
     * arrowParens (always recommended)
   - Verify consistent configuration across monorepo
   
3. Prettier Ignore Patterns:
   - Check .prettierignore file
   - Verify ignore patterns match .eslintignore
   - Check for build artifacts exclusion

TYPESCRIPT STRICT MODE ANALYSIS:

1. Compiler Options (tsconfig.json):
   - CRITICAL: Check strict mode configuration:
     * "strict": true (enables all strict checks)
     * Or individual strict flags:
       - "noImplicitAny": true
       - "strictNullChecks": true
       - "strictFunctionTypes": true
       - "strictBindCallApply": true
       - "strictPropertyInitialization": true
       - "noImplicitThis": true
       - "alwaysStrict": true
   
2. Additional Type Checking:
   - "noUnusedLocals": true
   - "noUnusedParameters": true
   - "noImplicitReturns": true
   - "noFallthroughCasesInSwitch": true
   - "noUncheckedIndexedAccess": true (recommended)
   - "noPropertyAccessFromIndexSignature": true (recommended)
   
3. NestJS-Required Options:
   - "emitDecoratorMetadata": true (REQUIRED for NestJS)
   - "experimentalDecorators": true (REQUIRED for NestJS)
   - "esModuleInterop": true (recommended)
   - "skipLibCheck": true (performance)
   - "forceConsistentCasingInFileNames": true

CODE QUALITY SCRIPTS ANALYSIS:

1. Linting Scripts (package.json):
   - Check for "lint" script
   - Check for "lint:fix" script
   - Verify lint script includes all relevant paths
   - Check for lint in pre-commit hooks
   
2. Formatting Scripts:
   - Check for "format" script
   - Check for "format:check" script
   - Verify format script includes all relevant paths
   
3. Type Checking Scripts:
   - Check for "type-check" or "tsc" script
   - Verify --noEmit flag (for type checking only)
   
4. Build Scripts:
   - Check for "build" script
   - Verify build process includes type checking
   - Check for "prebuild" or "postbuild" hooks

AUTOMATED CODE QUALITY ENFORCEMENT:

1. Husky Configuration:
   - Check for .husky/ directory
   - Verify pre-commit hook exists
   - Check for commit-msg hook (conventional commits)
   
2. Lint-Staged Configuration:
   - Check for lint-staged in package.json or .lintstagedrc
   - Verify configuration:
     * ESLint runs on *.ts files
     * Prettier runs on *.ts files
     * Tests run on changed files (optional)
   
3. Commitlint Configuration:
   - Check for @commitlint/config-conventional
   - Verify commitlint.config.js
   - Check for conventional commit enforcement

SONARQUBE/CODE ANALYSIS INTEGRATION:

1. Static Analysis Tools:
   - Check for sonar-project.properties
   - Check for .codeclimate.yml
   - Check for CodeQL configuration
   
2. Code Smells Detection:
   - Look for TODO/FIXME comments (acceptable but track count)
   - Check for console.log statements (should be removed)
   - Check for debugger statements (should be removed)
   - Check for any eslint-disable comments (analyze if justified)

DEPENDENCY ANALYSIS:

1. Outdated Dependencies:
   - Run npm outdated or yarn outdated
   - IMPORTANT: Pipe output through `| head -50` to avoid flooding
     context with large dependency lists
   - Check for major version upgrades available
   - Identify deprecated packages
   
2. Security Vulnerabilities:
   - Check for npm audit or yarn audit results
   - IMPORTANT: Pipe audit output through `| head -50` to avoid
     flooding context. Focus on high/critical vulnerabilities only.
   - Identify high/critical vulnerabilities
   - Check for dependency security tools (Snyk, Dependabot)
   
3. Duplicate Dependencies:
   - Check for duplicate packages with different versions
   - Analyze bundle size impact

MULTI-APP MONOREPO CODE QUALITY:
- Root-level configuration:
  * Check for root .eslintrc.js
  * Check for root .prettierrc
  * Check for root tsconfig.json (base config)
  * Verify shared code quality standards
- Per-app analysis:
  * For each app in apps/ directory:
    - Check for app-specific .eslintrc.js (extends root)
    - Check for app-specific tsconfig.json (extends root)
    - Verify consistent code quality standards
- Package/library analysis:
  * For each package in packages/ or libs/:
    - Verify buildable packages have proper linting
    - Check for stricter rules on published packages
    - Verify no console.log in library code

BEST PRACTICES VALIDATION:

1. Code Organization:
   - Verify single responsibility principle
   - Check for proper module separation
   - Verify dependency injection patterns
   - CRITICAL: Check for circular dependencies:
     * Analyze import statements between modules
     * Check for circular module imports
     * Check for circular service dependencies
     * Verify proper use of forwardRef() where needed
     * Flag circular dependencies as CRITICAL issues
   - Method/function size and complexity:
     * Flag functions/methods > 50 lines (should be split)
     * Check for functions with multiple responsibilities
     * Verify large operations are split into smaller step methods
      * Example: createUser() calls validateUserData(), hashPassword(),
        saveUser()
   - Service file organization:
     * If service file > 300 lines, recommend splitting by functionality
     * Each service method should have single responsibility
      * Large operations should be split into multiple private helper
        methods
   
2. Naming Conventions:
   - File naming:
     * Controllers: *.controller.ts
     * Services: *.service.ts
     * Modules: *.module.ts
     * Guards: *.guard.ts
     * Interceptors: *.interceptor.ts
     * Pipes: *.pipe.ts
     * DTOs: *.dto.ts
     * Entities: *.entity.ts
     * Repositories: *.repository.ts
   - CRITICAL: Method/function naming:
     * Use clear, descriptive names (no abbreviations)
     * Verb-based names: createUser, findUserById, updateUserProfile
     * Boolean methods: isValid, hasPermission, canAccess
     * Avoid generic names: process, handle, doWork
      * Service methods should indicate intent: calculateTotalPrice,
        validateUserCredentials
   - Variable naming:
     * Use camelCase for variables
     * Use PascalCase for classes
     * Use UPPER_SNAKE_CASE for constants
     * Descriptive names over short names: userData vs ud
   
3. Error Handling:
   - Check for proper exception filters
   - Verify custom exceptions extend HttpException
   - Check for global exception filter

Output format:
- Repository structure type (single app / monorepo)
- ESLint configuration status (per app if monorepo)
- Prettier configuration status (per app if monorepo)
- TypeScript strict mode status (per app if monorepo)
- Code quality scripts availability (per app if monorepo)
- Automated enforcement tools (husky, lint-staged) status
- Static analysis integration status
- Dependency health (outdated, vulnerabilities, duplicates)
- Code smells detected (console.log, TODO, eslint-disable)
- Best practices compliance (per app if monorepo)
- Configuration consistency across apps/packages (if monorepo)
- Missing configurations or gaps (per app if monorepo)
- Recommendations for improvement (per app if monorepo)
