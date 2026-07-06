### pytest unit-testing conventions — plain assert, test_*.py discovery, fixture scoping, parametrize, mocker/autospec, Hypothesis. Applies to all Python test files.
> Applies to: `**/*.py`
## Rules

1. Use plain `assert` statements; never use `unittest.TestCase` assertion methods inside pytest tests. (https://docs.pytest.org/en/stable/how-to/assert.html)
2. Name test files `test_*.py` or `*_test.py`; mirror the source package structure under `tests/`. (https://docs.pytest.org/en/stable/explanation/goodpractices.html)
3. Name every test function `test_<unit>_<scenario>_<expected>`. (https://docs.pytest.org/en/stable/explanation/goodpractices.html)
4. Use `@pytest.fixture` instead of `setUp`/`tearDown`; place shared fixtures in `conftest.py`. (https://docs.pytest.org/en/stable/how-to/fixtures.html)
5. Declare fixtures at the narrowest scope that satisfies the test; default is `scope="function"`; only widen to `"module"` or `"session"` for provably read-only resources. (https://docs.pytest.org/en/stable/how-to/fixtures.html)
6. Always pass `ids=[...]` to `@pytest.mark.parametrize` so test node IDs are human-readable. (https://docs.pytest.org/en/stable/how-to/parametrize.html)
7. Assert expected exceptions with `pytest.raises(ExcType, match=r"...")`, never without `match`. (https://docs.pytest.org/en/stable/how-to/assert.html)
8. Use `mocker.patch(..., autospec=True)` from `pytest-mock` for all mocks; never leave `autospec` off. (https://pytest-mock.readthedocs.io/en/latest/usage.html · https://docs.python.org/3/library/unittest.mock.html)
9. Patch at the import site used by the module under test, not at the definition site. (https://docs.python.org/3/library/unittest.mock-examples.html)
10. Apply `@hypothesis.given` to pure functions with well-defined contracts; do not use Hypothesis for stateful or I/O-heavy tests. (https://hypothesis.readthedocs.io/en/latest/tutorial/introduction.html)

## Rules

- **Use pytest plain `assert` with rewriting** — pytest rewrites `assert` expressions at collection time to produce detailed introspection output on failure; never use `assertEqual`/`assertTrue` or `unittest.TestCase` assertions in pytest tests. Source: https://docs.pytest.org/en/stable/how-to/assert.html

- **Follow `test_*.py` / `*_test.py` file naming** — pytest discovers tests in files matching `test_*.py` or `*_test.py` by default; keep test files alongside the source tree or under a top-level `tests/` directory with the same sub-package structure. Source: https://docs.pytest.org/en/stable/explanation/goodpractices.html

- **Name tests `test_<unit>_<scenario>_<expected>`** — a three-part name (`test_parse_empty_string_returns_none`) makes the intent explicit without reading the body; it also serves as executable documentation. Source: https://docs.pytest.org/en/stable/explanation/goodpractices.html

- **Use fixtures over `setup`/`teardown`** — pytest fixtures are composable, type-annotated, and respect scope; replace `setUp`/`tearDown` class methods and module-level globals with `@pytest.fixture` functions. Shared fixtures belong in `conftest.py`, discovered automatically by pytest without explicit imports. Source: https://docs.pytest.org/en/stable/how-to/fixtures.html · https://docs.pytest.org/en/stable/reference/fixtures.html

- **Use the narrowest fixture scope that satisfies the test** — declare `scope="function"` (the default) unless the fixture is provably read-only, in which case `scope="module"` or `scope="session"` is acceptable; over-scoped fixtures cause hidden state leakage between tests. Source: https://docs.pytest.org/en/stable/how-to/fixtures.html

- **Parametrize with explicit `ids`** — `@pytest.mark.parametrize("x,y", [...], ids=[...])` produces human-readable node IDs; without `ids`, pytest auto-generates numeric suffixes that obscure what scenario failed. Source: https://docs.pytest.org/en/stable/how-to/parametrize.html

- **Assert exceptions with `pytest.raises(ExcType, match=...)`** — the `match` argument compiles a regex against the string representation of the exception value, confirming both type and message; omitting `match` tests only the exception type, leaving the message unverified. Source: https://docs.pytest.org/en/stable/how-to/assert.html

- **Prefer `pytest-mock`'s `mocker` fixture over bare `unittest.mock.patch`** — `mocker.patch` automatically undoes patches after the test without requiring a context manager or manual `addCleanup`; use `autospec=True` on every mock to catch call-signature mismatches at test time. Source: https://pytest-mock.readthedocs.io/en/latest/usage.html · https://docs.python.org/3/library/unittest.mock.html

- **Patch at the import site, not the definition site** — mock the name as it is looked up in the module under test (e.g. `myapp.service.requests.get`), not where `requests.get` is defined; patching the wrong namespace leaves the real code unchanged. Source: https://docs.python.org/3/library/unittest.mock-examples.html · https://realpython.com/python-mock-library/

- **Use Hypothesis for property-based / invariant testing** — `@given(st.text())` generates hundreds of examples automatically and shrinks counter-examples to minimal reproducible inputs; apply it to pure functions with well-defined contracts (parsers, encoders, data transformations). Source: https://hypothesis.readthedocs.io/en/latest/tutorial/introduction.html

- Avoid using `assert x == True` instead of `assert x` — defeats pytest's rewriting and produces weaker failure messages.
- Avoid defining fixtures in test modules instead of `conftest.py` — fixtures defined outside `conftest.py` cannot be shared across files without explicit imports.
- Avoid using `scope="session"` on fixtures that mutate state — causes test-order dependency; a test that passes alone may fail in CI due to leftover state.
- Avoid calling `@pytest.mark.parametrize` without `ids` — node IDs like `test_add[1-2-3]` instead of `test_add[positive_integers]` make failure reports hard to read.
- Avoid writing `with pytest.raises(ValueError):` without `match` — only confirms the type; a completely different error message goes undetected.
- Avoid using `mocker.patch("requests.get")` when the SUT imports `from requests import get` — the mock patches the wrong binding and the real function is called.
- Avoid creating mocks without `autospec=True` — allows calling the mock with the wrong arguments; the bug is invisible until production.
- Avoid relying on Hypothesis for integration scenarios — `@given` is for pure-function invariants; stateful/DB tests should use pytest fixtures with controlled data, not property strategies.
- Avoid over-asserting implementation details (`assert mock.call_count == 3`) instead of observable behaviour — brittle tests that break on valid refactors.
