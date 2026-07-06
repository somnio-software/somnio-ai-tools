---
description: Python type hints everywhere — modern generics (list[int]/dict[str,int]/X | None, Python 3.10+), Protocol structural typing, pyright/basedpyright strict mode, py.typed marker (PEP 561). Applies to all .py files.
globs: **/*.py
alwaysApply: false
---

## Best Practices

- **Annotate every function signature** — all parameters and the return type.
  Unannotated code defeats static analysis. Source: https://peps.python.org/pep-0484/

- **Use modern built-in generics** (Python 3.10+, PEP 585): write `list[int]`,
  `dict[str, int]`, `tuple[str, ...]`, `set[float]` — never the deprecated
  `typing.List`, `typing.Dict`, `typing.Tuple`, `typing.Set`.
  Source: https://peps.python.org/pep-0585/

- **Use the `X | Y` union syntax** (Python 3.10+, PEP 604) for union types and
  optional values: `str | None`, `int | str`. Do not use `typing.Optional[X]`
  or `typing.Union[X, Y]` in new code.
  Source: https://peps.python.org/pep-0604/

- **Annotate module-level variables** with PEP 526 variable annotations
  (`x: int = 0`, `items: list[str] = []`). Do not rely on type inference alone
  for public module-level names.
  Source: https://peps.python.org/pep-0526/

- **Prefer `Protocol` for structural (duck-typed) interfaces** over `ABC`
  when the implementation should not depend on the base class. `Protocol`
  enables structural subtyping — callers pass any object satisfying the
  shape without explicitly inheriting.
  Source: https://peps.python.org/pep-0484/ (section: protocols)

- **Run pyright or basedpyright in strict mode** as the CI type-checking gate.
  Strict mode enables `reportUnknownVariableType`, `reportMissingTypeArgument`,
  `reportUnknownMemberType`, and other checks suppressed in basic mode.
  Source: https://microsoft.github.io/pyright/ · https://docs.basedpyright.com/

  > **CONTESTED — checker choice:** pyright (Microsoft) and basedpyright (community
  > fork with stricter defaults) are both acceptable. **Default: pyright strict**,
  > because it ships with Pylance and integrates with VS Code out of the box.
  > Projects may pin basedpyright if they prefer its additional diagnostics, but
  > the choice must be recorded in `pyproject.toml` and applied consistently.
  > Source: https://docs.basedpyright.com/ · https://github.com/microsoft/pyright/blob/main/docs/mypy-comparison.md

- **Ship `py.typed` (PEP 561)** in every distributable Python package. An empty
  `py.typed` marker file in the package root tells type checkers that the
  package provides inline type information and should be checked rather than
  treated as `Any`.
  Source: https://peps.python.org/pep-0561/

- **Never use `Any` without a suppression comment** explaining why static typing
  cannot express the type at that point. Prefer `object`, `Unknown`, or a
  narrower `Protocol` first; reach for `Any` only as a last resort.
  Source: https://peps.python.org/pep-0484/ (section: the Any type)

- **Annotate `TypeVar`-bound generic functions and classes** when a function
  must preserve the concrete type of its argument (e.g. identity functions,
  copy helpers, decorator factories). Use `TypeVar` with an upper bound
  (`T = TypeVar("T", bound=SomeBase)`) rather than annotating the parameter
  as the base type and losing the concrete subtype.
  Source: https://peps.python.org/pep-0484/

- **Use `Final` for constants** that must not be reassigned. Declare at module
  level or as a class variable: `MAX_RETRIES: Final = 3`.
  Source: https://peps.python.org/pep-0526/

- **Use `Literal` for narrow string/int constants** in function signatures
  instead of plain `str` or `int` when only specific values are valid:
  `def set_mode(mode: Literal["read", "write"]) -> None`.
  Source: https://peps.python.org/pep-0484/

- **astral `ty`** (2025+) is an emerging fast type checker from the Ruff team.
  It is not yet production-stable for all projects; do not replace pyright with
  ty unless the team has evaluated compatibility.
  Source: https://astral.sh/blog/ty · https://github.com/astral-sh/ty

## Common Mistakes

- Using `Optional[X]` or `Union[X, Y]` in new code instead of the modern
  `X | None` / `X | Y` syntax (requires Python 3.10+; add
  `from __future__ import annotations` for 3.9 files if back-compat is needed).
- Importing `List`, `Dict`, `Tuple`, `Set`, `FrozenSet` from `typing` in new
  code — use the built-in types directly.
- Annotating only the "happy path" return type and omitting `None` when the
  function can return `None` under some branch — this produces false negatives
  in pyright's strict mode.
- Skipping the return type annotation on `__init__` (should be `-> None`) and
  on coroutines (should be `-> Coroutine[Any, Any, T]` or `-> T` wrapped in
  `async def`).
- Using `type: ignore` comments without a specific error code
  (`# type: ignore[attr-defined]`) — blanket ignores mask real bugs.
- Publishing a library without a `py.typed` marker, forcing downstream type
  checkers to treat all imports from it as `Any`.
- Declaring `Protocol` classes with methods that accept `self: Any` — this
  defeats the structural check and allows any class to satisfy the protocol
  silently.
- Running pyright in basic (default) mode and assuming the project is
  type-safe; strict mode is required.

## Purpose

Strong, complete type annotations close the gap between documentation and
verification — the type checker finds whole classes of bugs (wrong argument
order, missing `None` guards, incorrect return shapes) before tests run or
code ships. Modern Python 3.10+ syntax (`list[int]`, `X | None`, `Protocol`)
is unambiguous, concise, and not dependent on `typing` imports that were
deprecated in PEP 585/604. Shipping `py.typed` makes type safety transitive
across library boundaries. Running pyright in strict mode prevents annotation
gaps from silently degrading into `Unknown`/`Any` propagation.

## Rules

1. Annotate every function parameter and return type. No unannotated public
   function signatures. (https://peps.python.org/pep-0484/)
2. Use built-in generic types: `list[T]`, `dict[K, V]`, `tuple[T, ...]`,
   `set[T]`. Never import `List`/`Dict`/`Tuple`/`Set` from `typing` in new
   code. (https://peps.python.org/pep-0585/)
3. Use `X | Y` union syntax. Do not use `Optional[X]` or `Union[X, Y]` in
   new code. (https://peps.python.org/pep-0604/)
4. Annotate module-level and class-level variables with PEP 526 syntax.
   (https://peps.python.org/pep-0526/)
5. Use `Protocol` for structural interfaces; reserve `ABC` for cases where
   explicit inheritance is semantically required. (https://peps.python.org/pep-0484/)
6. Run pyright in strict mode (`--pythonversion` matching the project's minimum
   supported version) as the CI gate. Baseline: pyright; basedpyright is
   permitted if configured in `pyproject.toml`. (https://microsoft.github.io/pyright/ ·
   https://docs.basedpyright.com/)
7. Never use bare `# type: ignore`; always attach an error code
   (`# type: ignore[assignment]`). Treat unexplained ignores as a lint error.
   (https://peps.python.org/pep-0484/)
8. Use `Any` only as a documented last resort; add a comment explaining why a
   narrower type is not feasible. (https://peps.python.org/pep-0484/)
9. Ship an empty `py.typed` file in every distributable package root.
   (https://peps.python.org/pep-0561/)
10. Use `Final` for constants that must not be reassigned and `Literal` to
    narrow string/int parameters to specific permitted values.
    (https://peps.python.org/pep-0526/ · https://peps.python.org/pep-0484/)
11. Bound `TypeVar` with an upper-bound type when generic functions must
    preserve concrete subtypes across call sites. (https://peps.python.org/pep-0484/)
12. Do not use `astral ty` as the sole type-checking gate in production
    pipelines until the team has validated compatibility; it is tracked but not
    yet the default. (https://astral.sh/blog/ty · https://github.com/astral-sh/ty)
