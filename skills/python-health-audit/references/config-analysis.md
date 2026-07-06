# Python Configuration Analysis

> Read and analyze Python project configuration: pyproject.toml tool sections, lockfiles, dependency pinning strategy, and pre-commit hooks for single-package or workspace repos.

---

Goal: Read and analyze Python project configuration files for single-package
or workspace/monorepo repositories.

EFFICIENCY REQUIREMENTS:
- Target: <= 8 total tool calls for this entire analysis
- Read multiple config files per tool call using parallel reads (3-5 files per response)
- Use grep -r to scan across files rather than reading each one individually
- Reference cached artifacts from previous steps when available

MONOREPO DETECTION:
- First detect repository structure: single package or workspace
  ([tool.uv.workspace], [tool.hatch.workspace], packages/ with multiple
  pyproject.toml files)
- If workspace detected, analyze root pyproject.toml AND each member's
  pyproject.toml separately

PYPROJECT.TOML ANALYSIS:

1. [project] Table (PEP 621):
   - name and version present
   - requires-python: check for a minimum constraint (e.g. ">=3.11")
     * CRITICAL: missing requires-python means any Python version is accepted
   - dependencies: list runtime deps — check for unpinned specs (bare package
     names with no version constraint)
   - optional-dependencies: check [project.optional-dependencies] groups
     (dev, test, docs, lint, etc.)

2. [tool.uv] — uv package manager:
   - dev-dependencies under [tool.uv.dev-dependencies]
   - [tool.uv.workspace] for workspace repos
   - Check uv.lock exists alongside pyproject.toml (REQUIRED for reproducible installs)
   - Verify uv.lock is committed to VCS (not in .gitignore)

3. [tool.poetry] — Poetry:
   - version, python constraint under [tool.poetry.dependencies]
   - [tool.poetry.dev-dependencies] or [tool.poetry.group.*.dependencies]
   - Check poetry.lock exists and is committed

4. [tool.pdm] — PDM:
   - Check pdm.lock exists and is committed

5. pip / requirements.txt:
   - Check for requirements.txt, requirements-dev.txt, requirements-lock.txt
   - CRITICAL: requirements.txt without pinned versions (== only; >= is unpinned)
   - Check for pip-tools: requirements.in -> requirements.txt workflow
   - Note if no lockfile mechanism exists at all

DEPENDENCY PINNING STRATEGY:

Classify each discovered dependency set:

- Fully pinned: every dep uses == (or uv.lock / poetry.lock / pdm.lock present)
  -> GOOD for applications; NOTE for libraries (too restrictive)
- Range-pinned: deps use >= and < or ~= (compatible release)
  -> ACCEPTABLE for libraries; WEAK for applications without a lockfile
- Unpinned: bare package names or >= with no upper bound and no lockfile
  -> CRITICAL for applications; flag for libraries
- Mixed: some pinned, some not — flag the unpinned subset

TOOL CONFIGURATION SECTIONS:

1. [tool.ruff] — Ruff linter + formatter:
   - line-length
   - target-version (must match requires-python)
   - [tool.ruff.lint] select: check for security rules (S), complexity (C90),
     import sort (I), pep8-naming (N), type annotations (ANN), bugbear (B)
   - [tool.ruff.lint] ignore: note any suppressed rules
   - [tool.ruff.format] settings
   - CRITICAL: absence of S (flake8-bandit) security rules in select

2. [tool.mypy] — mypy type checker:
   - strict = true (PREFERRED)
   - disallow_untyped_defs, disallow_incomplete_defs
   - warn_return_any, warn_unused_ignores
   - per-module [[tool.mypy.overrides]] ignores: list any broad ignores
   - python_version: must match requires-python major.minor

3. [tool.pyright] or [tool.basedpyright] — Pyright / basedpyright:
   - typeCheckingMode: strict / basic / off
   - pythonVersion: must match requires-python
   - Note: basedpyright is a stricter fork — preferred

4. [tool.pytest.ini_options] — pytest:
   - testpaths: list of directories to search
   - addopts: check for --strict-markers, -ra, --tb=short
   - markers: registered custom markers (prevents PytestUnknownMarkWarning)
   - filterwarnings: error conversions

5. [tool.coverage.run] and [tool.coverage.report]:
   - source or source_pkgs
   - branch = true (branch coverage)
   - omit patterns
   - [tool.coverage.report] fail_under threshold
   - CRITICAL: absence of fail_under means coverage never blocks CI

6. [tool.hatch] — Hatch:
   - [tool.hatch.envs.*] for environment management
   - [tool.hatch.build.targets.*] for build configuration

PRE-COMMIT CONFIGURATION:

File: .pre-commit-config.yaml

1. Presence check:
   - File exists: note
   - File missing: note as gap (pre-commit prevents committing broken code)

2. Hook inventory (if file exists):
   - pre-commit/pre-commit-hooks: check for trailing-whitespace,
     end-of-file-fixer, check-yaml, check-toml, check-merge-conflict,
     debug-statements
   - astral-sh/ruff-pre-commit: ruff --fix and ruff-format hooks
   - pre-commit mirrors-mypy or local mypy hook
   - detect-secrets or gitleaks: secret scanning hooks
   - Note any hooks that duplicate CI checks (good: fast feedback loops)

3. Hook versions:
   - Check rev pinned to a tag or commit hash (not a branch)
   - Check for rev: HEAD or rev: main — CRITICAL: non-reproducible

4. default_language_version:
   - python should be explicit (e.g. python3.11) to match project Python

ENVIRONMENT AND SECRETS:

1. .env files:
   - .env should NOT be committed; verify it is in .gitignore
   - .env.example should exist with all required variable names (values redacted)

2. python-dotenv / pydantic-settings:
   - Check if project uses python-dotenv or pydantic-settings for env loading
   - pydantic-settings (v2): look for BaseSettings subclass with model_config
   - Check for typed settings class vs raw os.getenv() calls scattered in code

3. Secret management:
   - AWS Secrets Manager, GCP Secret Manager, HashiCorp Vault, Azure Key Vault
     integrations: note if present
   - Direct os.getenv("SECRET_KEY") in non-settings files: flag each occurrence

SCRIPT ANALYSIS:

From [project.scripts] and pyproject.toml [tool.*] scripts sections:
- Build: e.g., uv build, hatch build, python -m build
- Dev server: e.g., uvicorn src.app:app --reload, fastapi dev
- Lint: ruff check ., ruff format --check .
- Type check: mypy src/ or pyright src/
- Test: pytest
- Coverage: pytest --cov
- Migrations: alembic upgrade head, django migrate
- Docs: mkdocs serve, sphinx-build

OUTPUT FORMAT:

- Repository structure: [Single-package / Workspace (tool)]
- Python version constraint: [exact value or MISSING]
- Package manager + lockfile: [uv+uv.lock / poetry+poetry.lock / pip+requirements / none]
- Lockfile committed: [Yes / No / N/A]
- Dependency pinning: [Fully pinned / Range-pinned / Unpinned / Mixed — list gaps]
- Ruff configuration: [Present / Missing] — note missing rule categories
- Type checker: [mypy strict / mypy non-strict / pyright strict / pyright basic / Missing]
- pytest configuration: [Present / Missing] — note missing options
- Coverage fail_under: [value or MISSING]
- pre-commit: [Present / Missing] — list hooks found
- .env.example: [Present / Missing]
- Settings management: [pydantic-settings / python-dotenv / raw os.getenv / None]
- Per-workspace-member diffs (if monorepo)
- Risks identified
- Recommendations
