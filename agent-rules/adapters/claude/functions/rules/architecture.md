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

```bash
# Each command should return zero matches (the listed file is the only caller).
# Run from repo root.

# Only geminiService.ts may import @google/genai
grep -r "'@google/genai'" functions/src --include="*.ts" | grep -v geminiService

# Only firestoreService.ts and webhookService.ts may import firebase-admin/firestore
grep -r "'firebase-admin/firestore'" functions/src --include="*.ts" | grep -v firestoreService | grep -v webhookService

# Only messagingService.ts may import firebase-admin/messaging
grep -r "'firebase-admin/messaging'" functions/src --include="*.ts" | grep -v messagingService

# Only storageService.ts may import firebase-admin/storage (stub in v1 — expected: zero other matches)
grep -r "'firebase-admin/storage'" functions/src --include="*.ts" | grep -v storageService
```

---

## Handler registration (`functions/index.ts`)

`index.ts` contains only handler exports. The Express app lives in
`src/app.ts`; the handler wraps it and declares the secrets v2 will mount at
runtime.

Real pattern from `functions/index.ts`:

```typescript
import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { FIREBASE_REGION, GEMINI_API_KEY, REVENUECAT_WEBHOOK_SECRET } from './src/config';
import { app } from './src/app';

if (!admin.apps.length) admin.initializeApp();

export const api = onRequest(
  {
    region: FIREBASE_REGION,
    secrets: [GEMINI_API_KEY, REVENUECAT_WEBHOOK_SECRET],
  },
  app,
);
```

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

```typescript
export interface AuthenticatedRequest extends Request {
  user?: { uid: string; email: string | null; isAdmin: boolean };
}

async function requireAuth(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).end();
    return;
  }

  const idToken = authHeader.slice('Bearer '.length);
  let decoded: admin.auth.DecodedIdToken;
  try {
    decoded = await getAuth().verifyIdToken(idToken);
  } catch {
    res.status(401).end();
    return;
  }

  await upsertUserProfile(decoded);  // writes to users/{uid}
  req.user = { uid: decoded.uid, email: decoded.email ?? null, isAdmin: false };
  next();
}

const app = express();
app.use(express.json());
app.use(requireAuth as express.RequestHandler);
```

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

```typescript
// src/config.ts
import { defineSecret } from 'firebase-functions/params';

export const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
export const REVENUECAT_WEBHOOK_SECRET = defineSecret('REVENUECAT_WEBHOOK_SECRET');
```

Read `secret.value()` **inside** a handler or service function — never at
module top level, because the value isn't bound until the v2 handler
registers the secret:

```typescript
// ✅ Good — read inside the function
export function getGeminiApiKey(): string {
  return GEMINI_API_KEY.value();
}

// ❌ Bad — evaluated at module load; secret isn't bound yet
const API_KEY = GEMINI_API_KEY.value();
```

### Non-sensitive env config (`functions/.env`)

For values that are public-ish but environment-specific (spreadsheet IDs,
region overrides, bucket overrides), use `process.env` wrapped in a getter:

```typescript
// src/config.ts
export const getSpreadsheetId = (): string =>
  process.env.SPREADSHEET_ID ?? '';

export function getStorageBucketName(): string | undefined {
  const v = process.env.STORAGE_BUCKET;
  return v && v.trim() ? v.trim() : undefined;
}
```

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

```typescript
export async function getFlavorPrompts(flavor: string): Promise<FlavorPrompts> {
  const doc = await getFirestore().collection('systemPrompts').doc(flavor).get();
  if (!doc.exists) {
    return { chatPrompt: `You are a ${flavor} spiritual guide.`, sermonPrompt: `Write a short ${flavor} devotional for today.` };
  }
  const data = doc.data() as Partial<FlavorPrompts>;
  return {
    chatPrompt: data.chatPrompt ?? `You are a ${flavor} spiritual guide.`,
    sermonPrompt: data.sermonPrompt ?? `Write a short ${flavor} devotional for today.`,
  };
}
```

Caller pattern (fatal — fail the request):

```typescript
let prompts: FlavorPrompts;
try {
  prompts = await getFlavorPrompts(flavor);
} catch (e) {
  logger.error('Failed to read system prompt', { flavor, error: String(e) });
  res.status(500).json({ error: 'Internal server error' });
  return;
}
```

### Logging

Use `logger` from `firebase-functions` (structured logs — visible in
Cloud Run → Logs with severity and payload). Do not use `console.log` in
Functions source.

```typescript
import { logger } from 'firebase-functions';

logger.info('bootstrapWhitelist: whitelist created', {
  adminCount: adminEmails.length,
  userCount: userEmails.length,
});

logger.error('uploadReceipt failed', { error: String(e), chatId });
```

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
