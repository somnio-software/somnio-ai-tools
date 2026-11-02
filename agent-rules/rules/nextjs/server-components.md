---
description: Next.js Server and Client Components — default to Server Components, minimal 'use client' boundaries, serializable props, server-only/client-only modules, composition via children, and environment variable exposure.
globs: "app/**, src/app/**, src/components/**, components/**"
alwaysApply: false
---

# Next.js Server and Client Components

How to split a Next.js App Router UI between Server Components and Client Components so that data and secrets stay on the server and the client bundle stays small.

## Purpose

In the App Router every component is a Server Component unless a module (or one of its importers) declares `'use client'`. That boundary decides what code ships to the browser and what data crosses the network. Misplaced boundaries leak private data, inflate bundles, or break at build time.

## Patterns

### Server Components by default

Fetch data and read secrets in Server Components. Add `'use client'` only to components that need state, effects, event handlers, browser APIs, or client-only hooks.

#### Good

```tsx
// app/products/page.tsx (Server Component)
import { getProducts } from '@/data/products'
import { AddToCartButton } from './_components/add-to-cart-button'

export default async function ProductsPage() {
  const products = await getProducts()
  return (
    <ul>
      {products.map((p) => (
        <li key={p.id}>
          {p.name} <AddToCartButton productId={p.id} />
        </li>
      ))}
    </ul>
  )
}
```

```tsx
// app/products/_components/add-to-cart-button.tsx
'use client'

import { useTransition } from 'react'
import { addToCart } from '@/app/actions/cart'

export function AddToCartButton({ productId }: { productId: string }) {
  const [pending, startTransition] = useTransition()
  return (
    <button disabled={pending} onClick={() => startTransition(() => addToCart(productId))}>
      Add to cart
    </button>
  )
}
```

#### Bad

```tsx
// ❌ Whole page marked 'use client' just for one button: data fetching moves to
// the browser, the API must be public, and the bundle grows
'use client'

export default function ProductsPage() {
  const [products, setProducts] = useState([])
  useEffect(() => { fetch('/api/products').then((r) => r.json()).then(setProducts) }, [])
  return <ul>{products.map((p) => <li key={p.id}>{p.name}</li>)}</ul>
}
```

---

### Keep the `'use client'` boundary at the leaves

`'use client'` marks an entry point: everything the module imports becomes client code. Put it on the smallest interactive component, and pass Server Components into Client Components as `children` or other props instead of importing them.

#### Good

```tsx
// app/_components/modal.tsx
'use client'

import { useState, type ReactNode } from 'react'

export function Modal({ trigger, children }: { trigger: string; children: ReactNode }) {
  const [open, setOpen] = useState(false)
  return (
    <>
      <button onClick={() => setOpen(true)}>{trigger}</button>
      {open && <dialog open>{children}</dialog>}
    </>
  )
}
```

```tsx
// app/page.tsx (Server Component composes the server-rendered content into the client shell)
import { Modal } from './_components/modal'
import { Cart } from './_components/cart' // Server Component

export default function Page() {
  return (
    <Modal trigger="Open cart">
      <Cart />
    </Modal>
  )
}
```

#### Bad

```tsx
// ❌ Importing a Server Component (that reads the DB) into a Client Component
'use client'

import { Cart } from './cart'

export function Modal() {
  return <dialog open><Cart /></dialog>
}
```

---

### Pass minimal, serializable props across the boundary

Props from Server to Client Components are serialized into the RSC payload and are visible in the browser. Pass only the fields the client needs, as plain data. Functions cannot be passed except Server Actions.

#### Good

```tsx
// Server Component
const user = await getUser()
return <ProfileCard name={user.name} avatarUrl={user.avatarUrl} />
```

#### Bad

```tsx
// ❌ The full record (password hash, email, internal flags) is serialized to the client
const user = await db.user.findUnique({ where: { id } })
return <ProfileCard user={user} />
```

---

### Mark server-only and client-only modules

Add `import 'server-only'` to modules that touch secrets, the database or internal APIs, so importing them from a Client Component fails the build. Use `import 'client-only'` for modules that rely on `window` or other browser APIs.

#### Good

```ts
// src/data/db.ts
import 'server-only'
import { Pool } from 'pg'

export const pool = new Pool({ connectionString: process.env.DATABASE_URL })
```

#### Bad

```ts
// ❌ No guard: an accidental import from a Client Component bundles this module
export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)
```

---

### Environment variables

Only variables prefixed with `NEXT_PUBLIC_` are inlined into client bundles, at build time. Everything else is server-only. Never prefix a secret with `NEXT_PUBLIC_`, and read secrets only inside `server-only` modules (ideally the Data Access Layer).

#### Good

```ts
// Client-safe, public by design
const mapsKey = process.env.NEXT_PUBLIC_MAPS_BROWSER_KEY

// Server-only module
import 'server-only'
const apiSecret = process.env.PAYMENTS_API_SECRET
```

#### Bad

```ts
// ❌ Inlined into the JavaScript every visitor downloads
const secret = process.env.NEXT_PUBLIC_PAYMENTS_API_SECRET
```

---

### Context providers and third-party client components

React context does not work in Server Components. Wrap providers in a small Client Component and render it as deep as possible (not around `<html>` if only part of the tree needs it). Wrap third-party components that use client features but lack `'use client'` in your own client re-export.

#### Good

```tsx
// app/providers.tsx
'use client'

import { ThemeProvider } from 'some-theme-lib'

export function Providers({ children }: { children: React.ReactNode }) {
  return <ThemeProvider>{children}</ThemeProvider>
}
```

## Best Practices

- Default to Server Components; justify each `'use client'` by a concrete need (state, effects, events, browser APIs).
- Place `'use client'` on leaf components and compose server content through `children`.
- Pass DTOs with only the fields the client renders; never pass ORM entities or full API responses.
- Put `import 'server-only'` at the top of every module that reads secrets, the database or internal services.
- Keep secrets out of `NEXT_PUBLIC_*`; remember those values are fixed at build time.
- Fetch data in Server Components rather than in `useEffect` + Route Handler round trips.
- Use `React.cache` to deduplicate the same server read within one render instead of prop-drilling the result.

## Common Mistakes

- Marking a page or layout `'use client'` to use one hook, pulling its whole import graph into the client bundle.
- Importing a Server Component (or a module that touches the DB) from a Client Component.
- Passing whole database records or session objects as props to Client Components.
- Reading `process.env.SECRET` in a module that a Client Component can import.
- Expecting `NEXT_PUBLIC_*` values to change at runtime without a rebuild.
- Using React context in a Server Component.
- Passing non-serializable values (plain functions, class instances) from Server to Client Components; only Server Actions can be passed as functions.
