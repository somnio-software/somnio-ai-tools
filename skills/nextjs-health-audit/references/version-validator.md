# Next.js Version Validator

> Verify nvm setup, validate Node.js version alignment, confirm dependencies are installed from the lockfile, and run a non-blocking `next build` and type check.

---

Goal: Verify that nvm configuration succeeded and all project
dependencies are properly installed before analysis proceeds.

VALIDATION STEPS:

1. **nvm Setup Verification**:
   - Verify nvm is sourced and available: `nvm --version`
   - Confirm the correct Node.js version is active: `node --version`
   - Cross-check version matches `.nvmrc`, `.node-version`, or
     `package.json#engines.node`
   - Compare against the installed Next.js minimum:
     `node -p "require('next/package.json').engines.node"` (run from the
     Next.js app directory in a monorepo)
   - If mismatch detected: attempt re-alignment, then STOP if it fails

2. **Package Manager Detection and Validation**:
   - Detect lockfile: `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn,
     `bun.lock`/`bun.lockb` → bun, `package-lock.json` → npm
   - Run the package manager version check and compare it with the
     `packageManager` field of the root `package.json`
   - Confirm the frozen install from `version-alignment.md` succeeded
     (lockfile in sync with `package.json`)
   - Confirm no lockfile was modified: `git status --porcelain -- '*lock*'`
     must print nothing. If it prints a change, restore it and record it.

3. **Dependency Installation Verification**:
   - Check `node_modules` exists in the project root
   - List top-level packages: `pnpm list --depth 0` / `npm ls --depth=0` /
     `yarn list --depth=0` (Yarn 1) / `yarn info --name-only` (Yarn Berry)
   - Record the INSTALLED versions of `next`, `react` and `react-dom`
     from the package manager (not from the `package.json` range):
     ```bash
     pnpm list next react react-dom --depth 0 --json   # pnpm
     npm ls next react react-dom --json                # npm
     ```
     In a monorepo, run it per Next.js app (`pnpm --filter <app> list ...`)
   - Check for peer dependency warnings involving `react`/`react-dom`/`next`

4. **Build Verification** (optional, non-blocking):
   - If a `build` script exists in `package.json`, run it with the
     project's package manager: `pnpm build` / `npm run build` /
     `yarn build` (in a Turborepo monorepo, `pnpm exec turbo run build
     --filter=<app>`)
   - The `build` script normally runs `next build`. Note the bundler it
     uses (`next build` defaults to Turbopack on recent majors; a
     `--webpack` flag or a custom `webpack` config means webpack)
   - Missing required environment variables are a common cause of build
     failure: record the error, do not create a `.env` with invented values
   - Log build success or failure (do NOT stop execution on build fail)
   - From the build output, keep: the route table (static / dynamic /
     partially prerendered markers) and any warnings — they feed the
     Architecture and Performance sections
   - Build failure should be noted in the report as a risk

5. **Type Checking** (optional, non-blocking):
   - If a `typecheck` / `type-check` / `tsc` script exists, run it;
     otherwise `npx tsc --noEmit` when `tsconfig.json` exists
   - Count TypeScript errors: note in report
   - Note whether `next.config.*` sets `typescript.ignoreBuildErrors`
     (the build would hide these errors — a red flag reported by
     `config-analysis.md`)
   - Do NOT stop execution on type errors

OUTPUT:
- Node.js version confirmed: [Version] (Next.js minimum: [range from next/package.json])
- Package manager: [pnpm/npm/yarn/bun] [Version] (packageManager field: [value or unset])
- Lockfile in sync / unmodified: [Yes/No]
- Installed versions (from the package manager): next [X.Y.Z], react [X.Y.Z], react-dom [X.Y.Z] — per app in a monorepo
- Dependencies installed: [Yes/No]
- Build status: [Success/Failed/Skipped] (bundler: [Turbopack/webpack/Unknown])
- TypeScript errors: [XX or Skipped]
- Ready for analysis: [Yes/No]
