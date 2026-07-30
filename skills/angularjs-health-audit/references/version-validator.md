# AngularJS Version Validator

> Verify nvm setup, validate Node.js version alignment, and confirm all project dependencies (npm + Bower) are installed correctly.

---

Goal: Verify that nvm configuration succeeded and all project
dependencies are properly installed before analysis proceeds.

VALIDATION STEPS:

1. **nvm Setup Verification**:
   - Verify nvm is sourced and available: `nvm --version`
   - Confirm the correct Node.js version is active: `node --version`
   - Cross-check the version matches `.nvmrc`, `.node-version`, or
     `package.json#engines.node`
   - If a mismatch is detected: attempt re-alignment, then STOP if it fails

2. **Package Manager Detection and Validation**:
   - Detect the Node manager: `yarn.lock` → yarn, otherwise npm
   - Detect Bower usage: `bower.json` present
   - Run the manager version checks (`npm --version`, `bower --version` if used)
   - Verify the lock file is consistent with `package.json`

3. **Dependency Installation Verification**:
   - Check `node_modules/` exists in the project root
   - Run `npm list --depth=0` (or `yarn list --depth=0`) to verify packages
   - If `bower.json` is present, check `bower_components/` exists and
     optionally run `bower list`
   - Check for peer/unmet dependency warnings

4. **Build Verification** (optional, non-blocking):
   - If a build task exists (`grunt build`, `gulp build`, or an npm `build`
     script), attempt it: `npx grunt build > /dev/null 2>&1` (or the gulp/npm
     equivalent)
   - Log build success or failure (do NOT stop execution on build failure)
   - A build failure should be noted in the report as a risk (e.g. an
     ngAnnotate/uglify failure, or a legacy toolchain incompatible with the
     Node version)

5. **Lint Sanity** (optional, non-blocking):
   - If a lint task exists (`grunt jshint`, `eslint`, npm `lint`):
     `npx eslint . > /dev/null 2>&1` or the project's lint task
   - Count lint errors: note in the report
   - Do NOT stop execution on lint errors

OUTPUT:
- Node.js version confirmed: [Version]
- Package manager: [npm/yarn] [Version]
- Bower used: [Yes/No] — components installed: [Yes/No/N/A]
- Dependencies installed: [Yes/No]
- Build status: [Success/Failed/Skipped]
- Lint errors: [XX or Skipped]
- Ready for analysis: [Yes/No]
