---
description: Next.js security — authorization in every page, Server Action and Route Handler (never only in proxy/middleware), input validation, server-only secrets and Taint API, security headers and nonce CSP, image remotePatterns, and supply chain hardening with pnpm plus live advisory checks before adding or upgrading dependencies.
globs: "**/*.ts, **/*.tsx, **/*.js, **/*.jsx, **/*.mjs, next.config.*, package.json, pnpm-lock.yaml, pnpm-workspace.yaml, .npmrc, .github/workflows/**"
alwaysApply: false
---

# Next.js Security

Security rules for Next.js applications: where to enforce access control, how to keep secrets and private data on the server, which headers to send, and how to keep the dependency tree trustworthy.

## Purpose

Next.js has many entry points: pages, layouts, Server Actions, Route Handlers, proxy/middleware, image optimization and metadata routes. Each can be reached directly over HTTP. Framework-level protections (encrypted action IDs, Origin checks) reduce risk but do not replace application checks. The dependency tree, including `next` and `react` themselves, is part of the attack surface and its advisories change weekly.

## Patterns

### Authorize at every entry point, never only in proxy/middleware

`proxy.ts` (Next.js 16+) or `middleware.ts` (15.x and earlier) may do optimistic, cookie-only redirects, but it must not be the only check. Matchers change, Server Actions are POSTs to whatever route renders them, and layouts do not re-run on client navigation. Every page that shows protected data, every Server Action and every Route Handler must verify the session and authorize the specific resource, ideally through a `server-only` Data Access Layer.

#### Good

```ts
// src/data/auth.ts
import 'server-only'
import { cache } from 'react'
import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import { decrypt } from '@/lib/session'

export const verifySession = cache(async () => {
  const session = await decrypt((await cookies()).get('session')?.value)
  if (!session?.userId) redirect('/login')
  return { userId: session.userId, role: session.role }
})
```

```tsx
// app/invoices/[id]/page.tsx
import { notFound } from 'next/navigation'
import { verifySession } from '@/data/auth'
import { getInvoiceForUser } from '@/data/invoices'

export default async function Page(props: PageProps<'/invoices/[id]'>) {
  const { userId } = await verifySession()
  const { id } = await props.params
  const invoice = await getInvoiceForUser(userId, id) // filters by owner
  if (!invoice) notFound()
  return <InvoiceView invoice={invoice} />
}
```

#### Bad

```ts
// ❌ Only line of defense: the matcher can miss routes, and the pages, actions
// and route handlers behind it perform no checks of their own
export function proxy(request: NextRequest) {
  if (!request.cookies.get('session')) {
    return NextResponse.redirect(new URL('/login', request.url))
  }
}
```

```tsx
// ❌ Auth check only in the layout: does not re-run on client navigation, does not
// protect nested pages' data in the RSC payload, and does not protect Server Actions
export default async function AdminLayout({ children }: LayoutProps<'/admin'>) {
  const session = await getSession()
  if (!session?.isAdmin) return null
  return <>{children}</>
}
```

---

### Validate all input in Server Actions and Route Handlers

Validate arguments, `FormData`, JSON bodies, `params`, `searchParams` and headers with a schema. Folders in brackets (`[id]`) are user input. Then authorize the resource (schema validation alone does not prevent IDOR). Use parameterized queries or an ORM; never interpolate input into SQL, shell commands, file paths or redirect URLs.

#### Good

```ts
'use server'

import { z } from 'zod'
import { verifySession } from '@/data/auth'

const Input = z.object({ itemId: z.string().uuid() })

export async function completeItem(raw: unknown) {
  const { itemId } = Input.parse(raw)
  const { userId } = await verifySession()
  const item = await db.item.findFirst({ where: { id: itemId, ownerId: userId } })
  if (!item) throw new Error('Not found')
  await db.item.update({ where: { id: item.id }, data: { completed: true } })
}
```

```ts
// Open-redirect safe: only allow same-site relative paths
const next = request.nextUrl.searchParams.get('next') ?? '/'
const target = next.startsWith('/') && !next.startsWith('//') ? next : '/'
return NextResponse.redirect(new URL(target, request.url))
```

#### Bad

```tsx
// ❌ Trusts a query parameter for authorization
export default async function Page({ searchParams }: PageProps<'/settings'>) {
  if ((await searchParams).isAdmin === 'true') return <AdminPanel />
}
```

---

### Keep secrets and private data on the server

- Put `import 'server-only'` in every module that reads secrets, the database or internal APIs.
- Only the DAL should read `process.env` secrets.
- Never put a secret in a `NEXT_PUBLIC_*` variable; those are inlined into client JavaScript at build time.
- Pass DTOs, not records, to Client Components and from Server Actions.
- Where available, enable React's Taint API (`experimental.taint: true` in `next.config`) and taint objects and values that must never reach the client. It is defense in depth, not a replacement for DTOs. It is experimental; check the installed Next.js and React versions.

#### Good

```ts
// next.config.ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  experimental: { taint: true },
}

export default nextConfig
```

```ts
// src/data/user.ts
import 'server-only'
import { experimental_taintObjectReference, experimental_taintUniqueValue } from 'react'

export async function getUserRecord(id: string) {
  const user = await db.user.findUnique({ where: { id } })
  if (!user) return null
  experimental_taintObjectReference('Do not pass the raw user record to the client', user)
  experimental_taintUniqueValue('Do not pass the API token to the client', user, user.apiToken)
  return user
}
```

#### Bad

```ts
// ❌ Secret shipped to every browser
const client = new PaymentsClient(process.env.NEXT_PUBLIC_PAYMENTS_SECRET)
```

---

### Security headers and Content Security Policy

Send baseline security headers from `next.config` `headers()`. For a strict CSP with nonces, generate a fresh nonce per request in `proxy.ts` (`middleware.ts` before 16); Next.js reads the nonce from the `Content-Security-Policy` request header and applies it to its scripts. Nonce CSP requires dynamic rendering for every affected page (no static optimization, ISR or Partial Prerendering for them); if that is unacceptable, use a non-nonce CSP from `next.config` or the experimental SRI option. Disable the `X-Powered-By` header.

#### Good

```ts
// next.config.ts
import type { NextConfig } from 'next'

const securityHeaders = [
  { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
]

const nextConfig: NextConfig = {
  poweredByHeader: false,
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }]
  },
}

export default nextConfig
```

```ts
// proxy.ts (Next.js 16+; middleware.ts exporting `middleware` on 15.x)
import { NextResponse, type NextRequest } from 'next/server'

export function proxy(request: NextRequest) {
  const nonce = Buffer.from(crypto.randomUUID()).toString('base64')
  const isDev = process.env.NODE_ENV === 'development'
  const csp = `
    default-src 'self';
    script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${isDev ? " 'unsafe-eval'" : ''};
    style-src 'self' 'nonce-${nonce}';
    img-src 'self' blob: data:;
    font-src 'self';
    object-src 'none';
    base-uri 'self';
    form-action 'self';
    frame-ancestors 'none';
    upgrade-insecure-requests;
  `.replace(/\s{2,}/g, ' ').trim()

  const requestHeaders = new Headers(request.headers)
  requestHeaders.set('x-nonce', nonce)
  requestHeaders.set('Content-Security-Policy', csp)

  const response = NextResponse.next({ request: { headers: requestHeaders } })
  response.headers.set('Content-Security-Policy', csp)
  return response
}

export const config = {
  matcher: [
    {
      source: '/((?!api|_next/static|_next/image|favicon.ico).*)',
      missing: [
        { type: 'header', key: 'next-router-prefetch' },
        { type: 'header', key: 'purpose', value: 'prefetch' },
      ],
    },
  ],
}
```

Read the nonce in Server Components with `(await headers()).get('x-nonce')` and pass it to `<Script nonce={nonce}>` for third-party scripts.

#### Bad

```ts
// ❌ 'unsafe-inline' and 'unsafe-eval' in production, static nonce reused across requests,
// and request headers leaked to the client via NextResponse.next({ headers })
const csp = "script-src 'self' 'unsafe-inline' 'unsafe-eval' 'nonce-abc123'"
return NextResponse.next({ headers: requestHeaders })
```

---

### Image optimization: strict `remotePatterns`

Allow only the exact remote hosts and paths you serve images from. Omitted `protocol`, `port`, `pathname` or `search` fields imply `**`, so set them. Avoid `**` hostname wildcards. `images.domains` is deprecated; do not use it. Keep `dangerouslyAllowSVG` and `dangerouslyAllowLocalIP` off; if SVG is unavoidable, also set `contentDispositionType: 'attachment'` and a sandboxing `contentSecurityPolicy`. Remote redirects are followed without re-checking `remotePatterns`, so lower `maximumRedirects` (or set it to `0`) when you can.

#### Good

```ts
// next.config.ts
images: {
  remotePatterns: [
    { protocol: 'https', hostname: 'cdn.example.com', port: '', pathname: '/products/**', search: '' },
  ],
  maximumRedirects: 0,
},
```

#### Bad

```ts
// ❌ Any host, any protocol: turns /_next/image into an open proxy and SSRF vector
images: {
  remotePatterns: [{ hostname: '**' }],
  dangerouslyAllowSVG: true,
},
```

---

### Server Actions origin and encryption key

Do not widen `serverActions.allowedOrigins` beyond the specific proxy/CDN hosts that front the app. When self-hosting on multiple instances, set a stable, secret `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` (base64 AES key, for example from `openssl rand -base64 32`) and rotate it like any secret.

---

### Dependencies: use pnpm with a hardened configuration

Use pnpm, pinned through the `packageManager` field and Corepack, with a committed `pnpm-lock.yaml`, frozen installs in CI, and supply-chain settings in `pnpm-workspace.yaml`. Setting names and defaults change between pnpm majors (for example, pnpm 11 replaced `onlyBuiltDependencies`/`neverBuiltDependencies`/`ignoredBuiltDependencies` with `allowBuilds`). Verify every key against the installed pnpm version at https://pnpm.io/settings before writing it.

#### Good

In `package.json`, pin the exact pnpm version the team uses (look it up; do not guess):

```json
{
  "packageManager": "pnpm@<exact-version>"
}
```

```bash
corepack enable          # if Corepack is not bundled with your Node.js version: npm i -g corepack
pnpm install             # locally; commit pnpm-lock.yaml
pnpm install --frozen-lockfile   # in CI: fails if the lockfile is out of date
```

```yaml
# pnpm-workspace.yaml (pnpm 11+ key names; verify at https://pnpm.io/settings)
minimumReleaseAge: 1440        # minutes a version must be public before it can be installed
minimumReleaseAgeExclude: []   # keep empty; add a package only for an urgent security fix
blockExoticSubdeps: true       # transitive deps may not come from git/tarball URLs
trustPolicy: no-downgrade      # fail if a package's publish trust level drops
strictDepBuilds: true          # fail install when a dependency has an unreviewed build script
allowBuilds:                   # explicit allowlist of packages allowed to run install scripts
  esbuild: true
  sharp: true
# pnpm 10.x and older: use onlyBuiltDependencies instead of allowBuilds
```

```yaml
# .github/workflows/ci.yml (excerpt)
- uses: pnpm/action-setup@<pinned-sha>   # reads packageManager from package.json
- uses: actions/setup-node@<pinned-sha>
  with:
    node-version-file: .nvmrc
    cache: pnpm
- run: pnpm install --frozen-lockfile
```

#### Bad

```bash
npm install some-package       # mixes package managers; creates package-lock.json next to pnpm-lock.yaml
pnpm install --no-frozen-lockfile   # in CI: silently resolves new versions
```

```yaml
dangerouslyAllowAllBuilds: true
```

---

### Check live advisories before adding or upgrading any dependency

Before adding a dependency, or upgrading `next`, `react`, `react-dom` or anything else, query live advisory sources for the exact version you are about to install. Do not rely on a remembered "safe" or "patched" version: advisories for Next.js and React Server Components are published frequently, and versions that were safe last month may not be today. Never hardcode a version as known-good in code comments or docs.

#### Good

```bash
# 1. Resolve the exact version you intend to install
pnpm view next version
pnpm view next@<major> version

# 2. OSV (covers GHSA and other sources)
curl -s -X POST https://api.osv.dev/v1/query \
  -d '{"package":{"name":"next","ecosystem":"npm"},"version":"<version>"}'

# 3. GitHub Advisory Database
gh api 'advisories?ecosystem=npm&affects=next@<version>'

# 4. Next.js security advisories (read https://github.com/vercel/next.js/security)
gh api repos/vercel/next.js/security-advisories --jq '.[] | {ghsa_id, summary, published_at}'
#    and release-line support status
curl -s https://endoflife.date/api/nextjs.json

# 5. After installing, audit the resolved tree
pnpm audit --prod
```

Repeat steps 2 and 3 for `react`, `react-dom` and any new package. If an advisory affects the target version, pick a version outside every affected range, and prefer a release line that `endoflife.date` reports as supported. Record in the PR description which sources you checked.

#### Bad

```text
"Upgrade to next@<some version I remember being patched>" without querying OSV, GitHub
advisories or the Next.js security page for that exact version.
```

## Best Practices

- Verify session and resource ownership inside every page that shows protected data, every Server Action and every Route Handler; treat proxy/middleware checks as optimistic only.
- Centralize auth and data access in a `server-only` DAL that returns DTOs.
- Validate every input with a schema and use parameterized queries.
- Keep secrets out of `NEXT_PUBLIC_*`, guard server modules with `server-only`, and enable the Taint API where the installed versions support it.
- Set `poweredByHeader: false` and send HSTS, `X-Content-Type-Options`, `Referrer-Policy`, frame protection and `Permissions-Policy` headers.
- Use a nonce CSP from proxy/middleware when strict CSP is required, accepting dynamic rendering; otherwise a header CSP from `next.config` (or experimental SRI).
- Restrict `images.remotePatterns` to exact protocol, host and path; never `**` hosts.
- Use pnpm with `packageManager` + Corepack, a committed `pnpm-lock.yaml`, `pnpm install --frozen-lockfile` in CI, and a hardened `pnpm-workspace.yaml` (`minimumReleaseAge`, `blockExoticSubdeps`, `allowBuilds` or `onlyBuiltDependencies` on pnpm 10 and older, `strictDepBuilds`), verified against https://pnpm.io/settings.
- Before adding or upgrading any dependency, check OSV, the GitHub Advisory Database, https://github.com/vercel/next.js/security and https://endoflife.date/api/nextjs.json for the exact version.

## Common Mistakes

- Protecting routes only with `proxy.ts`/`middleware.ts` matchers.
- Doing auth checks only in layouts, or returning `null` from a layout as access control.
- Checking authentication but not authorization on the specific record (IDOR).
- Trusting `searchParams`, hidden form fields or client-sent IDs of owners/roles.
- Prefixing secrets with `NEXT_PUBLIC_` or reading secrets in modules a Client Component can import.
- Returning full database rows from Server Actions or passing them as props.
- Leaving `X-Powered-By` enabled and shipping no CSP or security headers.
- Using a static or reused CSP nonce, or `'unsafe-eval'` in production.
- `remotePatterns` with `hostname: '**'`, omitted protocol/pathname, or the deprecated `images.domains`.
- Committing both `package-lock.json` and `pnpm-lock.yaml`, or running non-frozen installs in CI.
- Enabling `dangerouslyAllowAllBuilds` or allowing every package to run install scripts.
- Choosing a `next`/`react` version from memory instead of checking live advisories.
