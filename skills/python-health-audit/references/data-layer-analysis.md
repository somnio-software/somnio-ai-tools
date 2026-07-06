# Python Data Layer Analysis

> Analyze SQLAlchemy / Django ORM / Tortoise-ORM setup, Alembic or framework migrations, repository and Unit-of-Work patterns, N+1 query risks, and transaction handling.

---

Goal: Analyze the data layer implementation focusing on clean,
maintainable, and performant database access patterns.
This is a 0.11-weight pillar.

IMPORTANT: Apply REASONABLE production standards. Not every project
needs a full repository pattern or Unit-of-Work abstraction. Focus on
whether the data layer is organised, avoids obvious pitfalls, and
can be understood by a new developer.

ORM / DATABASE DETECTION:

1. Identify ORM from pyproject.toml / requirements:
   - sqlalchemy (+ asyncpg / psycopg2 / aiosqlite) → SQLAlchemy
   - django → Django ORM
   - tortoise-orm → Tortoise ORM
   - databases (encode) → databases (async raw SQL)
   - peewee → Peewee
   - If none found, note "No ORM — raw queries or external data layer"

2. Database Driver Detection:
   - asyncpg / psycopg3 (async) → PostgreSQL async
   - psycopg2 / pg8000 → PostgreSQL sync
   - aiomysql / pymysql → MySQL
   - motor / beanie / odmantic → MongoDB (async)
   - aiosqlite / sqlite3 → SQLite
   - Note: async ORM requires async engine; flag sync ORM in async app as risk

SQLALCHEMY ANALYSIS (if applicable):

1. Engine / Session Configuration:
   - Check for create_async_engine vs. create_engine; async preferred in
     async apps (FastAPI, Litestar, Starlette)
   - Verify connection string comes from environment variable (not hardcoded)
   - Check pool_size, max_overflow, pool_timeout settings (not required but
     flag if defaults are used in high-traffic context without comment)
   - Check for async_sessionmaker or sessionmaker with expire_on_commit=False
     (important for async; prevents lazy-load after session close)

2. Model / Mapped Class Definition:
   - Check for DeclarativeBase (SQLAlchemy 2.x) or declarative_base() (1.x)
   - Verify Mapped[type] annotations (SQLAlchemy 2.x) or Column() (1.x)
   - Check for __tablename__ on every model
   - Verify explicit column types (not relying on inference)
   - Check for relationship() with lazy parameter explicit where async is used
     (lazy="selectin" or lazy="joined" preferred over lazy="subquery" in async)
   - Flag lazy="dynamic" in SQLAlchemy 2.x as removed / deprecated

3. Session Lifecycle:
   - Verify sessions are yielded via async generator (FastAPI Depends pattern)
     or context manager — never stored as global singletons
   - Check for async with session.begin() for atomic blocks
   - Flag session.commit() inside nested loops (N+1 commit pattern)

DJANGO ORM ANALYSIS (if applicable):

1. Model Organisation:
   - Check models are per-app (django apps) not monolithic models.py
   - Verify Meta class includes ordering, verbose_name, indexes where needed
   - Check for db_index=True on frequently filtered foreign keys and fields
   - Flag large models (> 30 fields without comment) as potential candidate
     for normalisation

2. QuerySet Patterns:
   - Check for select_related() on FK/OneToOne relationships in list views
   - Check for prefetch_related() on M2M and reverse FK in list views
   - Flag queryset.all() in view without .only() or .defer() on large models
   - Check for custom Manager / QuerySet classes for domain-level query logic

3. Django Migrations:
   - Verify migrations/ directory exists in every app with models
   - Check for squashmigrations usage on old projects
   - Flag missing migration for model change (run makemigrations --check in CI)
   - Verify no RunPython calling external APIs or time-consuming operations
     without a hint about reversibility

TORTOISE ORM ANALYSIS (if applicable):

1. Model Configuration:
   - Check for class Meta with table name and ordering
   - Verify ForeignKeyField and ManyToManyField use related_name
   - Check for indexes in Meta.indexes

2. Session / Connection:
   - Check Tortoise.init() is called at application startup with config from env
   - Verify generate_schemas=False in production (use Aerich migrations instead)

REPOSITORY / UNIT-OF-WORK PATTERNS:

1. Repository Detection:
   - Check for repository classes or files (*_repository.py, repositories/)
   - CRITICAL: repositories should contain ONLY data access logic:
     * Query construction (filter, join, aggregate)
     * Persistence (add, merge, delete)
     * Result mapping (ORM model → domain model if applicable)
   - CRITICAL: repositories should NOT contain:
     * Business rules or calculations
     * HTTP / external service calls
     * Email sending, event publishing (except after unit of work)
   - File size check: > 400 lines suggests splitting by entity or query type

2. Unit-of-Work Pattern:
   - Check for UnitOfWork class that groups one or more repositories under
     a single transaction/session
   - NEUTRAL: UoW is an advanced pattern; absence alone does not penalise
   - Flag if business logic services create their own sessions ad hoc instead
     of receiving a session (makes testing harder)

3. Direct ORM in Service Layer:
   - Check service files for direct ORM model imports and query calls
   - REASONABLE: Direct ORM in services is acceptable for small codebases;
     flag only if it creates test difficulties or business-logic mixing

MIGRATION ANALYSIS:

1. Alembic (SQLAlchemy projects):
   - Check for alembic/ directory with env.py and versions/
   - Verify alembic.ini connection string uses env variable interpolation
   - Check for alembic upgrade head in deployment scripts or CI
   - Verify autogenerate is used (not manual migration scripts for schema
     changes that ORM can detect)
   - Flag downgrade() methods that are pass-only (no rollback capability)

2. Django Migrations:
   - Already covered above; ensure manage.py migrate is in deploy pipeline

3. Aerich (Tortoise ORM):
   - Check for aerich/ directory or aerich.ini
   - Verify aerich upgrade in deploy pipeline

4. General:
   - Migrations must be version-controlled (never in .gitignore)
   - Flag if there are no migrations for a relational ORM (schema drift risk)

TRANSACTION HANDLING:

1. Explicit Transactions:
   - Check for context manager transaction blocks around multi-step writes:
     * SQLAlchemy async: async with session.begin()
     * Django: transaction.atomic() / async with transaction.atomic()
     * Tortoise: use in_transaction() context manager
   - Flag business logic that modifies 2+ tables without transaction protection

2. Rollback Handling:
   - Verify try/except/finally or context manager patterns ensure rollback on
     error
   - Flag bare session.commit() without error handling

N+1 QUERY DETECTION:

1. Patterns to Flag:
   - Loops that call .get(), .filter().first(), or async equivalents on ORM
     objects fetched in a parent query
   - Django: loops over queryset without prefetch_related for related access
   - SQLAlchemy: accessing relationship attributes inside loop without
     eager loading
   - FastAPI: route that queries a list then loops to fetch sub-resources
     one by one

2. REASONABLE Threshold:
   - Flag only when the N+1 is clearly avoidable with a join/prefetch
   - Do not flag cases where the pattern is intentional and commented

PAGINATION:

1. Unbounded Queries:
   - Flag queries that fetch all rows from potentially large tables without
     limit / offset / cursor pagination
   - Check for skip/limit (SQLAlchemy), paginator (Django), or offset/limit
     kwargs in repository methods
   - FastAPI: check for common Depends(pagination) or Query(ge=0) params

CONNECTION MANAGEMENT:

1. Configuration:
   - All DSN / DATABASE_URL values must come from environment variables;
     flag any hardcoded connection strings
   - Check for separate test database configuration

2. Health Checks:
   - Check for /health or /readiness endpoint that pings the database
   - NEUTRAL: health endpoint is nice-to-have, not required

OUTPUT FORMAT:

Provide structured analysis:
- ORM detected: [SQLAlchemy 2.x async / SQLAlchemy sync / Django ORM / Tortoise / None]
- Database type: [PostgreSQL / MySQL / SQLite / MongoDB / etc.]
- Model organisation: [Feature-based / Centralised / Mixed]
- Model count: [N]
- Repository pattern: [Yes / Partial / No]
- Migration tool: [Alembic / Django migrations / Aerich / None]
- Migration count: [N or N/A]
- Transactions on multi-step writes: [Yes / Partial / No]
- N+1 risks identified: [N or None]
- Pagination on list endpoints: [Implemented / Partial / Missing]
- Connection string from env: [Yes / Partial / No]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- ORM configured correctly with env-based connection
- Models well-organised (centralised or feature-based)
- Migrations present and version-controlled; run in CI/CD
- No obvious N+1 patterns
- Transactions protect multi-step writes
- Session lifecycle managed via dependency injection / context manager

Fair (70-84):
- ORM configured and working; minor session lifecycle issues
- Models exist but organisation could improve
- Migrations present but may lack rollback capability
- Some N+1 risks or missing pagination on 1-2 endpoints
- Some services create sessions ad hoc

Weak (0-69):
- No ORM or inconsistent raw-query + ORM mixing
- Models disorganised or missing
- No migrations for relational DB (schema drift risk)
- Obvious N+1 patterns in critical paths
- Hardcoded connection strings
- No transaction protection on multi-step writes
