# Next.js Security Headers and Config

> Check the HTTP security headers a Next.js app sends and the next.config options that affect them: CSP (nonce-based preferred), HSTS, framing, MIME sniffing, Referrer-Policy, Permissions-Policy, poweredByHeader, external rewrites/redirects, and Cache-Control on authenticated or per-user responses. Covers next.config headers(), middleware/proxy, vercel.json and other host config.

---

Goal: Fill a fixed header checklist (used for scoring) per app, plus
findings for cache and rewrite issues, with file:line evidence.

Official references:
- CSP guide (nonce via proxy/middleware, `next.config` headers without
  nonces, experimental SRI): https://nextjs.org/docs/app/guides/content-security-policy
- `headers()` in next.config: https://nextjs.org/docs/app/api-reference/config/next-config-js/headers
- `poweredByHeader`: https://nextjs.org/docs/app/api-reference/config/next-config-js/poweredByHeader

## WHERE HEADERS CAN BE SET (check all, per app)

```bash
S=reports/.artifacts/nextjs-security-audit/scope
for c in $(grep -E 'next\.config' "$S/config.lst"); do
  echo "=== $c"; grep -nE 'headers\(|source:|key:|value:|poweredByHeader|rewrites|redirects|destination|basePath|trailingSlash' "$c"
done
for e in $(cat "$S/edge.lst"); do
  echo "=== $e"; grep -nE 'headers\.set|Content-Security-Policy|nonce|Strict-Transport|X-Frame|frame-ancestors|X-Content-Type|Referrer-Policy|Permissions-Policy|Cache-Control|matcher' "$e"
done
for v in $(grep -E '(^|/)(vercel\.json|netlify\.toml)$' "$S/config.lst"); do
  echo "=== $v"; cat "$v" | head -80
done
git ls-files | grep -E '(^|/)(_headers|nginx[^/]*\.conf|Caddyfile)$|(^|/)nginx/' | head
. "$S/scan.sh"
SCAN_MAX=40 scan js.src "Headers set in code" -E "Content-Security-Policy|Strict-Transport-Security|X-Frame-Options|X-Content-Type-Options|Referrer-Policy|Permissions-Policy"
```

A header counts as **present** if it is set for all HTML routes (a
`source: '/(.*)'` / `'/:path*'` rule, or middleware/proxy whose matcher
covers pages) by any of these sources. Set only on some routes: PARTIAL.
If headers are set by infrastructure that is not in the repository (CDN,
load balancer), the auditor cannot see it: mark `Unknown — not in repo`
(no deduction) and say what would prove it. Never assume the hosting
provider adds a header.

Optional live check, only if a URL for the app appears in the repository
(README, `package.json` `homepage`, env example) and the user has not
forbidden network calls: `curl -sI <url>` and record the headers seen.
The repository evidence is still the primary source.

## CHECKLIST (one status per app: PRESENT / PARTIAL / MISSING / Unknown)

| # | Control | Good value | Notes |
|---|---------|-----------|-------|
| H1 | `Content-Security-Policy` | present, with `default-src`, `script-src` without `'unsafe-inline'` in production (nonce or hash), `object-src 'none'`, `base-uri`, `frame-ancestors` | Nonce via proxy/middleware is the guide's strict option; `next.config` headers without nonces need `'unsafe-inline'` for scripts. Record `CSP_MODE`: nonce / hash-SRI / static / report-only / none |
| H2 | `Strict-Transport-Security` | `max-age` of at least 1 year (`31536000`), `includeSubDomains` | Only meaningful over HTTPS |
| H3 | Framing protection | CSP `frame-ancestors 'none'` or `'self'`, or `X-Frame-Options: DENY` / `SAMEORIGIN` | Either satisfies it |
| H4 | `X-Content-Type-Options` | `nosniff` | |
| H5 | `Referrer-Policy` | `strict-origin-when-cross-origin` or stricter | |
| H6 | `Permissions-Policy` | present, disabling unused features (camera, microphone, geolocation, ...) | |
| H7 | `poweredByHeader: false` | set in next.config | Default sends `X-Powered-By: Next.js` |

CSP quality findings (in addition to the checklist status):
- `script-src` with `'unsafe-eval'` outside a development-only branch:
  MEDIUM.
- `script-src` with `'unsafe-inline'` and no nonce/hash: LOW (the guide's
  documented non-nonce option, but weaker against XSS).
- Wildcards (`*`, `https:`) in `script-src`: MEDIUM.
- `Content-Security-Policy-Report-Only` only: H1 = PARTIAL.

## REWRITES AND REDIRECTS TO EXTERNAL HOSTS

```bash
for c in $(grep -E 'next\.config' reports/.artifacts/nextjs-security-audit/scope/config.lst); do
  grep -nE "destination:\s*['\"\`]https?://" "$c"
done
```

- A rewrite to an external host proxies that host under your origin
  (cookies and CSP `'self'` apply to it): list each; MEDIUM if the
  destination includes a user-controlled segment (`:path*` into a
  third-party host) or the host is not clearly owned by the project, LOW
  otherwise.
- A redirect whose destination is built from a `has`/query value: MEDIUM
  (open redirect).

## CACHE-CONTROL ON AUTHENTICATED / PER-USER RESPONSES (cache poisoning class)

```bash
. reports/.artifacts/nextjs-security-audit/scope/scan.sh
SCAN_MAX=40 scan js.src "Shared cache headers" -E "Cache-Control['\"]?\s*[,:]\s*['\"\`][^'\"\`]*(public|s-maxage|stale-while-revalidate)"
SCAN_MAX=40 scan js.src "Static/cached render config" -E "export const (dynamic|revalidate|fetchCache)\s*=|['\"]use cache['\"]|unstable_cache\(|cacheLife\(|cacheTag\("
SCAN_MAX=40 scan js.src "Per-user inputs" -E "cookies\(\)|headers\(\)|auth\(|getServerSession|currentUser"
grep -nE 'Cache-Control|Vary' $(grep -E 'next\.config|vercel\.json' reports/.artifacts/nextjs-security-audit/scope/config.lst) 2>/dev/null
```

Cross-reference the files from the three scans and read the overlaps:
- A response that depends on the user (reads cookies/session/auth headers)
  but is sent with `public` / `s-maxage` / CDN cache headers, or is
  computed inside `'use cache'` / `unstable_cache` / `force-static` /
  `revalidate` with user-specific data and no per-user cache key:
  **HIGH** (one user's data served to others).
- Shared-cache headers on a response that varies by a request header
  without a matching `Vary`: MEDIUM.
- Authenticated API responses with no `Cache-Control` at all: LOW
  (recommend `private, no-store`).

## ARTIFACT SAVE (mandatory)

Save the full output to: reports/.artifacts/nextjs-security-audit/step_08_headers-and-config.md
Run before finishing: mkdir -p reports/.artifacts/nextjs-security-audit

Output format:
- Where headers are set (per app): next.config / middleware or proxy /
  vercel.json / other / not in repo
- `CSP_MODE` per app
- Checklist table per app: H1-H7 with status (PRESENT / PARTIAL / MISSING /
  Unknown) and file:line evidence
- `HEADERS_MISSING`: list of H-codes MISSING (worst app wins in a monorepo)
- `HEADERS_PARTIAL`: list of H-codes PARTIAL
- Findings (CSP quality, external rewrites, redirects, cache) with severity,
  file:line and rationale
- `HEADER_FINDINGS_HIGH`, `HEADER_FINDINGS_MEDIUM`, `HEADER_FINDINGS_LOW`
  counts (findings only; the checklist is scored separately)
- Ready-to-apply snippet for missing headers: point to the CSP guide's
  proxy example for nonce-based CSP, or a `headers()` block for the static
  headers (H2-H6). Do not copy a CSP that the app's third-party scripts
  would break without saying which sources must be added.
