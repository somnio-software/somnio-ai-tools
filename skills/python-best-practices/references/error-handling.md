# Python Error Handling Analysis

> Analyze error handling quality — EAFP style, exception specificity, custom hierarchy, boundary translation, no silent swallowing, no control-flow-by-exception — based on somnio-software standards.

---

Goal: Analyze the quality and correctness of error-handling patterns across
Python source files.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/python/error-handling.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/python/error-handling.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **Exception Specificity**:
    *   Flag any bare `except:` or `except Exception:` used at depth (not at a
        top-level boundary handler).
    *   Flag `except BaseException:` in application code.
    *   Verify every `except` clause names the narrowest applicable exception
        type.

2.  **EAFP vs LBYL**:
    *   Identify LBYL patterns (check-then-act on attributes or dict keys) that
        could be replaced with idiomatic EAFP try/except.
    *   Flag concurrent-unsafe guard checks (`if key in dict` before
        `dict[key]`).

3.  **Custom Exception Hierarchy**:
    *   Verify a project-level base exception (e.g. `AppError(Exception)`) is
        defined.
    *   Check that distinct failure modes are represented by typed subclasses,
        not raw `Exception("msg")` raises.

4.  **Boundary Translation**:
    *   Check that infrastructure/third-party exceptions (`sqlalchemy`,
        `httpx`, `boto3`, etc.) are caught at the repository or adapter layer
        and re-raised as domain exceptions.
    *   Flag raw third-party exceptions leaking across layer boundaries.
    *   Verify domain exceptions are translated to user-facing responses at the
        API/presentation boundary.

5.  **Exception Chaining**:
    *   Confirm `raise DomainError("msg") from original_exc` is used when
        translating exceptions.
    *   Flag `raise NewError(...)` without `from` inside an `except` block.
    *   Allow `from None` only when documented to avoid exposing sensitive data.

6.  **Silent Swallowing**:
    *   Flag `except ...: pass` with no log, re-raise, or `contextlib.suppress`.
    *   Flag empty or comment-only `except` bodies.
    *   Verify `contextlib.suppress` usage includes a justification comment.

7.  **No Control-Flow-by-Exception**:
    *   Identify exceptions raised and immediately caught for expected branching
        (e.g. raising `StopIteration` to break a loop, using exceptions to
        signal optional values).
    *   Flag exception-driven logic that should be replaced with `if`/`else` or
        early returns.

8.  **Resource Cleanup**:
    *   Verify file handles, DB connections, and locks are managed with `with`
        statements or `finally` blocks.
    *   Flag duplicated cleanup logic in both the happy path and an `except`
        clause.

9.  **Exception Messages**:
    *   Check that exception messages include the offending value(s)
        (e.g. `f"invalid status {status!r}"`).
    *   Flag generic messages like `"invalid input"` or `"error"` with no
        context.

OUTPUT FORMAT:
*   **Overview**: Total files analyzed, quality score (1-10).
*   **Violations**: List specific file paths and lines violating the above
    rules.
    *   Format: `` `path/to/file.py:XX` — [Issue] ``
*   **Compliance**: Highlight good examples found in the codebase.
*   **Recommendations**: Specific refactoring suggestions for violations.
