---
description: >-
  Execute a Modular Architecture Audit against a written standard, in
  proportion to the codebase's size and team. Measures the profile, maps
  every module into a role, extracts the import graph with a fixed metrics
  script, inspects composition and navigation, checks which rules tools
  enforce, and scores four contours out of 100 with a maturity band and a
  staged remediation plan. Read-only: never modifies the audited
  repository.
---

# Modular Architecture Audit

Execute the Modular Architecture Audit through sequential, modular rules,
measuring the codebase against `architecture-audit/references/architecture-standard.md`.
This audit is strictly read-only against the audited repository.

## Step 1: Module Map

Read `architecture-audit/references/module-map.md` and follow ALL instructions in the prompt field

## Step 2: Dependency Graph

Read `architecture-audit/references/dependency-graph.md` and follow ALL instructions in the prompt field

## Step 3: Composition Analysis

Read `architecture-audit/references/composition-analysis.md` and follow ALL instructions in the prompt field

## Step 4: Control Analysis

Read `architecture-audit/references/control-analysis.md` and follow ALL instructions in the prompt field

## Step 5: Architecture Scoring

Read `architecture-audit/references/architecture-scoring.md` and follow ALL instructions in the prompt field

## Step 6: Generate Architecture Audit Report

Read `architecture-audit/references/report-generator.md` and follow ALL instructions in the prompt field

## Step 7: Validate and Export Report

Read `architecture-audit/references/report-format-enforcer.md` and follow ALL instructions in the prompt field

Save the validated report to `./reports/<YYYY-MM-DD>-<project>-architecture-audit.md`
