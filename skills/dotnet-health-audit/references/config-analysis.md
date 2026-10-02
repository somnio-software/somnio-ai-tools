# .NET Health Audit Configuration Analysis

> Read and analyze ASP.NET Core (.NET 8) project and MSBuild configuration files for environment setup, secret management, and build/tooling maturity.

---

Goal: Read and analyze .NET project/build configuration files to
verify environment-specific settings are correct, secrets are not
hardcoded, and modern build tooling conventions are in place.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire analysis
- Read multiple config files per tool call using parallel reads (3-5
  files per response)
- Use batch grep commands instead of reading files one by one
- Reference cached artifacts from previous steps when available (e.g.
  the `.csproj` list from repository-inventory)

APPSETTINGS HIERARCHY:

1. **appsettings hierarchy**:
   - Locate `appsettings.json` and any `appsettings.{Environment}.json`
     files (`appsettings.Development.json`,
     `appsettings.Staging.json`, `appsettings.Production.json`)
   - Verify environment-specific files actually override meaningful
     settings (connection strings, logging levels, feature flags) and
     are not empty placeholders
   - Verify `appsettings.Production.json` does NOT contain hardcoded
     secrets (connection strings with real credentials, API keys,
     JWT signing keys) — production secrets should come from
     environment variables, Azure Key Vault, AWS Secrets Manager, or
     similar, injected at deploy time
   - Verify `appsettings.Development.json` does not contain real
     production-like secrets either — local secrets should use User
     Secrets instead

USER SECRETS:

2. **User Secrets**:
   - Check the main API `.csproj` for a `<UserSecretsId>` element
     (a GUID), which indicates `dotnet user-secrets` is configured for
     local development
   - Presence is a strength: recommended over storing secrets in
     `appsettings.Development.json`
   - Absence is not critical if the team instead relies purely on
     environment variables locally, but note it as a missed convenience

LAUNCH SETTINGS:

3. **launchSettings.json**:
   - Locate `Properties/launchSettings.json` in the main API project
   - Verify launch profiles exist (`http`, `https`, `IIS Express`, or
     container profile)
   - It is fine for this file to be committed — but flag if
     `environmentVariables` in any profile contains what looks like a
     real secret or connection string (as opposed to a local
     placeholder like `Server=localhost;Database=devdb;Trusted_Connection=True;`)

DIRECTORY.BUILD.PROPS / TARGETS:

4. **Directory.Build.props / Directory.Build.targets**:
   - Check the solution root (and any intermediate folders) for
     `Directory.Build.props` and `Directory.Build.targets`
   - These apply solution-wide MSBuild settings without repeating them
     per `.csproj` — commonly `<LangVersion>`, `<Nullable>`,
     `<ImplicitUsings>`, `<TreatWarningsAsErrors>`,
     `<EnforceCodeStyleInBuild>`, shared analyzer package references
     (e.g. `Microsoft.CodeAnalysis.NetAnalyzers`, `StyleCop.Analyzers`)
   - Presence indicates mature, consistent tooling across the solution;
     absence means each `.csproj` must set these individually (higher
     drift risk) — note as an opportunity, not a hard failure, for
     single-project repos

CENTRAL PACKAGE MANAGEMENT:

5. **Directory.Packages.props (Central Package Management)**:
   - Check for `Directory.Packages.props` at the solution root with
     `<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>`
     in a `PropertyGroup`
   - If present: verify `.csproj` files reference packages via
     `<PackageReference Include="..." />` WITHOUT a `Version` attribute
     (version pinned centrally in `<PackageVersion>` entries) — flag
     as inconsistent if any project still sets its own `Version`
   - If present: this is a strength — consistent versions across all
     projects, no drift
   - If absent: note as an opportunity (not a hard requirement,
     especially for single-project repos) — check whether shared
     package versions (e.g. `Microsoft.EntityFrameworkCore.*`,
     `Microsoft.AspNetCore.*`) are at least consistent across
     `.csproj` files manually

NULLABLE REFERENCE TYPES:

6. **Nullable Reference Types**:
   - Check for `<Nullable>enable</Nullable>` in each `.csproj` or in
     `Directory.Build.props`
   - Flag if disabled (`disable` or omitted, which defaults to
     disabled for older-style projects) — modern .NET 6+ templates
     enable this by default, so absence is a regression signal
   - Note "Partial" if enabled in some projects but not others across
     the solution

IMPLICIT USINGS:

7. **ImplicitUsings**:
   - Check for `<ImplicitUsings>enable</ImplicitUsings>` in each
     `.csproj` or `Directory.Build.props`
   - This is the modern (.NET 6+) convention reducing boilerplate
     `using` statements; note if absent (not critical, but a
     modernization opportunity)

EDITORCONFIG:

8. **.editorconfig**:
   - Check for `.editorconfig` at the solution root
   - If present, verify it contains C#-specific sections
     (`[*.cs]`) defining formatting rules and/or analyzer severities
     (e.g. `dotnet_diagnostic.CAxxxx.severity`,
     `csharp_style_*` preferences, `dotnet_style_*` preferences)
   - Presence with real rules is a strength (enforces consistent style
     via `dotnet format` / IDE integration and CI); presence with only
     defaults or absence entirely should be noted as a gap

SECRET/ENVIRONMENT VARIABLE USAGE:

9. **Environment variable usage**:
   - Grep for `Environment.GetEnvironmentVariable`,
     `builder.Configuration[`, `Configuration.GetConnectionString`,
     and `IOptions<`/`IOptionsSnapshot<`/`IOptionsMonitor<` patterns
     across `Program.cs` and configuration/startup code to confirm
     configuration is externalized through the standard ASP.NET Core
     configuration pipeline (appsettings + environment variables +
     user secrets + Key Vault), not hardcoded
   - Grep source files for suspicious hardcoded values: literal
     connection strings (`Server=`, `Data Source=`, `Password=`),
     API keys, or JWT secrets assigned directly in `.cs` files rather
     than read from configuration — flag any match as a hardcoded
     secrets risk with the file/line as evidence
   - Verify strongly-typed configuration classes bound via
     `builder.Services.Configure<T>(builder.Configuration.GetSection(...))`
     are used rather than scattering raw `IConfiguration["Key:SubKey"]`
     string lookups throughout the codebase (the latter is acceptable
     in small services but note as an opportunity in larger ones)

OUTPUT FORMAT:

Provide structured analysis:
- Appsettings environments found: [list — e.g. Development, Staging,
  Production]
- UserSecretsId present: [Yes/No]
- launchSettings.json present: [Yes/No — flag if it contains real
  secrets]
- Directory.Build.props present: [Yes/No — key settings found]
- Central Package Management (Directory.Packages.props): [Yes/No]
- Nullable Reference Types enabled: [Yes/No/Partial]
- ImplicitUsings enabled: [Yes/No/Partial]
- .editorconfig present: [Yes/No — C#-specific rules: Yes/No]
- Hardcoded secrets risk found: [Yes/No + evidence (file/line)]
- Strongly-typed configuration (Options pattern) usage: [Consistent/
  Partial/Not used]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Full appsettings hierarchy with correct environment overrides; no
  hardcoded secrets anywhere in source or committed config
- UserSecretsId configured for local development
- Directory.Build.props (or per-project equivalent) enforces
  Nullable + ImplicitUsings + analyzers consistently across the
  solution
- Central Package Management in place (or, for a single-project repo,
  package versions are clean and current)
- .editorconfig present with real C#-specific formatting/analyzer
  rules
- Configuration consistently accessed via the Options pattern
  (`IOptions<T>`), not scattered raw `IConfiguration` lookups

Fair (70-84):
- Appsettings hierarchy present but minor gaps (e.g. missing a
  Staging file, or Development secrets that should use User Secrets)
- Nullable/ImplicitUsings enabled in most but not all projects
- .editorconfig present but mostly defaults, or Central Package
  Management absent without an equivalent manual version-consistency
  process
- Some raw `IConfiguration` string-key lookups alongside the Options
  pattern

Weak (0-69):
- Hardcoded secrets or connection strings found in
  appsettings.Production.json, launchSettings.json, or source code
- Nullable Reference Types disabled or absent
- No Directory.Build.props/.editorconfig — inconsistent settings
  across projects
- No environment-specific appsettings overrides (single file used for
  all environments)
- Configuration accessed via scattered, untyped
  `Environment.GetEnvironmentVariable`/raw `IConfiguration` calls
  throughout the codebase
