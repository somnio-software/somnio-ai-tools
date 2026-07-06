# NestJS Architecture Compliance Analysis

> Analyze codebase for adherence to Layered Architecture, dependency injection patterns, and separation of concerns.

---

Goal: Analyze the NestJS codebase for strict adherence to Layered
Architecture and Separation of Concerns.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/nestjs/module-structure.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/nestjs/module-structure.md
- local: `agent-rules/rules/nestjs/service-patterns.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/nestjs/service-patterns.md
- local: `agent-rules/rules/nestjs/repository-patterns.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/nestjs/repository-patterns.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

LAYER DEFINITIONS:
1.  **Controller Layer**: Controllers, HTTP endpoints, request handling.
2.  **Service Layer**: Business logic, validation, orchestration.
3.  **Repository Layer**: Data access abstraction, queries.
4.  **Data Layer**: Prisma/ORM direct access, external services.

ANALYSIS TARGETS:
1.  **Layer Boundary Violations**:
    *   **CRITICAL**: Controller MUST NOT access Repository or Prisma
        directly. They MUST use a Service.
    *   **CRITICAL**: Controller SHOULD NOT contain business logic.
        They should only handle HTTP concerns.
    *   **CRITICAL**: Service SHOULD NOT contain Prisma/ORM queries
        directly unless simple project. Use Repository pattern.

2.  **Dependency Injection**:
    *   Check for proper constructor injection (not direct instantiation).
    *   Flag rigid dependencies (e.g., `const repo = new Repository();`
        inside a Service instead of constructor injection).
    *   Verify `@Injectable()` decorator on all services/repositories.
    *   Check for abstract repository pattern implementation.

3.  **Module Organization**:
    *   Verify one module per feature/domain.
    *   Check for proper imports/exports declarations.
    *   Ensure services are exported when used by other modules.
    *   Flag circular dependencies (use of `forwardRef`).

4.  **Repository Pattern**:
    *   Verify Repositories abstract the data sources.
    *   Check for abstract class + implementation pattern.
    *   Ensure proper module provider registration.

5.  **Service Composition**:
    *   Flag excessive service-to-service dependencies.
    *   Check for proper delegation between services.
    *   Verify single responsibility principle.

OUTPUT FORMAT:
*   **Architecture Score**: (1-10) based on layer separation.
*   **Violations**:
    *   `[Layer Violation]` [file:line]: Description of the leak
        (e.g., "Controller accessing Prisma directly").
    *   `[DI Issue]` [file:line]: Hardcoded dependency.
    *   `[Logic in Controller]` [file:line]: Business logic in Controller.
     *   `[Module Issue]` [file:line]: Missing export or circular
       dependency.
* **Recommendations**: Specific refactoring advice for correcting layer
violations.
