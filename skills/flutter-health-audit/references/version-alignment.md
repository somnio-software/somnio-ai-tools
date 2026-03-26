# Flutter Version Alignment

> Mandatory Flutter version alignment requirement for any Flutter project analysis (single app or multi-app monorepos). Ensures global Flutter version matches project requirements.

---

MANDATORY STEP 0: Execute Flutter Version Alignment Requirement before
any Flutter project analysis.

CRITICAL REQUIREMENT: This rule MUST configure FVM global version
to match project requirements. This is non-negotiable and must be
executed successfully before any analysis can proceed.

This rule applies to ANY Flutter project regardless of versions found:

MONOREPO DETECTION:
- First detect repository structure: single app (app/) or multi-app
  monorepo (apps/app1/, apps/app2/, etc.)
- If apps/ directory exists, analyze each app individually
- If packages/ directory exists, analyze each package individually

SINGLE APP VERSION ALIGNMENT:
1. **Extract Project Flutter Version**:
   - Read `app/pubspec.yaml` and extract the Flutter SDK version
     constraint from environment.sdk.flutter
   - Check for `app/.fvm/fvm_config.json` or `app/.fvmrc` files for
     FVM-specific version
   - Identify the exact Flutter version the project requires

2. **Check Current Global Flutter Version**:
   - Run `flutter --version 2>/dev/null | head -1` to get current global
     Flutter version
   - Compare with project requirement

3. **Version Mismatch Detection**:
   - If versions differ (even minor/patch differences): ALIGNMENT REQUIRED
   - If versions match: Continue with analysis
   - If FVM is configured but not installed: Error, FVM should be
     installed by @flutter_tool_installer

4. **Smart Dependency Check** (SKIP REINSTALL IF ALIGNED):
   - If version ALREADY MATCHES the project requirement:
     * Check if `.dart_tool/` directory exists in the project
     * Check if `pubspec.lock` exists
     * If BOTH exist: SKIP `flutter clean` and `pub get` — dependencies are already in place
     * If either is missing: proceed with dependency installation ONLY (no version change needed)
     * Log: "Version aligned, dependencies intact — skipping reinstall"
   - If version DOES NOT MATCH: proceed with full version alignment (step 5)

5. **Execute Version Alignment** (MANDATORY FVM GLOBAL CONFIGURATION):
   - Verify FVM is present (installed by @flutter_tool_installer)
   - Install required Flutter version via FVM: `fvm install <version>`
   - Set Flutter version as GLOBAL using FVM: `fvm global <version>`
   - Verify global alignment with `fvm flutter --version`
   - Update project to use global version: `fvm use <version> --force`
   - Clean project dependencies: `fvm flutter clean && fvm flutter
     pub get`
   - Execute pub get in ALL packages: `find packages/ -name
     "pubspec.yaml" -execdir fvm flutter pub get \;`
   - Execute pub get in ALL apps: `find apps/ -name "pubspec.yaml"
     -execdir fvm flutter pub get \;`

MULTI-APP MONOREPO VERSION ALIGNMENT:
1. **Extract Project Flutter Versions**:
   - Read root `pubspec.yaml` (if exists) and extract Flutter SDK
     version constraint
   - Check for root-level `.fvm/fvm_config.json` or `.fvmrc` files
   - For each app in apps/ directory:
     - Read `apps/<app_name>/pubspec.yaml` and extract Flutter SDK
       version constraint
     - Check for `apps/<app_name>/.fvm/fvm_config.json` or
       `apps/<app_name>/.fvmrc` files
   - For each package in packages/ directory:
     - Read `packages/<package_name>/pubspec.yaml` and extract
       Flutter SDK version constraint
     - Check for `packages/<package_name>/.fvm/fvm_config.json` or
       `packages/<package_name>/.fvmrc` files

2. **Version Consistency Analysis**:
   - Compare Flutter versions across all apps and packages
   - Identify version conflicts between apps/packages
   - Determine the target Flutter version (most common or highest)

3. **Check Current Global Flutter Version**:
   - Run `flutter --version 2>/dev/null | head -1` to get current global
     Flutter version
   - Compare with target project requirement

4. **Version Mismatch Detection**:
   - If versions differ (even minor/patch differences): ALIGNMENT REQUIRED
   - If versions match: Continue with analysis
   - If FVM is configured but not installed: Error, FVM should be
     installed by @flutter_tool_installer
   - Note any version inconsistencies between apps/packages

5. **Smart Dependency Check** (SKIP REINSTALL IF ALIGNED):
   - If version ALREADY MATCHES the target requirement:
     * Check if root `.dart_tool/` exists
     * Check if root `pubspec.lock` exists
     * For each app in apps/: check if `.dart_tool/` and `pubspec.lock` exist
     * For each package in packages/: check if `.dart_tool/` and `pubspec.lock` exist
     * If ALL `.dart_tool/` directories exist AND all `pubspec.lock` files exist: SKIP clean and reinstall
     * If any are missing: run `pub get` ONLY in missing locations (no clean needed)
     * Log: "Version aligned, dependencies intact — skipping reinstall"
   - If version DOES NOT MATCH: proceed with full version alignment (step 6)

6. **Execute Version Alignment** (MANDATORY FVM GLOBAL CONFIGURATION):
   - Verify FVM is present (installed by @flutter_tool_installer)
   - Install required Flutter version via FVM: `fvm install <version>`
   - Set Flutter version as GLOBAL using FVM: `fvm global <version>`
   - Verify global alignment with `fvm flutter --version`
   - Update project to use global version: `fvm use <version> --force`
   - Clean project dependencies for each app: `cd apps/<app_name>
     && fvm flutter clean && fvm flutter pub get`
   - Clean project dependencies for each package: `cd
     packages/<package_name> && fvm flutter clean && fvm flutter
     pub get`
   - Clean root dependencies if applicable: `fvm flutter clean &&
     fvm flutter pub get`
   - Execute pub get in ALL packages:
     `find packages/ -name "pubspec.yaml" -execdir fvm flutter pub get \;`
   - Execute pub get in ALL apps:
     `find apps/ -name "pubspec.yaml" -execdir fvm flutter pub get \;`

7. **Documentation**:
   - Log the version change process
   - Document any alignment issues or failures
   - Document version consistency across apps/packages
   - Note any version conflicts that require resolution

CRITICAL: FVM GLOBAL CONFIGURATION IS MANDATORY:
 - If FVM is missing, STOP execution and advise running
  @flutter_tool_installer
- If Flutter version installation via FVM fails, STOP execution and
  provide resolution steps
- If global version setting fails, STOP execution and provide
  troubleshooting steps
- If any error occurs during FVM global configuration:
  - Log the specific error and reason for failure
  - Note missing FVM files/folders (.fvm/, .fvm/fvm_config.json, .fvmrc)
  - STOP execution - FVM global configuration is REQUIRED
  - Document the failure reason for inclusion in the final report
  - Provide step-by-step resolution instructions
- Only continue execution after successful FVM global configuration

COMPREHENSIVE DEPENDENCY MANAGEMENT:
After setting FVM global version, execute comprehensive dependency
management:

 ```bash
 # Smart dependency check - skip if already aligned
 NEEDS_INSTALL=false

 if [ ! -f "pubspec.lock" ]; then
   NEEDS_INSTALL=true
   echo "pubspec.lock missing — pub get required"
 fi

 if [ ! -d ".dart_tool" ]; then
   NEEDS_INSTALL=true
   echo ".dart_tool missing — pub get required"
 fi

 if [ -d "packages" ]; then
   for dir in packages/*/; do
     if [ -f "$dir/pubspec.yaml" ] && { [ ! -f "$dir/pubspec.lock" ] || [ ! -d "$dir/.dart_tool" ]; }; then
       NEEDS_INSTALL=true
       echo "Dependencies missing in $dir — pub get required"
     fi
   done
 fi

 if [ -d "apps" ]; then
   for dir in apps/*/; do
     if [ -f "$dir/pubspec.yaml" ] && { [ ! -f "$dir/pubspec.lock" ] || [ ! -d "$dir/.dart_tool" ]; }; then
       NEEDS_INSTALL=true
       echo "Dependencies missing in $dir — pub get required"
     fi
   done
 fi

 if [ "$NEEDS_INSTALL" = false ]; then
   echo "Dependencies already resolved — skipping pub get"
 else
   # Root project dependencies
   echo "Installing root project dependencies..."
   fvm flutter pub get > /dev/null 2>&1

   # All packages dependencies (if packages/ directory exists)
   if [ -d "packages" ]; then
     echo "Installing dependencies for all packages..."
     find packages/ -name "pubspec.yaml" -execdir sh -c \
       'fvm flutter pub get > /dev/null 2>&1' \;
     echo "Packages dependencies installed successfully"
   fi

   # All apps dependencies (if apps/ directory exists)
   if [ -d "apps" ]; then
     echo "Installing dependencies for all apps..."
     find apps/ -name "pubspec.yaml" -execdir sh -c \
       'fvm flutter pub get > /dev/null 2>&1' \;
     echo "Apps dependencies installed successfully"
   fi
 fi

 # Verify all dependencies are resolved
 echo "Verifying dependency resolution..."
 fvm flutter pub deps > /dev/null 2>&1
 
 # Run build_runner where applicable
if grep -q "build_runner" pubspec.yaml 2>/dev/null; then
  echo "Running build_runner at root..."
  fvm dart run build_runner build --delete-conflicting-outputs \
    > /dev/null 2>&1
fi

 if [ -d "packages" ]; then
   echo "Running build_runner in all packages that declare \
   build_runner..."
   find packages/ -name "pubspec.yaml" -execdir sh -c \
     'if grep -q "build_runner" pubspec.yaml 2>/dev/null; then \
     fvm dart run build_runner build --delete-conflicting-outputs \
     > /dev/null 2>&1; fi' \;
 fi

 if [ -d "apps" ]; then
   echo "Running build_runner in all apps that declare build_runner..."
   find apps/ -name "pubspec.yaml" -execdir sh -c \
     'if grep -q "build_runner" pubspec.yaml 2>/dev/null; then \
     fvm dart run build_runner build --delete-conflicting-outputs \
     > /dev/null 2>&1; fi' \;
 fi
 ```

Why This Is Critical:
- Prevents Build Failures: Version mismatches cause compilation errors
- Ensures Accurate Analysis: Different Flutter versions have different
  capabilities
- Maintains Consistency: All team members should use the same Flutter
  version
- Avoids False Positives: Analysis results depend on the correct
  Flutter version
- Multi-app Consistency: Ensures all apps in monorepo use compatible
  Flutter versions
- Complete Dependency Resolution: All packages and apps have their
  dependencies properly installed
- Monorepo Support: Handles complex project structures with multiple
  packages and apps
