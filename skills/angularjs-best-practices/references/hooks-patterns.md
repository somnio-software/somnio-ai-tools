# AngularJS Scope & Binding Patterns Analysis

> Analyze $scope/binding usage for controllerAs discipline, isolate-scope binding correctness, component lifecycle hooks, and $watch/cleanup management.

---

Goal: Analyze the AngularJS codebase for correct scope and binding usage,
component lifecycle hook conventions, and `$watch`/cleanup management.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/angularjs/scope-binding-patterns.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/angularjs/scope-binding-patterns.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **controllerAs vs $scope Discipline**:
    *   **CRITICAL**: Prefer `controllerAs` + `bindToController` (`this.x`)
        over assigning view state directly onto `$scope`.
    *   Flag pervasive `$scope.foo = ...` view models and `$scope`-soup where
        `controllerAs` would isolate and test better.
    *   Verify `$scope` is only injected when genuinely needed
        (`$scope.$watch`, `$scope.$on`, `$scope.$emit`).
    *   Flag controllers that inject `$scope` solely to hold view state.

2.  **Isolate Scope Binding Correctness**:
    *   Check isolate-scope / component `bindings` use the correct type:
        `<` one-way input, `@` string/text, `&` output expression.
    *   **CRITICAL**: Flag `=` two-way bindings used where `<` + an output
        `&` would be clearer and cheaper.
    *   Verify bound values are treated as inputs (not mutated in place when
        `<` is used).
    *   Flag directives that read parent scope implicitly instead of declaring
        explicit bindings.

3.  **Component Lifecycle Hooks**:
    *   Check `$onInit` is used for initialization (not work in the
        constructor / not relying on bindings before `$onInit`).
    *   Verify `$onChanges` handles one-way binding updates.
    *   Verify `$onDestroy` (or `$scope.$on('$destroy', ...)`) tears down
        watches, listeners, intervals, and third-party widgets.
    *   Flag initialization logic that runs before bindings are available.

4.  **$watch Usage & Stability**:
    *   Check `$scope.$watch` / `$watchCollection` are used sparingly and with
        a clear need (prefer `$onChanges` / events where possible).
    *   Flag deep watches (`$watch(expr, fn, true)`) over large objects.
    *   Verify watch listeners are cheap and side-effect-safe (they run every
        digest).
    *   Flag `$watch` registered without a matching `$destroy` cleanup where
        it can leak.

5.  **State & Async in Controllers**:
    *   Check promises (`$q`, `$http`) update `this`/`$scope` in `.then`, and
        that manual `$scope.$apply()` is not sprinkled to force digests.
    *   Verify `$timeout`/`$interval` handles are cancelled on `$onDestroy`.
    *   Flag direct mutation of bound inputs and duplicated stateful logic that
        should move to a service.

6.  **Shared Logic Extraction**:
    *   Check for stateful logic repeated across 2+ controllers/components that
        should be extracted into a `.factory`/`.service`:
        - Form state / validation
        - Data fetching → a data service (`$http`/`$resource`)
        - Debounce → a `$timeout`-based service
        - Local storage → a storage service
        - Cross-component events → a small event service (not `$rootScope`)
    *   Verify extracted services are reusable and not tightly coupled to a
        specific controller.

OUTPUT FORMAT:
*   **Scope & Binding Score**: (1-10) based on compliance and patterns.
*   **Violations**:
    *   `[Scope Discipline]` [file:line]: `$scope`-soup instead of `controllerAs`.
    *   `[Binding Issue]` [file:line]: `=` two-way used where `<` fits.
    *   `[Lifecycle Issue]` [file:line]: Missing `$onDestroy`/watch cleanup.
    *   `[Extraction Opportunity]` [file:line]: Logic should be a service.
*   **Recommendations**: Specific refactoring advice per violation.
