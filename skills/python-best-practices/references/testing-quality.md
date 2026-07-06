# Python Testing Quality Analysis

> Analyze testing code quality, naming conventions, and best practices (assertions, fixtures, mocks, parametrize, integration isolation, coverage) based on somnio-software standards.

---

Goal: Analyze the quality, structure, and best practices of Python
test files — both unit and integration tests.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/python/testing-unit.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/python/testing-unit.md
- local: `agent-rules/rules/python/testing-integration.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/python/testing-integration.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **Test Discovery and Naming**:
    *   Verify test files follow `test_*.py` or `*_test.py` naming; flag any
        test files with non-standard names.
    *   Check that test functions are named `test_<unit>_<scenario>_<expected>`
        (three-part); flag vague names like `test_works` or `test_ok`.
    *   Verify the `tests/` directory mirrors the `src/` package structure.

2.  **Assertion Quality**:
    *   Confirm all assertions use plain `assert` statements (never
        `assertEqual`, `assertTrue`, or other `unittest.TestCase` methods).
    *   Flag every `with pytest.raises(ExcType):` block that omits the `match`
        argument.
    *   Flag tests with no assertions at all (pass-through tests).

3.  **Fixtures, Scope, and `conftest.py`**:
    *   Verify shared fixtures are defined in `conftest.py`, not in individual
        test modules.
    *   Check that fixtures use the narrowest scope (`function` by default);
        flag `scope="session"` or `scope="module"` on fixtures that mutate
        state.
    *   Confirm `yield`-based teardown is used in fixtures that create or
        modify external resources.

4.  **Parametrize and `ids`**:
    *   Verify every `@pytest.mark.parametrize` call includes an `ids=[...]`
        argument with human-readable names.
    *   Flag parametrized tests where `ids` is absent or contains only
        auto-generated numeric suffixes.

5.  **Mocking: `mocker`, `autospec`, patch-where-used**:
    *   Verify `pytest-mock`'s `mocker` fixture is used instead of bare
        `unittest.mock.patch` decorators or context managers.
    *   Flag any `mocker.patch(...)` call that does not pass `autospec=True`.
    *   Verify mocks patch the name at the import site in the module under test
        (e.g. `myapp.service.requests.get`), not the definition site.

6.  **Integration Test Teardown and Isolation**:
    *   Check that every DB-touching fixture uses `yield`-based teardown
        (rollback or delete) guaranteeing cleanup even on test failure.
    *   Verify relational DB tests are wrapped in a transaction rolled back
        after the test body; flag manual `DELETE` cleanup that can be skipped.
    *   Confirm test data uses generated unique values (`uuid.uuid4()`,
        factories, time-based suffixes); flag hard-coded shared IDs, emails,
        or usernames.
    *   Verify integration fixtures are placed in a dedicated `conftest.py`
        co-located with the integration test directory (not mixed into the unit
        `conftest.py`).

7.  **Registered Markers**:
    *   Confirm all custom markers (e.g. `@pytest.mark.integration`,
        `@pytest.mark.slow`) are declared in
        `[tool.pytest.ini_options] markers` in `pyproject.toml`.
    *   Verify `--strict-markers` and `--strict-config` are present in
        `addopts`.
    *   Flag any unregistered markers found in test files.

OUTPUT FORMAT:
*   **Overview**: Total tests analyzed, quality score (1-10).
*   **Violations**: List specific file paths and lines violating the above
    rules.
    *   Format: `` `path/to/file.py:XX` — [Issue] ``
*   **Compliance**: Highlight good examples found in the codebase.
*   **Recommendations**: Specific refactoring suggestions for violations.
