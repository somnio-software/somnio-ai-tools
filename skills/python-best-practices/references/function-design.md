# Python Function Design Analysis

> Analyze function design quality — single responsibility, function length, early returns, side-effect isolation, dataclass usage, and keyword-only arguments — based on somnio-software standards.

---

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/python/function-design.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/python/function-design.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1. **Single responsibility**:
   - Flag functions that both query state and change state in the same body.
   - Flag functions longer than ~20 lines of logic as refactor signals.
   - Verify function names describe *what* the function does, not *how*.

2. **Function length**:
   - Identify functions with more than ~20 lines of logic; flag them as candidates for helper extraction.

3. **Early returns (flat is better than nested)**:
   - Check for the arrow anti-pattern: three or more levels of nested `if`/`else`.
   - Verify guard clauses appear first, before the happy path.
   - Flag logic buried inside a final `else` that could instead be the early-return target.

4. **Side-effect isolation**:
   - Flag `print` calls inside library or domain functions (logging must be injected or delegated to caller).
   - Flag direct inline calls to I/O, network, or database inside domain/business-logic functions.
   - Check that side-effect collaborators are injected as dependencies rather than imported and called inline.
   - Flag functions that silently mutate a mutable argument without documentation.

5. **Dataclasses**:
   - Flag bare `dict` or `tuple` used as structured return values where a `@dataclass` would make fields explicit.
   - Check for `field(default=<mutable literal>)` — must use `field(default_factory=...)` instead.
   - Verify `frozen=True` is used for value objects and immutable structured data.

6. **Keyword-only arguments**:
   - Flag boolean flags and configuration parameters passed positionally — they must be keyword-only (`*` separator).
   - Flag function signatures where argument meaning is not obvious from position and no `*` separator is present.

OUTPUT FORMAT:
- **Overview**: Total functions analyzed, estimated design quality score (1-10).
- **Violations**: List specific violations.
  - Format: `path/to/file.py:XX` — [Issue]
- **Compliance**: Highlight well-designed functions or modules that exemplify the standards.
- **Recommendations**: Specific refactoring suggestions for each violation category.
