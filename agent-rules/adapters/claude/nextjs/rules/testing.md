---
description: "Next.js testing — unit-test DAL, validation and Server Action logic directly, component-test synchronous Client and Server Components with Vitest or Jest + Testing Library, cover async Server Components and full flows with Playwright E2E against a production build, and test proxy matchers."
paths:
  - "**/*.test.ts"
  - "**/*.test.tsx"
  - "**/*.spec.ts"
  - "**/*.spec.tsx"
  - "e2e/**"
  - "tests/**"
  - "__tests__/**"
  - "vitest.config.*"
  - "jest.config.*"
  - "playwright.config.*"
---

# Next.js Testing

How to test a Next.js App Router application: which layer to test with which tool, and how to keep tests independent of framework internals.

## Patterns

### Unit test the logic, not the framework

Keep authorization, validation and data mapping in plain functions (the DAL, schemas, mappers) and unit test them directly. Mock the session and database at the module boundary, not `next/headers` internals scattered across the codebase.

```ts
// src/data/posts.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'

vi.mock('server-only', () => ({}))
vi.mock('@/data/auth', () => ({ verifySession: vi.fn() }))
vi.mock('@/lib/db', () => ({ db: { post: { findUnique: vi.fn(), delete: vi.fn() } } }))

import { verifySession } from '@/data/auth'
import { db } from '@/lib/db'
import { deletePost } from './posts'

describe('deletePost', () => {
  beforeEach(() => vi.clearAllMocks())

  it('rejects users who do not own the post', async () => {
    vi.mocked(verifySession).mockResolvedValue({ userId: 'u1', role: 'user' })
    vi.mocked(db.post.findUnique).mockResolvedValue({ authorId: 'u2' } as never)

    await expect(deletePost('p1')).rejects.toThrow('Forbidden')
    expect(db.post.delete).not.toHaveBeenCalled()
  })
})
```

---

### Test Server Action input handling

Server Actions are async functions; call them directly with a `FormData` or argument object and assert on the returned state. Cover invalid input, unauthenticated and unauthorized callers, not only valid submissions.

```ts
// app/signup/actions.test.ts
import { it, expect, vi } from 'vitest'
vi.mock('server-only', () => ({}))
import { signup } from './actions'

it('returns field errors for an invalid email', async () => {
  const form = new FormData()
  form.set('email', 'not-an-email')
  form.set('password', 'long-enough-password')

  const state = await signup(undefined, form)

  expect(state?.errors?.email).toBeDefined()
})
```

---

### Component tests for synchronous components

Use Vitest (with `@vitejs/plugin-react`, `jsdom`, `@testing-library/react`) or Jest (with `next/jest`) for Client Components and synchronous Server Components. Query by role and label, interact with `@testing-library/user-event`, and assert visible behavior.

```tsx
// app/signup/signup-form.test.tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { it, expect, vi } from 'vitest'

vi.mock('./actions', () => ({ signup: vi.fn(async () => ({ message: 'Check your inbox' })) }))
import { SignupForm } from './signup-form'

it('shows the confirmation message after submit', async () => {
  render(<SignupForm />)
  await userEvent.type(screen.getByRole('textbox', { name: /email/i }), 'a@b.co')
  await userEvent.click(screen.getByRole('button', { name: /sign up/i }))
  expect(await screen.findByText(/check your inbox/i)).toBeInTheDocument()
})
```

---

### E2E with Playwright for async Server Components and flows

Run Playwright against a production build (`next build && next start`) to cover async Server Components, Server Actions, redirects, proxy behavior, caching and auth. Use `webServer` in `playwright.config.ts` to start the app, and include negative auth cases (direct URL access and direct POSTs while logged out or as another user).

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  use: { baseURL: 'http://localhost:3000' },
  webServer: {
    command: 'pnpm build && pnpm start',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
})
```

```ts
// e2e/invoices.spec.ts
import { test, expect } from '@playwright/test'

test('another user cannot open my invoice by URL', async ({ page }) => {
  await loginAs(page, 'bob@example.com')
  const response = await page.goto('/invoices/alice-invoice-id')
  expect(response?.status()).toBe(404)
})
```

---

### Test proxy/middleware matching

Test that the matcher covers what you expect. Recent versions provide experimental helpers in `next/experimental/testing/server` (`unstable_doesProxyMatch` on 16+; `unstable_doesMiddlewareMatch` on 15.x). The names are unstable; check the installed version's proxy/middleware reference.

```ts
import { unstable_doesProxyMatch } from 'next/experimental/testing/server'
import { config } from '../proxy'
import nextConfig from '../next.config'

it('does not run on static assets', () => {
  expect(unstable_doesProxyMatch({ config, nextConfig, url: '/_next/static/chunk.js' })).toBe(false)
})
```

---

### Cache Components regression tests

On versions with Cache Components and instant navigation validation, the docs describe `instant()` E2E assertions that fail when a route stops producing the expected static shell. Use them for routes whose instant load matters, following the installed version's Instant navigation guide.

## Rules

- Keep business, validation and authorization logic in plain functions and unit test them, including failure branches.
- Mock `server-only`, the session and the database at module boundaries.
- Call Server Actions directly in unit tests with `FormData`; assert on returned state.
- Use Testing Library queries by role/label and `user-event` for component tests.
- Use Playwright E2E for async Server Components, Server Actions in the browser, redirects, proxy and auth.
- Run E2E against a production build in CI, and include unauthenticated and cross-user cases.
- Run `next build` in CI; it catches prerender and type errors unit tests cannot.
- Use pnpm scripts (`pnpm test`, `pnpm test:e2e`) and `pnpm install --frozen-lockfile` in CI.

- Avoid unit-rendering `async` Server Components and fighting the test runner instead of using E2E.
- Avoid testing only that an action calls the database, never that it refuses unauthorized callers.
- Avoid mocking `next/headers` and `next/cache` in every test instead of isolating them behind the DAL.
- Avoid running E2E only against `next dev`.
- Avoid snapshot-testing large component trees instead of asserting behavior.
- Avoid using `getByTestId` where a role or label query exists.
- Avoid skipping `next build` in CI.
