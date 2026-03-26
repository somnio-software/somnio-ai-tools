# React Component Architecture Analysis

> Analyze codebase for adherence to feature-based folder structure, component composition, and naming conventions.

---

Goal: Analyze the React codebase for strict adherence to feature-based
organization, component composition patterns, and separation of concerns.

STANDARDS SOURCE (local):
- `agent-rules/rules/react/component-architecture.md`

To resolve the absolute path: find the directory containing
`skills/react-best-practices/SKILL.md`, go up two levels to reach
the somnio-ai-tools repository root, then read the file above.

INSTRUCTIONS:
1. USE the `Read` tool to read the local standards file listed above.
2. Proceed with the analysis below using strict adherence to those rules.

FOLDER STRUCTURE ANALYSIS:
1.  **Feature-Based Organization**:
    *   Check for `src/features/` or `src/components/` structure.
    *   Verify features are self-contained (components, hooks,
        services, types colocated).
    *   Flag flat structures that mix unrelated components.
    *   Check for max 3-4 nesting levels.

2.  **Naming Conventions**:
    *   Check PascalCase for component files (e.g., `UserProfile.tsx`).
    *   Check kebab-case for utility files (e.g., `format-date.ts`).
    *   Verify component files match exported component name.
    *   Check index.ts barrel exports for public API.

COMPONENT DESIGN ANALYSIS:
3.  **Component File Size**:
    *   Files under 150 lines: Healthy.
    *   Files 150-300 lines: Acceptable, note for review.
    *   Files over 300 lines: FLAG - likely violating single
        responsibility.
    *   Recommend splitting by logical sections (UI, logic, types).

4.  **Composition Patterns**:
    *   Check for Container/Presenter (Smart/Dumb) separation where
        applicable.
    *   Verify business logic is NOT directly in render/JSX.
    *   Check for prop drilling more than 2-3 levels (suggest Context
        or composition).
    *   Flag components doing too many things (data fetching + complex
        UI + business logic).

5.  **Export Patterns**:
    *   **CRITICAL**: Named exports preferred over default exports
        for components.
    *   Check barrel `index.ts` files export only public API.
    *   Flag circular imports created by barrel files.
    *   Verify consistent export pattern across feature folders.

6.  **Colocated Files**:
    *   Check that tests, styles, and types are colocated with
        components.
    *   Verify `Component.tsx`, `Component.test.tsx`,
        `Component.types.ts` pattern.
    *   Flag global type files that should be colocated.

OUTPUT FORMAT:
*   **Architecture Score**: (1-10) based on folder organization.
*   **Violations**:
    *   `[Folder Issue]` [path]: Flat structure mixing unrelated components.
    *   `[Size Issue]` [file:line]: Component exceeds 300 lines.
    *   `[Export Issue]` [file:line]: Default export used instead of named.
    *   `[Composition Issue]` [file:line]: Business logic in JSX render.
*   **Recommendations**: Specific refactoring advice for violations.
