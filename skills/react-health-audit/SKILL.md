---
name: react-health-audit
description: >-
  Execute a comprehensive React Project Health Audit. Analyzes tech stack,
  architecture, state management, testing, code quality, performance, CI/CD,
  and documentation. Produces a Google Docs-ready report with section scores
  and weighted overall score. Use when the user asks to audit a React project,
  run a health check, evaluate frontend quality, or assess technical debt.
  Triggers on: 'react audit', 'health audit', 'react health', 'frontend audit',
  'next.js audit', 'vite audit', 'project quality check'.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent
---

# React Project Health Audit - Modular Execution Plan

This plan executes the React Project Health Audit through sequential,
modular rules. Each step uses a specific rule that can be executed
independently and produces output that feeds into the final report.

## Agent Role & Context

**Role**: React Project Health Auditor

## Your Core Expertise

You are a master at:
- **Comprehensive Project Auditing**: Evaluating all aspects of React
  project health (tech stack, architecture, state management, testing,
  performance, CI/CD, documentation)
- **Evidence-Based Analysis**: Analyzing repository evidence objectively
  without inventing data or making assumptions
- **Modular Rule Execution**: Coordinating sequential execution of 13
  specialized analysis rules
- **Score Calculation**: Calculating section scores (0-100) and weighted
  overall scores accurately
- **Technical Risk Assessment**: Identifying technical risks, technical
  debt, and project maturity indicators
- **Report Integration**: Synthesizing findings from multiple analysis
  rules into unified Google Docs-ready reports
- **React Best Practices**: Deep knowledge of React patterns, hooks,
  component architecture, state management, and performance optimization
- **Frontend Architecture**: Understanding of feature-based structure,
  CSR/SSR/SSG patterns, and bundler configurations

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
- **ALWAYS execute comprehensive dependency management** - root,
  packages, and apps must have dependencies installed

## REQUIREMENT - NODE.JS VERSION ALIGNMENT

**MANDATORY STEP 0**: Before executing any React project analysis,
ALWAYS verify and align the Node.js version with the project's
required version using nvm.

**Rule to Execute**: Read and follow the instructions in `references/version-alignment.md`

**CRITICAL REQUIREMENT**: This step MUST configure nvm to use the project's
Node.js version. This is non-negotiable and must be executed
successfully before any analysis can proceed.

This requirement applies to ANY React project regardless of versions
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

**Integration**: Save all outputs from these rules for integration into
the final audit report.

**Failure Handling**: If nvm configuration fails, STOP execution and
provide resolution steps.

## Step 1. Repository Inventory

Goal: Detect repository structure, framework (CRA/Vite/Next.js/Remix),
monorepo setup, and feature-based folder organization.

**Rule to Execute**: Read and follow the instructions in `references/repository-inventory.md`

**Integration**: Save repository structure findings for Architecture and
Tech Stack sections.

## Step 2. Core Configuration Files

Goal: Read and analyze React/Node.js configuration files for version
info, dependencies, TypeScript setup, ESLint, Prettier, and bundler
configuration.

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

Goal: Analyze ESLint configuration (including react-hooks plugin),
Prettier setup, TypeScript strict mode, and code quality enforcement.

**Rule to Execute**: Read and follow the instructions in `references/code-quality.md`

**Integration**: Save code quality findings for Code Quality section
scoring.

## Step 6. State Management Analysis

Goal: Analyze state management patterns, library choices, and
server/client state separation.

**Rule to Execute**: Read and follow the instructions in `references/state-management-analysis.md`

**Integration**: Save state management findings for State Management
section scoring.

## Step 7. Documentation and Operations

Goal: Review technical documentation, component docs, Storybook
integration, and environment setup.

**Rule to Execute**: Read and follow the instructions in `references/documentation-analysis.md`

**Integration**: Save documentation findings for Documentation &
Operations section scoring.

## Step 8. Generate Final Report

Goal: Generate the final React Project Health Audit report by
integrating all analysis results.

**Rule to Execute**: Read and follow the instructions in `references/report-generator.md`

**Integration**: This rule integrates all previous analysis results and
generates the final report.

**Report Sections**:
- Executive Summary with overall score
- At-a-Glance Scorecard with all 8 section scores
- All 8 detailed sections (Tech Stack, Architecture, State Management,
  Testing, Code Quality, Performance, Documentation &
  Operations, CI/CD)
- Additional Metrics (including coverage percentages)
- Quality Index
- Risks & Opportunities (5-8 bullets)
- Recommendations (6-10 prioritized actions)
- Appendix: Evidence Index

## Step 9. Export Final Report

Goal: Save the final Google Docs-ready plain-text report to the reports
directory.

**Action**: Create the reports directory if it doesn't exist and save
the final React Project Health Audit report to:
`./reports/react_audit.txt`

**Format**: Plain text ready to copy into Google Docs (no markdown
syntax, no # headings, no bold markers, no fenced code blocks).

**Command**:
```bash
mkdir -p reports
# Save report content to ./reports/react_audit.txt
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
10. `references/state-management-analysis.md`
11. `references/documentation-analysis.md`
12. `references/report-format-enforcer.md`
13. `references/report-generator.md`

**Benefits of Modular Approach**:
- Each rule can be executed independently
- Outputs can be saved and reused
- Easier debugging and maintenance
- Parallel execution possible for some rules
- Clear separation of concerns
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
Skill: react-health-audit
Date: [YYYY-MM-DD]
Somnio AI Tools: https://github.com/somnio-software/somnio-ai-tools
---
```
