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
