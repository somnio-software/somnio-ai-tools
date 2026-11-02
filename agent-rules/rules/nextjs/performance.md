---
description: Next.js performance — maximize the prerendered static shell, stream with Suspense, next/image sizing and preload, next/font, next/script strategies, lazy-loading client code, Link prefetching, and bundle analysis.
globs: "app/**, src/app/**, src/components/**, components/**, next.config.*"
alwaysApply: false
---

# Next.js Performance

How to keep Next.js pages fast: render as much as possible ahead of time, stream the rest, and keep client JavaScript and media small.

## Purpose

Most Next.js performance problems come from a few causes: request-time work at the top of the tree that blocks the whole route, oversized client bundles from misplaced `'use client'` boundaries, unoptimized images and fonts, and third-party scripts loaded eagerly. Measure first (Lighthouse, Web Vitals, the bundle analyzer), then fix the specific cause.

## Patterns

### Maximize the static shell, stream the rest

Keep static and cached content outside request-time boundaries. Put runtime reads (`cookies()`, `headers()`, `searchParams`, uncached fetches) in small components wrapped in `<Suspense>` with meaningful fallbacks. With Cache Components (Next.js 16+), this is how Partial Prerendering produces an instant shell.

#### Good

```tsx
export default function ProductPage(props: PageProps<'/products/[id]'>) {
  return (
    <>
      <ProductDetails params={props.params} />            {/* 'use cache' inside */}
      <Suspense fallback={<RecommendationsSkeleton />}>
        <PersonalizedRecommendations />                   {/* reads cookies() */}
      </Suspense>
    </>
  )
}
```

#### Bad

```tsx
// ❌ One request-time read at the top makes the whole page wait
export default async function ProductPage(props: PageProps<'/products/[id]'>) {
  const user = (await cookies()).get('user')?.value
  const { id } = await props.params
  return <><ProductDetails id={id} /><PersonalizedRecommendations user={user} /></>
}
```

---

### Images with `next/image`

Use `next/image` with explicit `width`/`height` (or `fill` plus `sizes`) to prevent layout shift and serve responsive sizes. Mark only the LCP image as high priority. In Next.js 16 the `priority` prop is deprecated in favor of `preload`; in most cases prefer `loading="eager"` or `fetchPriority="high"`. Check the installed version's `next/image` reference.

#### Good

```tsx
import Image from 'next/image'
import hero from './hero.jpg' // static import: dimensions and blur placeholder inferred

export function Hero() {
  return <Image src={hero} alt="Team at work" placeholder="blur" fetchPriority="high" sizes="100vw" />
}

export function Thumb({ src, alt }: { src: string; alt: string }) {
  return <Image src={src} alt={alt} width={320} height={240} sizes="(max-width: 768px) 50vw, 320px" />
}
```

#### Bad

```tsx
// ❌ Plain <img>: no resizing, no modern formats, layout shift
<img src="/hero-4000px.jpg" />

// ❌ Every image marked high priority defeats the purpose
{products.map((p) => <Image key={p.id} src={p.img} alt={p.name} width={300} height={300} preload />)}
```

---

### Fonts with `next/font`

`next/font` self-hosts fonts at build time (no request to Google at runtime) and avoids layout shift. Load fonts once in the root layout and expose them as CSS variables.

#### Good

```tsx
// app/layout.tsx
import { Inter } from 'next/font/google'

const inter = Inter({ subsets: ['latin'], display: 'swap', variable: '--font-inter' })

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.variable}>
      <body>{children}</body>
    </html>
  )
}
```

#### Bad

```tsx
// ❌ Render-blocking external stylesheet and a runtime request to a third party
<link href="https://fonts.googleapis.com/css2?family=Inter" rel="stylesheet" />
```

---

### Third-party scripts with `next/script`

Load third-party scripts with `next/script` and the least eager `strategy` that works: `afterInteractive` (default) for analytics and tag managers, `lazyOnload` for chat widgets and other non-critical scripts. Use `beforeInteractive` only for scripts that must run before hydration (it must be placed in the root layout). Prefer `@next/third-parties` components where available.

#### Good

```tsx
import Script from 'next/script'

<Script src="https://widget.example.com/chat.js" strategy="lazyOnload" />
```

#### Bad

```tsx
// ❌ Synchronous script in the document blocks parsing and hydration
<script src="https://widget.example.com/chat.js"></script>
```

---

### Keep client bundles small

Client bundle size is driven by `'use client'` entry points and what they import. Keep boundaries at the leaves (see `server-components.md`), lazy-load heavy client-only widgets with `next/dynamic`, and import only what you use from large libraries.

#### Good

```tsx
'use client'

import dynamic from 'next/dynamic'

const Chart = dynamic(() => import('./revenue-chart'), {
  ssr: false,
  loading: () => <ChartSkeleton />,
})
```

#### Bad

```tsx
// ❌ Pulls the whole library into the client bundle for one helper
'use client'
import _ from 'lodash'
```

> `ssr: false` is only allowed inside Client Components.

---

### Navigation and prefetching

Use `<Link>` for internal navigation so routes are prefetched and transitions are client-side. Prefetching behavior differs by version and by whether Partial Prefetching is enabled; read the installed version's `Link` and prefetching docs before setting `prefetch` explicitly. Avoid `prefetch={true}` on long lists of links where each prefetch costs a server invocation.

#### Good

```tsx
import Link from 'next/link'

<Link href={`/products/${product.id}`}>{product.name}</Link>
```

#### Bad

```tsx
// ❌ Full page reload, no prefetch
<a href={`/products/${product.id}`}>{product.name}</a>
```

---

### Measure

- Run `next build` and read the route output (static, partially prerendered, dynamic).
- Analyze bundles with the analyzer that matches the bundler and version (Turbopack's analyzer on recent versions; `@next/bundle-analyzer` for webpack). The official `next-bundle-optimizer` Skill (`npx skills add vercel/next.js --skill next-bundle-optimizer`) automates this on versions that support it.
- Report Core Web Vitals from real users with `useReportWebVitals` from `next/web-vitals` or your analytics provider.

## Best Practices

- Profile with a production build (`next build && next start`) before optimizing; dev mode is intentionally slower.
- Push request-time reads into small Suspense-wrapped components so the shell prerenders.
- Use `next/image` with explicit dimensions or `fill` + `sizes`; give high priority only to the LCP image.
- Use `next/font` in the root layout with `display: 'swap'` and CSS variables.
- Load third-party scripts with `next/script` and the least eager strategy.
- Keep `'use client'` boundaries small and lazy-load heavy client widgets with `next/dynamic`.
- Use `<Link>` for internal navigation and tune prefetching only with evidence.
- Fetch independent data in parallel (see `data-fetching-caching.md`).

## Common Mistakes

- Awaiting `cookies()`, `headers()` or `params` at the top of a layout or page, blocking the whole route.
- Using `<img>` instead of `next/image`, or omitting `sizes` with `fill`.
- Marking many images `preload`/`priority`.
- Loading Google Fonts via `<link>` instead of `next/font`.
- Adding third-party scripts with a raw `<script>` tag or `beforeInteractive` without need.
- Marking large trees `'use client'`, inflating the bundle.
- Using `next/dynamic` with `ssr: false` inside a Server Component.
- Using `<a>` for internal links.
