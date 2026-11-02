# Next.js Testing Analysis

> Find and classify all test files, identify the test runners (Vitest/Jest + React Testing Library, Playwright/Cypress E2E), check how Server Actions, Route Handlers and async Server Components are tested, and assess testing infrastructure quality.

---

Goal: Identify all test files, classify test types, and evaluate
the overall testing infrastructure quality of the Next.js project.

EFFICIENCY REQUIREMENTS:
- Use find commands to inventory test files in one pass
- Do NOT read individual test files in full — use grep for pattern detection
- Focus on infrastructure and coverage, not test quality (that is for
  a best-practices review)
- Exclude `node_modules`, `.next`, `coverage`, `playwright-report`,
  `test-results` from every `find`/`grep`

Reference: https://nextjs.org/docs/app/guides/testing — Next.js
documents Vitest and Jest for unit/component tests and Playwright and
Cypress for E2E. Async Server Components are not fully supported by
unit test tools; the guide recommends E2E tests for them.

TEST FILE DETECTION:

1. **Find All Test Files**:
   ```bash
   find . \( -path ./node_modules -o -path ./.next -o -path '*/node_modules' \) -prune -o \
     -type f \( -name '*.test.ts' -o -name '*.test.tsx' -o -name '*.spec.ts' -o -name '*.spec.tsx' \
     -o -name '*.test.js' -o -name '*.test.jsx' -o -name '*.spec.js' \) -print | wc -l
   ```
   - Count total test files and list the patterns used
   - Note colocated tests inside `app/`: they are safe (only `page`,
     `route` and other special files become routes), but tests under
     `pages/` would be treated as pages by the Pages Router — flag any

2. **Test Type Classification**:
   - Unit/Component tests: colocated with components, or `__tests__/`
   - Integration tests: `tests/integration/` or similar
   - E2E tests: Playwright (`playwright.config.*`, `@playwright/test`),
     Cypress (`cypress.config.*`, `cypress/`)
   - Instant-navigation tests: `@next/playwright` and its `instant()`
     helper (used with Cache Components to lock in which UI is available
     immediately on navigation) — a strong maturity signal when present
   - Storybook interaction/visual tests: `*.stories.tsx`,
     `@storybook/nextjs` or `@storybook/nextjs-vite`

3. **Runner Configuration**:
   - Vitest: `vitest.config.*` with `@vitejs/plugin-react`, `environment:
     'jsdom'` (or `happy-dom`), `vite-tsconfig-paths` for `@/*` aliases
   - Jest: `jest.config.*` built with `next/jest` (loads `next.config`,
     `.env`, SWC transforms and mocks for styles/images/`next/font`)
   - Coverage settings: Vitest `coverage` block / Jest
     `collectCoverageFrom`, `coverageThreshold`
   - Playwright: `webServer` command (`pnpm build && pnpm start` is
     closer to production than `next dev`), `baseURL`, projects/browsers,
     `retries` and `trace` in CI

4. **Testing Libraries**:
   - Check devDependencies for:
     * `@testing-library/react` — component testing
     * `@testing-library/user-event` — interaction simulation
     * `@testing-library/jest-dom` — custom matchers
     * `msw` — network mocking
     * `vitest` or `jest` — unit runner
     * `@playwright/test` or `cypress` — E2E
     * `@next/playwright` — instant-navigation assertions
   - Note which are missing but commonly needed

5. **Next.js server code under test** (grep, count, list examples):
   - **Server Actions**: files with `'use server'` — are the action
     functions imported and called directly in unit tests (with the data
     layer mocked), or exercised through E2E form submissions? Count
     action files vs action files referenced by any test
   - **Route Handlers** (`app/**/route.ts`): tests that import the
     `GET`/`POST` exports and call them with a `Request`/`NextRequest`,
     or E2E/API tests hitting the endpoint. Count handlers vs handlers
     referenced by any test
   - **Pages Router API routes** (`pages/api/**`): tested with
     `node-mocks-http` or similar?
   - **Proxy / middleware**: tests using
     `unstable_doesProxyMatch` from `next/experimental/testing/server`
     (experimental utility) or E2E coverage of redirects/auth
   - **`next.config` routing**: `unstable_getResponseFromNextConfig`
     tests for headers/redirects/rewrites (experimental utility)
   - **Async Server Components**: count async `page`/`layout`
     components; check whether E2E specs cover those routes (unit tests
     cannot fully render them)
   - Mocks for Next.js modules: `next/navigation` (`useRouter`,
     `usePathname`), `next/headers` (`cookies`, `headers`), `next/cache`

6. **Test Coverage Ratio**:
   - Count component files (`*.tsx` excluding special route files) and
     their tests
   - Calculate rough ratio: test files / component files
   - Report Server Action and Route Handler test ratios separately
   - Note: this is file coverage, not line coverage (use
     `test-coverage.md` for actual percentages)

7. **Mocking Setup**:
   - `__mocks__/` directories, MSW handlers (`mocks/handlers.*`)
   - Setup files (`vitest.setup.*`, `jest.setup.*`) importing
     `@testing-library/jest-dom`

OUTPUT FORMAT:

Provide structured analysis:
- Total test files: [XX]
- Unit runner: [Vitest/Jest/None] (Jest via next/jest: [Yes/No/N/A])
- RTL installed: [Yes/No]
- user-event installed: [Yes/No]
- jest-dom installed: [Yes/No]
- MSW installed: [Yes/No]
- E2E testing: [Playwright/Cypress/None] (spec files: [XX]; webServer: [build+start/dev/preview URL])
- `@next/playwright` instant() tests: [Yes/No]
- Server Actions tested: [X of Y action files referenced by tests]
- Route Handlers tested: [X of Y handlers referenced by tests]
- Async Server Component routes with E2E coverage: [X of Y / Unknown]
- Proxy/middleware tests: [Yes/No/N/A]
- Coverage configured: [Yes/No] (thresholds: [Yes/No])
- Component-to-test ratio: [XX]%
- Storybook present: [Yes/No]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Unit runner + RTL + user-event + jest-dom configured
- Coverage thresholds configured and met
- E2E suite covering critical flows, including async Server Component routes
- Server Actions and Route Handlers tested (unit or E2E)

Fair (70-84):
- Basic unit testing configured, little or no E2E
- Server Actions / Route Handlers mostly untested
- Coverage configured but no thresholds

Weak (0-69):
- Few or no tests
- Testing libraries not installed
- No coverage configuration and no E2E
