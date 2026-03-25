# Flutter Configuration Analysis

> Read and analyze Flutter/Dart configuration files for version info, dependencies, linter setup, and internationalization configuration (single app or multi-app monorepos).

---

Goal: Read and analyze Flutter/Dart configuration files for single app
or multi-app repositories.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire analysis
- Read multiple config files per tool call using parallel reads (3-5 files per response)
- Use batch grep commands instead of reading files one by one
- Pipe dependency list outputs through `| head -50`
- Reference cached artifacts from previous steps when available

MONOREPO DETECTION:
- First detect repository structure: single app (app/) or multi-app
  monorepo (apps/app1/, apps/app2/, etc.)
- If apps/ directory exists, analyze each app individually
- If packages/ directory exists, analyze each package individually

SINGLE APP ANALYSIS:
- Read completely and analyze:
  * app/pubspec.yaml (Flutter version, Dart SDK, dependencies,
    dev_dependencies, especially very_good_analysis,
    flutter_localizations)
  * app/analysis_options.yaml (includes, exclusions, rule overrides)
  * Check for .fvm/fvm_config.json or .fvmrc (Flutter version management)
  * Check for i18n configuration: app/l10n.yaml, app/lib/l10n/*.arb files
  * Verify flutter_localizations dependency in pubspec.yaml

MULTI-APP MONOREPO ANALYSIS:
- For each app in apps/ directory:
  * Read apps/<app_name>/pubspec.yaml (Flutter version, Dart SDK,
    dependencies, dev_dependencies, especially very_good_analysis,
    flutter_localizations)
  * Read apps/<app_name>/analysis_options.yaml (includes,
    exclusions, rule overrides)
  * Check for app-specific .fvm/fvm_config.json or .fvmrc in
    apps/<app_name>/
  * Check for app-specific i18n configuration:
    apps/<app_name>/l10n.yaml, apps/<app_name>/lib/l10n/*.arb files
  * Verify flutter_localizations dependency in each app's pubspec.yaml
  * Check for root-level .fvm/fvm_config.json or .fvmrc (shared
    across apps)
  * Check for root-level i18n configuration: l10n.yaml,
    lib/l10n/*.arb files
- Compare configurations across apps:
  * Flutter/Dart version consistency
  * Dependency version alignment
  * Analysis options consistency
  * i18n configuration consistency

PACKAGE ANALYSIS (if packages/ exists):
- For each package in packages/ directory:
  * Read packages/<package_name>/pubspec.yaml (Flutter version, Dart
    SDK, dependencies, dev_dependencies)
  * Read packages/<package_name>/analysis_options.yaml (includes,
    exclusions, rule overrides)
  * Check for package-specific .fvm/fvm_config.json or .fvmrc
  * Check for package-specific i18n configuration if applicable

Output format:
- Repository structure type (single app / multi-app monorepo)
- Extract exact Flutter and Dart SDK versions (per app if multi-app)
- List all dependencies and dev_dependencies (per app if multi-app)
- Note very_good_analysis version if present (per app if multi-app)
- Document analysis_options.yaml configuration (per app/package if
  applicable)
- Report internationalization setup status (per app if multi-app)
- Important: Do NOT recommend adding new languages or translations
- Do NOT recommend CODEOWNERS or SECURITY.md files - these are
  governance decisions, not technical requirements
- Identify any missing configuration files (per app if multi-app)
- Version consistency across apps/packages (if multi-app)
- Configuration inheritance patterns (if multi-app)
