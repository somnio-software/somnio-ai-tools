# Flutter Version Validator

> Validate Flutter version and FVM setup for consistent development environment

---

When requested to validate Flutter version and FVM setup, you will:

MANDATORY REQUIREMENT: This rule MUST verify and enforce FVM global
configuration. This is non-negotiable.

1. Check current Flutter version
2. Validate FVM configuration
3. Compare versions and provide recommendations
4. Guide FVM installation and setup if needed
5. ENFORCE FVM global configuration - this is mandatory for all
   Flutter projects

----------------------------------------------------------------------
EXECUTION STEPS
----------------------------------------------------------------------

Step 1: Extract Flutter Version from pubspec.yaml
Read the required Flutter version from the project's pubspec.yaml:

```bash
# Check if pubspec.yaml exists
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: pubspec.yaml not found in current directory"
  exit 1
fi

# Extract Flutter version from pubspec.yaml
FLUTTER_VERSION=$(grep -A 1 "flutter:" pubspec.yaml | grep "sdk:" |
  sed 's/.*sdk: *//' | sed 's/[^0-9.]//g')

if [ -z "$FLUTTER_VERSION" ]; then
  echo "ERROR: No Flutter SDK version specified in pubspec.yaml"
  echo "Please add Flutter SDK constraint to pubspec.yaml:"
  echo "environment:"
  echo "  sdk: '>=2.17.0 <4.0.0'"
  echo "  flutter: '>=3.0.0'"
  exit 1
fi

echo "Project requires Flutter version: $FLUTTER_VERSION"
```

Step 2: Check FVM Installation
Verify FVM is installed and available:

```bash
# Check if FVM is installed
if ! command -v fvm &> /dev/null; then
  echo "ERROR: FVM is not installed"
  echo "Please install FVM first:"
  echo "dart pub global activate fvm"
  echo "export PATH=\"\$PATH\":\"\$HOME/.pub-cache/bin\""
  echo ""
  echo "After installation, restart your terminal and run this
    command again."
  exit 1
fi

echo "FVM is installed: $(fvm --version 2>/dev/null)"
```

Step 2.5: Check Current Global Flutter Version
Verify if the current global Flutter version matches the project
requirement:

```bash
# Get current global Flutter version
CURRENT_GLOBAL_VERSION=$(fvm global --version 2>/dev/null || echo "none")

if [ "$CURRENT_GLOBAL_VERSION" != "$FLUTTER_VERSION" ]; then
  echo "Current global Flutter version: $CURRENT_GLOBAL_VERSION"
  echo "Project requires Flutter version: $FLUTTER_VERSION"
  echo "Versions do not match. Proceeding to set correct global
    version..."
else
  echo "Global Flutter version matches project requirement:
    $FLUTTER_VERSION"
fi
```

Step 3: Check if Flutter Version is Installed
Verify if the required Flutter version is available via FVM:

```bash
# Check if Flutter version is installed via FVM
if ! fvm list | grep -q "$FLUTTER_VERSION"; then
  echo "ERROR: Flutter version $FLUTTER_VERSION is not installed via FVM"
  echo "Please install the required version:"
  echo "fvm install $FLUTTER_VERSION"
  echo ""
  echo "After installation, run this command again to set it as
    global version."
  exit 1
fi

echo "Flutter version $FLUTTER_VERSION is available via FVM"
```

Step 4: Set Flutter Version Globally (MANDATORY)
ALWAYS configure the project's Flutter version as the global version
using FVM:

```bash
# MANDATORY: Always set global version to match project requirement
echo "Setting Flutter $FLUTTER_VERSION as global version (MANDATORY)..."
fvm global $FLUTTER_VERSION

# Verify the global version
echo "Verifying global Flutter version:"
fvm flutter --version 2>/dev/null | head -1

# Update project to use global version
fvm use $FLUTTER_VERSION --force > /dev/null 2>&1

echo "Successfully configured Flutter $FLUTTER_VERSION as global version"

# Additional verification
echo "Final verification - Global Flutter version:"
fvm global --version 2>/dev/null
echo "Project Flutter version:"
fvm flutter --version 2>/dev/null | head -1
```

Step 5: Prepare Project Environment
Clean and prepare the project for development with comprehensive
dependency management:

```bash
# Clean previous build artifacts
echo "Cleaning project..."
fvm flutter clean > /dev/null 2>&1

# Get root project dependencies
echo "Getting root project dependencies..."
fvm flutter pub get > /dev/null 2>&1

# Get all packages dependencies (if packages/ directory exists)
if [ -d "packages" ]; then
  echo "Getting dependencies for all packages..."
   find packages/ -name "pubspec.yaml" -execdir sh -c \
     'fvm flutter pub get > /dev/null 2>&1' \;
  echo "Packages dependencies installed successfully"
fi

# Get all apps dependencies (if apps/ directory exists)
if [ -d "apps" ]; then
  echo "Getting dependencies for all apps..."
   find apps/ -name "pubspec.yaml" -execdir sh -c \
     'fvm flutter pub get > /dev/null 2>&1' \;
  echo "Apps dependencies installed successfully"
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
  echo "Running build_runner in all packages that declare build_runner..."
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

echo "Project environment prepared successfully with all dependencies"
```

----------------------------------------------------------------------
OUTPUT FORMAT
----------------------------------------------------------------------

Provide the following structured output:

1. VERSION EXTRACTION
   - Flutter version extracted from pubspec.yaml
   - Validation status of version format
   - Project configuration status

2. FVM VERIFICATION
   - FVM installation status
   - FVM version information
   - Installation instructions (if needed)

2.5. GLOBAL VERSION CHECK
   - Current global Flutter version
   - Project required Flutter version
   - Version match status
   - Action needed (if any)

3. FLUTTER VERSION AVAILABILITY
   - Required Flutter version status
   - Installation status via FVM
   - Installation instructions (if needed)

4. GLOBAL CONFIGURATION
   - Global Flutter version setting
   - Project configuration update
   - Verification of successful setup

5. PROJECT PREPARATION
   - Project cleaning status
   - Root dependencies installation
   - Packages dependencies installation (if packages/ exists)
   - Apps dependencies installation (if apps/ exists)
   - Dependency resolution verification
   - Environment readiness

6. FINAL STATUS
   - Success/failure status
   - Current global Flutter version
   - Project environment status
   - Next steps or error resolution

----------------------------------------------------------------------
FVM INTEGRATION GUIDELINES
----------------------------------------------------------------------

FVM Setup Instructions:
1. Install FVM globally: `dart pub global activate fvm`
2. Add FVM to PATH: `export PATH="$PATH":"$HOME/.pub-cache/bin"`
3. Install project Flutter version: `fvm install <version>`
4. Use project version: `fvm use <version>`
5. Verify installation: `fvm flutter --version`

IDE Integration:
- VS Code: Install "Flutter Version Manager" extension
- Android Studio: Configure Flutter SDK path to FVM directory
- Cursor: Use FVM commands in terminal

Team Workflow:
- Commit .fvm/fvm_config.json to version control
- Document Flutter version requirements in README
- Use FVM in CI/CD pipelines for consistent builds
- Regular Flutter version updates with team coordination

----------------------------------------------------------------------
COMMAND EXECUTION RULES
----------------------------------------------------------------------

Always execute commands in this order:
1. Extract Flutter version from pubspec.yaml
2. Check FVM installation status
2.5. Check current global Flutter version
3. Verify Flutter version availability via FVM
4. Set Flutter version globally (MANDATORY - always execute)
5. Prepare project environment (clean and pub get)
6. Verify successful configuration
7. Additional verification of global configuration

Handle errors gracefully:
- If pubspec.yaml is missing, exit with error and instructions
- If Flutter version is not specified, exit with error and format example
- If FVM is not installed, exit with installation instructions
- If Flutter version is not installed via FVM, exit with
  installation command
- Always provide clear error messages and next steps
- Stop execution immediately on any error condition

----------------------------------------------------------------------
VERSION MANAGEMENT BEST PRACTICES
----------------------------------------------------------------------

Execution Flow:
- Extract Flutter version from pubspec.yaml environment section
- Verify FVM is installed and available
- Check current global Flutter version against project requirement
- Check if required Flutter version is installed via FVM
- Set the Flutter version as global using FVM (only if versions
  don't match)
- Update project configuration to use the global version
- Clean project and install dependencies
- Verify successful configuration

Error Handling:
- Stop execution on any error condition
- Provide clear error messages with specific instructions
- Include exact commands needed to resolve issues
- Guide user through installation process step by step

Success Criteria (ALL MANDATORY):
- Flutter version successfully extracted from pubspec.yaml
- FVM is installed and functional
- Required Flutter version is available via FVM
- Global Flutter version is ALWAYS set correctly (MANDATORY)
- Project is configured to use the global version
- Root project dependencies are installed
- All packages dependencies are installed (if packages/ exists)
- All apps dependencies are installed (if apps/ exists)
- Dependency resolution is verified
- Additional verification confirms global configuration
- FVM global configuration is enforced for all projects
- Complete monorepo dependency management is executed

Remember: This rule focuses on automatic Flutter version
configuration based on project requirements. It stops execution on
any error and provides clear resolution steps.
