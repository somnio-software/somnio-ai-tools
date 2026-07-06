# Python Testing Analysis

> Find and classify all test files, identify pytest vs unittest usage, conftest.py fixtures, markers, parametrize patterns, mocking strategy, and Hypothesis property-based tests for Python projects.

---

Goal: Find and classify all test files, identify testing patterns and quality
indicators for single-package or workspace/monorepo Python repositories.

MONOREPO DETECTION:
- First detect repository structure: single package or workspace
- If workspace detected, analyze each member package individually
- Report per-package test counts and patterns

EFFICIENCY REQUIREMENTS:
- Target: <= 8 total tool calls for this entire analysis
- Use find + wc to count test files rather than listing them one by one
- Use grep -r to detect patterns across all test files in one pass
- Read conftest.py files individually (they are high-signal and usually small)
- Do NOT open every test file — sample representative ones where pattern
  confirmation is needed

SINGLE-PACKAGE TESTING ANALYSIS:

1. Test Discovery:
   - Find all test files:
     * tests/**/*.py matching test_*.py or *_test.py (pytest conventions)
     * Inline tests: src/**/*_test.py (co-located style)
   - Detect test runner: pytest (PREFERRED) vs unittest only
     * Presence of pytest in dependencies or [tool.pytest.ini_options] = pytest
     * import unittest only, no pytest imports = unittest-only project
   - Count: total test files, total test functions (grep -c "^def test_")

2. Test Organization:
   - Top-level tests/ or test/ directory (PREFERRED for applications)
   - Co-located: src/<pkg>/<module>_test.py (acceptable for libraries)
   - Mixed: note inconsistency
   - Check for tests/unit/, tests/integration/, tests/e2e/ subdirectory split
   - Check for tests/fixtures/ or tests/factories/ for shared test data

CONFTEST.PY ANALYSIS:

Read every conftest.py in the project (usually 1-3 files):

1. Root conftest.py (tests/conftest.py or conftest.py):
   - List all fixtures defined (@pytest.fixture)
   - Note scope for each: function (default), class, module, session, package
   - Check for autouse=True fixtures (auto-injected — document what they do)
   - Check for fixture factories (fixtures returning callables or classes)
   - Check for database/app setup fixtures:
     * FastAPI: TestClient or httpx.AsyncClient fixture
     * Django: django_db mark or pytest-django db fixture
     * SQLAlchemy: engine, session, transaction rollback fixtures
   - Check for event_loop override (asyncio tests) — note if deprecated pattern
     (anyio is preferred over custom event_loop fixture)

2. Nested conftest.py files (tests/unit/conftest.py, etc.):
   - Note scope narrowing (fixtures only visible to subtree)
   - Check for fixture override patterns

PYTEST MARKERS ANALYSIS:

1. Standard markers in use (grep -r "@pytest.mark."):
   - @pytest.mark.slow: long-running tests excluded from fast runs
   - @pytest.mark.integration: tests requiring external services
   - @pytest.mark.e2e: end-to-end tests
   - @pytest.mark.asyncio or @pytest.mark.anyio: async test functions
   - @pytest.mark.django_db: Django database access
   - @pytest.mark.parametrize: parametrized test cases (see below)
   - @pytest.mark.xfail: expected failures
   - @pytest.mark.skip or @pytest.mark.skipif: skipped tests

2. Custom markers:
   - Check [tool.pytest.ini_options] markers for registered custom markers
   - Unregistered markers: PytestUnknownMarkWarning — flag if --strict-markers
     is not set

3. Marker usage quality:
   - Slow/integration markers allow fast subset: pytest -m "not slow"
   - Absence of any markers: note (makes selective execution impossible)

PARAMETRIZE PATTERN ANALYSIS:

Grep for @pytest.mark.parametrize across all test files:

1. Presence: how many parametrized tests exist
2. Pattern quality:
   - Direct value lists: @pytest.mark.parametrize("x,y", [(1,2),(3,4)])
   - Named cases: pytest.param(..., id="descriptive-name") — PREFERRED
   - Indirect parametrize (fixtures as parameters): note if used
3. Coverage benefit: parametrize is preferred over duplicated test functions
   for same logic with different inputs

MOCKING ANALYSIS:

Grep for mock-related imports and decorators:

1. Standard library unittest.mock:
   - from unittest.mock import MagicMock, patch, AsyncMock
   - @patch decorator usage
   - MagicMock() vs spec=RealClass: spec-less mocks miss interface changes — flag

2. pytest-mock:
   - mocker fixture usage (from conftest injection)
   - mocker.patch(), mocker.MagicMock(), mocker.AsyncMock()
   - PREFERRED over @patch decorator (cleaner scope management)

3. respx / responses / httpretty:
   - HTTP client mocking (requests, httpx)
   - Check if HTTP calls in tests go to real endpoints (missing mock: flag)

4. factory_boy / polyfactory / model_bakery:
   - Test data factories: present / absent
   - factories/ directory or factories.py files

5. Mocking anti-patterns to flag:
   - Mocking the class under test itself
   - Broad mock.patch("builtins.open") without context manager scope
   - No spec= on MagicMock for critical interface objects
   - Patching private implementation details (_method) rather than boundaries

ASYNC TEST ANALYSIS:

1. asyncio.mark: detect @pytest.mark.asyncio
   - asyncio_mode = "auto" in [tool.pytest.ini_options]: all async functions
     are auto-collected (convenient, note it)
2. anyio: detect @pytest.mark.anyio (supports asyncio + trio backends)
3. Check for running async tests with event_loop fixture override:
   - Deprecated in pytest-asyncio >= 0.21 — flag if present

HYPOTHESIS PROPERTY-BASED TESTING:

Grep for "from hypothesis" or "import hypothesis":

1. Presence: hypothesis detected / not detected
2. Strategies in use:
   - st.integers(), st.text(), st.lists(), st.builds()
   - @given decorator usage
   - @settings decorator (max_examples, deadline)
3. Database (Hypothesis database for failure reproduction):
   - Check .hypothesis/ in .gitignore (should be ignored except for
     examples/ subdirectory which is useful to commit)
4. Quality: Hypothesis is especially valuable for:
   - Data parsing / serialization logic
   - Mathematical / numerical functions
   - String processing utilities
   Note if project type would benefit but hypothesis is absent

COVERAGE CONFIGURATION:

1. [tool.coverage.run] in pyproject.toml or .coveragerc:
   - source or source_pkgs: must point to package, not tests/
   - branch = true: branch coverage (REQUIRED for meaningful coverage)
   - omit: check what is excluded

2. [tool.coverage.report]:
   - fail_under: threshold value (CRITICAL — absent means no enforcement)
   - show_missing = true: shows uncovered lines in terminal output
   - skip_covered: note if hiding fully-covered files

3. Coverage artifacts:
   - coverage.xml (for CI coverage upload / diff reporting)
   - htmlcov/ (local HTML report — should be in .gitignore)

TEST QUALITY INDICATORS:

1. Assertion specificity:
   - assert x == expected vs assert x (too vague)
   - pytest assertions preferred over self.assertEqual (better diff output)
   - assert x is None vs assert not x (semantically different — check usage)

2. Test isolation:
   - Database tests use rollback fixtures or isolated test DB
   - No shared mutable state between tests (global vars, class-level lists)
   - teardown (yield fixture cleanup or pytest.fixture with yield) present

3. Test naming quality:
   - test_<unit>_<scenario>_<expected_outcome> pattern
   - Descriptive names vs test_1, test_2: flag generic names

4. Flaky test signals:
   - time.sleep() calls in tests: flag (use mocking or freezegun)
   - datetime.now() / date.today() without freezing: flag
   - Random without seed: flag

OUTPUT FORMAT:

- Repository structure: [Single-package / Workspace]
- Test runner: [pytest / unittest / pytest+unittest / None]
- Total test files: [count] (unit / integration / e2e breakdown if separated)
- Total test functions (approx): [count]
- Test organization: [tests/ top-level / co-located / mixed]
- conftest.py fixtures:
  * Root fixtures: list names, scopes, autouse
  * Nested conftest files: list locations
- Markers: [list custom markers] or NONE REGISTERED
- Parametrize usage: [count of parametrized tests, id quality]
- Mocking library: [pytest-mock / unittest.mock / both / none]
- Mocking anti-patterns found: list or NONE
- Async tests: [asyncio / anyio / none]
- Hypothesis: [Present — strategies used / Absent]
- Coverage branch: [enabled / disabled / not configured]
- Coverage fail_under: [value% / MISSING]
- Test data factories: [factory_boy / polyfactory / model_bakery / none]
- Quality risks: list
- Recommendations
