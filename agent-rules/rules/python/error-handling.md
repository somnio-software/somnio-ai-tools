---
description: Python error handling — EAFP over LBYL, narrowest except, custom exception hierarchy, translate at boundaries, never swallow, no control-flow-by-exception. Applies to all .py files.
globs: **/*.py
alwaysApply: false
---

## Best Practices

- **EAFP over LBYL.** Prefer "Easier to Ask Forgiveness than Permission": attempt the operation and handle the exception, rather than pre-checking conditions that may change between the check and the use. This is idiomatic Python and avoids TOCTOU races. Source: https://realpython.com/ref/best-practices/exception-handling/

- **Narrowest `except` clause.** Catch the most specific exception type that covers the failure. Never use a bare `except:` or `except Exception:` at depth — these swallow `KeyboardInterrupt`, `SystemExit`, and programming errors, violating PEP 20 ("Errors should never pass silently"). Source: https://peps.python.org/pep-0020/

- **Custom exception hierarchy rooted on a project base class.** Define `class AppError(Exception): ...` (or per-domain variants) at the top of your package. Subclass it for each distinct failure mode. This lets callers catch by category without coupling to built-in types. Source: https://blog.miguelgrinberg.com/post/the-ultimate-guide-to-error-handling-in-python

- **Translate exceptions at layer boundaries.** Infrastructure exceptions (`sqlite3.OperationalError`, `httpx.TimeoutException`, `boto3` errors) must be caught at the repository/adapter layer and re-raised as domain exceptions (`OrderNotFoundError`, `PaymentGatewayError`). Domain exceptions must be translated to user-facing responses at the API/presentation boundary. Never let raw third-party exceptions leak across layers. Source: https://blog.miguelgrinberg.com/post/the-ultimate-guide-to-error-handling-in-python

- **Never swallow exceptions silently.** An empty `except` block or one that only passes is forbidden. At minimum, log the exception with context before continuing. PEP 20: "Errors should never pass silently. Unless explicitly silenced." If you intentionally suppress, name the reason in a comment and use `contextlib.suppress` for clarity. Source: https://peps.python.org/pep-0020/

- **Do not use exceptions for control flow.** Exceptions carry overhead and make logic hard to follow. Use `if`/`else` or early returns for expected branching (empty list, missing key, optional value). Reserve exceptions for genuinely exceptional conditions (I/O failure, constraint violation, invariant broken). Source: https://realpython.com/ref/best-practices/exception-handling/

- **Chain exceptions with `raise ... from`.** When catching one exception and raising another, always use `raise NewError("msg") from original_exc` to preserve the original traceback and make debugging tractable. Use `raise NewError("msg") from None` only when the original exception contains sensitive data you explicitly cannot expose. Source: https://blog.miguelgrinberg.com/post/the-ultimate-guide-to-error-handling-in-python

- **Provide context in exception messages.** Include the values that caused the failure: `raise ValueError(f"invalid status {status!r}, expected one of {VALID_STATUSES}")`. Generic messages like `"invalid input"` force developers to re-run with a debugger to understand the failure. Source: https://realpython.com/ref/best-practices/exception-handling/

- **Use `finally` / context managers for cleanup, not bare try/except.** Resource cleanup (files, connections, locks) belongs in `finally` blocks or `with` statements, not duplicated in both the happy path and the except clause. Source: https://realpython.com/ref/best-practices/exception-handling/

## Common Mistakes

- Bare `except:` or `except Exception:` at depth — catches `KeyboardInterrupt` and `SystemExit`, masks bugs, hides programming errors.
- LBYL races: checking `if key in dict` then accessing `dict[key]` in a concurrent context — the key can be removed between the two statements. Just `try: value = dict[key]` and handle `KeyError`.
- Raising `Exception("something went wrong")` at every callsite — callers cannot distinguish failure modes; use typed subclasses.
- Leaking `sqlalchemy.exc.NoResultFound` or `requests.exceptions.ConnectionError` out of a repository — callers outside the data layer now depend on infrastructure libraries.
- Using exceptions as `goto`: catching an exception thrown two levels down to skip intermediate logic — restructure with early returns or a result type.
- Forgetting `raise ... from exc` when translating — the original traceback is lost, making root-cause analysis much harder.
- Silent swallowing: `except SomeError: pass` with no log, no re-raise, no `contextlib.suppress` — a future maintainer will never know the failure happened.
- Catching `BaseException` in application code — this catches `SystemExit` and `GeneratorExit`; only framework/runner code should ever do this, with immediate re-raise.

## Purpose

Consistent error-handling discipline makes Python services predictable and debuggable:

- **EAFP + narrow clauses** mean the code reads naturally and only handles what it expects, so unexpected failures propagate immediately.
- **Custom hierarchy + boundary translation** means each layer speaks its own language; domain logic never leaks infrastructure details to the presentation layer.
- **Never-swallow + exception chaining** ensures that every failure leaves a traceable record and that the full causal chain is always available in tracebacks.
- **No control-flow-by-exception** keeps branching logic readable and avoids the performance cost of exception construction on hot paths.

Together these rules reduce the "silent bug" failure mode and ensure that any unexpected state surfaces immediately with enough context to diagnose.

## Rules

1. Prefer EAFP: attempt the operation and handle the resulting exception rather than pre-checking conditions that could change. Source: https://realpython.com/ref/best-practices/exception-handling/
2. Always name the narrowest applicable exception type in `except`. Never use a bare `except:` or catch `BaseException` in application code. Source: https://peps.python.org/pep-0020/
3. Define a project-level base exception class (e.g. `AppError(Exception)`) and subclass it for every distinct domain failure mode. Source: https://blog.miguelgrinberg.com/post/the-ultimate-guide-to-error-handling-in-python
4. Translate infrastructure/third-party exceptions into domain exceptions at the repository or adapter boundary. Domain exceptions must be translated to user-facing responses at the API boundary. Source: https://blog.miguelgrinberg.com/post/the-ultimate-guide-to-error-handling-in-python
5. Never silently swallow an exception. Either log it, re-raise it, or use `contextlib.suppress` with a documented justification comment. Source: https://peps.python.org/pep-0020/
6. Do not use exceptions for expected branching or control flow. Reserve them for genuinely exceptional runtime conditions. Source: https://realpython.com/ref/best-practices/exception-handling/
7. Always chain exceptions when translating: `raise DomainError("msg") from original_exc`. Suppress the chain (`from None`) only to avoid exposing sensitive data, and document why. Source: https://blog.miguelgrinberg.com/post/the-ultimate-guide-to-error-handling-in-python
8. Include the offending value(s) in exception messages to make failures self-diagnosable without a debugger. Source: https://realpython.com/ref/best-practices/exception-handling/
9. Use `with` statements and `finally` blocks for all resource cleanup; never duplicate cleanup logic across the happy path and exception branches. Source: https://realpython.com/ref/best-practices/exception-handling/
10. Do not catch `Exception` at depth for general-purpose silencing; if broad catching is required at a top-level handler (e.g. a CLI entrypoint or WSGI middleware), log the full traceback and exit or return an error response — never continue silently. Source: https://peps.python.org/pep-0020/
