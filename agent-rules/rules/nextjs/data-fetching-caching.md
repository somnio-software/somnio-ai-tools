---
description: Next.js data fetching and caching — detect the caching model in use (Cache Components with 'use cache'/cacheLife/cacheTag vs the previous fetch/unstable_cache model), Suspense for request-time data, parallel fetching, React cache deduplication, and on-demand revalidation.
globs: "app/**, src/app/**, src/data/**, src/lib/**, next.config.*"
alwaysApply: false
---

# Next.js Data Fetching and Caching

How to fetch, cache and revalidate data in the App Router, given that Next.js has two caching models and defaults changed across majors.

## Purpose

Caching is the area where Next.js changed most between majors. In 14, `fetch` was cached by default; in 15 it is not; in 16 the opt-in Cache Components model (`cacheComponents: true`) replaces `fetch` cache options, `unstable_cache` and route segment config with the `'use cache'` directive. Applying the wrong model's APIs silently does nothing or breaks the build.

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

#### Good

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

#### Bad

```ts
// ❌ Reads cookies() inside a shared 'use cache' scope — runtime APIs are not allowed there;
// read them outside and pass the value as an argument (or use 'use cache: private')
export async function getCart() {
  'use cache'
  const sessionId = (await cookies()).get('session')?.value
  return db.cart.findFirst({ where: { sessionId } })
}
```

---

### Request-time data behind `<Suspense>`

With Cache Components, uncached data and runtime APIs (`cookies()`, `headers()`, `searchParams`, non-static `params`, `connection()`) must sit inside a `<Suspense>` boundary so the static shell can prerender. Without it, the dev overlay and build report a blocking-route error. Pass runtime values as arguments into cached functions when the result can be shared.

#### Good

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

#### Bad

```tsx
// ❌ Top-level runtime read with no Suspense boundary blocks the whole route
export default async function Page() {
  const teamId = (await cookies()).get('team')?.value
  return <ActivityList items={await getTeamActivity(teamId)} />
}
```

---

### Previous model: opt in explicitly

Without Cache Components (and on 15.x), `fetch` is not cached by default. Opt in per request and tag what you will revalidate. Use `React.cache` to deduplicate ORM calls within a render.

#### Good

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

#### Bad

```ts
// ❌ Assumes Next.js 14 behavior (cached by default) on 15+, and never checks res.ok
const posts = await fetch('https://cms.example.com/posts').then((r) => r.json())
```

---

### Fetch in parallel, not in waterfalls

Start independent requests together with `Promise.all`, or split them into sibling components each wrapped in its own `<Suspense>` so they stream independently.

#### Good

```tsx
export default async function Page(props: PageProps<'/artists/[id]'>) {
  const { id } = await props.params
  const [artist, albums] = await Promise.all([getArtist(id), getAlbums(id)])
  return <ArtistView artist={artist} albums={albums} />
}
```

#### Bad

```tsx
// ❌ Sequential awaits for independent data double the latency
const artist = await getArtist(id)
const albums = await getAlbums(id)
```

---

### On-demand revalidation

- `updateTag(tag)`: expires immediately; next read waits for fresh data. Server Actions only. Use for read-your-own-writes.
- `revalidateTag(tag, profile)`: stale-while-revalidate (`'max'` recommended). Server Actions and Route Handlers. The single-argument form is from older majors; check the installed version's reference.
- `revalidatePath(path)`: invalidate a route when tags are overkill. Prefer tags.
- `refresh()`: re-render the current route from a Server Action without invalidating cache.

#### Good

```ts
// app/api/cms-webhook/route.ts — CMS content changed
import { revalidateTag } from 'next/cache'

export async function POST(request: Request) {
  if (!(await verifyCmsSignature(request))) return new Response(null, { status: 401 })
  revalidateTag('posts', 'max')
  return new Response(null, { status: 204 })
}
```

#### Bad

```ts
// ❌ Unauthenticated revalidation endpoint lets anyone flush your cache on demand
export async function GET(request: NextRequest) {
  revalidatePath(request.nextUrl.searchParams.get('path') ?? '/')
  return Response.json({ revalidated: true })
}
```

---

### Never cache per-user data in a shared cache

A shared `'use cache'` entry (or `force-cache` fetch) is served to every user with the same key. Per-user data must be keyed by the user (passed as an argument), cached privately (`'use cache: private'` with Cache Components), or not cached. Authorization must happen before the cached call, not inside a cache that might be reused.

## Best Practices

- Identify the caching model (version + `cacheComponents`) before using any caching API.
- Pair every `'use cache'` with `cacheLife`, and tag data you will invalidate with `cacheTag`.
- Wrap request-time reads in `<Suspense>` and push them down the tree to maximize the static shell.
- Fetch in Server Components or the DAL; avoid client-side `useEffect` fetching for initial data.
- Run independent fetches in parallel.
- Use `React.cache` for per-render deduplication of non-`fetch` reads.
- Prefer tag-based revalidation over path-based; use `updateTag` after user-initiated writes.
- Check `res.ok` and handle failures explicitly; let `error.tsx` catch the rest.
- Use `'use cache: remote'` only when a durable shared cache handler is configured and the hit rate justifies it.

## Common Mistakes

- Mixing models: `export const revalidate` / `dynamic` / `fetchCache` in a Cache Components app, or `'use cache'` without `cacheComponents` enabled.
- Assuming `fetch` is cached by default on Next.js 15+.
- Calling `cookies()`/`headers()` inside a shared `'use cache'` scope.
- Leaving request-time data outside `<Suspense>` with Cache Components enabled.
- Caching user-specific or authorization-dependent data under a shared key.
- Sequential `await`s for independent requests.
- Exposing unauthenticated revalidation endpoints.
- Using `Math.random()`, `Date.now()` or `crypto.randomUUID()` during prerender without `connection()` or `'use cache'`.
