# NestJS Version Alignment

> Mandatory Node.js version alignment requirement for any NestJS project analysis (single app or monorepo). Ensures Node.js version matches project requirements.

---

MANDATORY STEP 0: Execute Node.js Version Alignment Requirement
before any NestJS project analysis.

CRITICAL REQUIREMENT: This rule MUST configure nvm to use the
project's Node.js version. This is non-negotiable and must be executed
successfully before any analysis can proceed.

This rule applies to ANY NestJS project regardless of versions found:

MONOREPO DETECTION:
- First detect repository structure: single app or monorepo
  (nx, turborepo, lerna, or apps/ structure)
- If apps/ directory exists, analyze each app individually
- If packages/ directory exists, analyze each package individually

SINGLE APP VERSION ALIGNMENT:
1. **Extract Project Node.js Version**:
   - Read `package.json` and extract the Node.js version from engines.node
   - Check for `.nvmrc` file for nvm-specific version
   - Check for `.node-version` file
   - If no version specified, use LTS version
   - Identify the exact Node.js version the project requires

2. **Check Current Node.js Version**:
   - Run `node --version 2>/dev/null` to get current Node.js version
   - Compare with project requirement

3. **Version Mismatch Detection**:
   - If versions differ (even minor/patch differences): ALIGNMENT REQUIRED
   - If versions match: Continue with analysis
   - If nvm is not installed: Error, nvm should be installed by
     @nestjs_tool_installer

4. **Smart Dependency Check** (SKIP REINSTALL IF ALIGNED):
   - If version ALREADY MATCHES the project requirement:
     * Check if `node_modules/` directory exists at root
     * Check if the lock file (package-lock.json, yarn.lock, or pnpm-lock.yaml) exists
     * If BOTH exist: SKIP clean and reinstall — dependencies are already in place
     * If either is missing: proceed with dependency installation ONLY (no version change needed)
     * Log: "Version aligned, dependencies intact — skipping reinstall"
   - If version DOES NOT MATCH: proceed with full version alignment (step 5)

5. **Execute Version Alignment** (MANDATORY nvm CONFIGURATION):
   - Verify nvm is present (installed by @nestjs_tool_installer)
   - Install required Node.js version via nvm:
     `nvm install <version> > /dev/null 2>&1`
   - Use Node.js version: `nvm use <version> > /dev/null 2>&1`
   - Verify alignment with `node --version 2>/dev/null`
   - Clean project dependencies and caches:
     * Remove node_modules: `rm -rf node_modules`
     * Remove package-lock.json, yarn.lock, or pnpm-lock.yaml (if exists)
     * Clean npm cache: `npm cache clean --force` (if using npm)
   - Install dependencies based on detected package manager:
     * If package-lock.json exists: `npm install > /dev/null 2>&1`
     * If yarn.lock exists: `yarn install > /dev/null 2>&1`
     * If pnpm-lock.yaml exists: `pnpm install > /dev/null 2>&1`
     * Otherwise: `npm install > /dev/null 2>&1`
   - Install dependencies in ALL packages:
     `find packages/ -name "package.json" -execdir sh -c \
     'npm install > /dev/null 2>&1' \;`
   - Install dependencies in ALL apps:
     `find apps/ -name "package.json" -execdir sh -c \
     'npm install > /dev/null 2>&1' \;`

MONOREPO VERSION ALIGNMENT:
1. **Extract Project Node.js Versions**:
   - Read root `package.json` (if exists) and extract Node.js version
   - Check for root-level `.nvmrc` or `.node-version` files
   - For each app in apps/ directory:
     - Read `apps/<app_name>/package.json` and extract Node.js version
     - Check for `apps/<app_name>/.nvmrc` or `.node-version` files
   - For each package in packages/ directory:
     - Read `packages/<package_name>/package.json` and extract
       Node.js version
     - Check for `packages/<package_name>/.nvmrc` or `.node-version` files

2. **Version Consistency Analysis**:
   - Compare Node.js versions across all apps and packages
   - Identify version conflicts between apps/packages
   - Determine the target Node.js version (most common or highest)

3. **Check Current Node.js Version**:
   - Run `node --version 2>/dev/null` to get current Node.js version
   - Compare with target project requirement

4. **Version Mismatch Detection**:
   - If versions differ (even minor/patch differences): ALIGNMENT REQUIRED
   - If versions match: Continue with analysis
   - If nvm is not installed: Error, nvm should be installed by
     @nestjs_tool_installer
   - Note any version inconsistencies between apps/packages

5. **Smart Dependency Check** (SKIP REINSTALL IF ALIGNED):
   - If version ALREADY MATCHES the target requirement:
     * Check if root `node_modules/` exists
     * Check if root lock file exists
     * For each app in apps/: check if `node_modules/` exists
     * For each package in packages/: check if `node_modules/` exists
     * If ALL node_modules exist AND root lock file exists: SKIP clean and reinstall
     * If any are missing: install ONLY in missing locations (no clean needed)
     * Log: "Version aligned, dependencies intact — skipping reinstall"
   - If version DOES NOT MATCH: proceed with full version alignment (step 6)

6. **Execute Version Alignment** (MANDATORY nvm CONFIGURATION):
   - Verify nvm is present (installed by @nestjs_tool_installer)
   - Install required Node.js version via nvm:
     `nvm install <version> > /dev/null 2>&1`
   - Use Node.js version: `nvm use <version> > /dev/null 2>&1`
   - Verify alignment with `node --version 2>/dev/null`
   - Clean project dependencies and caches for each app:
     * Remove node_modules in each app:
       `find apps/ -name "node_modules" -type d -prune -exec rm -rf {} +`
     * Remove lock files in each app:
       `find apps/ \( -name "package-lock.json" -o -name "yarn.lock" \
       -o -name "pnpm-lock.yaml" \) -delete`
   - Clean project dependencies and caches for each package:
     * Remove node_modules in each package:
       `find packages/ -name "node_modules" -type d -prune \
       -exec rm -rf {} +`
     * Remove lock files in each package:
       `find packages/ \( -name "package-lock.json" -o -name "yarn.lock" \
       -o -name "pnpm-lock.yaml" \) -delete`
   - Clean root dependencies if applicable:
     * Remove root node_modules: `rm -rf node_modules`
     * Remove root lock file
   - Install dependencies in ALL packages:
     `find packages/ -name "package.json" -execdir sh -c \
     'npm install > /dev/null 2>&1' \;`
   - Install dependencies in ALL apps:
     `find apps/ -name "package.json" -execdir sh -c \
     'npm install > /dev/null 2>&1' \;`
   - Install root dependencies if applicable:
     `npm install > /dev/null 2>&1`

7. **Documentation**:
   - Log the version change process
   - Document any alignment issues or failures
   - Document version consistency across apps/packages
   - Note any version conflicts that require resolution

CRITICAL: nvm CONFIGURATION IS MANDATORY:
- If nvm is missing, STOP execution and advise running
  @nestjs_tool_installer
- If Node.js version installation via nvm fails, STOP execution and
  provide resolution steps
- If version setting fails, STOP execution and provide troubleshooting
  steps
- If any error occurs during nvm configuration:
  - Log the specific error and reason for failure
  - Note missing nvm files/folders (.nvmrc, .node-version)
  - STOP execution - nvm configuration is REQUIRED
  - Document the failure reason for inclusion in the final report
  - Provide step-by-step resolution instructions
- Only continue execution after successful nvm configuration

COMPREHENSIVE DEPENDENCY MANAGEMENT:
After setting nvm version, execute comprehensive dependency management:

```bash
# Detect package manager
if [ -f "pnpm-lock.yaml" ]; then
  PKG_MANAGER="pnpm"
  INSTALL_CMD="pnpm install"
elif [ -f "yarn.lock" ]; then
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
  echo "Root node_modules missing — installation required"
fi

if [ ! -f "package-lock.json" ] && [ ! -f "yarn.lock" ] && [ ! -f "pnpm-lock.yaml" ]; then
  NEEDS_INSTALL=true
  echo "Lock file missing — installation required"
fi

if [ -d "packages" ]; then
  for dir in packages/*/; do
    if [ -f "$dir/package.json" ] && [ ! -d "$dir/node_modules" ]; then
      NEEDS_INSTALL=true
      echo "node_modules missing in $dir — installation required"
    fi
  done
fi

if [ -d "apps" ]; then
  for dir in apps/*/; do
    if [ -f "$dir/package.json" ] && [ ! -d "$dir/node_modules" ]; then
      NEEDS_INSTALL=true
      echo "node_modules missing in $dir — installation required"
    fi
  done
fi

if [ "$NEEDS_INSTALL" = false ]; then
  echo "Dependencies already installed — skipping reinstall"
else
  # Root project dependencies
  echo "Installing root project dependencies..."
  $INSTALL_CMD > /dev/null 2>&1

  # All packages dependencies (if packages/ directory exists)
  if [ -d "packages" ]; then
    echo "Installing dependencies for all packages..."
    find packages/ -name "package.json" -execdir sh -c \
      '"$INSTALL_CMD"' > /dev/null 2>&1 \;
    echo "Packages dependencies installed successfully"
  fi

  # All apps dependencies (if apps/ directory exists)
  if [ -d "apps" ]; then
    echo "Installing dependencies for all apps..."
    find apps/ -name "package.json" -execdir sh -c \
      '"$INSTALL_CMD"' > /dev/null 2>&1 \;
    echo "Apps dependencies installed successfully"
  fi
fi

# Run build if build script exists
if grep -q "\"build\":" package.json 2>/dev/null; then
  echo "Running build at root..."
  $PKG_MANAGER run build > /dev/null 2>&1
fi

if [ -d "packages" ]; then
  echo "Running build in all packages that have build script..."
  find packages/ -name "package.json" -execdir sh -c \
    'if grep -q "\"build\":" package.json 2>/dev/null; then \
    '"$PKG_MANAGER"' run build > /dev/null 2>&1; fi' \;
fi

if [ -d "apps" ]; then
  echo "Running build in all apps that have build script..."
  find apps/ -name "package.json" -execdir sh -c \
    'if grep -q "\"build\":" package.json 2>/dev/null; then \
    '"$PKG_MANAGER"' run build > /dev/null 2>&1; fi' \;
fi
```

Why This Is Critical:
- Prevents Build Failures: Version mismatches cause compilation errors
- Ensures Accurate Analysis: Different Node.js versions have different
  capabilities
- Maintains Consistency: All team members should use the same Node.js
  version
- Avoids False Positives: Analysis results depend on the correct
  Node.js version
- Monorepo Consistency: Ensures all apps in monorepo use compatible
  Node.js versions
- Complete Dependency Resolution: All packages and apps have their
  dependencies properly installed
- Monorepo Support: Handles complex project structures with multiple
  packages and apps
