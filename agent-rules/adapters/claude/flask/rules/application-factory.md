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
