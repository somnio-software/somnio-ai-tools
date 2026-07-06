# Python Code Quality Analysis

> Analyze Ruff lint and format configuration (including S security rules), mypy strict or pyright/basedpyright type checking, and suppression comment density for Python projects.

---

Goal: Analyze static analysis tooling configuration and enforcement for
single-package or monorepo Python repositories.

IMPORTANT: Apply REASONABLE production standards. Focus on whether
tooling is configured correctly and suppressions are justified, not on
achieving a zero-findings baseline.

EFFICIENCY REQUIREMENTS:
- Target: <= 8 total tool calls for this entire analysis
- Read pyproject.toml, setup.cfg, and tox.ini in one parallel batch
- Use batch grep to scan all suppression comments across the codebase at once
- Pipe large outputs through `| head -60`

MONOREPO DETECTION:
- Detect repository structure: single package or monorepo (src-layout,
  packages/, apps/, or workspace members in pyproject.toml)
- If multiple packages exist, analyze each individually but keep
  per-package summaries concise

RUFF CONFIGURATION ANALYSIS:

1. Ruff Setup:
   - Check pyproject.toml [tool.ruff] section or ruff.toml
   - Verify ruff is listed in dev dependencies (pyproject.toml, requirements-dev.txt,
     or as a uv tool)
   - Check target-python or target-version alignment with
     .python-version / requires-python

2. Rule Selection:
   - Inspect [tool.ruff.lint] select / extend-select:
     * E, W — pycodestyle errors and warnings
     * F — pyflakes
     * I — isort (import ordering)
     * N — pep8-naming
     * UP — pyupgrade
     * B — flake8-bugbear
     * C4 — flake8-comprehensions
     * SIM — flake8-simplify
     * CRITICAL: S (flake8-bandit) — security rules; flag if absent
     * ANN — annotation checks (overlaps with mypy; optional but valuable)
   - Inspect ignore / extend-ignore list; flag broad ignores (e.g., ignoring
     all of S or all of ANN) as risks

3. Ruff Format:
   - Check [tool.ruff.format] section (or ruff format usage)
   - Verify quote-style, indent-style, line-length are explicitly set
   - Flag if black or autopep8 co-exists (dual formatter conflict)

4. Ruff Scripts / Pre-commit:
   - Check package.json / Makefile / justfile / tox.ini for lint and
     format commands
   - Check .pre-commit-config.yaml for ruff and ruff-format hooks
   - Verify CI runs ruff check --no-fix (fail on violations)

# NOQA SUPPRESSION ANALYSIS:

1. Density Check:
   - Run: grep -rn "# noqa" <src_dir> | wc -l
   - Flag if count exceeds 1 suppression per 100 lines of source code
   - List the top 5 most frequent suppression codes
   - Distinguish blanket `# noqa` (no code) from specific `# noqa: <code>`
   - Blanket suppressions are always a risk; flag each one

2. Justification Quality:
   - Check if suppressions in critical files (auth, payments, config) carry
     explanatory comments
   - Flag S-rule suppressions (security) as requiring explicit justification

MYPY / PYRIGHT CONFIGURATION ANALYSIS:

1. Tool Detection:
   - Check pyproject.toml for [tool.mypy] or [tool.pyright] / [tool.basedpyright]
   - Check for mypy.ini or .mypy.ini
   - If neither is present, flag as MISSING type checker

2. Mypy Strict Mode:
   - CRITICAL CHECK: verify `strict = true` OR all equivalent flags present:
     * disallow_untyped_defs = true
     * disallow_incomplete_defs = true
     * disallow_any_generics = true
     * warn_return_any = true
     * warn_unused_ignores = true
     * check_untyped_defs = true
     * no_implicit_optional = true
   - Verify python_version matches .python-version / requires-python
   - Check ignore_missing_imports usage; flag if set globally to true

3. Pyright / basedpyright Mode:
   - Check typeCheckingMode: strict is set
   - Check pythonVersion alignment
   - Verify pyrightconfig.json or [tool.pyright] section exists
   - Flag if typeCheckingMode is off or basic

4. TYPE_IGNORE SUPPRESSION DENSITY:
   - Run: grep -rn "# type: ignore" <src_dir> | wc -l
   - Flag if count exceeds 1 per 100 lines
   - List files with the highest concentration
   - type: ignore[<code>] is preferred over bare # type: ignore

5. Type Checker Scripts / CI:
   - Verify mypy or pyright is run in CI (tox, GitHub Actions, GitLab CI)
   - Check for --strict flag in CI invocation (mypy) or strict mode in config
   - Flag if type checking is only local (pre-commit) with no CI gate

AUTOMATED ENFORCEMENT:

1. Pre-commit Hooks:
   - Check .pre-commit-config.yaml for:
     * ruff (lint + format)
     * mypy or pyright
     * check-merge-conflict, end-of-file-fixer, trailing-whitespace
   - Verify hooks use pinned rev, not latest

2. CI Integration:
   - Verify lint, format-check, and type-check jobs run on every PR
   - Check for separate jobs vs. combined; separate is preferred for
     clear failure attribution
   - Flag if any quality gate is skipped on main/master pushes

DEPENDENCY SECURITY:

1. pip-audit / safety:
   - Check for pip-audit or safety in dev dependencies or CI
   - Note: Ruff S rules cover code-level security, not dependency CVEs

2. Dependabot / Renovate:
   - Check .github/dependabot.yml or renovate.json
   - Flag if neither is present

OUTPUT FORMAT:

Provide structured analysis:
- Repository structure: [Single package / Monorepo]
- Ruff configured: [Yes / Partial / No]
  * S (security) rules enabled: [Yes / No]
  * Format configured: [Yes / No]
  * Pre-commit hook: [Yes / No]
- Type checker: [mypy strict / mypy non-strict / pyright strict / pyright non-strict / None]
  * Version alignment: [OK / Mismatch / Unknown]
- Suppression density:
  * # noqa count: [N] across [LOC] lines ([ratio])
  * # type: ignore count: [N] across [LOC] lines ([ratio])
  * Blanket suppressions (no code): [N]
- CI quality gates: [lint / format / type-check each Yes or No]
- Dependency CVE scanning: [Yes / No]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Ruff configured with S rules and format; ruff in CI and pre-commit
- mypy strict or pyright strict in CI
- Suppression density < 1 per 100 lines, specific codes only
- All three quality gates (lint, format, type) in CI
- Dependency CVE scanning present

Fair (70-84):
- Ruff configured but S rules missing or ignored broadly
- Type checker present but not strict mode
- Suppression density slightly elevated (1-3 per 100 lines)
- Some CI gates missing (e.g., format check absent)

Weak (0-69):
- Ruff absent or minimal rule set
- No type checker configured
- Suppression density > 3 per 100 lines or many blanket suppressions
- No CI lint or type-check gates
- No security rule coverage (no S rules, no pip-audit)
