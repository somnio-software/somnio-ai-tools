---
description: >-
  Execute a comprehensive, framework-agnostic Security Audit. Detects project
  type at runtime and adapts security checks accordingly. Analyzes sensitive
  files, source code secrets, dependency vulnerabilities, and optionally uses
  Gemini AI for advanced analysis. Produces a severity-classified report with
  quantitative scoring.
---

# Security Audit

Execute the Security Audit through sequential, modular rules. Detects the
project type at runtime and adapts all checks accordingly.

## Step 1: Tool Detection and Setup (MANDATORY)

Read `security-audit/references/tool-installer.md` and follow ALL instructions in the prompt field

## Step 2: Sensitive File Analysis

Read `security-audit/references/file-analysis.md` and follow ALL instructions in the prompt field

## Step 3: Source Code Secret Scanning

Read `security-audit/references/secret-patterns.md` and follow ALL instructions in the prompt field

## Step 4: Gitleaks Scan (Optional)

Read `security-audit/references/gitleaks.md` and follow ALL instructions in the prompt field

## Step 5: Dependency Vulnerability Audit

Read `security-audit/references/dependency-audit.md` and follow ALL instructions in the prompt field

## Step 6: Dependency Age Audit

Read `security-audit/references/dependency-age.md` and follow ALL instructions in the prompt field

## Step 7: Trivy Vulnerability Scan (Optional)

Read `security-audit/references/trivy.md` and follow ALL instructions in the prompt field

## Step 8: SAST Analysis

Read `security-audit/references/sast.md` and follow ALL instructions in the prompt field

## Step 9: Gemini AI Security Analysis (Optional)

Read `security-audit/references/gemini-analysis.md` and follow ALL instructions in the prompt field

## Step 10: Generate Security Report

Read `security-audit/references/report-generator.md` and follow ALL instructions in the prompt field

## Step 11: Validate and Export Report

Read `security-audit/references/report-format-enforcer.md` and follow ALL instructions in the prompt field

Save the validated report to `./reports/security_audit.txt`
