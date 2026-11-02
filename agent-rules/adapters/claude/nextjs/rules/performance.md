---
description: "Next.js performance — maximize the prerendered static shell, stream with Suspense, next/image sizing and preload, next/font, next/script strategies, lazy-loading client code, Link prefetching, and bundle analysis."
paths:
  - "app/**"
  - "src/app/**"
  - "src/components/**"
  - "components/**"
  - "next.config.*"
---

# Next.js Performance

How to keep Next.js pages fast: render as much as possible ahead of time, stream the rest, and keep client JavaScript and media small.

## Patterns

### Maximize the static shell, stream the rest

Keep static and cached content outside request-time boundaries. Put runtime reads (`cookies()`, `headers()`, `searchParams`, uncached fetches) in small components wrapped in `<Suspense>` with meaningful fallbacks. With Cache Components (Next.js 16+), this is how Partial Prerendering produces an instant shell.

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

---

### Images with `next/image`

Use `next/image` with explicit `width`/`height` (or `fill` plus `sizes`) to prevent layout shift and serve responsive sizes. Mark only the LCP image as high priority. In Next.js 16 the `priority` prop is deprecated in favor of `preload`; in most cases prefer `loading="eager"` or `fetchPriority="high"`. Check the installed version's `next/image` reference.

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

---

### Fonts with `next/font`

`next/font` self-hosts fonts at build time (no request to Google at runtime) and avoids layout shift. Load fonts once in the root layout and expose them as CSS variables.

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

---

### Third-party scripts with `next/script`

Load third-party scripts with `next/script` and the least eager `strategy` that works: `afterInteractive` (default) for analytics and tag managers, `lazyOnload` for chat widgets and other non-critical scripts. Use `beforeInteractive` only for scripts that must run before hydration (it must be placed in the root layout). Prefer `@next/third-parties` components where available.

```tsx
import Script from 'next/script'

<Script src="https://widget.example.com/chat.js" strategy="lazyOnload" />
```

---

### Keep client bundles small

Client bundle size is driven by `'use client'` entry points and what they import. Keep boundaries at the leaves (see `server-components.md`), lazy-load heavy client-only widgets with `next/dynamic`, and import only what you use from large libraries.

```tsx
'use client'

import dynamic from 'next/dynamic'

const Chart = dynamic(() => import('./revenue-chart'), {
  ssr: false,
  loading: () => <ChartSkeleton />,
})
```

---

### Navigation and prefetching

Use `<Link>` for internal navigation so routes are prefetched and transitions are client-side. Prefetching behavior differs by version and by whether Partial Prefetching is enabled; read the installed version's `Link` and prefetching docs before setting `prefetch` explicitly. Avoid `prefetch={true}` on long lists of links where each prefetch costs a server invocation.

```tsx
import Link from 'next/link'

<Link href={`/products/${product.id}`}>{product.name}</Link>
```

---

### Measure

- Run `next build` and read the route output (static, partially prerendered, dynamic).
- Analyze bundles with the analyzer that matches the bundler and version (Turbopack's analyzer on recent versions; `@next/bundle-analyzer` for webpack). The official `next-bundle-optimizer` Skill (`npx skills add vercel/next.js --skill next-bundle-optimizer`) automates this on versions that support it.
- Report Core Web Vitals from real users with `useReportWebVitals` from `next/web-vitals` or your analytics provider.

## Rules

- Profile with a production build (`next build && next start`) before optimizing; dev mode is intentionally slower.
- Push request-time reads into small Suspense-wrapped components so the shell prerenders.
- Use `next/image` with explicit dimensions or `fill` + `sizes`; give high priority only to the LCP image.
- Use `next/font` in the root layout with `display: 'swap'` and CSS variables.
- Load third-party scripts with `next/script` and the least eager strategy.
- Keep `'use client'` boundaries small and lazy-load heavy client widgets with `next/dynamic`.
- Use `<Link>` for internal navigation and tune prefetching only with evidence.
- Fetch independent data in parallel (see `data-fetching-caching.md`).

- Avoid awaiting `cookies()`, `headers()` or `params` at the top of a layout or page, blocking the whole route.
- Avoid using `<img>` instead of `next/image`, or omitting `sizes` with `fill`.
- Avoid marking many images `preload`/`priority`.
- Avoid loading Google Fonts via `<link>` instead of `next/font`.
- Avoid adding third-party scripts with a raw `<script>` tag or `beforeInteractive` without need.
- Avoid marking large trees `'use client'`, inflating the bundle.
- Avoid using `next/dynamic` with `ssr: false` inside a Server Component.
- Avoid using `<a>` for internal links.
