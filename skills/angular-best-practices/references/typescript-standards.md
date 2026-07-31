# Angular TypeScript Standards Analysis

> Analyze TypeScript strictness, Angular strict-template type-checking, angular-eslint, typed inputs/outputs, and type safety patterns.

---

Goal: Analyze the modern Angular codebase for TypeScript strict-mode
compliance, Angular strict-template type-checking, and Angular-specific
type usage.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/angular/typescript.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/angular/typescript.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **TypeScript Configuration**:
    *   Check `tsconfig.json` has `"strict": true`.
    *   Verify `"noImplicitAny": true` (covered by strict).
    *   Check `"strictNullChecks": true` (covered by strict).
    *   Check Angular strict flags under `angularCompilerOptions`:
        `"strictTemplates": true`, `"strictInjectionParameters": true`,
        and (ideally) `"strictTemplateTypeCheck"`.
    *   Verify path aliases (`paths` / `baseUrl`) are configured.

2.  **Component I/O & API Typing**:
    *   Check `@Input()`/`@Output()` (or `input()`/`output()`) properties
        are explicitly typed — never left as implicit `any`.
    *   Verify `@Output() EventEmitter<T>` uses a concrete payload type.
    *   Check public component/service methods have explicit return types.
    *   Verify HTTP calls are typed (`HttpClient.get<User[]>(...)`), and
        response models are declared as `interface`/`type` — never `any`.

3.  **No `any` Usage**:
    *   **CRITICAL**: Flag all occurrences of the `any` type.
    *   Check `unknown` is used (with narrowing) where a value is genuinely
        untyped, instead of `any`.
    *   Flag `as any` type assertions and `<any>` casts.
    *   Check for implicit `any` from untyped function parameters and
        untyped `catchError` callbacks.

4.  **Typed Forms & Generics**:
    *   Check reactive forms use typed `FormGroup`/`FormControl<T>`
        (typed forms) rather than untyped forms.
    *   Check reusable services/components use generics with meaningful
        constraints (`<T extends object>` not just `<T>`), avoiding `any`.
    *   Verify route data / resolvers are typed.

5.  **Angular & TS Utility Types**:
    *   Check correct use of `Observable<T>`, `Signal<T>`, `WritableSignal<T>`
        rather than untyped streams.
    *   Verify DI tokens use `InjectionToken<T>` (typed) instead of string
        tokens.
    *   Check narrowing/`readonly` used for immutable data exposed to
        `OnPush` templates.

6.  **angular-eslint & Interface vs Type Rules**:
    *   Check `@angular-eslint` (and `@typescript-eslint`) is configured;
        flag deprecated TSLint remnants.
    *   Check `interface` used for object shapes that can be extended, and
        `type` for unions/intersections/mapped types.
    *   Flag disabled strict lint rules or blanket `eslint-disable` that
        suppress type-safety warnings.

OUTPUT FORMAT:
*   **TypeScript Score**: (1-10) based on strict compliance.
*   **Violations**:
    *   `[Any Usage]` [file:line]: Explicit `any` type found.
    *   `[Input Typing]` [file:line]: Untyped `@Input()`/`@Output()`.
    *   `[Config Issue]` [tsconfig.json]: Missing strict / `strictTemplates` option.
    *   `[Form Typing]` [file:line]: Untyped reactive form.
*   **Recommendations**: Specific typing improvements per violation.
