# Python CI/CD Analysis

> Read all GitHub Actions workflows and GitLab CI configuration for Python projects: matrix Python versions, lint/type/test/coverage gates, Docker setup, and pre-commit integration.

---

Goal: Read all CI/CD configuration files for single-package or
workspace/monorepo Python repositories.

IMPORTANT EXCLUSIONS:
- Do NOT recommend operational workflows (deployment monitoring, performance
  tracking, incident response)
- Do NOT recommend platform-specific deployment beyond basic Docker/container
- Focus ONLY on technical CI/CD (lint, type-check, test, coverage, security)
- Do NOT analyze, recommend, or consider CODEOWNERS files
- Do NOT analyze, recommend, or consider SECURITY.md files
- These are governance decisions, not technical CI/CD requirements

MONOREPO DETECTION:
- First detect repository structure: single package or workspace
- If workspace detected, check for per-package job matrix or separate
  workflow files per package
- Path-filter triggers (on: push: paths:) are especially important in monorepos

EFFICIENCY REQUIREMENTS:
- Target: <= 8 total tool calls for this entire analysis
- Read 3-5 workflow files per tool call using parallel reads
- Use grep -r to search across all workflow files at once
- Do NOT read workflow files one at a time
- Reference cached artifacts from previous steps when available

GITHUB ACTIONS ANALYSIS:

1. Workflow File Discovery:
   - List all .github/workflows/*.yml and .github/workflows/*.yaml files
   - Read each workflow completely
   - For each workflow, identify:
     * Trigger events (push, pull_request, schedule, workflow_dispatch)
     * Path filters (on: push: paths: — important for monorepos)
     * Python version matrix (strategy: matrix: python-version:)
     * Steps for lint, format check, type check, test, coverage, security, Docker

2. Python Version Matrix:
   - CRITICAL: CI should test against at least the minimum Python from
     requires-python AND the latest stable release
   - Single version only: note as gap (misses compatibility regressions)
   - Matrix with 2+ versions: GOOD
   - Check that matrix versions align with requires-python in pyproject.toml
   - fail-fast: false is recommended for matrices (see all failures, not just first)

3. Lint Gate:
   - ruff check . step: present / absent
   - ruff format --check . step: present / absent
   - CRITICAL: lint step must fail the job on any violation (exit code != 0)
   - Check --output-format flag for CI-friendly output (github or json)

4. Type-Check Gate:
   - mypy src/ or equivalent: present / absent
   - pyright src/ or basedpyright src/: present / absent
   - CRITICAL: type checking absent entirely is a significant gap
   - Check for --strict flag or equivalent config (see config-analysis)

5. Test + Coverage Gate:
   - pytest step: present / absent
   - Coverage collection: --cov, --cov-branch, --cov-report=xml
   - Coverage threshold enforcement: --cov-fail-under=<N> OR fail_under in
     .coveragerc / [tool.coverage.report]
   - CRITICAL: tests without a coverage threshold never block on coverage drops
   - Coverage artifact upload: actions/upload-artifact for coverage.xml / htmlcov

6. Pre-commit in CI:
   - pre-commit run --all-files step: present / absent
   - Alternative: use pre-commit.ci (saas) — check for .pre-commit-ci.yaml or
     presence in pre-commit.ci badge in README
   - Either approach is valid; absence means pre-commit hooks are only local

7. Security Scanning:
   - pip audit / uv pip audit: checks for known CVEs in installed packages
   - safety check: alternative to pip audit
   - bandit -r src/: SAST for common Python security issues (S rules in Ruff
     are the linter equivalent — check if both are present)
   - trivy or grype: container image scanning if Docker is used
   - dependency-review action: flags new vulnerable deps on PRs
   - CRITICAL: no security scanning at all is a notable gap

8. Build / Package:
   - python -m build or uv build step: present / absent
   - Upload to PyPI / artifact registry: note if present
   - Check for trusted publishing (pypa/gh-action-pypi-publish with OIDC)
     vs API token auth

GITLAB CI ANALYSIS (if .gitlab-ci.yml exists):

1. File Discovery:
   - .gitlab-ci.yml at root
   - Include directives referencing other files

2. Pipeline Stages:
   - stages: list and verify lint, test, coverage, security, build are present
   - Parallel matrix: parallel: matrix: for Python version testing

3. Python Version Matrix:
   - Same standards as GitHub Actions matrix

4. Cache Configuration:
   - pip cache: key and paths for pip or uv cache directories
   - Reduces install time on repeated runs

5. Coverage Integration:
   - coverage: regex in GitLab job for coverage badge
   - artifacts: reports: coverage_report: for merge request diff annotations

DOCKER CONFIGURATION:

1. Dockerfile analysis (if present):
   - Base image: prefer python:<version>-slim or python:<version>-alpine
     * Avoid python:latest (non-reproducible)
   - Multi-stage build:
     * Stage 1 (builder): install deps, compile if needed
     * Stage 2 (runtime): copy only installed packages and app code
     * Absence of multi-stage for apps > trivial size: flag
   - Non-root user:
     * RUN adduser --disabled-password appuser && USER appuser (or equivalent)
     * CRITICAL: running as root in production container
   - Dependency installation:
     * COPY pyproject.toml uv.lock ./ before COPY src/ ./
       (layer caching — dep layer only rebuilds on lockfile change)
     * pip install -r requirements.txt with --no-cache-dir flag
   - HEALTHCHECK instruction present / absent
   - WORKDIR set to /app or similar (not /)
   - EXPOSE port documented

2. .dockerignore analysis (if Dockerfile present):
   - __pycache__, *.pyc, *.pyo
   - .venv, venv, env
   - .git
   - .env (CRITICAL — secrets must not enter image)
   - tests/, docs/ (keep image lean)
   - .github/, .gitlab/

3. docker-compose.yml (if present):
   - app service configuration
   - Database service (postgres, mysql, redis)
   - Environment variable injection (env_file vs environment:)
   - Volume mounts for development
   - Network configuration
   - healthcheck on dependent services

VERIFICATION CHECKLIST:

Single package:
- [ ] .github/workflows/ or .gitlab-ci.yml exists
- [ ] At least one workflow/pipeline defined
- [ ] Lint step (ruff check) present and blocking
- [ ] Type-check step (mypy or pyright) present
- [ ] Test step (pytest) present
- [ ] Coverage threshold enforced (--cov-fail-under or fail_under config)
- [ ] Python version matrix with >= 2 versions (or justified single-version)
- [ ] Security scanning present (pip audit / bandit / trivy)
- [ ] Dockerfile exists (if distributed as container)
- [ ] .dockerignore exists (if Dockerfile exists)

Monorepo additions:
- [ ] Path filters on workflows to avoid unnecessary runs
- [ ] Per-package jobs or matrix covering all workspace members
- [ ] Affected-only strategy if using a tool that supports it

OUTPUT FORMAT:

- Repository structure: [Single-package / Workspace]
- CI platform: [GitHub Actions / GitLab CI / Both / None]
- Workflow files found: list with trigger events
- Python version matrix: [versions tested] or MISSING
- Lint gate (ruff check): [Present+blocking / Present-non-blocking / Missing]
- Format gate (ruff format --check): [Present / Missing]
- Type-check gate: [mypy-strict / mypy / pyright / Missing]
- Test gate: [Present / Missing]
- Coverage threshold: [value% enforced / present-not-enforced / Missing]
- Pre-commit in CI: [pre-commit run / pre-commit.ci / Missing]
- Security scanning: list tools found, or MISSING
- Docker: [Multi-stage+non-root / Single-stage / Missing]
- .dockerignore: [Present / Missing / N/A]
- Monorepo: path filters and per-package coverage (if applicable)
- Missing gates / gaps
- Recommendations
