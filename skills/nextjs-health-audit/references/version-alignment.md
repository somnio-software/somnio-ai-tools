# Next.js Version Alignment

> Mandatory Node.js version alignment requirement for any Next.js project analysis (single app or monorepo). Ensures the Node.js version matches project requirements and installs dependencies with the repository's own package manager and lockfile.

---

MANDATORY STEP 0: Execute Node.js Version Alignment Requirement
before any Next.js project analysis.

CRITICAL REQUIREMENT: This rule MUST configure nvm to use the
project's Node.js version. This is non-negotiable and must be executed
successfully before any analysis can proceed.

LOCKFILE RULE (NON-NEGOTIABLE):
- NEVER delete, regenerate or convert a lockfile (`pnpm-lock.yaml`,
  `package-lock.json`, `yarn.lock`, `bun.lock`). The lockfile is the
  evidence the dependency-security step reads.
- Install with the frozen/immutable flag so the install reproduces the
  lockfile exactly. If a frozen install fails because the lockfile is out
  of date with `package.json`, record `LOCKFILE OUT OF SYNC` as a finding
  and only then fall back to a non-frozen install, without committing or
  keeping lockfile changes (`git checkout -- <lockfile>` afterwards).

This rule applies to ANY Next.js project regardless of versions found:

MONOREPO DETECTION:
- First detect repository structure: single app or monorepo
  (`pnpm-workspace.yaml`, `"workspaces"` in root `package.json`,
  `turbo.json`, `nx.json`, `lerna.json`, or an `apps/` + `packages/`
  layout)
- Identify every workspace package that depends on `next` — those are
  the Next.js apps to analyze
- In a workspace monorepo, ONE install at the root installs every
  package. Never run per-directory installs inside a pnpm/yarn/npm
  workspace — that creates stray lockfiles and nested `node_modules`.

SINGLE APP VERSION ALIGNMENT:
1. **Extract Project Node.js Version**:
   - Read `package.json` and extract the Node.js version from `engines.node`
   - Check for `.nvmrc` file for nvm-specific version
   - Check for `.node-version` file
   - Check `volta.node` in `package.json` if present
   - If no version is specified, use the active LTS and record
     `Node.js version not pinned` as a finding
   - Note: the installed `next` major declares its own minimum Node.js in
     `node_modules/next/package.json` (`engines.node`) once dependencies
     are installed — compare the project pin against it and flag a pin
     below that minimum

2. **Check Current Node.js Version**:
   - Run `node --version 2>/dev/null` to get current Node.js version
   - Compare with project requirement

3. **Version Mismatch Detection**:
   - If versions differ: ALIGNMENT REQUIRED
   - If versions match: Continue with analysis
   - If nvm is not installed: Error, nvm should be installed by
     `references/tool-installer.md`

4. **Smart Dependency Check** (SKIP REINSTALL IF ALIGNED):
   - If version ALREADY MATCHES the project requirement:
     * Check if `node_modules/` exists at root
     * Check that the lockfile exists
     * If BOTH exist: SKIP reinstall — dependencies are already in place
     * If `node_modules/` is missing: install ONLY (no version change needed)
     * Log: "Version aligned, dependencies intact — skipping reinstall"
   - If version DOES NOT MATCH: proceed with full version alignment (step 5)

5. **Execute Version Alignment** (MANDATORY nvm CONFIGURATION):
   - Verify nvm is present (installed by `references/tool-installer.md`)
   - Install required Node.js version via nvm:
     `nvm install <version> > /dev/null 2>&1`
   - Use Node.js version: `nvm use <version> > /dev/null 2>&1`
   - Verify alignment with `node --version 2>/dev/null`
   - Re-enable Corepack on the new Node.js (`corepack enable`) — Corepack
     shims are per Node.js installation
   - Remove `node_modules` only (native modules such as `sharp` are built
     per Node.js ABI): `rm -rf node_modules`. Keep the lockfile.
   - Install dependencies with the frozen command (see COMPREHENSIVE
     DEPENDENCY MANAGEMENT below)

MONOREPO VERSION ALIGNMENT:
1. **Extract Project Node.js Versions**:
   - Read the root `package.json` (`engines.node`), root `.nvmrc` /
     `.node-version`
   - For each workspace package that depends on `next`, read its
     `package.json` `engines.node` and any package-level `.nvmrc`

2. **Version Consistency Analysis**:
   - Compare Node.js versions across apps and packages
   - Identify version conflicts between apps/packages
   - Determine the target Node.js version (the root pin if present,
     otherwise the highest pin among the Next.js apps)

3. **Check Current Node.js Version**, **Version Mismatch Detection** and
   **Smart Dependency Check**: as in the single-app flow, checking the
   root `node_modules/` and the root lockfile

4. **Execute Version Alignment**: as in the single-app flow, with ONE
   frozen install at the workspace root

5. **Documentation**:
   - Log the version change process
   - Document any alignment issues or failures
   - Document version consistency across apps/packages
   - Note any version conflicts that require resolution

COMPREHENSIVE DEPENDENCY MANAGEMENT:
After setting the nvm version, install dependencies with the
repository's own package manager (pnpm first):

```bash
# Detect package manager (same precedence as tool-installer.md)
if [ -f "pnpm-lock.yaml" ]; then
  PKG_MANAGER="pnpm"
  corepack enable > /dev/null 2>&1
  INSTALL_CMD="pnpm install --frozen-lockfile"
elif [ -f "yarn.lock" ]; then
  PKG_MANAGER="yarn"
  corepack enable > /dev/null 2>&1
  # Yarn Berry uses --immutable; Yarn 1 uses --frozen-lockfile
  if yarn --version 2>/dev/null | grep -q '^1\.'; then
    INSTALL_CMD="yarn install --frozen-lockfile"
  else
    INSTALL_CMD="yarn install --immutable"
  fi
elif [ -f "bun.lock" ] || [ -f "bun.lockb" ]; then
  PKG_MANAGER="bun"
  INSTALL_CMD="bun install --frozen-lockfile"
elif [ -f "package-lock.json" ]; then
  PKG_MANAGER="npm"
  INSTALL_CMD="npm ci"
else
  PKG_MANAGER="npm"
  INSTALL_CMD="npm install --no-package-lock"
  echo "PACKAGE MANAGER FINDING: no lockfile committed"
fi

echo "Detected package manager: $PKG_MANAGER"
[ "$PKG_MANAGER" != "pnpm" ] && echo "PACKAGE MANAGER FINDING: not using pnpm (uses $PKG_MANAGER)"

# Smart dependency check - skip if already installed
if [ -d "node_modules" ]; then
  echo "Dependencies already installed — skipping reinstall"
else
  echo "Installing dependencies at the workspace root: $INSTALL_CMD"
  if ! $INSTALL_CMD > "${TMPDIR:-/tmp}/nextjs-audit-install.log" 2>&1; then
    echo "LOCKFILE OUT OF SYNC or install failure — see log"
    tail -20 "${TMPDIR:-/tmp}/nextjs-audit-install.log"
  fi
fi
```

If the frozen install fails, record the last lines of the log as
evidence, then retry once without the frozen flag only to unblock the
analysis, and restore the lockfile afterwards
(`git checkout -- <lockfile>`). Never leave modified lockfiles behind.

CRITICAL: nvm CONFIGURATION IS MANDATORY:
- If nvm is missing, STOP execution and advise running
  `references/tool-installer.md`
- If Node.js version installation via nvm fails, STOP execution and
  provide resolution steps
- If version setting fails, STOP execution and provide troubleshooting
  steps

OUTPUT:
- Node.js version required (source: `.nvmrc` / `.node-version` / `engines.node` / not pinned)
- Node.js version active
- Package manager and the exact install command used
- Install result: frozen install succeeded / lockfile out of sync / failed
- Package-manager findings (not using pnpm, no lockfile, lockfile out of sync)
- Monorepo: workspace tool and the list of Next.js apps

Why This Is Critical:
- Prevents Build Failures: Version mismatches cause compilation errors
- Ensures Accurate Analysis: Different Node.js versions have different
  capabilities, and each `next` major declares a minimum Node.js
- Avoids False Positives: Analysis results depend on the correct
  Node.js version and the exact locked dependency tree
