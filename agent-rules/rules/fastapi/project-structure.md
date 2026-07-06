---
description: FastAPI project structure — domain-package layout, APIRouter modularization, and thin route handlers that delegate to a service layer. Layers on the python stack for language-level structure.
globs: **/*.py
alwaysApply: false
---

## Best Practices

- Create one `APIRouter` per resource or domain module and assemble all routers in `main.py` via `app.include_router(...)` — keeps the application object slim and the routing tree explicit. [bigger-apps](https://fastapi.tiangolo.com/tutorial/bigger-applications/)
- Declare `prefix`, `tags`, `dependencies`, and `responses` once on the `APIRouter` object, never per-route decorator — a single change propagates across the whole domain. [bigger-apps](https://fastapi.tiangolo.com/tutorial/bigger-applications/)
- Organize the codebase by domain/feature package; each package owns `router.py`, `schemas.py`, `models.py`, `service.py`, `dependencies.py`, and `exceptions.py`. A layout-by-type global namespace (`routers/`, `models/`, `schemas/`) is only acceptable for tiny proof-of-concept apps. [zk](https://github.com/zhanymkanov/fastapi-best-practices)
- Keep business logic out of route handlers — handlers validate input, delegate to `service.py`, and return a response. No SQL queries, third-party calls, or domain logic in the handler body. [zk](https://github.com/zhanymkanov/fastapi-best-practices)
- Nest routers and mount them under versioned prefixes (e.g., `/api/v1`) so version migration is a single `include_router` change. [bigger-apps](https://fastapi.tiangolo.com/tutorial/bigger-applications/)
- For language-level concerns (absolute imports, `__init__`/`__all__` exports, layered/clean architecture, packaging via `pyproject.toml`) see `python/module-structure.md`.

## Common Mistakes

- Registering all routes directly on the global `app` object — eliminates modularization and makes the app object a single point of change. [bigger-apps](https://fastapi.tiangolo.com/tutorial/bigger-applications/)
- Repeating `tags=`, `prefix=`, or shared `dependencies=` on every `@router.get(...)` / `@router.post(...)` decorator instead of setting them once on the router. [bigger-apps](https://fastapi.tiangolo.com/tutorial/bigger-applications/)
- Layout-by-type on a non-trivial application (a flat `routers/` dir full of mixed concerns) — causes cross-domain coupling and makes feature-level isolation impossible. [zk](https://github.com/zhanymkanov/fastapi-best-practices)
- Fat handlers containing SQL queries, complex business rules, or third-party calls inline — prevents unit testing the logic without spinning up a full HTTP server. [zk](https://github.com/zhanymkanov/fastapi-best-practices)

## Purpose

Standardizes how FastAPI applications are broken into domain packages with isolated routers and thin handlers. Ensures the `app` object stays clean (only router registration, middleware, and lifespan events) and that service-layer logic is independently testable. This file covers only FastAPI-level structural patterns; language-level packaging, import style, and architecture principles are governed by `python/module-structure.md`.

## Rules

1. Create one `APIRouter` per domain/resource; register every router in `main.py` with `app.include_router(...)`. Never mount routes directly on `app` outside of `main.py`. [bigger-apps](https://fastapi.tiangolo.com/tutorial/bigger-applications/)
2. Set `prefix`, `tags`, `dependencies`, and `responses` on the `APIRouter` constructor, not on individual route decorators. [bigger-apps](https://fastapi.tiangolo.com/tutorial/bigger-applications/)
3. **CONTESTED — layout strategy.** Domain-driven packages (each feature owns `router.py` / `schemas.py` / `models.py` / `service.py` / `dependencies.py` / `exceptions.py`) is the **default** for any non-trivial app. Layout-by-type (`routers/`, `schemas/`, `models/` at the top level) is acceptable only for apps with three or fewer domains. Divergence from the default must be justified in a comment. [zk](https://github.com/zhanymkanov/fastapi-best-practices) vs [bigger-apps](https://fastapi.tiangolo.com/tutorial/bigger-applications/)
4. Route handlers must delegate all non-trivial logic to `service.py`. A handler body should be: validate/extract inputs → call service function → return the result. No inline queries, business rules, or external calls. [zk](https://github.com/zhanymkanov/fastapi-best-practices)
5. Nest routers and version the API via route prefixes (e.g., `app.include_router(users_router, prefix="/api/v1")`). Version promotion requires no handler changes. [bigger-apps](https://fastapi.tiangolo.com/tutorial/bigger-applications/)
