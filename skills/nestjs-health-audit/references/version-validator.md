# NestJS Version Validator

> Verify nvm installation, Node.js environment setup, and dependency management for NestJS projects (single app or monorepo).

---

Goal: Verify nvm installation, Node.js environment setup, and
comprehensive dependency management.

MONOREPO DETECTION:
- First detect repository structure: single app or monorepo
  (nx, turborepo, lerna, apps/ structure)
- If apps/ directory exists, analyze each app individually
- If packages/ directory exists, analyze each package individually

VALIDATION CHECKS:

1. nvm Installation and Configuration:
   ```bash
   # Check if nvm is installed
   if command -v nvm &> /dev/null; then
     echo "✓ nvm is installed"
     nvm --version
   else
     echo "✗ nvm is NOT installed"
   fi

   # Check current Node.js version
   echo "Current Node.js version:"
   node --version

   # Check if .nvmrc exists
   if [ -f ".nvmrc" ]; then
     echo "✓ .nvmrc file found"
     cat .nvmrc 2>/dev/null | head -1
   else
     echo "! .nvmrc file not found"
   fi

   # Check if .node-version exists
   if [ -f ".node-version" ]; then
     echo "✓ .node-version file found"
     cat .node-version 2>/dev/null | head -1
   else
     echo "! .node-version file not found"
   fi
   ```

2. Package Manager Detection:
   ```bash
   # Detect which package manager is in use
   if [ -f "pnpm-lock.yaml" ]; then
     echo "Detected package manager: pnpm"
     pnpm --version
   elif [ -f "yarn.lock" ]; then
     echo "Detected package manager: yarn"
     yarn --version
   elif [ -f "package-lock.json" ]; then
     echo "Detected package manager: npm"
     npm --version
   else
     echo "No lock file found - defaulting to npm"
     npm --version
   fi
   ```

3. Node.js Version Requirement Check:
   ```bash
   # Check package.json for Node.js engine requirement
   if [ -f "package.json" ]; then
     echo "Checking package.json for Node.js version requirement..."
     if grep -q "engines" package.json; then
       grep -A 3 "engines" package.json
     else
       echo "! No engines field in package.json"
     fi
   fi
   ```

4. Dependency Installation Verification:
   ```bash
   # Check if node_modules exists
   if [ -d "node_modules" ]; then
     echo "✓ node_modules directory exists"
     echo "Number of dependencies installed: $(ls node_modules | wc -l)"
   else
      echo "✗ node_modules directory NOT found - dependencies not installed"
   fi

   # Verify root dependencies are installed
   if [ -f "package.json" ]; then
     echo "Verifying root dependencies..."
      echo "Dependencies: $(npm list --depth=0 2>/dev/null | wc -l) packages" && \
        npm list --depth=0 2>/dev/null | \
        grep -E "@nestjs|@typescript|typescript" | head -5
   fi
   ```

5. Monorepo Structure Validation (if applicable):
   ```bash
   # Check for monorepo structure
   if [ -d "apps" ]; then
     echo "✓ Monorepo detected: apps/ directory found"
     echo "Apps found:"
     ls -d apps/*/ 2>/dev/null || echo "No apps found"
     
     # Check each app for dependencies
     for app_dir in apps/*/; do
       app_name=$(basename "$app_dir")
       echo "Checking app: $app_name"
       if [ -d "$app_dir/node_modules" ]; then
         echo "  ✓ Dependencies installed"
       else
         echo "  ✗ Dependencies NOT installed"
       fi
     done
   fi

   if [ -d "packages" ]; then
     echo "✓ Packages directory found"
     echo "Packages found:"
     ls -d packages/*/ 2>/dev/null || echo "No packages found"
     
     # Check each package for dependencies
     for pkg_dir in packages/*/; do
       pkg_name=$(basename "$pkg_dir")
       echo "Checking package: $pkg_name"
       if [ -d "$pkg_dir/node_modules" ]; then
         echo "  ✓ Dependencies installed"
       else
         echo "  ✗ Dependencies NOT installed"
       fi
     done
   fi
   ```

6. NestJS Installation Verification:
   ```bash
   # Check if NestJS is installed
   echo "Checking NestJS installation..."
   
   if [ -f "package.json" ]; then
     if grep -q "@nestjs/core" package.json; then
       echo "✓ NestJS detected in package.json"
       grep "@nestjs/core" package.json
     else
       echo "✗ NestJS NOT found in package.json"
     fi
     
     # Check NestJS CLI
     if command -v nest &> /dev/null; then
       echo "✓ NestJS CLI is installed"
       nest --version 2>/dev/null | head -1
     else
       echo "! NestJS CLI not installed globally"
     fi
   fi
   ```

7. TypeScript Configuration Verification:
   ```bash
   # Check TypeScript configuration
   if [ -f "tsconfig.json" ]; then
     echo "✓ tsconfig.json found"
     PATTERN='"strict"|"target"|"module"|"esModuleInterop"|"skipLibCheck"'
     grep -E "$PATTERN" tsconfig.json | head -5 || \
       cat tsconfig.json | head -n 10
   else
     echo "✗ tsconfig.json NOT found"
   fi
   
   # Check if TypeScript is installed
   if command -v tsc &> /dev/null; then
     echo "✓ TypeScript compiler available"
     tsc --version
   else
     echo "! TypeScript compiler not available in PATH"
   fi
   ```

Output format:
- Repository structure type (single app / monorepo)
- nvm installation status and version
- Current Node.js version vs required version
- Package manager detected and version
- Dependencies installation status (root, apps, packages)
- NestJS installation status and version
- TypeScript configuration status
- Any missing configurations or failed validations
- Recommendations for fixes if issues found
