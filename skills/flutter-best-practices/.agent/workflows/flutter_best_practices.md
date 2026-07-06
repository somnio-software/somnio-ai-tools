---
description: >-
  Execute a micro-level Flutter code quality audit. Validates code against
  live GitHub standards for testing, architecture, and code implementation.
  Produces a detailed violations report with prioritized action plan.
---

# Flutter Best Practices Check

Execute the Flutter Micro-Code Audit through a two-wave multi-agent orchestration.
The orchestrator dispatches three mid-tier auditors in parallel (Wave 1), validates
artifacts, then dispatches the frontier-tier report-writer (Wave 2).

Read `agents/orchestrator.md` and follow ALL instructions.

---

## Wave 1 — Parallel Audit (model: mid)

Three auditors run simultaneously. Each owns one reference and writes one artifact.

### Step 1: Testing Quality Analysis (model: mid)

Read `flutter-best-practices/references/testing-quality.md` and follow ALL instructions in the prompt field

Artifact: `reports/.artifacts/flutter-best-practices/step_01_testing_quality.md`

### Step 2: Architecture Compliance Analysis (model: mid)

Read `flutter-best-practices/references/architecture-compliance.md` and follow ALL instructions in the prompt field

Artifact: `reports/.artifacts/flutter-best-practices/step_02_architecture_compliance.md`

### Step 3: Code Standards Analysis (model: mid)

Read `flutter-best-practices/references/code-standards.md` and follow ALL instructions in the prompt field

Artifact: `reports/.artifacts/flutter-best-practices/step_03_code_standards.md`

---

## Wave 2 — Report Synthesis (model: frontier)

Runs after the orchestrator confirms all three Wave 1 artifacts exist.

### Step 4: Report Generation (model: frontier)

Read `flutter-best-practices/references/best-practices-format-enforcer.md` and follow ALL instructions in the prompt field
Read `flutter-best-practices/references/best-practices-generator.md` and follow ALL instructions in the prompt field

Output: `reports/flutter_best_practices_report.md`
