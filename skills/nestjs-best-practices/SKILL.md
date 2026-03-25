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
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch
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
- **Standards Validation**: Validating code against live standards from
  GitHub repositories (nestjs-testing-unit.mdc, nestjs-testing-integration.mdc,
  nestjs-module-structure.mdc, nestjs-service-patterns.mdc,
  nestjs-repository-patterns.mdc, nestjs-dto-validation.mdc,
  nestjs-error-handling.mdc, nestjs-typescript.mdc)
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
- **Standards Compliance**: Validate against live `.mdc` standards from
  GitHub (nestjs-testing-unit.mdc, nestjs-testing-integration.mdc,
  nestjs-module-structure.mdc, nestjs-service-patterns.mdc,
  nestjs-repository-patterns.mdc, nestjs-dto-validation.mdc,
  nestjs-error-handling.mdc, nestjs-typescript.mdc)
- **Granular Analysis**: Focus on individual functions, classes, and
  test files rather than project infrastructure
- **No Assumptions**: If something cannot be proven by code evidence,
  write "Unknown" and specify what would prove it

**Critical Rules**:
- **ALWAYS validate against live standards** - fetch latest standards
  from GitHub repositories
- **FOCUS on code quality** - analyze implementation, not infrastructure
- **REPORT violations clearly** - specify which standard is violated
  and provide code examples
- **MAINTAIN format consistency** - follow the template structure for
  plain-text reports
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
**Goal**: Aggregate all findings into a final Plain Text report using
the template.
**Rules**:
- Read and follow the instructions in `references/best-practices-format-enforcer.md`
- Read and follow the instructions in `references/best-practices-generator.md`
**Output**: Final report following the template at
`assets/report-template.txt`

**Rule Execution Order**:
1.  `references/testing-quality.md`
2.  `references/architecture-compliance.md`
3.  `references/code-standards.md`
4.  `references/dto-validation.md`
5.  `references/error-handling.md`
6.  `references/best-practices-format-enforcer.md`
7.  `references/best-practices-generator.md`

## Standards References

All standards are sourced from:
`https://github.com/somnio-software/cursor-rules/tree/main/.cursor/rules/nestjs/`

| Standard File | Purpose |
|---------------|---------|
| `nestjs-dto-validation.mdc` | DTO structure, class-validator, Swagger |
| `nestjs-service-patterns.mdc` | Service layer patterns, transactions |
| `nestjs-controller-patterns.mdc` | Controller decorators, guards |
| `nestjs-repository-patterns.mdc` | Repository pattern, soft deletes |
| `nestjs-testing-unit.mdc` | Unit test patterns, mocking |
| `nestjs-testing-integration.mdc` | Integration tests, database setup |
| `nestjs-error-handling.mdc` | Exception filters, error enums |
| `nestjs-module-structure.mdc` | Module organization, imports/exports |
| `nestjs-typescript.mdc` | TypeScript standards, naming conventions |

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
