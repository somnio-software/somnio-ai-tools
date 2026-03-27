# Flutter Testing Analysis

> Find and classify all test files, identify coverage configuration and test types for Flutter projects (single app or multi-app monorepos).

---

Goal: Find and classify all test files, identify coverage configuration
and test types for single app or multi-app repositories.

EFFICIENCY REQUIREMENTS:
- Minimize tool call round-trips to reduce context accumulation
- Use batch grep/find commands to classify test files instead of
  reading individual files one by one
- Use ONE find+grep command to classify ALL test files at once:
  ```bash
  find . -name "*_test.dart" -type f \
    ! -path "./.dart_tool/*" ! -path "./build/*" 2>/dev/null | \
  while read f; do
    if grep -q "import.*bloc_test\|BlocTest\|blocTest" "$f" 2>/dev/null; then
      echo "BLOC|$f"
    elif grep -q "testWidgets\|WidgetTester\|pumpWidget" "$f" 2>/dev/null; then
      echo "WIDGET|$f"
    else
      echo "UNIT|$f"
    fi
  done | sort
  ```
- Do NOT read individual test files to check their imports
- Coverage execution results are already available from the
  @flutter_test_coverage artifact - reference those instead of
  re-analyzing coverage data
- Coverage workflow thresholds are already available from the
  @flutter_cicd_analysis artifact - reference those instead of
  re-searching workflows
- Target: < 8 total tool calls for this entire analysis

MONOREPO DETECTION:
- First detect repository structure: single app (app/) or multi-app
  monorepo (apps/app1/, apps/app2/, etc.)
- If apps/ directory exists, analyze each app individually
- If packages/ directory exists, analyze each package individually

SINGLE APP TESTING ANALYSIS:
- Search and classify testing setup:
  * Find all *_test.dart files in app/test/ and app/packages/*/test/
  * Count total test files
  * Classify by type based on imports: bloc_test (uses bloc_test
    package), widget tests (uses testWidgets), unit tests (other)
  * Search workflows for coverage enforcement (lcov, coverage
    threshold, --coverage flag)
  * Look for test/ directory structure in main app and each package
  * Integrate coverage results from Flutter Test Coverage Runner
  * Include coverage percentage and threshold verification

MULTI-APP MONOREPO TESTING ANALYSIS:
- Root-level testing configuration:
  * Search for root-level test configurations
  * Check for shared testing utilities or packages
  * Look for root-level coverage configuration
- Per-app testing analysis:
  * For each app in apps/ directory:
    - Find all *_test.dart files in apps/<app_name>/test/ and
      apps/<app_name>/packages/*/test/
    - Count total test files per app
    - Classify by type based on imports: bloc_test (uses bloc_test
      package), widget tests (uses testWidgets), unit tests (other)
    - Look for test/ directory structure in each app
    - Check for app-specific coverage configuration
    - Integrate coverage results from Flutter Test Coverage Runner per app
    - Include coverage percentage and threshold verification per app
- Cross-app testing consistency:
  * Compare testing patterns across apps
  * Verify consistent test structure
  * Check for shared vs app-specific test utilities
- Workflow testing analysis:
  * Search workflows for app-specific testing:
    - Look for workflows that test specific apps (e.g., "cd
      apps/app1 && flutter test")
    - Check for matrix strategies that test multiple apps
    - Verify each app has proper test execution
  * Search workflows for coverage enforcement (lcov, coverage
    threshold, --coverage flag)
  * Check for per-app coverage collection

PACKAGE TESTING ANALYSIS (if packages/ exists):
- For each package in packages/ directory:
  * Find all *_test.dart files in packages/<package_name>/test/
  * Count total test files per package
  * Classify by type based on imports
  * Look for package-specific test configurations
  * Check for package-specific coverage configuration

COVERAGE ANALYSIS:
- Single app coverage:
  * Look for coverage/lcov.info

  * Verify coverage thresholds in workflows
- Multi-app coverage:
  * Look for per-app coverage: coverage/app1/lcov.info,
    coverage/app2/lcov.info
  * Verify per-app coverage thresholds
  * Check for aggregated coverage reports
  * Verify coverage execution per app

Output format:

MANDATORY FIRST LINES: The output artifact MUST begin with the
"Code Coverage:" and "Coverage Breakdown:" lines copied VERBATIM from
the preflight coverage artifact at:
  reports/.artifacts/flutter_health/step_00_test_coverage.md

Copy the "Code Coverage:" line and ALL "Coverage Breakdown:" lines
exactly as they appear. Do NOT summarize, reformat, or omit any line.
The report generator depends on these exact lines for Section 7.

If the preflight artifact is missing, write:
  Code Coverage: 0% (coverage data unavailable from preflight)
  Coverage Breakdown:
    (no coverage data — preflight artifact missing)

After the mandatory coverage lines, include:
- Repository structure type (single app / multi-app monorepo)
- Total count of test files (per app if multi-app)
- Breakdown by test type (unit, widget, bloc) (per app if multi-app)
- Coverage configuration found in workflows (per app if multi-app)
- Test directory structure analysis (per app if multi-app)
- Coverage percentage and threshold status (per app if multi-app)
- Any missing test configurations (per app if multi-app)
- Testing consistency across apps/packages (if multi-app)
- Cross-app testing patterns and shared utilities (if multi-app)
- Per-app vs aggregated coverage analysis (if multi-app)
