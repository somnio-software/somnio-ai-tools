# AngularJS Test Coverage

> Generate and extract test coverage metrics for AngularJS projects using Karma + karma-coverage (Istanbul).

---

Goal: Execute the unit test suite with coverage collection and extract
coverage percentages for the final audit report.

COVERAGE GENERATION:

1. **Detect Test Runner**:
   - Check for `karma.conf.js` (or `karma.conf.coffee`)
   - Check `package.json` scripts / Gruntfile / gulpfile for a test task
     (`karma start --single-run`, `grunt test`, `gulp test`, `npm test`)
   - Check devDependencies for `karma`, `jasmine`/`mocha`, `angular-mocks`,
     `karma-coverage`

2. **Karma Coverage Command**:
   - Preferred single-run invocation:
     `npx karma start --single-run > /dev/null 2>&1`
   - Or via the build tool: `npx grunt test > /dev/null 2>&1` /
     `npx gulp test > /dev/null 2>&1`
   - Ensure `karma-coverage` is in `reporters` and a `coverageReporter` is
     configured (type `json-summary`/`lcov`/`text-summary`)
   - Prefer a headless browser (`ChromeHeadless`); PhantomJS may be
     unavailable on modern systems — note it if the run fails for that reason

3. **Coverage Threshold Check**:
   - Check `coverageReporter.check` in `karma.conf.js` for configured
     thresholds
   - Note if thresholds are met or failing
   - Report the configured thresholds

4. **Extract Coverage Metrics**:
   - Read `coverage/**/coverage-summary.json` (Istanbul json-summary) if
     generated, or parse `text-summary` stdout
   - Extract: lines %, branches %, functions %, statements %
   - Format: `Code Coverage: [lines]% lines / [branches]% branches /
     [functions]% functions`

5. **Failure Handling**:
   - If tests fail: note failures but continue (get partial coverage)
   - If no browser launcher is available (e.g. PhantomJS missing): note it and
     report "Coverage not collected — no runnable browser"
   - If coverage is not configured: note "Coverage not configured"
   - Report "Unknown" if no coverage data can be extracted

OUTPUT:
- Code Coverage: [XX]% lines / [XX]% branches / [XX]% functions
- Coverage thresholds configured: [Yes/No]
- Thresholds met: [Yes/No/N/A]
- Test runner: [Karma]
- Test framework: [Jasmine/Mocha]
- Total tests: [XX passing / XX failing / XX total]
