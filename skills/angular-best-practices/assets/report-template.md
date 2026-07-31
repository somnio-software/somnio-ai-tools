# Angular Best Practices Audit Report

**Project:** [PROJECT_NAME]
**Date:** [AUDIT_DATE]
**Auditor:** AI-Assisted Analysis

---

## 1. Executive Summary

**Overall Score:** [XX]/100 ([Strong/Fair/Weak])

**Description:**
[One paragraph summary of the codebase quality and key findings]

**Top Strengths:**
- [Strength 1]
- [Strength 2]
- [Strength 3]

**Critical Issues:**
- [Critical Issue 1]
- [Critical Issue 2]
- [Critical Issue 3]

**Immediate Action Items:**
1. [Most urgent action]
2. [Second priority action]
3. [Third priority action]

---

## 2. Score Breakdown

| Section | Score | Label |
|---------|-------|-------|
| Testing Quality | [XX]/100 | [Label] |
| Component Architecture | [XX]/100 | [Label] |
| Lifecycle & DI Patterns | [XX]/100 | [Label] |
| Services & State Management | [XX]/100 | [Label] |
| Change Detection & Performance | [XX]/100 | [Label] |
| TypeScript Standards | [XX]/100 | [Label] |
| **Weighted Overall** | **[XX]/100** | **[Label]** |

> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)

---

## 3. Testing Quality

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of testing quality findings]

**TestBed Analysis:**
- Specs with mocked dependencies: [XX]%
- `fixture.detectChanges()` before assertions: [Good/Needs Improvement]
- Whole-`AppModule` imports in specs: [None/Found]

**Async Testing:**
- `fakeAsync`/`tick` or `waitForAsync` usage: [Good/Needs Improvement]
- `fixture.whenStable()` awaited: [Correct/Misused]
- Real-timeout reliance: [None/Found]

**HTTP & Dependency Mocking:**
- `HttpClientTestingModule` used: [Yes/No]
- `httpMock.verify()` in teardown: [Yes/No]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]
- [Finding 4]

### Violations
- `[path/to/file.spec.ts:XX]` — [Issue description]
- `[path/to/file.spec.ts:XX]` — [Issue description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 4. Component Architecture

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of component architecture findings]

**Folder / Module Structure:**
- Feature-based organization: [Yes/Partial/No]
- Standalone vs NgModule consistency: [Consistent/Mixed]
- Barrel / public-api exports present: [Yes/No]
- Max nesting depth: [XX] levels

**Component Design:**
- Average component `.ts` size: [XX] lines
- Files over 300 lines: [XX]
- Smart/Dumb (container/presentational) separation: [Used/Not Used]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[path/to/foo.component.ts:XX]` — [Architecture Issue]: [Description]
- `[path/to/foo.component.ts:XX]` — [Size Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 5. Lifecycle & DI Patterns

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of lifecycle and dependency-injection findings]

**Lifecycle Compliance:**
- Hooks with matching `implements` interface: [XX]% compliant
- Work in constructor instead of `ngOnInit`: [None/Found — list files]
- Heavy logic in `ngDoCheck`/`ngAfterViewChecked`: [None/Found]

**Subscription Cleanup:**
- Manual subscriptions torn down: [XX]% where needed
- `takeUntilDestroyed` / `async` pipe usage: [Good/Needs Improvement]
- Subscriptions without `ngOnDestroy`: [XX] occurrences

**Dependency Injection:**
- Constructor / `inject()` used (no manual `new`): [Yes/No]
- Provider scope correctness (`providedIn: 'root'`): [Good/Needs Improvement]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[path/to/foo.component.ts:XX]` — [Cleanup Violation]: [Description]
- `[path/to/bar.service.ts:XX]` — [DI Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 6. Services & State Management

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of services and state management findings]

**State Distribution:**
- Component-local state: [Appropriate/Overused]
- Service state (`BehaviorSubject`/signals): [Present/Missing/Overused]
- HttpClient centralized in services: [Yes/No — components calling HttpClient]
- Store library: [NgRx/NGXS/ComponentStore/None]

**Pattern Compliance:**
- State scope decisions: [Good/Needs Improvement]
- RxJS discipline (async pipe, no nested subscribe): [Good/Needs Improvement]
- HTTP interceptors for cross-cutting concerns: [Used/Not Used/N/A]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[path/to/foo.service.ts:XX]` — [State Issue]: [Description]
- `[path/to/bar.component.ts:XX]` — [Http Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 7. Change Detection & Performance

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of change detection and performance findings]

**Change Detection:**
- `OnPush` adoption: [Widespread/Partial/Missing]
- Manual `detectChanges`/`markForCheck` masking issues: [None/Found]
- Immutable inputs to `OnPush` components: [Good/Needs Improvement]

**Template & Lists:**
- Method calls in template bindings: [XX] occurrences
- `*ngFor` without `trackBy`: [XX] occurrences
- Virtual scrolling for large lists: [Yes/No/N/A]

**Lazy Loading & Budgets:**
- Lazy-loaded routes: [Yes/No]
- `angular.json` bundle budgets: [Present/Missing]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[path/to/foo.component.ts:XX]` — [CD Issue]: [Description]
- `[path/to/list.component.html:XX]` — [Key Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 8. TypeScript Standards

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of TypeScript standards findings]

**TypeScript Configuration:**
- Strict mode: [Enabled/Disabled]
- `strictTemplates`: [Enabled/Disabled]
- `any` usage: [XX] occurrences
- Proper typing: [XX]% coverage

**Component & API Typing:**
- Typed `@Input()`/`@Output()`: [XX]% compliant
- Typed HTTP responses: [Used/Not Used]
- Typed reactive forms: [XX]% compliant
- Generic services/components: [Present/Missing/N/A]

**Angular Type Utilities:**
- `Observable<T>`/`Signal<T>` typing: [Correct/Misused]
- `InjectionToken<T>` for non-class deps: [Present/N/A]
- `@angular-eslint` configured: [Yes/No]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[path/to/foo.component.ts:XX]` — [Type Issue]: [Description]
- `[path/to/models.ts:XX]` — [Naming Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 9. Prioritized Recommendations

### 🔴 Critical (Must Fix Immediately)
1. [Critical recommendation with file reference]
2. [Critical recommendation with file reference]

### 🟠 High Priority
1. [High priority recommendation]
2. [High priority recommendation]
3. [High priority recommendation]

### 🟡 Medium Priority
1. [Medium priority recommendation]
2. [Medium priority recommendation]
3. [Medium priority recommendation]

### 🟢 Low Priority (Nice to Have)
1. [Low priority recommendation]
2. [Low priority recommendation]

---

## 10. Evidence Index

**Spec Files Analyzed:**
- `[path/to/file.spec.ts]`
- `[path/to/file.spec.ts]`

**Component Files Analyzed:**
- `[path/to/foo.component.ts]`
- `[path/to/foo.component.ts]`

**Service Files Analyzed:**
- `[path/to/foo.service.ts]`
- `[path/to/bar.service.ts]`

**Store / State Files Analyzed:**
- `[path/to/foo.store.ts]`
- `[path/to/foo.reducer.ts]`

---

## Report Metadata

| Field | Value |
|-------|-------|
| Generated by | [Plugin Name] v[Plugin Version] |
| Skill | angular-best-practices |
| Date | [YYYY-MM-DD] |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
| Standards Source | https://github.com/somnio-software/somnio-ai-tools |
