# Next.js Server Actions & Route Handlers Analysis

> Analyze Server Actions (Server Functions) and Route Handlers: input validation, authorization in every entry point, revalidation after mutation, error handling, progressive enhancement and Route Handler conventions.

---

Goal: Evaluate whether every mutation and HTTP endpoint validates its input,
re-checks who is calling, keeps caches consistent after writes, and fails in
a controlled way.

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
- Getting Started: Mutating Data (Server Functions / Server Actions),
  Route Handlers
- Guides: Server Actions, Forms, Data Security (authentication and
  authorization inside actions, validating client input, return values)
- API Reference: `route` file convention, the revalidation functions the
  installed version documents (`revalidatePath`, `revalidateTag`, and
  `updateTag` where present), `redirect`, `notFound`

SCOPE BOUNDARY: this dimension checks that the PRACTICES are in place (a
validation step exists, an authorization check exists, errors are handled).
Exploitability, CSRF configuration, rate limiting and secret handling depth
belong to `nextjs-security-audit` — refer there instead of scoring them here.

If the project has no Server Actions and no Route Handlers (nor Pages Router
API routes), write `Score: N/A` with the reason and stop.

ANALYSIS TARGETS:
1.  **Inventory**:
    *   Server Actions: files with a top-level `'use server'` directive and
        functions with an inline `'use server'`. Count exported actions.
    *   Route Handlers: `route.*` files under the App Router; list the HTTP
        methods each exports. Pages Router API routes under `pages/api/`.

2.  **Input Validation**:
    *   Every action and handler parses its input (`FormData`, arguments,
        JSON body, `params`, `searchParams`) with a schema library such as
        zod (or valibot, yup, arktype) before use. Flag direct
        `formData.get(...) as string` into a database call.
    *   Flag `params` / dynamic segment values used in queries without
        validation.
    *   Validation errors are returned to the UI as structured field errors,
        not thrown as unhandled exceptions.

3.  **Authentication & Authorization in Every Entry Point**:
    *   Each Server Action re-verifies the session inside the action (or in a
        `server-only` data access layer it calls). A page-level or
        layout-level check does NOT protect actions defined or imported there.
    *   Each Route Handler that is not intentionally public checks the caller.
    *   Mutations on a specific resource check ownership/permission, not just
        "is logged in".
    *   Flag actions that depend only on proxy/middleware for auth without an
        in-action check.

4.  **Revalidation After Mutation**:
    *   After a successful write, the action revalidates the affected data
        with the API the installed docs prescribe for that caching model
        (tag-based where tags are used; path-based otherwise).
    *   Flag mutations that change data rendered elsewhere with no
        revalidation and no `redirect`/`refresh` that would show fresh data.
    *   Flag over-broad revalidation (whole-site path) when a tag exists.

5.  **Error Handling & Return Values**:
    *   Expected failures are returned as values (e.g. `{ ok: false, errors }`)
        and consumed with the form-state hook the installed docs show;
        unexpected failures propagate to an error boundary.
    *   Flag empty `catch` blocks and actions that swallow errors and return
        success.
    *   Flag actions returning full database records instead of the minimal
        fields the UI needs.
    *   Check `redirect()` is not called inside a `try` block that would catch
        it, when the installed docs say it works by throwing.

6.  **Progressive Enhancement & Usage**:
    *   Forms that call actions use `<form action={...}>` (works before
        hydration) rather than `onSubmit` + `fetch` to an internal API route,
        unless there is a documented reason.
    *   Pending and disabled states use the hooks the installed docs show.
    *   Flag Server Actions used for data READS on render (the docs position
        them for mutations); reads belong in Server Components.

7.  **Route Handler Conventions**:
    *   Named exports per HTTP method; correct status codes; `Response` /
        `NextResponse` with explicit content type for JSON.
    *   Caching behavior of `GET` handlers matches the installed version's
        docs (it differs across majors and with Cache Components).
    *   Flag Route Handlers that duplicate logic already available as a
        server-only function used by Server Components.

OUTPUT FORMAT:
*   **Installed version / Docs source**: as resolved above.
*   **Overview**: actions count, handlers count, validation coverage
    `[validated]/[total]`, authorization coverage `[checked]/[total]`,
    revalidation coverage for mutations.
*   **Score**: 0-100 integer with label (Strong 85-100 / Fair 70-84 / Weak 0-69).
    Start at 100 and deduct per violation: Critical -15, High -8, Medium -4,
    Low -1 (floor 0). A mutating action with no authorization check is
    Critical.
*   **Violations**: list specific file paths and lines.
    *   Format: `[Type Issue] path/to/actions.ts:line — description (docs: <page>)`
*   **Compliance**: good examples found in the codebase.
*   **Recommendations**: specific refactoring suggestions per violation, and
    a referral to `nextjs-security-audit` for any finding with security impact.
