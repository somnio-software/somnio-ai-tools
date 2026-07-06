---
description: >-
  Execute a micro-level Python code quality audit. Validates code against live
  GitHub standards for typing, code style, function design, data validation,
  error handling, module structure, and testing. Produces a detailed violations
  report with prioritized action plan.
---

# Python Best Practices Check

## Orchestrator-Driven (In-Session) Path

Read `python-best-practices/agents/orchestrator.md` and follow ALL instructions.

The orchestrator dispatches all subagents in two parallel waves and then delegates report synthesis to the frontier-tier report-writer. This is the preferred path when running inside a Claude session with Agent tool support.

---

## Sequential (CLI / Fallback) Path

Execute the Python Micro-Code Audit through sequential, modular rules.
Each rule validates code against specific standards from the somnio-ai-tools
repository.

### Step 1: Typing Analysis
# model: mid

Read `python-best-practices/references/typing.md` and follow ALL instructions in the prompt field

### Step 2: Code Style Analysis
# model: cheap

Read `python-best-practices/references/code-style.md` and follow ALL instructions in the prompt field

### Step 3: Function Design Analysis
# model: mid

Read `python-best-practices/references/function-design.md` and follow ALL instructions in the prompt field

### Step 4: Data Validation Analysis
# model: mid

Read `python-best-practices/references/data-validation.md` and follow ALL instructions in the prompt field

### Step 5: Error Handling Analysis
# model: mid

Read `python-best-practices/references/error-handling.md` and follow ALL instructions in the prompt field

### Step 6: Module Structure Analysis
# model: cheap

Read `python-best-practices/references/module-structure.md` and follow ALL instructions in the prompt field

### Step 7: Testing Quality Analysis
# model: mid

Read `python-best-practices/references/testing-quality.md` and follow ALL instructions in the prompt field

### Step 8: Report Generation
# model: frontier

Read `python-best-practices/references/best-practices-format-enforcer.md` and follow ALL instructions in the prompt field
Read `python-best-practices/references/best-practices-generator.md` and follow ALL instructions in the prompt field
