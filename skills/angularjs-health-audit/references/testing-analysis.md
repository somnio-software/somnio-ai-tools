# AngularJS Testing Analysis

> Find and classify all test files (Karma/Jasmine specs, angular-mocks, Protractor/Cypress e2e), identify coverage configuration, and assess testing infrastructure quality.

---

Goal: Identify all test files, classify test types, and evaluate
the overall testing infrastructure quality.

EFFICIENCY REQUIREMENTS:
- Use find commands to inventory test files in one pass
- Do NOT read individual test files — use grep for pattern detection
- Focus on infrastructure and coverage, not test quality
- EXCLUDE vendor/min/dist from all counts

TEST FILE DETECTION:

1. **Find All Test Files**:
   ```bash
   find . -path ./node_modules -prune -o -path ./bower_components -prune -o \
     \( -name "*.spec.js" -o -name "*_spec.js" -o -name "*.test.js" \) -print | wc -l
   ```
   - Count total spec files
   - List the spec-file pattern used (`.spec.js`, `_spec.js`, `test/unit/...`)

2. **Test Type Classification**:
   - Unit specs: Jasmine (or Mocha) specs run by Karma, typically colocated
     with the source or under `test/unit/`
   - e2e tests: Protractor (`protractor.conf.js`, `test/e2e/`), or a modern
     Cypress (`cypress.config.*`) / WebdriverIO setup
   - Note whether the project still relies on the abandoned Protractor

3. **Karma / Runner Configuration**:
   - Check for `karma.conf.js` (or `karma.conf.coffee`)
   - Inspect `frameworks` (jasmine/mocha), `browsers` (PhantomJS is a
     deprecation risk; ChromeHeadless is current), `preprocessors`
     (coverage), `reporters`
   - Note if coverage (`karma-coverage`) is configured and any thresholds
   - If no Karma config exists, note "no unit test runner configured"

4. **Testing Libraries** (from bower.json / package.json devDependencies):
   - `angular-mocks` — MANDATORY for real AngularJS unit tests (`module()`,
     `inject()`, `$httpBackend`); flag its absence loudly
   - `karma` + launchers (`karma-chrome-launcher`, `karma-phantomjs-launcher`)
   - `jasmine` / `jasmine-core` (or `mocha` + `chai` + `sinon`)
   - `karma-coverage` / `istanbul`
   - `protractor` or `cypress` for e2e
   - Note which are missing but commonly needed

5. **Test Coverage Ratio**:
   - Count source `.js` files (controllers/services/directives, excluding
     vendor/min/dist)
   - Count corresponding spec files
   - Calculate a rough file-coverage ratio: spec files / source files
   - Note: this is file coverage, not line coverage (use test-coverage.md for
     actual percentages)

6. **Mocking Setup**:
   - Check for `$httpBackend` usage (mocking `$http`)
   - Check for `angular.mock.module` / `module('app')` + `inject()` patterns
   - Check for fixture files under `test/mock/` or similar

OUTPUT FORMAT:

Provide structured analysis:
- Total spec files: [XX]
- Test runner: [Karma/Unknown]
- Test framework: [Jasmine/Mocha/Unknown]
- angular-mocks installed: [Yes/No]
- Browser launcher: [ChromeHeadless/PhantomJS(deprecated)/Other]
- Coverage tooling (karma-coverage): [Yes/No]
- e2e testing: [Protractor(EOL)/Cypress/WebdriverIO/None]
- Source-to-spec ratio: [XX]%
- $httpBackend / mocks in use: [Yes/No]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Karma + Jasmine + angular-mocks fully configured
- Coverage thresholds configured and met
- Most controllers/services/directives have specs
- e2e tests present on a maintained runner

Fair (70-84):
- Basic Karma/Jasmine configured
- Some units missing specs
- Coverage configured but no thresholds; or e2e only on Protractor

Weak (0-69):
- Few or no specs
- angular-mocks or Karma not installed
- No coverage configuration
