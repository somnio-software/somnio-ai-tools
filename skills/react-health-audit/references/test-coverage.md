# React Test Coverage

> Generate and extract test coverage metrics for React projects using Jest or Vitest.

---

Goal: Execute test suite with coverage collection and extract
coverage percentages for the final audit report.

COVERAGE GENERATION:

1. **Detect Test Runner**:
   - Check `package.json` scripts for test runner:
     * Jest: `"test": "jest"` or `"react-scripts test"`
     * Vitest: `"test": "vitest"`
   - Check devDependencies for `jest`, `vitest`, or `@jest/core`
   - Check for `jest.config.*` or `vitest.config.*` files

2. **Jest Coverage Command**:
   - If CRA project: `npx react-scripts test --coverage --watchAll=false
     --ci > /dev/null 2>&1`
   - If Jest configured: `npx jest --coverage --passWithNoTests
     > /dev/null 2>&1`
   - Check for existing coverage config in `jest.config.*`:
     `coverageDirectory`, `collectCoverageFrom`, `coverageThreshold`

3. **Vitest Coverage Command**:
   - If Vitest: `npx vitest run --coverage > /dev/null 2>&1`
   - Check for `coverage` config in `vitest.config.*`:
     `provider` (v8 or istanbul), `reporter`, `thresholds`

4. **Extract Coverage Metrics**:
   - Read `coverage/coverage-summary.json` (Jest) or
     `coverage/coverage-summary.json` (Vitest) if generated
   - Extract: lines %, branches %, functions %, statements %
   - If summary file missing, parse stdout output for percentages
   - Format: `Code Coverage: [lines]% lines / [branches]% branches /
     [functions]% functions`

5. **Coverage Threshold Check**:
   - Check if coverage thresholds are configured
   - Note if thresholds are met or failing
   - Report configured thresholds

6. **Failure Handling**:
   - If tests fail: note failures but continue (get partial coverage)
   - If coverage is not configured: note "Coverage not configured"
   - Report "Unknown" if no coverage data can be extracted

OUTPUT:
- Code Coverage: [XX]% lines / [XX]% branches / [XX]% functions
- Coverage thresholds configured: [Yes/No]
- Thresholds met: [Yes/No/N/A]
- Test runner: [Jest/Vitest]
- Total tests: [XX passing / XX failing / XX total]
