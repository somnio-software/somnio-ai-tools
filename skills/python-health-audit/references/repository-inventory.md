# Python Repository Inventory

> Detect repository structure, package layout, entry points, and framework for Python projects. Validates src-layout vs flat-layout, monorepo patterns, and package boundaries.

---

Goal: Detect repository structure, package layout, and entry-point
organization for single-package or monorepo Python repositories.

EFFICIENCY REQUIREMENTS:
- Target: <= 6 total tool calls for this entire analysis
- Use batch find/ls commands to inventory directory structure in one pass
- Count files with find + wc rather than reading them individually
- Read multiple manifests per tool call using parallel reads
- Do NOT open individual source files to count lines — use find + wc -l

IMPORTANT: Apply REASONABLE production standards. Focus on
clarity and maintainability, not perfection.

REPOSITORY STRUCTURE DETECTION:

1. Project Type Detection:
   - Single-package repo: one pyproject.toml (or setup.cfg/setup.py) at root
   - Monorepo detected if ANY of the following exist:
     * packages/ or libs/ directory containing multiple subdirs with their own pyproject.toml
     * apps/ directory with per-app pyproject.toml
     * uv workspaces ([tool.uv.workspace]) in root pyproject.toml
     * hatch workspaces ([tool.hatch.workspace]) in root pyproject.toml
     * poetry workspaces (not official, but packages = [...] in [tool.poetry])
   - If monorepo detected:
     * NOTE in report: "Workspace/monorepo structure detected"
     * FOCUS analysis on the primary application package
     * Don't penalize for workspace overhead
     * Suggest analyzing each package separately if needed

2. Layout Detection:
   - src-layout (PREFERRED):
     * src/<package_name>/__init__.py exists
     * Protects against accidental imports from working directory
   - Flat-layout:
     * <package_name>/__init__.py at root (no src/ prefix)
     * Note as acceptable for small projects; recommend src-layout for libraries
   - Namespace packages:
     * Directories without __init__.py — note if intentional

3. Entry Point Detection:
   - Console scripts: [project.scripts] or [tool.poetry.scripts] in pyproject.toml
   - Module entry: if __name__ == "__main__" in top-level or src/<pkg>/__main__.py
   - WSGI/ASGI callable: e.g., app = FastAPI(), application = Django WSGI
   - CLI framework: typer, click, argparse detected from imports
   - List all discovered entry points with their locations

FRAMEWORK DETECTION:

Scan pyproject.toml dependencies and top-level imports for:

1. Web Frameworks:
   - FastAPI: look for fastapi in dependencies; check for APIRouter, @app.get patterns
   - Django: look for Django in dependencies; check for INSTALLED_APPS, manage.py
   - Flask: look for flask in dependencies; check for Flask(), Blueprint
   - Starlette: standalone (not via FastAPI)
   - Litestar / Sanic / aiohttp: note if detected

2. CLI:
   - typer, click, argparse, rich.cli

3. Task / Worker:
   - Celery, dramatiq, arq, rq

4. Data / ML:
   - pandas, numpy, scikit-learn, torch, transformers (note as data/ML project)
   - Affects testing expectations (property-based and data-driven tests more relevant)

5. None / Library:
   - No HTTP or CLI framework: classify as pure library

PACKAGE SIZE ANALYSIS:

For each top-level package (or workspace member):
1. Count Python source files:
   find src/<pkg> -name "*.py" | wc -l
2. Count lines of Python:
   find src/<pkg> -name "*.py" | xargs wc -l | tail -1
3. Classify:
   - Small (< 50 files): single responsibility likely — note as healthy
   - Medium (50-200 files): check for clear subpackage organization
   - Large (> 200 files): flag if subpackages lack clear boundaries

SUBPACKAGE ORGANIZATION:

1. Check for logical subpackage grouping:
   - routes/ or api/ (HTTP layer)
   - services/ or domain/ (business logic)
   - models/ or schemas/ (data shapes)
   - db/ or repositories/ or dal/ (data access)
   - config/ or settings/ (configuration)
   - utils/ or helpers/ (shared utilities)
   - tests/ or test/ (co-located or top-level)

2. Depth warning: more than 4 levels of nesting is a smell — note it

CONFIGURATION / PROJECT MANIFEST:

1. pyproject.toml (PREFERRED):
   - Check [project] table for name, version, requires-python
   - Note if only [tool.*] sections exist with no [project] (non-packaging use)
2. Legacy manifests (flag as migration candidates):
   - setup.cfg + setup.py combination
   - setup.py only
3. Missing manifest:
   - No pyproject.toml or setup.cfg: CRITICAL — unfindable package

OUTPUT FORMAT:

Provide structured analysis:
- Project type: [Single-package / Workspace monorepo (tool)]
- If monorepo: list member packages and primary focus
- Layout: [src-layout / flat-layout / namespace packages]
- Entry points: list with locations and types
- Framework: [FastAPI / Django / Flask / CLI / Library / Data-ML / None detected]
- Package size summary (files, lines per package)
- Subpackage organization: [Clear / Partial / Absent]
- Manifest type: [pyproject.toml / setup.cfg / setup.py / missing]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- src-layout with clear subpackage boundaries
- pyproject.toml with [project] table
- Entry points clearly declared
- Logical subpackage grouping
- Package size appropriate to responsibility

Fair (70-84):
- Flat-layout but otherwise organized
- Mix of pyproject.toml + legacy files (migration in progress)
- Entry points present but undeclared
- Some subpackage organization

Weak (0-69):
- No manifest or setup.py only
- No layout convention — imports work only from repo root
- No identifiable entry points
- Flat soup of .py files at root
- Package too large with no subpackage structure

IMPORTANT: Be practical. A small utility library in flat-layout with a
clear README is not weak — weight the finding against project size and purpose.
