---
description: "Next.js data fetching and caching — detect the caching model in use (Cache Components with 'use cache'/cacheLife/cacheTag vs the previous fetch/unstable_cache model), Suspense for request-time data, parallel fetching, React cache deduplication, and on-demand revalidation."
paths:
  - "app/**"
  - "src/app/**"
  - "src/data/**"
  - "src/lib/**"
  - "next.config.*"
---

# Next.js Data Fetching and Caching

How to fetch, cache and revalidate data in the App Router, given that Next.js has two caching models and defaults changed across majors.

## Patterns

### Detect the model before writing caching code

1. Read the installed `next` version.
2. Check `next.config.*` for `cacheComponents: true` (16+). New apps from `create-next-app` on recent 16.x enable it, together with `partialPrefetching`.
3. Use the matching docs: with Cache Components, `node_modules/next/dist/docs/01-app/01-getting-started/` caching and revalidating pages; without it, the "Caching and Revalidating (Previous Model)" guide.

| Concern | Cache Components (16+, `cacheComponents: true`) | Previous model |
|---------|-----------------------------------------------|----------------|
| Cache a function/component | `'use cache'` + `cacheLife()` | `fetch(url, { cache: 'force-cache' })`, `unstable_cache` |
| Time-based revalidation | `cacheLife('hours')` or `{ stale, revalidate, expire }` | `next: { revalidate: n }`, `export const revalidate = n` |
| Tagging | `cacheTag('posts')` | `next: { tags: ['posts'] }`, `unstable_cache(..., { tags })` |
| Request-time data | Wrap in `<Suspense>` | Route becomes dynamic; `export const dynamic` |
| Segment config `dynamic`/`revalidate`/`fetchCache` | Not used | Supported |

---

### Cache Components: `'use cache'` with an explicit lifetime

Put `'use cache'` at the top of an async function, component or file, and pair it with `cacheLife`. Arguments and captured values become part of the cache key. Tag entries you will invalidate on demand.

```ts
// src/data/products.ts
import { cacheLife, cacheTag } from 'next/cache'

export async function getProducts(categoryId: string) {
  'use cache'
  cacheLife('hours')
  cacheTag('products', `category:${categoryId}`)
  return db.product.findMany({ where: { categoryId }, select: { id: true, name: true, price: true } })
}
```

---

### Request-time data behind `<Suspense>`

With Cache Components, uncached data and runtime APIs (`cookies()`, `headers()`, `searchParams`, non-static `params`, `connection()`) must sit inside a `<Suspense>` boundary so the static shell can prerender. Without it, the dev overlay and build report a blocking-route error. Pass runtime values as arguments into cached functions when the result can be shared.

```tsx
// app/dashboard/page.tsx
import { Suspense } from 'react'
import { cookies } from 'next/headers'

export default function Page() {
  return (
    <>
      <h1>Dashboard</h1>
      <Suspense fallback={<p>Loading activity…</p>}>
        <Activity />
      </Suspense>
    </>
  )
}

async function Activity() {
  const teamId = (await cookies()).get('team')?.value
  const items = await getTeamActivity(teamId) // may itself be 'use cache' keyed by teamId
  return <ActivityList items={items} />
}
```

---

### Previous model: opt in explicitly

Without Cache Components (and on 15.x), `fetch` is not cached by default. Opt in per request and tag what you will revalidate. Use `React.cache` to deduplicate ORM calls within a render.

```ts
// src/data/posts.ts
import 'server-only'
import { cache } from 'react'

export async function getPosts() {
  const res = await fetch('https://cms.example.com/posts', {
    next: { revalidate: 3600, tags: ['posts'] },
  })
  if (!res.ok) throw new Error(`CMS responded ${res.status}`)
  return (await res.json()) as Post[]
}

export const getPost = cache(async (id: string) => db.post.findUnique({ where: { id } }))
```

---

### Fetch in parallel, not in waterfalls

Start independent requests together with `Promise.all`, or split them into sibling components each wrapped in its own `<Suspense>` so they stream independently.

```tsx
export default async function Page(props: PageProps<'/artists/[id]'>) {
  const { id } = await props.params
  const [artist, albums] = await Promise.all([getArtist(id), getAlbums(id)])
  return <ArtistView artist={artist} albums={albums} />
}
```

---

### On-demand revalidation

- `updateTag(tag)`: expires immediately; next read waits for fresh data. Server Actions only. Use for read-your-own-writes.
- `revalidateTag(tag, profile)`: stale-while-revalidate (`'max'` recommended). Server Actions and Route Handlers. The single-argument form is from older majors; check the installed version's reference.
- `revalidatePath(path)`: invalidate a route when tags are overkill. Prefer tags.
- `refresh()`: re-render the current route from a Server Action without invalidating cache.

```ts
// app/api/cms-webhook/route.ts — CMS content changed
import { revalidateTag } from 'next/cache'

export async function POST(request: Request) {
  if (!(await verifyCmsSignature(request))) return new Response(null, { status: 401 })
  revalidateTag('posts', 'max')
  return new Response(null, { status: 204 })
}
```

---

### Never cache per-user data in a shared cache

A shared `'use cache'` entry (or `force-cache` fetch) is served to every user with the same key. Per-user data must be keyed by the user (passed as an argument), cached privately (`'use cache: private'` with Cache Components), or not cached. Authorization must happen before the cached call, not inside a cache that might be reused.

## Rules

- Identify the caching model (version + `cacheComponents`) before using any caching API.
- Pair every `'use cache'` with `cacheLife`, and tag data you will invalidate with `cacheTag`.
- Wrap request-time reads in `<Suspense>` and push them down the tree to maximize the static shell.
- Fetch in Server Components or the DAL; avoid client-side `useEffect` fetching for initial data.
- Run independent fetches in parallel.
- Use `React.cache` for per-render deduplication of non-`fetch` reads.
- Prefer tag-based revalidation over path-based; use `updateTag` after user-initiated writes.
- Check `res.ok` and handle failures explicitly; let `error.tsx` catch the rest.
- Use `'use cache: remote'` only when a durable shared cache handler is configured and the hit rate justifies it.

- Avoid mixing models: `export const revalidate` / `dynamic` / `fetchCache` in a Cache Components app, or `'use cache'` without `cacheComponents` enabled.
- Avoid assuming `fetch` is cached by default on Next.js 15+.
- Avoid calling `cookies()`/`headers()` inside a shared `'use cache'` scope.
- Avoid leaving request-time data outside `<Suspense>` with Cache Components enabled.
- Avoid caching user-specific or authorization-dependent data under a shared key.
- Avoid sequential `await`s for independent requests.
- Avoid exposing unauthenticated revalidation endpoints.
- Avoid using `Math.random()`, `Date.now()` or `crypto.randomUUID()` during prerender without `connection()` or `'use cache'`.
