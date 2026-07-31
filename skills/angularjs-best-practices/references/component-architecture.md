# AngularJS Component Architecture Analysis

> Analyze codebase for adherence to feature-based module structure, controller/directive/component composition, and naming conventions.

---

Goal: Analyze the AngularJS codebase for strict adherence to feature-based
module organization, `.component()`/`controllerAs` composition patterns, and
separation of concerns.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/angularjs/component-architecture.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/angularjs/component-architecture.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

FOLDER / MODULE STRUCTURE ANALYSIS:
1.  **Feature-Based Organization**:
    *   Check for feature modules (`angular.module('app.feature', [...])`)
        with components, directives, controllers, and services colocated.
    *   Prefer feature folders (`app/orders/`) over type folders
        (`controllers/`, `services/`, `directives/` split app-wide).
    *   Flag flat structures that mix unrelated features.
    *   Check for max 3-4 nesting levels.

2.  **Naming Conventions**:
    *   Check `camelCase` component/directive names in JS
        (`orderList`) rendering as kebab-case in templates (`<order-list>`).
    *   Check PascalCase for controller constructor names
        (`OrderListController`) and `kebab-case` for filenames
        (`order-list.component.js`).
    *   Verify one AngularJS unit (component/controller/service) per file.
    *   Check module registration files (`*.module.js`) declare the module
        and its dependencies clearly.

COMPONENT DESIGN ANALYSIS:
3.  **Unit File Size**:
    *   Files under 150 lines: Healthy.
    *   Files 150-300 lines: Acceptable, note for review.
    *   Files over 300 lines: FLAG - likely a fat controller violating single
        responsibility.
    *   Recommend splitting by logical sections (template, controller, service).

4.  **Composition Patterns**:
    *   **CRITICAL**: Prefer `.component()` + `controllerAs` + `bindToController`
        over `$scope`-heavy controllers assigning directly to `$scope`.
    *   Verify business logic and server access live in `.factory`/`.service`
        units, NOT inline in controllers ("fat controller" smell).
    *   Choose `.component()` for UI building blocks; reserve `.directive()`
        for behavior needing `link`/DOM/transclusion.
    *   Flag controllers doing too many things (data fetching + DOM
        manipulation + business logic).

5.  **Registration & Export Patterns**:
    *   **CRITICAL**: Register units on a named module
        (`angular.module('app.feature').component(...)`), not by leaking
        globals onto `window`.
    *   Verify each file registers exactly one unit and wraps it in an IIFE.
    *   Flag re-opening the same module inconsistently
        (`angular.module('app', [])` vs `angular.module('app')`).
    *   Verify consistent registration style across feature folders.

6.  **Colocated Files**:
    *   Check that specs, templates, and styles are colocated with the unit.
    *   Verify `order-list.component.js`, `order-list.component.spec.js`,
        `order-list.template.html` pattern.
    *   Flag inline template strings for non-trivial markup that should be
        external `templateUrl` files.

OUTPUT FORMAT:
*   **Architecture Score**: (1-10) based on module organization.
*   **Violations**:
    *   `[Folder Issue]` [path]: Type-based split mixing unrelated features.
    *   `[Size Issue]` [file:line]: Controller exceeds 300 lines (fat controller).
    *   `[Composition Issue]` [file:line]: `$scope`-soup instead of `controllerAs`.
    *   `[Registration Issue]` [file:line]: Unit leaks a global / no IIFE.
*   **Recommendations**: Specific refactoring advice for violations.
