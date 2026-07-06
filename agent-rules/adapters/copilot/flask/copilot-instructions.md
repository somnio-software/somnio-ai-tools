# Somnio Coding Standards — GitHub Copilot (Flask)

Follow these standards in all code suggestions.

### Using Flask current_app and g proxies, application and request context lifetime, and keeping view functions thin.
> Applies to: `**/*.py`

## Rules

1. Always reach the running application via `current_app`; never import the `app` instance from another module. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
2. `g` holds only per-context (per-request or per-app-context) data; anything that must outlive the context must go in the session or a database. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
3. Never access context-bound proxies (`current_app`, `request`, `session`, `g`) at import/module scope; push an explicit app context first when access is needed outside a request. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
4. Keep view functions thin — delegate business logic to plain Python functions so that logic can be tested without HTTP machinery. (Default chosen from recommendation in [testing](https://flask.palletsprojects.com/en/stable/testing/); contested because Flask imposes no structural requirement.)

## Rules

- Use the `current_app` proxy to reference the running application inside views, helpers, and extensions — never import the `app` object directly from another module. Importing `app` causes circular imports and breaks under the application factory pattern where no module-level `app` exists. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
- Use `g` for data that must live exactly for one request or application-context lifetime. The idiomatic pattern is a `get_db()` helper that stores the connection on `g` and a `teardown_appcontext` callback that calls `g.pop('db', None)` to release it. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
- When you need an application context outside a running request (CLI commands, background threads, test setup, scripts), push one explicitly with `with app.app_context():`. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
- **CONTESTED — service layer.** Flask is deliberately unopinionated about where business logic lives. The chosen default for this project is **thin views that delegate to plain functions** — this aligns with the testing documentation's guidance to "extract complex behaviors as separate functions" so they can be tested without HTTP machinery. ([testing](https://flask.palletsprojects.com/en/stable/testing/)) Views should validate input, call a service/helper function, and return a response; domain logic must not live inline inside route handlers.

- Avoid storing data on `g` that needs to persist beyond the current context. The docs state: "The data is lost after the context ends … use the session or a database instead." ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
- Avoid accessing `current_app`, `request`, or `session` at import/module scope. These proxies are only valid inside an active context; accessing them during module initialization raises `RuntimeError: Working outside of application context`. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
- Avoid importing the app object across modules (e.g., `from myapp import app` inside a blueprint or helper). This leads to circular imports and is incompatible with the application factory pattern. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
- Avoid embedding non-trivial business logic directly inside view functions, making the logic untestable without a full request context.

---

### Flask application factory (create_app) and installable package layout; avoid module-level global app instances.
> Applies to: `**/*.py`

## Rules

1. **Factory-created app object.** The `Flask(...)` constructor call must appear inside `create_app`, not at module scope. No file in the project may contain a bare `app = Flask(__name__)` outside a function body.
   _Source: [appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/ · [factory] https://flask.palletsprojects.com/en/stable/tutorial/factory/_

2. **Factory accepts `test_config`.** `create_app` must accept at least a `test_config` parameter (defaulting to `None`) so that test fixtures can override configuration without patching environment variables.
   _Source: [factory] https://flask.palletsprojects.com/en/stable/tutorial/factory/_

3. **All registration inside the factory.** Config loading, `init_app` calls, blueprint registration, error handler registration, and CLI command attachment must all occur inside `create_app` before `return app`. No setup may be deferred to import-time side effects outside the factory.
   _Source: [appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/ · [factory] https://flask.palletsprojects.com/en/stable/tutorial/factory/_

4. **Installable package, never a directly-runnable module.** The application must be structured as a Python package (a directory with `__init__.py` containing the factory) and launched with `flask --app <package> run`. The codebase must not contain invocations of `python <package>/__init__.py` or `python -m <package>` as the primary run method.
   _Source: [packages] https://flask.palletsprojects.com/en/stable/patterns/packages/ · [factory] https://flask.palletsprojects.com/en/stable/tutorial/factory/_

5. **No import-time dependence on config or app.** Module-level code must not read `app.config`, call `current_app`, or invoke any function that requires an active application context. Such logic belongs inside a view, a factory-registered callback, or a block that explicitly pushes an app context (`with app.app_context():`).
   _Source: [config] https://flask.palletsprojects.com/en/stable/config/ · [appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/_

## Rules

- Create the `Flask` instance inside a `create_app` function, never as a module-level global — this is the pattern auto-detected by `flask --app` and avoids "tricky issues as the project grows". ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/ · [factory] https://flask.palletsprojects.com/en/stable/tutorial/factory/)
- Use the canonical signature `def create_app(test_config=None):`, loading defaults first and then overriding with instance or test config so the factory is reusable across environments. ([factory] https://flask.palletsprojects.com/en/stable/tutorial/factory/)
- Do ALL setup inside the factory — config loading, extension initialization, blueprint registration, error handler registration, CLI command attachment — then `return app` at the end. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/ · [factory] https://flask.palletsprojects.com/en/stable/tutorial/factory/)
- Structure real applications as an installable package: place the factory in the package's `__init__.py`, run via the `flask` command (`flask --app yourpackage run`), and never run via `python yourpackage/__init__.py`. ([packages] https://flask.palletsprojects.com/en/stable/patterns/packages/ · [factory] https://flask.palletsprojects.com/en/stable/tutorial/factory/)
- When CLI or test code needs to vary factory behaviour, pass arguments to `create_app` directly (`create_app(test_config={...})`) rather than relying on environment mutation after import. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/)

- Avoid **Module-level `app = Flask(__name__)`** — the docs explicitly warn this causes "tricky issues as the project grows"; the factory pattern exists precisely to avoid it. ([factory] https://flask.palletsprojects.com/en/stable/tutorial/factory/)
- Avoid **Code that reads config or calls extensions at import time** — any module-level code that depends on `app.config` will execute before the factory has loaded configuration, silently reading stale or missing values. ([config] https://flask.palletsprojects.com/en/stable/config/)
- Avoid **`python yourpackage/__init__.py`** — running the package file directly bypasses the Flask development server and the app context bootstrap; always use the `flask` CLI. ([packages] https://flask.palletsprojects.com/en/stable/patterns/packages/)
- Avoid **The legacy bottom-of-`__init__` import trick** (`from . import views` at the end of `__init__.py` to register routes on a global `app`) — this pattern is an older workaround that the installable-package layout supersedes and should not appear in new code. ([packages] https://flask.palletsprojects.com/en/stable/patterns/packages/)

---

### Organizing Flask apps into feature blueprints with namespaced endpoints and blueprint-local templates and static files. Use when structuring routes into modules, building URL names, or registering blueprints in the factory.
> Applies to: `**/*.py`

## Rules

1. Every cohesive feature that owns a set of routes must be implemented as a `Blueprint` registered inside `create_app` with an explicit `url_prefix`. ([blueprints])
2. Build URLs exclusively through `url_for` using the namespaced form `'<blueprint_name>.<endpoint>'` from outside the blueprint, or the relative form `'.<endpoint>'` from within it. Never hard-code URL strings in `href` attributes or redirects. ([blueprints])
3. Place blueprint-local templates under `<blueprint>/templates/<blueprint_name>/` and reference them as `'<blueprint_name>/template.html'` to avoid name collisions with app-level templates. ([blueprints])
4. Register 404 and 405 error handlers at the application level (inside `create_app`), never on a blueprint, because routing-level errors bypass blueprint error handlers entirely. For Flask-specific registration patterns see `flask/error-handling.md`. ([blueprints], [errorhandling])
5. Access the application object inside blueprint views via `current_app`; never import the application instance across modules. ([appfactories], [appcontext])

---

**Citations**

- [appfactories] Application Factories — https://flask.palletsprojects.com/en/stable/patterns/appfactories/
- [factory] Tutorial: Application Setup — https://flask.palletsprojects.com/en/stable/tutorial/factory/
- [blueprints] Modular Applications with Blueprints — https://flask.palletsprojects.com/en/stable/blueprints/
- [appcontext] The Application Context (`current_app`/`g`) — https://flask.palletsprojects.com/en/stable/appcontext/
- [errorhandling] Handling Application Errors — https://flask.palletsprojects.com/en/stable/errorhandling/

## Rules

- Factor larger applications into feature-oriented `Blueprint` objects and register them in `create_app` with a `url_prefix` so each feature owns a distinct URL namespace. ([blueprints])
- Build URLs with the blueprint name as a prefix: `url_for('admin.index')` from outside the blueprint, or the relative shorthand `url_for('.index')` from a view inside the same blueprint. ([blueprints])
- Ship blueprint-local templates under `<blueprint>/templates/<blueprint_name>/` and static files under `<blueprint>/static/`. App-level templates (in the application's `templates/` folder) always take precedence over blueprint-level templates when names collide. ([blueprints])
- Use `current_app` inside blueprint views instead of importing the application object; under the factory pattern there is no importable app-level `app` variable. ([appfactories], [appcontext])
- Register all blueprints inside `create_app` after config and extensions have been initialised, then `return app`. ([factory], [blueprints])

- Avoid expecting a blueprint-registered `404` or `405` error handler to fire: blueprint error handlers only handle errors raised *within that blueprint's views*; routing-level errors (no route matched, method not allowed) are always dispatched to the app-level handler. Register 404/405 handlers on the application, not on a blueprint. ([blueprints], [errorhandling])
- Avoid relying on a blueprint's `static_folder` route when no `url_prefix` is set: without a prefix the static endpoint URL collides with the app-level `/static/` endpoint, producing an `AssertionError` at registration time. ([blueprints])
- Avoid treating a blueprint as a fully independent WSGI application that can be mounted and unmounted without re-registering: a blueprint is *not* a sub-application; it has no app context of its own and cannot be detached from the app it was registered with. ([blueprints])
- Avoid importing the application instance (`from myapp import app`) inside a blueprint module; this creates a circular import and breaks the factory pattern. Use `current_app` instead. ([appfactories], [appcontext])

---

### Flask configuration objects, config-class hierarchy, SECRET_KEY and secrets handling, debug flag, instance folder, and cookie hardening. Applies to all Flask .py files.
> Applies to: `**/*.py`

## Rules

1. **UPPERCASE keys only.** All `app.config` keys must be uppercase; lowercase keys are silently ignored by Flask. ([config](https://flask.palletsprojects.com/en/stable/config/))

2. **Config-class hierarchy selected by one env var.** Define `Config` / `DevelopmentConfig` / `ProductionConfig` / `TestingConfig` classes; select the active class via a single environment variable and `app.config.from_object(...)`. **CONTESTED — config strategy:** the Flask docs present `from_object`, `from_envvar`, and `from_prefixed_env` as equally valid alternatives. This rule standardises on a config-class hierarchy + `from_object` as the default because it is explicit, type-checkable, and maps naturally to deployment pipelines; teams may choose `from_prefixed_env` for twelve-factor purity as long as the choice is applied uniformly. ([config](https://flask.palletsprojects.com/en/stable/config/))

3. **`SECRET_KEY` from env or instance folder — never committed; rotate via `SECRET_KEY_FALLBACKS`.** Generate with `secrets.token_hex(32)`. Store in `os.environ['SECRET_KEY']` or the instance config file. List older keys in `SECRET_KEY_FALLBACKS` during rotation periods. ([config](https://flask.palletsprojects.com/en/stable/config/))

4. **Debug mode exclusively via `--debug` CLI flag; never in config or code.** Do not set `DEBUG=True` in any config class, `.env` file, or `app.run()` call. This prevents the Werkzeug interactive debugger from reaching production. ([config](https://flask.palletsprojects.com/en/stable/config/))

5. **Deployment-specific files belong in the instance folder.** Initialise the app with `instance_relative_config=True` and load overrides with `app.config.from_pyfile('config.py', silent=True)`. Add `instance/` to `.gitignore`. ([config](https://flask.palletsprojects.com/en/stable/config/) · [factory](https://flask.palletsprojects.com/en/stable/tutorial/factory/))

6. **Harden session cookies in production config.** Set `SESSION_COOKIE_SECURE=True`, `SESSION_COOKIE_HTTPONLY=True`, `SESSION_COOKIE_SAMESITE='Lax'` (or `'Strict'`), and, where applicable, `TRUSTED_HOSTS` in `ProductionConfig`. ([config](https://flask.palletsprojects.com/en/stable/config/))

## Rules

- **UPPERCASE keys only.** Only uppercase names are stored by Flask; lowercase keys are silently ignored by `app.config`. ([config](https://flask.palletsprojects.com/en/stable/config/))
- **Config-class hierarchy selected by one env var.** Define a `Config` base class with safe defaults, then `DevelopmentConfig`, `ProductionConfig`, `TestingConfig` subclasses that override per-environment values. Load with `app.config.from_object(os.environ['APP_ENV'])` (or a mapping dict keyed by the env-var value). This is the chosen default — see CONTESTED note below. ([config](https://flask.palletsprojects.com/en/stable/config/))
- **Secrets from env or the instance folder, never committed.** Read `SECRET_KEY` and other secrets from environment variables (`os.environ['SECRET_KEY']`) or from a file inside the instance folder (`app.instance_path`). Use `secrets.token_hex(32)` to generate a strong value. Support key rotation with `SECRET_KEY_FALLBACKS` (a list of older keys Flask will still accept for existing sessions). ([config](https://flask.palletsprojects.com/en/stable/config/))
- **Debug mode via `--debug` flag only.** Never set `DEBUG=True` in a config class, environment variable, or `app.run(debug=True)`. Enable debug mode exclusively through `flask --debug run` on the CLI. This ensures it can never accidentally reach production. ([config](https://flask.palletsprojects.com/en/stable/config/))
- **Deployment-specific files in the instance folder.** Pass `instance_relative_config=True` to the `Flask()` constructor and load deployment overrides with `app.config.from_pyfile('config.py', silent=True)`. The instance folder is outside version control by default (`instance/` in `.gitignore`). ([config](https://flask.palletsprojects.com/en/stable/config/) · [factory](https://flask.palletsprojects.com/en/stable/tutorial/factory/))
- **Harden session cookies in production.** Set `SESSION_COOKIE_SECURE=True`, `SESSION_COOKIE_HTTPONLY=True`, and `SESSION_COOKIE_SAMESITE='Lax'` (or `'Strict'`) in the production config. Optionally configure `TRUSTED_HOSTS` to guard against host-header injection. ([config](https://flask.palletsprojects.com/en/stable/config/))

- Avoid **Committed `SECRET_KEY` or other secrets.** Hard-coding secrets in any checked-in file (`config.py`, `.env` committed to git) is a critical security flaw. Always read from the environment or instance folder. ([config](https://flask.palletsprojects.com/en/stable/config/))
- Avoid **Lowercase config keys.** Keys like `secret_key = "..."` are silently ignored by Flask — the application runs without error but sessions are broken or insecure. ([config](https://flask.palletsprojects.com/en/stable/config/))
- Avoid **`DEBUG=True` in code or config.** Setting debug mode through config or `app.run()` is fragile: it can leak into production builds, enables the Werkzeug debugger (remote code execution risk), and bypasses the intent of the `--debug` CLI flag. ([config](https://flask.palletsprojects.com/en/stable/config/))
- Avoid **Single flat config for all environments.** One `config.py` with `if ENV == 'production':` branches mixes concerns and makes it easy to accidentally ship development settings. A class hierarchy with one env var as the selector avoids this. ([config](https://flask.palletsprojects.com/en/stable/config/))
- Avoid **Missing `SESSION_COOKIE_SECURE` in production.** Without it, session cookies are transmitted over plain HTTP, making them trivially interceptable. ([config](https://flask.palletsprojects.com/en/stable/config/))

---

### Flask error handler registration in the factory, explicit HTTP status codes, and JSON API error responses with Werkzeug HTTPException.
> Applies to: `**/*.py`

## Rules

1. Register all error handlers inside `create_app` using `@app.errorhandler` or `app.register_error_handler`; never register them at module scope or outside the factory. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
2. Return the HTTP status code explicitly from every error handler (e.g. `return response, 404`); do not rely on Flask to infer it from the registered exception class. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
3. Construct JSON error responses by calling `e.get_response()` and overwriting `.data` and `Content-Type`, preserving the original status code and all Werkzeug-set headers. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
4. A broad `Exception` handler, if present, must immediately re-raise `werkzeug.exceptions.HTTPException` instances; prefer registering specific handlers over a catch-all. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
5. Subclass `werkzeug.exceptions.HTTPException` (setting `code` and `description`) for any non-standard HTTP status code; do not raise plain exceptions with ad-hoc codes. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
6. Register 404 and 405 (and other routing-layer) error handlers at the app level, not on a blueprint, because routing errors are raised before blueprint dispatch. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/), [blueprints](https://flask.palletsprojects.com/en/stable/blueprints/))

## Rules

- Register error handlers with `@app.errorhandler` or `app.register_error_handler` as plain functions inside `create_app`, never at module scope. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- Always set the HTTP status code explicitly on the response returned from a handler — Flask does not automatically apply the handler's registered code to the returned value. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- Build JSON error responses by starting from `e.get_response()` and replacing its `Content-Type` and data, so that the original status code and headers (e.g. `WWW-Authenticate`, `Retry-After`) are preserved. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- For non-standard HTTP status codes, subclass `werkzeug.exceptions.HTTPException` and set `code` and `description` on the class body; register it with `app.register_error_handler`. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- Model application-level domain errors (e.g. missing resource in an API) as a custom `InvalidAPIUsage` exception with `status_code` and a `to_dict()` method, and raise it via `abort` or directly; use `abort(404, description=...)` for quick HTTP errors. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- A `500`/`InternalServerError` handler receives both intentional `abort(500)` calls and uncaught exceptions; access the original exception via `e.original_exception` to log or report it. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- Integrate a production error aggregator (e.g. Sentry) for unhandled exceptions; the docs provide the canonical `init_app` setup pattern. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- For routing errors (404, 405) that must return JSON, register the handlers at the **app** level, not on a blueprint — blueprint-scoped handlers do not fire for routing errors. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/), [blueprints](https://flask.palletsprojects.com/en/stable/blueprints/))
- For language-level exception design (exception hierarchies, raising vs returning, narrowing except clauses), see `python/error-handling.md`.

- Avoid **Broad `@app.errorhandler(Exception)` that swallows HTTP errors.** A catch-all `Exception` handler intercepts `werkzeug.exceptions.HTTPException` subclasses, turning 404s and 405s into 500 responses. If you must register one, re-raise `HTTPException` instances immediately. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- Avoid **JSON handler that discards status code and headers.** Constructing `jsonify(...)` from scratch loses the status code, `WWW-Authenticate`, and other headers set by Werkzeug. Always start from `e.get_response()` and mutate its `.data` and `Content-Type`. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- Avoid **Registering routing-error handlers on a blueprint.** Blueprint `errorhandler` decorators handle only errors that originate inside that blueprint's own view functions; 404 and 405 are raised by the routing layer before any blueprint is involved. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/), [blueprints](https://flask.palletsprojects.com/en/stable/blueprints/))
- Avoid **Relying on a 500 handler in debug mode.** Flask's interactive debugger takes over in debug mode and the `InternalServerError` handler is not called. Do not test 500-handler logic with `DEBUG=True`. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- Avoid **Registering handlers outside the factory.** Attaching `@app.errorhandler` at module scope, or on a module-level `app` object, breaks the application factory pattern and makes handlers invisible to the test app. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))

---

### Flask extension initialization via init_app and Flask-SQLAlchemy session, context, and migration patterns. Applies to all Python files in Flask projects.
> Applies to: `**/*.py`

## Rules

1. Declare every extension at module scope without passing an app: `db = SQLAlchemy()`. Never pass the app to the constructor inside or outside the factory. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/ · [flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

2. Bind extensions inside `create_app` with `ext.init_app(app)`, called after config is loaded. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/ · [config] https://flask.palletsprojects.com/en/stable/config/)

3. Never store per-app or per-request state on the shared extension singleton. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/)

4. Perform all session operations and queries within an active app context; push one explicitly (`with app.app_context():`) when outside a request. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

5. Manage production schema exclusively through Alembic migrations (Flask-Migrate). Reserve `db.create_all()` for test fixtures and initial local setup only. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

6. Use SQLAlchemy 2.x `Mapped[...]` / `mapped_column` model style and `db.session.execute(db.select(...))` query style; do not use the legacy `Model.query` interface. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

## Rules

- Instantiate extensions at **module scope without the app object** (`db = SQLAlchemy()`, `migrate = Migrate()`, `login_manager = LoginManager()`), then bind them inside the factory with `db.init_app(app)`. This keeps no app-specific state on the extension object, making it reusable across multiple apps and test instances. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/ · [flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

- Load configuration **before** calling `init_app` so extensions can read `app.config` values (e.g. `SQLALCHEMY_DATABASE_URI`) during binding. ([config] https://flask.palletsprojects.com/en/stable/config/)

- Use SQLAlchemy 2.x declarative style: `Mapped[...]` type annotations and `mapped_column(...)` for model definitions. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

- Call `db.create_all()` **only** inside an active app context (`with app.app_context(): db.create_all()`), and only for development or test setup. In production, use Alembic migrations via Flask-Migrate instead. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

- Perform all queries and session operations within an active app context. Prefer `db.session.execute(db.select(Model).where(...))` over the legacy `Model.query` interface. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

- When registering multiple extensions, group all `ext.init_app(app)` calls together inside `create_app`, after config is loaded and before blueprints are registered, so the initialization order is clear and reproducible. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/)

- Avoid **`db = SQLAlchemy(app)` inside the factory** — passing the app to the constructor in the factory defeats the purpose of `init_app` and breaks multi-app setups and test isolation. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/)

- Avoid **Per-app state on shared extension singletons** — storing request-scoped or app-scoped data directly on the module-level extension object (e.g. `db.my_custom_attr = ...`) corrupts state across test runs or multiple WSGI app instances. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/)

- Avoid **Accessing the session or running queries outside an app context** — code executed at import time or in background threads without a pushed context will raise `RuntimeError: Working outside of application context`. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

- Avoid **Using `db.create_all()` to manage production schema** — `create_all` is not migration-aware; it will not alter or drop existing columns. Use Flask-Migrate / Alembic for any schema change in a deployed database. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

- Avoid **Using the legacy `Model.query` interface** — `Model.query` is a Flask-SQLAlchemy 2.x legacy API and is not available by default in Flask-SQLAlchemy 3.x. Prefer `db.session.execute(db.select(...))`. ([flask-sqlalchemy] https://flask-sqlalchemy.palletsprojects.com/en/stable/quickstart/)

- Avoid **Initializing extensions after blueprint registration** — some extensions (e.g. Flask-Login, Flask-Migrate) need to see the app's blueprints or URL map during `init_app`. Follow the order: config → extensions → blueprints → error handlers. ([appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/)

---

### Testing Flask apps with conftest factory fixtures, test_client and test_cli_runner, TESTING mode, and context pushing.
> Applies to: `**/*.py`

## Rules

1. The `app` fixture in `tests/conftest.py` must call `create_app(...)` with `TESTING=True`, `yield` the app, and include teardown. ([testing] https://flask.palletsprojects.com/en/stable/testing/)
2. The `client` and `runner` fixtures must be derived from the factory-built `app` fixture via `app.test_client()` and `app.test_cli_runner()`; never created from a module-level global `app`. ([testing] https://flask.palletsprojects.com/en/stable/testing/)
3. JSON endpoint tests must use `client.post(..., json=...)` and read `response.json`; redirect-following tests must use `follow_redirects=True` and inspect `response.history`. ([testing] https://flask.palletsprojects.com/en/stable/testing/)
4. Push `app.app_context()` or `app.test_request_context()` for context-only tests; call `app.preprocess_request()` explicitly when `before_request` hook execution is required — `test_request_context()` alone does not trigger it. ([testing] https://flask.palletsprojects.com/en/stable/testing/)
5. Tests must target application code, not Flask or third-party library internals. ([testing] https://flask.palletsprojects.com/en/stable/testing/)

## Rules

- Define all fixtures in `tests/conftest.py`. The `app` fixture must call `create_app(...)` with `TESTING=True`, `yield` the app, then perform teardown — this ensures each test gets a fresh application instance with exceptions propagating correctly ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- Derive `client` and `runner` fixtures from the factory-built `app` fixture using `app.test_client()` and `app.test_cli_runner()` respectively; never instantiate them from a module-level global `app` ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- Set `TESTING=True` in the test config so Flask propagates exceptions instead of returning 500 responses; without this flag, test failures may be silently swallowed ([testing] https://flask.palletsprojects.com/en/stable/testing/, [config] https://flask.palletsprojects.com/en/stable/config/).
- Test JSON endpoints via `client.post(..., json=...)` and read `response.json`; use `follow_redirects=True` and inspect `response.history` for redirect-based flows ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- Test session state via a `with client:` block (so `session` is accessible after the response) or with `client.session_transaction()` to pre-populate the session before the request ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- Push `app.app_context()` or `app.test_request_context()` in fixtures or tests that need context-bound objects (e.g., `current_app`, `g`, `db`) outside of a real request cycle ([testing] https://flask.palletsprojects.com/en/stable/testing/, [appcontext] https://flask.palletsprojects.com/en/stable/appcontext/).
- Extract complex view logic into plain helper functions so that logic can be unit-tested without the HTTP layer at all ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- For generic pytest discipline (fixture scope, parametrize, coverage thresholds, test naming), see `python/testing-unit.md`.

- Avoid calling `app.test_request_context()` and expecting `before_request` hooks to have run — `test_request_context()` does NOT dispatch a request; `before_request` is not called. Manually call `app.preprocess_request()` when that behaviour is required ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- Avoid writing tests that exercise Flask or a third-party library rather than your own application code — tests should target behaviour you wrote, not library internals ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- Avoid creating the `Flask` instance at module scope (outside a factory) and importing it directly in tests — this couples tests to a non-configurable app and breaks isolation; always go through `create_app` ([testing] https://flask.palletsprojects.com/en/stable/testing/, [appfactories] https://flask.palletsprojects.com/en/stable/patterns/appfactories/).
- Avoid forgetting `TESTING=True` — unhandled exceptions become opaque 500 responses rather than test failures, making debugging unnecessarily hard ([testing] https://flask.palletsprojects.com/en/stable/testing/).
- Avoid accessing `session` after the `with client:` block has closed — the session context is torn down on block exit; read `session` inside the block ([testing] https://flask.palletsprojects.com/en/stable/testing/).

---
