# Angular Version Alignment

> Mandatory Node.js version alignment requirement for any Angular project analysis (single app or multi-project workspace). Ensures the Node.js version matches project requirements — Angular CLI enforces supported Node ranges.

---

MANDATORY STEP 0: Execute Node.js Version Alignment Requirement
before any Angular project analysis.

CRITICAL REQUIREMENT: This rule MUST configure nvm to use the
project's Node.js version. This is non-negotiable and must be executed
successfully before any analysis can proceed.

This rule applies to ANY Angular project regardless of versions found:

WORKSPACE / MONOREPO DETECTION:
- First detect repository structure: single Angular app or multi-project
  workspace (multiple `projects` in `angular.json`, an `apps/`+`libs/`
  layout, or an Nx workspace)
- If `apps/` (or multiple `projects`) exist, analyze each app individually
- If `libs/` / library projects exist, analyze each library individually

SINGLE APP VERSION ALIGNMENT:
1. **Extract Project Node.js Version**:
   - Read `package.json` and extract the Node.js version from engines.node
   - Check for `.nvmrc` file for nvm-specific version
   - Check for `.node-version` file
   - If no version specified, use the LTS version supported by the
     project's Angular major (Angular CLI documents its supported range)
   - Identify the exact Node.js version the project requires

2. **Check Current Node.js Version**:
   - Run `node --version 2>/dev/null` to get current Node.js version
   - Compare with project requirement

3. **Version Mismatch Detection**:
   - If versions differ (even minor/patch differences): ALIGNMENT REQUIRED
   - If versions match: Continue with analysis
   - If nvm is not installed: Error, nvm should be installed by
     @angular_tool_installer

4. **Smart Dependency Check** (SKIP REINSTALL IF ALIGNED):
   - If version ALREADY MATCHES the project requirement:
     * Check if `node_modules/` directory exists at root
     * Check if the lock file (package-lock.json, yarn.lock, or pnpm-lock.yaml) exists
     * If BOTH exist: SKIP clean and reinstall — dependencies are already in place
     * If either is missing: proceed with dependency installation ONLY (no version change needed)
     * Log: "Version aligned, dependencies intact — skipping reinstall"
   - If version DOES NOT MATCH: proceed with full version alignment (step 5)

5. **Execute Version Alignment** (MANDATORY nvm CONFIGURATION):
   - Verify nvm is present (installed by @angular_tool_installer)
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
   - Install dependencies in ALL workspace libraries:
     `find libs/ projects/ -name "package.json" -execdir sh -c \
     'npm install > /dev/null 2>&1' \;`
   - Install dependencies in ALL workspace apps:
     `find apps/ -name "package.json" -execdir sh -c \
     'npm install > /dev/null 2>&1' \;`

MULTI-PROJECT WORKSPACE VERSION ALIGNMENT:
1. **Extract Project Node.js Versions**:
   - Read root `package.json` (if exists) and extract Node.js version
   - Check for root-level `.nvmrc` or `.node-version` files
   - For each app in apps/ directory:
     - Read `apps/<app_name>/package.json` and extract Node.js version
     - Check for `apps/<app_name>/.nvmrc` or `.node-version` files
   - For each library in libs/ (or `projects/`) directory:
     - Read `libs/<lib_name>/package.json` and extract Node.js version
     - Check for `libs/<lib_name>/.nvmrc` or `.node-version` files

2. **Version Consistency Analysis**:
   - Compare Node.js versions across all apps and libraries
   - Identify version conflicts between apps/libraries
   - Determine the target Node.js version (most common or highest)

3. **Check Current Node.js Version**:
   - Run `node --version 2>/dev/null` to get current Node.js version
   - Compare with target project requirement

4. **Version Mismatch Detection**:
   - If versions differ (even minor/patch differences): ALIGNMENT REQUIRED
   - If versions match: Continue with analysis
   - If nvm is not installed: Error, nvm should be installed by
     @angular_tool_installer
   - Note any version inconsistencies between apps/libraries

5. **Smart Dependency Check** (SKIP REINSTALL IF ALIGNED):
   - If version ALREADY MATCHES the target requirement:
     * Check if root `node_modules/` exists
     * Check if root lock file exists
     * For each app in apps/: check if `node_modules/` exists
     * For each library in libs/: check if `node_modules/` exists
     * If ALL node_modules exist AND root lock file exists: SKIP clean and reinstall
     * If any are missing: install ONLY in missing locations (no clean needed)
     * Log: "Version aligned, dependencies intact — skipping reinstall"
   - If version DOES NOT MATCH: proceed with full version alignment (step 6)

6. **Execute Version Alignment** (MANDATORY nvm CONFIGURATION):
   - Verify nvm is present (installed by @angular_tool_installer)
   - Install required Node.js version via nvm:
     `nvm install <version> > /dev/null 2>&1`
   - Use Node.js version: `nvm use <version> > /dev/null 2>&1`
   - Verify alignment with `node --version 2>/dev/null`
   - Clean and reinstall dependencies across all apps and libraries

7. **Documentation**:
   - Log the version change process
   - Document any alignment issues or failures
   - Document version consistency across apps/libraries
   - Note any version conflicts that require resolution

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

if [ -d "libs" ]; then
  for dir in libs/*/; do
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

  # All library dependencies (if libs/ directory exists)
  if [ -d "libs" ]; then
    echo "Installing dependencies for all libraries..."
    find libs/ -name "package.json" -execdir sh -c \
      '"$INSTALL_CMD"' > /dev/null 2>&1 \;
  fi

  # All apps dependencies (if apps/ directory exists)
  if [ -d "apps" ]; then
    echo "Installing dependencies for all apps..."
    find apps/ -name "package.json" -execdir sh -c \
      '"$INSTALL_CMD"' > /dev/null 2>&1 \;
  fi
fi
```

CRITICAL: nvm CONFIGURATION IS MANDATORY:
- If nvm is missing, STOP execution and advise running
  @angular_tool_installer
- If Node.js version installation via nvm fails, STOP execution and
  provide resolution steps
- If version setting fails, STOP execution and provide troubleshooting
  steps

Why This Is Critical:
- Prevents Build Failures: Angular CLI refuses unsupported Node.js versions
- Ensures Accurate Analysis: Different Node.js versions have different
  capabilities
- Avoids False Positives: Analysis results depend on the correct
  Node.js version
