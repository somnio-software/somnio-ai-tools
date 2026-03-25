---
name: flutter-health-audit
description: >-
  Execute a comprehensive Flutter Project Health Audit. Analyzes tech stack,
  architecture, state management, testing, code quality, CI/CD, and
  documentation. Produces a Google Docs-ready report with section scores and
  weighted overall score. Use when the user asks to audit a Flutter project,
  run a health check, evaluate project quality, or assess technical debt.
  Triggers on: 'flutter audit', 'health audit', 'project audit', 'flutter
  health', 'tech debt assessment', 'project quality check'.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent
---

# Flutter Project Health Audit - Modular Execution Plan

This plan executes the Flutter Project Health Audit through sequential,
modular rules. Each step uses a specific rule that can be executed
independently and produces output that feeds into the final report.

## Agent Role & Context

**Role**: Flutter Project Health Auditor

## Your Core Expertise

You are a master at:
- **Comprehensive Project Auditing**: Evaluating all aspects of Flutter
  project health (tech stack, architecture, testing, CI/CD,
  documentation)
- **Evidence-Based Analysis**: Analyzing repository evidence objectively
  without inventing data or making assumptions
- **Modular Rule Execution**: Coordinating sequential execution of 11
  specialized analysis rules
- **Score Calculation**: Calculating section scores (0-100) and weighted
  overall scores accurately
- **Technical Risk Assessment**: Identifying technical risks, technical debt,
  and project maturity indicators
- **Report Integration**: Synthesizing findings from multiple analysis rules
  into unified Google Docs-ready reports

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
- **User Interaction**: Only interact with user when explicitly required
  (Step 8 - Best Practices Check prompt)
- **Error Handling**: Stop execution on MANDATORY step failures;
  continue with warnings for non-critical issues
- **No Assumptions**: If something cannot be proven by repository
  evidence, write "Unknown" and specify what would prove it

**Critical Rules**:
- **NEVER execute `/somnio:flutter-best-practices` automatically** - always wait
  for explicit user confirmation
- **NEVER recommend CODEOWNERS or SECURITY.md files** - these are
  governance decisions, not technical requirements
- **NEVER recommend operational documentation** (runbooks, deployment
  procedures, monitoring) - focus on technical setup only
- **ALWAYS use FVM for Flutter version management** - global
  configuration is MANDATORY
- **ALWAYS execute comprehensive dependency management** - root, packages,
  and apps must have dependencies installed

## REQUIREMENT - FLUTTER VERSION ALIGNMENT

**MANDATORY STEP 0**: Before executing any Flutter project analysis,
ALWAYS verify and align the global Flutter version with the project's
required version using FVM.

**Rule to Execute**: Read and follow the instructions in `references/version-alignment.md`

**CRITICAL REQUIREMENT**: This step MUST configure FVM global version to
match project requirements. This is non-negotiable and must be executed
successfully before any analysis can proceed.

This requirement applies to ANY Flutter project regardless of versions
found and ensures accurate analysis by preventing version-related build
failures.

## Step 0. Flutter Environment Setup and Test Coverage Verification

Goal: Configure Flutter environment with MANDATORY FVM global
configuration and execute comprehensive dependency management with tests
and coverage verification.

**CRITICAL**: This step MUST configure FVM global version and install ALL
dependencies (root, packages, apps). Execution stops if FVM global
configuration fails.

**Rules to Execute**:
1. Read and follow the instructions in `references/tool-installer.md` (MANDATORY: Installs Node.js, FVM)
2. Read and follow the instructions in `references/version-alignment.md` (MANDATORY - stops if fails)
3. Read and follow the instructions in `references/version-validator.md`
4. Read and follow the instructions in `references/test-coverage.md` (coverage generation)

**Execution Order**:
1. Execute `references/tool-installer.md` rule first (MANDATORY - stops if fails)
2. Execute `references/version-alignment.md` rule (MANDATORY - stops if fails)
3. Execute `references/version-validator.md` rule to verify FVM global setup
   and comprehensive dependency management
4. Execute `references/test-coverage.md` rule to generate coverage

**Comprehensive Dependency Management**:
- Root project: `fvm flutter pub get`
- All packages: `find packages/ -name "pubspec.yaml" -execdir fvm flutter
  pub get \;`
- All apps: `find apps/ -name "pubspec.yaml" -execdir fvm flutter pub get \;`
- Verification: `fvm flutter pub deps`
- Build artifacts generation (only where build_runner is declared):
  - Root: `fvm dart run build_runner build --delete-conflicting-outputs`
  - Packages: `find packages/ -name "pubspec.yaml" -execdir sh -c 'if
    grep -q "build_runner" pubspec.yaml 2>/dev/null; then fvm dart run
    build_runner build --delete-conflicting-outputs; fi' \;`
  - Apps: `find apps/ -name "pubspec.yaml" -execdir sh -c 'if grep -q
    "build_runner" pubspec.yaml 2>/dev/null; then fvm dart run
    build_runner build --delete-conflicting-outputs; fi' \;`

**Integration**: Save all outputs from these rules for integration into
the final audit report.

**Failure Handling**: If FVM global configuration fails, STOP execution
and provide resolution steps.

## Step 1. Repository Inventory

Goal: Detect repository structure, platform folders, monorepo packages,
and feature organization.

**Rule to Execute**: Read and follow the instructions in `references/repository-inventory.md`

**Integration**: Save repository structure findings for Architecture and
Tech Stack sections.

## Step 2. Core Configuration Files and Internationalization

Goal: Read and analyze Flutter/Dart configuration files for version
info, dependencies, linter setup, and internationalization
configuration.

**Rule to Execute**: Read and follow the instructions in `references/config-analysis.md`

**Integration**: Save configuration findings for Tech Stack and Code
Quality sections.

## Step 3. CI/CD Workflows Analysis

Goal: Read all GitHub Actions workflows and related CI/CD configuration files.

**Rule to Execute**: Read and follow the instructions in `references/cicd-analysis.md`

**Integration**: Save CI/CD findings for CI/CD section scoring.

## Step 4. Testing Infrastructure

Goal: Find and classify all test files, identify coverage
configuration and test types.

**Rule to Execute**: Read and follow the instructions in `references/testing-analysis.md`

**Integration**: Save testing findings for Testing section, integrate
with coverage results from Step 0.

## Step 5. Code Quality and Linter

Goal: Analyze linter configuration, exclusions, and code quality enforcement.

**Rule to Execute**: Read and follow the instructions in `references/code-quality.md`

**Integration**: Save code quality findings for Code Quality section scoring.

## Step 6. Documentation and Operations

Goal: Review technical documentation, build instructions, and
environment setup (no operational/runbook content).

**Rule to Execute**: Read and follow the instructions in `references/documentation-analysis.md`

**Integration**: Save documentation findings for Documentation &
Operations section scoring.

## Step 7. Generate Final Report

Goal: Generate the final Flutter Project Health Audit report by
integrating all analysis results.

**Rule to Execute**: Read and follow the instructions in `references/report-generator.md`

**Integration**: This rule integrates all previous analysis results and
generates the final report.

**Report Sections**:
- Executive Summary with overall score
- At-a-Glance Scorecard with all 8 section scores
- All 8 detailed sections (Tech Stack, Architecture, State Management,
  Repositories & Data Layer, Testing, Code Quality,
  Documentation & Operations, CI/CD)
- Additional Metrics (including coverage percentages)
- Quality Index
- Risks & Opportunities (5-8 bullets)
- Recommendations (6-10 prioritized actions)
- Appendix: Evidence Index

## Step 8. Export Final Report

Goal: Save the final Google Docs-ready plain-text report to the reports
directory.

**Action**: Create the reports directory if it doesn't exist and save
the final Flutter Project Health Audit report to:
`./reports/flutter_audit.txt`

**Format**: Plain text ready to copy into Google Docs (no markdown
syntax, no # headings, no bold markers, no fenced code blocks).

**Command**:
```bash
mkdir -p reports
# Save report content to ./reports/flutter_audit.txt
```

## Step 9. Optional Best Practices Check Prompt

**CRITICAL**: After completing Step 8, you MUST ask the user if they
want to execute the Best Practices Check plan. **NEVER execute it
automatically**.

**Action**: Prompt the user with the following question:

```
Flutter Project Health Audit completed successfully!

Would you like to execute the Best Practices Check for micro-level
code quality analysis?
This will analyze code quality, testing standards, and architecture compliance.

Plan: /somnio:flutter-best-practices

Type 'yes' or 'y' to proceed, or 'no' or 'n' to skip.
```

**Rules**:
- **NEVER execute `/somnio:flutter-best-practices` automatically**
- **ALWAYS wait for explicit user confirmation**
- If user confirms, execute `/somnio:flutter-best-practices`
- If user declines or doesn't respond, end execution here

**Best Practices Plan Details** (only if user confirms):
- Plan: `/somnio:flutter-best-practices`
- Steps:
  1. `references/testing-quality.md` (from `/somnio:flutter-best-practices`)
  2. `references/architecture-compliance.md` (from `/somnio:flutter-best-practices`)
  3. `references/code-standards.md` (from `/somnio:flutter-best-practices`)
  4. `references/best-practices-format-enforcer.md` (from `/somnio:flutter-best-practices`)
  5. `references/best-practices-generator.md` (from `/somnio:flutter-best-practices`)

**Benefits of Combined Execution** (informational only):
- **Macro-level analysis** (Health Audit): Project infrastructure,
  CI/CD, documentation
- **Micro-level analysis** (Best Practices): Code quality, testing
  standards, architecture compliance
- **Comprehensive coverage**: Both infrastructure and code
  implementation quality
- **Separate reports**: Each plan generates its own report for focused analysis

**Report Outputs**:
- Health Audit: `./reports/flutter_audit.txt`
- Best Practices: Generated by `references/best-practices-generator.md` (from `/somnio:flutter-best-practices`) (see
  plan for output location)

**Note**: For security analysis, run the standalone Security Audit (`/somnio:security-audit`).

## Execution Summary

**Total Rules**: 11 rules

**Rule Execution Order**:
1. Read and follow the instructions in `references/tool-installer.md`
2. Read and follow the instructions in `references/version-alignment.md` (MANDATORY - stops if FVM global
   fails)
3. Read and follow the instructions in `references/version-validator.md` (verification of FVM global setup)
4. Read and follow the instructions in `references/test-coverage.md` (coverage generation)
5. Read and follow the instructions in `references/repository-inventory.md`
6. Read and follow the instructions in `references/config-analysis.md`
7. Read and follow the instructions in `references/cicd-analysis.md`
8. Read and follow the instructions in `references/testing-analysis.md`
9. Read and follow the instructions in `references/code-quality.md`
10. Read and follow the instructions in `references/documentation-analysis.md`
11. Read and follow the instructions in `references/report-generator.md`

**Benefits of Modular Approach**:
- Each rule can be executed independently
- Outputs can be saved and reused
- Easier debugging and maintenance
- Parallel execution possible for some rules
- Clear separation of concerns
- Comprehensive dependency management for monorepos
- Complete FVM global configuration enforcement
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
Skill: flutter-health-audit
Date: [YYYY-MM-DD]
Somnio AI Tools: https://github.com/somnio-software/somnio-ai-tools
---
```
