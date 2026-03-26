# React Testing Analysis

> Find and classify all test files, identify coverage configuration, and assess testing infrastructure quality.

---

Goal: Identify all test files, classify test types, and evaluate
the overall testing infrastructure quality.

EFFICIENCY REQUIREMENTS:
- Use find commands to inventory test files in one pass
- Do NOT read individual test files — use grep for pattern detection
- Focus on infrastructure and coverage, not test quality (that is for react-best-practices)

TEST FILE DETECTION:

1. **Find All Test Files**:
   ```bash
   find src/ -name "*.test.tsx" -o -name "*.test.ts" \
     -o -name "*.spec.tsx" -o -name "*.spec.ts" \
     -o -name "*.test.jsx" -o -name "*.test.js" | wc -l
   ```
   - Count total test files
   - List test file patterns used (`.test.tsx`, `.spec.ts`, etc.)

2. **Test Type Classification**:
   - Unit/Component tests: files in `src/` colocated with components
   - Integration tests: files in `src/__tests__/` or `tests/`
   - E2E tests: check for Playwright (`playwright.config.*`), Cypress
     (`cypress.config.*`), or Vitest browser mode
   - Storybook interaction tests: check for `*.stories.tsx` files

3. **Coverage Configuration**:
   - Check Jest: `jest.config.*` for `collectCoverageFrom`,
     `coverageDirectory`, `coverageThreshold`
   - Check Vitest: `vitest.config.*` for `coverage` section
   - Note if coverage is configured or missing

4. **Testing Libraries**:
   - Check devDependencies for:
     * `@testing-library/react` — component testing
     * `@testing-library/user-event` — interaction simulation
     * `@testing-library/jest-dom` — custom matchers
     * `msw` — API mocking
     * `jest` or `vitest` — test runner
     * `@playwright/test` or `cypress` — E2E
   - Note which libraries are missing but commonly needed

5. **Test Coverage Ratio**:
   - Count `.tsx` component files in `src/`
   - Count corresponding `.test.tsx` files
   - Calculate rough coverage ratio: test files / component files
   - Note: This is file coverage, not line coverage (use test-coverage.md
     for actual percentages)

6. **Mocking Setup**:
   - Check for `src/__mocks__/` directory (module mocks)
   - Check for MSW handlers: `src/mocks/handlers.*`
   - Check `setupFilesAfterFramework` in Jest/Vitest config for
     `@testing-library/jest-dom/extend-expect`

OUTPUT FORMAT:

Provide structured analysis:
- Total test files: [XX]
- Test runner: [Jest/Vitest/Unknown]
- RTL installed: [Yes/No]
- user-event installed: [Yes/No]
- jest-dom installed: [Yes/No]
- MSW installed: [Yes/No]
- E2E testing: [Playwright/Cypress/None]
- Coverage configured: [Yes/No]
- Component-to-test ratio: [XX]%
- Storybook present: [Yes/No]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Testing library fully configured (RTL + user-event + jest-dom)
- Coverage thresholds configured and met
- Most components have tests
- E2E or integration tests present

Fair (70-84):
- Basic testing configured
- Some components missing tests
- Coverage configured but no thresholds

Weak (0-69):
- Few or no tests
- Testing libraries not installed
- No coverage configuration
