# .NET DTO Validation Analysis

> Analyze DTO structure, FluentValidation/DataAnnotations usage, mapping patterns, and response shape safety.

---

Goal: Analyze DTO files for proper validation, mapping, and
response-shape safety.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/dotnet/dto-validation.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/dotnet/dto-validation.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **DTO Shape & Immutability**:
    *   **Records Where Appropriate**: Check that DTOs are implemented
        as `record` types (or `record struct` for small value-like
        payloads) so they get value equality and `init`-only properties
        for free, rather than mutable classes with settable properties.
    *   **Init-Only Properties**: Where a class is used instead of a
        record, verify properties use `init` (not open `set`) so the DTO
        is immutable once constructed/bound.

2.  **DTO Separation**:
    *   **Create/Update/Response Split**: Check for distinct
        `CreateXRequest`, `UpdateXRequest`, and `XResponse` DTOs per
        resource — flag any endpoint that binds directly to, or returns,
        the EF Core entity type.
    *   **No Entity Leakage**: Verify controllers/handlers never return
        an entity directly from an action (`return Ok(user)` where `user`
        is the EF Core entity) — every outbound payload must go through an
        explicit response DTO.
    *   **Partial Update Shape**: For partial updates, check that the
        update DTO models only the fields that are actually patchable
        (nullable value types / nullable reference types for "not
        supplied"), rather than reusing the full create DTO.

3.  **Validation Coverage**:
    *   **FluentValidation**: Check for an `AbstractValidator<T>`
        registered per inbound DTO (via `AddValidatorsFromAssembly` or
        explicit `services.AddScoped<IValidator<T>, TValidator>()`) with
        rules for every user-facing property (`RuleFor(x => x.Email)
        .NotEmpty().EmailAddress()`, `RuleFor(x => x.Name).MaximumLength(...)`,
        etc.).
    *   **DataAnnotations Fallback**: Where FluentValidation is not used,
        check for equivalent coverage via DataAnnotations
        (`[Required]`, `[StringLength]`, `[EmailAddress]`, `[Range]`,
        `[RegularExpression]`) and that `ApiController`-attributed
        controllers have automatic model validation enabled (not
        suppressed via `SuppressModelStateInvalidFilter`).
    *   **Nested/Collection Validation**: Check for `RuleForEach` (or
        `[ValidateNever]`/nested `[Required]` + custom validator) on
        collection properties and nested object properties, so validation
        does not stop at the top level.

4.  **Sensitive Field Exclusion**:
    *   **No Secrets Over the Wire**: Verify response DTOs never expose
        password hashes, security stamps, refresh tokens, API keys, or
        other credential material — these fields must simply not exist on
        the response DTO type.
    *   **Explicit Projection**: Check that the mapping from entity to
        response DTO explicitly selects fields (constructor, object
        initializer, or a mapper profile) rather than reflection-based
        "map everything" helpers that could accidentally carry a new
        sensitive entity property into a response.

5.  **Entity-DTO Mapping**:
    *   **Explicit Mapping Present**: Check for an explicit mapping step
        between entity and DTO — a mapping method, extension method, or
        AutoMapper/Mapster profile — rather than serializing the entity
        directly.
    *   **No Navigation Property Leakage**: Flag entities serialized (or
        mapped 1:1) with EF Core navigation properties intact, which risks
        reference cycles (`JsonException: A possible object cycle was
        detected`) or over-fetching unrelated related data into the
        response.
    *   **AutoMapper/Mapster Config Sanity**: If a mapping library is
        used, check that sensitive/internal members are explicitly
        ignored (`.ForMember(d => d.PasswordHash, opt => opt.Ignore())`)
        rather than assumed safe by convention.

6.  **Nullable Semantics on DTO Properties**:
    *   **Required vs. Optional**: Check that non-nullable reference-type
        properties (or value types without `?`) represent fields that are
        truly required on the wire, and that optional fields are modeled
        as nullable (`string?`, `int?`) — a mismatch here (e.g. a
        non-nullable property with `[IsOptional]`-equivalent validation)
        indicates the DTO's nullability doesn't reflect its actual
        contract.
    *   **Consistent with Validator**: Cross-check that a property marked
        required by nullability is also enforced by a `NotEmpty()`/
        `[Required]` rule, and vice versa — nullability and validation
        rules should agree, not contradict each other.

OUTPUT FORMAT:

Produce one entry per violation found:
*   **File**: `path/to/Dto.cs:17`
*   **Standard Violated**: `dto-validation.md`
*   **Severity**: `Critical` | `Major` | `Minor`
*   **Issue**: One-line description of the violation.
*   **Suggested Fix**: One-line recommended remediation.

Group violations by category (`[Shape Issue]`, `[Separation Issue]`,
`[Validation Issue]`, `[Security Issue]`, `[Mapping Issue]`,
`[Nullability Issue]`) before listing the per-violation records. Treat
any sensitive-field exposure as `Critical` regardless of how minor it
otherwise looks.

SCORING GUIDANCE:

*   **Strong (85-100)**: Every inbound DTO is a record with full
    FluentValidation (or DataAnnotations) coverage on user-facing
    properties, Create/Update/Response DTOs are cleanly separated,
    entities are never returned or bound directly, mapping is explicit
    with no navigation-property leakage, and nullability on DTO
    properties accurately reflects required-vs-optional semantics.
*   **Fair (70-84)**: DTOs are mostly separated and validated, but with
    isolated gaps — a missing validator on one property, an update DTO
    that reuses the create DTO's shape, or a nullability annotation that
    doesn't quite match the validator — with no sensitive-data exposure.
*   **Weak (0-69)**: Entities are bound or returned directly, validation
    coverage is sparse or absent, sensitive fields (passwords, tokens,
    security stamps) are exposed in a response DTO, or entity-DTO mapping
    is missing/implicit enough to risk serialization cycles or field
    leakage.
