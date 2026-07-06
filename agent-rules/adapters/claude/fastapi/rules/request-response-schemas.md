### FastAPI request/response schemas — Pydantic input models, dedicated response_model/return-type output models, and field filtering as a security boundary. Layers on the python stack's data-validation rules.
> Applies to: `**/*.py`
## Rules

1. Every request body parameter and every route response must use a Pydantic model; bare `dict` return types and untyped `dict` bodies are forbidden.
2. Declare a dedicated output model (e.g. `*Public`, `*Response`) per endpoint or endpoint group that excludes all secrets and server-controlled fields; never return an ORM instance directly.
3. Structure schemas in per-operation families — `Base` / `*Create` / `*Update` (all fields `Optional`) / `*Public` — so that write-only, read-only, and mutable fields cannot be mixed accidentally.
4. Prefer the return-type annotation (`-> MySchema`) over `response_model=MySchema`; use `response_model=` only when the return type and the serialized shape genuinely differ.
5. Never use `response_model_include` or `response_model_exclude` as a security measure — they do not remove fields from the OpenAPI schema and must not be relied upon to hide sensitive data.
6. Enforce input constraints (formats, ranges, cross-field invariants) with Pydantic validators that raise `ValueError`; FastAPI converts these automatically to a 422 with a structured error body.

## Rules

- Declare every request body and every response as a dedicated Pydantic model — never accept or return a bare `dict`. ([response-model](https://fastapi.tiangolo.com/tutorial/response-model/), [zk](https://github.com/zhanymkanov/fastapi-best-practices))
- Always declare a distinct *output* model (e.g. `UserPublic`) that explicitly excludes server-controlled fields and secrets such as `hashed_password`, `internal_id`, or audit timestamps — output filtering is a **security boundary**, not a cosmetic choice. ([response-model](https://fastapi.tiangolo.com/tutorial/response-model/), [sql](https://fastapi.tiangolo.com/tutorial/sql-databases/))
- Use per-operation model families: a shared `Base` carries common fields; `*Create` adds write-only fields; `*Update` makes every field `Optional` for partial updates; `*Public` is the safe read projection. This pattern avoids accidental field leakage as schemas evolve. ([sql](https://fastapi.tiangolo.com/tutorial/sql-databases/))
- Prefer the **return-type annotation** on the path-operation function (e.g. `-> UserPublic`) over the `response_model=` parameter — it is more concise, is checked by type-checkers, and produces the same OpenAPI output. ([response-model](https://fastapi.tiangolo.com/tutorial/response-model/))
- Surface input domain validation errors as `ValueError` (or a Pydantic `field_validator` raising `ValueError`) so FastAPI converts them automatically to a structured 422 response. ([zk](https://github.com/zhanymkanov/fastapi-best-practices))
- Use `response_model_exclude_unset=True` on endpoints that return partial/sparse projections so fields that were never set are omitted from the JSON body rather than serialized as `null`. ([response-model](https://fastapi.tiangolo.com/tutorial/response-model/))
- For field-level validation logic (formats, cross-field invariants, business constraints) defer to `python/data-validation.md`; this file covers only FastAPI-specific wiring of those models into route declarations and response filtering.

- Avoid returning an ORM/table model instance directly from a route handler — this leaks columns such as `hashed_password` or internal foreign keys to the client. Always map the ORM row to a `*Public` Pydantic schema before returning. ([response-model](https://fastapi.tiangolo.com/tutorial/response-model/), [sql](https://fastapi.tiangolo.com/tutorial/sql-databases/))
- Avoid using a single model for create, update, and read operations: a field required on creation (e.g. `password`) must not appear in read responses, and optional update fields must not accidentally become required on create. ([sql](https://fastapi.tiangolo.com/tutorial/sql-databases/))
- Avoid relying on `response_model_include` or `response_model_exclude` to hide sensitive fields: FastAPI still generates an OpenAPI schema from the *full* model, so the excluded fields remain visible in the docs and in generated clients — this is **not a security mechanism**. ([response-model](https://fastapi.tiangolo.com/tutorial/response-model/))
- Avoid skipping `response_model` / return-type annotations entirely and letting FastAPI serialize whatever the handler returns: this removes OpenAPI documentation, disables output validation, and makes future refactors silently break the API contract. ([response-model](https://fastapi.tiangolo.com/tutorial/response-model/))
