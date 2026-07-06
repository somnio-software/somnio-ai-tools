# System Prompt — Somnio Coding Standards (Python)

You are an expert software engineer. Follow these coding standards precisely when generating code.

### Python code style — PEP 8 enforced via Ruff as CI gate; line length 88 (CONTESTED); naming conventions; 3-group sorted absolute imports; docstrings (PEP 257 + Google sections via Ruff D + convention=google, CONTESTED). Applies to all .py files.
> Applies to: `**/*.py`

## Rules

1. Ruff is the sole lint/format/import-sort gate; CI must run `ruff check` and `ruff format --check` and fail on any violation. (Source: https://docs.astral.sh/ruff/)
2. Configure Ruff in `pyproject.toml`; do not use `.ruffrc` or inline config files. (Source: https://docs.astral.sh/ruff/settings/)
3. Line length is **88** characters (CONTESTED: PEP 8 specifies 79; this project adopts 88 to match Ruff formatter default). (Source: https://docs.astral.sh/ruff/formatter/ · https://peps.python.org/pep-0008/)
4. Enable at minimum Ruff rule sets `E`, `F`, `W`, `I`, `D`; do not disable `E` or `F` rules project-wide. (Source: https://docs.astral.sh/ruff/settings/)
5. Modules and packages: `snake_case`. Functions, methods, variables, parameters: `snake_case`. Classes: `PascalCase`. Module-level immutable constants: `SCREAMING_SNAKE_CASE`. (Source: https://peps.python.org/pep-0008/#naming-conventions)
6. All imports must be absolute; never use relative imports outside of intra-package `__init__` re-exports. (Source: https://peps.python.org/pep-0008/#imports)
7. Imports are sorted into exactly 3 groups — stdlib, third-party, first-party — each separated by one blank line, enforced by Ruff isort (`I` rules). (Source: https://peps.python.org/pep-0008/#imports · https://docs.astral.sh/ruff/settings/)
8. Every public module, class, function, and method must have a docstring; omitting one is a Ruff `D1xx` violation. (Source: https://peps.python.org/pep-0257/)
9. Docstrings follow Google style (CONTESTED: PEP 257 is the baseline; NumPy style is an alternative; this project chooses Google for compactness) enforced via `ruff.lint.pydocstyle.convention = "google"`. (Source: https://peps.python.org/pep-0257/ · https://google.github.io/styleguide/pyguide.html · https://docs.astral.sh/ruff/settings/)
10. Multi-line docstring: summary on first line (imperative mood), blank line, sections (`Args:`, `Returns:`, `Raises:` as needed), closing `"""` on its own line. (Source: https://peps.python.org/pep-0257/ · https://google.github.io/styleguide/pyguide.html)
11. Use `# noqa: <CODE>` (never bare `# noqa`) to suppress a Ruff rule on a specific line, and add a brief comment explaining why. (Source: https://docs.astral.sh/ruff/settings/)
12. Do not use `SCREAMING_SNAKE_CASE` for mutable module-level objects; reserve it for truly immutable constants. (Source: https://peps.python.org/pep-0008/#naming-conventions)

## Rules

### Formatter and linter: Ruff as CI gate

Run Ruff for both linting and formatting (replaces flake8, isort, black, and pyupgrade). Ruff is configured in `pyproject.toml` under `[tool.ruff]`. The CI pipeline must fail on any lint or format violation.
Source: https://docs.astral.sh/ruff/ · https://docs.astral.sh/ruff/formatter/ · https://docs.astral.sh/ruff/settings/

**CONTESTED — line length 88:** PEP 8 (https://peps.python.org/pep-0008/) specifies 79 characters for code and 72 for docstrings. The Black formatter popularised 88 as a pragmatic increase; Ruff's formatter (https://docs.astral.sh/ruff/formatter/) defaults to 88. This project adopts **88** as the default for consistency with Ruff's formatter default, but teams may override it via `line-length` in `pyproject.toml`.

### Naming conventions (PEP 8)

Follow the naming rules from PEP 8 (https://peps.python.org/pep-0008/#naming-conventions):

- **Modules and packages:** `snake_case` (`my_module.py`, `my_package/`).
- **Functions, methods, variables, parameters:** `snake_case` (`parse_response`, `user_id`).
- **Classes:** `PascalCase` (`UserRepository`, `PaymentService`).
- **Constants (module-level, immutable):** `SCREAMING_SNAKE_CASE` (`MAX_RETRIES`, `DEFAULT_TIMEOUT`).
- **"Protected" members (single leading underscore):** `_internal`. Not enforced by the runtime, but signals "implementation detail".
- **Private name-mangled members (double leading underscore):** `__mangled`. Use sparingly; prefer `_single` in most cases.
- **Type variables:** Short `PascalCase` or single capital letter (`T`, `KT`, `VT`).

### Imports: 3-group sorted absolute imports

Organise every file's imports into exactly three groups separated by a blank line. Never use relative imports at the package level; use absolute paths throughout.
Source: https://peps.python.org/pep-0008/#imports · https://docs.astral.sh/ruff/settings/ (isort rules)

Ruff's `I` rule set (isort) enforces this automatically. Do not write manual blank lines between imports within a group.

### Docstrings: PEP 257 + Google style via Ruff D

Every public module, class, and function/method must have a docstring. Use the **one-liner form** for trivial cases; use the **multi-line Google-style form** when arguments, return values, or raised exceptions need documentation.

Sources:
- PEP 257 (conventions): https://peps.python.org/pep-0257/
- Google Python Style Guide (sections): https://google.github.io/styleguide/pyguide.html
- Ruff D rules with `convention = "google"`: https://docs.astral.sh/ruff/settings/

**CONTESTED — Google docstring convention:** PEP 257 (https://peps.python.org/pep-0257/) is the canonical standard and does not specify section format. Google style (https://google.github.io/styleguide/pyguide.html) and NumPy style are both widely adopted. This project adopts **Google style** (enforced via `ruff.lint.pydocstyle.convention = "google"`) because it is compact, readable, and natively supported by Ruff's `D` rule set. Teams preferring NumPy style must change the convention key and update this file.

Rules enforced by Ruff D + `convention = "google"`:
- Summary line on the first line, no leading blank line.
- Multi-line docstrings: blank line after summary, sections (`Args:`, `Returns:`, `Raises:`, `Attributes:`, `Example:`), closing `"""` on its own line.
- No trailing whitespace in docstrings.

---

- Avoid **Mixing import groups or using relative imports** — Ruff isort (`I` rules) will flag this; fix it with `ruff check --fix`.
- Avoid **Line length over 88 with no `# noqa`** — Ruff formatter rewraps automatically; do not manually insert line breaks that contradict the formatter's output.
- Avoid **Missing docstring on a public function** — Ruff `D100`/`D101`/`D102`/`D103` will raise. Add a docstring rather than suppressing with `# noqa`.
- Avoid **Wrong docstring summary style** — e.g. "Returns the user" instead of an imperative "Return the user." Google style requires imperative mood.
- Avoid **`SCREAMING_SNAKE_CASE` used for mutable module-level objects** — constants are values that never change; a mutable list or dict must not use this casing.
- Avoid **Non-public names with double leading underscore where single underscore suffices** — `__private` triggers name mangling; use `_protected` unless you specifically need mangling in a class hierarchy.
- Avoid **Inline `# noqa` without a rule code** — always specify the suppressed code: `# noqa: E501`, never bare `# noqa`.
- Avoid **Docstring in `"""triple quotes"""` on same line as `def`** — only one-liners may keep the closing `"""` on the same line as the opening; multi-line docstrings must have `"""` on its own closing line.

---

---

---

### Python data-validation conventions — pydantic models at input boundaries, field validators/constraints, no unvalidated dict, typed response models, pydantic-settings BaseSettings for 12-factor configuration. Applies to all .py files.
> Applies to: `**/*.py`

## Rules

1. Parse every external input (HTTP body, env var, queue message, file, external API response) through a `pydantic.BaseModel` at the boundary before passing it inward. Source: [https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/)
2. Never pass a raw `dict` across layer boundaries as a substitute for a typed model. Source: [https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/)
3. Declare value constraints (`gt`, `min_length`, `pattern`, `max_length`, etc.) with `Field(...)` on the model, not in handler or service code. Source: [https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/)
4. Implement cross-field invariants in `@field_validator` or `@model_validator`, not in application logic after the model is constructed. Source: [https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/)
5. Annotate every public function's return type as a pydantic model (or `list[Model]`) when it produces structured data — never `dict` or `Any`. Source: [https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/)
6. Load all configuration through `pydantic-settings BaseSettings`; required variables have no default so a missing variable raises `ValidationError` at startup (fail-fast). Source: [https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/) · [https://medium.com/datamindedbe/twelve-factor-python-applications-using-pydantic-settings-f74a69906f2f](https://medium.com/datamindedbe/twelve-factor-python-applications-using-pydantic-settings-f74a69906f2f)
7. Instantiate `Settings` once at the application edge (module level or cached factory) and inject it — never construct it inside a request handler or service method. Source: [https://medium.com/datamindedbe/twelve-factor-python-applications-using-pydantic-settings-f74a69906f2f](https://medium.com/datamindedbe/twelve-factor-python-applications-using-pydantic-settings-f74a69906f2f)
8. Use `model_config = ConfigDict(frozen=True)` for settings objects and immutable value models to prevent post-construction mutation. Source: [https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/)
9. Catch `pydantic.ValidationError` at the boundary layer and translate it to a domain or HTTP error; do not let it propagate unhandled into the service layer. Source: [https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/)
10. Do not store sensitive secrets as field defaults in `BaseSettings`; defaults belong in the environment, not in source code (12-factor principle III). Source: [https://medium.com/datamindedbe/twelve-factor-python-applications-using-pydantic-settings-f74a69906f2f](https://medium.com/datamindedbe/twelve-factor-python-applications-using-pydantic-settings-f74a69906f2f)

## Rules

- **Validate at every external boundary with a pydantic `BaseModel`.** HTTP request bodies, CLI arguments, message-queue payloads, file-parsed data, and external API responses must each be parsed through a pydantic model before the value is used anywhere in application code. Raw `dict` values from `json.loads`, `request.json()`, or ORM row-as-dict are never passed inward — they are fed to `Model.model_validate()` or `Model(**data)` immediately at the boundary. ([https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/))

- **Declare constraints inline with `Field(...)`.** Use `Field(gt=0)`, `Field(min_length=1)`, `Field(pattern=r"^\w+$")`, `Field(max_length=255)` etc. rather than validating in application logic after the fact. Pydantic raises `ValidationError` before the model instance is returned, guaranteeing the object is always valid. ([https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/))

- **Prefer `@field_validator` and `@model_validator` for cross-field invariants.** Custom business rules that cannot be expressed with `Field` constraints (e.g., "end date must be after start date") belong in `@field_validator('end_date', mode='after')` or `@model_validator(mode='after')`, not in service/handler code that receives the model. ([https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/))

- **Never pass unvalidated `dict` objects across layer boundaries.** Passing `dict` instead of a model loses type information and bypasses validation. If a downstream function accepts a `dict`, it should be refactored to accept the model. The one permitted exception is serialisation output (`model.model_dump()`) going into a persistence or transport layer — that is a deliberate serialisation step, not bypassed validation.

- **Return typed response models from every public endpoint or service method.** Every function that produces structured data for a caller should annotate its return type as a pydantic `BaseModel` (or `list[MyModel]`). Using `dict` or `Any` as a return type for structured data is forbidden. ([https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/))

- **Load application configuration through `pydantic-settings BaseSettings`, built once at the application edge, not on first use.** Each required environment variable is declared as a typed field with no default (or `...`). Missing variables raise `ValidationError` on startup — fail-fast, before any request is handled. Optional variables carry a typed default. This implements the 12-factor config principle: config from the environment, never from code. ([https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/), [https://medium.com/datamindedbe/twelve-factor-python-applications-using-pydantic-settings-f74a69906f2f](https://medium.com/datamindedbe/twelve-factor-python-applications-using-pydantic-settings-f74a69906f2f))

- **Instantiate `Settings` once at module level or via a cached factory; inject it into components.** Do not call `Settings()` inside a request handler or service method — doing so re-parses the environment on every invocation and hides startup failures. ([https://medium.com/datamindedbe/twelve-factor-python-applications-using-pydantic-settings-f74a69906f2f](https://medium.com/datamindedbe/twelve-factor-python-applications-using-pydantic-settings-f74a69906f2f))

- **Use `model_config = ConfigDict(frozen=True)` for settings and immutable value objects.** Frozen models prevent accidental mutation and are hashable. Request/command models that should not be mutated after parsing also benefit from `frozen=True`. ([https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/))

- **Catch `pydantic.ValidationError` at boundaries and translate to a domain or HTTP error.** Do not let `ValidationError` propagate as an unhandled exception into the middle tier. Translate it at the edge (e.g., HTTP 422 Unprocessable Entity) and log the structured error details. ([https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/))

- Avoid accepting `dict` or `Any` as a function parameter for "flexibility" — this silently removes all validation and type safety across the call stack.
- Avoid calling `Settings()` inside request handlers or service constructors — configuration is re-parsed on every call and missing-variable errors appear at runtime rather than startup.
- Avoid declaring `Optional[str]` with no default (implicitly `None`) for a required environment variable — pydantic-settings will silently use `None` instead of raising on a missing env var. Use `str` with no default to make the field required.
- Avoid validating business rules (e.g., range checks, cross-field consistency) in handler code after the model is already constructed — these rules belong in `@field_validator` / `@model_validator` so validation is centralised and reusable.
- Avoid using `model.dict()` (v1 API) instead of `model.model_dump()` (v2 API) — the v1 alias is deprecated and will be removed.
- Avoid constructing response data as a plain `dict` and returning it — callers lose type information and pydantic's serialisation guarantees. Construct and return the typed response model.
- Avoid mutating a parsed model after construction to "patch" data — validation runs only at construction time. If the data needs adjustment, adjust the input before parsing or use a validator.
- Avoid putting sensitive defaults (e.g., development secrets) as field defaults in `BaseSettings` — defaults are code, not config, and violate 12-factor principle III.

---

### Python error handling — EAFP over LBYL, narrowest except, custom exception hierarchy, translate at boundaries, never swallow, no control-flow-by-exception. Applies to all .py files.
> Applies to: `**/*.py`

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

## Rules

- **EAFP over LBYL.** Prefer "Easier to Ask Forgiveness than Permission": attempt the operation and handle the exception, rather than pre-checking conditions that may change between the check and the use. This is idiomatic Python and avoids TOCTOU races. Source: https://realpython.com/ref/best-practices/exception-handling/

- **Narrowest `except` clause.** Catch the most specific exception type that covers the failure. Never use a bare `except:` or `except Exception:` at depth — these swallow `KeyboardInterrupt`, `SystemExit`, and programming errors, violating PEP 20 ("Errors should never pass silently"). Source: https://peps.python.org/pep-0020/

- **Custom exception hierarchy rooted on a project base class.** Define `class AppError(Exception): ...` (or per-domain variants) at the top of your package. Subclass it for each distinct failure mode. This lets callers catch by category without coupling to built-in types. Source: https://blog.miguelgrinberg.com/post/the-ultimate-guide-to-error-handling-in-python

- **Translate exceptions at layer boundaries.** Infrastructure exceptions (`sqlite3.OperationalError`, `httpx.TimeoutException`, `boto3` errors) must be caught at the repository/adapter layer and re-raised as domain exceptions (`OrderNotFoundError`, `PaymentGatewayError`). Domain exceptions must be translated to user-facing responses at the API/presentation boundary. Never let raw third-party exceptions leak across layers. Source: https://blog.miguelgrinberg.com/post/the-ultimate-guide-to-error-handling-in-python

- **Never swallow exceptions silently.** An empty `except` block or one that only passes is forbidden. At minimum, log the exception with context before continuing. PEP 20: "Errors should never pass silently. Unless explicitly silenced." If you intentionally suppress, name the reason in a comment and use `contextlib.suppress` for clarity. Source: https://peps.python.org/pep-0020/

- **Do not use exceptions for control flow.** Exceptions carry overhead and make logic hard to follow. Use `if`/`else` or early returns for expected branching (empty list, missing key, optional value). Reserve exceptions for genuinely exceptional conditions (I/O failure, constraint violation, invariant broken). Source: https://realpython.com/ref/best-practices/exception-handling/

- **Chain exceptions with `raise ... from`.** When catching one exception and raising another, always use `raise NewError("msg") from original_exc` to preserve the original traceback and make debugging tractable. Use `raise NewError("msg") from None` only when the original exception contains sensitive data you explicitly cannot expose. Source: https://blog.miguelgrinberg.com/post/the-ultimate-guide-to-error-handling-in-python

- **Provide context in exception messages.** Include the values that caused the failure: `raise ValueError(f"invalid status {status!r}, expected one of {VALID_STATUSES}")`. Generic messages like `"invalid input"` force developers to re-run with a debugger to understand the failure. Source: https://realpython.com/ref/best-practices/exception-handling/

- **Use `finally` / context managers for cleanup, not bare try/except.** Resource cleanup (files, connections, locks) belongs in `finally` blocks or `with` statements, not duplicated in both the happy path and the except clause. Source: https://realpython.com/ref/best-practices/exception-handling/

- Avoid bare `except:` or `except Exception:` at depth — catches `KeyboardInterrupt` and `SystemExit`, masks bugs, hides programming errors.
- Avoid lBYL races: checking `if key in dict` then accessing `dict[key]` in a concurrent context — the key can be removed between the two statements. Just `try: value = dict[key]` and handle `KeyError`.
- Avoid raising `Exception("something went wrong")` at every callsite — callers cannot distinguish failure modes; use typed subclasses.
- Avoid leaking `sqlalchemy.exc.NoResultFound` or `requests.exceptions.ConnectionError` out of a repository — callers outside the data layer now depend on infrastructure libraries.
- Avoid using exceptions as `goto`: catching an exception thrown two levels down to skip intermediate logic — restructure with early returns or a result type.
- Avoid forgetting `raise ... from exc` when translating — the original traceback is lost, making root-cause analysis much harder.
- Avoid silent swallowing: `except SomeError: pass` with no log, no re-raise, no `contextlib.suppress` — a future maintainer will never know the failure happened.
- Avoid catching `BaseException` in application code — this catches `SystemExit` and `GeneratorExit`; only framework/runner code should ever do this, with immediate re-raise.

---

### Python function design — single responsibility, early returns, pure functions, side-effect isolation, dataclasses, keyword-only args. Applies to all .py files.
> Applies to: `**/*.py`

## Rules

1. Each function has a single, clearly named responsibility — it either queries state or changes state, not both. (https://peps.python.org/pep-0020/)
2. Use guard clauses (early returns / raises) to handle preconditions before the happy path. Never nest the main logic inside an `else`. (https://peps.python.org/pep-0020/ — "Flat is better than nested.")
3. Keep pure computation separate from side effects. Business-logic functions must not perform I/O directly; receive collaborators via dependency injection instead. (https://arjancodes.com/blog/python-dependency-injection-best-practices/)
4. Never silently mutate a function argument. Return a new object or document mutation explicitly. (https://google.github.io/styleguide/pyguide.html)
5. Use `@dataclass` (or `@dataclass(frozen=True)`) for any group of fields that travels together as a unit; avoid bare `dict` or `tuple` for structured return values. (https://peps.python.org/pep-0557/)
6. Use `field(default_factory=...)` for mutable defaults inside dataclasses — never assign a mutable literal as a default. (https://peps.python.org/pep-0557/)
7. Mark flags, configuration, and non-obvious parameters as keyword-only using `*` in the function signature. (https://peps.python.org/pep-3102/)
8. Functions with more than ~20 lines of logic are a refactor signal. Extract a named helper rather than adding another indent level.
9. Side effects (logging, network, file I/O, DB writes) belong in clearly named boundary functions. Inject them as collaborators; do not import and call them inline inside domain logic. (https://snyk.io/blog/dependency-injection-python/)
10. Do not use `print` inside library/domain code. Accept a logger via dependency injection, or let the caller handle output. (https://google.github.io/styleguide/pyguide.html)

## Rules

### Single Responsibility
- Each function does **one thing**: it either queries state or changes state, not both. (Source: https://peps.python.org/pep-0020/ — "Simple is better than complex.")
- Functions longer than ~20 lines are a signal to extract a helper. Name the helper after *what* it does, not *how*.
- Side effects (I/O, mutation, network) are pushed to the edges; pure computation lives in the centre. (Source: https://google.github.io/styleguide/pyguide.html — functions section.)

### Early Returns ("Flat is Better Than Nested")
- Validate preconditions and return (or raise) early to keep the happy path un-indented. (Source: https://peps.python.org/pep-0020/ — "Flat is better than nested.")
- Avoid the "arrow anti-pattern" — deeply nested `if`/`else` chains that force readers to track 3+ levels of indentation simultaneously.

### Pure Functions and Side-Effect Isolation
- A **pure function** always returns the same output for the same input and produces no observable side effects. Prefer pure functions for business logic. (Source: https://peps.python.org/pep-0020/ — "Explicit is better than implicit.")
- Isolate side effects (file I/O, database writes, HTTP calls, `print`) behind clearly named functions or service objects injected as dependencies. (Source: https://arjancodes.com/blog/python-dependency-injection-best-practices/ — dependency injection best practices.)
- Never mutate a mutable argument silently; return a new object or document the mutation explicitly. (Source: https://google.github.io/styleguide/pyguide.html.)

### Dataclasses for Structured Data
- Use `@dataclass` (or `@dataclass(frozen=True)` for value objects) instead of plain dicts or tuples whenever a group of fields travels together. (Source: https://peps.python.org/pep-0557/ — Data Classes.)
- Frozen dataclasses express immutability at the type level and are hashable by default.
- For data that crosses service/API boundaries, prefer Pydantic models (see `data-validation.md`); for internal pure-Python structured data, `dataclass` is sufficient and has no runtime dependency.

### Keyword-Only Arguments
- Mark parameters that are **not positional** with `*` in the signature. This prevents callers from passing arguments in the wrong order by accident. (Source: https://peps.python.org/pep-3102/ — Keyword-Only Arguments.)
- Use keyword-only args for boolean flags, optional configuration, and any parameter whose meaning is not obvious from its position.

- Avoid writing functions that both compute a result **and** write it to a file/database — split into two functions.
- Avoid arrow anti-pattern: three or more levels of nested `if`/`else` instead of early returns.
- Avoid returning `None` implicitly when the caller expects a value — missing `return` in some branches. (Source: https://google.github.io/styleguide/pyguide.html.)
- Avoid mutating a list or dict argument in-place without documenting it, causing unexpected caller-side changes.
- Avoid using positional-only boolean flags (`do_thing(True, False)`) — the call site is unreadable; use keyword-only args.
- Avoid using a plain `dict` as a function's return type when a `@dataclass` would make fields explicit and type-checkable.
- Avoid defining `default_factory` as a mutable literal (e.g., `field(default=[])`) — always use `field(default_factory=list)`. (Source: https://peps.python.org/pep-0557/.)

---

### Python module structure — src/ layout, __init__/__all__ exports, layered/clean architecture, dependency inversion (ABC/Protocol, single composition root), no circular imports, absolute imports, pyproject.toml packaging (PEP 517/518/621, no setup.py), structured logging (structlog, no import-time config in libraries).
> Applies to: `**/*.py`

## Rules

1. Place all importable source under `src/<package_name>/`; never at the repo root. (Source: https://packaging.python.org/en/latest/discussions/src-layout-vs-flat-layout/)
2. Every `__init__.py` that re-exports symbols must define an explicit `__all__` list.
3. Use absolute imports exclusively — `from mypackage.x import Y`, never `from ..x import Y`. (Source: https://peps.python.org/pep-0008/)
4. Layer the codebase (API → Application → Domain → Infrastructure); inner layers must not import from outer layers. (Source: https://dev.to/markoulis/layered-architecture-dependency-injection-a-recipe-for-clean-and-testable-fastapi-code-3ioo)
5. Define layer boundaries as `ABC` subclasses or `Protocol` classes in the inner layer; outer layers provide the concrete implementation. (Source: https://arjancodes.com/blog/python-dependency-injection-best-practices/)
6. Assemble all concrete implementations in a single composition root — no application or domain module may instantiate infrastructure classes directly. (Source: https://arjancodes.com/blog/python-dependency-injection-best-practices/)
7. Circular imports are forbidden; extract shared concepts to a `types.py` or `interfaces.py` module that is imported by both sides.
8. Package exclusively with `pyproject.toml` (`[build-system]` PEP 518, `build-backend` PEP 517, `[project]` PEP 621); remove `setup.py` and `setup.cfg`. (Source: https://peps.python.org/pep-0517/ · https://peps.python.org/pep-0518/ · https://peps.python.org/pep-0621/)
9. In applications, configure structlog once at the entry point (`bootstrap.py` / `main.py`), never at import time. (Source: https://www.structlog.org/en/stable/logging-best-practices.html)
10. Libraries must never call `logging.basicConfig()`, `structlog.configure()`, or any logging-configuration function; obtain loggers with `structlog.get_logger(__name__)` only. (Source: https://www.structlog.org/en/stable/logging-best-practices.html)

## Rules

- **Use the `src/` layout.** Place all importable package code under `src/<package_name>/` so the installed package is tested, not the local source tree.
  Source: https://packaging.python.org/en/latest/discussions/src-layout-vs-flat-layout/

- **Declare public surfaces with `__all__`.** Every `__init__.py` that re-exports symbols must define `__all__` as an explicit list of strings. Unlisted names are internal and may change without notice.

- **Use absolute imports only.** Always write `from mypackage.services.user import UserService`, never `from ..services.user import UserService`. Absolute imports make the dependency graph readable and are required for reliable `src/` layout tooling.
  Source: https://peps.python.org/pep-0008/ (§ Imports)

- **Layer the architecture: API → Application → Domain → Infrastructure.** Dependencies point inward only — inner layers know nothing about outer layers.
  Source: https://dev.to/markoulis/layered-architecture-dependency-injection-a-recipe-for-clean-and-testable-fastapi-code-3ioo

- **Invert dependencies with `ABC` or `Protocol`.** Inner layers define an abstract interface; outer layers provide the concrete implementation. This keeps domain logic independent of frameworks and I/O drivers.
  Source: https://arjancodes.com/blog/python-dependency-injection-best-practices/
  Source: https://snyk.io/blog/dependency-injection-python/

- **Wire all concrete implementations in a single composition root.** One location (e.g. `src/<pkg>/bootstrap.py` or the DI container module) instantiates and assembles the full object graph. Application and domain modules never call constructors of infrastructure classes.
  Source: https://arjancodes.com/blog/python-dependency-injection-best-practices/

- **Eliminate circular imports by design.** If module A imports module B and B imports A, extract the shared concept into a third module (e.g. a `types.py` or `interfaces.py`) that neither A nor B imports from each other.

- **Package with `pyproject.toml` only — no `setup.py`.** Declare build-system requirements in `[build-system]` (PEP 518), use `build-backend` (PEP 517), and put all project metadata in `[project]` (PEP 621). Delete `setup.py`, `setup.cfg`, and `MANIFEST.in` if present.
  Source: https://peps.python.org/pep-0518/
  Source: https://peps.python.org/pep-0517/
  Source: https://peps.python.org/pep-0621/
  Source: https://packaging.python.org/en/latest/guides/writing-pyproject-toml/
  Source: https://packaging.python.org/en/latest/specifications/pyproject-toml/

- **Use structlog for structured logging in applications.** Configure it once at the application entry point (`bootstrap.py` / `main.py`), never at import time. Library code must accept a bound logger via dependency injection or use `structlog.get_logger()` without calling any configuration function.
  Source: https://www.structlog.org/en/stable/logging-best-practices.html
  Source: https://www.structlog.org/

- **Libraries must not configure logging.** A library that calls `logging.basicConfig()`, `structlog.configure()`, or any equivalent at import time corrupts the host application's logging setup. Libraries obtain a logger (`structlog.get_logger(__name__)`) and leave configuration entirely to the application.
  Source: https://www.structlog.org/en/stable/logging-best-practices.html

- Avoid placing package code at the repo root (`mypackage/` next to `tests/`) instead of under `src/` — this means `import mypackage` resolves to the local directory rather than the installed package, masking missing `__init__.py` files and import errors.
- Avoid exporting everything from `__init__.py` without an explicit `__all__`, making it impossible to distinguish the public API from internal helpers.
- Avoid using relative imports (`from .. import foo`) — they break under `src/` layout if a file is run directly and make refactoring harder.
- Avoid skipping `pyproject.toml` in favour of a bare `setup.py` or `setup.cfg`, which are legacy formats that do not support PEP 517 build isolation.
- Avoid importing a concrete infrastructure class (e.g. `PostgresRepository`) directly inside a domain service — this couples business logic to a driver and makes unit-testing require a live database.
- Avoid calling `structlog.configure()` or `logging.basicConfig()` inside a library module at module-level — the first import of the library silently changes the host app's logging.
- Avoid having more than one place that assembles the object graph, so the same interface is wired to different concrete implementations in different contexts (duplicated/conflicting composition roots).
- Avoid circular imports caused by placing shared types inline in a feature module that other modules also import — resolve by extracting shared types to a standalone `types.py` or `interfaces.py`.

---

### Python integration testing — DB/fixture teardown & isolation; unique test data; registered markers (--strict-markers); branch coverage (--cov-branch) + fail_under gate; coverage != quality (flag untested branches/error paths).
> Applies to: `**/*.py`

## Rules

1. Every DB-touching fixture must use `yield`-based teardown (rollback or delete) so cleanup runs even when the test fails. Source: https://docs.pytest.org/en/stable/how-to/fixtures.html
2. Wrap relational DB tests in a transaction that is rolled back after the test body; never rely on manual cleanup that can be skipped on error. Source: https://docs.pytest.org/en/stable/how-to/fixtures.html
3. Never hard-code shared identifiers (IDs, emails, usernames) as bare string literals in tests; generate unique values per test run using factories, `uuid.uuid4()`, or time-based suffixes. Source: https://docs.pytest.org/en/stable/explanation/goodpractices.html
4. Declare every custom marker in `[tool.pytest.ini_options] markers` in `pyproject.toml` and add `--strict-markers --strict-config` to `addopts`. Source: https://docs.pytest.org/en/stable/how-to/mark.html
5. Mark integration/slow tests with a registered marker (e.g. `@pytest.mark.integration`) and run them in a dedicated CI step, separate from the fast unit suite. Source: https://docs.pytest.org/en/stable/how-to/mark.html
6. Run coverage as `pytest --cov=<src_pkg> --cov-branch --cov-report=xml` — never `coverage run -m pytest`. Source: https://pytest-cov.readthedocs.io/en/latest/config.html · https://coverage.readthedocs.io/en/latest/branch.html
7. Set `[tool.coverage.report] fail_under = <N>` (minimum 80 for new projects) in `pyproject.toml` so coverage regressions break CI. Source: https://coverage.readthedocs.io/en/latest/cmd.html
8. Do not treat coverage percentage as a quality signal in isolation; explicitly review uncovered branches (exception handlers, early-return guards, loop `else` clauses) and add assertions or mark them `# pragma: no cover` with a documented reason. Source: https://coverage.readthedocs.io/en/latest/faq.html · https://hynek.me/articles/ditch-codecov-python/ · https://learn.scientific-python.org/development/guides/coverage/
9. Place integration-scope fixtures (DB sessions, connection pools) in a dedicated `conftest.py` co-located with the integration test directory; do not mix them into the unit `conftest.py`. Source: https://docs.pytest.org/en/stable/reference/fixtures.html
10. Use `# pragma: no cover` only for genuinely untestable lines (`if TYPE_CHECKING:`, `__main__` guards, platform branches); always add an inline comment explaining why. Source: https://coverage.readthedocs.io/en/latest/excluding.html

## Rules

- **DB/fixture teardown and isolation.** Each integration test must leave the database (or any external resource) in the same state it found it. Use pytest fixtures with the narrowest appropriate scope (`function` by default, `session` only for truly read-only shared state) and yield-based teardown (`yield` + cleanup) so rollback or deletion is guaranteed even on failure. Source: https://docs.pytest.org/en/stable/how-to/fixtures.html

- **Transaction-scoped rollback for DB tests.** Wrap each test in a transaction and roll it back after the test body; never rely on manual `DELETE` statements that can be skipped on error. This is the canonical isolation strategy for relational DBs. Source: https://docs.pytest.org/en/stable/how-to/fixtures.html

- **Unique, generated test data.** Never hard-code IDs, usernames, or email addresses as bare string literals shared across tests. Use factories (e.g. factory_boy), `uuid.uuid4()`, or time-based suffixes to guarantee uniqueness and prevent inter-test coupling. Source: https://docs.pytest.org/en/stable/explanation/goodpractices.html

- **Register all custom markers; run with `--strict-markers`.** Every `@pytest.mark.<name>` must be declared in `[tool.pytest.ini_options] markers` in `pyproject.toml`. Add `--strict-markers` (and `--strict-config`) to the `addopts` line so an unregistered marker raises an error rather than silently passing. Source: https://docs.pytest.org/en/stable/how-to/mark.html

- **Enable branch coverage with `--cov-branch`.** Run `pytest --cov=<src_pkg> --cov-branch` (never `coverage run -m pytest`) to capture decision-branch data. Report as `coverage.xml` for CI consumption. Source: https://coverage.readthedocs.io/en/latest/branch.html · https://pytest-cov.readthedocs.io/en/latest/config.html

- **Enforce a `fail_under` gate in CI.** Set `[tool.coverage.report] fail_under = <N>` in `pyproject.toml` (project default: 80; raise per-project) so coverage regressions break the build automatically. Source: https://coverage.readthedocs.io/en/latest/cmd.html

- **Coverage percentage is not a quality proxy.** A line or branch executed by a test that never asserts correctness is covered but untested in any meaningful sense. Prefer targeted assertions over coverage-padding tests. Explicitly flag uncovered branches and error paths (e.g. exception handlers, early-return guards, `else` clauses on loops) rather than silencing them with `# pragma: no cover` without justification. Source: https://coverage.readthedocs.io/en/latest/faq.html · https://hynek.me/articles/ditch-codecov-python/ · https://learn.scientific-python.org/development/guides/coverage/

- **Keep integration and unit markers separate.** Mark slow/external-dependency tests with `@pytest.mark.integration` (or `@pytest.mark.slow`) and run them separately in CI from the fast unit suite. Source: https://docs.pytest.org/en/stable/how-to/mark.html

- **Use `conftest.py` for shared integration fixtures.** Place DB connection fixtures, session factories, and other integration-scope setup in the nearest `conftest.py` to the integration test directory, not in the unit `conftest.py`. Source: https://docs.pytest.org/en/stable/reference/fixtures.html

- **Exclude only genuinely untestable lines from coverage.** Use `# pragma: no cover` sparingly and only for platform-specific branches, `if TYPE_CHECKING:` blocks, and `__main__` guards. Document the reason inline. Source: https://coverage.readthedocs.io/en/latest/excluding.html

- Avoid sharing hard-coded test records (fixed IDs, emails, usernames) across tests — causes order-dependent failures and flaky CI.
- Avoid using function-scope DB fixtures that commit data without rollback, leaving pollution for subsequent tests.
- Avoid adding `@pytest.mark.integration` (or any custom marker) without declaring it in `pyproject.toml markers` — silently ignored unless `--strict-markers` is active.
- Avoid running `coverage run -m pytest` instead of `pytest --cov` — inconsistent configuration and misses `pytest-cov` integration.
- Avoid setting a `fail_under` gate of 0 or omitting it entirely — coverage regressions pass undetected.
- Avoid writing tests whose only effect is hitting lines (no assertions) to bump the coverage number — produces false confidence.
- Avoid applying `# pragma: no cover` to an entire error-handling block without comment — hides real gaps.
- Avoid using `session`-scoped fixtures for data that mutates between tests — leads to hidden coupling.
- Avoid forgetting `--strict-config` alongside `--strict-markers` in `addopts` — allows invalid ini keys to pass silently.

---

### pytest unit-testing conventions — plain assert, test_*.py discovery, fixture scoping, parametrize, mocker/autospec, Hypothesis. Applies to all Python test files.
> Applies to: `**/*.py`

## Rules

1. Use plain `assert` statements; never use `unittest.TestCase` assertion methods inside pytest tests. (https://docs.pytest.org/en/stable/how-to/assert.html)
2. Name test files `test_*.py` or `*_test.py`; mirror the source package structure under `tests/`. (https://docs.pytest.org/en/stable/explanation/goodpractices.html)
3. Name every test function `test_<unit>_<scenario>_<expected>`. (https://docs.pytest.org/en/stable/explanation/goodpractices.html)
4. Use `@pytest.fixture` instead of `setUp`/`tearDown`; place shared fixtures in `conftest.py`. (https://docs.pytest.org/en/stable/how-to/fixtures.html)
5. Declare fixtures at the narrowest scope that satisfies the test; default is `scope="function"`; only widen to `"module"` or `"session"` for provably read-only resources. (https://docs.pytest.org/en/stable/how-to/fixtures.html)
6. Always pass `ids=[...]` to `@pytest.mark.parametrize` so test node IDs are human-readable. (https://docs.pytest.org/en/stable/how-to/parametrize.html)
7. Assert expected exceptions with `pytest.raises(ExcType, match=r"...")`, never without `match`. (https://docs.pytest.org/en/stable/how-to/assert.html)
8. Use `mocker.patch(..., autospec=True)` from `pytest-mock` for all mocks; never leave `autospec` off. (https://pytest-mock.readthedocs.io/en/latest/usage.html · https://docs.python.org/3/library/unittest.mock.html)
9. Patch at the import site used by the module under test, not at the definition site. (https://docs.python.org/3/library/unittest.mock-examples.html)
10. Apply `@hypothesis.given` to pure functions with well-defined contracts; do not use Hypothesis for stateful or I/O-heavy tests. (https://hypothesis.readthedocs.io/en/latest/tutorial/introduction.html)

## Rules

- **Use pytest plain `assert` with rewriting** — pytest rewrites `assert` expressions at collection time to produce detailed introspection output on failure; never use `assertEqual`/`assertTrue` or `unittest.TestCase` assertions in pytest tests. Source: https://docs.pytest.org/en/stable/how-to/assert.html

- **Follow `test_*.py` / `*_test.py` file naming** — pytest discovers tests in files matching `test_*.py` or `*_test.py` by default; keep test files alongside the source tree or under a top-level `tests/` directory with the same sub-package structure. Source: https://docs.pytest.org/en/stable/explanation/goodpractices.html

- **Name tests `test_<unit>_<scenario>_<expected>`** — a three-part name (`test_parse_empty_string_returns_none`) makes the intent explicit without reading the body; it also serves as executable documentation. Source: https://docs.pytest.org/en/stable/explanation/goodpractices.html

- **Use fixtures over `setup`/`teardown`** — pytest fixtures are composable, type-annotated, and respect scope; replace `setUp`/`tearDown` class methods and module-level globals with `@pytest.fixture` functions. Shared fixtures belong in `conftest.py`, discovered automatically by pytest without explicit imports. Source: https://docs.pytest.org/en/stable/how-to/fixtures.html · https://docs.pytest.org/en/stable/reference/fixtures.html

- **Use the narrowest fixture scope that satisfies the test** — declare `scope="function"` (the default) unless the fixture is provably read-only, in which case `scope="module"` or `scope="session"` is acceptable; over-scoped fixtures cause hidden state leakage between tests. Source: https://docs.pytest.org/en/stable/how-to/fixtures.html

- **Parametrize with explicit `ids`** — `@pytest.mark.parametrize("x,y", [...], ids=[...])` produces human-readable node IDs; without `ids`, pytest auto-generates numeric suffixes that obscure what scenario failed. Source: https://docs.pytest.org/en/stable/how-to/parametrize.html

- **Assert exceptions with `pytest.raises(ExcType, match=...)`** — the `match` argument compiles a regex against the string representation of the exception value, confirming both type and message; omitting `match` tests only the exception type, leaving the message unverified. Source: https://docs.pytest.org/en/stable/how-to/assert.html

- **Prefer `pytest-mock`'s `mocker` fixture over bare `unittest.mock.patch`** — `mocker.patch` automatically undoes patches after the test without requiring a context manager or manual `addCleanup`; use `autospec=True` on every mock to catch call-signature mismatches at test time. Source: https://pytest-mock.readthedocs.io/en/latest/usage.html · https://docs.python.org/3/library/unittest.mock.html

- **Patch at the import site, not the definition site** — mock the name as it is looked up in the module under test (e.g. `myapp.service.requests.get`), not where `requests.get` is defined; patching the wrong namespace leaves the real code unchanged. Source: https://docs.python.org/3/library/unittest.mock-examples.html · https://realpython.com/python-mock-library/

- **Use Hypothesis for property-based / invariant testing** — `@given(st.text())` generates hundreds of examples automatically and shrinks counter-examples to minimal reproducible inputs; apply it to pure functions with well-defined contracts (parsers, encoders, data transformations). Source: https://hypothesis.readthedocs.io/en/latest/tutorial/introduction.html

- Avoid using `assert x == True` instead of `assert x` — defeats pytest's rewriting and produces weaker failure messages.
- Avoid defining fixtures in test modules instead of `conftest.py` — fixtures defined outside `conftest.py` cannot be shared across files without explicit imports.
- Avoid using `scope="session"` on fixtures that mutate state — causes test-order dependency; a test that passes alone may fail in CI due to leftover state.
- Avoid calling `@pytest.mark.parametrize` without `ids` — node IDs like `test_add[1-2-3]` instead of `test_add[positive_integers]` make failure reports hard to read.
- Avoid writing `with pytest.raises(ValueError):` without `match` — only confirms the type; a completely different error message goes undetected.
- Avoid using `mocker.patch("requests.get")` when the SUT imports `from requests import get` — the mock patches the wrong binding and the real function is called.
- Avoid creating mocks without `autospec=True` — allows calling the mock with the wrong arguments; the bug is invisible until production.
- Avoid relying on Hypothesis for integration scenarios — `@given` is for pure-function invariants; stateful/DB tests should use pytest fixtures with controlled data, not property strategies.
- Avoid over-asserting implementation details (`assert mock.call_count == 3`) instead of observable behaviour — brittle tests that break on valid refactors.

---

### Python type hints everywhere — modern generics (list[int]/dict[str,int]/X | None, Python 3.10+), Protocol structural typing, pyright/basedpyright strict mode, py.typed marker (PEP 561). Applies to all .py files.
> Applies to: `**/*.py`

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

## Rules

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

- Avoid using `Optional[X]` or `Union[X, Y]` in new code instead of the modern
  `X | None` / `X | Y` syntax (requires Python 3.10+; add
  `from __future__ import annotations` for 3.9 files if back-compat is needed).
- Avoid importing `List`, `Dict`, `Tuple`, `Set`, `FrozenSet` from `typing` in new
  code — use the built-in types directly.
- Avoid annotating only the "happy path" return type and omitting `None` when the
  function can return `None` under some branch — this produces false negatives
  in pyright's strict mode.
- Avoid skipping the return type annotation on `__init__` (should be `-> None`) and
  on coroutines (should be `-> Coroutine[Any, Any, T]` or `-> T` wrapped in
  `async def`).
- Avoid using `type: ignore` comments without a specific error code
  (`# type: ignore[attr-defined]`) — blanket ignores mask real bugs.
- Avoid publishing a library without a `py.typed` marker, forcing downstream type
  checkers to treat all imports from it as `Any`.
- Avoid declaring `Protocol` classes with methods that accept `self: Any` — this
  defeats the structural check and allows any class to satisfy the protocol
  silently.
- Avoid running pyright in basic (default) mode and assuming the project is
  type-safe; strict mode is required.

---
