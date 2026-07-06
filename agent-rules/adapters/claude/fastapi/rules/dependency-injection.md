### FastAPI dependency injection — Depends, sub-dependency composition, per-request caching, and yield dependencies with correct setup/teardown and re-raise discipline.
> Applies to: `**/*.py`
## Rules

1. Extract every shared request concern (auth, pagination, existence checks, DB sessions) into a `Depends`-injected function; never duplicate this logic in handlers.
2. Manage every resource that requires teardown (DB sessions, HTTP clients, file handles) via a `yield` dependency inside a `try/finally` block — never open such resources inline in a handler.
3. In any `yield` dependency, re-raise every caught exception you are not deliberately converting to an `HTTPException`; swallowing exceptions silently is forbidden.
4. Rely on FastAPI's per-request dependency caching; do not hand-memoize dependency results or store them in module-level state.
5. Use `async def` for trivial non-I/O dependencies; use plain `def` only when the dependency itself performs blocking work.
6. Keep path-parameter names consistent in reusable existence-check dependencies so they are shareable across routes without modification.

## Rules

- Use `Depends` for every shared cross-cutting concern (authentication, pagination parameters, resource existence checks, DB sessions, rate limiting) — do not duplicate this logic in handlers. ([zk](https://github.com/zhanymkanov/fastapi-best-practices), [deps-yield](https://fastapi.tiangolo.com/tutorial/dependencies/dependencies-with-yield/))
- Compose sub-dependencies freely: a dependency can itself declare `Depends` parameters; FastAPI resolves the full graph automatically. ([deps-yield](https://fastapi.tiangolo.com/tutorial/dependencies/dependencies-with-yield/), [zk](https://github.com/zhanymkanov/fastapi-best-practices))
- Rely on FastAPI's per-request dependency caching — within a single request, the same dependency class/function is called only once and its result is shared with all dependants. Never hand-memoize or store the result in a module-level variable. ([zk](https://github.com/zhanymkanov/fastapi-best-practices))
- Use `yield` dependencies (with a `try/finally` block) for any resource that requires deterministic teardown: DB sessions, HTTP clients, file handles. Teardown runs in the reverse order of dependency resolution. ([deps-yield](https://fastapi.tiangolo.com/tutorial/dependencies/dependencies-with-yield/))
- You may `raise HTTPException` (or `raise WebSocketException`) after `yield` in a `yield` dependency to signal an error during teardown; however, any *other* exception caught inside the `yield` dep MUST be re-raised — swallowing it causes silent failure. ([deps-yield](https://fastapi.tiangolo.com/tutorial/dependencies/dependencies-with-yield/))
- Prefer `async def` for trivial non-I/O dependencies (parameter parsing, header extraction) so they run on the event loop without dispatching to the thread pool. Use plain `def` only when the dependency performs blocking work that cannot be awaited. ([zk](https://github.com/zhanymkanov/fastapi-best-practices))
- Keep path-parameter names consistent across reusable existence-check dependencies (e.g. always `user_id: int`) so the same `Depends` can be shared across multiple routes without renaming. ([zk](https://github.com/zhanymkanov/fastapi-best-practices))

- Avoid catching an exception inside a `yield` dependency without re-raising it: the exception is swallowed, teardown code still runs, but the error is never propagated to the caller — producing a silent 200 or an unrelated downstream failure. ([deps-yield](https://fastapi.tiangolo.com/tutorial/dependencies/dependencies-with-yield/))
- Avoid opening DB sessions, HTTP clients, or other resources inline inside a route handler instead of via a `yield` dependency: the resource is never reliably closed on errors, leading to connection leaks. ([deps-yield](https://fastapi.tiangolo.com/tutorial/dependencies/dependencies-with-yield/))
- Avoid manually caching or re-running a dependency that FastAPI already caches per request — this duplicates work and can produce stale or inconsistent state within the same request lifecycle. ([zk](https://github.com/zhanymkanov/fastapi-best-practices))
- Avoid placing business logic or database queries directly in a route handler that could instead be extracted into a `Depends` — this prevents reuse and makes testing harder. ([zk](https://github.com/zhanymkanov/fastapi-best-practices))
