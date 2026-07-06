---
description: Django models and ORM optimization — select_related/prefetch_related for N+1 defense, bulk operations, DB-level evaluation, queryset limits, Meta indexes and constraints, and profiling. Applies to all Python files.
globs: **/*.py
alwaysApply: false
---

## Best Practices

- Use `select_related()` for forward FK and one-to-one relationships (single SQL JOIN); use `prefetch_related()` for reverse FK and M2M relationships (separate query + Python join) — both prevent N+1 loops ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).
- Use `values()`, `only()`, and `defer()` to limit the columns fetched when you do not need full model instances ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).
- Use `.count()` instead of `len(qs)`, `.exists()` instead of `if qs:`, and `.contains(obj)` instead of `obj in qs` — all push evaluation into the DB and avoid loading rows ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).
- Use `bulk_create()`, `bulk_update()`, and `m2m.add(*objs)` instead of per-object loops; a single SQL statement is orders of magnitude faster than N individual saves ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).
- Access `instance.related_id` (the raw FK column) instead of `instance.related.pk` to avoid an extra query when you only need the id ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).
- Assign a queryset to a local variable and reuse it; use `iterator()` for querysets that return large numbers of rows and whose results are not needed more than once ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).
- Push aggregation and computed values into the DB with `annotate()`, `aggregate()`, and `F()` expressions rather than processing Python lists ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).
- Declare `Meta.indexes` (with `fields` and an explicit `name`) on columns used in `filter()`, `order_by()`, and `exclude()`; add `db_index=True` directly on a field only for single-column indexes ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).
- Enforce integrity at the DB layer with `Meta.constraints` — `UniqueConstraint` for uniqueness, `CheckConstraint` for value rules — rather than relying solely on Python-level validation ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).
- Profile slow querysets with `qs.explain()` and the Django Debug Toolbar SQL panel before optimizing; confirm each optimization with a measured before/after ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).

## Common Mistakes

- Accessing a related object (`article.reporter.name`) inside a loop without a prior `select_related()` or `prefetch_related()` — generates N+1 queries, one per loop iteration ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).
- Writing `len(qs)` or `if qs:` to check count/emptiness — forces the ORM to evaluate the entire queryset and load all rows into memory ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).
- Saving objects inside a loop (`for obj in items: obj.save()`) instead of a single `bulk_update()` call — scales linearly with row count ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).
- Missing indexes on frequently filtered or ordered columns — causes full-table scans as the table grows ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).
- Enforcing uniqueness or value rules only at the Python/form level without a corresponding `Meta` constraint — allows inconsistent data when rows are inserted by management commands, bulk ops, or external tools ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).
- Fetching full model instances when only one or two fields are needed — loads unnecessary columns and may trigger additional deferred-field queries ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/)).

## Purpose

Enforce correct Django ORM usage so that the DB does the heavy lifting: joins, counting, aggregation, and integrity are pushed into SQL rather than handled in Python loops. The rules prevent the most common performance regressions (N+1, missing indexes, per-row saves) and the most common data-integrity gaps (Python-only constraints). Language-level concerns — type annotations, docstrings, generic exception design, and pytest/coverage discipline — are covered in `python/` stack rules and are not restated here.

## Rules

1. **`select_related` for FK/one-to-one, `prefetch_related` for reverse FK/M2M.** Every queryset that accesses a related object must use the appropriate prefetch method; access without it in a loop is forbidden. ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/))

2. **No related-object access inside loops without prior prefetch.** Patterns like `for obj in qs: obj.related.field` without `select_related`/`prefetch_related` are a defect. ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/))

3. **DB-level count and existence checks.** Use `.count()` in place of `len(qs)`, `.exists()` in place of `if qs:`, and `.contains(obj)` in place of `obj in qs`. ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/))

4. **Bulk operations over per-object loops.** Use `bulk_create()`, `bulk_update()`, and `m2m.add(*objs)` whenever processing more than one object; never call `.save()` inside a for-loop. ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/))

5. **Limit fetched data.** Use `values()` / `only()` / `defer()` when the code only needs a subset of fields; do not retrieve full model instances when a flat value dict suffices. ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/))

6. **Access FK ids via `*_id` attributes.** Read `instance.related_id` (the raw column) rather than `instance.related.pk` to avoid an extra SELECT. ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/))

7. **Reuse evaluated querysets; use `iterator()` for large sets.** Assign a queryset to a variable before iterating more than once; use `iterator()` when a large result set is consumed only once and caching is undesirable. ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/))

8. **Push aggregation and computed values into the DB.** Use `annotate()`, `aggregate()`, and `F()` expressions to let the DB compute totals, differences, and conditional values; do not retrieve rows and compute in Python. ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/))

9. **Index all filtered and ordered columns.** Declare `Meta.indexes` with an explicit `name` for multi-column or named indexes; use `db_index=True` only for simple single-column cases. Add indexes as a migration alongside model changes. ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/))

10. **`Meta` constraints for DB-level integrity.** Add `UniqueConstraint` for uniqueness rules and `CheckConstraint` for value rules inside `Meta.constraints`; Python-only validation (forms, serializers, `clean()`) is not a substitute for DB constraints. ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/))

11. **Profile before optimizing.** Use `qs.explain()` (or the Debug Toolbar SQL panel) to verify that a query plan is suboptimal before adding indexes or rewriting queries; document the measured improvement. ([ORM optimization](https://docs.djangoproject.com/en/stable/topics/db/optimization/))

12. **Do not hand-edit `Meta` constraints outside a migration.** Any change to `Meta.indexes` or `Meta.constraints` must be accompanied by a generated migration; never apply schema changes directly to the DB. ([Migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
