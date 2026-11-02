# Next.js Test Coverage

> Generate and extract test coverage metrics for Next.js projects using Vitest or Jest, run with the repository's own package manager.

---

Goal: Execute the unit/component test suite with coverage collection
and extract coverage percentages for the final audit report.

Run every command with the package manager detected in
`tool-installer.md` (`pnpm exec`, `npx`, `yarn`, `bunx`). The examples
below use `pnpm exec`; substitute the equivalent for npm/yarn/bun.

COVERAGE GENERATION:

1. **Detect Test Runner**:
   - Check `package.json` scripts for the runner:
     * Vitest: `"test": "vitest"` / `"vitest run"`
     * Jest: `"test": "jest"`
   - Check devDependencies for `vitest`, `@vitest/coverage-v8`,
     `@vitest/coverage-istanbul`, `jest`, `jest-environment-jsdom`
   - Check for `vitest.config.*` or `jest.config.*` (Next.js projects
     commonly use `next/jest` to create the Jest config)
   - In a monorepo, detect per Next.js app (and per shared package)

2. **Vitest Coverage Command**:
   - `pnpm exec vitest run --coverage > /dev/null 2>&1`
   - Check the `coverage` block in `vitest.config.*`: `provider`
     (`v8` or `istanbul`), `reporter`, `thresholds`, `include`/`exclude`
   - If the coverage provider package is missing, record
     "Coverage provider not installed" — do not install it

3. **Jest Coverage Command**:
   - `pnpm exec jest --coverage --passWithNoTests > /dev/null 2>&1`
   - Check `jest.config.*` for `coverageDirectory`, `collectCoverageFrom`,
     `coverageThreshold`, and whether it is built with `next/jest`

4. **Monorepo**:
   - Prefer the repository's own task: `pnpm exec turbo run test --
     --coverage` or `pnpm -r --filter <app> test -- --coverage`
   - Collect one summary per app/package for the Coverage Breakdown

5. **Extract Coverage Metrics**:
   - Read `coverage/coverage-summary.json` if generated (enable the
     `json-summary` reporter on the command line when it is not
     configured: Vitest `--coverage.reporter=json-summary`, Jest
     `--coverageReporters=json-summary`)
   - Extract: lines %, branches %, functions %, statements %
   - If the summary file is missing, parse stdout for percentages
   - Format: `Code Coverage: [lines]% lines / [branches]% branches /
     [functions]% functions`

6. **Coverage Threshold Check**:
   - Check if coverage thresholds are configured
   - Note if thresholds are met or failing
   - Report configured thresholds

7. **What unit coverage does not measure** (record, do not penalise
   twice): async Server Components are not fully supported by unit test
   tools, and the Next.js testing guide recommends E2E tests for them
   (https://nextjs.org/docs/app/guides/testing). Note how many `app/`
   routes are async Server Components so the Testing section can weigh
   unit coverage against E2E coverage from `testing-analysis.md`.

8. **Failure Handling**:
   - If tests fail: note failures but continue (get partial coverage)
   - If coverage is not configured: note "Coverage not configured"
   - Report "Unknown" if no coverage data can be extracted
   - Never fabricate a percentage

OUTPUT:
- Code Coverage: [XX]% lines / [XX]% branches / [XX]% functions
- Per app/package coverage (monorepo)
- Coverage thresholds configured: [Yes/No]
- Thresholds met: [Yes/No/N/A]
- Test runner: [Vitest/Jest]
- Total tests: [XX passing / XX failing / XX total]
