---
description: Python data-validation conventions — pydantic models at input boundaries, field validators/constraints, no unvalidated dict, typed response models, pydantic-settings BaseSettings for 12-factor configuration. Applies to all .py files.
globs: **/*.py
alwaysApply: false
---

## Best Practices

- **Validate at every external boundary with a pydantic `BaseModel`.** HTTP request bodies, CLI arguments, message-queue payloads, file-parsed data, and external API responses must each be parsed through a pydantic model before the value is used anywhere in application code. Raw `dict` values from `json.loads`, `request.json()`, or ORM row-as-dict are never passed inward — they are fed to `Model.model_validate()` or `Model(**data)` immediately at the boundary. ([https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/))

- **Declare constraints inline with `Field(...)`.** Use `Field(gt=0)`, `Field(min_length=1)`, `Field(pattern=r"^\w+$")`, `Field(max_length=255)` etc. rather than validating in application logic after the fact. Pydantic raises `ValidationError` before the model instance is returned, guaranteeing the object is always valid. ([https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/))

- **Prefer `@field_validator` and `@model_validator` for cross-field invariants.** Custom business rules that cannot be expressed with `Field` constraints (e.g., "end date must be after start date") belong in `@field_validator('end_date', mode='after')` or `@model_validator(mode='after')`, not in service/handler code that receives the model. ([https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/))

- **Never pass unvalidated `dict` objects across layer boundaries.** Passing `dict` instead of a model loses type information and bypasses validation. If a downstream function accepts a `dict`, it should be refactored to accept the model. The one permitted exception is serialisation output (`model.model_dump()`) going into a persistence or transport layer — that is a deliberate serialisation step, not bypassed validation.

- **Return typed response models from every public endpoint or service method.** Every function that produces structured data for a caller should annotate its return type as a pydantic `BaseModel` (or `list[MyModel]`). Using `dict` or `Any` as a return type for structured data is forbidden. ([https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/))

- **Load application configuration through `pydantic-settings BaseSettings`, built once at the application edge, not on first use.** Each required environment variable is declared as a typed field with no default (or `...`). Missing variables raise `ValidationError` on startup — fail-fast, before any request is handled. Optional variables carry a typed default. This implements the 12-factor config principle: config from the environment, never from code. ([https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/), [https://medium.com/datamindedbe/twelve-factor-python-applications-using-pydantic-settings-f74a69906f2f](https://medium.com/datamindedbe/twelve-factor-python-applications-using-pydantic-settings-f74a69906f2f))

- **Instantiate `Settings` once at module level or via a cached factory; inject it into components.** Do not call `Settings()` inside a request handler or service method — doing so re-parses the environment on every invocation and hides startup failures. ([https://medium.com/datamindedbe/twelve-factor-python-applications-using-pydantic-settings-f74a69906f2f](https://medium.com/datamindedbe/twelve-factor-python-applications-using-pydantic-settings-f74a69906f2f))

- **Use `model_config = ConfigDict(frozen=True)` for settings and immutable value objects.** Frozen models prevent accidental mutation and are hashable. Request/command models that should not be mutated after parsing also benefit from `frozen=True`. ([https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/))

- **Catch `pydantic.ValidationError` at boundaries and translate to a domain or HTTP error.** Do not let `ValidationError` propagate as an unhandled exception into the middle tier. Translate it at the edge (e.g., HTTP 422 Unprocessable Entity) and log the structured error details. ([https://docs.pydantic.dev/latest/api/pydantic_settings/](https://docs.pydantic.dev/latest/api/pydantic_settings/))

## Common Mistakes

- Accepting `dict` or `Any` as a function parameter for "flexibility" — this silently removes all validation and type safety across the call stack.
- Calling `Settings()` inside request handlers or service constructors — configuration is re-parsed on every call and missing-variable errors appear at runtime rather than startup.
- Declaring `Optional[str]` with no default (implicitly `None`) for a required environment variable — pydantic-settings will silently use `None` instead of raising on a missing env var. Use `str` with no default to make the field required.
- Validating business rules (e.g., range checks, cross-field consistency) in handler code after the model is already constructed — these rules belong in `@field_validator` / `@model_validator` so validation is centralised and reusable.
- Using `model.dict()` (v1 API) instead of `model.model_dump()` (v2 API) — the v1 alias is deprecated and will be removed.
- Constructing response data as a plain `dict` and returning it — callers lose type information and pydantic's serialisation guarantees. Construct and return the typed response model.
- Mutating a parsed model after construction to "patch" data — validation runs only at construction time. If the data needs adjustment, adjust the input before parsing or use a validator.
- Putting sensitive defaults (e.g., development secrets) as field defaults in `BaseSettings` — defaults are code, not config, and violate 12-factor principle III.

## Purpose

Data validation rules enforce that invalid data is rejected as early as possible — at the process boundary — before it propagates into business logic, databases, or external services. Centralising validation in pydantic models means every caller gets the same guarantees without duplicating checks. Using `pydantic-settings BaseSettings` for configuration applies the same fail-fast principle to environment variables: misconfigured deployments crash at startup with a clear error rather than failing silently during the first request. Together these practices eliminate an entire class of runtime errors caused by unvalidated input.

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
