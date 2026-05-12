# System Prompt — Somnio Coding Standards (Functions)

You are an expert software engineer. Follow these coding standards precisely when generating code.

> Applies to: `functions/**/*.ts`
# Firebase Cloud Functions — Architecture

How to structure, register, and secure code under `functions/`. Runs on
Firebase Cloud Functions v2 (Node 22) in region `southamerica-east1`, exposing
a single Express app behind one `onRequest` handler.

General TypeScript conventions — naming, types, error handling — live in
`.claude/rules/typescript/best-practices.md`. This file covers only what's
specific to Firebase Functions.

---

## Stack

- **Runtime:** Node 22 on Firebase Cloud Functions v2 (`firebase-functions` ≥ 7).
- **HTTP framework:** Express 5 mounted behind `onRequest`.
- **Auth:** Firebase Auth (anonymous + linked) verified with Admin SDK.
- **Data:** Firestore (user profiles, usage, sermons, system prompts, calendar events), Gemini via `@google/genai` (chat replies + sermon generation), FCM via `firebase-admin/messaging` (push notifications).
- **Region:** `southamerica-east1` — declared once in `config.ts` as `FIREBASE_REGION` and re-used at every handler registration.

---

## Single-responsibility modules

Every file under `functions/src/` owns **one** external SDK or **one**
coherent domain concern. Non-negotiable:

| File | Sole responsibility |
|---|---|
| `index.ts` (repo root) | Handler registration only — no business logic |
| `src/app.ts` | Express app, `requireAuth` middleware |
| `src/config.ts` | Secrets (`defineSecret`), env accessors, constants |
| `src/middleware/auth.ts` | Firebase token verification, user upsert, `req.user` attachment |
| `src/routes/chat.ts` | `POST /api/chat` route handler |
| `src/routes/sermon.ts` | `GET /api/sermon/:date` route handler |
| `src/services/firestoreService.ts` | **Only** file that imports `firebase-admin/firestore` |
| `src/services/geminiService.ts` | **Only** file that imports `@google/genai` |
| `src/services/messagingService.ts` | **Only** file that imports `firebase-admin/messaging` |
| `src/services/storageService.ts` | **Only** file that imports `firebase-admin/storage` (stub v1 — pre-registered boundary) |
| `src/services/webhookService.ts` | RevenueCat webhook processing — **exception:** also imports `firebase-admin/firestore` directly (sole writer of `users/{uid}.tier`; this exception is documented and accounted for in CI boundary checks) |
| `src/services/promptService.ts` | Reads system prompts from Firestore `systemPrompts/{flavor}`; no external SDK |
| `src/scheduledJobs/dailySermon.ts` | Daily sermon generation and FCM push, one export per flavor |

If new business logic doesn't fit any file above, create a new one with a
single responsibility. Do not widen an existing module's scope.

Verify boundaries are intact:

---

## Handler registration (`functions/index.ts`)

`index.ts` contains only handler exports. The Express app lives in
`src/app.ts`; the handler wraps it and declares the secrets v2 will mount at
runtime.

Real pattern from `functions/index.ts`:

Rules:
- One `onRequest` handler per HTTP surface. All REST routes live under
  the single `api` export, routed internally by Express.
- The `secrets: [...]` array must list **every** secret the handler needs at
  runtime. Missing entries cause undefined `.value()` at cold start.
- Scheduled jobs use `onSchedule` from `firebase-functions/v2/scheduler` and
  follow the same shape.
- Never call Firebase Admin at module top level in `src/` files — always
  inside functions, because initialization must happen after
  `admin.initializeApp()` in `index.ts`. `app.ts` guards with
  `if (!admin.apps.length)` for when it runs outside Functions (tests).

---

## Express + `requireAuth` middleware

Every HTTP request goes through `requireAuth` in `src/middleware/auth.ts` before
any route handler runs. It:

1. Extracts the `Authorization: Bearer <idToken>` header.
2. Verifies the ID token with `admin.auth().verifyIdToken()` (validates
   project binding, signature, expiry).
3. **Consumer app — no email whitelist.** Any valid Firebase UID is accepted
   (anonymous or linked). `isAdmin` is always `false` for consumer accounts.
4. Rejects with **bare `res.status(401).end()` — no body**. Any leaked
   detail becomes an enumeration surface.
5. On first successful login, upserts `uid`, `displayName`, and `avatarUrl`
   to the user profile document at `users/{uid}` in Firestore.
6. Attaches `req.user = { uid, email, isAdmin }` and calls `next()`.

Shape (from `src/middleware/auth.ts`):

Rules:
- `app.use(requireAuth)` is mounted **once, globally**. Never add a route
  that bypasses it. Public endpoints (if ever needed) get their own
  `onRequest` handler, outside this app.
- The rejection body is empty. Do not add JSON error payloads to 401
  responses — enumeration risk.
- Auth logic lives in `src/middleware/auth.ts`. Other files trust that
  `req.user` is already populated.

---

## Secrets & env config

### Secrets (Google Secret Manager)

Declare every secret with `defineSecret()` in `src/config.ts`:

Read `secret.value()` **inside** a handler or service function — never at
module top level, because the value isn't bound until the v2 handler
registers the secret:

### Non-sensitive env config (`functions/.env`)

For values that are public-ish but environment-specific (spreadsheet IDs,
region overrides, bucket overrides), use `process.env` wrapped in a getter:

- `functions/.env` must be listed in `.gitignore`.
- Never use `functions.config()` — deprecated in v2.
- Never hardcode a spreadsheet ID, bucket name, project ID, or admin email in
  source. Tests pass literals through mocks; production pulls from env /
  secrets.

---

## Error handling

### Services throw; callers catch

Service-layer functions (`firestoreService`, `geminiService`, `messagingService`,
…) **do not** wrap their own body in try/catch. They let the underlying SDK
error propagate. The caller — usually a route handler in `src/routes/` or a
scheduled job — decides whether to fail the request, fall back to a default, or
log and continue.

Example (from `src/services/promptService.ts`):

Caller pattern (fatal — fail the request):

### Logging

Use `logger` from `firebase-functions` (structured logs — visible in
Cloud Run → Logs with severity and payload). Do not use `console.log` in
Functions source.

Never log:
- ID tokens or parts of them.
- Raw request headers.
- Full user objects. Log the email or uid only.
- Secret values (the linter can't catch this — be deliberate).

---

## Firestore patterns

- **Dedup via transaction** (`security.ts::isDuplicate`): each update ID
  gets an idempotency doc written transactionally. Never read-then-write
  non-transactionally for dedup.
- **Cache with TTL**: caches (OCR results, NL responses) store an `expiresAt`
  timestamp. Readers check it at read time — do not rely only on a Firestore
  TTL policy for correctness.
- **Client rules are `deny all`.** Authenticated whitelist members can read
  their own whitelist entry; everything else goes through Functions.

---

## What NOT to Do

- ❌ Do not import `@google/genai`, `firebase-admin/firestore`, `firebase-admin/storage`, or `firebase-admin/messaging` outside their owning service file. **Exception:** `webhookService.ts` also imports `firebase-admin/firestore` — this is the only documented exception; the CI boundary check excludes both `firestoreService` and `webhookService` from this grep.
- ❌ Do not bypass `requireAuth`. Any "internal" endpoint gets auth too.
- ❌ Do not read `secret.value()` at module load. Wrap in a function.
- ❌ Do not use `functions.config()` — deprecated in v2.
- ❌ Do not put business logic in `index.ts`. It routes only.
- ❌ Do not initialize `admin.firestore()` / `admin.auth()` at module level.
  Call the getters (`getFirestore()`, `getAuth()`) inside functions.
- ❌ Do not respond to failed auth with a body. `res.status(401).end()` —
  nothing else.

---

## Rules

1. `functions/index.ts` contains handler exports only — never business logic.
2. All HTTP traffic flows through Express + `requireAuth` in `src/app.ts`.
3. One external SDK per file. Verify with `grep` before merging.
4. Secrets via `defineSecret()`, read via `.value()` **inside** functions.
5. Non-sensitive env via `process.env` wrapped in a getter.
6. Services throw; callers decide to fail, fallback, or log-and-continue.
7. Log with `logger` from `firebase-functions` — never `console.log`.
8. Failed auth returns `401` with empty body. No enumeration surface.
9. Never copy patterns from `telegram-deprecated/`.
10. Deploy region is `FIREBASE_REGION` from `config.ts` — re-use, don't
    hardcode.

---

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

---

## Jest config

Real `functions/tests/jest.config.js`:

**`maxWorkers: 1` and `workerThreads: false` are mandatory.** Parallel
execution causes intermittent failures when multiple workers each load
`firebase-admin` and compete for cached modules. Do not override these for
"speed" — the flakiness isn't worth it.

---

## File layout

One test file per source file; mirror the name:

Keep tests flat. No nested `tests/` folders. One suite per module.

---

## Mocking Firebase SDKs

The single most important rule: **mock before importing the module under
test.** `jest.mock()` is hoisted to the top of the file at compile time, but
the modules being mocked must be registered before the `import` of the
subject pulls them in transitively.

Real pattern from `functions/tests/storageService.test.ts`:

Standard mock targets for the SDKs you'll see:

`@google/genai` is mocked the same way — replace the exported class with a
factory that returns a stub.

**`@ts-nocheck` is acceptable at the top of test files** when mock shapes
don't line up with the real types. It's explicitly excluded from the
TypeScript "no `@ts-ignore`" rule for source files.

---

## Mocking `src/config.ts`

Tests mock `../src/config` to stub secrets (`.value()` returns a fixed
string) and constants. Real pattern from `functions/tests/app.test.ts`:

The mocked module must re-export **every** named export the subject imports
from `config.ts`, or the test will crash with `undefined is not a function`
at runtime.

---

## Testing `requireAuth` + Express routes

Use `supertest` to exercise the real Express app against mocked Firebase
clients. Pattern from `functions/tests/app.test.ts`:

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

Do not catch inside the test and `expect(e).toBeDefined()` — that swallows
the failure mode and passes even if the wrong error is thrown.

---

## Assertions & naming

- **Arrange / Act / Assert** layout, with blank lines between phases when the
  test is longer than a few lines.
- **Test names describe behavior, not mechanics**:

- Use `toBe` for primitives, `toEqual` for objects, `toHaveBeenCalledWith`
  for mock call verification.
- When asserting object shapes partially, use
  `expect.objectContaining({ … })` — locks the fields you care about without
  failing on unrelated additions.

---

## State between tests

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

---
