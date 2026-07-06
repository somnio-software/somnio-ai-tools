---
description: Flask extension initialization via init_app and Flask-SQLAlchemy session, context, and migration patterns. Applies to all Python files in Flask projects.
globs: **/*.py
alwaysApply: false
---

## Best Practices

- Instantiate extensions at **module scope without the app object** (`db = SQLAlchemy()`, `migrate = Migrate()`, `login_manager = LoginManager()`), then bind them inside the factory with `db.init_app(app)`. This keeps no app-specific state on the extension object, making it reusable across multiple apps and test instances. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/ · [flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

- Load configuration **before** calling `init_app` so extensions can read `app.config` values (e.g. `SQLALCHEMY_DATABASE_URI`) during binding. ([config] https://flask.palletsprojects.com/en/stable/config/)

- Use SQLAlchemy 2.x declarative style: `Mapped[...]` type annotations and `mapped_column(...)` for model definitions. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

- Call `db.create_all()` **only** inside an active app context (`with app.app_context(): db.create_all()`), and only for development or test setup. In production, use Alembic migrations via Flask-Migrate instead. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

- Perform all queries and session operations within an active app context. Prefer `db.session.execute(db.select(Model).where(...))` over the legacy `Model.query` interface. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

- When registering multiple extensions, group all `ext.init_app(app)` calls together inside `create_app`, after config is loaded and before blueprints are registered, so the initialization order is clear and reproducible. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/)

## Common Mistakes

- **`db = SQLAlchemy(app)` inside the factory** — passing the app to the constructor in the factory defeats the purpose of `init_app` and breaks multi-app setups and test isolation. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/)

- **Per-app state on shared extension singletons** — storing request-scoped or app-scoped data directly on the module-level extension object (e.g. `db.my_custom_attr = ...`) corrupts state across test runs or multiple WSGI app instances. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/)

- **Accessing the session or running queries outside an app context** — code executed at import time or in background threads without a pushed context will raise `RuntimeError: Working outside of application context`. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

- **Using `db.create_all()` to manage production schema** — `create_all` is not migration-aware; it will not alter or drop existing columns. Use Flask-Migrate / Alembic for any schema change in a deployed database. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

- **Using the legacy `Model.query` interface** — `Model.query` is a Flask-SQLAlchemy 2.x legacy API and is not available by default in Flask-SQLAlchemy 3.x. Prefer `db.session.execute(db.select(...))`. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

- **Initializing extensions after blueprint registration** — some extensions (e.g. Flask-Login, Flask-Migrate) need to see the app's blueprints or URL map during `init_app`. Follow the order: config → extensions → blueprints → error handlers. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/)

## Purpose

Defines how Flask extensions — especially Flask-SQLAlchemy — must be initialized and used. The `init_app` pattern is the only safe approach for factory-based apps: it decouples the extension from any single app object, enabling test isolation, multi-app deployments, and clean teardown. Correct session and context discipline prevents the most common Flask runtime errors in database-backed code.

## Rules

1. Declare every extension at module scope without passing an app: `db = SQLAlchemy()`. Never pass the app to the constructor inside or outside the factory. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/ · [flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

2. Bind extensions inside `create_app` with `ext.init_app(app)`, called after config is loaded. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/ · [config] https://flask.palletsprojects.com/en/stable/config/)

3. Never store per-app or per-request state on the shared extension singleton. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/)

4. Perform all session operations and queries within an active app context; push one explicitly (`with app.app_context():`) when outside a request. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

5. Manage production schema exclusively through Alembic migrations (Flask-Migrate). Reserve `db.create_all()` for test fixtures and initial local setup only. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

6. Use SQLAlchemy 2.x `Mapped[...]` / `mapped_column` model style and `db.session.execute(db.select(...))` query style; do not use the legacy `Model.query` interface. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)
