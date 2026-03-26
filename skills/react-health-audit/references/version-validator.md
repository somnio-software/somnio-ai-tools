# React Version Validator

> Verify nvm setup, validate Node.js version alignment, and confirm all project dependencies are installed correctly.

---

Goal: Verify that nvm configuration succeeded and all project
dependencies are properly installed before analysis proceeds.

VALIDATION STEPS:

1. **nvm Setup Verification**:
   - Verify nvm is sourced and available: `nvm --version`
   - Confirm the correct Node.js version is active: `node --version`
   - Cross-check version matches `.nvmrc`, `.node-version`, or
     `package.json#engines.node`
   - If mismatch detected: attempt re-alignment, then STOP if fails

2. **Package Manager Detection and Validation**:
   - Detect lock file: pnpm-lock.yaml → pnpm, yarn.lock → yarn,
     package-lock.json → npm
   - Run package manager version check
   - Verify lock file is up-to-date with `package.json`

3. **Dependency Installation Verification**:
   - Check `node_modules` exists in project root
   - Run `npm list --depth=0` (or equivalent) to verify packages
   - Check for peer dependency warnings
   - If apps/ or packages/ exist, verify each has `node_modules`

4. **Build Verification** (optional, non-blocking):
   - If `build` script exists in `package.json`, attempt:
     `npm run build > /dev/null 2>&1`
   - Log build success or failure (do NOT stop execution on build fail)
   - Build failure should be noted in the report as a risk

5. **Type Checking** (optional, non-blocking):
   - If `typecheck` or `tsc` script exists:
     `npm run typecheck > /dev/null 2>&1` or `npx tsc --noEmit`
   - Count TypeScript errors: note in report
   - Do NOT stop execution on type errors

OUTPUT:
- Node.js version confirmed: [Version]
- Package manager: [npm/yarn/pnpm] [Version]
- Dependencies installed: [Yes/No]
- Build status: [Success/Failed/Skipped]
- TypeScript errors: [XX or Skipped]
- Ready for analysis: [Yes/No]
