# AngularJS JavaScript Standards Analysis

> Analyze minification-safe dependency injection, IIFE + 'use strict' module hygiene, JSHint/ESLint configuration, and JavaScript code-quality patterns.

---

Goal: Analyze the AngularJS codebase for minification-safe DI, JavaScript
module hygiene, and linting/quality enforcement.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/angularjs/javascript-standards.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/angularjs/javascript-standards.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

> Note: AngularJS 1.x codebases are plain JavaScript, not TypeScript. This
> standard covers the equivalent JS-level guarantees: minification-safe DI,
> module hygiene, and linting. (If the project happens to layer TypeScript on
> top, apply strict-mode typing as an additional bonus, but the checks below
> are the primary standard.)

ANALYSIS TARGETS:
1.  **Linter Configuration**:
    *   Check `.jshintrc`, `.eslintrc.*`, or `eslint.config.*` exists and
        covers the source tree (not just a stray file).
    *   Verify Angular-aware linting: `eslint-plugin-angular`, or JSHint
        globals declaring `angular`, `$`, `module`, `inject`.
    *   Check rules like `no-unused-vars`, `no-undef`, and DI-safety rules
        (`angular/di`) are enabled.
    *   Flag disabled rules that matter for AngularJS quality.

2.  **Minification-Safe DI (CRITICAL for Angular 1.x)**:
    *   **CRITICAL**: Flag positional injection with NO annotation, e.g.
        `.controller('X', function ($scope, $http) {...})` without a matching
        `['$scope', '$http', function(...)]` array or `X.$inject = [...]`.
    *   Confirm ONE of these is present and consistent across the codebase:
        - inline array annotation `['$scope', function($scope){}]`
        - explicit `$inject` property
        - an `ng-annotate`/`ngAnnotate` build step
    *   If the app is minified AND none of the above is present, that is a
        CRITICAL runtime-breakage finding (injector resolves mangled names),
        not a style nit.

3.  **Module Hygiene (IIFE + 'use strict')**:
    *   **CRITICAL**: Check each source file is wrapped in an IIFE
        `(function () { ... })();` (or a module bundler provides scope) so
        nothing leaks to `window`/global scope.
    *   Check `'use strict';` at the top of files or inside the IIFE.
    *   Flag code that attaches to `window`/global directly or re-declares the
        app module inconsistently.

4.  **No console / debug residue**:
    *   **CRITICAL**: Flag all `console.log`/`console.debug` occurrences in
        source (excluding specs/vendor).
    *   Flag `debugger;` statements.
    *   Count `eslint-disable` / `jshint ignore` comments; flag broad or
        unexplained disables.

5.  **No DOM / jQuery in Controllers or Services**:
    *   Flag direct DOM/jQuery manipulation inside controllers/services
        (`$('...')`, `angular.element(document...)`, `document.getElementById`)
        — an AngularJS anti-pattern; DOM work belongs in directives.
    *   Verify `angular.element` (jqLite) is confined to directive `link`
        functions, not controllers.

6.  **Formatter & Consistency**:
    *   Check `.prettierrc`/`prettier.config.*` or `.editorconfig` exists.
    *   Verify a lint task exists in `package.json` scripts / Grunt / gulp and
        targets the source directory (and ideally runs in CI).
    *   Flag inconsistent quote/semicolon/indentation style with no enforcement.

OUTPUT FORMAT:
*   **JavaScript Standards Score**: (1-10) based on DI safety and hygiene.
*   **Violations**:
    *   `[Unsafe DI]` [file:line]: Positional injection with no annotation.
    *   `[Module Hygiene]` [file:line]: Missing IIFE / `'use strict'` / global leak.
    *   `[Debug Residue]` [file:line]: `console.log` / `debugger` in source.
    *   `[DOM in Controller]` [file:line]: jQuery/DOM manipulation in a controller.
*   **Recommendations**: Specific improvements per violation.
