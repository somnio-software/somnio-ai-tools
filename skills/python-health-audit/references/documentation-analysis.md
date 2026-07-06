# Python Documentation Analysis

> Review README completeness, docstring coverage and quality, Sphinx or MkDocs setup, and type hints as machine-readable documentation. Excludes governance, operational runbooks, and deployment docs.

---

Goal: Assess technical documentation quality — project setup,
API surface, and inline code documentation — for single-package
or monorepo Python repositories.

IMPORTANT EXCLUSIONS:
- Do NOT check for or recommend operational runbooks, deployment
  procedures, monitoring playbooks, or on-call guides
- Do NOT recommend CODEOWNERS or SECURITY.md — governance decisions
- Focus ONLY on technical setup documentation, public API docs,
  and inline code documentation

EFFICIENCY REQUIREMENTS:
- Target: <= 6 total tool calls for this entire analysis
- Read README, pyproject.toml, and key doc config files in parallel
- Use a single find command to locate all documentation files at once
- Use batch grep for docstring density checks across source tree

MONOREPO DETECTION:
- Detect repository structure; if multiple packages found,
  assess per-package README and docstrings concisely

README ANALYSIS:

1. Root README (README.md or README.rst):
   - Check for presence
   - Verify essential sections:
     * Project description and purpose (1-2 sentences)
     * Python version requirement (e.g., "Requires Python 3.11+")
     * Installation instructions (pip install, uv add, poetry add)
     * Environment setup (.env or config file instructions)
     * Quick start / usage example (code block)
     * Running tests (pytest command)
     * Linting / type-check commands
     * Link to API documentation (Swagger /docs, hosted Sphinx/MkDocs)
   - NEUTRAL if missing: CHANGELOG link, badges, logo
   - Flag as RISK: missing installation or usage section

2. Monorepo / Multi-package README:
   - Check root README explains workspace structure
   - Check for per-package README in each package directory
   - Verify each package README covers installation and public API

ENVIRONMENT CONFIGURATION DOCUMENTATION:

1. .env.example or .env.template:
   - Check file is present and committed
   - Verify it includes all required environment variables with placeholder
     values (not real secrets)
   - Check for inline comments explaining each variable
   - Flag if .env.example is absent and the project uses environment vars
   - Flag actual secrets present in .env.example as CRITICAL

2. pyproject.toml Documentation:
   - Check for [project] description and homepage/documentation URLs
   - Verify [project.optional-dependencies] groups are documented
     (e.g., dev, test, docs groups)

DOCSTRING COVERAGE AND QUALITY:

1. Docstring Presence:
   - Run: grep -rn "def \|class " <src_dir> | wc -l to estimate
     public symbols count
   - Run: grep -rn '"""' <src_dir> | wc -l as a proxy for docstring coverage
   - REASONABLE thresholds:
     * Public modules and classes: should have docstrings
     * Public functions / methods: should have docstrings
     * Private (_prefixed) functions: optional
     * Simple property getters: optional

2. Docstring Format Consistency:
   - Check for a consistent style across the codebase:
     * Google style (Args: / Returns: / Raises:)
     * NumPy style (Parameters / Returns / Raises sections)
     * reStructuredText / Sphinx (:param x: / :returns:)
   - Flag mixed styles as a documentation maintenance risk
   - Check if pydocstyle or Ruff D rules (pydocstyle plugin) are configured

3. Docstring Quality (sample check on public API modules):
   - Good: explains WHAT the function does and WHY non-obvious behaviour occurs
   - Bad: redundant docstrings that repeat the function name
     (e.g., def get_user(): """Gets the user.""")
   - Check that complex algorithms, public library entry points, and
     configuration classes have meaningful docstrings
   - Verify raised exceptions are documented where non-obvious
   - IMPORTANT: Do not penalise absence of docstrings on private helpers
     with obvious names

4. Type Hints as Documentation:
   - Check that all public function signatures have parameter and return
     type annotations
   - Verify Pydantic model fields have Field(description=...) or docstring
     where the field purpose is not obvious from its name
   - Check TypedDict, Protocol, and NamedTuple usage for structured data
     (preferred over untyped dict in public APIs)
   - Flag Any in public API signatures as documentation debt

GENERATED DOCUMENTATION (Sphinx / MkDocs):

1. Sphinx:
   - Check for docs/ directory with conf.py
   - Verify extensions list includes at minimum:
     * sphinx.ext.autodoc (generates docs from docstrings)
     * sphinx.ext.napoleon (Google/NumPy style parsing)
   - Check for make html / sphinx-build in Makefile or tox envs
   - Check for hosted docs link in README

2. MkDocs / MkDocs Material:
   - Check for mkdocs.yml in root
   - Verify mkdocstrings plugin is configured (generates from docstrings)
   - Check for docs/ directory with at least index.md
   - Check for mkdocs build or mkdocs gh-deploy in CI

3. NEUTRAL if absent:
   - Generated documentation is strongly recommended for libraries;
     for internal services it is optional
   - Flag only as a recommendation, not a hard risk, unless the project
     is a distributed library

CHANGELOG AND VERSIONING DOCUMENTATION:

1. CHANGELOG.md (or CHANGES.rst):
   - Check for presence
   - Verify it follows Keep a Changelog format or similar structured format
   - Check that the latest version entry matches pyproject.toml version
   - NEUTRAL if absent for internal services; flag as recommendation for
     libraries

2. Version Documentation:
   - Check pyproject.toml [project] version
   - Verify semantic versioning (MAJOR.MINOR.PATCH)
   - Check __version__ in package __init__.py (importlib.metadata preferred
     over hardcoded string)

CONTRIBUTING GUIDELINES:

1. CONTRIBUTING.md:
   - Check for presence
   - Verify it includes development setup instructions (uv / poetry)
   - Check for test-running instructions
   - Check for branch naming and commit message conventions
   - NEUTRAL if absent — flag only as recommendation

CODE DOCUMENTATION FOR COMPLEX MODULES:

1. Architecture / Module Documentation:
   - Check for docstrings at module level (top of .py files) in complex
     internal packages
   - Check for docs/architecture.md or equivalent
   - Verify cross-cutting concerns (auth, caching, error handling) are
     documented somewhere (README, docs/, or module docstring)

2. Non-Obvious Implementation Comments:
   - Verify inline comments explain WHY, not WHAT:
     * Good: # Using a deque here to get O(1) pops from both ends
     * Bad: # Loop through items
   - Flag absence of comments around workarounds, hacks, or
     performance-sensitive sections

OUTPUT FORMAT:

Provide structured analysis:
- README present: [Yes / No]
  * Installation section: [Yes / No]
  * Usage / quick start: [Yes / No]
  * Test commands: [Yes / No]
  * API docs link: [Yes / No]
- .env.example present: [Yes / No / Not applicable]
- Docstring coverage estimate:
  * Public functions with docstrings: [Good / Partial / Low]
  * Docstring style: [Google / NumPy / rST / Mixed / None]
- Type annotations on public API: [Complete / Partial / Missing]
- Generated docs (Sphinx/MkDocs): [Configured / Not configured]
- CHANGELOG: [Present / Absent]
- Contributing guide: [Present / Absent]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- README with installation, usage, test commands, and docs link
- .env.example present and complete
- Public functions and classes have meaningful docstrings
- Consistent docstring style enforced (Ruff D rules or pydocstyle)
- Full type annotations on public API surface
- Generated docs (Sphinx/MkDocs) configured for libraries

Fair (70-84):
- README present but missing some sections (e.g., no quick start)
- .env.example present but incomplete
- Docstring coverage partial (public classes documented, methods sparse)
- Type annotations mostly present; some Any or missing return types
- No generated docs but README links to inline Swagger for services

Weak (0-69):
- README absent or near-empty
- No .env.example for an env-var-heavy project
- Minimal docstrings across public API
- No type annotations on public functions
- No API documentation of any kind
