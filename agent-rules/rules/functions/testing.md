> Applies to: `functions/tests/**/*.test.ts`
# Firebase Functions — Testing

Jest + ts-jest for backend tests. Tests mock Firebase SDKs at the module
boundary and exercise real TypeScript source via `ts-jest`.

General testing concepts live in `.claude/rules/flutter/testing.md` — this
file covers only the Firebase Functions specifics.

---

## Stack

- **Runner:** Jest 29.
- **Transformer:** `ts-jest` preset (no `tsc` build step before running tests).
- **HTTP:** `supertest` for end-to-end Express route tests.
- **Firebase helpers:** `firebase-functions-test` (rarely needed — mocks are
  usually enough).
- **Location:** `functions/tests/` (flat — mirrors `functions/src/` file by
  file).

Run:

```bash
cd functions && npm test
```

---

## Jest config

Real `functions/tests/jest.config.js`:

```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  // Run serially — ts-jest + firebase-admin spawn heavy processes per worker
  // and parallel runs exhaust memory.
  maxWorkers: 1,
  workerThreads: false,
};
```

**`maxWorkers: 1` and `workerThreads: false` are mandatory.** Parallel
execution causes intermittent failures when multiple workers each load
`firebase-admin` and compete for cached modules. Do not override these for
"speed" — the flakiness isn't worth it.

---

## File layout

One test file per source file; mirror the name:

```
functions/src/sheetsService.ts   → functions/tests/sheetsService.test.ts
functions/src/app.ts             → functions/tests/app.test.ts
functions/src/storageService.ts  → functions/tests/storageService.test.ts
```

Keep tests flat. No nested `tests/` folders. One suite per module.

---

## Mocking Firebase SDKs

The single most important rule: **mock before importing the module under
test.** `jest.mock()` is hoisted to the top of the file at compile time, but
the modules being mocked must be registered before the `import` of the
subject pulls them in transitively.

Real pattern from `functions/tests/storageService.test.ts`:

```typescript
// @ts-nocheck

// ── Mock firebase-admin/storage FIRST ───────────────────────────────────
const mockSave = jest.fn();
const mockGetSignedUrl = jest.fn()
  .mockResolvedValue(['https://storage.googleapis.com/signed-url']);
const mockFile = jest.fn(() => ({ save: mockSave, getSignedUrl: mockGetSignedUrl }));
const mockBucket = jest.fn(() => ({ file: mockFile }));

jest.mock('firebase-admin/storage', () => ({
  getStorage: () => ({ bucket: mockBucket }),
}));

jest.mock('firebase-admin/app', () => ({
  initializeApp: jest.fn(),
  getApps: jest.fn(() => [{}]),  // pretend app is already initialized
}));

// ── THEN import the subject ─────────────────────────────────────────────
import { uploadReceiptToStorage } from '../src/storageService';
```

Standard mock targets for the SDKs you'll see:

```typescript
jest.mock('firebase-admin/auth', () => ({ getAuth: jest.fn() }));
jest.mock('firebase-admin/firestore', () => ({ getFirestore: jest.fn() }));
jest.mock('firebase-admin', () => ({
  apps: { length: 0 },
  initializeApp: jest.fn(),
}));
jest.mock('firebase-functions', () => ({
  logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));
jest.mock('googleapis', () => ({
  google: { sheets: jest.fn().mockReturnValue(mockSheets) },
}));
```

`@google/genai` is mocked the same way — replace the exported class with a
factory that returns a stub.

**`@ts-nocheck` is acceptable at the top of test files** when mock shapes
don't line up with the real types. It's explicitly excluded from the
TypeScript "no `@ts-ignore`" rule for source files.

---

## Mocking `src/config.ts`

Tests mock `../src/config` to stub secrets (`.value()` returns a fixed
string) and constants. Real pattern from `functions/tests/app.test.ts`:

```typescript
jest.mock('../src/config', () => ({
  GEMINI_API_KEY: { value: () => 'test-gemini-key' },
  REVENUECAT_WEBHOOK_SECRET: { value: () => 'test-rc-secret' },
  FIREBASE_REGION: 'southamerica-east1',
}));
```

The mocked module must re-export **every** named export the subject imports
from `config.ts`, or the test will crash with `undefined is not a function`
at runtime.

---

## Testing `requireAuth` + Express routes

Use `supertest` to exercise the real Express app against mocked Firebase
clients. Pattern from `functions/tests/app.test.ts`:

```typescript
import request from 'supertest';

// (All the jest.mock() calls from above ran first.)

describe('requireAuth middleware', () => {
  beforeEach(() => {
    jest.resetModules();
    // Re-apply mocks after resetModules so each test gets a clean state
    jest.mock('firebase-admin/auth', () => ({ getAuth: jest.fn() }));
    // … (repeat the other mocks)
  });

  it('returns 401 with empty body when Authorization header is missing', async () => {
    const firestoreMock = buildFirestoreMock({
      users: { 'admin@example.com': { uid: null, isAdmin: true, displayName: null, avatarUrl: null } },
    });
    const { getFirestore: mockGetFirestore } = require('firebase-admin/firestore');
    const { getAuth: mockGetAuth } = require('firebase-admin/auth');
    mockGetFirestore.mockReturnValue(firestoreMock);
    mockGetAuth.mockReturnValue(buildAuthMock('reject'));

    const { app } = require('../src/app');
    const res = await request(app).get('/api/auth/check');

    expect(res.status).toBe(401);
    expect(res.text).toBe('');  // Empty body — no enumeration surface
  });
});
```

Key points:
- `jest.resetModules()` + re-mocking in `beforeEach` forces a fresh import
  of the subject per test. Without it, module-level state leaks between tests.
- Use `require()` (not `import`) inside the test body when you need the
  fresh-after-reset instance.
- Assert `res.text === ''` on 401 responses. The empty body is a contract —
  see `.claude/rules/functions/architecture.md`.

---

## Testing services that throw

Services let SDK errors propagate. Assert with `rejects.toThrow()`:

```typescript
test('throws when bucket.save fails', async () => {
  mockSave.mockRejectedValueOnce(new Error('quota exceeded'));

  await expect(
    uploadReceiptToStorage(Buffer.from('x'), 'image/jpeg', 'f.jpg', '2026-04'),
  ).rejects.toThrow('quota exceeded');
});
```

Do not catch inside the test and `expect(e).toBeDefined()` — that swallows
the failure mode and passes even if the wrong error is thrown.

---

## Assertions & naming

- **Arrange / Act / Assert** layout, with blank lines between phases when the
  test is longer than a few lines.
- **Test names describe behavior, not mechanics**:

```typescript
// ✅ Good
it('returns 401 with empty body when Authorization header is missing', ...);

// ❌ Bad
it('test1', ...);
it('works', ...);
```

- Use `toBe` for primitives, `toEqual` for objects, `toHaveBeenCalledWith`
  for mock call verification.
- When asserting object shapes partially, use
  `expect.objectContaining({ … })` — locks the fields you care about without
  failing on unrelated additions.

---

## State between tests

```typescript
beforeEach(() => {
  jest.clearAllMocks();  // Reset call history; keep implementations
  // Re-stub default return values if your test needs them
  mockSave.mockResolvedValue(undefined);
});
```

- `jest.clearAllMocks()` — clears `.mock.calls` and `.mock.results` but
  keeps mock implementations. Almost always what you want.
- `jest.resetAllMocks()` — also clears implementations. Only when you're
  swapping mocks between tests in the same suite.
- `jest.restoreAllMocks()` — only meaningful if you used `jest.spyOn()`
  (rare in this codebase).

---

## Rules

1. `maxWorkers: 1` + `workerThreads: false` — never override.
2. `jest.mock(...)` calls go **before** the `import` of the subject.
3. Mock at the module boundary of the SDK (`firebase-admin/auth`,
   `firebase-admin/firestore`, `firebase-admin/storage`, `googleapis`,
   `@google/genai`) — not at individual function call sites.
4. Mock `firebase-functions` → `logger` so tests don't try to write logs.
5. When mocking `../src/config`, re-export **every** named import the
   subject uses, or the test crashes at runtime.
6. Use `supertest` against the real Express `app` for route + middleware
   tests. Call `jest.resetModules()` + re-mock in `beforeEach`.
7. `@ts-nocheck` is acceptable at the top of test files. It stays out of
   `src/`.
8. Services that throw are tested with `await expect(...).rejects.toThrow()`
   — never a try/catch in the test.
9. Test names describe behavior. `it('test1')` is a bug.
10. `jest.clearAllMocks()` in `beforeEach` is the default; reach for
    `resetAllMocks` only with a concrete reason.
11. **≥80% line coverage per file** — not just overall. Check with Jest's
    `--coverage --coverageReporters=text` to see the per-file table. Every
    new `src/` file must individually meet the threshold; a high module
    average does not excuse a low-coverage file.
