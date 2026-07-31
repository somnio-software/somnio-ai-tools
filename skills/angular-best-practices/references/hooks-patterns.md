# Angular Lifecycle & DI Patterns Analysis

> Analyze lifecycle-hook usage, subscription cleanup, decorators, and dependency-injection patterns for correctness and Angular conventions.

---

Goal: Analyze the modern Angular codebase for correct lifecycle-hook
usage, subscription cleanup, and dependency-injection patterns.
Unlike React (which has function-component hooks), Angular uses class
lifecycle interface methods (`ngOnInit`, `ngOnDestroy`, ...), decorators,
and constructor/`inject()` dependency injection.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/angular/lifecycle-di-patterns.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/angular/lifecycle-di-patterns.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **Lifecycle Interface Compliance**:
    *   Verify every lifecycle method has its matching `implements`
        interface (`implements OnInit`, `OnDestroy`, `OnChanges`, etc.).
        Flag an `ngOnInit()` on a class that does not implement `OnInit`.
    *   Check hook methods are named exactly (`ngOnInit`, not `NgOnInit`).
    *   Flag empty lifecycle hooks left by the CLI scaffolder.
    *   Verify no async data work is done in the constructor — it belongs
        in `ngOnInit`.

2.  **Subscription Cleanup (CRITICAL — memory-leak class)**:
    *   **CRITICAL**: Every manual `.subscribe(...)` must be torn down —
        via `takeUntilDestroyed()`, a `takeUntil(destroy$)` + `ngOnDestroy`
        pattern, or `Subscription.unsubscribe()` in `ngOnDestroy`.
    *   Prefer the `async` pipe in templates over manual subscribe.
    *   Flag components that subscribe in `ngOnInit` but have no
        `ngOnDestroy` cleanup.
    *   Flag nested subscriptions that should use a flattening operator
        (`switchMap`, `concatMap`, `mergeMap`).

3.  **Dependency Injection Patterns**:
    *   Check DI is done via constructor parameters or the `inject()`
        function — not manual `new Service()` instantiation.
    *   Verify `@Injectable({ providedIn: 'root' })` for singletons;
        flag services listed in many component `providers` arrays that
        unintentionally create multiple instances.
    *   Check injection tokens (`InjectionToken`) are used for non-class
        dependencies instead of string tokens.
    *   Flag over-broad services injected where a narrower one exists.

4.  **Change-Detection-Sensitive Hooks**:
    *   Flag heavy or allocating logic inside `ngDoCheck` or
        `ngAfterViewChecked` (runs on every change-detection cycle).
    *   Verify `ngOnChanges` reads from the `SimpleChanges` argument
        rather than assuming inputs are already set.
    *   Flag DOM reads/writes outside `ngAfterViewInit` where a
        `@ViewChild` is required first.

5.  **Decorator & Input/Output Correctness**:
    *   Check `@Input()`/`@Output()` (or the `input()`/`output()` signal
        APIs) are used for component I/O rather than public mutable fields.
    *   Verify `@HostListener`/`@HostBinding` used instead of manual DOM
        listeners where appropriate, with cleanup handled by Angular.
    *   Flag `@ViewChild`/`@ContentChild` results read before the
        corresponding lifecycle hook has fired.

6.  **Reusable Logic Extraction**:
    *   Check for stateful logic repeated across 2+ components that should
        be extracted into an injectable service (or a directive/pipe).
    *   Verify shared cross-cutting behavior uses attribute directives
        instead of copy-pasted component code.
    *   Verify extracted services are single-responsibility and not tightly
        coupled to one component.

OUTPUT FORMAT:
*   **Lifecycle & DI Score**: (1-10) based on compliance and patterns.
*   **Violations**:
    *   `[Cleanup Violation]` [file:line]: Subscription without teardown.
    *   `[Lifecycle Issue]` [file:line]: Hook without matching interface / work in constructor.
    *   `[DI Issue]` [file:line]: Manual instantiation or wrong provider scope.
    *   `[Extraction Opportunity]` [file:line]: Logic should be an injectable service.
*   **Recommendations**: Specific refactoring advice per violation.
