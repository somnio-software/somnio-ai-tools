# Next.js Tool Installer

> Install required tools for Next.js project analysis: nvm, Node.js, the package manager the repository declares (pnpm first), and testing utilities.

---

Goal: Verify required tools are present and properly configured. Only
install tools that are genuinely missing — never reinstall tools that
are already available.

INSTALLATION PHILOSOPHY:
- CHECK FIRST: Always verify if a tool is already installed before attempting installation
- CONFIGURE, DON'T REINSTALL: If a tool exists, configure it for the project — do not reinstall
- MINIMAL CHANGES: Only install what is genuinely missing
- VERSION PRESERVATION: Do not change globally installed tool versions unless required by version-alignment step
- NEVER MIGRATE THE REPO: Use the package manager the repository already
  uses. Never delete, convert or regenerate a lockfile, and never switch
  a project from npm/yarn to pnpm as part of the audit
- IDEMPOTENT: Running this installer multiple times must produce the same result without side effects

TOOLS TO INSTALL AND VERIFY:

1. **nvm (Node Version Manager)** — MANDATORY:
   - Check if nvm is installed: `command -v nvm > /dev/null 2>&1` (after
     sourcing `~/.nvm/nvm.sh` if it exists, since nvm is a shell function)
   - If missing, install via the official script from
     https://github.com/nvm-sh/nvm (use the install command published in
     its README for the current release)
   - Source nvm: `. ~/.nvm/nvm.sh`
   - Verify: `nvm --version`
   - **CRITICAL**: If nvm install fails, STOP execution and provide
     manual installation instructions.

2. **Node.js (via nvm)**:
   - Install LTS version as fallback: `nvm install --lts`
     (the project version is applied in `version-alignment.md`)
   - Verify: `node --version`

3. **Package Manager Detection (pnpm first)**:
   Detect the package manager from the lockfile and the `packageManager`
   field of the root `package.json`. Precedence:

   ```bash
   PM_FIELD="$(node -p "require('./package.json').packageManager || ''" 2>/dev/null)"
   if [ -f "pnpm-lock.yaml" ] || printf '%s' "$PM_FIELD" | grep -q '^pnpm@'; then
     PKG_MANAGER="pnpm"
   elif [ -f "yarn.lock" ] || printf '%s' "$PM_FIELD" | grep -q '^yarn@'; then
     PKG_MANAGER="yarn"
   elif [ -f "bun.lock" ] || [ -f "bun.lockb" ]; then
     PKG_MANAGER="bun"
   elif [ -f "package-lock.json" ]; then
     PKG_MANAGER="npm"
   else
     PKG_MANAGER="none"   # no lockfile at all — a finding on its own
   fi
   echo "Detected package manager: $PKG_MANAGER (packageManager field: ${PM_FIELD:-unset})"
   ```

   - **pnpm** (preferred stack default): enable it through Corepack so the
     exact version pinned in `packageManager` is used:
     ```bash
     corepack enable
     pnpm --version
     ```
     If `corepack` is unavailable on the active Node.js, fall back to
     `npm install -g pnpm` and note it in the output.
   - **yarn**: `corepack enable` (Yarn Berry honours `packageManager`);
     only if that fails and `yarn.lock` exists, `npm install -g yarn`.
   - **npm**: bundled with Node.js — verify with `npm --version`.
   - **bun**: verify `bun --version`; if missing, note it — do not
     install a different package manager in its place.
   - **none**: no lockfile is committed. Do not create one. Record the
     finding (see below) and use `npm install --no-package-lock` only if
     dependencies are needed for coverage.

   Record these findings for the report (they feed the Tech Stack and
   CI/CD sections, not a new section):
   - `PACKAGE MANAGER FINDING: not using pnpm (uses <npm|yarn|bun|none>)`
     whenever the detected package manager is not pnpm. This is a
     recommendation, never a reason to migrate during the audit.
   - `PACKAGE MANAGER FINDING: packageManager field missing` when the root
     `package.json` has no `packageManager` pin (Corepack cannot
     guarantee a reproducible package-manager version).
   - `PACKAGE MANAGER FINDING: multiple lockfiles (<list>)` when more
     than one lockfile is committed.

4. **Monorepo tooling (detect, do not install globally)**:
   - pnpm workspaces: `pnpm-workspace.yaml`
   - npm/yarn workspaces: `"workspaces"` in root `package.json`
   - Turborepo: `turbo.json` (run through `pnpm exec turbo` / `npx turbo`,
     never a global install)
   - Nx: `nx.json`

5. **Next.js-specific analysis tools**:
   - Check for `npx` availability: `npx --version`
   - The `next` CLI comes from the project's own dependencies
     (`pnpm exec next --version` / `npx next --version`) — never install
     it globally
   - For coverage analysis: ensure jest/vitest is available as a
     dev dependency (do NOT install globally)

VERIFICATION CHECKLIST:
- nvm: installed and sourced
- node: version available
- Package manager: detected from lockfile / `packageManager`, enabled via Corepack when pnpm or yarn
- Project dependencies: ready to install (installation happens in `version-alignment.md`)

ERROR HANDLING:
- If nvm fails to install: STOP and provide manual steps
- If Node.js fails to install via nvm: STOP and provide resolution
- If the package manager cannot be enabled: attempt the fallback, warn if it fails
- Document all tool versions installed in the audit report

OUTPUT:
- List of tools installed with versions
- Package manager detected, its version, and the `packageManager` field value
- Package-manager findings (not using pnpm / no pin / multiple lockfiles / no lockfile)
- Monorepo tooling detected (pnpm workspaces / npm or yarn workspaces / Turborepo / Nx / none)
- Any errors or warnings encountered
- Ready status for version alignment step
