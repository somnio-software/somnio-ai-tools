# Angular Services & State Management Analysis

> Analyze state management patterns for correct tool selection: services with RxJS/signals, HttpClient centralization, interceptors, and NgRx usage.

---

Goal: Analyze the modern Angular codebase for appropriate state
management decisions, correct RxJS/signals usage, HttpClient
centralization, and state scope correctness.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/angular/state-management.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/angular/state-management.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **State Scope Decisions**:
    *   Check for component-local state that is unnecessarily lifted into a
        global store (over-sharing).
    *   Check for state duplicated across components that should live in a
        shared service (under-sharing / prop drilling via `@Input()`).
    *   Verify the decision tree: component field → service with
        `BehaviorSubject`/signal → NgRx/NGXS/ComponentStore is followed,
        and a heavy store is not introduced for trivial state.
    *   Flag server-fetched data cached ad-hoc in components instead of a
        service with an observable/signal cache.

2.  **Service Layer & HttpClient Centralization**:
    *   **CRITICAL**: `HttpClient` calls belong in injectable services, NOT
        directly in components. Flag components importing `HttpClient`.
    *   Verify data-access services expose typed methods returning
        `Observable<T>` and map raw responses to domain models.
    *   Check cross-cutting HTTP concerns (auth headers, error handling,
        retries, base URL) live in `HttpInterceptor`s, not repeated per call.
    *   Flag duplicated fetch/error/loading boolean juggling that a shared
        service (or a resource/query abstraction) should own.

3.  **RxJS Discipline**:
    *   Prefer the `async` pipe for template subscriptions over manual
        `.subscribe()` (which requires manual teardown).
    *   Flag nested `.subscribe()` inside another `.subscribe()` — use a
        flattening operator (`switchMap`/`concatMap`/`mergeMap`/`exhaustMap`).
    *   Verify subjects exposed from services are read-only to consumers
        (`asObservable()` / `.readonly` signal), not the raw `Subject`.
    *   Check operator choice: `switchMap` for cancel-previous, `shareReplay`
        for multicast caching, `distinctUntilChanged` to reduce emissions.

4.  **Signals & Reactive State**:
    *   Where signals are used, check `signal()`/`computed()`/`effect()` are
        applied correctly (no side effects inside `computed`).
    *   Verify writable signals are exposed as read-only (`asReadonly()`)
        from services.
    *   Flag mixing signals and observables for the same piece of state
        without a clear bridge (`toSignal`/`toObservable`).

5.  **Store Libraries (NgRx / NGXS / ComponentStore)**:
    *   If a store library is present, check actions/reducers/selectors (or
        state classes) follow the library's conventions.
    *   Verify selectors are used to read slices (no reading raw state).
    *   Verify side effects live in `@ngrx/effects` (or equivalent), not in
        components.
    *   Flag a global store used for state that is purely component-local.

6.  **Anti-Pattern Detection**:
    *   Flag manual mutation of state objects/arrays instead of immutable
        updates (breaks `OnPush` and store change detection).
    *   Flag `HttpClient` or business logic embedded in components.
    *   Flag manual loading/error flags where a shared pattern exists.
    *   Flag subscriptions in services that are never torn down.

OUTPUT FORMAT:
*   **State Management Score**: (1-10) based on scope decisions.
*   **Violations**:
    *   `[Scope Issue]` [file:line]: Component-local state in global store (or vice versa).
    *   `[Http Issue]` [file:line]: HttpClient called from a component instead of a service.
    *   `[RxJS Issue]` [file:line]: Nested subscribe / untorn-down subscription.
    *   `[Store Issue]` [file:line]: Effect/business logic in component instead of store.
*   **Recommendations**: Specific refactoring advice per violation.
