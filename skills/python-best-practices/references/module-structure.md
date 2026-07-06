# Python Module Structure Analysis

> Analyze module layout, import hygiene, layered architecture, dependency inversion, packaging, and logging configuration based on somnio-software standards.

---

Goal: Analyze the structural organization of the Python codebase —
directory layout, public API declarations, layer boundaries, dependency
direction, import style, packaging, and logging setup.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/python/module-structure.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/python/module-structure.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **`src/` Layout**:
    *   Verify all importable package code lives under `src/<package_name>/`.
    *   Flag packages placed at the repo root (next to `tests/`) instead of
        under `src/`.

2.  **`__all__` Declarations**:
    *   Check every `__init__.py` that re-exports symbols for an explicit
        `__all__` list.
    *   Flag `__init__.py` files that expose symbols via import without
        declaring `__all__`.

3.  **Absolute Imports**:
    *   Flag any relative imports (`from .. import`, `from . import`).
    *   Verify all imports use the fully qualified package path
        (e.g. `from mypackage.services.user import UserService`).

4.  **Layer Boundaries and Dependency Direction**:
    *   Map the codebase into layers (API → Application → Domain →
        Infrastructure).
    *   Flag inner-layer modules that import from outer layers (e.g. a domain
        service importing a concrete repository class).
    *   Verify that inner layers depend only on abstractions (`ABC` subclasses
        or `Protocol` classes) defined within the same or inner layer.

5.  **Dependency Inversion**:
    *   Check that interfaces/protocols for infrastructure dependencies are
        defined in the inner layer.
    *   Flag concrete infrastructure classes (e.g. `PostgresRepository`)
        instantiated directly inside application or domain modules.

6.  **Single Composition Root**:
    *   Identify where concrete implementations are assembled (e.g.
        `bootstrap.py`, a DI container module).
    *   Flag duplicate or scattered wiring of the same interface to different
        concrete implementations across multiple locations.

7.  **Circular Imports**:
    *   Identify circular dependencies between modules.
    *   Verify circular import issues are resolved by extracting shared types
        to a standalone `types.py` or `interfaces.py`.

8.  **Packaging (`pyproject.toml`)**:
    *   Confirm `pyproject.toml` is present with `[build-system]` (PEP 518),
        `build-backend` (PEP 517), and `[project]` metadata (PEP 621).
    *   Flag the presence of `setup.py`, `setup.cfg`, or `MANIFEST.in`.

9.  **Structured Logging**:
    *   Verify applications configure structlog once at the entry point
        (`bootstrap.py` / `main.py`) and never at import time.
    *   Flag any module-level calls to `logging.basicConfig()`,
        `structlog.configure()`, or equivalent in library code.
    *   Confirm libraries obtain loggers with `structlog.get_logger(__name__)`
        without calling any configuration function.

OUTPUT FORMAT:
*   **Overview**: Total files analyzed, quality score (1-10).
*   **Violations**: List specific file paths and lines violating the above
    rules.
    *   Format: `` `path/to/file.py:XX` — [Issue] ``
*   **Compliance**: Highlight good examples found in the codebase.
*   **Recommendations**: Specific refactoring suggestions for violations.
