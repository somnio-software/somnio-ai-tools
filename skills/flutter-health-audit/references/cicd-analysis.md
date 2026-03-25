# Flutter CI/CD Analysis

> Read all GitHub Actions workflows and related CI/CD configuration files for Flutter projects (single app or multi-app monorepos).

---

Goal: Read all GitHub Actions workflows and related CI/CD
configuration files for single app or multi-app repositories.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire analysis
- Read 3-5 workflow files per tool call using parallel reads
- Use batch grep commands to search across all workflow files at once
- Do NOT read workflow files one at a time
- Reference cached artifacts from previous steps when available

IMPORTANT EXCLUSIONS:
- Do NOT recommend operational workflows (deployment, monitoring,
  performance tracking)
- Do NOT recommend release automation beyond basic tagging
- Do NOT recommend vulnerability scanning beyond dependabot
- Focus ONLY on technical CI/CD (format, analyze, test, coverage,
  spell-check)
- Do NOT analyze, recommend, or consider CODEOWNERS files
- Do NOT analyze, recommend, or consider SECURITY.md files
- These are governance decisions, not technical CI/CD requirements

CRITICAL: Verify CI/CD files in the CORRECT locations based on
repository structure. This is mandatory for accurate analysis.

MONOREPO DETECTION:
- First detect repository structure: single app (app/) or multi-app
  monorepo (apps/app1/, apps/app2/, etc.)
- CRITICAL: Check if apps/ directory exists at root level
- CRITICAL: If apps/ directory exists, verify it contains
  subdirectories with pubspec.yaml files
- CRITICAL: Check for nested packages structure:
  apps/<app_name>/packages/ (app-specific packages)
- CRITICAL: Check for shared packages structure: apps/packages/
  (shared packages across apps)
- If apps/ directory exists, analyze each app individually
- If packages/ directory exists at root level, analyze each package
  individually
- If apps/<app_name>/packages/ exists, analyze each nested package
  individually
- VERIFY the correct file locations based on detected structure

EFFICIENCY: When reading workflow files, make multiple parallel read
calls (3-5 files per response) instead of reading one file per
response. This reduces context accumulation from round-trips.

SINGLE APP CI/CD ANALYSIS:
MANDATORY VERIFICATION: Check ONLY root-level .github/ directory
for single app projects.

- Read and analyze SPECIFIC files in .github/:
  * List all .github/workflows/*.yaml and .github/workflows/*.yml files
  * Read each workflow file completely (main.yaml and all
    package-specific workflows)
  * Read .github/dependabot.yaml
  * Read .github/cspell.json
  * Read .github/PULL_REQUEST_TEMPLATE.md
  * For each workflow, identify: format checks, analyze steps,
    test steps, coverage thresholds, spell-check, release
    automation
  * CRITICAL: Verify `min_coverage` is at least 70. (e.g.,
    `min_coverage: 70` is OK, `min_coverage: 69` is ERROR)
  * Verify monorepo naming: for each package in packages/<name>/,
    confirm .github/workflows/<name>.yaml exists

VERIFICATION CHECKLIST FOR SINGLE APP:
- [ ] .github/workflows/ directory exists
- [ ] At least one workflow file present
- [ ] .github/dependabot.yaml present (if configured)
- [ ] .github/cspell.json present (if configured)
- [ ] .github/PULL_REQUEST_TEMPLATE.md present (if configured)
- [ ] Workflows contain required checks (format, analyze, test, coverage)
- [ ] Coverage threshold `min_coverage` is >= 70%

MULTI-APP MONOREPO CI/CD ANALYSIS:
MANDATORY VERIFICATION: Check BOTH root-level AND per-app
.github/ directories for multi-app projects.

CRITICAL STRUCTURE VERIFICATION:
- Verify apps/ directory exists at root level
- Verify apps/ directory contains subdirectories (apps/app1/,
  apps/app2/, etc.)
- Verify each app subdirectory contains pubspec.yaml file
- Verify nested packages structure: apps/<app_name>/packages/ (if exists)
- Verify shared packages structure: apps/packages/ (if exists)
- Verify root-level packages structure: packages/ (if exists)
- If apps/ directory does not exist, treat as single-app repository

- Root-level CI/CD configuration (MANDATORY):
  * Read and analyze SPECIFIC files in .github/:
    - List all .github/workflows/*.yaml and .github/workflows/*.yml files
    - Read each workflow file completely
    - Read .github/dependabot.yaml
    - Read .github/cspell.json
    - Read .github/PULL_REQUEST_TEMPLATE.md
  * Identify root-level workflows: format checks, analyze steps,
    test steps, coverage thresholds, spell-check, release
    automation
  * CRITICAL: Verify `min_coverage` is at least 70. (e.g.,
    `min_coverage: 70` is OK, `min_coverage: 69` is ERROR)
  * Check for shared CI/CD utilities or configurations

ROOT-LEVEL VERIFICATION CHECKLIST:
- [ ] .github/workflows/ directory exists
- [ ] Root-level workflow files present
- [ ] .github/dependabot.yaml present (if configured)
- [ ] .github/cspell.json present (if configured)
- [ ] .github/PULL_REQUEST_TEMPLATE.md present (if configured)
- [ ] Root workflows contain required checks
- [ ] Root workflows coverage threshold `min_coverage` is >= 70%

- Per-app CI/CD analysis (MANDATORY for each app):
  * For each app in apps/ directory:
    - Verify .github/workflows/<app_name>.yaml or
      .github/workflows/<app_name>.yml exists
    - Read app-specific workflow files completely
    - For each app workflow, identify: format checks, analyze
      steps, test steps, coverage thresholds, spell-check, release
      automation
    - CRITICAL: Verify `min_coverage` is at least 70. (e.g.,
      `min_coverage: 70` is OK, `min_coverage: 69` is ERROR)
    - Check for app-specific dependabot.yaml in apps/<app_name>/.github/
    - Check for app-specific cspell.json in apps/<app_name>/.github/
    - Check for app-specific PR template in apps/<app_name>/.github/
    - Important: Do NOT recommend platform-specific workflows for
      Android/iOS builds - these are deployment decisions, not
      technical requirements
    - Do NOT recommend CODEOWNERS or SECURITY.md files - these are
      governance decisions, not technical requirements

PER-APP VERIFICATION CHECKLIST (for each app in apps/):
- [ ] .github/workflows/<app_name>.yaml exists
- [ ] App-specific workflow contains required checks
- [ ] App-specific workflow coverage threshold `min_coverage` is >= 70%
- [ ] apps/<app_name>/.github/dependabot.yaml present (if configured)
- [ ] apps/<app_name>/.github/cspell.json present (if configured)
- [ ] apps/<app_name>/.github/PULL_REQUEST_TEMPLATE.md present (if
  configured)
- Cross-app CI/CD consistency:
  * Compare workflow patterns across apps
  * Verify consistent CI/CD practices
  * Check for shared vs app-specific configurations
  * Verify matrix strategies for multi-app testing

- Package-specific workflows (if packages/ exists):
  MANDATORY VERIFICATION: Check ONLY workflow files for packages
  (no dependabot/cspell/PR template).
  
  * For each package in packages/ directory:
    - Verify .github/workflows/<package_name>.yaml or
      .github/workflows/<package_name>.yml exists
    - Read package-specific workflow files completely
    - For each package workflow, identify: format checks, analyze
      steps, test steps, coverage thresholds, spell-check, release
      automation
    - CRITICAL: Verify `min_coverage` is at least 70. (e.g.,
      `min_coverage: 70` is OK, `min_coverage: 69` is ERROR)

- Nested packages workflows (if apps/<app_name>/packages/ exists):
  MANDATORY VERIFICATION: Check ONLY workflow files for nested
  packages (no dependabot/cspell/PR template).
  
  * For each app in apps/ directory:
    * For each nested package in apps/<app_name>/packages/ directory:
      - Verify .github/workflows/<app_name>_<package_name>.yaml or
        .github/workflows/<app_name>_<package_name>.yml exists
      - Read nested package-specific workflow files completely
      - For each nested package workflow, identify: format checks,
        analyze steps, test steps, coverage thresholds, spell-check,
        release automation
      - CRITICAL: Verify `min_coverage` is at least 70. (e.g.,
        `min_coverage: 70` is OK, `min_coverage: 69` is ERROR)

- Shared packages workflows (if apps/packages/ exists):
  MANDATORY VERIFICATION: Check ONLY workflow files for shared
  packages (no dependabot/cspell/PR template).
  
  * For each shared package in apps/packages/ directory:
    - Verify .github/workflows/shared_<package_name>.yaml or
      .github/workflows/shared_<package_name>.yml exists
    - Read shared package-specific workflow files completely
    - For each shared package workflow, identify: format checks,
      analyze steps, test steps, coverage thresholds, spell-check,
      release automation
    - CRITICAL: Verify `min_coverage` is at least 70. (e.g.,
      `min_coverage: 70` is OK, `min_coverage: 69` is ERROR)

PACKAGE VERIFICATION CHECKLIST (for each package in packages/):
- [ ] .github/workflows/<package_name>.yaml exists
- [ ] Package-specific workflow contains required checks
- [ ] Package-specific workflow coverage threshold `min_coverage` is
  >= 70%
- [ ] NO dependabot.yaml expected in packages/ (root-level only)
- [ ] NO cspell.json expected in packages/ (root-level only)
- [ ] NO PULL_REQUEST_TEMPLATE.md expected in packages/ (root-level only)

NESTED PACKAGE VERIFICATION CHECKLIST (for each nested package in
apps/<app_name>/packages/):
- [ ] .github/workflows/<app_name>_<package_name>.yaml exists
- [ ] Nested package-specific workflow contains required checks
- [ ] Nested package-specific workflow coverage threshold
  `min_coverage` is >= 70%
- [ ] NO dependabot.yaml expected in nested packages/ (root-level only)
- [ ] NO cspell.json expected in nested packages/ (root-level only)
- [ ] NO PULL_REQUEST_TEMPLATE.md expected in nested packages/
  (root-level only)

SHARED PACKAGE VERIFICATION CHECKLIST (for each shared package in
apps/packages/):
- [ ] .github/workflows/shared_<package_name>.yaml exists
- [ ] Shared package-specific workflow contains required checks
- [ ] Shared package-specific workflow coverage threshold
  `min_coverage` is >= 70%
- [ ] NO dependabot.yaml expected in shared packages/ (root-level only)
- [ ] NO cspell.json expected in shared packages/ (root-level only)
- [ ] NO PULL_REQUEST_TEMPLATE.md expected in shared packages/
  (root-level only)

WORKFLOW ANALYSIS DETAILS:
- For each workflow, identify:
  * Format checks: "flutter format" or "dart format --set-exit-if-changed"
  * Analyze steps: "flutter analyze" or "dart analyze" with
    fatal-infos or fatal-warnings flags
  * Test steps: "flutter test" with coverage flags
  * Coverage thresholds: lcov, coverage percentage requirements
  * CRITICAL: `min_coverage` MUST be >= 70. (40=Error, 69=Error,
    70=OK, 71=OK)
  * Spell-check: cspell integration
  * Release automation: tagging, changelog generation, publishing
- Important exclusions:
  * Do NOT recommend platform-specific workflows for Android/iOS
    builds - these are deployment decisions, not technical
    requirements
  * Do NOT recommend CODEOWNERS or SECURITY.md files - these are
    governance decisions, not technical requirements
  * Do NOT recommend operational workflows (deployment, monitoring,
    performance tracking)
  * Do NOT recommend release automation beyond basic tagging
  * Do NOT recommend vulnerability scanning beyond dependabot
- Verify monorepo naming conventions:
  * For each package in packages/<name>/, confirm
    .github/workflows/<name>.yaml exists
  * For each app in apps/<name>/, confirm .github/workflows/<name>.yaml
    exists
  * For each nested package in apps/<app_name>/packages/<package_name>/,
    confirm .github/workflows/<app_name>_<package_name>.yaml exists
  * For each shared package in apps/packages/<package_name>/,
    confirm .github/workflows/shared_<package_name>.yaml exists
  * Missing package/app-specific workflows count as configuration gaps

MANDATORY OUTPUT VERIFICATION:
- Repository structure type (single app / multi-app monorepo)
- CRITICAL: Explicitly state whether apps/ directory exists and
  contains subdirectories
- CRITICAL: If apps/ directory exists, list all apps found
  (apps/app1/, apps/app2/, etc.)
- CRITICAL: If apps/ directory does not exist, explicitly state
  "Single app repository - no apps/ directory found"
- CRITICAL: List all packages found in each location:
  * Root-level packages: packages/<package_name>/
  * Nested packages: apps/<app_name>/packages/<package_name>/
  * Shared packages: apps/packages/<package_name>/
- VERIFICATION CHECKLIST COMPLETION STATUS for each level:
  * Root-level verification checklist (always required)
  * Per-app verification checklist (for each app in apps/ if multi-app)
  * Package verification checklist (for each package in packages/
    if exists)
  * Nested package verification checklist (for each nested package
    if exists)
  * Shared package verification checklist (for each shared package
    if exists)
- List all workflow files found with their purposes (per app if multi-app)
- Document each workflow's checks (format, analyze, test, coverage,
  etc.) (per app if multi-app)
- Note any missing package-specific workflows for monorepos
- Note any missing app-specific workflows for multi-app monorepos
- Report CI/CD configuration completeness (per app if multi-app)
- Identify any missing CI/CD files (.github/dependabot.yaml, etc.)
  in CORRECT locations only
- CI/CD consistency across apps/packages (if multi-app)
- Cross-app workflow patterns and shared configurations (if multi-app)
- Matrix strategies and multi-app testing approaches (if multi-app)

CRITICAL VERIFICATION RULES:
- Single app: Check ONLY .github/ directory
- Multi-app: Check .github/ AND apps/<app>/.github/ directories
- Root-level packages: Check ONLY .github/workflows/<package>.yaml files
- Nested packages: Check ONLY .github/workflows/<app>_<package>.yaml files
- Shared packages: Check ONLY .github/workflows/shared_<package>.yaml
  files
- Do NOT expect dependabot/cspell/PR template in packages/ directories
- Do NOT recommend CODEOWNERS or SECURITY.md files

CRITICAL: Do NOT report missing CODEOWNERS or SECURITY.md files as
CI/CD configuration gaps.
These are governance decisions, not technical CI/CD requirements.
If you see a rule asking for them, IGNORE IT. They are explicitly
excluded.
