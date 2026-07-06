---
name: python-health-audit
description: >-
  Execute a comprehensive Python Project Health Audit. Analyzes tech stack,
  architecture, API/interface design, data layer, testing, code quality,
  CI/CD, and documentation. Produces a Google Docs-ready report with section
  scores and weighted overall score. Use when the user asks to audit a Python
  project, run a health check, evaluate backend quality, or assess technical
  debt. Triggers on: 'python audit', 'python health audit', 'fastapi audit',
  'django audit', 'flask audit', 'tech debt assessment', 'python health',
  'python project quality', 'python quality check', 'python code review'.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent, Task
---

# Python Project Health Audit - Modular Execution Plan

This plan executes the Python Project Health Audit through sequential,
modular rules. Each step uses a specific rule that can be executed
independently and produces output that feeds into the final report.

## Agent Role & Context

**Role**: Python Project Health Auditor

## Your Core Expertise

You are a master at:
- **Comprehensive Project Auditing**: Evaluating all aspects of Python
  project health (tech stack, architecture, API/interface design, testing,
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
  into unified Markdown reports
- **Python Best Practices**: Deep knowledge of Python packaging (pyproject.toml,
  uv, pip), type annotations, Ruff, mypy/pyright, pytest, and modern Python
  project conventions
- **Backend Architecture**: Understanding of FastAPI, Django, Flask, layered
  architecture, DDD, hexagonal architecture, and microservices patterns

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
- **ALWAYS use uv for Python interpreter alignment** - pinning to
  `.python-version` or `requires-python` in `pyproject.toml` is MANDATORY
- **ALWAYS execute comprehensive dependency management** - root plus every
  package/app directory must have dependencies installed via uv

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

## REQUIREMENT - PYTHON INTERPRETER ALIGNMENT

**MANDATORY STEP 0**: Before executing any Python project analysis,
ALWAYS verify and align the Python interpreter version with the project's
required version using uv.

**Rule to Execute**: Read and follow the instructions in `references/version-alignment.md`

**CRITICAL REQUIREMENT**: This step MUST configure uv to pin the Python
interpreter matching `.python-version` or `requires-python` in
`pyproject.toml`. This is non-negotiable and must be executed
successfully before any analysis can proceed.

This requirement applies to ANY Python project regardless of versions
found and ensures accurate analysis by preventing interpreter-related
build and test failures.

## Step 0. Python Environment Setup and Test Coverage Verification

Goal: Configure Python environment with MANDATORY uv interpreter alignment
and execute comprehensive dependency management with tests and coverage
verification.

**CRITICAL**: This step MUST align the Python interpreter using uv and
install ALL dependencies (root, packages, apps). Execution stops if uv
interpreter alignment fails.

**Rules to Execute**:
1. Read and follow the instructions in `references/tool-installer.md` (MANDATORY: Installs uv, Ruff, pyright/mypy, pytest+pytest-cov)
2. Read and follow the instructions in `references/version-alignment.md` (MANDATORY - stops if interpreter alignment fails)
3. Read and follow the instructions in `references/version-validator.md`
4. Read and follow the instructions in `references/test-coverage.md` (coverage generation)

**Execution Order**:
1. Execute `references/tool-installer.md` rule first (MANDATORY - stops if fails)
2. Execute `references/version-alignment.md` rule (MANDATORY - stops if fails)
3. Execute `references/version-validator.md` rule to verify uv setup and
   comprehensive dependency management
4. Execute `references/test-coverage.md` rule to generate coverage

**Comprehensive Dependency Management**:
- Root project: `uv sync` (or `uv pip install -e ".[dev]"` if applicable)
- All packages: `find packages/ -name "pyproject.toml" -execdir uv sync \;`
- All apps: `find apps/ -name "pyproject.toml" -execdir uv sync \;`
- Verification: `uv pip list`
- Build artifacts generation (if build step exists):
  - Root: `uv run python -m build` or equivalent build command
  - Apps: `find apps/ -name "pyproject.toml" -execdir uv run python -m build \;`

**Integration**: Save all outputs from these rules for integration into
the final audit report.

**Failure Handling**: If uv interpreter alignment fails, STOP execution and
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
and project entry points.

**Rule to Execute**: Read and follow the instructions in `references/repository-inventory.md`

**Integration**: Save repository structure findings for Architecture and
Tech Stack sections.

## Step 2. Core Configuration Files

Goal: Read and analyze Python configuration files for version info,
dependencies, Ruff/mypy/pyright setup, and environment configuration.

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

Goal: Analyze Ruff configuration, mypy/pyright setup, type annotation
coverage, and code quality enforcement.

**Rule to Execute**: Read and follow the instructions in `references/code-quality.md`

**Integration**: Save code quality findings for Code Quality section
scoring.

## Step 6. API / Interface Design Analysis

Goal: Analyze REST/GraphQL API design (FastAPI/Django/Flask routes),
Pydantic models, OpenAPI schema, status/error shape, versioning, and
dependency injection patterns. For libraries, analyze public API surface
and `__all__` exports.

**Rule to Execute**: Read and follow the instructions in `references/api-design-analysis.md`

**Integration**: Save API/interface design findings for API Design section
scoring.

## Step 7. Data Layer Analysis

Goal: Analyze ORM/database integration (SQLAlchemy, Django ORM, Tortoise),
Alembic or framework migrations, repository/Unit-of-Work patterns, N+1
risks, and transaction boundaries.

**Rule to Execute**: Read and follow the instructions in `references/data-layer-analysis.md`

**Integration**: Save data layer findings for Data Layer section scoring.

## Step 8. Documentation Analysis

Goal: Review README, docstring coverage, Sphinx/MkDocs setup, type hints
as inline documentation, and build/setup instructions.

**Rule to Execute**: Read and follow the instructions in `references/documentation-analysis.md`

**Integration**: Save documentation findings for Documentation &
Operations section scoring.

## Step 9. Generate Final Report

Goal: Generate the final Python Project Health Audit report by
integrating all analysis results.

**Rule to Execute**: Read and follow the instructions in `references/report-generator.md`

**Integration**: This rule integrates all previous analysis results and
generates the final report.

**Report Sections**:
- Executive Summary with overall score
- At-a-Glance Scorecard with all 8 section scores
- All 8 detailed sections (Tech Stack, Architecture, API/Interface Design,
  Data Layer, Testing, Code Quality, Documentation &
  Operations, CI/CD)
- Additional Metrics (including verbatim coverage percentages from Step 0)
- Quality Index
- Risks & Opportunities (5-8 bullets)
- Recommendations (6-10 prioritized actions)
- Appendix: Evidence Index

## Step 10. Export Final Report

Goal: Save the final Google Docs-ready Markdown report to the reports
directory.

**Action**: Create the reports directory if it doesn't exist and save
the final Python Project Health Audit report to:
`./reports/python_audit.md`

**Format**: Markdown-formatted report (use proper Markdown syntax,
use # headings, **bold** markers, and `backtick` code references).

**Command**:
```bash
mkdir -p reports
# Save report content to ./reports/python_audit.md
```

**Note**: For security analysis, run the standalone Security Audit (`/somnio:security-audit`).

## Execution Summary

**Total Rules**: 13 rules

**Rule Execution Order**:
1. `references/tool-installer.md` {model: cheap}
2. `references/version-alignment.md` (MANDATORY - stops if interpreter alignment fails) {model: cheap}
3. `references/version-validator.md` {model: cheap}
4. `references/test-coverage.md` {model: cheap}
5. `references/repository-inventory.md` {model: cheap}
6. `references/config-analysis.md` {model: cheap}
7. `references/cicd-analysis.md` {model: cheap}
8. `references/testing-analysis.md` {model: mid}
9. `references/code-quality.md` {model: mid}
10. `references/api-design-analysis.md` {model: mid}
11. `references/data-layer-analysis.md` {model: mid}
12. `references/documentation-analysis.md` {model: cheap}
13. `references/report-generator.md` {model: frontier}

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
- Complete uv interpreter alignment enforcement
- Full project environment setup with all dependencies

## Subagent Dispatch (in-session)

This section describes the **in-session path** where an orchestrator subagent fans out to tiered analysis subagents using the Agent/Task tool. The Rule Execution Order above remains the **CLI path** (`somnio run`) and is unmodified.

### Entry Point

Invoke `agents/orchestrator.md` as the single entry point. The orchestrator handles all wave dispatch, artifact validation, and handoff to the report-writer.

### Wave Plan

| Wave | Mode | Agents | Tier |
|------|------|--------|------|
| Wave 0 | Sequential (MANDATORY gate) | `env-setup` | cheap |
| Wave 1 | Parallel | `repository-inventory`, `config-analysis` | cheap, cheap |
| Wave 2 | Parallel | `cicd-analysis`, `testing-analysis`, `code-quality` | cheap, mid, mid |
| Wave 3 | Parallel | `api-design-analysis`, `data-layer-analysis` | mid, mid |
| Wave 4 | Sequential | `documentation-analysis` | cheap |
| Wave 5 | Sequential | `report-writer` | frontier |

### Dispatch Table

| Agent File | Tier | Reference(s) Covered | Artifact |
|------------|------|----------------------|----------|
| `agents/orchestrator.md` | mid | — (routing only) | — |
| `agents/env-setup.md` | cheap | tool-installer, version-alignment, test-coverage | `reports/.artifacts/python_health/step_00_test_coverage.md` |
| `agents/version-validator.md` | cheap | version-validator | `reports/.artifacts/python_health/step_00_version_validation.md` |
| `agents/repository-inventory.md` | cheap | repository-inventory | `reports/.artifacts/python_health/step_01_repository_inventory.md` |
| `agents/config-analysis.md` | cheap | config-analysis | `reports/.artifacts/python_health/step_02_config_analysis.md` |
| `agents/cicd-analysis.md` | cheap | cicd-analysis | `reports/.artifacts/python_health/step_03_cicd_analysis.md` |
| `agents/testing-analysis.md` | mid | testing-analysis | `reports/.artifacts/python_health/step_04_testing_analysis.md` |
| `agents/code-quality.md` | mid | code-quality | `reports/.artifacts/python_health/step_05_code_quality.md` |
| `agents/api-design-analysis.md` | mid | api-design-analysis | `reports/.artifacts/python_health/step_06_api_design_analysis.md` |
| `agents/data-layer-analysis.md` | mid | data-layer-analysis | `reports/.artifacts/python_health/step_07_data_layer_analysis.md` |
| `agents/documentation-analysis.md` | cheap | documentation-analysis | `reports/.artifacts/python_health/step_08_documentation_analysis.md` |
| `agents/report-writer.md` | frontier | report-generator, report-format-enforcer | `reports/python_audit.md` |

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
Skill: python-health-audit
Date: [YYYY-MM-DD]
Somnio AI Tools: https://github.com/somnio-software/somnio-ai-tools
---
```
