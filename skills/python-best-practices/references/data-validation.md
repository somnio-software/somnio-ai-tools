# Python Data Validation Analysis

> Analyze data validation practices — pydantic models at input boundaries, field validators and constraints, absence of unvalidated dict passing, typed response models, and pydantic-settings configuration — based on somnio-software standards.

---

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/python/data-validation.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/python/data-validation.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1. **Pydantic at boundaries**:
   - Verify every external input (HTTP body, queue message, file parse, external API response) is parsed through a `pydantic.BaseModel` before being passed inward.
   - Flag raw `dict` values from `json.loads`, `request.json()`, or ORM row-as-dict that are not immediately fed into `Model.model_validate()` or `Model(**data)`.

2. **Field validators and constraints**:
   - Check that value constraints (`gt`, `min_length`, `pattern`, `max_length`, etc.) are declared with `Field(...)` on the model — not validated in handler or service code after the model is constructed.
   - Verify cross-field invariants (e.g., end date after start date) are implemented in `@field_validator` or `@model_validator`, not in application logic.

3. **No unvalidated `dict` across layer boundaries**:
   - Flag `dict` or `Any` used as function parameters or return types for structured data where a typed pydantic model should be used.
   - The one permitted exception: `model.model_dump()` going into a persistence or transport layer (deliberate serialisation, not bypassed validation).
   - Flag use of deprecated `model.dict()` (v1 API) — must be `model.model_dump()` (v2 API).

4. **Typed responses**:
   - Verify every public endpoint and service method that produces structured data annotates its return type as a pydantic `BaseModel` or `list[MyModel]`.
   - Flag `dict` or `Any` return types on functions producing structured data.

5. **pydantic-settings configuration**:
   - Check that application configuration is loaded via `pydantic-settings BaseSettings`.
   - Verify required environment variables have no default (so missing variables raise `ValidationError` at startup — fail-fast).
   - Flag `Settings()` instantiated inside request handlers or service methods — must be instantiated once at module level or via a cached factory.
   - Flag sensitive secrets stored as field defaults in `BaseSettings`.
   - Verify `model_config = ConfigDict(frozen=True)` is applied to settings and immutable value objects.

6. **ValidationError handling**:
   - Verify `pydantic.ValidationError` is caught at boundary layers and translated to a domain or HTTP error.
   - Flag `ValidationError` that is allowed to propagate unhandled into the service or domain layer.

OUTPUT FORMAT:
- **Overview**: Total files analyzed, boundary validation coverage estimate, compliance score (1-10).
- **Violations**: List specific violations.
  - Format: `path/to/file.py:XX` — [Issue]
- **Compliance**: Highlight well-validated boundary modules or correctly structured pydantic models found in the codebase.
- **Recommendations**: Specific refactoring suggestions for each violation category.
