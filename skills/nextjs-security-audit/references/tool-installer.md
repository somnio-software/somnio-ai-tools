# Next.js Security Tool Installer

> Confirm the project is a Next.js project, detect every Next.js app, the package manager and the router type, check the security toolchain, and build the source scope for the code-scanning steps. MANDATORY first step.

---

Goal: Confirm `next` is a dependency, record every Next.js app (monorepo
aware), detect the package manager by lockfile, check (and where possible
install) the tools later steps use, and write the source scope.

This step never modifies the audited repository. Installing a tool on the
machine (Homebrew, Corepack) is allowed; running an install that rewrites
`package.json` or a lockfile is not.

## 1. NEXT.JS DETECTION (MANDATORY - stop if absent)

```bash
echo "=== NEXT.JS DETECTION ==="
APPS=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  MANIFESTS=$(git ls-files | grep -E '(^|/)package\.json$' | grep -v node_modules)
else
  MANIFESTS=$(find . -name package.json -not -path '*/node_modules/*' | sed 's|^\./||')
fi
for f in $MANIFESTS; do
  if jq -e '((.dependencies // {}) + (.devDependencies // {})) | has("next")' "$f" >/dev/null 2>&1 \
     || { ! command -v jq >/dev/null 2>&1 && grep -qE '"next"[[:space:]]*:' "$f"; }; then
    d=$(dirname "$f")
    case " $APPS " in *" $d "*) ;; *) APPS="$APPS $d" ;; esac
  fi
done
APPS=$(echo $APPS)
if [ -z "$APPS" ]; then
  echo "NEXTJS_DETECTED=NO"
else
  echo "NEXTJS_DETECTED=YES"
  echo "NEXTJS_APPS=$(echo "$APPS" | tr ' ' '|')"
fi
```

If `NEXTJS_DETECTED=NO`: write the artifact with that line and the message
below, then STOP the audit (MANDATORY step failure). Do not run any other
step.

```
No package.json in this repository declares "next". This skill audits
Next.js projects only. Run the framework-agnostic `security-audit` skill
instead (e.g. `somnio run security-audit`).
```

A package that lists `next` only in `peerDependencies` is a library, not an
app: it is not in `NEXTJS_APPS`. If `jq` is missing, the grep fallback
cannot tell the two apart; confirm each match by reading the manifest.

## 2. PER-APP FACTS

For each app path in `NEXTJS_APPS` record:

```bash
for app in $(echo "$NEXTJS_APPS" | tr '|' ' '); do
  echo "--- app: $app ---"
  # Router type
  ls -d "$app/app" "$app/src/app" 2>/dev/null | sed 's/^/APP_ROUTER_DIR=/'
  ls -d "$app/pages" "$app/src/pages" 2>/dev/null | sed 's/^/PAGES_ROUTER_DIR=/'
  # Middleware / proxy (proxy.ts is the newer name of middleware.ts)
  ls "$app"/middleware.[jt]s "$app"/src/middleware.[jt]s "$app"/proxy.[jt]s "$app"/src/proxy.[jt]s 2>/dev/null \
    | sed 's/^/EDGE_FILE=/' || true
  # next.config
  ls "$app"/next.config.* 2>/dev/null | sed 's/^/NEXT_CONFIG=/'
  # Deployment hints (evidence only; never assume the hosting provider)
  ls "$app/vercel.json" vercel.json "$app/Dockerfile" Dockerfile netlify.toml \
     "$app/open-next.config.ts" 2>/dev/null | sed 's/^/DEPLOY_HINT=/'
  grep -hoE '"output"[[:space:]]*:[[:space:]]*"[a-z]+"|output:[[:space:]]*["'"'"'][a-z]+' "$app"/next.config.* 2>/dev/null \
    | sed 's/^/OUTPUT_MODE=/'
done
```

## 3. PACKAGE MANAGER DETECTION (by lockfile)

Look for lockfiles at the repository root and in each app directory (a
monorepo usually has one lockfile at the root).

```bash
echo "=== PACKAGE MANAGER ==="
for dir in . $(echo "$NEXTJS_APPS" | tr '|' ' '); do
  for lf in pnpm-lock.yaml package-lock.json npm-shrinkwrap.json yarn.lock bun.lock bun.lockb; do
    [ -f "$dir/$lf" ] && echo "LOCKFILE=$dir/$lf (tracked: $(git ls-files --error-unmatch "$dir/$lf" >/dev/null 2>&1 && echo yes || echo NO))"
  done
done | sort -u
jq -r '.packageManager // "none"' package.json 2>/dev/null | sed 's/^/PACKAGE_MANAGER_FIELD=/'
ls pnpm-workspace.yaml .npmrc .yarnrc.yml .yarnrc bunfig.toml 2>/dev/null | sed 's/^/PM_CONFIG=/'
```

Resolve `PACKAGE_MANAGER` with this precedence:
1. `pnpm-lock.yaml` → `pnpm`
2. `package-lock.json` / `npm-shrinkwrap.json` → `npm`
3. `yarn.lock` → `yarn` (record yarn classic vs berry: `.yarnrc.yml` or a
   `packageManager` of `yarn@` with a major above 1 means berry)
4. `bun.lock` / `bun.lockb` → `bun`
5. No lockfile → `NONE` (a finding for step 5)

If more than one lockfile type exists, record `MULTIPLE_LOCKFILES=YES` with
the list; use the one that matches the `packageManager` field, else the
first in the order above.

## 4. TOOL CHECK (install when possible, skip gracefully)

| Tool | Used by | Required? |
|------|---------|-----------|
| `jq` | steps 2-5 (JSON parsing) | strongly recommended |
| `curl` | step 3 (live sources) | required for live lookups |
| `gh` | step 3 (GitHub advisories, authenticated) | optional (`curl` fallback) |
| `pnpm` (via Corepack) | steps 2, 4, 5 when the project uses pnpm | required for pnpm projects |
| `osv-scanner` | step 4 | optional |
| `gitleaks` | step 9 | optional |
| `trivy` | step 10 | optional |

```bash
echo "=== TOOLS ==="
for t in jq curl gh node pnpm npm yarn bun osv-scanner gitleaks trivy; do
  if command -v "$t" >/dev/null 2>&1; then
    v=$("$t" --version 2>/dev/null | head -1)
    echo "TOOL $t: INSTALLED ($v)"
  else
    echo "TOOL $t: NOT_INSTALLED"
  fi
done
gh auth status >/dev/null 2>&1 && echo "GH_AUTH=YES" || echo "GH_AUTH=NO"
```

Install attempts (only for tools that are missing; never fail the step):

```bash
# pnpm through Corepack (ships with Node.js); only needed for pnpm projects.
# `corepack enable` changes the machine, not the repo. Corepack reads the
# version from the packageManager field when present.
if [ "$PACKAGE_MANAGER" = "pnpm" ] && ! command -v pnpm >/dev/null 2>&1; then
  corepack enable pnpm 2>/dev/null && echo "pnpm: enabled via corepack" \
    || echo "pnpm: NOT_INSTALLED (run: corepack enable pnpm)"
fi

# Homebrew installs for the optional scanners (macOS / Linuxbrew)
if command -v brew >/dev/null 2>&1; then
  for t in jq gh osv-scanner gitleaks trivy; do
    command -v "$t" >/dev/null 2>&1 || brew install "$t" >/dev/null 2>&1 \
      && echo "$t: available" || echo "$t: install failed (continue without it)"
  done
else
  echo "Homebrew not available. Install instructions:"
  echo "  osv-scanner: https://google.github.io/osv-scanner/installation/"
  echo "  gitleaks:    https://github.com/gitleaks/gitleaks#installing"
  echo "  trivy:       https://trivy.dev/latest/getting-started/installation/"
  echo "  gh:          https://cli.github.com/"
  echo "  jq:          https://jqlang.org/download/"
fi
```

If an install needs interactive confirmation or elevated rights, skip it and
record the instruction. A missing optional tool is INFO, not a failure.

## 5. SOURCE SCOPE

Which files the code-scanning steps (6, 7, 8) read: tracked JS/TS files,
excluding dependencies, build outputs and generated code.

```bash
S=reports/.artifacts/nextjs-security-audit/scope
mkdir -p "$S"
find "$S" -name '*.lst' -delete

BUILD_RE='(^|/)(node_modules|dist|build|out|\.next|\.vercel|\.turbo|\.open-next|coverage|storybook-static)/|\.min\.js$|\.d\.ts$|\.map$'
TEST_RE='(^|/)(test|tests|__tests__|__mocks__|e2e|cypress|playwright)/|\.(test|spec|stories)\.[cm]?[jt]sx?$'

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  SCOPE_SOURCE="git ls-files (tracked files only)"
  git ls-files | grep -Ev "$BUILD_RE" > "$S/tracked.lst"
else
  SCOPE_SOURCE="find (not a git repo: untracked files included)"
  find . -type f -not -path './.git/*' -not -path '*/node_modules/*' | sed 's|^\./||' | grep -Ev "$BUILD_RE" > "$S/tracked.lst"
fi

grep -E '\.[cm]?[jt]sx?$' "$S/tracked.lst" > "$S/js.all.lst"
grep -Ev "$TEST_RE" "$S/js.all.lst" > "$S/js.src.lst"
# Config and infra files scanned for secrets/headers/supply chain
grep -E '(^|/)(next\.config\.[cm]?[jt]s|vercel\.json|netlify\.toml|\.npmrc|\.yarnrc(\.yml)?|pnpm-workspace\.yaml|package\.json|Dockerfile[^/]*|docker-compose[^/]*\.ya?ml|\.env[^/]*)$|^\.github/workflows/|^\.gitlab-ci\.yml$|^bitbucket-pipelines\.yml$' \
  "$S/tracked.lst" | grep -v node_modules > "$S/config.lst"
# Next.js entry points
grep -E '(^|/)app/(.*/)?route\.[cm]?[jt]sx?$' "$S/js.src.lst" > "$S/route_handlers.lst"
grep -E '(^|/)pages/api/' "$S/js.src.lst" > "$S/api_routes.lst"
grep -E '(^|/)(src/)?(middleware|proxy)\.[cm]?[jt]s$' "$S/js.src.lst" > "$S/edge.lst"
tr '\n' '\0' < "$S/js.src.lst" | xargs -0 grep -lE "^[[:space:]]*['\"]use server['\"]" 2>/dev/null > "$S/use_server.lst"
tr '\n' '\0' < "$S/js.src.lst" | xargs -0 grep -lE "^[[:space:]]*['\"]use client['\"]" 2>/dev/null > "$S/use_client.lst"
tr '\n' '\0' < "$S/js.src.lst" | xargs -0 grep -lE "['\"]use server['\"]" 2>/dev/null | sort -u > "$S/server_fn.lst"

{
  echo "SCOPE_SOURCE=$SCOPE_SOURCE"
  echo "EXCLUDED=dependencies, build outputs, generated code, tests (Gitleaks still scans tests)"
  for l in js.src js.all config route_handlers api_routes edge use_server use_client server_fn; do
    echo "SOURCE_SCOPE $l: $(wc -l < "$S/$l.lst" | tr -d ' ') files"
  done
} | tee "$S/summary.txt"

cat > "$S/scan.sh" <<'EOF'
S=reports/.artifacts/nextjs-security-audit/scope
scope_count() { if [ -f "$S/$1.lst" ]; then wc -l < "$S/$1.lst" | tr -d ' '; else echo 0; fi; }
# scan [-v DROP_REGEX] <list> <label> <grep args...>
#   <list> is one of the scope lists (js.src, js.all, config, route_handlers,
#   api_routes, edge, use_server, use_client, server_fn).
#   Prints up to SCAN_MAX (default 20) matches, then always one summary line.
scan() {
  drop='^$'
  if [ "$1" = "-v" ]; then drop=$2; shift 2; fi
  list=$1; label=$2; shift 2
  n=$(scope_count "$list")
  if [ "$n" -eq 0 ]; then echo "[$label] not applicable: 0 files in scope ($list)"; return 0; fi
  out=$(tr '\n' '\0' < "$S/$list.lst" | xargs -0 grep -Hn "$@" 2>/dev/null | grep -v -- "$drop")
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | head -n "${SCAN_MAX:-20}"
    echo "[$label] $(printf '%s\n' "$out" | wc -l | tr -d ' ') match(es) across $n files ($list)"
  else
    echo "[$label] 0 matches across $n files ($list)"
  fi
}
EOF
```

## ARTIFACT SAVE (mandatory)

Save the full output to: reports/.artifacts/nextjs-security-audit/step_01_tool-installer.md
Run before finishing: mkdir -p reports/.artifacts/nextjs-security-audit

Output format (in artifact):
- `NEXTJS_DETECTED`: YES or NO (if NO, the stop message and nothing else)
- `NEXTJS_APPS`: pipe-separated app paths (e.g. `.` or `apps/web|apps/admin`)
- Per app: router type(s) (App Router / Pages Router / both), middleware or
  proxy file, next.config file, output mode, deployment hints (evidence only)
- `PACKAGE_MANAGER`: pnpm / npm / yarn (classic|berry) / bun / NONE
- Lockfiles found and whether each is tracked; `MULTIPLE_LOCKFILES`
- `packageManager` field value; package manager config files present
- Tool table: each tool INSTALLED (version) / NOT_INSTALLED (+ install
  instruction); `GH_AUTH`
- SOURCE SCOPE: the contents of `scope/summary.txt` verbatim. The lists and
  `scan.sh` stay in `reports/.artifacts/nextjs-security-audit/scope/` for
  steps 6-8.
