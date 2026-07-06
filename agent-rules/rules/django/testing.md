---
description: Django-specific testing with pytest-django — db marking, transaction isolation, factory_boy factories, signal muting, and service-layer test focus. Applies to all test files matching the pytest discovery pattern.
globs: **/test_*.py
alwaysApply: false
---

# Django Testing Standards

Framework-specific guidance for testing Django applications with pytest-django and factory_boy. For generic pytest patterns, fixture design, coverage discipline, and unit-vs-integration strategy, see `python/testing-unit.md` and `python/testing-integration.md`.

## Best Practices

- **Mark `@pytest.mark.django_db` only where DB access is required.** Tests that do not touch the database must not carry the marker — they run faster and fail loudly if they accidentally hit the DB. ([pytest-django database docs](https://pytest-django.readthedocs.io/en/latest/database.html))
- **Default to rollback isolation; use `transaction=True` only when you must observe commit behaviour.** The default `django_db` marker wraps each test in a transaction that is rolled back, giving fast isolation at near-zero cost. Reserve `@pytest.mark.django_db(transaction=True)` for code paths that rely on `transaction.on_commit(...)` or explicit `COMMIT`s. ([pytest-django database docs](https://pytest-django.readthedocs.io/en/latest/database.html))
- **Declare multi-database tests explicitly with `databases=[...]`.** When a test touches a non-default alias, add `@pytest.mark.django_db(databases=["default", "replica"])` so pytest-django grants access and documents intent. ([pytest-django database docs](https://pytest-django.readthedocs.io/en/latest/database.html))
- **Seed persistent test data only through `django_db_blocker.unblock()` in session-scoped fixtures, not inside individual tests.** Re-creating the same rows per test is slow; `--reuse-db`/`--create-db` flags let pytest-django reuse the schema across runs. ([pytest-django database docs](https://pytest-django.readthedocs.io/en/latest/database.html))
- **Use `DjangoModelFactory` (factory_boy) instead of hard-coded fixtures or manual `Model.objects.create()` calls.** Factories keep test data minimal, composable, and refactoring-safe. ([factory_boy ORM docs](https://factoryboy.readthedocs.io/en/stable/orms.html))
- **Use `SubFactory` for related objects, `Sequence` for unique fields, and `post_generation` for M2M relations.** This avoids duplicate-key errors and keeps factories self-contained. ([factory_boy ORM docs](https://factoryboy.readthedocs.io/en/stable/orms.html))
- **Set `django_get_or_create` in `Meta` when idempotency matters.** For lookup-table-style models this prevents duplicate rows when the same factory is called multiple times in a session. ([factory_boy ORM docs](https://factoryboy.readthedocs.io/en/stable/orms.html))
- **Mute signals during factory setup.** Wrap factory calls with `factory.django.mute_signals(post_save, ...)` or use `@mute_signals` on the factory class to prevent side-effects (e.g. Celery tasks, notifications) from firing on test object creation. ([factory_boy ORM docs](https://factoryboy.readthedocs.io/en/stable/orms.html))
- **Prefer `factory.build()` for pure unit tests; use `factory.create()` only when DB persistence is needed.** `build()` skips the DB round-trip entirely, keeping unit tests fast. ([factory_boy ORM docs](https://factoryboy.readthedocs.io/en/stable/orms.html))
- **Centre test coverage on the service layer.** Services and selectors carry the business logic; test them thoroughly. Mock external I/O (HTTP calls, S3, email) and assert that `transaction.on_commit(...)` queues Celery tasks rather than testing Celery execution. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
- **Test model logic only when models carry non-trivial derived behaviour.** Trivial `@property` accessors and `__str__` do not need dedicated tests. Prefer exercising model methods via service tests. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))
- **Mock selector calls from service tests and mock service calls from view/API tests.** This enforces the service-layer boundary and keeps each test layer fast and focused. ([HackSoft Django-Styleguide](https://github.com/HackSoftware/Django-Styleguide))

## Common Mistakes

- **Unnecessary `transaction=True`** — applied by default on every test, slowing the suite and masking isolation issues. Use only for commit-dependent code paths.
- **Over-marking `django_db`** — test classes or modules marked at the class level when only one or two methods need DB access; the rest should run without it.
- **Hand-built fixtures or `Model.objects.create()` scattered in tests** — duplicates setup logic, breaks on model changes, and cannot compose related objects cleanly.
- **Non-unique factory fields without `Sequence`** — causes `IntegrityError` on `UNIQUE` columns (e.g. `email`, `username`) when a factory is called more than once per session.
- **Signals firing during factory object creation** — `post_save` handlers that queue tasks or send emails pollute test output and slow the suite; mute them at the factory level.
- **Testing trivial getters/setters in isolation** — inflates test count without adding safety; rely on higher-level service tests to exercise these paths.
- **Asserting Celery task execution instead of `on_commit` queueing** — couples tests to task internals; assert that the correct task was enqueued on commit, not its result.

## Purpose

These rules ensure that Django test suites are:

- **Fast** — only tests that truly need the DB carry `django_db`; factories skip DB writes where possible; rollback isolation avoids costly teardown.
- **Reliable** — unique fields use `Sequence`; signals are muted at factory level; each test is DB-isolated by default.
- **Aligned with the service-layer architecture** — tests mirror the `services.py`/`selectors.py` separation and mock across layer boundaries, making refactors safe and test intent clear.
- **Maintainable** — factories centralise object creation; `django_db_blocker` controls schema reuse; explicit `databases=[...]` declarations document multi-DB intent.

Generic pytest/fixture/coverage discipline is delegated to `python/testing-unit.md` and `python/testing-integration.md` to avoid duplication.

## Rules

1. Apply `@pytest.mark.django_db` only to tests that require database access; tests without DB access must run without the marker. (Source: https://pytest-django.readthedocs.io/en/latest/database.html)
2. Use rollback isolation (default `django_db`) as the baseline; apply `transaction=True` exclusively when the test must observe `transaction.on_commit(...)` or explicit commit behaviour. (Source: https://pytest-django.readthedocs.io/en/latest/database.html)
3. Declare access to non-default database aliases with `databases=[...]` on the `django_db` marker. (Source: https://pytest-django.readthedocs.io/en/latest/database.html)
4. Seed persistent shared data only via `django_db_blocker.unblock()` in a session-scoped fixture; use `--reuse-db`/`--create-db` to control schema lifecycle across runs. (Source: https://pytest-django.readthedocs.io/en/latest/database.html)
5. Use `DjangoModelFactory` (factory_boy) for all test object creation; do not use hard-coded fixture files or bare `Model.objects.create()` calls in test bodies. (Source: https://factoryboy.readthedocs.io/en/stable/orms.html)
6. Use `SubFactory` for FK/related objects, `Sequence` for fields with `UNIQUE` constraints, and `post_generation` for M2M relations; set `django_get_or_create` in `Meta` for idempotent lookup factories. (Source: https://factoryboy.readthedocs.io/en/stable/orms.html)
7. Mute signals during factory object creation using `factory.django.mute_signals` or the `@mute_signals` decorator to prevent side-effects from polluting tests. (Source: https://factoryboy.readthedocs.io/en/stable/orms.html)
8. Use `factory.build()` in unit tests that do not require DB persistence; reserve `factory.create()` for tests that must assert on persisted state. (Source: https://factoryboy.readthedocs.io/en/stable/orms.html)
9. Concentrate test coverage on the service layer (services.py / selectors.py); mock external I/O and cross-layer calls, and assert `on_commit` task queueing rather than Celery task execution. (Source: https://github.com/HackSoftware/Django-Styleguide)
10. Test model methods only when they carry non-trivial business logic; exercise them via service-layer tests where possible rather than isolated model unit tests. (Source: https://github.com/HackSoftware/Django-Styleguide)
11. Mock selector calls in service tests and mock service calls in view/API tests to enforce layer boundaries and keep each test level focused. (Source: https://github.com/HackSoftware/Django-Styleguide)
