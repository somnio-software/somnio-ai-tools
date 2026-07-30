# AngularJS Version Alignment

> Mandatory Node.js version alignment requirement for any AngularJS project analysis. Ensures the Node.js version matches project requirements so the Bower/Grunt/gulp/Karma toolchain runs.

---

MANDATORY STEP 0: Execute Node.js Version Alignment Requirement
before any AngularJS project analysis.

CRITICAL REQUIREMENT: This rule MUST configure nvm to use the
project's Node.js version. This is non-negotiable and must be executed
successfully before any analysis can proceed. AngularJS itself runs in the
browser, but Bower, Grunt/gulp and Karma run on Node — an aligned Node is what
lets those tools resolve dependencies and run the specs.

This rule applies to ANY AngularJS project regardless of versions found:

PROJECT LAYOUT DETECTION:
- Detect the app root: `app/`, `public/`, `src/`, or `client/`
- Detect the dependency managers in use: `package.json` (npm) and/or
  `bower.json` (Bower)
- AngularJS projects are typically a single app (no npm-workspaces monorepo);
  if an `apps/`/`packages/` monorepo is detected, align once at the root and
  note the structure

NODE.JS VERSION ALIGNMENT:
1. **Extract Project Node.js Version**:
   - Read `package.json` and extract the Node.js version from `engines.node`
   - Check for a `.nvmrc` file for an nvm-specific version
   - Check for a `.node-version` file
   - Legacy AngularJS toolchains often need an OLDER Node (e.g. node-sass /
     old Karma break on new majors). If a pin is present, honor it exactly.
   - If no version specified, use an LTS version, and be prepared to fall back
     to an older LTS if the toolchain fails to install

2. **Check Current Node.js Version**:
   - Run `node --version 2>/dev/null` to get the current Node.js version
   - Compare with the project requirement

3. **Version Mismatch Detection**:
   - If versions differ (even minor/patch differences): ALIGNMENT REQUIRED
   - If versions match: continue with analysis
   - If nvm is not installed: error — nvm should be installed by the
     tool-installer step

4. **Smart Dependency Check** (SKIP REINSTALL IF ALIGNED):
   - If the version ALREADY MATCHES the project requirement:
     * Check if `node_modules/` exists (npm tooling)
     * Check if `bower_components/` exists when `bower.json` is present
     * Check if the lock file (`package-lock.json` or `yarn.lock`) exists
     * If all required trees exist: SKIP clean and reinstall — dependencies
       are already in place
     * If any is missing: proceed with installation ONLY (no version change)
     * Log: "Version aligned, dependencies intact — skipping reinstall"
   - If the version DOES NOT MATCH: proceed with full version alignment
     (step 5)

5. **Execute Version Alignment** (MANDATORY nvm CONFIGURATION):
   - Verify nvm is present (installed by the tool-installer step)
   - Install the required Node.js version via nvm:
     `nvm install <version> > /dev/null 2>&1`
   - Use the Node.js version: `nvm use <version> > /dev/null 2>&1`
   - Verify alignment with `node --version 2>/dev/null`
   - Clean project dependencies and caches:
     * Remove node_modules: `rm -rf node_modules`
     * Remove bower_components (if present): `rm -rf bower_components`
     * Remove `package-lock.json` / `yarn.lock` (if exists)
     * Clean npm cache: `npm cache clean --force` (if using npm)
   - Install dependencies based on the detected managers:
     * If `yarn.lock` exists: `yarn install > /dev/null 2>&1`
     * Otherwise: `npm install > /dev/null 2>&1`
     * If `bower.json` exists: `bower install > /dev/null 2>&1`

COMPREHENSIVE DEPENDENCY MANAGEMENT:
After setting the nvm version, execute comprehensive dependency management:

```bash
# Detect Node package manager
if [ -f "yarn.lock" ]; then
  PKG_MANAGER="yarn"
  INSTALL_CMD="yarn install"
else
  PKG_MANAGER="npm"
  INSTALL_CMD="npm install"
fi

echo "Detected package manager: $PKG_MANAGER"

# Smart dependency check - skip if already aligned
NEEDS_INSTALL=false

if [ ! -d "node_modules" ]; then
  NEEDS_INSTALL=true
  echo "node_modules missing — installation required"
fi

if [ ! -f "package-lock.json" ] && [ ! -f "yarn.lock" ]; then
  NEEDS_INSTALL=true
  echo "Lock file missing — installation required"
fi

if [ -f "bower.json" ] && [ ! -d "bower_components" ]; then
  NEEDS_INSTALL=true
  echo "bower_components missing — bower install required"
fi

if [ "$NEEDS_INSTALL" = false ]; then
  echo "Dependencies already installed — skipping reinstall"
else
  echo "Installing Node dev-tooling dependencies..."
  $INSTALL_CMD > /dev/null 2>&1

  if [ -f "bower.json" ]; then
    echo "Installing Bower components..."
    bower install > /dev/null 2>&1
  fi
fi
```

7. **Documentation**:
   - Log the version change process
   - Document any alignment issues or failures (especially toolchain installs
     that failed on a too-new Node — a common legacy-AngularJS trap)
   - Note whether Bower components were resolved

CRITICAL: nvm CONFIGURATION IS MANDATORY:
- If nvm is missing, STOP execution and advise running the tool-installer step
- If Node.js version installation via nvm fails, STOP execution and
  provide resolution steps
- If version setting fails, STOP execution and provide troubleshooting steps

Why This Is Critical:
- Prevents Tooling Failures: version mismatches break Bower/Grunt/gulp/Karma
- Ensures Accurate Analysis: different Node.js versions have different
  capabilities
- Avoids False Positives: coverage and lint results depend on the toolchain
  actually running
