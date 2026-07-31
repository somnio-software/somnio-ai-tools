# Angular State & Data Flow Analysis

> Analyze state management approach, service layering, HttpClient centralization, RxJS discipline, and store-library choices in a modern Angular project.

---

Goal: Analyze the Angular project's state & data flow to evaluate
service layering, RxJS usage, server/client state separation, and
overall state architecture quality. (This maps to the report's "State
Management" section.)

ANALYSIS TARGETS:

1. **State Management Library Detection**:
   - Check `package.json` dependencies for:
     * `@ngrx/store` + `@ngrx/effects` — Redux-style global store
     * `@ngrx/component-store` — local component store
     * `@ngrx/signals` — signal store (modern)
     * `@ngxs/store` — NGXS
     * `@datorama/akita` / `@ngneat/elf` — alternative stores
   - Detect Angular Signals usage (Angular 16+):
     `grep -rn "signal(\|computed(\|effect(" src/ --include="*.ts" | wc -l`
   - Note if state is held only in plain `@Injectable` services with
     `BehaviorSubject`/`Subject` (appropriate for small/medium apps)

2. **Service Layering**:
   - Count services: `find src/ -name "*.service.ts" | wc -l`
   - Check that components delegate data access to services rather than
     calling `HttpClient` directly in components
   - Flag `HttpClient` used inside `*.component.ts`:
     `grep -rln "HttpClient" src --include="*.component.ts"`

3. **HttpClient Centralization & Interceptors**:
   - Confirm `HttpClient` (`provideHttpClient` / `HttpClientModule`) is
     used, not `fetch`/`XMLHttpRequest` ad hoc
   - Find HTTP interceptors:
     `grep -rln "HTTP_INTERCEPTORS\|HttpInterceptor\|withInterceptors" src`
   - Interceptors for auth/error/logging are a positive centralization signal

4. **RxJS Discipline** (memory-leak and readability risk):
   - Count `.subscribe(` calls:
     `grep -rn "\.subscribe(" src --include="*.ts" | wc -l`
   - Count `async` pipe usage in templates:
     `grep -rn "| async" src --include="*.html" | wc -l`
   - Check unsubscribe hygiene: presence of `takeUntilDestroyed`,
     `takeUntil(`, `DestroyRef`, or `AsyncPipe` vs raw `subscribe` with no
     teardown — raw subscriptions without teardown are a leak risk
   - Flag nested subscribes (anti-pattern; should use higher-order
     operators like `switchMap`/`mergeMap`):
     `grep -rn "subscribe" src` then inspect suspicious files

5. **NgRx / NGXS Usage** (if present):
   - Find store artifacts: actions, reducers, effects, selectors, or
     `signalStore`/`StateClass`
   - Verify effects handle side effects (not components)
   - Verify selectors are used for reads (not reaching into state directly)
   - Note if a heavy global store is used for trivial local state
     (over-engineering)

6. **Anti-Pattern Detection**:
   - Business/data-fetching logic inside components instead of services
   - Manual subscription management with no teardown (leaks)
   - Manually mutating shared state instead of immutable updates
   - Storing derived data instead of using `computed`/selectors/`async`

OUTPUT FORMAT:

Provide structured analysis:
- State approach: [Signals/NgRx/NGXS/ComponentStore/BehaviorSubject services/Mixed]
- Store library detected: [name or None — plain services]
- Services count: [XX]
- HttpClient centralized in services: [Yes/Partial/No]
- HTTP interceptors present: [XX]
- .subscribe() count: [XX]
- async pipe usage: [XX]
- Unsubscribe hygiene: [takeUntilDestroyed/takeUntil/async-pipe/None]
- Anti-patterns found: [list — direct HttpClient in components, nested
  subscribes, unmanaged subscriptions]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Clear service layer; components consume observables via the async pipe
- HttpClient centralized with interceptors for cross-cutting concerns
- Subscriptions torn down (takeUntilDestroyed / async pipe) — no leak risk
- State library (or Signals/plain services) appropriate for project size

Fair (70-84):
- Mostly service-based but some direct HttpClient in components
- Mix of async pipe and manual subscribe with partial teardown
- Store choice slightly over/under-scaled

Weak (0-69):
- Data fetching and business logic living in components
- Many unmanaged subscriptions (memory-leak risk)
- Nested subscribes; no interceptors; ad hoc fetch
- Heavy global store for trivial state, or no coherent approach
