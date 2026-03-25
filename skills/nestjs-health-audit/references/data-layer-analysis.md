# NestJS Data Layer Analysis

> Analyze ORM/database integration, repository patterns, migrations, and data access layer organization for NestJS projects.

---

Goal: Analyze the data layer implementation focusing on clean,
maintainable, and performant database access patterns.

IMPORTANT: Apply REASONABLE production standards. Do not penalize
for advanced patterns that aren't strictly necessary. Focus on
clarity, maintainability, and correctness.

PROJECT STRUCTURE:
- If monorepo detected (apps/ directory): Note in report and
  focus analysis on main application
- Standard project: Analyze src/ directory

ORM/DATABASE DETECTION:

1. Identify ORM in Use:
   - Check package.json for:
     * typeorm, @nestjs/typeorm → TypeORM
     * prisma, @prisma/client → Prisma
     * mongoose, @nestjs/mongoose → Mongoose
     * sequelize, @nestjs/sequelize → Sequelize
     * @mikro-orm/core, @mikro-orm/nestjs → MikroORM
   - If no ORM detected, note as "No ORM" (may use raw queries)

2. Database Type Detection:
   - Check for database drivers:
     * pg, postgres → PostgreSQL
     * mysql, mysql2 → MySQL
     * mongodb → MongoDB
     * sqlite3 → SQLite
     * mssql → SQL Server
   - Check environment variables in .env.example

ENTITY/MODEL ANALYSIS:

1. Entity Organization (TypeORM/Sequelize/MikroORM):
   - Check for entities in:
     * src/entities/ (centralized)
     * src/modules/*/entities/ (feature-based) ← PREFERRED
     * src/**/*.entity.ts
   - For each entity, verify:
     * Clear, descriptive class name (User, Product, Order)
     * Proper decorator usage (@Entity, @Column, @PrimaryGeneratedColumn)
     * Relationship decorators (@OneToMany, @ManyToOne, @ManyToMany)
     * Column types are explicit (not relying on inference)
   - REASONABLE CHECK: Entities should be organized, either
     centralized OR feature-based is acceptable

2. Schema Organization (Prisma):
   - Check for prisma/schema.prisma
   - Verify schema includes:
     * Clear model definitions
     * Proper relations (@relation)
     * Indexes where appropriate (@@index)
     * Enums for constrained values
   - Check for Prisma client generation in scripts

3. Schema Organization (Mongoose):
   - Check for schemas in:
     * src/schemas/ (centralized)
     * src/modules/*/schemas/ (feature-based)
     * src/**/*.schema.ts
   - Verify schema includes:
     * @Schema decorator with proper options
     * @Prop decorators with types
     * Indexes where appropriate
     * Virtual fields if needed

REPOSITORY PATTERN ANALYSIS:

1. Repository Files:
   - Check for repository pattern usage:
     * src/modules/*/repositories/*.repository.ts
     * src/repositories/*.repository.ts
     * Custom repository classes
   - CRITICAL: Repositories should ONLY contain:
     * Database queries (find, save, update, delete)
     * Query building logic
     * Data transformation for DB operations
   - CRITICAL: Repositories should NOT contain:
     * Business logic (validation, calculations)
     * HTTP-related code
     * External service calls
   - Repository file length check:
     * < 300 lines: Good
     * 300-500 lines: Acceptable for complex entities
     * > 500 lines: Consider splitting by query type

2. TypeORM Repository Usage:
   - Check for @InjectRepository() usage in services
   - Verify custom repository classes extend Repository<Entity>
   - Check for QueryBuilder usage (acceptable for complex queries)
   - Verify proper typing (Repository<User>, not Repository<any>)

3. Prisma Service Pattern:
   - Check for PrismaService that extends PrismaClient
   - Verify PrismaService is injectable
   - Check for proper connection handling (onModuleInit, onModuleDestroy)

4. Mongoose Repository Pattern:
   - Check for @InjectModel() usage
   - Verify Model typing (Model<UserDocument>)

QUERY PATTERNS:

1. N+1 Query Prevention:
   - Check for eager loading where appropriate:
     * TypeORM: relations option or QueryBuilder joins
     * Prisma: include in queries
     * Mongoose: populate()
   - Flag loops that make individual queries
   - REASONABLE: Not every relation needs eager loading,
     only flag obvious N+1 patterns

2. Query Complexity:
   - Check for overly complex raw queries
   - Verify parameterized queries (prevent SQL injection)
   - Check for query timeouts on long-running queries
   - REASONABLE: Raw queries are acceptable for complex
     reports or performance-critical operations

3. Pagination:
   - Check for pagination in list endpoints:
     * skip/take (TypeORM, Prisma)
     * limit/offset (Mongoose)
   - Verify large datasets aren't fetched without limits
   - REASONABLE: Not all endpoints need pagination,
     only flag unbounded queries on potentially large tables

MIGRATION ANALYSIS:

1. TypeORM Migrations:
   - Check for migrations in:
     * src/migrations/
     * migrations/
     * database/migrations/
   - Verify migration scripts in package.json:
     * migration:generate
     * migration:run
     * migration:revert
   - Check for migration naming convention (timestamp-based)

2. Prisma Migrations:
   - Check for prisma/migrations/ directory
   - Verify migration commands in package.json:
     * prisma migrate dev
     * prisma migrate deploy
   - Check for migration history

3. Mongoose (Schema-based):
   - Mongoose typically doesn't use migrations
   - Check for schema versioning if applicable
   - NEUTRAL: No migrations expected for Mongoose

4. Migration Best Practices:
   - Migrations should be version controlled
   - Down migrations should exist for reversibility
   - REASONABLE: Down migrations are recommended but not
     strictly required for all cases

TRANSACTION HANDLING:

1. Transaction Patterns:
   - Check for transaction usage in services:
     * TypeORM: QueryRunner, @Transaction decorator
     * Prisma: $transaction()
     * Mongoose: session-based transactions
   - Verify transactions for multi-step operations
   - REASONABLE: Not every operation needs transactions,
     only flag operations that modify multiple tables/docs
     without transaction protection

2. Error Handling in Transactions:
   - Check for proper rollback on errors
   - Verify try/catch around transaction blocks
   - Check for connection release after transactions

DATA VALIDATION:

1. Entity-Level Validation:
   - Check for class-validator decorators on entities (optional)
   - Verify database constraints (NOT NULL, UNIQUE, etc.)
   - Check for enum types for constrained values

2. Query Result Validation:
   - Check for null checks after queries
   - Verify proper error handling for not found cases
   - REASONABLE: Basic null checks are sufficient,
     don't require extensive validation on every query

CONNECTION MANAGEMENT:

1. Connection Configuration:
   - Check for connection pooling configuration
   - Verify connection settings from environment variables
   - Check for separate configs for dev/test/prod
   - REASONABLE: Default connection settings are acceptable
     for most applications

2. Connection Health:
   - Check for database health checks (optional)
   - Verify graceful shutdown handling
   - REASONABLE: Health checks are nice-to-have, not required

SEEDING (OPTIONAL):

1. Seed Data:
   - Check for seed scripts in package.json
   - Check for seed files in:
     * src/database/seeds/
     * seeds/
     * prisma/seed.ts
   - NEUTRAL: Seeding is optional, don't penalize if missing

OUTPUT FORMAT:

Provide structured analysis:
- ORM detected: [TypeORM/Prisma/Mongoose/Sequelize/MikroORM/None]
- Database type: [PostgreSQL/MySQL/MongoDB/SQLite/etc.]
- Entity/Model organization: [Centralized/Feature-based/Mixed]
- Entity count: [Number]
- Repository pattern usage: [Yes/No/Partial]
- Repository files count: [Number]
- Migration setup: [Yes/No/N/A]
- Migration count: [Number]
- Transaction usage detected: [Yes/No]
- N+1 query risks identified: [Count or None]
- Query pagination: [Implemented/Partial/Missing]
- Connection configuration: [Environment-based/Hardcoded/Mixed]
- Data layer organization score assessment
- Risks identified (only significant issues)
- Recommendations (actionable, reasonable improvements)

SCORING GUIDANCE:

Strong (85-100):
- Clear ORM setup with proper configuration
- Entities/models well-organized (centralized or feature-based)
- Repository pattern separates data access from business logic
- Migrations in place and version controlled
- No obvious N+1 query issues
- Basic transaction usage for multi-step operations

Fair (70-84):
- ORM configured and working
- Entities/models exist but organization could improve
- Some mixing of data access and business logic
- Migrations exist but may be incomplete
- Minor query optimization opportunities

Weak (0-69):
- No clear ORM strategy or inconsistent usage
- Entities/models disorganized or missing
- Data access logic scattered across services
- No migrations for relational databases
- Obvious N+1 queries or performance issues
- Hardcoded connection strings

IMPORTANT: Be reasonable in scoring. A production app doesn't
need every advanced pattern. Focus on:
- Is the data layer organized and maintainable?
- Are there obvious performance or security issues?
- Can a new developer understand the data access patterns?
