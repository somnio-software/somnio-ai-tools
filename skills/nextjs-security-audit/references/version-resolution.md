# Next.js Installed Version Resolution

> Resolve the exact INSTALLED versions of next, react and the related packages from the lockfile (per app in a monorepo), plus the Node.js runtime. The version table this step writes is the only input step 3 may query advisories with.

---

Goal: Produce one row per (app, package) with the version that is actually
installed, its source, and the declared range for reference.

## RULES

- **The declared range is not the installed version.** A `package.json`
  entry such as `"next": "^<major>.<minor>.<patch>"` only says what may be
  installed. The lockfile says what is installed.
- **Never fill a version from memory.** If no lockfile and no
  `node_modules` exist, write `Unknown — no lockfile` and keep the declared
  range in its own column.
- **Monorepo:** resolve each app in `NEXTJS_APPS` separately. Two apps can
  pin different `next` versions in the same lockfile.
- Prefer the package manager's own listing; fall back to reading the
  lockfile; then to `node_modules/<pkg>/package.json`. Record which source
  was used for each row.

Read `PACKAGE_MANAGER`, `NEXTJS_APPS` and the lockfile list from
`reports/.artifacts/nextjs-security-audit/step_01_tool-installer.md`.

## PACKAGES

Always: `next`, `react`, `react-dom`.

When present (direct or transitive): `react-server-dom-webpack`,
`react-server-dom-turbopack`, `react-server-dom-parcel`, every `@next/*`
package, `eslint-config-next`, `next-auth`, every `@auth/*` package,
`sharp`, `@vercel/*` packages used at runtime.

Note: `next` bundles its own compiled copy of the React Server Components
runtime. A missing `react-server-dom-*` entry in the lockfile does not mean
the app does not use RSC; the `next` version is what decides it.

## 1. DECLARED RANGES

```bash
for app in $(echo "$NEXTJS_APPS" | tr '|' ' '); do
  echo "--- declared in $app/package.json ---"
  jq -r '((.dependencies // {}) + (.devDependencies // {})) | to_entries[]
    | select(.key | test("^(next|react|react-dom|react-server-dom-.*|@next/.*|eslint-config-next|next-auth|@auth/.*|sharp|@vercel/.*)$"))
    | "\(.key) \(.value)"' "$app/package.json"
done
# Overrides that force a version (they change what is installed)
jq '{pnpm_overrides: .pnpm.overrides, overrides: .overrides, resolutions: .resolutions}' package.json 2>/dev/null
grep -A20 -E '^overrides:' pnpm-workspace.yaml 2>/dev/null | head -25
```

## 2. INSTALLED VERSIONS

### pnpm

```bash
# Per app (workspace-aware). Works from the repo root.
for app in $(echo "$NEXTJS_APPS" | tr '|' ' '); do
  echo "--- installed in $app ---"
  (cd "$app" && pnpm list next react react-dom eslint-config-next next-auth sharp \
     '@next/*' '@auth/*' 'react-server-dom-*' --depth 0 --json 2>/dev/null) \
    | jq -r '.[] | [(.dependencies // {}), (.devDependencies // {})] | add // {}
       | to_entries[] | "\(.key) \(.value.version)"'
done
# Transitive copies (e.g. react-server-dom-* pulled by another package)
pnpm why react-server-dom-webpack --json 2>/dev/null | head -c 4000
```

Lockfile fallback (no `node_modules` needed): in `pnpm-lock.yaml`, the
`importers:` map has one key per workspace path (`.` or `apps/web`), and
each dependency has a `version:` line. The text before `(` is the version;
the parenthesised part lists peer resolutions.

```bash
awk -v app="$APP_KEY" '
  /^importers:/ {inimp=1; next}
  inimp && /^[^ ]/ {inimp=0}
  inimp && $0 ~ "^  "app":$" {inapp=1; next}
  inapp && /^  [^ ]/ {inapp=0}
  inapp && /^      (next|react|react-dom|eslint-config-next|next-auth|sharp|.@next\/[^:]+|.@auth\/[^:]+):/ {pkg=$1}
  inapp && pkg && /version:/ {print pkg, $2; pkg=""}
' pnpm-lock.yaml
```

(`APP_KEY` is the app path as written in `importers:`, `.` for the root.)

### npm

```bash
for app in $(echo "$NEXTJS_APPS" | tr '|' ' '); do
  echo "--- installed in $app ---"
  WS=""; [ "$app" != "." ] && WS="--workspace=$app"
  npm ls next react react-dom eslint-config-next next-auth sharp --all --json $WS 2>/dev/null \
    | jq -r 'paths(objects and has("version")) as $p
        | "\($p | map(select(. != "dependencies")) | join(" > ")) \(getpath($p).version)"' \
    | head -30
done
# Lockfile fallback: package-lock.json v2/v3 "packages" map
jq -r '.packages | to_entries[]
  | select(.key | test("(^|/)node_modules/(next|react|react-dom|react-server-dom-[^/]+|@next/[^/]+|eslint-config-next|next-auth|@auth/[^/]+|sharp)$"))
  | "\(.key) \(.value.version)"' package-lock.json
```

For the root app, use `npm ls` without `--workspace`. A key such as
`apps/web/node_modules/next` means that workspace has its own copy; the
hoisted `node_modules/next` is used otherwise.

### yarn

```bash
yarn why next 2>/dev/null | head -40          # classic and berry
yarn info next --json 2>/dev/null | head -c 2000   # berry: resolved version
# Lockfile fallback: each entry header lists the ranges, the next line(s) the version
grep -A3 -E '^"?(next|react|react-dom|eslint-config-next|next-auth|sharp)@' yarn.lock | grep -E '^"?[a-z@]|version'
```

### bun

```bash
bun pm ls 2>/dev/null | grep -E ' (next|react|react-dom|eslint-config-next|next-auth|sharp|@next/|@auth/)' | head -40
# bun.lock is JSONC text: the "packages" map holds "name": ["name@version", ...]
grep -E '"(next|react|react-dom|eslint-config-next|next-auth|sharp)": \["' bun.lock | head -20
```

A binary `bun.lockb` cannot be read as text; use `bun pm ls` or record
`Unknown`.

### node_modules fallback (any manager)

```bash
for app in $(echo "$NEXTJS_APPS" | tr '|' ' '); do
  for p in next react react-dom; do
    (cd "$app" && node -p "require('$p/package.json').version" 2>/dev/null | sed "s|^|$app $p |")
  done
done
```

## 3. NODE.JS RUNTIME

The runtime matters because an end-of-life Node.js line also receives no
security fixes. Record every declared target; do not treat the auditor's
local `node --version` as the deployed runtime.

```bash
cat .nvmrc .node-version 2>/dev/null
jq -r '.engines.node // empty' package.json $(echo "$NEXTJS_APPS" | tr '|' '\n' | sed 's|$|/package.json|') 2>/dev/null
grep -hE '^FROM .*node' Dockerfile* */Dockerfile* 2>/dev/null
grep -rhE 'node-version:|NODE_VERSION' .github/workflows .gitlab-ci.yml 2>/dev/null | head
jq -r '.functions // empty' vercel.json 2>/dev/null | head
```

Record the Node.js major per source. Step 3 checks its support status.

## ARTIFACT SAVE (mandatory)

Save the full output to: reports/.artifacts/nextjs-security-audit/step_02_version-resolution.md
Run before finishing: mkdir -p reports/.artifacts/nextjs-security-audit

Output format:

| App | Package | Declared range | Installed version | Source (pm list / lockfile / node_modules) | Direct or transitive |
|-----|---------|----------------|-------------------|--------------------------------------------|----------------------|

Then:
- `NEXT_MAJOR` per app (from the installed version)
- Overrides / resolutions that pin any of these packages
- Node.js runtime targets per source and their majors (`Unknown` if none)
- Rows that could not be resolved: `Unknown — <reason>`
