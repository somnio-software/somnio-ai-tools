# NestJS Testing Analysis

> Find and classify all test files, identify coverage configuration and test types (unit, integration, e2e) for NestJS projects.

---

Goal: Find and classify all test files, identify coverage configuration
and test types for single app or monorepo repositories.

MONOREPO DETECTION:
- First detect repository structure: single app or monorepo
- If apps/ directory exists, analyze each app individually
- If packages/ or libs/ directory exists, analyze each package/library
  individually

SINGLE APP TESTING ANALYSIS:
- Search and classify testing setup:
  * Find all *.spec.ts files (unit/integration tests)
  * Find all *.e2e-spec.ts files (end-to-end tests)
  * Count total test files by type
  * Analyze test organization: co-located vs test/ directory
  * Check for test/ directory structure
  * Look for test utilities and mocks
  * Integrate coverage results from NestJS Test Coverage Runner

TEST TYPES CLASSIFICATION:

1. Unit Tests (*.spec.ts):
   - Find all unit test files in src/**/*.spec.ts
   - Analyze unit test patterns:
     * Service tests (*.service.spec.ts)
     * Controller tests (*.controller.spec.ts)
     * Guard tests (*.guard.spec.ts)
     * Pipe tests (*.pipe.spec.ts)
     * Interceptor tests (*.interceptor.spec.ts)
     * Middleware tests (*.middleware.spec.ts)
     * Repository tests (*.repository.spec.ts)
   - Check for proper mocking:
     * @nestjs/testing Test module usage
     * Dependency injection mocking
     * External service mocking
   - Verify test isolation
   
2. Integration Tests:
   - Find integration test files (may be in test/ or src/)
   - Check for database integration tests
   - Check for API integration tests
   - Verify test database setup (in-memory, test containers)
   - Check for proper cleanup (afterEach, afterAll)
   
3. End-to-End Tests (*.e2e-spec.ts):
   - Find all E2E test files in test/**/*.e2e-spec.ts
   - Analyze E2E test structure:
     * API endpoint tests
     * Authentication flow tests
     * Business flow tests
     * Error handling tests
   - Check for supertest usage
   - Verify test app setup (TestingModule)
   - Check for database seeding/cleanup

TESTING FRAMEWORK ANALYSIS:

1. Jest Configuration:
   - Check for jest.config.js or package.json jest config
   - Analyze Jest configuration:
     * testMatch patterns
     * collectCoverageFrom patterns
     * coverageDirectory
     * coverageReporters (lcov, text, html)
     * coverageThreshold settings
     * moduleNameMapper (path aliases)
     * setupFilesAfterEnv (test setup)
     * testEnvironment (node)
   
2. Testing Utilities:
   - Check for @nestjs/testing usage
   - Verify Test.createTestingModule() usage
   - Check for custom test utilities
   - Check for test factories/builders
   - Verify mock factories
   
3. Test Coverage Configuration:
   - Check for coverage scripts in package.json
   - Verify coverage thresholds:
     * Global coverage threshold
     * Per-file coverage threshold
     * Branches coverage
     * Functions coverage
     * Lines coverage
     * Statements coverage
   - Check for coverage exclusions (ignore patterns)

MULTI-APP MONOREPO TESTING ANALYSIS:
- Root-level testing configuration:
  * Check for root jest.config.js
  * Check for shared testing utilities
  * Look for root-level test setup
- Per-app testing analysis:
  * For each app in apps/ directory:
    - Find all test files in apps/<app_name>
    - Count test files per app by type
    - Check for app-specific jest configuration
    - Check for app-specific test utilities
    - Integrate coverage results per app
- Cross-app testing consistency:
  * Compare testing patterns across apps
  * Verify consistent test structure
  * Check for shared vs app-specific test utilities
- Package/library testing:
  * For each package in packages/ or libs/:
    - Find all test files in package
    - Check for package-specific jest configuration
    - Verify published libraries have tests

TEST QUALITY INDICATORS:

1. Test Coverage Metrics:
   - Check for coverage reports (coverage/)
   - Analyze coverage by type:
     * Controllers coverage
     * Services coverage
     * Guards coverage
     * Pipes coverage
     * Repositories coverage
   - Identify untested files
   - Check coverage trends
   
2. Test Assertions Quality:
   - Check for proper assertions (expect statements)
   - Verify assertion specificity (not just toBeDefined)
   - Check for edge case testing
   - Verify error path testing
   
3. Test Maintainability:
   - Check for test duplication
   - Verify test readability (describe/it structure)
   - Check for magic numbers/strings
   - Verify test data management
   
4. Mocking Practices:
   - Check for proper mock isolation
   - Verify mock reset between tests
   - Check for spy usage
   - Verify mock completeness

NESTJS-SPECIFIC TESTING PATTERNS:

1. Dependency Injection Testing:
   - Verify proper provider mocking
   - Check for useValue, useClass, useFactory mocks
   - Verify module compilation in tests
   
2. Request/Response Testing:
   - Check for HTTP request testing (supertest)
   - Verify response validation
   - Check for status code assertions
   - Verify response body structure
   
3. Database Testing:
   - Check for repository mocking
   - Verify transaction handling in tests
   - Check for database cleanup
   - Verify query testing
   
4. Authentication/Authorization Testing:
   - Check for guard testing
   - Verify JWT mocking
   - Check for permission testing
   - Verify unauthorized access tests

CONTINUOUS TESTING INTEGRATION:

1. Watch Mode Configuration:
   - Check for test:watch script
   - Verify watch mode configuration
   
2. Debug Configuration:
   - Check for test:debug script
   - Verify debug configuration
   
3. CI/CD Integration:
   - Check for test scripts in CI/CD
   - Verify coverage reporting in CI
   - Check for test failure handling

Output format:
- Repository structure type (single app / monorepo)
- Total count of test files by type (per app if monorepo):
  * Unit tests count
  * Integration tests count
  * E2E tests count
- Test coverage metrics (per app if monorepo):
  * Overall coverage percentage
  * Coverage by component type
  * Files without tests
- Jest configuration analysis (per app if monorepo)
- Testing utilities and patterns (per app if monorepo)
- Test quality assessment (per app if monorepo)
- NestJS-specific patterns detected (per app if monorepo)
- Missing test types or gaps (per app if monorepo)
- Testing consistency across apps/packages (if monorepo)
- Recommendations for improvement (per app if monorepo)
