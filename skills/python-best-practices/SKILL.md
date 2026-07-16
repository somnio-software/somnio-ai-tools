---
name: python-best-practices
description: >-
  Execute a micro-level Python code quality audit. Validates code against live
  GitHub standards for typing, code style, function design, data validation,
  error handling, module structure, and testing. Produces a detailed violations
  report with prioritized action plan. Use when the user asks to check Python
  code quality, validate best practices, or review Python code standards.
  Triggers on: 'python best practices', 'python code quality', 'code review',
  'python standards', 'type hints review', 'pytest review', 'pydantic validation'.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent
---

# Python Micro-Code Audit Plan

This plan executes a deep-dive analysis of the Python codebase focusing
on **Micro-Level Code Quality** and adherence to specific typing,
code style, function design, validation, error handling, module structure,
and testing standards.

## Agent Role & Context

**Role**: Python Micro-Code Quality Auditor

## Your Core Expertise

You are a master at:
- **Code Quality Analysis**: Analyzing individual functions, classes, and
  test files for implementation quality
- **Standards Validation**: Validating code against the standards from
  `agent-rules/rules/python/` (local if in the repo, else live from GitHub raw)
  (typing.md, code-style.md,
  function-design.md, data-validation.md,
  error-handling.md, module-structure.md,
  testing-unit.md, testing-integration.md)
- **Typing Standards Evaluation**: Assessing type hint coverage, modern
  annotation syntax, and static analysis compliance
- **Architecture Compliance**: Evaluating adherence to `src/` layout,
  layer boundaries, and import discipline
- **Code Standards Enforcement**: Analyzing PEP 8 patterns, naming
  conventions, and Python-specific best practices
- **Evidence-Based Reporting**: Reporting findings objectively based on
  actual code inspection without assumptions

**Responsibilities**:
- Execute micro-level code quality analysis following the plan steps
  sequentially
- Validate code against the standards from the somnio-ai-tools repository (local if present, else fetched live via GitHub raw URL)
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
- **Standards Compliance**: Validate against the `.md` standards from
  `agent-rules/rules/python/` (local if in the repo, else live from GitHub raw)
  (typing.md, code-style.md,
  function-design.md, data-validation.md,
  error-handling.md, module-structure.md,
  testing-unit.md, testing-integration.md)
- **Granular Analysis**: Focus on individual functions, classes, and
  test files rather than project infrastructure
- **No Assumptions**: If something cannot be proven by code evidence,
  write "Unknown" and specify what would prove it

**Critical Rules**:
- **ALWAYS validate against the standards** - read from
  `agent-rules/rules/python/` if present in the repo, otherwise WebFetch them
  from the GitHub raw URL (https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/python/)
- **FOCUS on code quality** - analyze implementation, not infrastructure
- **REPORT violations clearly** - specify which standard is violated
  and provide code examples
- **MAINTAIN format consistency** - follow the template structure for
  Markdown reports
- **NEVER skip standard validation** - all code must be checked
  against applicable standards

## Step 1: Typing Analysis
**Goal**: Evaluate conformance to `python-typing.mdc` annotation standards.
**Rule**: Read and follow the instructions in `references/typing.md`
**Focus Areas**:
- Type hint coverage on all public functions and methods
- Absence of bare `Any` without justification
- Modern generic syntax (`list[int]`, `dict[str, int]`, `X | None`)
- `Protocol` and generic class usage
- pyright / mypy strict-mode compliance
- Presence of `py.typed` marker

## Step 2: Code Style Analysis
**Goal**: Evaluate conformance to `python-code-style.mdc` standards.
**Rule**: Read and follow the instructions in `references/code-style.md`
**Focus Areas**:
- PEP 8 compliance
- Naming conventions (snake_case, PascalCase, UPPER_CASE)
- Import grouping and absolute imports
- Line length (88 characters / Ruff default)
- Docstring format (Google style)
- Ruff-clean output

## Step 3: Function Design Analysis
**Goal**: Evaluate conformance to `python-function-design.mdc`.
**Rule**: Read and follow the instructions in `references/function-design.md`
**Focus Areas**:
- Single responsibility per function
- Function length and cognitive complexity
- Early returns and guard clauses
- Side-effect isolation
- Dataclass usage where appropriate
- Keyword-only argument usage

## Step 4: Data Validation Analysis
**Goal**: Evaluate conformance to `python-data-validation.mdc`.
**Rule**: Read and follow the instructions in `references/data-validation.md`
**Focus Areas**:
- Pydantic models at system boundaries
- Custom validator coverage
- No raw unvalidated `dict` passing
- Typed API request / response models
- pydantic-settings for configuration objects

## Step 5: Error Handling Analysis
**Goal**: Evaluate conformance to `python-error-handling.mdc`.
**Rule**: Read and follow the instructions in `references/error-handling.md`
**Focus Areas**:
- Specific vs. broad/bare `except` clauses
- Custom exception hierarchy
- No silent exception swallowing
- Appropriate logging levels
- No control-flow-by-exception anti-patterns

## Step 6: Module Structure Analysis
**Goal**: Evaluate conformance to `python-module-structure.mdc`.
**Rule**: Read and follow the instructions in `references/module-structure.md`
**Focus Areas**:
- `src/` layout adoption
- `__all__` declarations in public modules
- Layer boundary and dependency-direction enforcement
- Absence of circular imports
- Absolute import usage

## Step 7: Testing Quality Analysis
**Goal**: Evaluate conformance to `python-testing-unit.mdc` and
`python-testing-integration.mdc`.
**Rule**: Read and follow the instructions in `references/testing-quality.md`
**Focus Areas**:
- pytest discovery and naming conventions (`test_*.py` / `*_test.py`)
- Plain `assert` usage with `pytest.raises(match=...)`
- Fixture design, scope, and `conftest.py` placement
- `@pytest.mark.parametrize` with explicit `ids`
- `mocker` / autospec / patch-where-used discipline
- Integration test teardown and isolation
- Registered custom markers

## Step 8: Report Generation
**Goal**: Aggregate all findings into a final Markdown report using
the template.
**Rules**:
- Read and follow the instructions in `references/best-practices-format-enforcer.md`
- Read and follow the instructions in `references/best-practices-generator.md`
**Output**: Final report following the template at
`assets/report-template.md`

**Rule Execution Order**:
1.  `references/typing.md` {model: mid}
2.  `references/code-style.md` {model: cheap}
3.  `references/function-design.md` {model: mid}
4.  `references/data-validation.md` {model: mid}
5.  `references/error-handling.md` {model: mid}
6.  `references/module-structure.md` {model: cheap}
7.  `references/testing-quality.md` {model: mid}
8.  `references/best-practices-generator.md` {model: frontier}

## Subagent Dispatch (in-session)

When running inside a Claude session with the Agent tool available, the orchestrator is the single entry point. It fans out to subagents in parallel waves instead of running steps sequentially.

**Entry point**: `agents/orchestrator.md` (tier: mid)

### Wave Plan

| Wave | Agents (parallel) | Tier | Purpose |
|------|-------------------|------|---------|
| Wave 1 — Scan | code-style-analyzer, module-structure-analyzer | cheap | Mechanical grep-and-classify scans |
| Wave 2 — Analysis | typing-analyzer, function-design-analyzer, data-validation-analyzer, error-handling-analyzer, testing-quality-analyzer | mid | Semantic reasoning over code |
| Wave 3 — Report | report-writer | frontier | Cross-section score reconciliation and synthesis |

### Dispatch Table

| Agent file | Tier | Reference(s) covered | Artifact |
|------------|------|----------------------|----------|
| `agents/code-style-analyzer.md` | cheap | `references/code-style.md` (step 2) | `reports/.artifacts/python-best-practices/step_02_code_style.md` |
| `agents/module-structure-analyzer.md` | cheap | `references/module-structure.md` (step 6) | `reports/.artifacts/python-best-practices/step_06_module_structure.md` |
| `agents/typing-analyzer.md` | mid | `references/typing.md` (step 1) | `reports/.artifacts/python-best-practices/step_01_typing.md` |
| `agents/function-design-analyzer.md` | mid | `references/function-design.md` (step 3) | `reports/.artifacts/python-best-practices/step_03_function_design.md` |
| `agents/data-validation-analyzer.md` | mid | `references/data-validation.md` (step 4) | `reports/.artifacts/python-best-practices/step_04_data_validation.md` |
| `agents/error-handling-analyzer.md` | mid | `references/error-handling.md` (step 5) | `reports/.artifacts/python-best-practices/step_05_error_handling.md` |
| `agents/testing-quality-analyzer.md` | mid | `references/testing-quality.md` (step 7) | `reports/.artifacts/python-best-practices/step_07_testing_quality.md` |
| `agents/report-writer.md` | frontier | `references/best-practices-format-enforcer.md` + `references/best-practices-generator.md` (step 8) | `reports/python_best_practices_report.md` |

> **Note**: The Rule Execution Order above is the CLI runner path (`somnio run`). The Subagent Dispatch section documents the in-session path. Both paths produce the same report at `reports/python_best_practices_report.md`.

## Standards References

All standards are sourced from:
`agent-rules/rules/python/` (somnio-ai-tools repo locally, or GitHub raw if installed standalone)

| Standard File | Purpose |
|---------------|---------|
| `typing.md` | Type hint coverage, modern annotation syntax, static analysis |
| `code-style.md` | PEP 8, naming conventions, import grouping, docstrings, Ruff |
| `function-design.md` | Single responsibility, function length, side-effect isolation |
| `data-validation.md` | Pydantic boundaries, validators, typed responses, settings |
| `error-handling.md` | Exception specificity, custom hierarchy, logging levels |
| `module-structure.md` | `src/` layout, `__all__`, layer boundaries, circular imports |
| `testing-unit.md` | Unit test patterns, fixtures, parametrize, mocking |
| `testing-integration.md` | Integration tests, teardown, isolation, markers |

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
Skill: python-best-practices
Date: [YYYY-MM-DD]
Somnio AI Tools: https://github.com/somnio-software/somnio-ai-tools
---
```
