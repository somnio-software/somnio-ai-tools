# Next.js Data Fetching & Caching Analysis

> Analyze where and how data is fetched, parallel fetching versus waterfalls, Suspense streaming, and the caching and revalidation model of the INSTALLED Next.js version.

---

Goal: Evaluate data access patterns and whether caching and revalidation are
used the way the documentation for the installed version describes.

**The caching model changed across Next.js majors.** Defaults for `fetch`
caching, the set of caching APIs, and how revalidation works differ between
releases, and a newer opt-in model (Cache Components, with `use cache`,
`cacheLife` and `cacheTag`) coexists with the previous one (fetch options,
`unstable_cache`, route segment config). Do NOT judge this dimension from
memory: detect the version, detect which model the project uses, and read the
matching docs before writing a single finding.

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

CACHING MODEL DETECTION (after version resolution):
1. Read `next.config.*` for the caching flags the installed docs describe
   (for example `cacheComponents`, `partialPrefetching`, or experimental
   predecessors — use only names the matching docs list).
2. Grep the source for each model's markers:
   - Cache Components markers: `'use cache'` (and its documented variants),
     `cacheLife(`, `cacheTag(`, `updateTag(`.
   - Previous-model markers: `fetch(` options `cache:` / `next: { revalidate`
     / `next: { tags`, `unstable_cache(`, route segment exports
     (`export const revalidate`, `dynamic`, `fetchCache`).
   - Both models: `revalidatePath(`, `revalidateTag(`, React `cache(`.
3. State the model in use: "Cache Components", "Previous model",
   "Pages Router data fetching", or "Mixed" — and read the docs for THAT model:
   - Cache Components: Getting Started > Caching and Revalidating, API Reference
     for `use cache`, `cacheLife`, `cacheTag`, `updateTag`, `revalidateTag`,
     `revalidatePath`, and the `cacheComponents` config page.
   - Previous model (newer docs): Guides > "Caching and Revalidating (Previous
     Model)". Older majors: that major's own Caching page under its versioned
     prefix — its `fetch` defaults may differ from newer releases.
   - Pages Router: that version's Pages Router data-fetching pages.
4. Flag APIs that the installed version does not document (e.g. a model's
   directive used without its enabling flag, or a removed/renamed API) as
   High, quoting the docs page that proves it.

DOCS TO READ FOR THIS DIMENSION (in addition to the model pages above):
- Getting Started: Fetching Data (parallel fetching, streaming, React `cache`)
- Guides: Streaming, and Instant Navigation where the installed version has it

COMPLEMENTARY STANDARDS (read when present, never required):
- Somnio Next.js rules: every `.md` under `agent-rules/rules/nextjs/` in the
  local repo. Skip when the directory is absent; do not guess remote URLs.
- Somnio React state-management rule (client-side server-state libraries):
  local: `agent-rules/rules/react/state-management.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/react/state-management.md

ANALYSIS TARGETS:
1.  **Where Data Is Fetched**:
    *   Server data should be read in Server Components, Server Functions or a
        server-only data access layer. Flag `useEffect` + `fetch` (or a client
        data library) in Client Components for data that is available at
        render time on the server and is not user-interaction driven.
    *   Flag Route Handlers called from Server Components of the same app
        (an extra network hop the docs advise against when the logic can be
        called directly — verify the guidance in the installed docs).
    *   Check database and SDK access is centralized (data access layer) rather
        than scattered through components.

2.  **Waterfalls vs Parallel Fetching**:
    *   Flag sequential `await`s of independent requests in the same component
        or layout; recommend starting them together (`Promise.all` or the
        pattern the installed docs show).
    *   Flag parent/child waterfalls where a layout awaits data that only a
        deep child needs.
    *   Check request deduplication: repeated reads of the same non-`fetch`
        source within one render should go through React `cache` (or the
        documented equivalent).

3.  **Streaming & Suspense**:
    *   Slow or request-time data should sit behind `<Suspense>` or a
        `loading.*` boundary with a meaningful fallback.
    *   Flag a single top-level boundary that blocks the whole page when
        independent sections could stream separately.
    *   Under Cache Components: flag uncached or runtime-API reads (cookies,
        headers, searchParams, params) outside a `<Suspense>` boundary when
        the installed docs report them as blocking.

4.  **Caching & Revalidation (per detected model)**:
    *   Every cached read has an explicit, intentional lifetime as the
        installed docs recommend (e.g. a `cacheLife` profile with `use cache`,
        or `revalidate` / tags in the previous model).
    *   Flag user-specific or request-specific data cached in a shared cache
        (a correctness and privacy bug — referral to `nextjs-security-audit`
        if sensitive).
    *   Flag reliance on implicit defaults whose value changed across majors;
        state the default for the installed version with the docs quote.
    *   Prefer tag-based revalidation over broad path revalidation where the
        docs recommend it; flag `revalidatePath('/')`-style over-invalidation.
    *   Flag `export const dynamic = 'force-dynamic'` (or `revalidate = 0`) on
        routes that have no request-time data, and blanket opt-outs applied
        to a root layout.

OUTPUT FORMAT:
*   **Installed version / Docs source / Caching model**: as resolved above.
*   **Overview**: number of data-reading modules, waterfalls found, Suspense
    boundaries, caching APIs in use with counts.
*   **Score**: 0-100 integer with label (Strong 85-100 / Fair 70-84 / Weak 0-69).
    Start at 100 and deduct per violation: Critical -15, High -8, Medium -4,
    Low -1 (floor 0).
*   **Violations**: list specific file paths and lines.
    *   Format: `[Type Issue] path/to/file.ts:line — description (docs: <page>)`
*   **Compliance**: good examples found in the codebase.
*   **Recommendations**: specific refactoring suggestions per violation.
*   **Recommended follow-ups** (only when the docs for the installed version
    document the feature, and only those whose prerequisites the project
    meets): the official Next.js agent skills from
    https://github.com/vercel/next.js/tree/canary/skills, installed with
    `npx skills add vercel/next.js --skill <name>`:
    *   `next-cache-components-adoption` — project not on Cache Components yet.
    *   `next-cache-components-optimizer` — Cache Components adopted; static
        shell of a key route is thin.
    *   `next-partial-prefetching-adoption` / `next-partial-prefetching-optimizer`
        — Cache Components adopted and prefetching is in scope.
