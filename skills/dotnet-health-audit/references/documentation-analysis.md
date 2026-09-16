# .NET Health Audit Documentation Analysis

> Review technical documentation, XML doc comments, Swagger/OpenAPI reachability, and environment setup instructions for ASP.NET Core Web API projects.

---

Goal: Review all technical documentation in the ASP.NET Core Web API
project to evaluate documentation completeness and developer
experience quality.

IMPORTANT: Apply REASONABLE production standards. Focus on whether a
new developer could clone the repo and get a working local
environment without asking a teammate, not on documentation for its
own sake.

ANALYSIS TARGETS:

1. **README Quality**:
   - Check `README.md` exists in the repository/solution root
   - Verify README contains:
     * Project description
     * Prerequisites (.NET SDK version, e.g. .NET 8 SDK)
     * Restore/build instructions (`dotnet restore`, `dotnet build`)
     * Run instructions (`dotnet run`, or the relevant startup
       project if a multi-project solution)
     * Test instructions (`dotnet test`)
     * Required configuration documented (`appsettings.json` keys,
       required environment variables, user secrets setup via
       `dotnet user-secrets`)
     * Database setup instructions (connection string configuration,
       running EF Core migrations: `dotnet ef database update`)
   - Note missing sections

2. **Environment Setup Documentation**:
   - Check for an `appsettings.Development.json.example`,
     `appsettings.example.json`, or a documented list of required
     configuration keys/environment variables in the README
   - Verify sensitive configuration (connection strings, API keys,
     JWT signing keys) is NOT committed in `appsettings.json` — should
     be sourced via user secrets, environment variables, or a secrets
     manager, with only placeholder/example values checked in
   - Flag if `appsettings.Development.json` (or similar) containing
     real secrets is committed without a corresponding `.gitignore` entry

3. **XML Documentation Comments**:
   - Check the `.csproj` for `<GenerateDocumentationFile>true</GenerateDocumentationFile>`
   - Check for `<summary>` tags on public controllers/endpoint
     classes, service interfaces, and non-trivial public methods
   - Check for `<NoWarn>CS1591</NoWarn>` (or equivalent
     `#pragma warning disable CS1591`) suppressing the "missing XML
     comment on publicly visible type or member" warning:
     * If suppressed project-wide AND public APIs are largely
       undocumented: flag as documentation debt, not a genuine
       decision to document
     * If suppressed only for generated/non-public-surface code with
       real `<summary>` coverage elsewhere: acceptable
   - Sample a handful of public controller actions/service interfaces
     to gauge documented vs undocumented ratio — do not require
     exhaustive line-by-line coverage

4. **API Documentation (Swagger/OpenAPI)**:
   - Check whether Swagger UI is actually reachable: `app.UseSwaggerUI()`
     (Swashbuckle) or `app.MapOpenApi()`/Scalar/other UI registered in
     `Program.cs`, and not gated behind `if (app.Environment.IsDevelopment())`
     in a way that leaves no documented way to view it elsewhere
   - Cross-reference quality findings with the API design analysis:
     tags/grouping, `[ProducesResponseType]` coverage, and whether XML
     comments (from item 3) are wired into Swagger via
     `IncludeXmlComments(...)`
   - REASONABLE: gating Swagger UI to Development/Staging only is a
     legitimate production security choice — note it as such, don't
     flag it as missing documentation if the setup is intentional and
     the README explains how to reach it locally

5. **Architecture Documentation** (optional, nice-to-have):
   - Check for a `docs/` directory with architecture notes, ADRs
     (Architecture Decision Records), or a solution-structure
     explanation (especially valuable for Clean Architecture
     multi-project solutions where the layering isn't self-evident)
   - Check for inline `README.md` files in major project folders
     explaining a feature/module's structure
   - NEUTRAL: absence is not a strong penalty for small, single-project
     services where the structure is already obvious

6. **Contributing Documentation**:
   - Check for `CONTRIBUTING.md`
   - Check for `CHANGELOG.md`
   - Note if git conventions (branch naming, commit format) are documented

EXCLUDE FROM SCOPE:
- Do NOT recommend adding `CODEOWNERS`, `SECURITY.md`, or operational/
  deployment runbooks (CI/CD pipeline docs, infrastructure-as-code
  runbooks, on-call procedures) — these are governance/ops decisions,
  not technical documentation requirements for this audit

OUTPUT FORMAT:

Provide structured analysis:
- README present: [Yes/No]
- README quality: [Comprehensive/Basic/Missing]
- Environment/configuration setup documented: [Yes/No]
- Secrets committed in configuration files: [Yes/No]
- XML documentation:
  * `GenerateDocumentationFile` enabled: [Yes/No]
  * Coverage signal: [High/Medium/Low/None]
  * `CS1591` suppressed: [Yes - broadly / Yes - narrowly / No]
- Swagger/OpenAPI UI reachable: [Yes/No/Dev-only by design]
- CONTRIBUTING.md present: [Yes/No]
- docs/ folder or ADRs present: [Yes/No/Partial]
- Missing critical documentation
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Comprehensive README covering prerequisites, restore/build/run/test
  commands, required configuration, and database/migration setup
- Required configuration keys documented (example file or README
  section), no real secrets committed
- XML doc comments present on public controllers/services with
  `GenerateDocumentationFile` enabled and genuinely documented (not
  blanket `CS1591` suppression masking undocumented APIs)
- Swagger/OpenAPI UI reachable (or deliberately Dev-only, with that
  documented) and well-configured

Fair (70-84):
- README present but missing some sections (e.g. no migration/database
  setup instructions, or prerequisites not listed)
- Configuration keys partially documented
- Some XML doc coverage on public APIs, or `CS1591` suppressed without
  full replacement documentation
- Swagger/OpenAPI enabled but minimally configured

Weak (0-69):
- No README or a minimal one with no setup instructions
- No documented configuration/environment setup, or secrets committed
  in tracked configuration files
- No XML documentation and no Swagger/OpenAPI documentation
- No indication of how to run migrations or set up the database locally
