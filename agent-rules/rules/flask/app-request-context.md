---
description: Using Flask current_app and g proxies, application and request context lifetime, and keeping view functions thin.
globs: **/*.py
alwaysApply: false
---

## Best Practices

- Use the `current_app` proxy to reference the running application inside views, helpers, and extensions — never import the `app` object directly from another module. Importing `app` causes circular imports and breaks under the application factory pattern where no module-level `app` exists. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
- Use `g` for data that must live exactly for one request or application-context lifetime. The idiomatic pattern is a `get_db()` helper that stores the connection on `g` and a `teardown_appcontext` callback that calls `g.pop('db', None)` to release it. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
- When you need an application context outside a running request (CLI commands, background threads, test setup, scripts), push one explicitly with `with app.app_context():`. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
- **CONTESTED — service layer.** Flask is deliberately unopinionated about where business logic lives. The chosen default for this project is **thin views that delegate to plain functions** — this aligns with the testing documentation's guidance to "extract complex behaviors as separate functions" so they can be tested without HTTP machinery. ([testing](https://flask.palletsprojects.com/en/stable/testing/)) Views should validate input, call a service/helper function, and return a response; domain logic must not live inline inside route handlers.

## Common Mistakes

- Storing data on `g` that needs to persist beyond the current context. The docs state: "The data is lost after the context ends … use the session or a database instead." ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
- Accessing `current_app`, `request`, or `session` at import/module scope. These proxies are only valid inside an active context; accessing them during module initialization raises `RuntimeError: Working outside of application context`. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
- Importing the app object across modules (e.g., `from myapp import app` inside a blueprint or helper). This leads to circular imports and is incompatible with the application factory pattern. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
- Embedding non-trivial business logic directly inside view functions, making the logic untestable without a full request context.

## Purpose

This rule enforces correct usage of Flask's application and request context system — specifically the `current_app` and `g` proxies — so that code is free of circular imports, context-safety bugs, and `RuntimeError` crashes. It also mandates thin views to keep business logic independently testable. These are the most commonly violated Flask runtime constraints and the direct source of the majority of Flask-specific production errors.

## Rules

1. Always reach the running application via `current_app`; never import the `app` instance from another module. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
2. `g` holds only per-context (per-request or per-app-context) data; anything that must outlive the context must go in the session or a database. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
3. Never access context-bound proxies (`current_app`, `request`, `session`, `g`) at import/module scope; push an explicit app context first when access is needed outside a request. ([appcontext](https://flask.palletsprojects.com/en/stable/appcontext/))
4. Keep view functions thin — delegate business logic to plain Python functions so that logic can be tested without HTTP machinery. (Default chosen from recommendation in [testing](https://flask.palletsprojects.com/en/stable/testing/); contested because Flask imposes no structural requirement.)
