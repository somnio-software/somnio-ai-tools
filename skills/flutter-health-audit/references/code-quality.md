# Flutter Code Quality Analysis

> Analyze linter configuration, exclusions, and code quality enforcement for Flutter projects (single app or multi-app monorepos).

---

Goal: Analyze linter configuration, exclusions, and code quality
enforcement for single app or multi-app repositories.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire analysis
- Read 3-5 files per tool call using parallel reads
- Use batch grep commands to find lint suppressions across all files at once
- Group file reads by directory (e.g., read all analysis_options.yaml files together)
- Pipe large outputs through `| head -50`

MONOREPO DETECTION:
- First detect repository structure: single app (app/) or multi-app
  monorepo (apps/app1/, apps/app2/, etc.)
- If apps/ directory exists, analyze each app individually
- If packages/ directory exists, analyze each package individually

SINGLE APP ANALYSIS:
- Confirm very_good_analysis version in app/pubspec.yaml
  dev_dependencies
- Review app/analysis_options.yaml: included package, exclusions
  list, rule overrides
- Search workflows for "flutter analyze" or "dart analyze" with
  fatal-infos or fatal-warnings flags
- Search workflows for "flutter format" or "dart format
  --set-exit-if-changed"
- Identify any stored analyzer output or linter warnings (if absent,
  mark as neutral)

MULTI-APP MONOREPO ANALYSIS:
- For each app in apps/ directory:
  * Confirm very_good_analysis version in
    apps/<app_name>/pubspec.yaml dev_dependencies
  * Review apps/<app_name>/analysis_options.yaml: included package,
    exclusions list, rule overrides
  * Check for app-specific analysis_options.yaml or inheritance from
    root
- Search workflows for app-specific analysis:
  * Look for workflows that analyze specific apps (e.g., "cd
    apps/app1 && flutter analyze")
  * Check for matrix strategies that test multiple apps
  * Verify each app has proper analysis enforcement
- Search workflows for "flutter analyze" or "dart analyze" with
  fatal-infos or fatal-warnings flags
- Search workflows for "flutter format" or "dart format
  --set-exit-if-changed"
- Identify any stored analyzer output or linter warnings per app (if
  absent, mark as neutral)

PACKAGE ANALYSIS (if packages/ exists):
- For each package in packages/ directory:
  * Confirm very_good_analysis version in
    packages/<package_name>/pubspec.yaml dev_dependencies
  * Review packages/<package_name>/analysis_options.yaml: included
    package, exclusions list, rule overrides
  * Check for package-specific analysis_options.yaml or inheritance
    from root

Output format:
- Repository structure type (single app / multi-app monorepo)
- very_good_analysis version and configuration (per app if
  multi-app)
- analysis_options.yaml setup details (per app/package if
  applicable)
- Workflow analysis enforcement status (per app if multi-app)
- Format checking configuration
- Any linter warnings or issues found (per app if multi-app)
- Missing code quality configurations (per app if multi-app)
- Consistency across apps/packages (if multi-app)
