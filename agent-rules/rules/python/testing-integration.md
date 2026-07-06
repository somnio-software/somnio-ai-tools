---
description: Python integration testing — DB/fixture teardown & isolation; unique test data; registered markers (--strict-markers); branch coverage (--cov-branch) + fail_under gate; coverage != quality (flag untested branches/error paths).
globs: **/*.py
alwaysApply: false
---

## Best Practices

- **DB/fixture teardown and isolation.** Each integration test must leave the database (or any external resource) in the same state it found it. Use pytest fixtures with the narrowest appropriate scope (`function` by default, `session` only for truly read-only shared state) and yield-based teardown (`yield` + cleanup) so rollback or deletion is guaranteed even on failure. Source: https://docs.pytest.org/en/stable/how-to/fixtures.html

- **Transaction-scoped rollback for DB tests.** Wrap each test in a transaction and roll it back after the test body; never rely on manual `DELETE` statements that can be skipped on error. This is the canonical isolation strategy for relational DBs. Source: https://docs.pytest.org/en/stable/how-to/fixtures.html

- **Unique, generated test data.** Never hard-code IDs, usernames, or email addresses as bare string literals shared across tests. Use factories (e.g. factory_boy), `uuid.uuid4()`, or time-based suffixes to guarantee uniqueness and prevent inter-test coupling. Source: https://docs.pytest.org/en/stable/explanation/goodpractices.html

- **Register all custom markers; run with `--strict-markers`.** Every `@pytest.mark.<name>` must be declared in `[tool.pytest.ini_options] markers` in `pyproject.toml`. Add `--strict-markers` (and `--strict-config`) to the `addopts` line so an unregistered marker raises an error rather than silently passing. Source: https://docs.pytest.org/en/stable/how-to/mark.html

- **Enable branch coverage with `--cov-branch`.** Run `pytest --cov=<src_pkg> --cov-branch` (never `coverage run -m pytest`) to capture decision-branch data. Report as `coverage.xml` for CI consumption. Source: https://coverage.readthedocs.io/en/latest/branch.html · https://pytest-cov.readthedocs.io/en/latest/config.html

- **Enforce a `fail_under` gate in CI.** Set `[tool.coverage.report] fail_under = <N>` in `pyproject.toml` (project default: 80; raise per-project) so coverage regressions break the build automatically. Source: https://coverage.readthedocs.io/en/latest/cmd.html

- **Coverage percentage is not a quality proxy.** A line or branch executed by a test that never asserts correctness is covered but untested in any meaningful sense. Prefer targeted assertions over coverage-padding tests. Explicitly flag uncovered branches and error paths (e.g. exception handlers, early-return guards, `else` clauses on loops) rather than silencing them with `# pragma: no cover` without justification. Source: https://coverage.readthedocs.io/en/latest/faq.html · https://hynek.me/articles/ditch-codecov-python/ · https://learn.scientific-python.org/development/guides/coverage/

- **Keep integration and unit markers separate.** Mark slow/external-dependency tests with `@pytest.mark.integration` (or `@pytest.mark.slow`) and run them separately in CI from the fast unit suite. Source: https://docs.pytest.org/en/stable/how-to/mark.html

- **Use `conftest.py` for shared integration fixtures.** Place DB connection fixtures, session factories, and other integration-scope setup in the nearest `conftest.py` to the integration test directory, not in the unit `conftest.py`. Source: https://docs.pytest.org/en/stable/reference/fixtures.html

- **Exclude only genuinely untestable lines from coverage.** Use `# pragma: no cover` sparingly and only for platform-specific branches, `if TYPE_CHECKING:` blocks, and `__main__` guards. Document the reason inline. Source: https://coverage.readthedocs.io/en/latest/excluding.html

## Common Mistakes

- Sharing hard-coded test records (fixed IDs, emails, usernames) across tests — causes order-dependent failures and flaky CI.
- Using function-scope DB fixtures that commit data without rollback, leaving pollution for subsequent tests.
- Adding `@pytest.mark.integration` (or any custom marker) without declaring it in `pyproject.toml markers` — silently ignored unless `--strict-markers` is active.
- Running `coverage run -m pytest` instead of `pytest --cov` — inconsistent configuration and misses `pytest-cov` integration.
- Setting a `fail_under` gate of 0 or omitting it entirely — coverage regressions pass undetected.
- Writing tests whose only effect is hitting lines (no assertions) to bump the coverage number — produces false confidence.
- Applying `# pragma: no cover` to an entire error-handling block without comment — hides real gaps.
- Using `session`-scoped fixtures for data that mutates between tests — leads to hidden coupling.
- Forgetting `--strict-config` alongside `--strict-markers` in `addopts` — allows invalid ini keys to pass silently.

## Purpose

Integration tests verify that components work correctly together across real or realistic boundaries (databases, message queues, HTTP clients, file systems). This file governs how those tests are structured to be **isolated** (no shared mutable state between runs), **deterministic** (unique data, no order dependency), **observable** (registered markers, structured CI output), and **honest** (branch coverage with a hard gate, combined with critical review of what coverage actually means). These rules are framework-agnostic and complement `testing-unit.md`, which governs isolated unit tests with mocks.

## Rules

1. Every DB-touching fixture must use `yield`-based teardown (rollback or delete) so cleanup runs even when the test fails. Source: https://docs.pytest.org/en/stable/how-to/fixtures.html
2. Wrap relational DB tests in a transaction that is rolled back after the test body; never rely on manual cleanup that can be skipped on error. Source: https://docs.pytest.org/en/stable/how-to/fixtures.html
3. Never hard-code shared identifiers (IDs, emails, usernames) as bare string literals in tests; generate unique values per test run using factories, `uuid.uuid4()`, or time-based suffixes. Source: https://docs.pytest.org/en/stable/explanation/goodpractices.html
4. Declare every custom marker in `[tool.pytest.ini_options] markers` in `pyproject.toml` and add `--strict-markers --strict-config` to `addopts`. Source: https://docs.pytest.org/en/stable/how-to/mark.html
5. Mark integration/slow tests with a registered marker (e.g. `@pytest.mark.integration`) and run them in a dedicated CI step, separate from the fast unit suite. Source: https://docs.pytest.org/en/stable/how-to/mark.html
6. Run coverage as `pytest --cov=<src_pkg> --cov-branch --cov-report=xml` — never `coverage run -m pytest`. Source: https://pytest-cov.readthedocs.io/en/latest/config.html · https://coverage.readthedocs.io/en/latest/branch.html
7. Set `[tool.coverage.report] fail_under = <N>` (minimum 80 for new projects) in `pyproject.toml` so coverage regressions break CI. Source: https://coverage.readthedocs.io/en/latest/cmd.html
8. Do not treat coverage percentage as a quality signal in isolation; explicitly review uncovered branches (exception handlers, early-return guards, loop `else` clauses) and add assertions or mark them `# pragma: no cover` with a documented reason. Source: https://coverage.readthedocs.io/en/latest/faq.html · https://hynek.me/articles/ditch-codecov-python/ · https://learn.scientific-python.org/development/guides/coverage/
9. Place integration-scope fixtures (DB sessions, connection pools) in a dedicated `conftest.py` co-located with the integration test directory; do not mix them into the unit `conftest.py`. Source: https://docs.pytest.org/en/stable/reference/fixtures.html
10. Use `# pragma: no cover` only for genuinely untestable lines (`if TYPE_CHECKING:`, `__main__` guards, platform branches); always add an inline comment explaining why. Source: https://coverage.readthedocs.io/en/latest/excluding.html
