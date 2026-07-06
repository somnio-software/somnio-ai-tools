---
description: FastAPI data, config, and testing — session-per-request yield dependency, table-model vs API-schema separation, pydantic-settings via lru_cache dependency, and TestClient/AsyncClient with dependency_overrides.
globs: **/*.py
alwaysApply: false
---

## Best Practices

- Provide the database session as a `yield` dependency injected through an annotated type alias (`SessionDep = Annotated[Session, Depends(get_session)]`); never hold a global session across requests. ([sql])
- Keep SQLModel/SQLAlchemy table models strictly separate from Pydantic API schemas; never return an ORM row directly from a route. ([sql], [response-model])
- Implement partial updates by declaring all fields optional in a `*Update` model and applying `model_dump(exclude_unset=True)` before writing to the DB. ([sql])
- Centralise application configuration in a `pydantic-settings` `BaseSettings` subclass; expose it exclusively through a `@lru_cache` dependency (`get_settings()`) so the environment is read once and overrideable in tests. ([settings], [zk])
- Prefer `os.environ` / `.env` files managed by `pydantic-settings`; never scatter `os.environ.get(...)` calls across modules. ([settings])
- Write sync tests with `TestClient` and plain `def` test functions; `TestClient` manages its own event loop and does not require async test support. ([testing])
- Use httpx `AsyncClient` with `ASGITransport(app=app)` inside `@pytest.mark.anyio` (or equivalent) tests only when you need to exercise async code in the same event loop — not as a default. ([async-tests], [zk])
- Swap real dependencies for test doubles via `app.dependency_overrides[real_dep] = fake_dep`; always reset the overrides dict after each test (e.g. in a fixture teardown or `finally` block). ([test-deps], [settings])
- For async DB: only reach for an async session + `AsyncClient` when the entire driver chain is awaitable (e.g. `asyncpg`/`aiosqlite`); mixing sync and async drivers silently deadlocks. ([async], [sql])

**CONTESTED — async vs sync DB.** The official FastAPI docs demonstrate a sync `Session` with `def` handlers running in a threadpool as the primary example [sql]. An async `AsyncSession` with `async def` handlers is valid but requires the full driver chain to be async [async]. **Default chosen: sync session + `def` handlers** (threadpool). Use async only when the whole driver stack is awaitable and the performance requirement justifies the added complexity.

## Common Mistakes

- Opening a DB session inline inside a handler instead of injecting it as a `yield` dependency — the session is never properly closed on exceptions. ([sql])
- Returning ORM model instances directly from routes — leaks internal columns, `hashed_password`, and server-controlled fields to callers. ([sql], [response-model])
- Reusing one `*Create` schema for updates without making all fields optional — forces clients to resend unchanged values and breaks partial-patch semantics. ([sql])
- Reading config with bare `os.environ.get(...)` calls spread across the codebase — impossible to override consistently in tests. ([settings])
- Writing `async def` tests that call the sync `TestClient` — `TestClient` internally runs its own event loop and raises a `RuntimeError` when called from inside a running loop. ([async-tests])
- Forgetting to reset `dependency_overrides` after a test — overrides leak into subsequent tests and cause hard-to-diagnose failures. ([test-deps])
- Hitting real infrastructure (network, production DB) in unit tests instead of overriding dependencies — tests become slow, flaky, and environment-dependent. ([test-deps])

## Purpose

Enforces FastAPI-specific patterns for database session lifecycle, schema/model separation, config management, and test setup. These rules prevent session leaks, data exposure through ORM passthrough, config sprawl, and broken test isolation. For language-level testing conventions (assertion style, coverage thresholds, pytest fixture design) see `python/testing-unit.md`.

## Rules

1. Session-per-request only: provide the DB session exclusively through a `yield` dependency; never hold a module-level or global session. ([sql])
2. Keep table models (SQLModel `table=True` / SQLAlchemy `Base`) separate from API schemas; map to a `*Public`/`*Response` schema before returning. ([sql])
3. Partial updates must use an all-optional `*Update` model and `model_dump(exclude_unset=True)` — never overwrite fields the client did not send. ([sql])
4. Centralise config in `pydantic-settings` `BaseSettings`; expose it only through a `@lru_cache` dependency; no scattered `os.environ` calls. ([settings], [zk])
5. **CONTESTED — async vs sync DB. Default: sync session + `def` handlers** (threadpool, per official docs); use async session only when the full driver chain is awaitable. ([async], [sql])
6. Sync-route tests: use `TestClient` with plain `def` test functions. Async-route tests that must share the event loop: use `AsyncClient` + `ASGITransport` inside an async-aware test decorator. ([testing], [async-tests])
7. Override real dependencies with `app.dependency_overrides` in tests; always reset the overrides after each test. ([test-deps])

---

**Citation sources:**
- [sql] https://fastapi.tiangolo.com/tutorial/sql-databases/
- [response-model] https://fastapi.tiangolo.com/tutorial/response-model/
- [settings] https://fastapi.tiangolo.com/advanced/settings/
- [testing] https://fastapi.tiangolo.com/tutorial/testing/
- [async-tests] https://fastapi.tiangolo.com/advanced/async-tests/
- [test-deps] https://fastapi.tiangolo.com/advanced/testing-dependencies/
- [async] https://fastapi.tiangolo.com/async/
- [zk] https://github.com/zhanymkanov/fastapi-best-practices
