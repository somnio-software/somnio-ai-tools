# .NET Health Audit Data Layer Analysis

> Analyze EF Core/ORM integration, repository patterns, migrations, and data access layer organization for ASP.NET Core Web API projects.

---

Goal: Analyze the data layer implementation focusing on clean,
maintainable, and performant database access patterns.

IMPORTANT: Apply REASONABLE production standards. Do not penalize
for advanced patterns that aren't strictly necessary. Focus on
clarity, maintainability, and correctness.

PROJECT STRUCTURE:
- If a Clean Architecture solution is detected (separate Api/
  Application/Domain/Infrastructure projects): Note in report and
  expect the `DbContext`, entity configurations, and migrations to
  live in the Infrastructure project, with entity/domain classes in
  the Domain project
- Standard single-project repo: Analyze the whole project

ORM/DATABASE DETECTION:

1. Identify ORM in Use:
   - Check `.csproj` files for:
     * `Microsoft.EntityFrameworkCore` + a provider package → EF Core
     * `Dapper` → Dapper (lightweight micro-ORM alternative)
     * Both present → EF Core for writes/CRUD, Dapper for
       performance-critical reads (a valid, common combination)
   - If neither is detected, note as "No ORM detected" (may use raw
     `SqlConnection`/ADO.NET, or another data access library)

2. Database Provider Detection:
   - Check for EF Core provider packages:
     * `Npgsql.EntityFrameworkCore.PostgreSQL` → PostgreSQL
     * `Microsoft.EntityFrameworkCore.SqlServer` → SQL Server
     * `Pomelo.EntityFrameworkCore.MySql` → MySQL/MariaDB
     * `Microsoft.EntityFrameworkCore.Sqlite` → SQLite
     * `Microsoft.EntityFrameworkCore.InMemory` → in-memory (flag if
       used outside of test projects — not suitable for production)
   - Check `appsettings.json`/`appsettings.*.json` for connection
     string sections confirming the provider

ENTITY/DBCONTEXT ANALYSIS:

1. DbContext Organization:
   - Locate the `DbContext` subclass (typically `AppDbContext`/
     `ApplicationDbContext`) and note its project location
   - Verify `DbSet<T>` properties are declared for each aggregate/
     entity exposed to the data layer
   - Check `AddDbContext<T>()` registration in `Program.cs` and
     confirm the connection string is read from configuration, not
     hardcoded inline

2. Entity Configuration Approach:
   - `IEntityTypeConfiguration<T>` classes (Fluent API, one class per
     entity, applied via `modelBuilder.ApplyConfigurationsFromAssembly(...)`)
     ← PREFERRED for larger models, keeps `OnModelCreating` thin
   - Data Annotations directly on entity classes (`[Required]`,
     `[MaxLength]`, `[Column]`, `[ForeignKey]`) — acceptable for
     smaller models
   - Inline configuration entirely within `OnModelCreating` — acceptable
     for small models, flag if `OnModelCreating` has grown large
     (many entities configured inline) without extraction to
     `IEntityTypeConfiguration<T>` classes
   - REASONABLE CHECK: any single approach used consistently is fine;
     flag only an inconsistent, unmotivated mix across entities

3. Entity Design:
   - Clear, descriptive class names (`Order`, `Customer`, `Product`)
   - Relationship navigation properties (`ICollection<T>` for
     one-to-many, reference navigation for many-to-one) declared and
     configured (not left for EF Core's convention-only inference on
     non-obvious relationships)
   - Value objects/owned types (`OwnsOne`/`OwnsMany`) used where
     appropriate rather than flattening everything into scalar columns

REPOSITORY PATTERN ANALYSIS:

1. Repository Files:
   - Check for repository pattern usage:
     * `I*Repository`/`*Repository` interfaces and classes
     * Generic `IRepository<T>`/`Repository<T>` base plus specific
       repositories, or fully specific repositories per aggregate
   - Versus direct `DbContext`/`DbSet<T>` injection into services —
     BOTH are acceptable patterns in EF Core; note the tradeoff:
     * Repository pattern: extra abstraction layer, easier to test
       services in isolation, can be redundant on top of EF Core's
       own `DbSet`/`DbContext` abstraction (`DbContext` is already a
       Unit of Work and `DbSet<T>` already resembles a repository)
     * Direct `DbContext` injection: less ceremony, leans on EF Core's
       built-in abstractions directly, still testable via
       `UseInMemoryDatabase`/SQLite in-memory for integration-style
       tests
   - CRITICAL: Repositories (if used) should contain ONLY:
     * Database queries (`Find`, `Add`, `Update`, `Remove`, `SaveChangesAsync`)
     * Query composition (`IQueryable<T>` building)
   - CRITICAL: Repositories should NOT contain:
     * Business logic (validation, calculations, orchestration across
       aggregates)
     * HTTP-related code or DTO mapping better suited to a service/
       mapping layer

2. Repository File Size:
   - < 300 lines: Good
   - 300-500 lines: Acceptable for complex aggregates
   - \> 500 lines: Consider splitting by query responsibility (e.g.
     CQRS-style query objects instead of one large repository)

QUERY PATTERNS:

1. Read Query Optimization:
   - `AsNoTracking()` used on read-only queries (list/detail GET
     endpoints that don't subsequently call `SaveChangesAsync()`) —
     avoids unnecessary change-tracking overhead
   - `Include()`/`ThenInclude()` used for eager loading of related
     data needed by the response
   - Projection via `.Select()` into DTOs to avoid over-fetching full
     entity graphs when only a few columns are needed
   - REASONABLE: not every query needs `AsNoTracking()` (queries that
     will be updated in the same unit of work legitimately need
     tracking) — only flag read-only endpoints that omit it at scale

2. N+1 Query Prevention:
   - Flag loops that trigger individual queries per iteration (e.g.
     iterating a list of orders and calling
     `_context.Items.Where(i => i.OrderId == order.Id)` inside the
     loop) instead of eager loading (`Include`) or a single batched
     query
   - Flag lazy-loading proxies (`Microsoft.EntityFrameworkCore.Proxies`
     + `UseLazyLoadingProxies()`) combined with serialization of
     navigation properties in API responses — a common hidden N+1
     source
   - REASONABLE: not every relation needs eager loading, only flag
     obvious N+1 patterns

3. Query Complexity:
   - Check for raw SQL via `FromSqlRaw`/`FromSqlInterpolated` —
     verify parameterization (`FromSqlInterpolated` or parameterized
     `FromSqlRaw`) to prevent SQL injection; flag string concatenation
     into `FromSqlRaw`
   - REASONABLE: raw SQL/Dapper is acceptable for complex reports or
     performance-critical operations

PAGINATION:

1. Check for pagination on list endpoints:
   - `.Skip()`/`.Take()` (or a keyset/cursor-based equivalent) applied
     before materialization (`ToListAsync()`)
   - Flag unbounded `ToListAsync()`/`ToArrayAsync()` calls on tables
     that can grow large (orders, logs, transactions) with no
     `Skip`/`Take`, filtering, or upper bound
   - REASONABLE: not all endpoints need pagination (small, bounded
     reference tables are fine unpaginated) — only flag unbounded
     queries on potentially large tables

MIGRATION ANALYSIS:

1. Migrations:
   - Check for a `Migrations/` folder (typically in the project
     holding the `DbContext`)
   - Verify evidence of the `dotnet ef migrations add <Name>` /
     `dotnet ef database update` workflow: migration files with
     timestamp-prefixed names and matching `ModelSnapshot` file
   - Check migration naming reflects the actual schema change
     (`AddOrderStatusColumn` vs generic `Migration1`)

2. Migration Application Strategy:
   - `context.Database.Migrate()` called at application startup in
     `Program.cs` — FLAG as a production anti-pattern: it runs with
     the app's runtime credentials (often over-privileged), can race
     across multiple instances on deploy, and offers no rollback gate
   - Migrations applied via a separate CI/CD step (`dotnet ef database
     update` in a pipeline, or a dedicated migration bundle/job) —
     PREFERRED for production
   - REASONABLE: `Database.Migrate()` at startup is commonly acceptable
     for local development or single-instance small services; only
     flag it as a hard risk for services that scale horizontally or
     run in a shared production environment

3. Migration Best Practices:
   - Migrations should be version-controlled and reviewed like any
     other code change
   - `Down()` methods present and correct for reversibility
   - REASONABLE: down migrations are recommended but not strictly
     required for every migration (e.g. destructive/irreversible data
     migrations are sometimes intentionally one-way)

TRANSACTION HANDLING:

1. Transaction Patterns:
   - `SaveChangesAsync()` is itself transactional for a single unit of
     work — no explicit transaction needed for one `SaveChangesAsync()` call
   - Explicit `context.Database.BeginTransactionAsync()` (or
     `IDbContextTransaction`) used when an operation spans multiple
     `SaveChangesAsync()` calls, or coordinates writes across more than
     one `DbContext`
   - `IExecutionStrategy`/`context.Database.CreateExecutionStrategy().ExecuteAsync(...)`
     used to wrap explicit transactions when `EnableRetryOnFailure()`
     is configured (required — retrying execution strategies cannot
     wrap a manually-started transaction directly without this)
   - REASONABLE: not every operation needs an explicit transaction,
     only flag multi-step operations modifying multiple aggregates/
     tables without one

2. Error Handling in Transactions:
   - Check for proper rollback on exceptions (try/catch around
     transaction blocks, or reliance on the execution strategy's retry/
     rollback behavior)
   - Verify the transaction/connection is disposed (`await using`)

CONNECTION MANAGEMENT:

1. Connection Configuration:
   - Connection strings sourced from configuration
     (`appsettings.json`, environment variables, user secrets, Key
     Vault) — NOT hardcoded in source
   - `EnableRetryOnFailure()` configured on the provider (e.g.
     `UseNpgsql(cs, o => o.EnableRetryOnFailure())`) — important for
     cloud-hosted databases (Azure SQL, RDS) subject to transient faults
   - REASONABLE: default connection/pooling settings are acceptable
     for most applications; retry-on-failure is a strong recommendation
     for cloud-hosted production databases, not a hard requirement for
     local/on-prem SQL Server or SQLite

2. Connection Health:
   - Check for database health checks
     (`AddDbContextCheck<T>()`/`AddNpgsql(...)` via
     `Microsoft.Extensions.Diagnostics.HealthChecks`) — optional,
     nice-to-have signal of production maturity

DATA VALIDATION:

1. Database-Level Constraints:
   - Check migrations/configuration for NOT NULL, unique indexes,
     foreign keys, and check constraints backing the entity model
     (not relying solely on application-level validation)

2. Query Result Handling:
   - Check for null handling after single-entity lookups
     (`FindAsync`/`FirstOrDefaultAsync` returning null) — verify a
     404/`NotFoundResult` or domain exception is raised rather than an
     unguarded null-reference risk downstream
   - REASONABLE: basic null checks are sufficient, don't require
     extensive validation on every query

SEEDING (OPTIONAL):

1. Seed Data:
   - Check for `HasData(...)` calls in entity configurations, or a
     dedicated seeding class/`DbInitializer` invoked at startup for
     dev/test environments
   - NEUTRAL: seeding is optional, don't penalize if missing

OUTPUT FORMAT:

Provide structured analysis:
- ORM detected: [EF Core / Dapper / Both / None]
- Database provider: [PostgreSQL/SQL Server/MySQL/SQLite/InMemory/etc.]
- DbContext organization: [location, DbSet count]
- Entity configuration approach: [IEntityTypeConfiguration / Data Annotations / Inline OnModelCreating / Mixed]
- Repository pattern usage: [Yes / No / Partial]
- Repository files count: [Number]
- Query patterns: [AsNoTracking usage, Include/ThenInclude usage, projection usage]
- N+1 query risks identified: [Count or None]
- Pagination implemented: [Implemented / Partial / Missing]
- Migration setup: [Yes / No]
- Migration count: [Number]
- Migration application strategy: [CI/CD-driven / Database.Migrate() at startup / Manual / Unclear]
- Transaction usage: [Appropriate / Missing where needed / N/A]
- Connection management: [Configuration-based + retry / Configuration-based, no retry / Hardcoded]
- Risks identified (only significant issues)
- Recommendations (actionable, reasonable improvements)

SCORING GUIDANCE:

Strong (85-100):
- EF Core (or Dapper, deliberately) configured cleanly with connection
  strings from configuration
- Entity configuration organized (consistent use of
  `IEntityTypeConfiguration<T>` for non-trivial models)
- Repository pattern (or direct, well-encapsulated `DbContext` usage)
  cleanly separates data access from business logic
- Migrations in place, version-controlled, applied via CI/CD (not
  `Database.Migrate()` at startup in a scaled production service)
- No obvious N+1 query issues; `AsNoTracking()` used on read paths
- Pagination present on endpoints over potentially large tables
- Explicit transactions used appropriately for multi-step operations;
  `EnableRetryOnFailure()` configured for cloud-hosted databases

Fair (70-84):
- EF Core configured and working, connection strings externalized
- Entities exist but configuration approach is inconsistent across
  the model
- Some mixing of data access and business logic in services/repositories
- Migrations exist but application strategy is unclear or uses
  `Database.Migrate()` at startup without a clear justification
- Minor query optimization opportunities (missing `AsNoTracking()` on
  a few read endpoints, occasional missing pagination)

Weak (0-69):
- No clear ORM/data access strategy, or inconsistent usage across the
  codebase
- Entity configuration disorganized or missing constraints
- Data access logic scattered directly in controllers/endpoints
- No migrations for a relational database, or migrations with no
  discernible workflow
- Obvious N+1 queries, unbounded `ToListAsync()` on large tables, or
  hardcoded connection strings

IMPORTANT: Be reasonable in scoring. A production ASP.NET Core API
doesn't need every advanced EF Core pattern. Focus on:
- Is the data layer organized and maintainable?
- Are there obvious performance risks (N+1, unbounded queries) or
  security issues (unparameterized raw SQL, hardcoded credentials)?
- Can a new developer understand the data access patterns and how
  schema changes are made and applied?
