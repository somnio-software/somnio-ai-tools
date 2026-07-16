---
description: Execute a comprehensive Python Project Health Audit. Analyzes tech stack, architecture, API design, data layer, testing, code quality, CI/CD, and documentation. Produces a report with section scores and weighted overall score.
---

# Python Project Health Audit

Read `agents/orchestrator.md` and follow ALL instructions.

The orchestrator is the single entry point for the in-session path. It dispatches all analysis subagents in dependency-ordered waves, validates artifacts, and hands the full artifact manifest to the report-writer.

---

<!-- CLI PATH (somnio run) — preserved below for the plan_parser; do not remove or reorder -->

## Wave 0: Environment Setup (MANDATORY - Sequential)
<!-- model: cheap -->

Read `python-health-audit/references/tool-installer.md` and follow ALL instructions in the prompt field
STEP 0a COMPLETED: [log result]

Read `python-health-audit/references/version-alignment.md` and follow ALL instructions in the prompt field
STEP 0b COMPLETED: [log result]

Read `python-health-audit/references/version-validator.md` and follow ALL instructions in the prompt field
STEP 0c COMPLETED: [log result]

Read `python-health-audit/references/test-coverage.md` and follow ALL instructions in the prompt field
STEP 0d COMPLETED: [log result]

CRITICAL: If version-alignment fails, STOP execution and provide resolution steps.

## Wave 1: Structure Analysis (Parallelizable)
<!-- model: cheap -->

These steps are independent and can be executed in parallel if supported:

Read `python-health-audit/references/repository-inventory.md` and follow ALL instructions in the prompt field
STEP 1 COMPLETED: [log result]

Read `python-health-audit/references/config-analysis.md` and follow ALL instructions in the prompt field
STEP 2 COMPLETED: [log result]

## Wave 2: Infrastructure Analysis (Parallelizable)

These steps are independent and can be executed in parallel if supported:

<!-- model: cheap -->
Read `python-health-audit/references/cicd-analysis.md` and follow ALL instructions in the prompt field
STEP 3 COMPLETED: [log result]

<!-- model: mid -->
Read `python-health-audit/references/testing-analysis.md` and follow ALL instructions in the prompt field
STEP 4 COMPLETED: [log result]

<!-- model: mid -->
Read `python-health-audit/references/code-quality.md` and follow ALL instructions in the prompt field
STEP 5 COMPLETED: [log result]

<!-- model: mid -->
Read `python-health-audit/references/harness-analysis.md` and follow ALL instructions in the prompt field
STEP 6 COMPLETED: [log result]

## Wave 3: Domain Analysis (Parallelizable)
<!-- model: mid -->

These steps are independent and can be executed in parallel if supported:

Read `python-health-audit/references/api-design-analysis.md` and follow ALL instructions in the prompt field
STEP 7 COMPLETED: [log result]

Read `python-health-audit/references/data-layer-analysis.md` and follow ALL instructions in the prompt field
STEP 8 COMPLETED: [log result]

## Wave 4: Documentation (Sequential)
<!-- model: cheap -->

Read `python-health-audit/references/documentation-analysis.md` and follow ALL instructions in the prompt field
STEP 9 COMPLETED: [log result]

## Wave 5: Report (Sequential - Requires ALL previous results)
<!-- model: frontier -->

Read `python-health-audit/references/report-generator.md` and follow ALL instructions in the prompt field
STEP 10 COMPLETED: [log result]

Save the final Markdown report to `./reports/python_audit.md`
STEP 11 COMPLETED: Report exported

---

## Next Steps (Optional)

For Python-specific best practices and additional code improvement recommendations, see `python-best-practices/.agent/workflows/python_best_practices.md` (not auto-executed).
