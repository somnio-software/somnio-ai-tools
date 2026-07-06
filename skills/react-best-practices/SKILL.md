---
name: react-best-practices
description: >-
  Execute a micro-level React code quality audit. Validates code against live
  GitHub standards for testing, component architecture, hooks patterns, state
  management, performance, and TypeScript. Produces a detailed violations report
  with prioritized action plan. Use when the user asks to check React code
  quality, validate best practices, or review frontend code standards.
  Triggers on: 'react best practices', 'react code quality', 'component review',
  'hooks review', 'react standards', 'frontend code quality'.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent
---

# React Micro-Code Audit Plan

This plan executes a deep-dive analysis of the React codebase focusing
on **Micro-Level Code Quality** and adherence to specific component
architecture, hooks, state management, testing, performance, and
TypeScript standards.

## Agent Role & Context

**Role**: React Micro-Code Quality Auditor

## Your Core Expertise

You are a master at:
- **Code Quality Analysis**: Analyzing individual components, hooks, and
  test files for implementation quality
- **Standards Validation**: Validating code against the standards from
  `agent-rules/rules/` (local if in the repo, else live from GitHub raw)
  (testing.md, component-architecture.md,
  hooks-patterns.md, state-management.md, performance.md, typescript.md)
- **Testing Standards Evaluation**: Assessing test quality using React
  Testing Library, naming conventions, assertions, and test structure
- **Architecture Compliance**: Evaluating adherence to feature-based
  folder structure and component composition patterns
- **Code Standards Enforcement**: Analyzing TypeScript patterns, naming
  conventions, and React-specific best practices
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
  `agent-rules/rules/react/` (testing.md, component-architecture.md,
  hooks-patterns.md, state-management.md, performance.md, typescript.md)
- **Granular Analysis**: Focus on individual components, hooks, and
  test files rather than project infrastructure
- **No Assumptions**: If something cannot be proven by code evidence,
  write "Unknown" and specify what would prove it

**Critical Rules**:
- **ALWAYS validate against the standards** - read from
  `agent-rules/rules/react/` if present in the repo, otherwise WebFetch
  them from the GitHub raw URL
  (https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/react/)
- **FOCUS on code quality** - analyze implementation, not infrastructure
- **REPORT violations clearly** - specify which standard is violated
  and provide code examples
- **MAINTAIN format consistency** - follow the template structure for
  Markdown reports
- **NEVER skip standard validation** - all code must be checked
  against applicable standards

## Step 1: Testing Quality Analysis
**Goal**: Evaluate conformance to React Testing Library and Jest standards.
**Rule**: Read and follow the instructions in `references/testing-quality.md`
**Focus Areas**:
- Test naming conventions and describe block structure
- RTL query priority and semantic queries
- Assertion quality and async handling
- Arrange-Act-Assert structure
- renderHook usage for custom hooks

## Step 2: Component Architecture Analysis
**Goal**: Evaluate conformance to feature-based structure and composition patterns.
**Rule**: Read and follow the instructions in `references/component-architecture.md`
**Focus Areas**:
- Feature-based folder organization
- Component file size and single responsibility
- Barrel export patterns
- Container/Presenter separation
- Named exports over default exports

## Step 3: Hooks Patterns Analysis
**Goal**: Evaluate conformance to React hooks rules and custom hook conventions.
**Rule**: Read and follow the instructions in `references/hooks-patterns.md`
**Focus Areas**:
- Rules of Hooks compliance
- Custom hook extraction and naming
- useCallback and useMemo stability patterns
- useEffect dependency correctness
- useReducer vs useState decisions

## Step 4: State Management Analysis
**Goal**: Evaluate correct usage of state management tools and patterns.
**Rule**: Read and follow the instructions in `references/state-management.md`
**Focus Areas**:
- State scope decisions (local → Context → TanStack Query → Zustand)
- Context API structure for global UI state
- Zustand slice patterns and selector usage
- TanStack Query for server state
- Avoiding unnecessary global state

## Step 5: Performance Analysis
**Goal**: Evaluate usage of memoization, code splitting, and list optimization.
**Rule**: Read and follow the instructions in `references/performance.md`
**Focus Areas**:
- React.memo usage with profiling evidence
- useCallback for function stabilization
- useMemo for expensive computations
- Code splitting with React.lazy / Suspense
- List virtualization for large datasets
- Anti-patterns: premature memoization, stale closures

## Step 6: TypeScript Standards Analysis
**Goal**: Evaluate TypeScript strictness and React-specific type patterns.
**Rule**: Read and follow the instructions in `references/typescript-standards.md`
**Focus Areas**:
- Strict TypeScript configuration
- Component prop interfaces and extending HTML element props
- No usage of `any`
- Generic components for reusable types
- React utility types (ReactNode, ReactElement, CSSProperties, etc.)

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
7.  `references/best-practices-format-enforcer.md` {model: frontier}
8.  `references/best-practices-generator.md` {model: frontier}

## Subagent Dispatch (in-session)

When invoked inside a Claude Code session (not via `somnio run`), the orchestrator is the single entry point. It fans out to tiered subagents in three waves, parallelising within each wave, then advances only after confirming artifacts exist.

**Entry point**: `agents/orchestrator.md` (`model: mid`)

### Wave Plan

| Wave | Agent file | Tier | Reference / steps covered | Artifact |
|------|-----------|------|--------------------------|---------|
| 1 | `agents/typescript-scanner.md` | cheap | `references/typescript-standards.md` (scan portion) | `reports/.artifacts/react-best-practices/step_01_typescript_scan.md` |
| 1 | `agents/architecture-scanner.md` | cheap | `references/component-architecture.md` (enumeration) | `reports/.artifacts/react-best-practices/step_02_architecture_scan.md` |
| 2 | `agents/testing-analyzer.md` | mid | `references/testing-quality.md` | `reports/.artifacts/react-best-practices/step_03_testing_quality.md` |
| 2 | `agents/architecture-analyzer.md` | mid | `references/component-architecture.md` (consumes step_02) | `reports/.artifacts/react-best-practices/step_04_architecture_analysis.md` |
| 2 | `agents/hooks-analyzer.md` | mid | `references/hooks-patterns.md` | `reports/.artifacts/react-best-practices/step_05_hooks_analysis.md` |
| 2 | `agents/state-analyzer.md` | mid | `references/state-management.md` | `reports/.artifacts/react-best-practices/step_06_state_analysis.md` |
| 2 | `agents/performance-analyzer.md` | mid | `references/performance.md` | `reports/.artifacts/react-best-practices/step_07_performance_analysis.md` |
| 3 | `agents/report-writer.md` | frontier | `references/best-practices-format-enforcer.md` + `references/best-practices-generator.md` + all step artifacts | `reports/react-best-practices-report.md` |

**Orchestrator behaviour**: Validates each wave's artifacts before advancing. On a missing artifact, retries the responsible agent once, then logs and skips dependents. Hands the artifact manifest to the report-writer. Never reads source or writes prose.

## Standards References

All standards are sourced from:
`agent-rules/rules/react/` (somnio-ai-tools repo locally, or GitHub raw if installed standalone)

| Standard File | Purpose |
|---------------|---------|
| `testing.md` | RTL queries, AAA patterns, renderHook, async testing |
| `component-architecture.md` | Feature folders, barrel exports, composition |
| `hooks-patterns.md` | Rules of Hooks, custom hooks, useCallback/useMemo |
| `state-management.md` | useState/Context/Zustand/TanStack Query decisions |
| `performance.md` | React.memo, code splitting, virtualization |
| `typescript.md` | Strict config, prop interfaces, no `any` |

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
Skill: react-best-practices
Date: [YYYY-MM-DD]
Somnio AI Tools: https://github.com/somnio-software/somnio-ai-tools
---
```
