# Python Code Style Analysis

> Analyze code style conformance — PEP 8, naming conventions, import grouping, line length, docstrings (Google), and Ruff-clean status — based on somnio-software standards.

---

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/python/code-style.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/python/code-style.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1. **PEP 8 and Ruff compliance**:
   - Check that `pyproject.toml` configures Ruff with at minimum rule sets `E`, `F`, `W`, `I`, `D`.
   - Flag any bare `# noqa` without a rule code (must be `# noqa: <CODE>`).
   - Verify CI runs `ruff check` and `ruff format --check` and fails on violations.

2. **Naming conventions**:
   - Modules and packages: `snake_case`.
   - Functions, methods, variables, parameters: `snake_case`.
   - Classes: `PascalCase`.
   - Module-level immutable constants: `SCREAMING_SNAKE_CASE`; flag if applied to mutable objects.
   - Protected members: single leading underscore (`_name`); flag double underscore where single suffices.

3. **Import grouping and absolute imports**:
   - Verify exactly 3 import groups — stdlib, third-party, first-party — each separated by one blank line.
   - Flag relative imports outside of intra-package `__init__` re-exports.
   - Flag mixed groups or missing blank-line separators.

4. **Line length 88**:
   - Flag lines exceeding 88 characters that lack a `# noqa: E501` suppression.

5. **Docstrings (PEP 257 + Google style)**:
   - Every public module, class, function, and method must have a docstring.
   - Multi-line docstrings: summary on first line (imperative mood), blank line, sections (`Args:`, `Returns:`, `Raises:`), closing `"""` on its own line.
   - Flag missing docstrings (`D1xx` violations) and wrong summary style (non-imperative mood).

OUTPUT FORMAT:
- **Overview**: Total files analyzed, estimated Ruff-clean percentage, compliance score (1-10).
- **Violations**: List specific violations.
  - Format: `path/to/file.py:XX` — [Issue]
- **Compliance**: Highlight files or modules that are fully Ruff-clean and follow all conventions.
- **Recommendations**: Specific refactoring suggestions for each violation category.
