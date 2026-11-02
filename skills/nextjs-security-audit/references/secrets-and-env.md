# Next.js Secrets and Environment Exposure

> Find secrets that reach the browser or the repository in a Next.js app: NEXT_PUBLIC_ variables that look like secrets, committed .env files, secrets reachable from client components, the env key in next.config, browser source maps, and hardcoded secret patterns in JS/TS. MANDATORY check: the artifact must exist even if nothing is found.

---

Goal: Produce two separate blocks for the report — **Sensitive File & Env
Protection** (part A) and **Secret Detection** (part B) — each with counts
and file:line evidence.

Background (Next.js docs: https://nextjs.org/docs/app/guides/environment-variables
and https://nextjs.org/docs/app/guides/data-security):
- Any variable prefixed `NEXT_PUBLIC_` is inlined into the JavaScript sent
  to the browser at build time. It is public, whatever its name says.
- Values in the `env` key of `next.config.*` are inlined into the bundle too.
- Variables without the prefix are server-only; in client code they read as
  `undefined`, so they do not leak by that path — the leak paths are
  `NEXT_PUBLIC_`, `next.config` `env`, props passed from a Server Component
  to a Client Component, and Server Action return values.
- `import 'server-only'` makes the build fail if a module is imported into
  client code; it is the recommended guard for modules that read secrets.

SCAN SCOPE: run every block from the repository root and start each with
`. reports/.artifacts/nextjs-security-audit/scope/scan.sh` (lists built in
step 1). Record `cat reports/.artifacts/nextjs-security-audit/scope/summary.txt`
first. A list with 0 files prints "not applicable" — that is no result,
not a clean result.

## PART A — SENSITIVE FILE & ENV PROTECTION

### A1. Committed .env files

```bash
git ls-files | grep -E '(^|/)\.env($|\.)' 
for f in $(git ls-files | grep -E '(^|/)\.env($|\.)' | grep -vE '\.(example|sample|template|dist)$'); do
  echo "--- $f: $(grep -cE '^[A-Z0-9_]+=.+' "$f") non-empty assignments"
  grep -nE '^[A-Z0-9_]*(SECRET|TOKEN|PASSWORD|PRIVATE|KEY|DATABASE_URL|DSN|CREDENTIAL)[A-Z0-9_]*=.+' "$f" \
    | sed -E 's/=.*/=<redacted>/'
done
for f in .env .env.local .env.production .env.development .env.test; do
  git check-ignore -q "$f" && echo "IGNORED $f" || echo "NOT_IGNORED $f"
done
for app in $(echo "$NEXTJS_APPS" | tr '|' ' '); do
  git check-ignore -q "$app/.env.local" && echo "IGNORED $app/.env.local" || echo "NOT_IGNORED $app/.env.local"
done
```

Classify (never print secret values; redact as above):
- `.env*.local` tracked: HIGH (these files are meant for local secrets).
- `.env`, `.env.production`, `.env.development` tracked **with
  secret-looking non-empty values**: HIGH per file. Tracked with only
  public defaults (e.g. `NEXT_PUBLIC_APP_NAME=`): informational — Next.js
  supports committing defaults.
- `.env*.local` not ignored (`NOT_IGNORED`): MEDIUM (`MISSING_ENV_IGNORE`).
- `.env.example` / `.env.sample` with placeholders only: bonus. With real
  values: treat like a tracked `.env`.

### A2. Keys and credential files

```bash
git ls-files | grep -Ei '\.(pem|key|p12|pfx|jks|keystore)$|(^|/)(service-account|.*-credentials|.*firebase-adminsdk.*)\.json$|(^|/)\.vercel/'
```

Each tracked private key, certificate bundle with a key, or service-account
JSON: HIGH. A tracked `.vercel/` directory: MEDIUM (project and org IDs;
`.vercel` should be ignored).

### A3. NEXT_PUBLIC_ variables that look like secrets

```bash
. reports/.artifacts/nextjs-security-audit/scope/scan.sh
PUB='NEXT_PUBLIC_[A-Z0-9_]*(SECRET|PRIVATE|PASSWORD|PASSWD|SERVICE_ROLE|SERVICE_KEY|ADMIN|DATABASE|DB_|TOKEN|API_KEY|ACCESS_KEY|CLIENT_SECRET|WEBHOOK|SIGNING|JWT)[A-Z0-9_]*'
SCAN_MAX=40 scan js.src "NEXT_PUBLIC secret-like (code)" -E -o "$PUB"
SCAN_MAX=40 scan config "NEXT_PUBLIC secret-like (config/env/CI)" -E -o "$PUB"
```

Collect the distinct variable names. Classify each name:
- Contains `SECRET`, `PRIVATE`, `PASSWORD`, `SERVICE_ROLE`, `SERVICE_KEY`,
  `ADMIN`, `DATABASE`, `DB_`, `CLIENT_SECRET`, `SIGNING`, `JWT`,
  `WEBHOOK`: **HIGH** — a server secret shipped to every visitor.
- Contains `TOKEN`, `API_KEY`, `ACCESS_KEY`: **MEDIUM** unless the value
  or the provider's docs show it is a publishable key (then LOW /
  informational). Publishable-by-design examples: Stripe `pk_` keys,
  Supabase anon/publishable keys, Firebase web config `apiKey`, Sentry DSN,
  Algolia search-only keys, Mapbox public `pk.` tokens. Say which evidence
  you used; if unclear, keep MEDIUM and say "verify with the provider".

`NEXT_PUBLIC_SECRET_COUNT` = HIGH + MEDIUM names.

### A4. next.config `env` key

```bash
for c in $(grep -E '(^|/)next\.config\.[cm]?[jt]s$' reports/.artifacts/nextjs-security-audit/scope/config.lst); do
  echo "--- $c"; grep -nE '^\s*env\s*:\s*\{' -A15 "$c"
done
```

Every key under `env:` is public. A key whose name or value source looks
like a secret (`process.env.*SECRET*`, `*_KEY`, `*TOKEN*`, ...): HIGH
(`CONFIG_ENV_SECRET`). Non-secret values: informational.

### A5. Server secrets reachable from client code

```bash
. reports/.artifacts/nextjs-security-audit/scope/scan.sh
# Modules that read non-public secrets
SCAN_MAX=40 scan -v 'NEXT_PUBLIC_' js.src "Secret env reads" -E \
  'process\.env\.[A-Z0-9_]*(SECRET|PRIVATE|PASSWORD|TOKEN|KEY|DATABASE_URL|SERVICE_ROLE|DSN)'
# Which of those modules import 'server-only'
SCAN_MAX=60 scan js.src "server-only imports" -E "import ['\"]server-only['\"]"
SCAN_MAX=20 scan js.src "client-only imports" -E "import ['\"]client-only['\"]"
# Client components that read non-public env (reads as undefined; signals a wrong boundary)
SCAN_MAX=30 scan -v 'NEXT_PUBLIC_\|NODE_ENV' use_client "process.env in 'use client'" -E 'process\.env\.[A-Z]'
```

Then, for each module that reads a secret and has no `server-only` import,
check whether any `'use client'` file imports it (match the module's path
without extension in the import specifiers of the files in `use_client.lst`,
including `@/` aliases from `tsconfig.json` `paths`). Classify:
- Secret-reading module imported (directly) by a `'use client'` file: MEDIUM
  (the secret is undefined in the browser, but the code path and the
  boundary are wrong, and a later `NEXT_PUBLIC_` rename would leak it).
- Secret-reading module without `server-only`: LOW each (cap the list at 20).
- Secret passed as a prop to a Client Component or returned from a Server
  Action (read the file to confirm): HIGH.
- `process.env.X` (non-public) inside a `'use client'` file: LOW.

### A6. Browser source maps

```bash
grep -nE 'productionBrowserSourceMaps' $(grep -E 'next\.config' reports/.artifacts/nextjs-security-audit/scope/config.lst) 2>/dev/null
git ls-files | grep -E '^(.*/)?public/.*\.map$' | head
grep -nE 'withSentryConfig|hideSourceMaps|sourcemaps|deleteSourcemapsAfterUpload|widenClientFileUpload' \
  $(grep -E 'next\.config' reports/.artifacts/nextjs-security-audit/scope/config.lst) 2>/dev/null
```

- `productionBrowserSourceMaps: true`: MEDIUM (`PUBLIC_SOURCE_MAPS`) — full
  source is served to anyone. Informational if the project states it is
  open source.
- `.map` files committed under `public/`: MEDIUM.
- `@sentry/nextjs`: check that uploaded source maps are not also served
  publicly (option names differ by Sentry SDK major; confirm in the Sentry
  Next.js docs before judging). Unknown if unclear.

## PART B — SECRET DETECTION (hardcoded secrets, JS/TS and config)

```bash
. reports/.artifacts/nextjs-security-audit/scope/scan.sh
DROP='mock\|fake\|example\|sample\|placeholder\|dummy\|xxxx\|<your'
# HIGH: live secret formats
scan -v "$DROP" js.src "Private key block" -E -- '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'
scan -v "$DROP" config "Private key block (config)" -E -- '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'
scan -v "$DROP" js.src "Stripe/payment secret" -E 'sk_live_[0-9A-Za-z]{10,}|rk_live_[0-9A-Za-z]{10,}|whsec_[0-9A-Za-z]{10,}'
scan -v "$DROP" js.src "Cloud keys" -E 'AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|"private_key_id"'
scan -v "$DROP" js.src "Git/Slack/OpenAI-style tokens" -E 'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|xox[abpr]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9_-]{20,}|sk-ant-[A-Za-z0-9_-]{20,}'
scan -v "$DROP" js.src "Supabase service role / JWT literal" -E 'service_role|eyJ[A-Za-z0-9_-]{20,}\.eyJ[A-Za-z0-9_-]{20,}\.'
# HIGH/MEDIUM: assignments of literal secrets
scan -v "$DROP" js.src "Hardcoded secret assignment" -iE \
  "(secret|password|passwd|api_?key|token|auth_?key|private_?key)[A-Za-z_]*['\"]?[[:space:]]*[:=][[:space:]]*['\"][^'\"\$\{][^'\"]{7,}['\"]"
scan -v "$DROP" js.src "Credentials in connection string" -E '(postgres(ql)?|mysql|mongodb(\+srv)?|redis|amqp)://[^:/[:space:]]+:[^@/[:space:]]+@'
scan -v "$DROP" config "Credentials in connection string (config)" -E '(postgres(ql)?|mysql|mongodb(\+srv)?|redis|amqp)://[^:/[:space:]$]+:[^@/[:space:]$]+@'
# MEDIUM: test keys and weaker formats
scan -v "$DROP" js.src "Stripe test secret" -E 'sk_test_[0-9A-Za-z]{10,}'
scan -v "$DROP" js.src "Google API key literal" -E 'AIza[0-9A-Za-z_-]{35}'
# Pre-commit / gitleaks config (bonuses)
ls .gitleaks.toml .pre-commit-config.yaml .husky/pre-commit lefthook.yml 2>/dev/null
grep -nE 'gitleaks|detect-secrets|trufflehog|secretlint' .pre-commit-config.yaml .husky/pre-commit lefthook.yml package.json 2>/dev/null
```

Classify each match after reading the line (never print the secret value
in the artifact; show the first 4 characters and `…`):
- HIGH: live secret keys, private keys, tokens, service-role keys,
  credentials in connection strings, hardcoded secret assignments that are
  real values.
- MEDIUM: test-mode secret keys, cloud keys of unclear scope, `AIza` keys
  (often Firebase web keys, which are public by design — downgrade to LOW
  when the context is a Firebase web config).
- LOW: informational (variable names, obvious placeholders that slipped
  past the filter).
- `process.env.X` reads are **not** findings in Next.js server code.

If no issues are found, state: "No hardcoded secret patterns detected in
source code." — only next to a non-zero scope.

## ARTIFACT SAVE (mandatory)

Save the full output to: reports/.artifacts/nextjs-security-audit/step_06_secrets-and-env.md
Run before finishing: mkdir -p reports/.artifacts/nextjs-security-audit

Output format:
- **Scope** first: lines from `scope/summary.txt`
- **Part A — Sensitive File & Env Protection**
  - `ENV_FILES_TRACKED`: count + list (secret-looking values: yes/no, redacted)
  - `MISSING_ENV_IGNORE`: YES/NO + which patterns
  - `KEY_FILES_TRACKED`: count + list
  - `VERCEL_DIR_TRACKED`: YES/NO
  - `NEXT_PUBLIC_SECRET_HIGH` / `NEXT_PUBLIC_SECRET_MEDIUM`: count + names + file:line
  - `CONFIG_ENV_SECRET`: count + keys + file:line
  - `CLIENT_REACHABLE_SECRET_HIGH` (props / return values) and
    `CLIENT_IMPORTS_SECRET_MODULE` (MEDIUM): count + files
  - `SECRET_MODULES_WITHOUT_SERVER_ONLY`: count + files (LOW)
  - `SERVER_ONLY_USED`: YES/NO (bonus)
  - `PUBLIC_SOURCE_MAPS`: YES/NO + evidence
  - `ENV_EXAMPLE_SAFE`: YES/NO
- **Part B — Secret Detection**
  - Findings grouped HIGH / MEDIUM / LOW with file:line and pattern label
  - `SECRET_HIGH`, `SECRET_MEDIUM`, `SECRET_LOW` counts
  - `PRECOMMIT_SECRET_HOOK`: YES/NO; `GITLEAKS_CONFIG`: YES/NO
