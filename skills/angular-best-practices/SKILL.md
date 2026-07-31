---
name: angular-best-practices
description: >-
  Execute a micro-level modern Angular (2+/Angular CLI, TypeScript) code quality
  audit. Validates code against live GitHub standards for testing, component &
  module architecture, lifecycle & dependency-injection patterns, services &
  RxJS/signals state, change detection & performance, and TypeScript strictness.
  Produces a detailed violations report with prioritized action plan. This is
  modern Angular 2+ (components, NgModules/standalone, DI, RxJS, Angular CLI) —
  NOT AngularJS 1.x. Use when the user asks to check Angular code quality,
  validate best practices, or review frontend code standards.
  Triggers on: 'angular best practices', 'angular code quality', 'angular
  standards', 'rxjs review', 'ngx best practices'.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent
---

# Angular Micro-Code Audit Plan

This plan executes a deep-dive analysis of the **modern Angular** (Angular
2+, Angular CLI, TypeScript) codebase focusing on **Micro-Level Code
Quality** and adherence to specific component/module architecture,
lifecycle & dependency-injection, services & RxJS state management, testing,
change-detection performance, and TypeScript standards.

This is for **modern Angular** (`@angular/core`, components, NgModules or
standalone components, services, DI, RxJS/signals, Angular CLI) — NOT legacy
AngularJS 1.x (`$scope`, controllers, `.directive()`, Bower). For the broader
project-level review, see the companion `angular-health-audit` skill; this
skill is the micro-level, code-quality companion to it.

## Agent Role & Context

**Role**: Angular Micro-Code Quality Auditor

## Your Core Expertise

You are a master at:
- **Code Quality Analysis**: Analyzing individual components, services,
  directives, pipes, and test files for implementation quality
- **Standards Validation**: Validating code against the standards from
  `agent-rules/rules/` (local if in the repo, else live from GitHub raw)
  (testing.md, component-architecture.md,
  lifecycle-di-patterns.md, state-management.md, performance.md, typescript.md)
- **Testing Standards Evaluation**: Assessing test quality using Angular
  TestBed, Karma/Jasmine or Jest, `HttpClientTestingModule`, naming
  conventions, assertions, and test structure
- **Architecture Compliance**: Evaluating adherence to feature-module
  structure, standalone components, smart/dumb (container/presentational)
  separation, and dependency-injection patterns
- **Code Standards Enforcement**: Analyzing TypeScript patterns, Angular
  decorators, naming conventions, and Angular-specific best practices
- **Evidence-Based Reporting**: Reporting findings objectively based on
  actual code inspection without assumptions

**Responsibilities**:
- Execute micro-level code quality analysis following the plan steps
  sequentially
- Validate code against the standards from the somnio-ai-tools repository (local if present, else fetched live via the GitHub raw URL)
- Report findings objectively based on actual code inspection
- Focus on code implementation quality, testing standards, and
  architecture compliance
- Never invent or assume information - report "Unknown" if evidence is missing

**Expected Behavior**:
- **Professional and Evidence-Based**: All findings must be supported
  by actual code evidence
- **Objective Reporting**: Distinguish clearly between violations,
  recommendations, and compliant code
- **Explicit Documentation**: Document what was checked, what standards
  were applied, and what violations were found
- **Standards Compliance**: Validate against local `.md` standards from
  `agent-rules/rules/angular/` (testing.md, component-architecture.md,
  lifecycle-di-patterns.md, state-management.md, performance.md, typescript.md)
- **Granular Analysis**: Focus on individual components, services,
  directives, pipes, and test files rather than project infrastructure
- **No Assumptions**: If something cannot be proven by code evidence,
  write "Unknown" and specify what would prove it

**Critical Rules**:
- **ALWAYS validate against the standards** - read from
  `agent-rules/rules/angular/` if present in the repo, otherwise WebFetch
  them from the GitHub raw URL
  (https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/angular/)
- **FOCUS on code quality** - analyze implementation, not infrastructure
- **REPORT violations clearly** - specify which standard is violated
  and provide code examples
- **MAINTAIN format consistency** - follow the template structure for
  Markdown reports
- **NEVER skip standard validation** - all code must be checked
  against applicable standards
- **MODERN ANGULAR ONLY** - this audit targets Angular 2+ (components,
  DI, RxJS). If the codebase is AngularJS 1.x (`$scope`, controllers),
  stop and direct the user to the AngularJS tooling instead.

## Step 1: Testing Quality Analysis
**Goal**: Evaluate conformance to Angular TestBed and Karma/Jasmine (or Jest) standards.
**Rule**: Read and follow the instructions in `references/testing-quality.md`
**Focus Areas**:
- Test naming conventions and describe block structure
- TestBed configuration and component/service isolation
- `HttpClientTestingModule` for HTTP mocking and `HttpTestingController`
- Assertion quality and async handling (`fakeAsync`/`tick`, `waitForAsync`)
- Arrange-Act-Assert structure and `DebugElement`/harness queries

## Step 2: Component Architecture Analysis
**Goal**: Evaluate conformance to feature-module/standalone structure and smart/dumb composition patterns.
**Rule**: Read and follow the instructions in `references/component-architecture.md`
**Focus Areas**:
- Feature-module vs standalone-component organization
- Component/template/style file size and single responsibility
- Barrel (`index.ts` / public-api) export patterns
- Smart (container) vs dumb (presentational) separation
- `@Input()`/`@Output()` boundaries and selector naming conventions

## Step 3: Lifecycle & DI Patterns Analysis
**Goal**: Evaluate conformance to Angular lifecycle hooks and dependency-injection conventions.
**Rule**: Read and follow the instructions in `references/hooks-patterns.md`
**Focus Areas**:
- Correct lifecycle hook usage (`ngOnInit`, `ngOnChanges`, `ngOnDestroy`, etc.)
- `implements` on lifecycle interfaces (`OnInit`, `OnDestroy`)
- Subscription cleanup in `ngOnDestroy` (or `takeUntilDestroyed`)
- Dependency injection via constructor / `inject()` and provider scope
- Avoiding heavy work in constructors and per-`ngDoCheck` logic

## Step 4: Services & State Management Analysis
**Goal**: Evaluate correct usage of services, RxJS/observables, signals, and state libraries.
**Rule**: Read and follow the instructions in `references/state-management.md`
**Focus Areas**:
- State scope decisions (component state → service with `BehaviorSubject`/signals → NgRx/NGXS)
- `HttpClient` centralization in services and HTTP interceptors
- RxJS discipline: `async` pipe, subscription hygiene, operator correctness
- Signals vs observables usage and reactive state exposure
- Avoiding manual subscribe/state duplication and nested subscriptions

## Step 5: Change Detection & Performance Analysis
**Goal**: Evaluate change-detection strategy, template optimization, and bundle discipline.
**Rule**: Read and follow the instructions in `references/performance.md`
**Focus Areas**:
- `ChangeDetectionStrategy.OnPush` adoption and immutable inputs
- `trackBy` on `*ngFor` (or `@for` track) for list rendering
- Lazy-loaded routes and `angular.json` bundle budgets
- Pure pipes vs method calls in templates
- Anti-patterns: function calls in bindings, un-memoized template work, `async` pipe overuse in loops

## Step 6: TypeScript Standards Analysis
**Goal**: Evaluate TypeScript strictness and Angular-specific type/template patterns.
**Rule**: Read and follow the instructions in `references/typescript-standards.md`
**Focus Areas**:
- Strict TypeScript configuration (`strict: true`)
- Angular `strictTemplates` / full template type-checking
- `@angular-eslint` configuration and rule adherence
- No usage of `any`; typed `@Input()`/`@Output()` and HTTP responses
- Typed reactive forms and Angular utility types

## Step 7: Report Generation
**Goal**: Aggregate all findings into a final Markdown report using
the template.
**Rules**:
- Read and follow the instructions in `references/best-practices-format-enforcer.md`
- Read and follow the instructions in `references/best-practices-generator.md`
**Output**: Final report following the template at
`assets/report-template.md`

**Rule Execution Order**:
1.  `references/testing-quality.md` {model: mid}
2.  `references/component-architecture.md` {model: mid}
3.  `references/hooks-patterns.md` {model: mid}
4.  `references/state-management.md` {model: mid}
5.  `references/performance.md` {model: mid}
6.  `references/typescript-standards.md` {model: cheap}
7.  `references/best-practices-generator.md` {model: frontier}

## Subagent Dispatch (in-session)

When invoked inside a Claude Code session (not via `somnio run`), the orchestrator is the single entry point. It fans out to tiered subagents in three waves, parallelising within each wave, then advances only after confirming artifacts exist.

**Entry point**: `agents/orchestrator.md` (`model: mid`)

### Wave Plan

| Wave | Agent file | Tier | Reference / steps covered | Artifact |
|------|-----------|------|--------------------------|---------|
| 1 | `agents/typescript-scanner.md` | cheap | `references/typescript-standards.md` (scan portion) | `reports/.artifacts/angular-best-practices/step_01_typescript_scan.md` |
| 1 | `agents/architecture-scanner.md` | cheap | `references/component-architecture.md` (enumeration) | `reports/.artifacts/angular-best-practices/step_02_architecture_scan.md` |
| 2 | `agents/testing-analyzer.md` | mid | `references/testing-quality.md` | `reports/.artifacts/angular-best-practices/step_03_testing_quality.md` |
| 2 | `agents/architecture-analyzer.md` | mid | `references/component-architecture.md` (consumes step_02) | `reports/.artifacts/angular-best-practices/step_04_architecture_analysis.md` |
| 2 | `agents/hooks-analyzer.md` | mid | `references/hooks-patterns.md` | `reports/.artifacts/angular-best-practices/step_05_hooks_analysis.md` |
| 2 | `agents/state-analyzer.md` | mid | `references/state-management.md` | `reports/.artifacts/angular-best-practices/step_06_state_analysis.md` |
| 2 | `agents/performance-analyzer.md` | mid | `references/performance.md` | `reports/.artifacts/angular-best-practices/step_07_performance_analysis.md` |
| 3 | `agents/report-writer.md` | frontier | `references/best-practices-format-enforcer.md` + `references/best-practices-generator.md` + all step artifacts | `reports/angular-best-practices-report.md` |

**Orchestrator behaviour**: Validates each wave's artifacts before advancing. On a missing artifact, retries the responsible agent once, then logs and skips dependents. Hands the artifact manifest to the report-writer. Never reads source or writes prose.

## Standards References

All standards are sourced from:
`agent-rules/rules/angular/` (somnio-ai-tools repo locally, or GitHub raw if installed standalone)

| Standard File | Purpose |
|---------------|---------|
| `testing.md` | TestBed, AAA patterns, HttpClientTestingModule, async testing |
| `component-architecture.md` | Feature modules/standalone, barrel exports, smart/dumb composition |
| `lifecycle-di-patterns.md` | Lifecycle hooks, subscription cleanup, dependency injection |
| `state-management.md` | Services/RxJS/signals/NgRx decisions, HttpClient, interceptors |
| `performance.md` | OnPush, trackBy, lazy routes, bundle budgets, pure pipes |
| `typescript.md` | Strict config, strictTemplates, typed inputs, no `any` |

## Report Metadata (MANDATORY)

Every generated report MUST include a metadata block at the very end. This is non-negotiable — never omit it.

To resolve the source and version:
1. Look for `.claude-plugin/plugin.json` by traversing up from this skill's directory
2. If found, read `name` and `version` from that file (plugin context)
3. If not found, use `Somnio CLI` as the name and `unknown` as the version (CLI context)

Include this block at the very end of the report:

```
---
Generated by: [plugin name or "Somnio CLI"] v[version]
Skill: angular-best-practices
Date: [YYYY-MM-DD]
Somnio AI Tools: https://github.com/somnio-software/somnio-ai-tools
---
```
