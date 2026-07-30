# Angular Testing Analysis

> Find and classify all spec files, identify the test runner and coverage configuration, and assess testing infrastructure quality for an Angular project.

---

Goal: Identify all test files, classify test types, and evaluate
the overall testing infrastructure quality.

EFFICIENCY REQUIREMENTS:
- Use find commands to inventory spec files in one pass
- Do NOT read individual test files — use grep for pattern detection
- Focus on infrastructure and coverage, not test quality

TEST FILE DETECTION:

1. **Find All Test Files**:
   ```bash
   find src/ -name "*.spec.ts" | wc -l
   ```
   - Count total spec files (Angular's convention is `*.spec.ts`
     colocated with the unit under test)
   - Also note any `*.test.ts` files if Jest is used

2. **Test Type Classification**:
   - Unit tests: `*.spec.ts` colocated with components/services (use
     `TestBed`)
   - Integration tests: specs that mount a component tree / router
   - E2E tests: check for Cypress (`cypress.config.*`), Playwright
     (`playwright.config.*`), or legacy Protractor (`protractor.conf.js`
     / `e2e/` — deprecated, flag it)

3. **Test Runner Detection**:
   - Karma + Jasmine (Angular CLI default): `karma.conf.js`, `test.ts`,
     `jasmine-core` + `karma` in devDependencies, `test` builder is
     `@angular-devkit/build-angular:karma`
   - Jest: `jest.config.*` / `jest-preset-angular` /
     `@angular-builders/jest`, or `test` builder set to a Jest builder
   - Web Test Runner or other experimental runners: note if present

4. **Coverage Configuration**:
   - Karma: `karma.conf.js` `coverageReporter` /
     `coverageIstanbulReporter`, and `ng test --code-coverage`
   - Angular CLI: `codeCoverage` option, `check`/`thresholds` in the
     karma coverage reporter
   - Jest: `coverageThreshold`, `collectCoverageFrom` in `jest.config.*`
   - Note if coverage is configured or missing

5. **Testing Libraries**:
   - Check devDependencies for:
     * `@angular/core/testing` (`TestBed`) — always available with Angular
     * `jasmine-core` + `karma` — default runner
     * `@testing-library/angular` — user-centric component testing
     * `ng-mocks` / `spectator` — Angular test helpers
     * `jest` / `jest-preset-angular` — Jest runner
     * `@playwright/test` / `cypress` — E2E
   - Note which libraries are missing but commonly needed

6. **Test Coverage Ratio**:
   - Count `*.component.ts` and `*.service.ts` files in `src/`
   - Count corresponding `*.spec.ts` files
   - Calculate rough file-coverage ratio: spec files / (components +
     services)
   - Note: This is file coverage, not line coverage (use
     test-coverage.md for actual percentages)

7. **Mocking / Harness Setup**:
   - Check for `HttpClientTestingModule` / `provideHttpClientTesting`
     usage for HTTP mocking
   - Check for component test harnesses (`@angular/cdk/testing`)
   - Check `test.ts` / setup files for global test configuration

OUTPUT FORMAT:

Provide structured analysis:
- Total spec files: [XX]
- Test runner: [Karma+Jasmine/Jest/Unknown]
- TestBed usage: [Yes/No]
- @testing-library/angular installed: [Yes/No]
- ng-mocks / spectator installed: [Yes/No]
- HttpClientTestingModule usage: [Yes/No]
- E2E testing: [Cypress/Playwright/Protractor (deprecated)/None]
- Coverage configured: [Yes/No]
- (Component+Service)-to-spec ratio: [XX]%
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Test runner fully configured (Karma+Jasmine or Jest) with HTTP mocking
- Coverage thresholds configured and met
- Most components and services have specs
- E2E or integration tests present

Fair (70-84):
- Basic testing configured
- Some components/services missing specs
- Coverage configured but no thresholds

Weak (0-69):
- Few or no specs
- Coverage not configured
- Reliance on deprecated Protractor with no replacement
