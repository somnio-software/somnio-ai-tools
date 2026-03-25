# NestJS Test Coverage Runner

> Execute NestJS tests and generate comprehensive coverage reports with detailed analysis and recommendations for single app or monorepo

---

When requested to run tests and generate coverage, you will:

1. Execute NestJS tests with coverage collection
   (single app or per-app for monorepos)
2. Generate detailed coverage reports
3. Analyze coverage results and provide actionable insights
4. Identify areas needing more test coverage
5. Provide recommendations for improving test quality

----------------------------------------------------------------------
MONOREPO DETECTION
----------------------------------------------------------------------

First detect repository structure:
- Single app: Standard NestJS application structure
- Monorepo: nx workspace, turborepo, lerna, or apps/ structure
- If apps/ directory exists, analyze each app individually
- If packages/ directory exists, analyze each package individually

----------------------------------------------------------------------
EXECUTION STEPS
----------------------------------------------------------------------

IMPORTANT: Pipe all test command output through `tail -100` to capture
only the summary. Full test output floods the context window. The actual
coverage data is captured in coverage files on disk, not in stdout.

SINGLE APP EXECUTION:
Step 1: Run Tests with Coverage (Single App + Packages)
Execute the following commands in sequence:

```bash
# Detect package manager
if [ -f "pnpm-lock.yaml" ]; then
  PKG_MANAGER="pnpm"
  TEST_CMD="pnpm test:cov -- --silent"
elif [ -f "yarn.lock" ]; then
  PKG_MANAGER="yarn"
  TEST_CMD="yarn test:cov -- --silent"
else
  PKG_MANAGER="npm"
  TEST_CMD="npm run test:cov -- --silent"
fi

# 1. Run tests in root app directory
echo "Running tests in root app directory"
$TEST_CMD 2>&1 | tail -100

# 2. Run tests in all packages (if packages/ exists)
if [ -d "packages/" ]; then
  echo "Running tests in packages directory"
  for package_dir in packages/*/; do
    package_name=$(basename "$package_dir")
    echo "Running tests for package: $package_name"

    cd "$package_dir"

    if [ -f "package.json" ] && grep -q "test:cov" package.json; then
      $TEST_CMD 2>&1 | tail -100
    else
      echo "No test:cov script found for $package_name"
    fi

    cd ../..
  done
fi
```

MONOREPO EXECUTION:
Step 1: Run Tests with Coverage (Per App + All Packages)
Execute the following commands in sequence:

```bash
# Detect package manager
if [ -f "pnpm-lock.yaml" ]; then
  PKG_MANAGER="pnpm"
  TEST_CMD="pnpm test:cov -- --silent"
elif [ -f "yarn.lock" ]; then
  PKG_MANAGER="yarn"
  TEST_CMD="yarn test:cov -- --silent"
else
  PKG_MANAGER="npm"
  TEST_CMD="npm run test:cov -- --silent"
fi

# 1. Run tests for each app in apps/ directory
if [ -d "apps/" ]; then
  for app_dir in apps/*/; do
    app_name=$(basename "$app_dir")
    echo "Running tests for app: $app_name"
    
    cd "$app_dir"
    
    if [ -f "package.json" ] && grep -q "test:cov" package.json; then
      $TEST_CMD 2>&1 | tail -100
    else
      echo "No test:cov script found for $app_name"
    fi

    cd ../..
  done
fi

# 2. Run tests in packages (if root packages/ exists)
if [ -d "packages/" ]; then
  echo "Running tests in packages"
  for package_dir in packages/*/; do
    package_name=$(basename "$package_dir")
    echo "Running tests for package: $package_name"

    cd "$package_dir"

    if [ -f "package.json" ] && grep -q "test:cov" package.json; then
      $TEST_CMD 2>&1 | tail -100
    else
      echo "No test:cov script found for $package_name"
    fi

    cd ../..
  done
fi

# 3. Run root tests if applicable
if [ -f "package.json" ] && grep -q "test:cov" package.json; then
  echo "Running root tests..."
  $TEST_CMD 2>&1 | tail -100
fi
```

Step 2: Analyze Coverage Results
After running tests, analyze the coverage data:

SINGLE APP ANALYSIS:
```bash
# Check if coverage directory exists
if [ -d "coverage" ]; then
  echo "Coverage directory found"
  echo "Coverage files: $(find coverage/ -name '*.json' -o -name '*.html' 2>/dev/null | wc -l)"
  
  # Display coverage summary if available
  if [ -f "coverage/coverage-summary.json" ]; then
    cat coverage/coverage-summary.json | \
      jq '{lines,statements,functions,branches}' 2>/dev/null || \
      grep -E '"lines"|"statements"|"functions"|"branches"' \
      coverage/coverage-summary.json | head -4
  fi
  
  if [ -f "coverage/lcov-report/index.html" ]; then
    echo "Coverage HTML report available at: coverage/lcov-report/index.html"
  fi
else
  echo "No coverage directory found"
fi
```

MONOREPO ANALYSIS:
```bash
# Analyze coverage for each app
if [ -d "apps/" ]; then
  for app_dir in apps/*/; do
    app_name=$(basename "$app_dir")
    echo "Coverage analysis for app: $app_name"
    
    if [ -d "$app_dir/coverage" ]; then
      echo "✓ Coverage data found for $app_name"
      if [ -f "$app_dir/coverage/coverage-summary.json" ]; then
        cat "$app_dir/coverage/coverage-summary.json" | \
          jq '{lines,statements,functions,branches}' 2>/dev/null || \
          grep -E '"lines"|"statements"|"functions"|"branches"' \
          "$app_dir/coverage/coverage-summary.json" | head -4
      fi
    else
      echo "✗ No coverage data found for $app_name"
    fi
  done
fi

# Analyze packages coverage
if [ -d "packages/" ]; then
  echo "Packages coverage analysis:"
  for package_dir in packages/*/; do
    package_name=$(basename "$package_dir")
    echo "Coverage analysis for package: $package_name"
    
    if [ -d "$package_dir/coverage" ]; then
      echo "✓ Coverage data found for $package_name"
      if [ -f "$package_dir/coverage/coverage-summary.json" ]; then
        cat "$package_dir/coverage/coverage-summary.json" | \
          jq '{lines,statements,functions,branches}' 2>/dev/null || \
          grep -E '"lines"|"statements"|"functions"|"branches"' \
          "$package_dir/coverage/coverage-summary.json" | head -4
      fi
    else
      echo "✗ No coverage data found for $package_name"
    fi
  done
fi
```

Step 3: Calculate Overall Aggregated Coverage
Parse coverage data and calculate total coverage. Output MUST include a
line: Code Coverage: [X]%

```bash
echo "=== Coverage Aggregation ==="
total_lines=0
covered_lines=0

# Parse lcov.info (Jest default)
if [ -f "coverage/lcov.info" ]; then
  total_lines=$(grep -c "^DA:" coverage/lcov.info 2>/dev/null || echo 0)
  covered_lines=$(grep "^DA:" coverage/lcov.info 2>/dev/null | \
    grep -c ",[1-9]" || echo 0)
fi

# Monorepo: aggregate from apps/ and packages/
for cov_path in apps/*/coverage/lcov.info packages/*/coverage/lcov.info; do
  if [ -f "$cov_path" ]; then
    l=$(grep -c "^DA:" "$cov_path" 2>/dev/null || echo 0)
    c=$(grep "^DA:" "$cov_path" 2>/dev/null | grep -c ",[1-9]" || echo 0)
    total_lines=$((total_lines + l))
    covered_lines=$((covered_lines + c))
  fi
done

if [ $total_lines -gt 0 ]; then
  pct=$((covered_lines * 100 / total_lines))
  echo "Code Coverage: $pct%"
elif [ -f "coverage/coverage-summary.json" ]; then
  pct=$(cat coverage/coverage-summary.json | \
    jq -r '.total.lines.pct // empty' 2>/dev/null)
  [ -n "$pct" ] && echo "Code Coverage: ${pct}%"
fi
```

----------------------------------------------------------------------
COVERAGE ANALYSIS FRAMEWORK
----------------------------------------------------------------------

Coverage Categories:
- Excellent: 90-100%
- Good: 80-89%
- Fair: 70-79%
- Poor: 60-69%
- Critical: < 60%

File Analysis:
- Core business logic
  (src/modules/**/services/, src/modules/**/repositories/)
- Controllers (src/modules/**/controllers/, src/**/*.controller.ts)
- Guards and interceptors (src/guards/, src/interceptors/)
- Pipes and middleware (src/pipes/, src/middleware/)
- DTOs and entities (src/**/*.dto.ts, src/**/*.entity.ts)

Test Quality Indicators:
- Unit tests vs Integration tests vs E2E tests ratio
- Mock usage for external dependencies
- Test isolation and independence
- Assertion quality and coverage

----------------------------------------------------------------------
OUTPUT FORMAT
----------------------------------------------------------------------

MANDATORY: Your final output MUST include a line "Code Coverage: [X]%"
that the report generator will extract. Place it at the start of COVERAGE
OVERVIEW.

Provide the following structured output:

1. EXECUTION SUMMARY
   - Repository structure type (single app / monorepo)
   - Test execution status (per app and package if applicable)
   - Total tests run (per app and package if applicable)
   - Passed/Failed/Skipped counts (per app and package if applicable)
   - Execution time (per app and package if applicable)
   - Node.js version used for execution

2. COVERAGE OVERVIEW
   MANDATORY: Include exactly one line at the start of COVERAGE OVERVIEW:
   Code Coverage: [X]% (total project coverage, aggregated if monorepo)
   - App coverage percentage (per app if monorepo)
   - Packages coverage percentage (per package if applicable)
   - Overall aggregated coverage percentage
     (weighted average of all components)
   - Total lines of code (per app and package if applicable)
   - Lines covered (per app and package if applicable)
   - Lines missed (per app and package if applicable)
   - Cross-app coverage comparison (if monorepo)
   - Cross-package coverage comparison (if packages exist)

3. DETAILED COVERAGE BREAKDOWN
   - Coverage by file category (controllers, services, guards, etc.)
   - Top 10 files with lowest coverage (per app and package if applicable)
   - Files with 0% coverage (per app and package if applicable)
   - Critical files needing attention (per app and package if applicable)

4. TEST QUALITY ASSESSMENT
   - Test distribution analysis (unit/integration/e2e)
   - Mock usage evaluation (per app and package if applicable)
   - Test isolation assessment (per app and package if applicable)
   - Performance considerations (per app and package if applicable)

5. RECOMMENDATIONS
   - Priority files for test coverage improvement
     (per app and package if applicable)
   - Specific testing strategies (per app and package if applicable)
   - Test architecture suggestions (per app and package if applicable)
   - CI/CD integration recommendations (per app and package if applicable)
   - Node.js version management best practices
   - Cross-app testing consistency (if monorepo)
   - Cross-package testing consistency (if packages exist)

6. ACTION ITEMS
   - Immediate actions (high priority) (per app and package if applicable)
   - Medium-term improvements (per app and package if applicable)
   - Long-term testing strategy (per app and package if applicable)
   - nvm setup and version alignment
   - Monorepo coordination improvements (if monorepo)
   - Package testing coordination improvements (if packages exist)

----------------------------------------------------------------------
COVERAGE THRESHOLDS
----------------------------------------------------------------------

Recommended Coverage Targets:
- Overall project: 70%+
- Business logic (services): 80%+
- Controllers: 70%+
- Guards and interceptors: 75%+
- DTOs (validation logic): 60%+
- Shared packages: 80%+ (higher threshold due to reusability)

Critical Files (must have > 80% coverage):
- Authentication logic
- Authorization guards
- Payment processing
- Data validation
- Security-related functions
- Core business rules
- Public API services

----------------------------------------------------------------------
INTEGRATION WITH CI/CD
----------------------------------------------------------------------

Provide recommendations for:
- Coverage thresholds in CI (per app and package if applicable)
- Automated coverage reporting (per app and package if applicable)
- Coverage badge generation (per app and package if applicable)
- PR coverage requirements (per app and package if applicable)
- Coverage trend tracking (per app and package if applicable)
- Monorepo CI/CD coordination (if monorepo)
- Package testing coordination (if packages exist)
- Cross-package dependency testing strategies

Remember: Focus on actionable insights and specific recommendations
for improving test coverage and quality, considering single app,
monorepo, and package scenarios.
