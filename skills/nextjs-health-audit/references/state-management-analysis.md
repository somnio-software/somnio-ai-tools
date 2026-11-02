# Next.js Data & State Management Analysis

> Analyze how the Next.js app fetches, caches, mutates and holds data: the server/client state boundary, React Server Component data fetching, Server Actions, the caching model (Cache Components with `use cache`, or the previous fetch-cache model), revalidation, and client state libraries. Feeds the report's **State Management** section.

---

Goal: Evaluate whether data lives on the right side of the
server/client boundary, whether caching and revalidation are
deliberate, and whether client state tools are used only for real
client state.

Verify every API against the docs for the installed Next.js version
before citing it (caching APIs changed across majors):
- With Cache Components: https://nextjs.org/docs/app/getting-started/caching
  and https://nextjs.org/docs/app/getting-started/revalidating
- Without Cache Components: https://nextjs.org/docs/app/guides/caching-without-cache-components

Run greps from the app directory over `SRC` (the existing source roots
among `app src components lib server actions pages`), excluding tests.

ANALYSIS TARGETS:

1. **Caching model in use**:
   - `cacheComponents: true` in `next.config.*` → Cache Components model
     (caching is opt-in with `'use cache'`; runtime data must sit behind
     `<Suspense>`; Partial Prerendering is the default rendering)
   - `partialPrefetching` set explicitly (the docs ask for it to be set
     when Cache Components is on)
   - Otherwise → previous model: route segment config
     (`export const dynamic`, `revalidate`, `fetchCache`), `fetch`
     options (`cache`, `next: { revalidate, tags }`),
     `unstable_cache`
   - Pages Router data fetching: `getServerSideProps`,
     `getStaticProps` (+ `revalidate`), `getStaticPaths`

2. **Server data fetching (RSC)**:
   ```bash
   grep -rlE "^['\"]use cache" $SRC | wc -l                       # 'use cache' (incl. ': private' / ': remote')
   grep -rnE "cacheLife\(|cacheTag\(" $SRC | wc -l
   grep -rnE "export const (dynamic|revalidate|fetchCache)" $SRC | wc -l
   grep -rnE "unstable_cache\(" $SRC | wc -l
   grep -rnE "next:\s*\{\s*(revalidate|tags)" $SRC | wc -l
   grep -rnE "getServerSideProps|getStaticProps" $SRC | wc -l
   ```
   - Data fetched in async Server Components or a server data layer
     (`lib/data`, `server/queries`) vs fetched in Client Components with
     `useEffect`
   - `React.cache` for request-level de-duplication of non-`fetch` data
     access
   - Waterfalls: sequential `await`s of independent data at the top of a
     page/layout (should be parallel or pushed into `<Suspense>`
     children)
   - With Cache Components: every `'use cache'` paired with `cacheLife`;
     runtime APIs (`cookies()`, `headers()`, `searchParams`) read inside
     `<Suspense>`; `'use cache: private'` / `'use cache: remote'` used
     deliberately; `export const instant = false` opt-outs listed

3. **Mutations — Server Actions and Route Handlers**:
   ```bash
   grep -rlE "^['\"]use server['\"]" $SRC | wc -l                 # Server Action files
   grep -rnE "['\"]use server['\"]" $SRC | wc -l                   # incl. inline actions
   grep -rnE "revalidatePath\(|revalidateTag\(|updateTag\(|refresh\(" $SRC | wc -l
   grep -rnE "useActionState|useFormStatus|useOptimistic" $SRC | wc -l
   ```
   - Mutations go through Server Actions (or Route Handlers for external
     clients/webhooks), not client `fetch` to internal API routes that
     only the app itself calls
   - Every mutation revalidates what it changed: `updateTag` (Server
     Actions only, read-your-own-writes), `revalidateTag(tag, profile)`
     (Server Actions and Route Handlers, stale-while-revalidate),
     `revalidatePath` (coarser — prefer tags). A mutation with no
     revalidation call is a stale-data bug candidate
   - Input validation in actions (`zod`, `valibot`) and authorization
     inside each action (not only in Proxy) — record presence; depth is
     for `nextjs-security-audit`
   - Pending/optimistic UI via `useActionState`, `useFormStatus`,
     `useOptimistic`

4. **Server/client boundary**:
   - Props passed from Server to Client Components are serializable and
     minimal (no whole DB records with secret fields) — sample 3-5
     `'use client'` components that receive server data
   - `server-only` guarding data-access modules; `taint` APIs if enabled
   - Context providers (`createContext`) wrapped in a small client
     `providers.tsx` at the root, not turning layouts client-side

5. **Client state libraries** (`package.json` + usage):
   - `zustand`, `@reduxjs/toolkit` + `react-redux`, `jotai`, `recoil`
     (unmaintained), `valtio`, `xstate`
   - In the App Router, global stores must be created per request (not
     module-level singletons shared between users on the server) — check
     the store creation pattern (a `StoreProvider` using `useRef`/
     `useState`, or a factory)
   - Context API usage count and purpose (theme/auth/locale OK; server
     data in Context is an anti-pattern)
   - URL as state: `useSearchParams`/`searchParams` for filters and
     pagination (a good pattern) — `useSearchParams` in a client
     component needs a `<Suspense>` boundary

6. **Client server-state libraries**:
   - `@tanstack/react-query`, `swr`, `@apollo/client`, `urql`,
     `@trpc/react-query`
   - With RSC, a client cache library is justified for client-driven
     data (polling, infinite scroll, optimistic client updates). Flag it
     when it duplicates data already fetched in Server Components, or when
     queries hydrate without `HydrationBoundary` / initial data and
     re-fetch on mount
   - `QueryClient` created per request on the server / once per browser
     session on the client; `staleTime` configured

7. **Anti-Pattern Detection**:
   - Manual fetch state in Client Components:
     ```bash
     grep -rlE "useEffect" $SRC --include='*.tsx' | xargs grep -lE "fetch\(|axios" 2>/dev/null | wc -l
     ```
   - Client-side fetch to the app's own Route Handlers for data a Server
     Component could read directly
   - Module-level mutable state in server code (shared across requests)
   - Prop drilling through 3+ levels; global stores holding purely local
     UI state

OUTPUT FORMAT:

Provide structured analysis:
- Router / data model: [App Router RSC / Pages Router (getServerSideProps/getStaticProps) / Mixed]
- Caching model: [Cache Components (`use cache`) / previous fetch-cache model / Pages Router ISR / none deliberate]
- `use cache` directives: [N] (with cacheLife: [N]; private: [N]; remote: [N]); cacheTag calls: [N]
- Route segment config exports (dynamic/revalidate/fetchCache): [N]
- Server Action files: [N]; inline actions: [N]
- Revalidation calls: updateTag [N], revalidateTag [N], revalidatePath [N]
- Mutations without revalidation: [list or none found]
- Client state approach: [none needed/Context/Zustand/Redux/Jotai/Mixed] (per-request store: [Yes/No/N/A])
- Client server-state library: [TanStack Query/SWR/Apollo/tRPC/None] (justified: [Yes/Partially/No])
- Context providers count: [XX]
- Manual client fetch patterns: [XX]
- Anti-patterns found: [list]
- Risks identified
- Recommendations

SCORING GUIDANCE (State Management section):

Strong (85-100):
- Server data read in Server Components / a server data layer; client
  libraries only for genuinely client-driven state
- One deliberate caching model, with explicit lifetimes (`cacheLife`)
  or revalidation, and tags revalidated after every mutation
- Mutations through Server Actions with validation and pending UI
- No per-user state shared across requests

Fair (70-84):
- Mostly server-side data, but some client `useEffect` fetching or
  duplicated client caches
- Caching implicit or inconsistent; some mutations without revalidation

Weak (0-69):
- Data fetched client-side throughout an App Router app
- No deliberate caching/revalidation, stale data after mutations
- Global stores as module-level singletons on the server, or server data held in Context
