# Python Test Coverage Runner

> Execute pytest with branch coverage, generate coverage.xml and term-missing output, parse results, and emit verbatim "Code Coverage:" + "Coverage Breakdown:" into reports/.artifacts/python_health/step_00_test_coverage.md

---

When requested to run tests and generate coverage, you will:

1. Execute pytest with `--cov=<pkg> --cov-branch --cov-report=xml
   --cov-report=term-missing` (single package or per-member for
   monorepos)
2. Parse the resulting `coverage.xml` for aggregate line/branch
   percentages
3. Emit a verbatim `Code Coverage: X%` line for the report generator
4. Emit a verbatim `Coverage Breakdown:` table per source package
5. Write all findings to
   `reports/.artifacts/python_health/step_00_test_coverage.md`

----------------------------------------------------------------------
MONOREPO DETECTION
----------------------------------------------------------------------

First detect repository structure:
- Single package: one `pyproject.toml` at root; `src/<pkg>/` or flat
  `<pkg>/` layout
- Monorepo: `packages/` or `apps/` subdirectories, or a uv workspace

```bash
echo "=== Repository Structure ==="
if grep -qE '^\[tool\.uv\.workspace\]' pyproject.toml 2>/dev/null || \
   [ -d "packages" ] || [ -d "apps" ]; then
  REPO_TYPE="monorepo"
  echo "Monorepo detected"
else
  REPO_TYPE="single"
  echo "Single-package repository"
fi
```

----------------------------------------------------------------------
PACKAGE NAME DETECTION
----------------------------------------------------------------------

Resolve the importable package name before running pytest --cov=<pkg>:

```bash
echo "=== Package Name Detection ==="
resolve_pkg_name() {
  local dir="${1:-.}"
  local name=""

  # 1. pyproject.toml [project] name
  if [ -f "$dir/pyproject.toml" ]; then
    name=$(grep -E '^name\s*=' "$dir/pyproject.toml" 2>/dev/null | \
      head -1 | sed 's/.*=\s*"\([^"]*\)".*/\1/' | tr '-' '_')
  fi

  # 2. src/ layout — first directory under src/
  if [ -z "$name" ] && [ -d "$dir/src" ]; then
    name=$(ls -d "$dir/src"/*/ 2>/dev/null | head -1 | xargs basename 2>/dev/null)
  fi

  # 3. Flat layout — first directory containing __init__.py
  if [ -z "$name" ]; then
    name=$(find "$dir" -maxdepth 2 -name "__init__.py" ! -path "*/test*" \
      ! -path "*/.venv/*" | head -1 | xargs dirname | xargs basename 2>/dev/null)
  fi

  echo "${name:-}"
}
```

----------------------------------------------------------------------
EXECUTION STEPS
----------------------------------------------------------------------

IMPORTANT: Pipe full pytest stdout through `tail -200` to avoid
flooding the context window. Coverage data is captured in `coverage.xml`
and `term-missing` output on disk.

SINGLE PACKAGE EXECUTION:

```bash
echo "=== Running Tests with Coverage (single package) ==="
PKG_NAME=$(resolve_pkg_name ".")
echo "Coverage target package: ${PKG_NAME:-<not detected — using '.' as fallback>}"
COV_TARGET="${PKG_NAME:-.}"

mkdir -p reports/.artifacts/python_health

# Run pytest with branch coverage
uv run pytest \
  --cov="$COV_TARGET" \
  --cov-branch \
  --cov-report=xml:coverage.xml \
  --cov-report=term-missing \
  -q \
  2>&1 | tail -200

EXIT_CODE=${PIPESTATUS[0]}
echo "pytest exit code: $EXIT_CODE"
```

MONOREPO EXECUTION:

```bash
echo "=== Running Tests with Coverage (monorepo) ==="
mkdir -p reports/.artifacts/python_health

run_member_coverage() {
  local dir="$1"
  local label="$2"
  local pkg_name

  pkg_name=$(resolve_pkg_name "$dir")
  local cov_target="${pkg_name:-.}"
  echo "--- $label (cov target: $cov_target) ---"

  (
    cd "$dir"
    uv run pytest \
      --cov="$cov_target" \
      --cov-branch \
      --cov-report=xml:coverage.xml \
      --cov-report=term-missing \
      -q \
      2>&1 | tail -200
    echo "Exit code: $?"
  )
}

# Root (if it has tests)
if [ -f "pyproject.toml" ] && [ -d "tests" ]; then
  run_member_coverage "." "root"
fi

# packages/
if [ -d "packages" ]; then
  for dir in packages/*/; do
    [ -f "$dir/pyproject.toml" ] && run_member_coverage "$dir" "$dir"
  done
fi

# apps/
if [ -d "apps" ]; then
  for dir in apps/*/; do
    [ -f "$dir/pyproject.toml" ] && run_member_coverage "$dir" "$dir"
  done
fi
```

----------------------------------------------------------------------
COVERAGE PARSING
----------------------------------------------------------------------

Parse `coverage.xml` (Cobertura format) to extract line-rate and
branch-rate. Do NOT invent numbers — read only from the generated file.

```bash
echo "=== Parsing coverage.xml ==="
parse_coverage_xml() {
  local xml="${1:-coverage.xml}"

  if [ ! -f "$xml" ]; then
    echo "WARNING: $xml not found — pytest may have failed or pkg name is wrong"
    return 1
  fi

  # line-rate and branch-rate are attributes on the <coverage> root element
  LINE_RATE=$(grep -oE 'line-rate="[0-9.]+"' "$xml" | head -1 | \
    grep -oE '[0-9.]+')
  BRANCH_RATE=$(grep -oE 'branch-rate="[0-9.]+"' "$xml" | head -1 | \
    grep -oE '[0-9.]+')

  # Convert 0.xx to percentage
  LINE_PCT=$(awk "BEGIN {printf \"%.0f\", $LINE_RATE * 100}" 2>/dev/null)
  BRANCH_PCT=$(awk "BEGIN {printf \"%.0f\", $BRANCH_RATE * 100}" 2>/dev/null)

  echo "line-rate:   $LINE_RATE  ($LINE_PCT%)"
  echo "branch-rate: $BRANCH_RATE  ($BRANCH_PCT%)"
  echo "$LINE_PCT $BRANCH_PCT"
}

COVERAGE_RESULT=$(parse_coverage_xml coverage.xml)
LINE_PCT=$(echo "$COVERAGE_RESULT" | tail -1 | awk '{print $1}')
BRANCH_PCT=$(echo "$COVERAGE_RESULT" | tail -1 | awk '{print $2}')

# Overall: average of line and branch coverage
if [ -n "$LINE_PCT" ] && [ -n "$BRANCH_PCT" ]; then
  OVERALL_PCT=$(awk "BEGIN {printf \"%.0f\", ($LINE_PCT + $BRANCH_PCT) / 2}")
else
  OVERALL_PCT="${LINE_PCT:-0}"
fi
```

----------------------------------------------------------------------
MANDATORY OUTPUT LINES
----------------------------------------------------------------------

The report generator extracts "Code Coverage:" and "Coverage Breakdown:"
verbatim. These lines MUST appear exactly as shown.

```bash
echo "Code Coverage: ${OVERALL_PCT}%"
echo ""
echo "Coverage Breakdown:"
echo "| Metric         | Rate   | Percentage |"
echo "|----------------|--------|------------|"
echo "| Line coverage  | $LINE_RATE | ${LINE_PCT}%       |"
echo "| Branch coverage| $BRANCH_RATE | ${BRANCH_PCT}%       |"
echo "| Overall        |        | ${OVERALL_PCT}%       |"
```

----------------------------------------------------------------------
ARTIFACT FILE
----------------------------------------------------------------------

Write findings to the artifact path. This file is consumed by the
report generator in the final step.

```bash
ARTIFACT_DIR="reports/.artifacts/python_health"
ARTIFACT_FILE="$ARTIFACT_DIR/step_00_test_coverage.md"
mkdir -p "$ARTIFACT_DIR"

cat > "$ARTIFACT_FILE" << EOF
# Test Coverage Results

## Execution Summary
- Repository type: $REPO_TYPE
- Coverage target: $COV_TARGET
- pytest exit code: $EXIT_CODE

## Coverage Overview

Code Coverage: ${OVERALL_PCT}%

Coverage Breakdown:
| Metric          | Rate    | Percentage |
|-----------------|---------|------------|
| Line coverage   | $LINE_RATE | ${LINE_PCT}%       |
| Branch coverage | $BRANCH_RATE | ${BRANCH_PCT}%       |
| Overall         |         | ${OVERALL_PCT}%       |

## Raw term-missing Output
(Captured above from pytest --cov-report=term-missing)

## Notes
- Source file: coverage.xml (Cobertura format)
- Branch coverage requires --cov-branch flag (already set)
- If coverage.xml is missing: confirm package name resolution above
  and that pytest ran without import errors
EOF

echo "Artifact written to: $ARTIFACT_FILE"
```

----------------------------------------------------------------------
COVERAGE ANALYSIS FRAMEWORK
----------------------------------------------------------------------

Coverage categories (line rate):
- Excellent: 90-100%
- Good:      80-89%
- Fair:      70-79%
- Poor:      60-69%
- Critical:  < 60%

File-level analysis (read from coverage.xml `<class>` elements):
- Source files with 0% line coverage
- Source files with line coverage < 50%
- Files excluded from measurement (check `[tool.coverage.run] omit`)

----------------------------------------------------------------------
OUTPUT FORMAT
----------------------------------------------------------------------

MANDATORY: Your final analysis MUST include the verbatim lines:
  Code Coverage: [X]%
  Coverage Breakdown:

Place "Code Coverage: X%" at the start of the COVERAGE OVERVIEW
section. The report generator extracts this line by exact string match.

Provide the following structured output:

1. EXECUTION SUMMARY
   - Repository structure (single / monorepo)
   - pytest command used
   - Total tests: passed / failed / errors / skipped
   - Members executed (monorepo)
   - pytest exit code

2. COVERAGE OVERVIEW
   Code Coverage: X%  ← MANDATORY verbatim line
   - Line coverage %
   - Branch coverage %
   - Overall (average of line + branch) %

3. Coverage Breakdown:   ← MANDATORY verbatim line
   Per-file or per-package table from coverage.xml

4. FILES NEEDING ATTENTION
   - Zero-coverage files
   - Files below 50% line coverage
   - Missing test files for source modules

5. RECOMMENDATIONS
   - Untested modules to prioritise
   - Use of pytest markers and parametrize for edge cases
   - conftest.py fixture patterns for reducing boilerplate
   - CI coverage gate suggestion (e.g. --cov-fail-under=80)

6. ACTION ITEMS
   - Immediate: add tests for 0% files
   - Medium-term: raise coverage gate in CI
   - Long-term: property-based testing with Hypothesis where applicable

----------------------------------------------------------------------
COVERAGE THRESHOLDS
----------------------------------------------------------------------

Recommended targets:
- Overall project:       70%+
- Business logic:        80%+
- Public API / routes:   75%+
- Utilities / helpers:   70%+
- Shared library code:   80%+ (higher due to reuse surface)

Critical files requiring > 80% coverage:
- Authentication / authorisation logic
- Payment or financial calculation code
- Data validation (Pydantic models, validators)
- Security-sensitive functions
- Core business rules
