### Python module structure — src/ layout, __init__/__all__ exports, layered/clean architecture, dependency inversion (ABC/Protocol, single composition root), no circular imports, absolute imports, pyproject.toml packaging (PEP 517/518/621, no setup.py), structured logging (structlog, no import-time config in libraries).
> Applies to: `**/*.py`
## Rules

1. Place all importable source under `src/<package_name>/`; never at the repo root. (Source: https://packaging.python.org/en/latest/discussions/src-layout-vs-flat-layout/)
2. Every `__init__.py` that re-exports symbols must define an explicit `__all__` list.
3. Use absolute imports exclusively — `from mypackage.x import Y`, never `from ..x import Y`. (Source: https://peps.python.org/pep-0008/)
4. Layer the codebase (API → Application → Domain → Infrastructure); inner layers must not import from outer layers. (Source: https://dev.to/markoulis/layered-architecture-dependency-injection-a-recipe-for-clean-and-testable-fastapi-code-3ioo)
5. Define layer boundaries as `ABC` subclasses or `Protocol` classes in the inner layer; outer layers provide the concrete implementation. (Source: https://arjancodes.com/blog/python-dependency-injection-best-practices/)
6. Assemble all concrete implementations in a single composition root — no application or domain module may instantiate infrastructure classes directly. (Source: https://arjancodes.com/blog/python-dependency-injection-best-practices/)
7. Circular imports are forbidden; extract shared concepts to a `types.py` or `interfaces.py` module that is imported by both sides.
8. Package exclusively with `pyproject.toml` (`[build-system]` PEP 518, `build-backend` PEP 517, `[project]` PEP 621); remove `setup.py` and `setup.cfg`. (Source: https://peps.python.org/pep-0517/ · https://peps.python.org/pep-0518/ · https://peps.python.org/pep-0621/)
9. In applications, configure structlog once at the entry point (`bootstrap.py` / `main.py`), never at import time. (Source: https://www.structlog.org/en/stable/logging-best-practices.html)
10. Libraries must never call `logging.basicConfig()`, `structlog.configure()`, or any logging-configuration function; obtain loggers with `structlog.get_logger(__name__)` only. (Source: https://www.structlog.org/en/stable/logging-best-practices.html)

## Rules

- **Use the `src/` layout.** Place all importable package code under `src/<package_name>/` so the installed package is tested, not the local source tree.
  Source: https://packaging.python.org/en/latest/discussions/src-layout-vs-flat-layout/

- **Declare public surfaces with `__all__`.** Every `__init__.py` that re-exports symbols must define `__all__` as an explicit list of strings. Unlisted names are internal and may change without notice.

- **Use absolute imports only.** Always write `from mypackage.services.user import UserService`, never `from ..services.user import UserService`. Absolute imports make the dependency graph readable and are required for reliable `src/` layout tooling.
  Source: https://peps.python.org/pep-0008/ (§ Imports)

- **Layer the architecture: API → Application → Domain → Infrastructure.** Dependencies point inward only — inner layers know nothing about outer layers.
  Source: https://dev.to/markoulis/layered-architecture-dependency-injection-a-recipe-for-clean-and-testable-fastapi-code-3ioo

- **Invert dependencies with `ABC` or `Protocol`.** Inner layers define an abstract interface; outer layers provide the concrete implementation. This keeps domain logic independent of frameworks and I/O drivers.
  Source: https://arjancodes.com/blog/python-dependency-injection-best-practices/
  Source: https://snyk.io/blog/dependency-injection-python/

- **Wire all concrete implementations in a single composition root.** One location (e.g. `src/<pkg>/bootstrap.py` or the DI container module) instantiates and assembles the full object graph. Application and domain modules never call constructors of infrastructure classes.
  Source: https://arjancodes.com/blog/python-dependency-injection-best-practices/

- **Eliminate circular imports by design.** If module A imports module B and B imports A, extract the shared concept into a third module (e.g. a `types.py` or `interfaces.py`) that neither A nor B imports from each other.

- **Package with `pyproject.toml` only — no `setup.py`.** Declare build-system requirements in `[build-system]` (PEP 518), use `build-backend` (PEP 517), and put all project metadata in `[project]` (PEP 621). Delete `setup.py`, `setup.cfg`, and `MANIFEST.in` if present.
  Source: https://peps.python.org/pep-0518/
  Source: https://peps.python.org/pep-0517/
  Source: https://peps.python.org/pep-0621/
  Source: https://packaging.python.org/en/latest/guides/writing-pyproject-toml/
  Source: https://packaging.python.org/en/latest/specifications/pyproject-toml/

- **Use structlog for structured logging in applications.** Configure it once at the application entry point (`bootstrap.py` / `main.py`), never at import time. Library code must accept a bound logger via dependency injection or use `structlog.get_logger()` without calling any configuration function.
  Source: https://www.structlog.org/en/stable/logging-best-practices.html
  Source: https://www.structlog.org/

- **Libraries must not configure logging.** A library that calls `logging.basicConfig()`, `structlog.configure()`, or any equivalent at import time corrupts the host application's logging setup. Libraries obtain a logger (`structlog.get_logger(__name__)`) and leave configuration entirely to the application.
  Source: https://www.structlog.org/en/stable/logging-best-practices.html

- Avoid placing package code at the repo root (`mypackage/` next to `tests/`) instead of under `src/` — this means `import mypackage` resolves to the local directory rather than the installed package, masking missing `__init__.py` files and import errors.
- Avoid exporting everything from `__init__.py` without an explicit `__all__`, making it impossible to distinguish the public API from internal helpers.
- Avoid using relative imports (`from .. import foo`) — they break under `src/` layout if a file is run directly and make refactoring harder.
- Avoid skipping `pyproject.toml` in favour of a bare `setup.py` or `setup.cfg`, which are legacy formats that do not support PEP 517 build isolation.
- Avoid importing a concrete infrastructure class (e.g. `PostgresRepository`) directly inside a domain service — this couples business logic to a driver and makes unit-testing require a live database.
- Avoid calling `structlog.configure()` or `logging.basicConfig()` inside a library module at module-level — the first import of the library silently changes the host app's logging.
- Avoid having more than one place that assembles the object graph, so the same interface is wired to different concrete implementations in different contexts (duplicated/conflicting composition roots).
- Avoid circular imports caused by placing shared types inline in a feature module that other modules also import — resolve by extracting shared types to a standalone `types.py` or `interfaces.py`.
