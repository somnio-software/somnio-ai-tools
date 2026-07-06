---
description: Organizing Flask apps into feature blueprints with namespaced endpoints and blueprint-local templates and static files. Use when structuring routes into modules, building URL names, or registering blueprints in the factory.
globs: **/*.py
alwaysApply: false
---

## Best Practices

- Factor larger applications into feature-oriented `Blueprint` objects and register them in `create_app` with a `url_prefix` so each feature owns a distinct URL namespace. ([blueprints])
- Build URLs with the blueprint name as a prefix: `url_for('admin.index')` from outside the blueprint, or the relative shorthand `url_for('.index')` from a view inside the same blueprint. ([blueprints])
- Ship blueprint-local templates under `<blueprint>/templates/<blueprint_name>/` and static files under `<blueprint>/static/`. App-level templates (in the application's `templates/` folder) always take precedence over blueprint-level templates when names collide. ([blueprints])
- Use `current_app` inside blueprint views instead of importing the application object; under the factory pattern there is no importable app-level `app` variable. ([appfactories], [appcontext])
- Register all blueprints inside `create_app` after config and extensions have been initialised, then `return app`. ([factory], [blueprints])

## Common Mistakes

- Expecting a blueprint-registered `404` or `405` error handler to fire: blueprint error handlers only handle errors raised *within that blueprint's views*; routing-level errors (no route matched, method not allowed) are always dispatched to the app-level handler. Register 404/405 handlers on the application, not on a blueprint. ([blueprints], [errorhandling])
- Relying on a blueprint's `static_folder` route when no `url_prefix` is set: without a prefix the static endpoint URL collides with the app-level `/static/` endpoint, producing an `AssertionError` at registration time. ([blueprints])
- Treating a blueprint as a fully independent WSGI application that can be mounted and unmounted without re-registering: a blueprint is *not* a sub-application; it has no app context of its own and cannot be detached from the app it was registered with. ([blueprints])
- Importing the application instance (`from myapp import app`) inside a blueprint module; this creates a circular import and breaks the factory pattern. Use `current_app` instead. ([appfactories], [appcontext])

## Purpose

Feature blueprints let a Flask application be split into cohesive modules — each with its own views, URL prefix, templates, and static files — without creating separate WSGI apps. Registering blueprints in the application factory keeps the module structure decoupled from the app-construction lifecycle, making the application easier to test, extend, and maintain.

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
