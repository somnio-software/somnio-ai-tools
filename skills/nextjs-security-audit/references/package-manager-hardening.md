# Next.js Package Manager Hardening (Supply Chain)

> Evaluate how well the package manager, lockfile and CI install protect the project against malicious or compromised packages. pnpm is the recommended package manager for its supply-chain controls. npm or yarn is a MEDIUM finding with a migration recipe, not a hard gate. Never modifies the repository.

---

Goal: Record the supply-chain posture of the install pipeline with evidence,
and give a ready-to-apply recipe for every gap.

Official references:
- https://pnpm.io/supply-chain-security
- https://pnpm.io/settings (build settings: https://pnpm.io/settings/build,
  resolution settings: https://pnpm.io/settings/dependency-resolution)

## BEFORE JUDGING ANY PNPM SETTING (MANDATORY)

pnpm setting names, where they are read from, and their defaults have
changed across pnpm majors (for example, the build-script allowlist moved
from `onlyBuiltDependencies` to `allowBuilds`, and most non-auth settings
moved from `.npmrc` to `pnpm-workspace.yaml`). So:

1. Find the pnpm version the project uses: the `packageManager` field
   (`pnpm@<version>`), else `pnpm --version` (run in the repo so Corepack
   picks the pinned one).
2. Open https://pnpm.io/settings and https://pnpm.io/supply-chain-security
   (WebFetch) and confirm, for that major, each key's name, its default
   and the file it is read from. If the docs describe a newer major than
   the installed one, say which major's rules you applied.
3. Judge the **effective** value: explicit setting if present, otherwise
   the documented default for the installed major. Where supported,
   `pnpm config get <key>` shows the effective value.
4. If you cannot confirm a key for the installed major, write `Unknown`
   for it; do not deduct for it.

## 1. PACKAGE MANAGER AND LOCKFILE

```bash
jq -r '.packageManager // "MISSING"' package.json
git ls-files | grep -E '(^|/)(pnpm-lock\.yaml|package-lock\.json|npm-shrinkwrap\.json|yarn\.lock|bun\.lockb?)$'
cat .gitignore 2>/dev/null | grep -nE 'lock' || true
```

Record:
- `PM`: pnpm / npm / yarn / bun (from step 1)
- `PACKAGE_MANAGER_FIELD`: present (value) / MISSING
- `COREPACK`: is Corepack used (CI `corepack enable`, Dockerfile, docs in
  `package.json` scripts)? YES / NO / Unknown
- `LOCKFILE_COMMITTED`: YES / NO (lockfile in `.gitignore` or untracked is NO)
- `SINGLE_LOCKFILE`: YES / NO (list every committed lockfile type)

## 2. CI INSTALL

```bash
grep -rnE '(pnpm|npm|yarn|bun) (install|ci|i)\b|--frozen-lockfile|--immutable|npm ci|corepack' \
  .github/workflows .gitlab-ci.yml bitbucket-pipelines.yml Dockerfile* */Dockerfile* 2>/dev/null | head -40
```

`CI_FROZEN_INSTALL`:
- pnpm: `pnpm install --frozen-lockfile` (pnpm also defaults to frozen
  in CI environments; still record whether the flag is explicit)
- npm: `npm ci`
- yarn berry: `yarn install --immutable`; yarn classic: `yarn install --frozen-lockfile`
- bun: `bun install --frozen-lockfile`

Values: YES (every install in CI/Dockerfile is frozen) / PARTIAL / NO /
`NO_CI` (no CI configuration found). Also record whether CI runs a
dependency audit (`pnpm audit`, `npm audit`, `osv-scanner`, Dependabot or
Renovate config) as `CI_DEP_SCANNING` and `DEP_UPDATE_TOOL`:

```bash
ls .github/dependabot.y*ml renovate.json renovate.json5 .renovaterc* .github/renovate.json 2>/dev/null
grep -rlE 'pnpm audit|npm audit|yarn (npm )?audit|osv-scanner|trivy|snyk' .github/workflows .gitlab-ci.yml bitbucket-pipelines.yml 2>/dev/null
```

## 3. PNPM SETTINGS (only when PM = pnpm)

```bash
pnpm --version
cat pnpm-workspace.yaml 2>/dev/null
cat .npmrc 2>/dev/null | sed -E 's/(_authToken|_auth|_password)=.*/\1=<redacted>/'
for k in minimumReleaseAge minimumReleaseAgeExclude blockExoticSubdeps allowBuilds \
         onlyBuiltDependencies strictDepBuilds dangerouslyAllowAllBuilds trustPolicy \
         trustPolicyExclude ignoreScripts; do
  printf '%s=' "$k"; pnpm config get "$k" 2>/dev/null || echo "n/a"
done
```

Evaluate each (names as confirmed for the installed major):

| Control | Good | Finding when |
|---|---|---|
| Release-age gate (`minimumReleaseAge`) | set to a delay (the pnpm docs suggest a week, `10080` minutes, for a longer wait) | effective value is `0` / unset with no default → LOW; long `minimumReleaseAgeExclude` lists → note |
| Build-script allowlist (`allowBuilds`, or `onlyBuiltDependencies` on majors that use it) | only the packages that need builds (e.g. `sharp`, `esbuild`) are allowed | `dangerouslyAllowAllBuilds: true` → MEDIUM; allowlist contains packages with no build need → LOW |
| Fail on unreviewed builds (`strictDepBuilds`) | effective `true` | effective `false` → LOW |
| Block exotic transitive sources (`blockExoticSubdeps`) | effective `true` | effective `false` → LOW |
| Trust downgrade check (`trustPolicy`) | `no-downgrade` | `off` → LOW (informational on majors where it does not exist) |
| `ignoreScripts` | used deliberately with an allowlist | not required; never recommend it if it breaks `sharp` / native builds |

## 4. NPM / YARN / BUN

If `PM` is not pnpm, record `PM_NOT_PNPM=YES` — a **MEDIUM** finding with
the migration recipe below (score deduction, not a hard gate). Also check
the controls that manager offers:
- npm: `.npmrc` `ignore-scripts=true` (with explicit `npm rebuild <pkg>`
  for packages that need it), `npm ci` in CI.
- yarn berry: `enableScripts: false` and `dependenciesMeta.<pkg>.built`,
  `--immutable` in CI.
- bun: `trustedDependencies` in `package.json` (bun runs lifecycle scripts
  only for trusted packages), `--frozen-lockfile` in CI.

Confirm each against the manager's current documentation before judging.

## 5. REGISTRY, TOKENS AND EXOTIC SOURCES (all managers)

```bash
# Committed registry config and auth tokens
git ls-files | grep -E '(^|/)\.npmrc$|(^|/)\.yarnrc(\.yml)?$' | while read -r f; do
  echo "--- $f"; grep -nE 'registry|_authToken|_auth|_password|npmAuthToken|always-auth' "$f" \
    | sed -E 's/((_authToken|_auth|_password|npmAuthToken)[=:][[:space:]]*).*/\1<redacted>/'
done
# git / tarball / http / file dependencies in every package.json
for f in $(git ls-files | grep -E '(^|/)package\.json$' | grep -v node_modules); do
  jq -r --arg f "$f" '((.dependencies // {}) + (.devDependencies // {}) + (.optionalDependencies // {}))
    | to_entries[] | select(.value | test("^(git|git\\+|github:|gitlab:|bitbucket:|https?://|file:)|\\.tgz$"))
    | "\($f)\t\(.key)\t\(.value)"' "$f"
done
# Lifecycle scripts in DIRECT dependencies (read from the installed manifests)
for app in $(echo "$NEXTJS_APPS" | tr '|' ' '); do
  for d in $(jq -r '((.dependencies // {}) + (.devDependencies // {})) | keys[]' "$app/package.json"); do
    m="$app/node_modules/$d/package.json"; [ -f "$m" ] || m="node_modules/$d/package.json"
    [ -f "$m" ] && jq -r --arg d "$d" '.scripts // {} | to_entries[]
      | select(.key | test("^(preinstall|install|postinstall)$")) | "\($d)\t\(.key)\t\(.value)"' "$m"
  done
done | sort -u
```

Classify:
- Auth token value (not a `${ENV_VAR}` reference) committed in `.npmrc` /
  `.yarnrc.yml`: **HIGH** (`COMMITTED_REGISTRY_TOKEN`). Never print the
  token in the artifact.
- `file:` / `link:` / `workspace:` paths inside the repository: internal,
  informational. Outside the repository: MEDIUM.
- `git`, `github:`, tarball or `http(s)` URL dependencies:
  `EXOTIC_DIRECT_DEPS` — MEDIUM each (pinned to a commit SHA: LOW).
- Non-default registry for unscoped packages, or a scope without a pinned
  registry (dependency-confusion risk): MEDIUM.
- `preinstall` / `install` / `postinstall` scripts in direct dependencies:
  `LIFECYCLE_SCRIPTS` — LOW each (informational when the manager's build
  allowlist already blocks it).

## 6. MIGRATION RECIPE (include when PM is npm or yarn)

Write this recipe in the artifact, adapted to the repository's real paths
(apps, Dockerfiles, workflow files). Every command is for the team to run;
this audit runs none of them.

```bash
# 1. Enable pnpm through Corepack and pin it in package.json
corepack enable
corepack use pnpm@latest          # writes "packageManager": "pnpm@<version>"

# 2. Convert the existing lockfile (reads package-lock.json, npm-shrinkwrap.json or yarn.lock)
pnpm import

# 3. Remove the old lockfile and install
git rm package-lock.json          # or: git rm yarn.lock
rm -rf node_modules
pnpm install

# 4. Build and test before committing; fix any phantom (undeclared) dependency
#    errors by adding the missing package to the app's package.json.
```

Hardened `pnpm-workspace.yaml` example (confirm every key for the pinned
pnpm major at https://pnpm.io/settings before applying; on majors that
still use `onlyBuiltDependencies`, use that list instead of `allowBuilds`):

```yaml
packages:
  - "apps/*"
  - "packages/*"

# Wait before installing newly published versions (minutes). 10080 = 1 week.
minimumReleaseAge: 10080
# minimumReleaseAgeExclude:
#   - "@your-org/*"

# Only these dependencies may run install/build scripts.
allowBuilds:
  sharp: true
  # esbuild: true
strictDepBuilds: true

# Transitive dependencies may not come from git or tarball URLs.
blockExoticSubdeps: true

# Fail when a package's publishing trust level drops.
trustPolicy: no-downgrade
```

For a single-app repository, omit `packages:` (or keep only `"."` if the
pnpm major requires it).

CI (GitHub Actions example):

```yaml
- uses: actions/checkout@v4
- uses: pnpm/action-setup@v4        # reads the packageManager field
- uses: actions/setup-node@v4
  with:
    node-version-file: .nvmrc
    cache: pnpm
- run: pnpm install --frozen-lockfile
- run: pnpm audit --audit-level high
```

Dockerfile changes:

```dockerfile
FROM node:<supported-lts>-alpine AS deps
WORKDIR /app
RUN corepack enable
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
# COPY .npmrc ./   # only if it holds no secrets; pass tokens as build secrets
RUN pnpm install --frozen-lockfile
```

Replace `npm ci` / `yarn install` in every Dockerfile stage and workflow,
and `npx` with `pnpm exec` / `pnpm dlx` in scripts.

## ARTIFACT SAVE (mandatory)

Save the full output to: reports/.artifacts/nextjs-security-audit/step_05_package-manager-hardening.md
Run before finishing: mkdir -p reports/.artifacts/nextjs-security-audit

Output format (one `KEY: value` line each, then evidence):
- `PM`, `PM_VERSION`, `PM_NOT_PNPM` (YES/NO)
- `PACKAGE_MANAGER_FIELD`, `COREPACK`
- `LOCKFILE_COMMITTED`, `SINGLE_LOCKFILE`
- `CI_FROZEN_INSTALL` (YES/PARTIAL/NO/NO_CI), `CI_DEP_SCANNING`, `DEP_UPDATE_TOOL`
- pnpm only: `PNPM_DOCS_MAJOR_CONFIRMED`, and per control the effective
  value and source (explicit / default / Unknown): `RELEASE_AGE_GATE`,
  `BUILD_ALLOWLIST`, `ALLOW_ALL_BUILDS`, `STRICT_DEP_BUILDS`,
  `BLOCK_EXOTIC_SUBDEPS`, `TRUST_POLICY`
- `COMMITTED_REGISTRY_TOKEN` (count, files — never values)
- `EXOTIC_DIRECT_DEPS` (count, list), `EXTERNAL_PATH_DEPS`, `INTERNAL_PATH_DEPS` (informational)
- `REGISTRY_CONFUSION_RISK` (YES/NO + evidence)
- `LIFECYCLE_SCRIPTS` (count, list)
- Findings with severity (HIGH/MEDIUM/LOW) and file:line evidence
- Migration recipe (when `PM_NOT_PNPM=YES`) and hardening snippet for each gap
