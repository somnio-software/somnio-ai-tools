---
description: >-
  Execute a comprehensive Flutter Project Health Audit. Analyzes tech stack,
  architecture, state management, testing, code quality, CI/CD, and
  documentation. Produces a Google Docs-ready report with section scores and
  weighted overall score.
---

# Flutter Project Health Audit

Execute the Flutter Project Health Audit through sequential, modular rules.
Each rule produces output that feeds into the final report.

## Step 0: Environment Setup (MANDATORY)

Read `flutter-health-audit/references/tool-installer.md` and follow ALL instructions in the prompt field
Read `flutter-health-audit/references/version-alignment.md` and follow ALL instructions in the prompt field
Read `flutter-health-audit/references/version-validator.md` and follow ALL instructions in the prompt field
Read `flutter-health-audit/references/test-coverage.md` and follow ALL instructions in the prompt field

CRITICAL: If version-alignment fails, STOP execution and provide resolution steps.

## Step 1: Repository Inventory

Read `flutter-health-audit/references/repository-inventory.md` and follow ALL instructions in the prompt field

## Step 2: Configuration Analysis

Read `flutter-health-audit/references/config-analysis.md` and follow ALL instructions in the prompt field

## Step 3: CI/CD Workflows Analysis

Read `flutter-health-audit/references/cicd-analysis.md` and follow ALL instructions in the prompt field

## Step 4: Testing Infrastructure

Read `flutter-health-audit/references/testing-analysis.md` and follow ALL instructions in the prompt field

## Step 5: Code Quality and Linter

Read `flutter-health-audit/references/code-quality.md` and follow ALL instructions in the prompt field

## Step 6: Documentation and Operations

Read `flutter-health-audit/references/documentation-analysis.md` and follow ALL instructions in the prompt field

## Step 7: Generate Final Report

Read `flutter-health-audit/references/report-generator.md` and follow ALL instructions in the prompt field

## Step 8: Export Report

Save the final Google Docs-ready plain-text report to `./reports/flutter_audit.txt`

## Step 9: Optional Best Practices Check

After completing the export, ask the user if they want to execute the Flutter
Best Practices Check for micro-level code quality analysis.

NEVER execute it automatically. Only proceed if the user explicitly confirms.
If confirmed, follow workflow: `flutter-best-practices/.agent/workflows/flutter_best_practices.md`
