# Angular Test Coverage

> Generate and extract test coverage metrics for Angular projects using Karma/Jasmine or Jest.

---

Goal: Execute the test suite with coverage collection and extract
coverage percentages for the final audit report.

COVERAGE GENERATION:

1. **Detect Test Runner**:
   - Check `angular.json` `test` builder and `package.json` scripts:
     * Karma+Jasmine (default): `karma.conf.js`, `karma` + `jasmine-core`
       in devDependencies
     * Jest: `jest.config.*`, `jest-preset-angular` or
       `@angular-builders/jest`
   - Check for `karma.conf.js` or `jest.config.*` files

2. **Karma Coverage Command**:
   - Run headless with coverage:
     `npx ng test --watch=false --code-coverage --browsers=ChromeHeadless
     > /dev/null 2>&1`
   - Requires Chrome/Chromium; if unavailable set `CHROME_BIN` or note
     that the runner could not launch a browser
   - Check existing coverage config in `karma.conf.js`:
     `coverageReporter` / `coverageIstanbulReporter`, `check.global`
     thresholds

3. **Jest Coverage Command**:
   - If Jest: `npx jest --coverage > /dev/null 2>&1` (or the project's
     `npm test -- --coverage`)
   - Check `coverage` config in `jest.config.*`: `coverageThreshold`,
     `collectCoverageFrom`

4. **Extract Coverage Metrics**:
   - Read `coverage/**/coverage-summary.json` if generated, or parse the
     Istanbul text summary / `lcov.info`
   - Extract: lines %, branches %, functions %, statements %
   - If summary file missing, parse stdout output for percentages
   - Format: `Code Coverage: [lines]% lines / [branches]% branches /
     [functions]% functions`

5. **Coverage Threshold Check**:
   - Check if coverage thresholds are configured (karma `check.global`
     or jest `coverageThreshold`)
   - Note if thresholds are met or failing
   - Report configured thresholds

6. **Failure Handling**:
   - If tests fail: note failures but continue (get partial coverage)
   - If no browser is available for Karma: note it and report "Unknown"
   - If coverage is not configured: note "Coverage not configured"
   - Report "Unknown" if no coverage data can be extracted

OUTPUT:
- Code Coverage: [XX]% lines / [XX]% branches / [XX]% functions
- Coverage thresholds configured: [Yes/No]
- Thresholds met: [Yes/No/N/A]
- Test runner: [Karma+Jasmine/Jest]
- Total tests: [XX passing / XX failing / XX total]
