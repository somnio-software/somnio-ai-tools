# AngularJS Performance Analysis

> Analyze digest-cycle hygiene, binding cost (one-time/one-way), list rendering (ng-repeat track by), $sce/sanitization, and identify performance anti-patterns.

---

Goal: Analyze the AngularJS codebase for digest-cycle performance, identify
excessive or expensive watchers, and detect common Angular 1.x performance
anti-patterns.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/angularjs/performance.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/angularjs/performance.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **Digest & $watch Cost**:
    *   Check the total count of `$scope.$watch` / `$watchCollection`
        registrations — every watcher runs on every digest.
    *   **CRITICAL**: Flag deep watches (`$watch(expr, fn, true)`) over large
        objects/arrays.
    *   Flag expensive function expressions in the view (`{{ compute() }}`,
        `ng-if="expensive()"`) that re-run each digest.
    *   Flag manual `$scope.$apply()` / `$timeout(fn, 0)` used to force digests
        around non-Angular async (often a smell).

2.  **Binding Cost (one-time / one-way)**:
    *   Check one-time bindings (`::`) are used for values that never change
        after first render (labels, static lists).
    *   Verify component/directive inputs use `<` one-way bindings instead of
        `=` two-way where a value only flows downward.
    *   Flag pervasive `=` two-way bindings that inflate the digest.
    *   Check large static templates don't register needless watchers.

3.  **List Rendering**:
    *   **CRITICAL**: Check `ng-repeat` uses `track by` (e.g.
        `ng-repeat="item in items track by item.id"`) so DOM nodes are reused
        instead of rebuilt.
    *   Flag `ng-repeat` over large collections without `track by` or filters
        recomputed each digest.
    *   Check for very long lists (100+ items) rendered without pagination,
        infinite scroll, or a virtual-scroll directive.
    *   Flag in-view filtering/sorting (`ng-repeat="x in items | filter | orderBy"`)
        that recomputes each digest instead of precomputing in the controller.

4.  **Sanitization & Rendering ($sce)**:
    *   Check `$sce` / `ng-bind-html` usage: HTML is sanitized (`ngSanitize`)
        or trusted deliberately via `$sce.trustAsHtml`, never by disabling SCE
        globally.
    *   Flag `$sceProvider.enabled(false)` or blanket `trustAsHtml` on
        user-provided content (XSS + rendering cost).
    *   Prefer `ng-bind` over `{{ }}` interpolation in hot paths to avoid FOUC
        and reduce watchers.

5.  **Re-render / Digest Anti-Patterns**:
    *   Flag DOM manipulation inside controllers/services instead of directives
        (forces manual digests, breaks data flow).
    *   Flag watchers with side effects that mutate watched state (digest
        thrash / `$digest already in progress`).
    *   Check third-party widgets are wrapped in directives and torn down on
        `$destroy` (leaks otherwise).
    *   Flag global `$rootScope` watchers that run for the whole app.

OUTPUT FORMAT:
*   **Performance Score**: (1-10) based on pattern compliance.
*   **Violations**:
    *   `[Watch Issue]` [file:line]: Deep watch over a large object.
    *   `[Track By Issue]` [file:line]: `ng-repeat` without `track by`.
    *   `[Binding Issue]` [file:line]: `=` two-way where `<`/`::` fits.
    *   `[Digest Issue]` [file:line]: Manual `$apply`/DOM work forcing digests.
*   **Recommendations**: Specific optimization suggestions per violation.
