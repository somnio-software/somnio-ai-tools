# AngularJS State Management Analysis

> Analyze state management patterns for correct service/factory layering, $http centralization and interceptors, and $rootScope discipline.

---

Goal: Analyze the AngularJS codebase for appropriate state management
decisions, correct service/factory layering, and state-scope correctness.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/angularjs/state-management.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/angularjs/state-management.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **State Scope Decisions**:
    *   Check for controller-local state that is unnecessarily promoted to
        `$rootScope` or a global service (over-sharing).
    *   Check for state duplicated across controllers that should live in a
        shared service (under-sharing).
    *   Verify the decision tree: controller-local (`this`) → feature
        `.service`/`.factory` → `$rootScope.$emit`/`$on` events for a few
        global signals.
    *   Flag server-fetched data cached on `$scope`/`$rootScope` instead of a
        data service.

2.  **Service / Factory Layering**:
    *   Check business logic and server access live in `.factory`/`.service`
        units, not inline in controllers.
    *   **CRITICAL**: Flag "fat controllers" that call `$http` directly instead
        of delegating to a data service.
    *   Verify services expose a small, intention-revealing API (methods
        returning promises) rather than leaking `$http` config to callers.
    *   Check singletons are used for shared state (services are singletons in
        AngularJS) rather than re-instantiating logic.

3.  **$http / $resource Centralization & Interceptors**:
    *   Check `$http`/`$resource` calls are centralized in a small set of data
        services, not scattered across controllers.
    *   Verify `$httpProvider.interceptors` handle cross-cutting concerns
        (auth token injection, error handling, spinner) instead of repeating
        that logic per call.
    *   Note `$resource` (declarative REST) vs raw `$http` usage and
        consistency.
    *   Flag manual loading/error boolean bookkeeping duplicated everywhere
        that a shared service or interceptor could own.

4.  **$rootScope Discipline**:
    *   Distinguish legitimate use (`$rootScope.$on`/`$emit`/`$broadcast` for a
        few global events) from misuse ($rootScope as a global data store/bus
        for everything).
    *   **CRITICAL**: Flag heavy `$rootScope` data storage as an anti-pattern.
    *   Verify `$rootScope` listeners registered in controllers are cleaned up
        on `$destroy` (root listeners are not auto-removed).

5.  **Anti-Pattern Detection**:
    *   Flag `$http` scattered through fat controllers with no data service.
    *   Flag prop/scope drilling via nested `$scope` inheritance where a
        service or explicit bindings would be clearer.
    *   Flag business logic duplicated across controllers rather than shared
        in a service.
    *   Check for server data cached on `$rootScope`/`$scope` instead of a
        service with a cache.

OUTPUT FORMAT:
*   **State Management Score**: (1-10) based on scope decisions.
*   **Violations**:
    *   `[Scope Issue]` [file:line]: Server data cached on `$rootScope`/`$scope`.
    *   `[Layering Issue]` [file:line]: `$http` called directly in a controller.
    *   `[Interceptor Gap]` [file:line]: Repeated auth/error logic; no interceptor.
    *   `[$rootScope Misuse]` [file:line]: `$rootScope` used as a data bus.
*   **Recommendations**: Specific refactoring advice per violation.
