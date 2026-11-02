# Next.js SAST

> Grep-based review of Next.js-specific risk patterns with file:line evidence: authorization only in middleware/proxy, Server Actions and Route Handlers without authorization or input validation, XSS, open redirects, SSRF, image and Server Actions configuration, server data leaking to client components, unsafe SQL, cookie flags and CSRF. Every finding carries a severity (LOW / MEDIUM / HIGH) and a one-line rationale.

---

Goal: Find the Next.js application-layer weaknesses an attacker can reach
over HTTP, with evidence a reviewer can open.

Official reference (its "Auditing" checklist is the model for this step):
https://nextjs.org/docs/app/guides/data-security

Key facts from that guide that drive the checks below:
- A Server Action (`'use server'`) is reachable by a direct POST request,
  not only through the UI. It must authenticate **and** authorize inside
  the action (or in the Data Access Layer it calls). A page-level check
  does not protect the actions defined in it.
- `proxy.ts` (formerly `middleware.ts`) and `route.ts` "have a lot of
  power" and deserve extra review.
- Dynamic route segments (`[param]`) and `searchParams` are user input.
- Server Action return values and props passed to Client Components are
  serialized to the browser.

## RULES

- Grep finds candidates; **read the file before assigning a severity**.
  A candidate you did not read is reported as "candidate, not confirmed"
  with LOW severity.
- One finding per (file, issue). Quote file:line.
- Severity scale:
  - **HIGH**: exploitable without special conditions (missing authz on a
    mutation, injection with user input, secret/PII sent to the client,
    authorization done only in middleware/proxy for a sensitive route).
  - **MEDIUM**: exploitable under conditions or missing a defense layer
    (no input validation, open redirect, permissive config, CSRF exposure,
    cookie flags missing on a session cookie).
  - **LOW**: hardening / informational / unconfirmed candidate.

Start every block with
`. reports/.artifacts/nextjs-security-audit/scope/scan.sh` and run it from
the repository root. Record `cat reports/.artifacts/nextjs-security-audit/scope/summary.txt`
first.

## 1. INVENTORY OF ENTRY POINTS

```bash
S=reports/.artifacts/nextjs-security-audit/scope
echo "Route Handlers:"; cat "$S/route_handlers.lst"
echo "Pages API routes:"; cat "$S/api_routes.lst"
echo "Middleware/Proxy:"; cat "$S/edge.lst"
echo "'use server' modules:"; cat "$S/use_server.lst"
echo "Inline server functions (files containing 'use server'):"; cat "$S/server_fn.lst"
# Mutating handlers
. "$S/scan.sh"
SCAN_MAX=60 scan route_handlers "Mutating Route Handler exports" -E 'export (async )?(function|const) (POST|PUT|PATCH|DELETE)\b'
SCAN_MAX=60 scan api_routes "Pages API method checks" -E "req\.method"
```

## 2. AUTHORIZATION

### 2a. Authorization only in middleware / proxy

```bash
. reports/.artifacts/nextjs-security-audit/scope/scan.sh
AUTH_RE='auth\(|getServerSession|getSession|currentUser|getCurrentUser|getUser\(|verifySession|requireUser|requireAuth|getToken|withAuth|clerk|auth\.api|supabase\.auth|session\??\.user|validateRequest|iron-session|getIronSession|jwtVerify|verifyToken'
scan edge "Auth logic in middleware/proxy" -E "$AUTH_RE|redirect\(.*login|NextResponse\.redirect"
grep -nE 'matcher' $(cat reports/.artifacts/nextjs-security-audit/scope/edge.lst) 2>/dev/null
# Entry points with no auth call at all (candidates)
for f in $(cat reports/.artifacts/nextjs-security-audit/scope/route_handlers.lst \
               reports/.artifacts/nextjs-security-audit/scope/api_routes.lst \
               reports/.artifacts/nextjs-security-audit/scope/server_fn.lst); do
  grep -qE "$AUTH_RE" "$f" || echo "NO_AUTH_CALL $f"
done
```

Interpretation:
- If middleware/proxy performs authentication or route protection **and**
  any Route Handler, Server Action or page under a protected matcher has
  no authorization check of its own (directly or via a DAL function it
  calls — follow the import), report **HIGH: authorization only in
  middleware/proxy** per file. Middleware-bypass vulnerabilities have
  existed; middleware must be one layer, not the only one.
- A `NO_AUTH_CALL` file may delegate to a DAL (`import ... from '@/data/...'`
  or similar). Read it: if the called function checks the session and
  ownership, it is not a finding.
- A mutating Server Action or Route Handler (POST/PUT/PATCH/DELETE, or any
  DB write) with no authentication: **HIGH**. Authentication without an
  ownership/role check on a resource ID from input (IDOR): **HIGH**.
- A read-only handler with no auth that returns non-public data: **HIGH**;
  public by design (health check, webhook with signature verification,
  public content): not a finding — say why.

### 2b. Webhooks

```bash
. reports/.artifacts/nextjs-security-audit/scope/scan.sh
scan route_handlers "Webhook handlers" -iE 'webhook'
scan js.src "Webhook signature verification" -E 'constructEvent|verifySignature|svix|createHmac|timingSafeEqual|verifyWebhook'
```

A webhook Route Handler without signature verification: **HIGH**.

## 3. INPUT VALIDATION

```bash
. reports/.artifacts/nextjs-security-audit/scope/scan.sh
VALID_RE='z\.object|z\.string|\.safeParse\(|\.parse\(|valibot|v\.object|yup\.|object\(\{|Joi\.|superstruct|typebox|arktype|next-safe-action|zsa'
for f in $(cat reports/.artifacts/nextjs-security-audit/scope/route_handlers.lst \
               reports/.artifacts/nextjs-security-audit/scope/api_routes.lst \
               reports/.artifacts/nextjs-security-audit/scope/use_server.lst); do
  grep -qE "formData|request\.json\(\)|req\.body|searchParams|params" "$f" \
    && ! grep -qE "$VALID_RE" "$f" && echo "NO_VALIDATION $f"
done
```

A Server Action or Route Handler that uses `formData`, `request.json()`,
`req.body`, `params` or `searchParams` with no schema validation (in the
file or in the DAL function it calls): **MEDIUM**. If the unvalidated value
reaches a DB write, a redirect, a fetch URL, a file path or HTML: report
the more specific issue below instead (with its own severity).

## 4. XSS — dangerouslySetInnerHTML

```bash
. reports/.artifacts/nextjs-security-audit/scope/scan.sh
SCAN_MAX=40 scan js.src "dangerouslySetInnerHTML" -F 'dangerouslySetInnerHTML'
scan js.src "Sanitizers" -E 'DOMPurify|isomorphic-dompurify|sanitize-html|xss\(|rehype-sanitize'
```

Read each match:
- Constant string, or `JSON.stringify(...)` into `<script type="application/ld+json">`
  with server-controlled data: LOW (ld+json from user data without
  escaping `<`: MEDIUM).
- Sanitized with DOMPurify / sanitize-html: LOW.
- Data from a DB, CMS, markdown or user input without sanitizing: **HIGH**
  if user-controlled, MEDIUM if CMS/admin-controlled.

## 5. OPEN REDIRECT

```bash
. reports/.artifacts/nextjs-security-audit/scope/scan.sh
SCAN_MAX=40 scan js.src "redirect with input" -E \
  '(redirect|permanentRedirect|NextResponse\.redirect|res\.redirect|router\.push|router\.replace)\(.*(searchParams|params|formData|get\(|query|callbackUrl|returnTo|redirectTo|next\b|url\b)'
```

A redirect target taken from input without allow-listing (same-origin
relative path that is not `//...`, or a host allow-list): **MEDIUM**
(HIGH on login/OAuth callback flows, where it enables token theft).

## 6. SSRF

```bash
. reports/.artifacts/nextjs-security-audit/scope/scan.sh
SCAN_MAX=40 scan js.src "fetch with variable URL" -E '(fetch|axios(\.(get|post|put|request))?|got|ky)\(\s*(`[^`]*\$\{|[a-zA-Z_$][a-zA-Z0-9_$.]*\s*[,)])'
```

Read each match in a server context (Route Handler, Server Action, Server
Component, DAL). A URL or host built from `searchParams`, `params`,
`formData`, request body or a DB field the user controls, with no host
allow-list: **HIGH** (Server Actions and Route Handlers run inside your
network and can reach metadata endpoints and internal services). Path-only
interpolation into a fixed trusted origin: LOW.

## 7. next.config — images and Server Actions

```bash
for c in $(grep -E 'next\.config' reports/.artifacts/nextjs-security-audit/scope/config.lst); do
  echo "--- $c"
  grep -nE 'images|remotePatterns|hostname|domains|dangerouslyAllowSVG|contentSecurityPolicy|contentDispositionType|unoptimized|loader' "$c"
  grep -nE 'serverActions|allowedOrigins|bodySizeLimit|experimental|taint' "$c"
done
```

- `remotePatterns` with `hostname: '**'` or a bare wildcard, or a protocol
  of `http`: **MEDIUM** (the image optimizer fetches and serves arbitrary
  hosts — abuse as an open proxy / cost amplification). Narrow wildcards on
  an owned domain: LOW.
- `images.domains` (deprecated in favor of `remotePatterns`): LOW.
- `dangerouslyAllowSVG: true` without `contentDispositionType: 'attachment'`
  **and** a restrictive `images.contentSecurityPolicy`: **MEDIUM** (stored
  XSS through SVG).
- `serverActions.allowedOrigins` containing `*` alone or wildcards of
  domains the project does not control: **MEDIUM** (weakens the built-in
  Origin/Host check that protects Server Actions from CSRF).
- `serverActions.bodySizeLimit` set very high (state the configured value):
  LOW (DoS surface).
- `experimental.taint` enabled and `experimental_taintObjectReference` /
  `experimental_taintUniqueValue` used: record as a positive control.

## 8. SERVER DATA LEAKING TO THE CLIENT

```bash
. reports/.artifacts/nextjs-security-audit/scope/scan.sh
# Whole-model props in client components
SCAN_MAX=40 scan use_client "Model-typed props" -E '(: *(User|Account|Customer|Order|Profile)\b|Prisma\.[A-Z]|\$inferSelect|InferSelectModel|Tables<|Database\[)'
# Server Actions returning raw DB results
SCAN_MAX=40 scan server_fn "Returning DB call" -E 'return (await )?(db|prisma|sql|supabase|knex|drizzle)[.`(]'
# Taint API usage
scan js.src "Taint API" -E 'experimental_taint(ObjectReference|UniqueValue)'
```

Read the matches and the Server Component that renders each client
component:
- A full DB row / ORM model object (with fields such as password hash,
  tokens, email, internal IDs) passed as a prop to a `'use client'`
  component, or returned from a Server Action: **HIGH** if it carries
  secrets or PII the UI does not need, MEDIUM if over-broad but not
  sensitive.
- A client component whose prop type is a full model type: LOW (type
  signature invites over-sharing; the guide recommends DTOs).

## 9. CODE AND SQL INJECTION

```bash
. reports/.artifacts/nextjs-security-audit/scope/scan.sh
scan js.src "eval / new Function" -E '\beval\(|new Function\(|vm\.runIn|setTimeout\(\s*['\''"`]'
scan js.src "Raw SQL" -E '\$queryRawUnsafe|\$executeRawUnsafe|sql\.raw\(|sql\.unsafe\(|\.raw\(`|knex\.raw\(`|query\(\s*`[^`]*\$\{|query\(\s*['\''"][^'\''"]*['\''"]\s*\+'
scan js.src "Shell exec" -E "child_process|exec\(|execSync\(|spawn\("
scan js.src "File path from input" -E '(readFile|createReadStream|writeFile|unlink)\(.*(params|searchParams|formData|body|query)'
```

- `eval` / `new Function` / shell exec with input-derived data: **HIGH**;
  constant input: LOW.
- SQL string built with template interpolation or concatenation, or an
  `*Unsafe` / `raw` API, with input-derived values: **HIGH**; with constant
  values: LOW. Tagged templates (`` sql`... ${x}` ``, Prisma `$queryRaw`
  tagged form) are parameterized: not a finding.
- File paths built from input without normalization and a base-dir check:
  **HIGH**.

## 10. COOKIES AND CSRF

```bash
. reports/.artifacts/nextjs-security-audit/scope/scan.sh
SCAN_MAX=40 scan js.src "Cookie writes" -E '(cookies\(\)|cookieStore|response\.cookies|res\.cookies|\.cookies)\.set\(|Set-Cookie|serialize\('
for f in $(cat reports/.artifacts/nextjs-security-audit/scope/route_handlers.lst reports/.artifacts/nextjs-security-audit/scope/api_routes.lst); do
  grep -qE 'export (async )?(function|const) (POST|PUT|PATCH|DELETE)|req\.method' "$f" \
    && grep -qE 'cookies\(|request\.cookies|req\.cookies|getServerSession|auth\(' "$f" \
    && ! grep -qiE "origin|csrf|x-csrf|sec-fetch-site|sameSite" "$f" && echo "CSRF_CANDIDATE $f"
done
```

- A session / auth cookie set without `httpOnly: true`, `secure: true`
  (production) or `sameSite` (`lax` or `strict`): **MEDIUM** per cookie;
  non-auth cookies: LOW. Cookies set by an auth library with its defaults
  are not findings unless the config overrides them insecurely.
- `CSRF_CANDIDATE`: a cookie-authenticated mutating Route Handler with no
  Origin / CSRF token / `Sec-Fetch-Site` check: **MEDIUM**. Server Actions
  get a built-in Origin vs Host check; Route Handlers do not. Lower to LOW
  if the session cookie is confirmed `SameSite=Strict`, or if the handler
  only accepts `application/json` and rejects simple requests (state the
  evidence).

## 11. DYNAMIC ROUTE PARAMS (informational sweep)

```bash
git ls-files | grep -E '/\[[^/]+\]/' | grep -E '(page|route)\.[cm]?[jt]sx?$' | head -40
```

Spot-check up to 5 dynamic routes that reach a DB or file system: a param
used without validation feeds the issues above; report it there.

## ARTIFACT SAVE (mandatory)

Save the full output to: reports/.artifacts/nextjs-security-audit/step_07_nextjs-sast.md
Run before finishing: mkdir -p reports/.artifacts/nextjs-security-audit

Output format:
- **Scope** first (from `scope/summary.txt`) and the entry-point inventory
  counts (Route Handlers, Pages API routes, middleware/proxy, `'use server'`
  modules)
- `AUTH_ONLY_IN_MIDDLEWARE`: YES/NO + affected files
- Findings table: # | Severity | Category | File:line | Evidence (short quote) | Rationale | Confirmed (read) / Candidate
- `SAST_HIGH`, `SAST_MEDIUM`, `SAST_LOW` counts (confirmed + candidates,
  candidates are always LOW)
- Positive controls observed (DAL with `server-only`, schema validation
  everywhere, Taint API, webhook signature verification)
- "No Next.js SAST findings" only next to a non-zero scope
