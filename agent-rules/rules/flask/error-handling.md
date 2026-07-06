---
description: Flask error handler registration in the factory, explicit HTTP status codes, and JSON API error responses with Werkzeug HTTPException.
globs: **/*.py
alwaysApply: false
---

## Best Practices

- Register error handlers with `@app.errorhandler` or `app.register_error_handler` as plain functions inside `create_app`, never at module scope. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- Always set the HTTP status code explicitly on the response returned from a handler — Flask does not automatically apply the handler's registered code to the returned value. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- Build JSON error responses by starting from `e.get_response()` and replacing its `Content-Type` and data, so that the original status code and headers (e.g. `WWW-Authenticate`, `Retry-After`) are preserved. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- For non-standard HTTP status codes, subclass `werkzeug.exceptions.HTTPException` and set `code` and `description` on the class body; register it with `app.register_error_handler`. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- Model application-level domain errors (e.g. missing resource in an API) as a custom `InvalidAPIUsage` exception with `status_code` and a `to_dict()` method, and raise it via `abort` or directly; use `abort(404, description=...)` for quick HTTP errors. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- A `500`/`InternalServerError` handler receives both intentional `abort(500)` calls and uncaught exceptions; access the original exception via `e.original_exception` to log or report it. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- Integrate a production error aggregator (e.g. Sentry) for unhandled exceptions; the docs provide the canonical `init_app` setup pattern. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- For routing errors (404, 405) that must return JSON, register the handlers at the **app** level, not on a blueprint — blueprint-scoped handlers do not fire for routing errors. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/), [blueprints](https://flask.palletsprojects.com/en/stable/blueprints/))
- For language-level exception design (exception hierarchies, raising vs returning, narrowing except clauses), see `python/error-handling.md`.

## Common Mistakes

- **Broad `@app.errorhandler(Exception)` that swallows HTTP errors.** A catch-all `Exception` handler intercepts `werkzeug.exceptions.HTTPException` subclasses, turning 404s and 405s into 500 responses. If you must register one, re-raise `HTTPException` instances immediately. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- **JSON handler that discards status code and headers.** Constructing `jsonify(...)` from scratch loses the status code, `WWW-Authenticate`, and other headers set by Werkzeug. Always start from `e.get_response()` and mutate its `.data` and `Content-Type`. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- **Registering routing-error handlers on a blueprint.** Blueprint `errorhandler` decorators handle only errors that originate inside that blueprint's own view functions; 404 and 405 are raised by the routing layer before any blueprint is involved. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/), [blueprints](https://flask.palletsprojects.com/en/stable/blueprints/))
- **Relying on a 500 handler in debug mode.** Flask's interactive debugger takes over in debug mode and the `InternalServerError` handler is not called. Do not test 500-handler logic with `DEBUG=True`. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
- **Registering handlers outside the factory.** Attaching `@app.errorhandler` at module scope, or on a module-level `app` object, breaks the application factory pattern and makes handlers invisible to the test app. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))

## Purpose

Flask does not enforce an error-response contract; without explicit conventions, error responses diverge in shape, status codes are silently wrong, and HTTP semantic headers are lost. These rules establish where handlers live (the factory), how JSON errors are constructed (from `e.get_response()`), how non-standard codes are introduced (subclassing `HTTPException`), and where routing-error handlers must be registered (app level). They are Flask-specific and complement the language-level exception design rules in `python/error-handling.md`.

## Rules

1. Register all error handlers inside `create_app` using `@app.errorhandler` or `app.register_error_handler`; never register them at module scope or outside the factory. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
2. Return the HTTP status code explicitly from every error handler (e.g. `return response, 404`); do not rely on Flask to infer it from the registered exception class. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
3. Construct JSON error responses by calling `e.get_response()` and overwriting `.data` and `Content-Type`, preserving the original status code and all Werkzeug-set headers. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
4. A broad `Exception` handler, if present, must immediately re-raise `werkzeug.exceptions.HTTPException` instances; prefer registering specific handlers over a catch-all. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
5. Subclass `werkzeug.exceptions.HTTPException` (setting `code` and `description`) for any non-standard HTTP status code; do not raise plain exceptions with ad-hoc codes. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/))
6. Register 404 and 405 (and other routing-layer) error handlers at the app level, not on a blueprint, because routing errors are raised before blueprint dispatch. ([errorhandling](https://flask.palletsprojects.com/en/stable/errorhandling/), [blueprints](https://flask.palletsprojects.com/en/stable/blueprints/))
