# Next.js Testing Quality Analysis

> Analyze the test suite for Next.js surfaces: Vitest or Jest with React Testing Library, Playwright end-to-end tests, and how async Server Components, Server Actions and Route Handlers are tested.

---

Goal: Evaluate whether the tests cover the parts of a Next.js app that unit
tests alone cannot, and whether component tests follow Testing Library
practice.

VERSION & DOCS RESOLUTION (MANDATORY — run before any analysis):
1. Resolve the INSTALLED `next` version from the lockfile, not from the
   `package.json` range:
   - `pnpm-lock.yaml`, `package-lock.json`, `yarn.lock` or `bun.lock` at the
     project root (or at the workspace root in a monorepo).
   - Fallback: the `"version"` field of `node_modules/next/package.json`.
   - If neither resolves, record the `package.json` range, write
     "Installed version: Unknown", and mark every version-dependent finding
     "unverified against the installed version".
2. Read version-matched documentation; the first source that exists wins:
   a. `node_modules/next/dist/docs/` — bundled with the installed package in
      newer releases; mirrors the nextjs.org/docs tree (`01-app/`, `02-pages/`).
   b. `.next-docs/` — downloaded by `npx @next/codemod@canary agents-md` for
      releases that do not bundle docs (usually indexed from `AGENTS.md`).
   c. Otherwise fetch https://nextjs.org/docs for the installed major. Older
      majors live under a versioned prefix (e.g. `https://nextjs.org/docs/15`);
      the unprefixed path documents the latest release. Every page has a
      Markdown variant at `<url>.md`, and `<prefix>/llms.txt` indexes all pages
      for that version.
   Record in the output: "Installed version: X.Y.Z" and "Docs source: <a|b|c + path>".
3. Never assert that an API, option, file convention or default exists in the
   installed version without evidence from those docs. If the matching docs do
   not mention it, write "not documented for vX.Y" instead of recommending it.
4. Never cite vulnerability version numbers from memory. Security findings go
   to the `nextjs-security-audit` skill; mention them only as a referral.

DOCS TO READ FOR THIS DIMENSION (use the equivalent page names if the
installed version organizes them differently):
- Guides: Testing (overview, including its guidance on async Server
  Components), and the Vitest, Jest, Playwright and Cypress setup guides
- Guides: Instant Navigation, if the installed version documents an
  `instant()` test helper — only then may you recommend it

COMPLEMENTARY STANDARDS (read when present, never required):
- Somnio Next.js rules: every `.md` under `agent-rules/rules/nextjs/` in the
  local repo. Skip when the directory is absent; do not guess remote URLs.
- Somnio React testing rule (RTL query priority, AAA, async testing):
  local: `agent-rules/rules/react/testing.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/react/testing.md

ANALYSIS TARGETS:
1.  **Tooling Inventory**:
    *   Unit/component runner: Vitest or Jest (config file, `next/jest` or
        the Vitest React plugin setup the docs describe), jsdom/happy-dom
        environment, React Testing Library and `@testing-library/user-event`.
    *   E2E runner: Playwright (or Cypress) config, `webServer` / base URL
        setup, whether tests run against a production build.
    *   CI wiring: test scripts in `package.json` and a CI workflow that runs
        them. Report "Unknown" if no CI config is in the repo.

2.  **Coverage of Next.js Surfaces**:
    *   Async Server Components: the testing docs recommend end-to-end tests
        over unit tests for `async` components (confirm for the installed
        version). Flag unit tests that render async Server Components through
        workarounds that the docs do not support, and key async pages with no
        E2E coverage.
    *   Server Actions: the underlying logic (validation, authorization,
        data access layer) is unit-tested as plain functions; at least the
        critical forms are covered end to end.
    *   Route Handlers: handlers are tested by calling the exported method
        functions with a `Request`, or through E2E/API tests.
    *   Critical user flows (auth, checkout, CRUD of the core entity) have at
        least one E2E test. List the flows found and missing.

3.  **Component Test Quality (Client Components)**:
    *   Query priority: `getByRole` > `getByLabelText` > ... > `getByTestId`;
        `screen` usage; `findBy*` for async UI.
    *   `userEvent` over `fireEvent`; no stray `act()` wrapping.
    *   Every test asserts something; one behavior per test; Arrange-Act-Assert.
    *   `next/navigation` and `next/headers` are mocked at module level in a
        typed way when a unit test needs them, rather than ad hoc per test.

4.  **E2E Test Quality**:
    *   Locators by role/label/text rather than CSS selectors; no fixed
        `waitForTimeout` sleeps; tests are independent (own data setup).
    *   Flag E2E tests that hit real third-party services without isolation.

OUTPUT FORMAT:
*   **Installed version / Docs source**: as resolved above.
*   **Overview**: unit test files, E2E spec files, runners in use, critical
    flows covered `[covered]/[identified]`.
*   **Score**: 0-100 integer with label (Strong 85-100 / Fair 70-84 / Weak 0-69).
    Start at 100 and deduct per violation: Critical -15, High -8, Medium -4,
    Low -1 (floor 0). No tests at all is Critical and caps the score at 30.
*   **Violations**: list specific file paths and lines.
    *   Format: `[Type Issue] path/to/file.test.tsx:line — description`
*   **Compliance**: good examples found in the codebase.
*   **Recommendations**: specific suggestions per violation.
*   **Recommended follow-up** (only when the installed docs mention it): the
    official `next-dev-loop` skill (`npx skills add vercel/next.js --skill
    next-dev-loop`, source https://github.com/vercel/next.js/tree/canary/skills)
    to verify changes against a running dev server.
