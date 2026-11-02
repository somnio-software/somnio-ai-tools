---
description: >-
  Execute a Next.js-specific Security Audit. Resolves the installed next and
  react versions from the lockfile and checks them against live advisory
  sources and end-of-life status, audits the dependency tree, package manager
  supply-chain hardening (pnpm recommended), secrets and NEXT_PUBLIC_
  exposure, Server Actions, Route Handlers, middleware/proxy authorization and
  security headers. Produces a severity-classified report with quantitative
  scoring.
---

# Next.js Security Audit

Execute the Next.js Security Audit through sequential, modular rules. Stops
at step 1 if no `package.json` declares `next` (use the `security-audit`
workflow instead).

## Step 1: Tool Detection and Setup (MANDATORY)

Read `nextjs-security-audit/references/tool-installer.md` and follow ALL instructions in the prompt field

## Step 2: Installed Version Resolution

Read `nextjs-security-audit/references/version-resolution.md` and follow ALL instructions in the prompt field

## Step 3: Framework Vulnerabilities and Support Status

Read `nextjs-security-audit/references/framework-vulnerabilities.md` and follow ALL instructions in the prompt field (it runs `nextjs-security-audit/references/live-vulnerability-sources.md`)

## Step 4: Dependency Tree Audit

Read `nextjs-security-audit/references/dependency-audit.md` and follow ALL instructions in the prompt field

## Step 5: Package Manager Hardening

Read `nextjs-security-audit/references/package-manager-hardening.md` and follow ALL instructions in the prompt field

## Step 6: Secrets and Environment Exposure

Read `nextjs-security-audit/references/secrets-and-env.md` and follow ALL instructions in the prompt field

## Step 7: Next.js SAST

Read `nextjs-security-audit/references/nextjs-sast.md` and follow ALL instructions in the prompt field

## Step 8: Security Headers and Config

Read `nextjs-security-audit/references/headers-and-config.md` and follow ALL instructions in the prompt field

## Step 9: Gitleaks Scan (Optional)

Read `nextjs-security-audit/references/gitleaks.md` and follow ALL instructions in the prompt field

## Step 10: Trivy Scan (Optional)

Read `nextjs-security-audit/references/trivy.md` and follow ALL instructions in the prompt field

## Step 11: Generate Security Report

Read `nextjs-security-audit/references/report-generator.md` and follow ALL instructions in the prompt field

## Step 12: Validate and Export Report

Read `nextjs-security-audit/references/report-format-enforcer.md` and follow ALL instructions in the prompt field

Save the validated report to `./reports/<YYYY-MM-DD>-<project>-nextjs-security-audit.md`
