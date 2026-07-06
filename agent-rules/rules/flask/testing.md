---
description: Testing Flask apps with conftest factory fixtures, test_client and test_cli_runner, TESTING mode, and context pushing.
globs: **/*.py
alwaysApply: false
---

## Best Practices

- Define all fixtures in `tests/conftest.py`. The `app` fixture must call `create_app(...)` with `TESTING=True`, `yield` the app, then perform teardown — this ensures each test gets a fresh application instance with exceptions propagating correctly ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- Derive `client` and `runner` fixtures from the factory-built `app` fixture using `app.test_client()` and `app.test_cli_runner()` respectively; never instantiate them from a module-level global `app` ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- Set `TESTING=True` in the test config so Flask propagates exceptions instead of returning 500 responses; without this flag, test failures may be silently swallowed ([testing] https://flask.palletsprojects.com/en/stable/testing/, [config] https://flask.palletsprojects.com/en/stable/config/).
- Test JSON endpoints via `client.post(..., json=...)` and read `response.json`; use `follow_redirects=True` and inspect `response.history` for redirect-based flows ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- Test session state via a `with client:` block (so `session` is accessible after the response) or with `client.session_transaction()` to pre-populate the session before the request ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- Push `app.app_context()` or `app.test_request_context()` in fixtures or tests that need context-bound objects (e.g., `current_app`, `g`, `db`) outside of a real request cycle ([testing] https://flask.palletsprojects.com/en/stable/testing/, [appcontext] https://flask.palletsprojects.com/en/stable/appcontext/).
- Extract complex view logic into plain helper functions so that logic can be unit-tested without the HTTP layer at all ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- For generic pytest discipline (fixture scope, parametrize, coverage thresholds, test naming), see `python/testing-unit.md`.

## Common Mistakes

- Calling `app.test_request_context()` and expecting `before_request` hooks to have run — `test_request_context()` does NOT dispatch a request; `before_request` is not called. Manually call `app.preprocess_request()` when that behaviour is required ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- Writing tests that exercise Flask or a third-party library rather than your own application code — tests should target behaviour you wrote, not library internals ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- Creating the `Flask` instance at module scope (outside a factory) and importing it directly in tests — this couples tests to a non-configurable app and breaks isolation; always go through `create_app` ([testing] https://flask.palletsprojects.com/en/stable/testing/, [appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/).
- Forgetting `TESTING=True` — unhandled exceptions become opaque 500 responses rather than test failures, making debugging unnecessarily hard ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- Accessing `session` after the `with client:` block has closed — the session context is torn down on block exit; read `session` inside the block ([testing] https://flask.palletsprojects.com/en/stable/testing/).

## Purpose

Flask's test utilities are tightly coupled to the application factory pattern. This file ensures that every test file uses factory-based fixtures, the correct propagation mode (`TESTING=True`), and the proper context-management primitives so that tests are isolated, deterministic, and faithful to the real request lifecycle — without duplicating generic pytest rules that belong in `python/testing-unit.md`.

## Rules

1. The `app` fixture in `tests/conftest.py` must call `create_app(...)` with `TESTING=True`, `yield` the app, and include teardown. ([testing] https://flask.palletsprojects.com/en/stable/testing/)
2. The `client` and `runner` fixtures must be derived from the factory-built `app` fixture via `app.test_client()` and `app.test_cli_runner()`; never created from a module-level global `app`. ([testing] https://flask.palletsprojects.com/en/stable/testing/)
3. JSON endpoint tests must use `client.post(..., json=...)` and read `response.json`; redirect-following tests must use `follow_redirects=True` and inspect `response.history`. ([testing] https://flask.palletsprojects.com/en/stable/testing/)
4. Push `app.app_context()` or `app.test_request_context()` for context-only tests; call `app.preprocess_request()` explicitly when `before_request` hook execution is required — `test_request_context()` alone does not trigger it. ([testing] https://flask.palletsprojects.com/en/stable/testing/)
5. Tests must target application code, not Flask or third-party library internals. ([testing] https://flask.palletsprojects.com/en/stable/testing/)
