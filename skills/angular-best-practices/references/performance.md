# Angular Change Detection & Performance Analysis

> Analyze change-detection strategy, template optimization, lazy loading, bundle budgets, and identify performance anti-patterns.

---

Goal: Analyze the modern Angular codebase for change-detection and
performance optimization patterns, identify missing `OnPush` adoption,
un-tracked lists, and common template performance anti-patterns.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/angular/performance.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/angular/performance.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **Change Detection Strategy**:
    *   Check `ChangeDetectionStrategy.OnPush` is used on presentational
        components (and most feature components) — not left on the default
        `CheckAlways`.
    *   Verify `OnPush` components receive immutable inputs (new object
        references on change) so they update correctly.
    *   Flag manual `ChangeDetectorRef.detectChanges()`/`markForCheck()`
        calls that mask a missing `OnPush` or an immutability problem.
    *   Flag frequent state mutation that defeats `OnPush`.

2.  **Template Evaluation Cost**:
    *   **CRITICAL**: Flag method calls and getters invoked directly in
        template bindings (`{{ compute() }}`, `[x]="getValue()"`) — they run
        on every change-detection cycle. Prefer pure pipes, `computed`
        signals, or precomputed fields.
    *   Verify custom pipes are `pure: true` (the default) unless a stateful
        pipe is genuinely required.
    *   Flag heavy expressions and object/array literals created inline in
        the template.

3.  **List Rendering**:
    *   **CRITICAL**: Check `*ngFor` uses a `trackBy` function (or `@for`
        uses `track`) with a stable unique key — otherwise Angular re-creates
        DOM nodes on every change.
    *   Verify large lists (100+ items) use virtual scrolling
        (`cdk-virtual-scroll-viewport`) instead of rendering everything.
    *   Flag `async` pipe used repeatedly inside an `*ngFor` on the same
        source (multiple subscriptions) — subscribe once above the loop.

4.  **Lazy Loading & Bundle Budgets**:
    *   Check feature routes are lazy-loaded (`loadChildren`/`loadComponent`)
        rather than all eagerly imported into the root.
    *   Verify `angular.json` defines bundle `budgets` (initial / anyComponentStyle)
        and that they are reasonable; flag missing budgets.
    *   Flag large third-party libraries imported eagerly that could be
        deferred or replaced.
    *   Check images/heavy assets use appropriate loading strategies.

5.  **Rendering & Zone Anti-Patterns**:
    *   Flag frequent high-cost operations run inside Angular's zone that
        could use `runOutsideAngular` (e.g. rAF loops, scroll handlers).
    *   Flag un-memoized derived data recomputed on every render instead of
        a `computed` signal or cached observable (`shareReplay`).
    *   Check for un-tracked subscriptions triggering broad change detection.
    *   Flag missing `OnPush` on frequently-updated components.

OUTPUT FORMAT:
*   **Performance Score**: (1-10) based on pattern compliance.
*   **Violations**:
    *   `[CD Issue]` [file:line]: Component missing OnPush / manual detectChanges masking a problem.
    *   `[Template Issue]` [file:line]: Method call in binding re-run each cycle.
    *   `[Key Issue]` [file:line]: `*ngFor` without `trackBy`.
    *   `[Split Opportunity]` [file:line]: Eagerly loaded route/module that should be lazy.
*   **Recommendations**: Specific optimization suggestions per violation.
