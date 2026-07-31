# Angular Component Architecture Analysis

> Analyze codebase for adherence to feature-module/standalone structure, smart/dumb composition, dependency injection, and naming conventions.

---

Goal: Analyze the modern Angular codebase for strict adherence to
feature-based organization (NgModules or standalone components),
component composition patterns, and separation of concerns.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/angular/component-architecture.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/angular/component-architecture.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

FOLDER STRUCTURE ANALYSIS:
1.  **Feature-Based Organization**:
    *   Check for a `src/app/features/` (or `src/app/<feature>/`) structure
        with feature modules or standalone route groups.
    *   Verify features are self-contained (components, services,
        models, routing colocated), with `core/` and `shared/` separated.
    *   Flag flat structures that dump unrelated components in one folder.
    *   Check for max 3-4 nesting levels.

2.  **Naming Conventions**:
    *   Check the Angular file-suffix convention: `user-profile.component.ts`,
        `auth.service.ts`, `highlight.directive.ts`, `currency.pipe.ts`,
        `app.module.ts` (kebab-case filenames).
    *   Verify class names are PascalCase and match the suffix
        (`UserProfileComponent`, `AuthService`).
    *   Check component/directive selectors use a consistent prefix
        (`app-`, or a project prefix from `angular.json`).
    *   Check `index.ts` / `public-api.ts` barrel exports for a library's
        public API.

COMPONENT DESIGN ANALYSIS:
3.  **Component File Size**:
    *   Component `.ts` files under 150 lines: Healthy.
    *   Files 150-300 lines: Acceptable, note for review.
    *   Files over 300 lines: FLAG - likely violating single
        responsibility.
    *   Recommend splitting by logical sections (presentational child
        components, services for logic, models for types). Flag inline
        templates over ~40 lines that should move to a `.html` file.

4.  **Composition Patterns**:
    *   Check for Smart (container) / Dumb (presentational) separation:
        presentational components use `@Input()`/`@Output()` only and
        `ChangeDetectionStrategy.OnPush`, containers wire services.
    *   Verify business logic lives in services, NOT in the component
        class or template expressions.
    *   Check for `@Input()` drilling through more than 2-3 component
        levels (suggest a shared service or content projection).
    *   Flag components doing too many things (HTTP calls + heavy
        template logic + state orchestration in one component).

5.  **Module / Standalone & Declaration Patterns**:
    *   **CRITICAL**: A component/directive/pipe must be declared/imported
        exactly once — flag duplicate declarations or a component declared
        in multiple NgModules.
    *   For standalone components, verify `standalone: true` with an
        explicit `imports` array (no leftover `declarations`).
    *   Check barrel/`public-api.ts` files export only the intended public
        surface; flag circular imports created by barrels.
    *   Verify a consistent pattern (all-standalone vs NgModule-based)
        across feature folders rather than an inconsistent mix.

6.  **Colocated Files & Dependency Injection**:
    *   Check that spec, template, and style files are colocated with the
        component (`foo.component.ts`, `foo.component.html`,
        `foo.component.scss`, `foo.component.spec.ts`).
    *   Verify services are provided at the correct scope
        (`providedIn: 'root'` for singletons, component-level `providers`
        only when a scoped instance is intended).
    *   Flag global model/type files that should be colocated with their
        feature.

OUTPUT FORMAT:
*   **Architecture Score**: (1-10) based on folder organization.
*   **Violations**:
    *   `[Folder Issue]` [path]: Flat structure mixing unrelated components.
    *   `[Size Issue]` [file:line]: Component exceeds 300 lines.
    *   `[Declaration Issue]` [file:line]: Component declared in multiple modules.
    *   `[Composition Issue]` [file:line]: Business logic in component/template instead of a service.
*   **Recommendations**: Specific refactoring advice for violations.
