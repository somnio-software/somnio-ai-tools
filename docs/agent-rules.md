[Home](../README.md) > Agent Rules

# Agent Rules

Agent rules are coding standards for NestJS, Flutter, React, Python, FastAPI, Django, and Flask that are automatically applied by your AI coding agent in every session. They are written once in `agent-rules/rules/` and compiled into agent-specific adapters for Claude Code, Cursor, Windsurf, Copilot, Codex, and Antigravity.

---

## How It Works

Rules live in `agent-rules/rules/` and are the single source of truth. Running the generation script produces all adapters:

```
agent-rules/
├── rules/            ← edit here
│   ├── django/
│   ├── fastapi/
│   ├── flask/
│   ├── flutter/
│   ├── functions/
│   ├── nestjs/
│   ├── python/
│   ├── react/
│   └── typescript/
└── adapters/         ← never edit directly, auto-generated
    ├── antigravity/
    ├── claude/
    ├── codex/
    ├── copilot/
    ├── cursor/
    └── windsurf/
```

---

## Installation via CLI

Install rules for your agent — globally (applied to all projects) or locally (current project only):

```bash
somnio rules install                          # interactive: detect agents + choose scope
somnio rules install --agent claude --global  # Claude Code, global
somnio rules install --agent cursor --project # Cursor, current project
somnio rules install --all --global           # all detected agents, global
somnio rules status                           # check what is installed
```

### Install paths per agent

| Agent | Global | Project |
|:------|:-------|:--------|
| Claude Code | `~/.claude/CLAUDE.md` | `./CLAUDE.md` |
| Cursor | `~/.cursor/rules/` | `./.cursor/rules/` |
| Windsurf | `~/.windsurfrules` | `./.windsurfrules` |
| GitHub Copilot | — | `./.github/copilot-instructions.md` |
| OpenAI Codex | — | `./AGENTS.md` |
| Antigravity | — | `./rules/` |

> Global installs wrap the content in `<!-- BEGIN/END SOMNIO RULES -->` markers so updates are idempotent and existing file content is preserved.

---

## Available Rules

### NestJS

| Rule | Purpose |
|:-----|:--------|
| `dto-validation` | DTOs with class-validator, class-transformer, and Swagger |
| `service-patterns` | Service layer: RO-RO pattern, transactions, validation |
| `controller-patterns` | Controllers: guards, Swagger docs, response formatting |
| `repository-patterns` | Repository pattern: parameterized queries, soft deletes |
| `testing-unit` | Unit tests: mocking, structure, Arrange-Act-Assert |
| `testing-integration` | Integration tests: real database, isolation |
| `error-handling` | Exception filters, error enums, consistent responses |
| `module-structure` | Module organization, DI, barrel exports |
| `typescript` | TypeScript guidelines, naming conventions |

### Flutter

| Rule | Purpose |
|:-----|:--------|
| `architecture` | Layered architecture: Data, Repository, BLoC, Presentation |
| `best-practices` | General best practices: SOLID, state, navigation, theming |
| `bloc-test` | BLoC test structure and patterns |
| `code-patterns` | Dart/Flutter implementation patterns: null safety, async, const, routing, serialization |
| `layout` | Layout patterns: Row/Column, Stack, Overlay, scrolling, LayoutBuilder |
| `testing` | Testing best practices: mocking, matchers, grouping |
| `ui-theming` | UI theming, Material 3, ThemeData, ColorScheme, ThemeExtension, accessibility |

### React

| Rule | Purpose |
|:-----|:--------|
| `component-architecture` | Feature-based folder structure, naming, and composition patterns |
| `hooks-patterns` | Rules of Hooks, custom hook design, useCallback/useMemo stability |
| `performance` | React.memo, code splitting, list virtualization, anti-patterns |
| `state-management` | useState/Context/Zustand/TanStack Query decision guide |
| `testing` | RTL queries, AAA patterns, renderHook, async testing |
| `typescript` | Strict config, prop interfaces, generic components, no `any` |

### Python

| Rule | Purpose |
|:-----|:--------|
| `typing` | Type hints everywhere; modern `list[int]`/`X \| None` (3.10+); `Protocol` structural typing; pyright/basedpyright strict; `py.typed` (PEP 561) |
| `code-style` | PEP 8 + Ruff (lint/format/import-sort) as CI gate; line length 88; naming; 3-group sorted absolute imports; docstrings (PEP 257 + Google sections) |
| `function-design` | Single responsibility; early returns; pure functions / side-effect isolation; dataclasses; keyword-only args |
| `data-validation` | Pydantic models at input boundaries; field validators/constraints; no unvalidated `dict`; typed response models; configuration via pydantic-settings `BaseSettings` |
| `error-handling` | EAFP over LBYL; narrowest `except`; custom exception hierarchy; translate at boundaries; never swallow; no control-flow-by-exception |
| `module-structure` | `src/` layout; `__init__`/`__all__` exports; layered/clean architecture + dependency-inversion; no circular imports; packaging (`pyproject.toml` PEP 517/518/621); structured logging |
| `testing-unit` | pytest plain `assert`; `test_<unit>_<scenario>_<expected>` naming; fixtures + `conftest.py`; `parametrize` with `ids`; `pytest.raises(match=...)`; `mocker`/autospec; Hypothesis |
| `testing-integration` | DB/fixture teardown & isolation; unique test data; `--strict-markers`; branch coverage (`--cov-branch`) + `fail_under` gate |

### FastAPI

> These rules cover FastAPI-specific concerns only and layer on top of the `python` stack rules for language-level guidance (typing, style, error handling, testing).

| Rule | Purpose |
|:-----|:--------|
| `project-structure` | Domain-package layout + `APIRouter` modularization; thin handlers delegating to a service layer; routers assembled in `main.py` |
| `dependency-injection` | `Depends`, sub-dependency composition, per-request caching, `yield` setup/teardown with re-raise discipline |
| `request-response-schemas` | Pydantic input models, dedicated `response_model`/return-type output models, field filtering as a security boundary |
| `async-and-background-tasks` | `async def` vs `def` handler choice, never blocking the event loop, `run_in_threadpool`, `BackgroundTasks` vs a real task queue |
| `exception-handling` | `raise HTTPException`, centralized `@app.exception_handler`, Starlette `HTTPException` override, domain→HTTP translation |
| `data-and-config` | Session-per-request `yield` dependency, table-model vs API-schema separation, `pydantic-settings` via `@lru_cache` dependency, `TestClient`/`AsyncClient` + `dependency_overrides` |

### Django

> These rules cover Django-specific concerns only and layer on top of the `python` stack rules for language-level guidance (typing, style, error handling, testing).

| Rule | Purpose |
|:-----|:--------|
| `models-orm` | Models, queryset optimization (`select_related`/`prefetch_related`, N+1), bulk ops, DB-level evaluation, indexes, `Meta` constraints |
| `migrations` | Schema vs data migrations, historical-model access in `RunPython`, reversibility, cross-app dependencies |
| `views-serializers` | DRF views/viewsets/routers + serializers; thin views; explicit `fields`; input/output separation; per-action scoping |
| `service-layer` | HackSoft services/selectors; business-logic placement; model `clean()`/`full_clean()`; per-app `services.py`/`selectors.py`/`apis.py`; Celery as an API layer |
| `settings-config` | Settings split (`base`/env), `DEBUG=False`, env-loaded secrets, `ALLOWED_HOSTS`, static/media, persistent connections, `check --deploy` |
| `security` | CSRF, template XSS/autoescape, ORM vs raw SQL, clickjacking, HTTPS/HSTS/secure cookies, host header, upload hardening |
| `testing` | pytest-django `django_db` marking, transaction-rollback isolation, `factory_boy` over fixtures, signal muting, service-layer focus |

### Flask

> These rules cover Flask-specific concerns only and layer on top of the `python` stack rules for language-level guidance (typing, style, error handling, testing).

| Rule | Purpose |
|:-----|:--------|
| `application-factory` | `create_app` factory + installable package layout; never a module-level global `app` |
| `extensions-and-database` | Module-scope extension objects bound via `init_app`; Flask-SQLAlchemy session/context/migration rules |
| `blueprints-structure` | Feature blueprints, namespaced endpoints, blueprint-local templates/static, registration in the factory |
| `configuration` | UPPERCASE config, `from_object`/config-class hierarchy, `SECRET_KEY`/secrets, `--debug` flag, instance folder, cookie hardening |
| `app-request-context` | `current_app`/`g` proxies vs importing `app`; per-request lifetime; pushing contexts; thin views |
| `error-handling` | Error handlers in the factory, explicit status codes, JSON-API error shape, blueprint-handler caveats |
| `testing` | `conftest.py` factory fixtures, `test_client`/`test_cli_runner`, `TESTING=True`, JSON/session/context testing |

---

## Editing Rules

```bash
# 1. Edit a rule
vim agent-rules/rules/nestjs/service-patterns.md

# 2. Regenerate all adapters
cd agent-rules && python3 scripts/generate.py

# Or regenerate a specific adapter
python3 scripts/generate.py --only claude
python3 scripts/generate.py --only cursor
python3 scripts/generate.py --only copilot
python3 scripts/generate.py --only windsurf
python3 scripts/generate.py --only codex
python3 scripts/generate.py --only antigravity
```

---

## Contributing

See the [Contributing Guide](../CONTRIBUTING.md#contributing-agent-rules) for instructions on editing rules, adding new rules, and adding support for new agents.
