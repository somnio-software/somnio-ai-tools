# System Prompt — Somnio Coding Standards (Typescript)

You are an expert software engineer. Follow these coding standards precisely when generating code.

### General guidelines for TypeScript code in this repo.
# TypeScript Best Practices

These rules apply to every `.ts` file in the repo (Firebase Functions, build
scripts, utilities). Firebase-specific conventions — handler registration,
module boundaries, secrets — live in `.claude/rules/functions/`.

Assume the reader knows JavaScript and is comfortable with static types. Do
not restate basic language mechanics.

---

## tsconfig standards

Canonical baseline used by `functions/tsconfig.json`. Mirror these flags in any
new TS package unless the framework overrides them:

Why these flags:
- `strict: true` turns on `strictNullChecks`, `noImplicitAny`, and the rest —
  non-negotiable.
- `noImplicitReturns` forces every branch of a function to return a value.
  Catches fallthrough bugs.
- `noUnusedLocals` makes dead variables a compile error. Remove them instead
  of prefixing `_`.
- `esModuleInterop` lets you write `import * as admin from 'firebase-admin'`
  against CommonJS packages.
- `skipLibCheck` skips type-checking of `node_modules/**/*.d.ts` — faster
  builds, and we can't fix upstream types anyway.

Never downgrade `strict` to bypass an error. Fix the type.

---

## Naming

- **Functions, variables, parameters:** `camelCase`. Verb-first for functions:
  `writeExpenseToSheet()`, `parseExpenseMessage()`.
- **Constants (module-level, immutable):** `SCREAMING_SNAKE_CASE`.
- **Types, interfaces, classes, enums:** `PascalCase`.
- **Files:** `camelCase.ts`. Barrel files (`index.ts`) re-export only.
- **Secret/env keys:** `SCREAMING_SNAKE_CASE` strings — match the name on the
  secret in Google Secret Manager / `.env`.
- **Identifiers in code are always English.** User-facing strings (Telegram
  replies, sheet headers, UI labels) may be in Spanish, but their variable
  names must still be English:

---

## Imports & modules

Use ES module syntax (`import`/`export`) even when the compiled output is
CommonJS. Never write `require()` in source.

Grouping: built-in → third-party → local, separated by a blank line.

Import only what you use. Prefer named imports over `import * as X` unless the
library exposes a large surface you actually consume (e.g.
`import * as admin from 'firebase-admin'`).

Use relative paths for local imports (`./config`, `../utils`). No path
aliases unless they're set up in `tsconfig.json`.

---

## Types

- **`interface` for object shapes** that are part of a public contract
  (function parameters, return types, repository models). They extend cleanly
  and produce better error messages.
- **`type` for unions, tuples, conditional types, aliases.**
- **Never `any` without a one-line comment justifying it.** At external
  boundaries (`JSON.parse`, `req.body`, library escape hatches), use `unknown`
  and narrow:

- **Type guards** are functions that narrow `unknown`/union types. Name them
  `isX()` and return `value is X`:

- **No enums for string unions.** Use a literal union type instead — it
  plays better with JSON and erases at runtime:

---

## Nullables & optionals

With `strict: true`, `null` and `undefined` are never assignable to non-null
types. Use them deliberately:

- Optional object fields: `field?: string` — the field may be absent or
  `undefined`.
- Explicitly nullable fields (present but can hold null): `field: string | null`.
- Defaults via nullish coalescing:

Avoid the non-null assertion `!` unless you add a comment explaining why the
value is guaranteed non-null. Prefer narrowing, optional chaining, or
explicit checks.

---

## Async / await

Always `async`/`await`. No `.then()` chains in source code.

Parallelize independent calls with `Promise.all`. Keep sequential only when
each step depends on the previous one:

Every `await` in a non-throwing path must be reachable from a caller that
either handles the rejection or intentionally lets it propagate (see error
handling below).

---

## Error handling

- **Throw `Error` subclasses with descriptive messages.** Define a custom
  class for domain errors you want callers to distinguish:

- **Narrow `unknown` in catches before accessing `.message`.** In strict
  mode, the catch variable is `unknown`:

- **Services throw; callers decide what to do.** Service functions (pure
  data access or external API wrappers) do not wrap their own body in
  try/catch — they let errors propagate. The route handler or orchestrator
  decides whether to fail the request, fall back to a default, or log and
  continue.

---

## Logging

- In plain Node scripts, `console.log` / `console.error` are fine.
- In library code or shared utilities, **accept a logger via dependency
  injection** rather than importing a logger module at the top level — keeps
  the utility testable without mocking `console`.
- Never log secrets, ID tokens, full request headers, or PII. If a field
  might contain user email, redact or hash before logging.

Firebase Functions has its own logger convention — see
`.claude/rules/functions/architecture.md`.

---

## What NOT to Do

- ❌ Do not write `require()` in source. Use ES module `import`.
- ❌ Do not use `any` without an explanatory comment.
- ❌ Do not mutate function parameters. Build a new object and return it.
- ❌ Do not `export *` from barrel files unless the re-exported module is
  explicitly a public surface. Prefer named re-exports.
- ❌ Do not `catch (e)` and silently swallow. Log or rethrow.
- ❌ Do not use `||` for defaults when `0`, `''`, or `false` are valid
  values — use `??`.
- ❌ Do not suppress type errors with `@ts-ignore` / `@ts-nocheck` in source.
  (Tests may use `@ts-nocheck` when mocking — that's an explicit exception.)
- ❌ Do not commit commented-out code. Delete it; git remembers.

---

## Rules

1. `strict: true` is non-negotiable. Fix type errors, don't suppress them.
2. Identifiers are English. User-facing strings may be Spanish, but the
   variable holding them is still named in English.
3. `camelCase` members, `PascalCase` types, `SCREAMING_SNAKE_CASE` constants.
4. ES module `import` only — never `require()`.
5. Group imports: built-in → third-party → local, blank line between groups.
6. `interface` for object shapes, `type` for unions and aliases. No enums for
   string unions.
7. Use `unknown` + type guards at external boundaries; never `any` without a
   comment.
8. `??` for defaults; `!` only with a comment justifying the assertion.
9. `async`/`await` only. Parallelize with `Promise.all` when calls are
   independent.
10. Catch `unknown`; narrow with `instanceof Error` before reading `.message`.
11. Services throw; callers decide how to handle. No silent swallowing.
12. Never log secrets, ID tokens, or PII.

---
