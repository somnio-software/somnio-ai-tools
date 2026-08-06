# .NET Health Audit Repository Inventory

> Detect solution/project structure, layering pattern, and directory organization for ASP.NET Core Web API repositories.

---

Goal: Detect solution structure, project types, layering pattern, and
validate architecture and file-size conventions for clean, maintainable
ASP.NET Core Web API code.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire analysis
- Use batch find/ls commands to inventory directory structure in one pass
- Read multiple `.csproj` files per tool call using parallel reads
- Do NOT read individual `.cs` source files to count lines — use
  `find ... -name "*.cs" | xargs wc -l` style batching instead
- Grep for endpoint-mapping calls (`MapGet|MapPost|MapPut|MapDelete|MapGroup`)
  in a single pass across the project rather than opening each file

SOLUTION DETECTION:

1. **Solution Detection**:
   - Run `find . -maxdepth 3 -name "*.sln"` to locate solution file(s)
   - Run `find . -maxdepth 4 -name "*.csproj"` to locate all projects
   - If no `.sln` is found: note "single-project repo (no .sln)" — this
     is valid for small services, do not penalize
   - If multiple `.sln` files exist, flag as unusual and note which one
     appears to be the primary solution

PROJECT TYPE DETECTION:

2. **Project Type Detection** (per `.csproj`, via the `<Project Sdk="...">`
   attribute, `<OutputType>`/`<TargetFramework>`, and package references):
   - `Microsoft.NET.Sdk.Web` + `Microsoft.AspNetCore.*` / `Swashbuckle.*` /
     `Microsoft.AspNetCore.OpenApi` package refs → Web API / MVC project
   - `Microsoft.AspNetCore.Components` (Server or WebAssembly) present →
     Blazor Server/WebAssembly project
   - `Microsoft.NET.Sdk.Worker`, OR usage of `IHostedService` /
     `BackgroundService` in source → Worker Service
   - Plain `Microsoft.NET.Sdk` with no ASP.NET Core references → Class
     Library (likely Domain/Application/Infrastructure layer)
   - Project name ending in `.Tests`, `.UnitTests`, or
     `.IntegrationTests` → test project — EXCLUDE from "application
     project" counts, report separately
   - Note the `<TargetFramework>` (expect `net8.0`) for each project;
     flag inconsistent target frameworks across projects in the same
     solution

LAYERING / ARCHITECTURE DETECTION:

3. **Architecture Pattern Detection** — classify into ONE of five named
   patterns (do not just say "layered", identify which specific one):

   a. **Vertical Slice Architecture**: organized by *feature*, not by
      technical layer. Look for a top-level `Features/` folder (or
      similarly named `Modules/`/`Slices/`) containing one subfolder
      per use case (e.g. `Features/Orders/CreateOrder/`,
      `Features/Orders/GetOrderById/`), each bundling its own
      request/command, handler, and often endpoint mapping together in
      one place. Strong signals: `MediatR` package reference,
      `IRequestHandler<TRequest, TResponse>` implementations, one
      `.cs` file (or small cluster) per use case rather than per
      technical role. This is structurally the OPPOSITE of layering —
      do not misclassify it as "flat" just because there's no
      `Controllers/`/`Services/`/`Repositories/` split; the
      organizing axis is the feature, not the absence of structure.

   b. **Onion Architecture**: multi-project, with `Domain` at the
      absolute center depending on NOTHING (not even Infrastructure
      abstractions defined elsewhere) — all interfaces the Domain
      needs are defined INSIDE Domain itself, and outer rings
      (Application, Infrastructure, Api/Presentation) reference
      inward only. The distinguishing test vs. Clean Architecture
      below: in strict Onion, repository/gateway interfaces live in
      `Domain`; Infrastructure only implements them.

   c. **Clean Architecture**: multi-project with `Domain`,
      `Application`, `Infrastructure`, `Api`/`WebApi` as separate
      `.csproj`s and an inward `ProjectReference` chain (Api →
      Application → Domain, Infrastructure → Application), but
      interfaces for external concerns (repositories, gateways) are
      typically defined in `Application` (not `Domain` itself) and
      implemented by `Infrastructure`. If you can't distinguish this
      from Onion with confidence from folder/interface placement
      alone, report "Clean/Onion (multi-project, inward dependency
      confirmed)" rather than guessing — the key finding for scoring
      purposes is the presence of proper layering and inward
      dependency direction, not perfect taxonomy.

   d. **N-Layer / Layered (single project)**: one project with
      `Controllers/`, `Services/`, `Repositories/`, `Models/` (or
      `Entities/`) folders — the same conceptual layers as Clean
      Architecture, but as folders inside one `.csproj` rather than
      separate projects. Valid for smaller services; do not penalize
      solely for being single-project if the folder-level separation
      is consistent.

   e. **Flat / No discernible architecture**: no consistent
      layering, feature organization, or folder convention — business
      logic, data access, and HTTP concerns mixed together directly in
      Controllers or a handful of catch-all classes.

   - Both (a)-(d) are valid, deliberate architectural choices — score
     based on CONSISTENCY of whichever pattern is used, not on which
     pattern was chosen.
   - Flag as "Mixed/Inconsistent" if some features follow one pattern
     (e.g. Vertical Slice) while others sit directly in the API
     project with no separation, or if Clean/Onion/N-Layer layers are
     bypassed in places (e.g. a Controller injecting `DbContext`
     directly instead of going through Application/Service).
   - For multi-project patterns (b, c), check `ProjectReference`
     entries in each `.csproj` to confirm the dependency direction is
     inward and Domain has no outward references — this is the single
     most important structural fact to verify, regardless of which of
     the two you classify it as.

DIRECTORY INVENTORY:

4. **Directory Inventory** (inside the main API project):
   - Count Controllers: `find . -path "*/Controllers/*.cs"` (files
     ending `Controller.cs` inheriting `ControllerBase`/`Controller`)
   - Count Minimal API endpoint groups: grep for
     `MapGet|MapPost|MapPut|MapDelete|MapGroup` across `*.cs` files if
     no/few Controllers are found
   - Count Services: files under `Services/` or ending `Service.cs`
   - Count Repositories: files under `Repositories/` or ending
     `Repository.cs`
   - Count DTOs/Contracts: files under `Dtos/`, `Contracts/`,
     `Requests/`, `Responses/`
   - Count Entities/Models: files under `Entities/`, `Models/`,
     `Domain/`
   - Count Validators: files ending `Validator.cs` (FluentValidation)

FILE SIZE ANALYSIS:

5. **File Size Analysis**:
   For all `*.cs` files under the main API and Application project(s)
   (exclude `bin/`, `obj/`, `*.Designer.cs`, migrations):
   - Files < 150 lines: Healthy
   - Files 150-300 lines: Acceptable
   - Files > 300 lines: FLAG for review
   - Files > 500 lines: CRITICAL FLAG — recommend splitting (e.g. a
     bloated controller should delegate to services; a bloated service
     should be split by sub-domain or CQRS command/query)

NAMING CONVENTIONS:

6. **Naming Conventions**:
   - PascalCase for public types and matching file names:
     `OrdersController.cs`, `OrderService.cs` ✓
   - Consistent suffixes: `*Controller.cs`, `*Service.cs`,
     `*Repository.cs`, `*Dto.cs`, `*Validator.cs`, `*Profile.cs`
     (AutoMapper)
   - Interfaces prefixed with `I`: `IOrderService.cs`,
     `IOrderRepository.cs`
   - Flag: file name not matching the public type it contains,
     inconsistent casing, or missing standard suffixes

API STYLE DETECTION:

7. **Minimal APIs vs Controllers**:
   - Detect which style is used: presence of `[ApiController]` classes
     inheriting `ControllerBase` vs `app.MapGet/MapPost/...` /
     `MapGroup` calls in `Program.cs` or extension methods
   - Both styles are valid — note which one dominates
   - Flag if BOTH styles are used inconsistently for the same kind of
     resource (e.g. some resources exposed via Controllers, others via
     Minimal API endpoint groups, with no clear rationale noted in docs)

OUTPUT FORMAT:

Provide structured analysis:
- Solution detected: [Yes/No — path if found]
- Project count: [Number] (application projects vs test projects)
- Project types breakdown: [Web API: N, Class Library: N, Worker: N,
  Blazor: N, Test: N]
- Target framework consistency: [Consistent (net8.0) / Inconsistent — list]
- Architecture pattern: [Vertical Slice / Onion / Clean Architecture /
  N-Layer (single project) / Flat / Mixed-Inconsistent]
- Dependency direction (multi-project patterns only): [Inward-confirmed
  (Domain has no outward references) / Violated — list offending
  references / N/A — single project]
- API style: [Controllers / Minimal APIs / Mixed]
- Controllers or endpoint groups count: [Number]
- Services count: [Number]
- Repositories count: [Number]
- DTOs/Contracts count: [Number]
- Entities/Models count: [Number]
- Validators count: [Number]
- File size analysis:
  * Files < 150 lines: [Count]
  * Files 150-300 lines: [Count]
  * Files > 300 lines: [Count] (flag for review)
  * Files > 500 lines: [Count] (critical - list files)
- Naming convention compliance: [XX]%
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- One of the five named patterns (Vertical Slice, Onion, Clean
  Architecture, N-Layer) applied consistently across the codebase —
  no pattern is inherently better than another, consistency is what
  matters
- For multi-project patterns (Onion/Clean Architecture): dependency
  direction confirmed inward, Domain has no outward references
- Consistent API style (Controllers or Minimal APIs, not an
  unmotivated mix)
- Source files reasonably sized (most < 300 lines, few or no files
  > 500 lines)
- Consistent PascalCase naming with standard suffixes across
  Controllers/Services/Repositories/DTOs/Validators
- Dependency direction respected (Domain has no outward references)

Fair (70-84):
- Layering present but with some inconsistency (a few features bypass
  the intended layers)
- Mostly consistent API style with a few exceptions
- Some large files (300-500 lines) but no widespread bloat
- Minor naming inconsistencies (a handful of missing suffixes or
  casing issues)

Weak (0-69):
- No discernible layering — business logic, data access, and HTTP
  concerns mixed together in the same classes
- Inconsistent, unmotivated mix of Controllers and Minimal APIs for
  equivalent resources
- Multiple oversized files (> 500 lines), especially Controllers or
  Services doing too much
- Inconsistent or incorrect naming conventions throughout
