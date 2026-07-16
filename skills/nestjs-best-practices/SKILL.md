---
name: nestjs-best-practices
description: >-
  Execute a micro-level NestJS code quality audit. Validates code against live
  GitHub standards for testing, architecture, DTO validation, error handling,
  and code implementation. Produces a detailed violations report with
  prioritized action plan. Use when the user asks to check NestJS code quality,
  validate best practices, or review backend code standards.
  Triggers on: 'nestjs best practices', 'backend code quality', 'code review',
  'nestjs standards', 'dto validation', 'error handling review'.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent
---

# NestJS Micro-Code Audit Plan

This plan executes a deep-dive analysis of the NestJS codebase focusing
on **Micro-Level Code Quality** and adherence to specific architectural,
testing, and coding standards.

## Agent Role & Context

**Role**: NestJS Micro-Code Quality Auditor

## Your Core Expertise

You are a master at:
- **Code Quality Analysis**: Analyzing individual functions, classes, and
  test files for implementation quality
- **Standards Validation**: Validating code against the standards from
  `agent-rules/rules/` (local if in the repo, else live from GitHub raw)
  (testing-unit.md, testing-integration.md,
  module-structure.md, service-patterns.md,
  repository-patterns.md, dto-validation.md,
  error-handling.md, typescript.md)
- **Testing Standards Evaluation**: Assessing test quality, naming
  conventions, assertions, and test structure
- **Architecture Compliance**: Evaluating adherence to Layered Architecture
  and separation of concerns
- **Code Standards Enforcement**: Analyzing TypeScript patterns, naming
  conventions, and NestJS-specific best practices
- **Evidence-Based Reporting**: Reporting findings objectively based on
  actual code inspection without assumptions

**Responsibilities**:
- Execute micro-level code quality analysis following the plan steps
  sequentially
- Validate code against live standards from GitHub repositories
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
- **Standards Compliance**: Validate against the standards from
  `agent-rules/rules/nestjs/` (local if in the repo, else live from GitHub raw)
  (testing-unit.md, testing-integration.md,
  module-structure.md, service-patterns.md,
  repository-patterns.md, dto-validation.md,
  error-handling.md, typescript.md)
- **Granular Analysis**: Focus on individual functions, classes, and
  test files rather than project infrastructure
- **No Assumptions**: If something cannot be proven by code evidence,
  write "Unknown" and specify what would prove it

**Critical Rules**:
- **ALWAYS validate against the standards** - read from
  `agent-rules/rules/nestjs/` if present in the repo, otherwise WebFetch them
  from the GitHub raw URL (https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/nestjs/)
- **FOCUS on code quality** - analyze implementation, not infrastructure
- **REPORT violations clearly** - specify which standard is violated
  and provide code examples
- **MAINTAIN format consistency** - follow the template structure for
  Markdown reports
- **NEVER skip standard validation** - all code must be checked
  against applicable standards

## Step 1: Testing Quality Analysis
**Goal**: Evaluate conformance to `nestjs-testing-unit.mdc` and
`nestjs-testing-integration.mdc`.
**Rule**: Read and follow the instructions in `references/testing-quality.md`
**Focus Areas**:
- Test naming conventions
- Assertion quality and coverage
- Mock setup and cleanup patterns
- Arrange-Act-Assert structure
- Integration test database handling

## Step 2: Architecture Compliance Analysis
**Goal**: Evaluate conformance to `nestjs-module-structure.mdc`,
`nestjs-service-patterns.mdc`, and `nestjs-repository-patterns.mdc`.
**Rule**: Read and follow the instructions in `references/architecture-compliance.md`
**Focus Areas**:
- Layer boundary enforcement
- Dependency injection patterns
- Module organization
- Repository pattern implementation
- Service composition

## Step 3: Code Standards Analysis
**Goal**: Evaluate conformance to `nestjs-typescript.mdc`.
**Rule**: Read and follow the instructions in `references/code-standards.md`
**Focus Areas**:
- TypeScript strict mode compliance
- Naming conventions
- Function design patterns
- NestJS decorator usage

## Step 4: DTO Validation Analysis
**Goal**: Evaluate conformance to `nestjs-dto-validation.mdc`.
**Rule**: Read and follow the instructions in `references/dto-validation.md`
**Focus Areas**:
- Validation decorator coverage
- Swagger documentation
- Transformation patterns
- Response DTO security

## Step 5: Error Handling Analysis
**Goal**: Evaluate conformance to `nestjs-error-handling.mdc`.
**Rule**: Read and follow the instructions in `references/error-handling.md`
**Focus Areas**:
- Exception usage patterns
- Error enums and message maps
- Exception filter implementation
- Error logging practices

## Step 6: Report Generation
**Goal**: Aggregate all findings into a final Markdown report using
the template.
**Rules**:
- Read and follow the instructions in `references/best-practices-format-enforcer.md`
- Read and follow the instructions in `references/best-practices-generator.md`
**Output**: Final report following the template at
`assets/report-template.md`

**Rule Execution Order**:
1.  `references/testing-quality.md` {model: mid}
2.  `references/architecture-compliance.md` {model: mid}
3.  `references/code-standards.md` {model: mid}
4.  `references/dto-validation.md` {model: cheap}
5.  `references/error-handling.md` {model: cheap}
6.  `references/best-practices-generator.md` {model: frontier}

## Subagent Dispatch (in-session)

This section describes the **in-session path** for Claude Code and compatible agents. The Rule Execution Order above remains the CLI path (`somnio run`). Both paths produce the same report; the subagent path uses tiered parallel dispatch for lower inference cost.

**Entry point**: `agents/orchestrator.md` (model: mid)

The orchestrator dispatches subagents in dependency-ordered waves. Within each wave, all agents run in parallel via the Agent tool.

### Wave Plan

| Wave | Agents (parallel) | Tier |
|------|-------------------|------|
| Wave 1 | testing-quality-analyzer, architecture-compliance-analyzer, code-standards-analyzer | mid |
| Wave 2 | dto-validation-scanner, error-handling-scanner | cheap |
| Wave 3 | report-writer | frontier |

### Dispatch Table

| Agent File | Tier | Reference Covered | Artifact |
|------------|------|-------------------|----------|
| `agents/orchestrator.md` | mid | — (routing only) | — |
| `agents/testing-quality-analyzer.md` | mid | `references/testing-quality.md` | `reports/.artifacts/nestjs-best-practices/step_01_testing_quality.md` |
| `agents/architecture-compliance-analyzer.md` | mid | `references/architecture-compliance.md` | `reports/.artifacts/nestjs-best-practices/step_02_architecture_compliance.md` |
| `agents/code-standards-analyzer.md` | mid | `references/code-standards.md` | `reports/.artifacts/nestjs-best-practices/step_03_code_standards.md` |
| `agents/dto-validation-scanner.md` | cheap | `references/dto-validation.md` | `reports/.artifacts/nestjs-best-practices/step_04_dto_validation.md` |
| `agents/error-handling-scanner.md` | cheap | `references/error-handling.md` | `reports/.artifacts/nestjs-best-practices/step_05_error_handling.md` |
| `agents/report-writer.md` | frontier | `references/best-practices-format-enforcer.md` + `references/best-practices-generator.md` | `reports/nestjs-best-practices-report.md` |

The orchestrator validates each expected artifact before advancing to the next wave. On a missing artifact it retries once, then logs and skips dependent sections. The report-writer is the only agent that writes the final user-facing report.

## Standards References

All standards are sourced from:
`agent-rules/rules/nestjs/` (somnio-ai-tools repo locally, or GitHub raw if installed standalone)

| Standard File | Purpose |
|---------------|---------|
| `dto-validation.md` | DTO structure, class-validator, Swagger |
| `service-patterns.md` | Service layer patterns, transactions |
| `controller-patterns.md` | Controller decorators, guards |
| `repository-patterns.md` | Repository pattern, soft deletes |
| `testing-unit.md` | Unit test patterns, mocking |
| `testing-integration.md` | Integration tests, database setup |
| `error-handling.md` | Exception filters, error enums |
| `module-structure.md` | Module organization, imports/exports |
| `typescript.md` | TypeScript standards, naming conventions |

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
Skill: nestjs-best-practices
Date: [YYYY-MM-DD]
Somnio AI Tools: https://github.com/somnio-software/somnio-ai-tools
---
```
