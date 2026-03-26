---
name: nestjs-health-audit
description: >-
  Execute a comprehensive NestJS Project Health Audit. Analyzes tech stack,
  architecture, API design, data layer, testing, code quality, CI/CD, and
  documentation. Produces a Google Docs-ready report with section scores and
  weighted overall score. Use when the user asks to audit a NestJS project,
  run a health check, evaluate backend quality, or assess technical debt.
  Triggers on: 'nestjs audit', 'health audit', 'backend audit', 'nestjs
  health', 'node audit', 'api audit', 'project quality check'.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent
---

# NestJS Project Health Audit - Modular Execution Plan

This plan executes the NestJS Project Health Audit through sequential,
modular rules. Each step uses a specific rule that can be executed
independently and produces output that feeds into the final report.

## Agent Role & Context

**Role**: NestJS Project Health Auditor

## Your Core Expertise

You are a master at:
- **Comprehensive Project Auditing**: Evaluating all aspects of NestJS
  project health (tech stack, architecture, API design, testing,
  CI/CD, documentation)
- **Evidence-Based Analysis**: Analyzing repository evidence objectively
  without inventing data or making assumptions
- **Modular Rule Execution**: Coordinating sequential execution of 13
  specialized analysis rules
- **Score Calculation**: Calculating section scores (0-100) and weighted
  overall scores accurately
- **Technical Risk Assessment**: Identifying technical risks, technical debt,
  and project maturity indicators
- **Report Integration**: Synthesizing findings from multiple analysis rules
  into unified Google Docs-ready reports
- **NestJS Best Practices**: Deep knowledge of NestJS patterns, decorators,
  modules, providers, guards, interceptors, and pipes
- **Backend Architecture**: Understanding of layered architecture, DDD,
  hexagonal architecture, and microservices patterns

**Responsibilities**:
- Execute technical audits following the plan steps sequentially
- Report findings objectively based on evidence found in the repository
- Stop execution immediately if MANDATORY steps fail
- Never invent or assume information - report "Unknown" if evidence is missing
- Focus exclusively on technical aspects, exclude
  operational/governance recommendations

**Expected Behavior**:
- **Professional and Evidence-Based**: All findings must be supported
  by actual repository evidence
- **Objective Reporting**: Distinguish clearly between critical issues,
  recommendations, and neutral items
- **Explicit Documentation**: Document what was checked, what was found,
  and what is missing
- **Error Handling**: Stop execution on MANDATORY step failures;
  continue with warnings for non-critical issues
- **No Assumptions**: If something cannot be proven by repository
  evidence, write "Unknown" and specify what would prove it

**Critical Rules**:
- **NEVER recommend CODEOWNERS or SECURITY.md files** - these are
  governance decisions, not technical requirements
- **NEVER recommend operational documentation** (runbooks, deployment
  procedures, monitoring) - focus on technical setup only
- **ALWAYS use nvm for Node.js version management** - global
  configuration is MANDATORY
- **ALWAYS execute comprehensive dependency management** - root, packages,
  and apps must have dependencies installed

**Execution Discipline (NON-NEGOTIABLE)**:
- **NEVER skip, combine, or abbreviate any step** — each step in this plan
  MUST be executed individually and completely
- **NEVER summarize a reference file instead of executing it** — you MUST
  read each reference file AND follow its instructions fully
- **NEVER take shortcuts** — even if you believe you already know the answer,
  you MUST execute the analysis commands and collect real evidence
- **ALWAYS read the reference file first** — before executing any step, read
  the referenced .md file completely, then follow its instructions
- **ALWAYS log step completion** — after completing each step, output:
  "STEP N COMPLETED: [brief result summary]" before proceeding to the next
- **NEVER proceed to the next step without completing the current one** —
  partial execution of a step is not acceptable
- **If a step fails**: document the failure, attempt recovery, and only skip
  if recovery is impossible (with explicit documentation of what was skipped
  and why)

## REQUIREMENT - NODE.JS VERSION ALIGNMENT

**MANDATORY STEP 0**: Before executing any NestJS project analysis,
ALWAYS verify and align the Node.js version with the project's
required version using nvm.

**Rule to Execute**: Read and follow the instructions in `references/version-alignment.md`

**CRITICAL REQUIREMENT**: This step MUST configure nvm to use the project's
Node.js version. This is non-negotiable and must be executed
successfully before any analysis can proceed.

This requirement applies to ANY NestJS project regardless of versions
found and ensures accurate analysis by preventing version-related build
failures.

## Step 0. Node.js Environment Setup and Test Coverage Verification

Goal: Configure Node.js environment with MANDATORY nvm configuration
and execute comprehensive dependency management with tests and coverage
verification.

**CRITICAL**: This step MUST configure nvm to use project's Node.js
version and install ALL dependencies (root, packages, apps). Execution
stops if nvm configuration fails.

**Rules to Execute**:
1. Read and follow the instructions in `references/tool-installer.md` (MANDATORY: Installs Node.js, nvm, required
   CLI tools)
2. Read and follow the instructions in `references/version-alignment.md` (MANDATORY - stops if fails)
3. Read and follow the instructions in `references/version-validator.md`
4. Read and follow the instructions in `references/test-coverage.md` (coverage generation)

**Execution Order**:
1. Execute `references/tool-installer.md` rule first (MANDATORY - stops if fails)
2. Execute `references/version-alignment.md` rule (MANDATORY - stops if fails)
3. Execute `references/version-validator.md` rule to verify nvm setup and
   comprehensive dependency management
4. Execute `references/test-coverage.md` rule to generate coverage

**Comprehensive Dependency Management**:
- Root project: `npm install` or `yarn install` or `pnpm install`
- All packages: `find packages/ -name "package.json" -execdir npm
  install \;`
- All apps: `find apps/ -name "package.json" -execdir npm install \;`
- Verification: `npm list` or `yarn list` or `pnpm list`
- Build artifacts generation (if build step exists):
  - Root: `npm run build` or `yarn build` or `pnpm build`
  - Apps: `find apps/ -name "package.json" -execdir npm run build \;`

**Integration**: Save all outputs from these rules for integration into
the final audit report.

**Failure Handling**: If nvm configuration fails, STOP execution and
provide resolution steps.

## Parallel Execution Strategy

Steps 1-8 can be partially parallelized using the Agent tool to launch
multiple analysis agents simultaneously. Use the following wave structure:

**Wave 0 (Sequential - MANDATORY)**: Step 0 — Environment Setup
  Must complete fully before any analysis begins.

**Wave 1 (Parallel)**: Steps 1 + 2 — Repository Inventory + Configuration Analysis
  Launch both as parallel agents. Both read from the filesystem independently.

**Wave 2 (Parallel)**: Steps 3 + 4 + 5 — CI/CD + Testing + Code Quality
  Launch all three as parallel agents. Independent read-only analyses.

**Wave 3 (Parallel)**: Steps 6 + 7 — API Design + Data Layer
  Launch both as parallel agents. Independent framework-specific analyses.

**Wave 4 (Sequential)**: Step 8 — Documentation Analysis
  Can run after all analysis waves complete.

**Wave 5 (Sequential)**: Steps 9 + 10 — Report Generation + Export
  Must run last — requires ALL previous results.

**Agent Launch Pattern**: For each parallel wave, use the Agent tool to
spawn one agent per step. Each agent MUST:
1. Read the referenced .md file completely
2. Execute ALL instructions in that file
3. Return the complete analysis results
4. Never abbreviate or summarize — return full evidence

Example for Wave 1:
- Agent 1: "Read references/repository-inventory.md and execute ALL instructions. Return complete findings."
- Agent 2: "Read references/config-analysis.md and execute ALL instructions. Return complete findings."

## Step 1. Repository Inventory

Goal: Detect repository structure, monorepo packages, module organization,
and feature structure.

**Rule to Execute**: Read and follow the instructions in `references/repository-inventory.md`

**Integration**: Save repository structure findings for Architecture and
Tech Stack sections.

## Step 2. Core Configuration Files

Goal: Read and analyze NestJS/Node.js configuration files for version
info, dependencies, TypeScript setup, and environment configuration.

**Rule to Execute**: Read and follow the instructions in `references/config-analysis.md`

**Integration**: Save configuration findings for Tech Stack and Code
Quality sections.

## Step 3. CI/CD Workflows Analysis

Goal: Read all GitHub Actions workflows and related CI/CD configuration
files including Docker setup.

**Rule to Execute**: Read and follow the instructions in `references/cicd-analysis.md`

**Integration**: Save CI/CD findings for CI/CD section scoring.

## Step 4. Testing Infrastructure

Goal: Find and classify all test files, identify coverage configuration
and test types (unit, integration, e2e).

**Rule to Execute**: Read and follow the instructions in `references/testing-analysis.md`

**Integration**: Save testing findings for Testing section, integrate
with coverage results from Step 0.

## Step 5. Code Quality and Linter

Goal: Analyze ESLint configuration, Prettier setup, TypeScript strict
mode, and code quality enforcement.

**Rule to Execute**: Read and follow the instructions in `references/code-quality.md`

**Integration**: Save code quality findings for Code Quality section
scoring.

## Step 6. API Design Analysis

Goal: Analyze REST/GraphQL API design, DTOs, validation patterns,
OpenAPI/Swagger documentation, and API versioning.

**Rule to Execute**: Read and follow the instructions in `references/api-design-analysis.md`

**Integration**: Save API design findings for API Design section scoring.

## Step 7. Data Layer Analysis

Goal: Analyze ORM/database integration, repository patterns, migrations,
and data access layer organization.

**Rule to Execute**: Read and follow the instructions in `references/data-layer-analysis.md`

**Integration**: Save data layer findings for Data Layer section scoring.

## Step 8. Documentation and Operations

Goal: Review technical documentation, API documentation, build
instructions, and environment setup.

**Rule to Execute**: Read and follow the instructions in `references/documentation-analysis.md`

**Integration**: Save documentation findings for Documentation &
Operations section scoring.

## Step 9. Generate Final Report

Goal: Generate the final NestJS Project Health Audit report by
integrating all analysis results.

**Rule to Execute**: Read and follow the instructions in `references/report-generator.md`

**Integration**: This rule integrates all previous analysis results and
generates the final report.

**Report Sections**:
- Executive Summary with overall score
- At-a-Glance Scorecard with all 8 section scores
- All 8 detailed sections (Tech Stack, Architecture, API Design,
  Data Layer, Testing, Code Quality, Documentation &
  Operations, CI/CD)
- Additional Metrics (including coverage percentages)
- Quality Index
- Risks & Opportunities (5-8 bullets)
- Recommendations (6-10 prioritized actions)
- Appendix: Evidence Index

## Step 10. Export Final Report

Goal: Save the final Google Docs-ready plain-text report to the reports
directory.

**Action**: Create the reports directory if it doesn't exist and save
the final NestJS Project Health Audit report to:
`./reports/nestjs_audit.txt`

**Format**: Plain text ready to copy into Google Docs (no markdown
syntax, no # headings, no bold markers, no fenced code blocks).

**Command**:
```bash
mkdir -p reports
# Save report content to ./reports/nestjs_audit.txt
```

**Note**: For security analysis, run the standalone Security Audit (`/somnio:security-audit`).

## Execution Summary

**Total Rules**: 13 rules

**Rule Execution Order**:
1. `references/tool-installer.md`
2. `references/version-alignment.md` (MANDATORY - stops if nvm fails)
3. `references/version-validator.md` (verification of nvm setup)
4. `references/test-coverage.md` (coverage generation)
5. `references/repository-inventory.md`
6. `references/config-analysis.md`
7. `references/cicd-analysis.md`
8. `references/testing-analysis.md`
9. `references/code-quality.md`
10. `references/api-design-analysis.md`
11. `references/data-layer-analysis.md`
12. `references/documentation-analysis.md`
13. `references/report-generator.md`

**Wave-Based Parallel Execution**:
- Wave 0 (Sequential): Step 0 — Environment Setup (rules 1-4)
- Wave 1 (Parallel): Steps 1 + 2 — Repository Inventory + Configuration (rules 5-6)
- Wave 2 (Parallel): Steps 3 + 4 + 5 — CI/CD + Testing + Code Quality (rules 7-9)
- Wave 3 (Parallel): Steps 6 + 7 — API Design + Data Layer (rules 10-11)
- Wave 4 (Sequential): Step 8 — Documentation (rule 12)
- Wave 5 (Sequential): Steps 9 + 10 — Report Generation + Export (rule 13)

**Benefits of Modular Approach**:
- Each rule can be executed independently
- Outputs can be saved and reused
- Easier debugging and maintenance
- Wave-based parallelization accelerates analysis using the Agent tool
- Clear separation of concerns
- Strict no-shortcuts enforcement ensures complete, evidence-based analysis
- Comprehensive dependency management for monorepos
- Complete nvm configuration enforcement
- Full project environment setup with all dependencies

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
Skill: nestjs-health-audit
Date: [YYYY-MM-DD]
Somnio AI Tools: https://github.com/somnio-software/somnio-ai-tools
---
```
