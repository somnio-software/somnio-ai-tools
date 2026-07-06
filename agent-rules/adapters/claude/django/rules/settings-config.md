### Django settings configuration — DEBUG flag, secrets from env, ALLOWED_HOSTS, settings split by environment, static/media roots, persistent connections, deployment checklist. Applies to settings files.
> Applies to: `**/settings/*.py`
# Django Settings & Configuration

Framework-specific configuration rules for Django settings files. Generic secret-loading patterns (e.g. pydantic-settings BaseSettings) are covered in `python/data-validation.md` — reference that file when adding schema-validated env parsing on top of `django-environ`.

---

## Rules

1. `DEBUG` must be `False` in every production settings file; drive it from an env var (`DJANGO_DEBUG`) in the base file so it is never hardcoded to `True` in any deployable module. ([deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))
2. All secrets (`SECRET_KEY`, DB password, third-party keys) must be read from environment variables at import time so the process fails immediately with a clear error if a var is missing. Never commit secret values. ([deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/) · [settings best practices](https://djangostars.com/blog/configuring-django-settings-best-practices/))
3. Populate `SECRET_KEY_FALLBACKS` during key rotation; remove the old key only after all existing sessions have been invalidated or naturally expired. ([deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))
4. `ALLOWED_HOSTS` must list only the exact hostnames the application serves; wildcards and empty lists are forbidden in production settings. ([deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))
5. Split settings into at minimum `base.py` + per-environment files (`local.py`, `production.py`); select the module via `DJANGO_SETTINGS_MODULE`. No inline `if ENV == 'prod'` branching inside a single file. ([settings best practices](https://djangostars.com/blog/configuring-django-settings-best-practices/))
6. `STATIC_ROOT` must be set in production settings and point to a filesystem path outside the project source; run `collectstatic` during the deploy pipeline, not at startup. ([deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))
7. Configure `CONN_MAX_AGE` to a positive integer (e.g. `60`) in production settings; add `CONN_HEALTH_CHECKS = True` when using connection poolers or long-running async workers. ([deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))

## Rules

- **Never commit `DEBUG=True` to production.** Set `DEBUG=False` in every environment-specific settings file that is deployed; use an env var (`DJANGO_DEBUG=False`) to override the base value rather than hardcoding. ([deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))

- **Load all secrets from environment variables.** `SECRET_KEY`, database passwords, third-party API keys, and OAuth credentials must never appear in version-controlled settings files. Use `django-environ` (`env('SECRET_KEY')`) or `os.environ[]` with a mandatory key so the app fails fast if the var is missing. For `SECRET_KEY` rotation keep `SECRET_KEY_FALLBACKS` populated until all sessions are cycled. ([deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/) · [settings best practices](https://djangostars.com/blog/configuring-django-settings-best-practices/))

- **Set `ALLOWED_HOSTS` explicitly.** In production this must list only the actual hostnames/IPs the app responds to. An empty list or wildcard (`['*']`) disables host-header validation and enables DNS-rebinding attacks. ([deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))

- **Split settings into `base.py` + per-environment overrides** selected by an env var (e.g. `DJANGO_SETTINGS_MODULE=myproject.settings.production`). Common patterns: `base.py` / `local.py` / `production.py` / `test.py`. Never litter a single `settings.py` with `if os.environ.get('ENV') == 'prod':` branches — use separate files. ([settings best practices](https://djangostars.com/blog/configuring-django-settings-best-practices/))

- **Configure `STATIC_ROOT` and `STATIC_URL` for `collectstatic`.** `STATIC_ROOT` is the filesystem path where `collectstatic` writes assets for the web server to serve; it must be set in production settings. Do not serve static files via `runserver` in production. ([deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))

- **Treat uploaded media as untrusted.** `MEDIA_ROOT`/`MEDIA_URL` should point to storage isolated from the app (separate subdomain, object storage, or a restricted filesystem path) so user uploads cannot be executed or served with elevated trust. ([deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))

- **Enable persistent database connections.** Set `CONN_MAX_AGE` to a non-zero value (e.g. `60` seconds) in production to avoid a new TCP/TLS handshake on every request. Pair this with `CONN_HEALTH_CHECKS = True` if you use long-lived workers. ([deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))

- **Enable the cached template loader in production.** Add `django.template.loaders.cached.Loader` wrapping the filesystem and app-directories loaders so templates are compiled once, not on every render. ([deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))

- **Run `manage.py check --deploy` before every deploy.** This built-in command audits `ALLOWED_HOSTS`, HTTPS/cookie flags, `DEBUG`, `SECRET_KEY` strength, and more. Treat any output as a blocking issue. ([deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))

---

- Avoid committing `SECRET_KEY` or database passwords directly in `settings.py` or `.env` files that are tracked by git.
- Avoid using a single settings file for all environments with inline `if`-branch logic — makes diffs noisy and secrets easy to leak.
- Avoid leaving `DEBUG=True` in a production-oriented settings file, exposing full tracebacks and disabling security checks.
- Avoid wildcard or empty `ALLOWED_HOSTS` in production, bypassing Django's host-header guard.
- Avoid starting the app with `runserver` in production — it is a single-threaded development server with no static-file serving and no hardening.
- Avoid forgetting `STATIC_ROOT` so `collectstatic` has nowhere to write, or missing `STATICFILES_STORAGE` for fingerprinted filenames.
- Avoid not rotating `SECRET_KEY` when it is suspected of being compromised, and not using `SECRET_KEY_FALLBACKS` to keep existing sessions valid during the rotation window.
- Avoid setting `CONN_MAX_AGE` without `CONN_HEALTH_CHECKS`, causing silent stale-connection errors under pgBouncer or long-idle workers.

---

---
