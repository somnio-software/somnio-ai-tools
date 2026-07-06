### Django migrations — schema vs data migrations, RunPython historical-model access, reversibility, cross-app dependencies, and commit discipline.
> Applies to: `**/migrations/*.py`
## Rules

1. Commit migrations alongside the model change that generated them — never in a separate commit. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
2. Each migration addresses exactly one logical change; do not bundle unrelated schema alterations. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
3. Separate schema migrations from data migrations; use `makemigrations --empty` to generate blank data-migration files. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
4. Inside every `RunPython` callable, access models exclusively via `apps.get_model("app_label", "ModelName")` — never via a direct import of the model class. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
5. Every `RunPython` call must supply a `reverse_code` argument; use `RunPython.noop` if reversal is intentionally a no-op rather than omitting it. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
6. Use `makemigrations --name <descriptive_name>` so every migration file has a human-readable name in `git log` and `showmigrations`. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
7. Declare explicit cross-app `dependencies` entries whenever a migration references a model or field owned by another app. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
8. Never modify the database schema or data out-of-band; all structural changes must go through the migrations system. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))

## Rules

- Commit every migration together with the model change that generated it; the migration file is part of the same logical change, not a follow-up commit. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
- Keep each migration to one logical change — one new model, one field addition, one constraint. This makes squashing, bisecting, and reverting predictable. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
- Never mix schema changes and data backfills in the same migration file. Use `makemigrations --empty <app>` to generate a blank data migration and perform backfills there; schema and data migrations have different rollback risk profiles and deployment ordering requirements. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
- In every `RunPython` callable, obtain the model via `apps.get_model("app_label", "ModelName")` — never import the live model class directly. Direct imports bypass the historical schema snapshot that Django builds for safe data migrations; importing the live class means the code runs against the *current* model definition, not the state at the time of the migration, causing breakage when future model changes are applied. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
- Always provide a `reverse_code` argument to `RunPython` — even if reversal is a no-op (`RunPython.noop`). Omitting it makes the migration irreversible, preventing `migrate <app> <previous>` and blocking emergency rollbacks in production. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
- Give every migration a descriptive `--name` when generating it (e.g. `makemigrations --name add_invoice_status_index invoicing`). Auto-generated names like `0017_auto_20240601_1423` are opaque in `git log` and `showmigrations` output. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
- Declare explicit cross-app `dependencies` when a migration touches a model from another app. Django can infer some dependencies automatically, but implicit ordering is fragile when apps are added or removed; an explicit `("other_app", "0005_some_migration")` entry in the `dependencies` list makes the ordering unambiguous. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))
- Never alter the database schema by hand (direct SQL or admin tooling outside of migrations). Out-of-band DDL changes desynchronize the migration graph and break `migrate`, `showmigrations`, and `sqlmigrate` for every developer and deployment environment. ([migrations](https://docs.djangoproject.com/en/stable/topics/migrations/))

- Avoid importing a live model class directly inside a `RunPython` callable instead of calling `apps.get_model(...)`. This is the single most common data-migration bug: the callable runs correctly at authoring time but silently operates on a mismatched schema once further model changes are applied.
- Avoid omitting `reverse_code` from `RunPython`. This is easily overlooked when writing one-shot backfills; the absence is invisible until a rollback is attempted in production under pressure.
- Avoid combining a schema change (e.g. `AddField`) and a data backfill in the same migration. The correct pattern is two migrations: one that adds the column, one (data migration) that populates it.
- Avoid undeclared cross-app dependencies. If migration `invoicing.0012` relies on a field added by `accounts.0008`, but `accounts.0008` is absent from `dependencies`, the migration order is non-deterministic across fresh installs and CI runs.
- Avoid not committing migrations. Leaving migrations as local-only changes means teammates hit `InconsistentMigrationHistory` errors and CI fails on the database-setup step.
- Avoid using vague auto-generated migration names. Reviewing `git log` or `showmigrations` output becomes difficult when every name is a timestamp.
- Avoid running ad-hoc `ALTER TABLE` or `INSERT` statements directly on the database. Even a "quick fix" applied in production will desync the migration graph and may conflict with the next deploy.
