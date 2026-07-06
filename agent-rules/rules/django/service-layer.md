---
description: Django service layer — HackSoft services/selectors pattern, business-logic placement, model clean()/full_clean(), per-app services.py/selectors.py/apis.py separation, and Celery task queuing via transaction.on_commit.
globs: **/*.py
alwaysApply: false
---

## Best Practices

- **Business logic lives in services (write) and selectors (read), never in views, serializers, `save()` overrides, managers, or signals.** Views and Celery tasks are thin routers that delegate immediately to a service function. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
- **CONTESTED — fat models vs. service layer.** Django's own docs encourage putting logic on the model ("fat models"). HackSoft and many large-project practitioners instead advocate services + selectors to keep models as data containers and avoid entangled side effects. **Default chosen: services + selectors for non-trivial apps; model methods only for simple derived/computed values.** ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
- **Always call `full_clean()` (which calls `clean()`, `clean_fields()`, and `validate_unique()`) in the service before `save()`.** Django's ORM does not call `full_clean()` automatically; skipping it lets constraint violations through at the DB level with no application-level detail. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
- **Selectors own all read-path logic: filtering, ordering, annotation, and pagination.** Views pass query parameters to selectors and receive querysets or plain values back; they never build filter expressions themselves. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
- **Queue Celery tasks via `transaction.on_commit(lambda: task.delay(...))`, never directly inside the service body.** Calling `.delay()` before the transaction commits risks the task running before the data it needs is visible. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
- **Define a per-app custom application exception hierarchy with a consistent shape.** Raise domain exceptions (e.g., `OrderAlreadyCancelledError`) inside services; translate them to HTTP responses only at the view/API boundary. See `python/error-handling.md` for language-level exception design; this file covers only the Django-specific placement rules.
- **Naming conventions follow the HackSoft style:** service functions as `<entity>_<action>` (e.g., `order_cancel`), selector functions as `<entity>_list`/`<entity>_get` (e.g., `order_list`, `order_get_by_id`), API class names as `<Entity><Action>Api` (e.g., `OrderCancelApi`), test modules as `test_<thing>.py`. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
- **Separate files per concern within each app:** `services.py` for write operations, `selectors.py` for read operations, `apis.py` (or `views.py`) for the HTTP boundary. For apps with many entities, split further into `services/<entity>.py`. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))

## Common Mistakes

- Putting business logic in views or serializers — the classic "fat view" anti-pattern that makes logic untestable in isolation and entangles HTTP concerns with domain rules.
- Overriding `Model.save()` to embed side effects (sending emails, queuing tasks, computing derived fields) — triggers silently on any `save()` call, including migrations and bulk operations.
- Calling `model.save()` without first calling `model.full_clean()` — skips field validation, `clean()` constraints, and `validate_unique()`, allowing invalid data to reach the database.
- Calling `celery_task.delay(...)` directly inside a service function that runs inside an atomic transaction — the task may execute before the transaction commits, reading stale or missing rows.
- Using Django signals for cross-app orchestration — creates invisible coupling and makes execution order hard to reason about; prefer explicit service calls.
- A single god `models.py` that accumulates manager methods, class methods, and helper functions as a substitute for a service layer.
- Inconsistent exception shapes — some services raise `ValidationError`, others raise `ValueError`, others return `None` — forces callers to handle multiple error protocols.

## Purpose

Enforces the HackSoft services/selectors architectural pattern for Django applications. Keeps business logic centralized, independently testable, and decoupled from the HTTP and ORM layers. Governs business-logic placement, model validation discipline, task-queuing safety, exception hierarchy placement, and the per-app file split between `services.py`, `selectors.py`, and `apis.py`.

Does not restate language-level exception design (see `python/error-handling.md`), generic pytest/coverage discipline, or ORM query optimization (see `django/models-orm.md`).

## Rules

1. Business logic belongs in services (writes) and selectors (reads); views, serializers, Celery tasks, `Model.save()` overrides, managers, and signals must not contain domain logic. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
2. **CONTESTED — fat models vs. service layer. Default: services + selectors** for non-trivial apps; model instance methods are acceptable only for simple derived values with no side effects. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
3. Views and Celery task functions are thin routers: parse input → call one service or selector → return the result. No filtering, no DB access, no business decisions inside the view or task body. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
4. Every service that saves a model instance must call `instance.full_clean()` before `instance.save()`; never skip validation at the service boundary. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
5. Selectors own all read-path concerns: filtering, ordering, annotation, and pagination. Views pass parameters to selectors and must not build filter expressions directly. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
6. Queue Celery tasks inside `transaction.on_commit(lambda: task.delay(...))`, never with a bare `.delay()` call inside a service that runs within an atomic block. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
7. Define a per-app (or project-level shared) custom exception hierarchy with a consistent shape; raise domain exceptions in services and translate to HTTP status codes only at the view/API boundary. For language-level exception class design, reference `python/error-handling.md`. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
8. Follow HackSoft naming: service functions as `<entity>_<action>`, selector functions as `<entity>_list`/`<entity>_get_*`, API classes as `<Entity><Action>Api`, test files as `test_<thing>.py`. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
9. Each app is split into `services.py` (writes), `selectors.py` (reads), and `apis.py`/`views.py` (HTTP boundary); for large apps, further split into `services/<entity>.py` per entity. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
