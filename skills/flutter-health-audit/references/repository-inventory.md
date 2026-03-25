# Flutter Repository Inventory

> Detect repository structure, platform folders, monorepo packages, and feature organization for Flutter projects (single app or multi-app monorepos).

---

Goal: Detect repository structure, platform folders, monorepo packages,
and feature organization for single app or multi-app repositories.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 6 total tool calls for this entire analysis
- Use batch find/ls commands to inventory directory structure in one pass
- Read multiple pubspec.yaml files per tool call using parallel reads
- Do NOT read individual source files to count them — use find + wc

IMPORTANT EXCLUSIONS:
- Do NOT analyze, recommend, or consider CODEOWNERS files
- Do NOT analyze, recommend, or consider SECURITY.md files
- These are governance decisions, not technical requirements

MONOREPO DETECTION:
- First detect repository structure: single app (app/) or multi-app
  monorepo (apps/app1/, apps/app2/, etc.)
- If apps/ directory exists, analyze each app individually
- If packages/ directory exists, analyze each package individually

SINGLE APP INVENTORY:
- Platform folders present in app/ (android/, ios/, web/, macos/,
  windows/, linux/)
- All packages in app/packages/ directory (list names)
- All feature folders in app/lib/ (count directories, exclude gen/,
  l10n/, utils/, extensions/, constants/)
- Presence of .fvm/ directory or .fvm/fvm_config.json

MULTI-APP MONOREPO INVENTORY:
- Root-level structure:
  * Overall repository structure type (multi-app monorepo)
  * Root-level packages/ directory (if exists)
  * Root-level .fvm/ directory or .fvm/fvm_config.json
  * Root-level feature folders (if any)
- Per-app inventory:
  * For each app in apps/ directory:
    - Platform folders present in apps/<app_name>/ (android/, ios/,
      web/, macos/, windows/, linux/)
    - All packages in apps/<app_name>/packages/ directory (list names)
    - All feature folders in apps/<app_name>/lib/ (count directories,
      exclude gen/, l10n/, utils/, extensions/, constants/)
    - Presence of apps/<app_name>/.fvm/ directory or
      apps/<app_name>/.fvm/fvm_config.json
- Cross-app analysis:
  * Compare platform support across apps
  * Compare package usage across apps
  * Compare feature organization across apps
  * Identify shared vs app-specific packages
  * Identify shared vs app-specific features

PACKAGE ANALYSIS (if packages/ exists):
- For each package in packages/ directory:
  * Package name and purpose
  * Platform folders present in packages/<package_name>/ (if applicable)
  * Feature folders in packages/<package_name>/lib/ (if applicable)
  * Package-specific .fvm/ configuration (if applicable)

Output format:
- Repository structure type (single app / multi-app monorepo)
- Provide exact counts for each category (per app if multi-app)
- List specific package names found (per app if multi-app)
- Note any missing expected directories (per app if multi-app)
- Document the overall repository structure type
- Cross-app consistency analysis (if multi-app)
- Shared vs app-specific resources breakdown (if multi-app)
- Platform support matrix across apps (if multi-app)
- Package usage patterns across apps (if multi-app)
