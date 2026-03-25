---
description: "Run project health, best practices, or security audit"
argument-hint: "[flutter|nestjs|security] [health|best-practices|all]"
allowed-tools: ["Bash", "Glob", "Grep", "Read", "Write", "Agent", "Skill", "AskUserQuestion"]
---

# Somnio Audit Orchestrator

You are the Somnio audit orchestrator. Your job is to detect the project type,
determine which audit(s) to run, and delegate execution to the appropriate
skill(s). Follow this plan step by step.

## Phase 1 — Parse Arguments

Read the user arguments: `$ARGUMENTS`

- `$1` = audit type: `flutter`, `nestjs`, or `security` (optional)
- `$2` = audit scope: `health`, `best-practices`, or `all` (optional)

If both arguments are provided, skip to Phase 3.
If only `$1` is provided, skip to Phase 2b.
If no arguments are provided, proceed to Phase 2a.

## Phase 2a — Auto-Detect Project Type (interactive mode)

Detect the project type by checking the current working directory:

1. Use Glob to check for `pubspec.yaml` in the project root.
2. Use Glob to check for `package.json` in the project root.
3. If `package.json` exists, use Read to check whether it contains
   `@nestjs/core` in its dependencies or devDependencies.

**Detection rules:**
- `pubspec.yaml` found --> Flutter project
- `package.json` with `@nestjs/core` --> NestJS project
- `package.json` without `@nestjs/core` --> Unknown Node.js project (only
  security audit available)
- Neither file found --> Cannot detect project type

If detection fails, use AskUserQuestion to ask the user:
> "Could not auto-detect project type. What type of project is this?
> Options: flutter, nestjs, security-only"

Once the project type is known, present available audits using AskUserQuestion:

**For Flutter projects, ask:**
> "Detected **Flutter** project. Which audit would you like to run?
>
> 1. **Health Audit** - Comprehensive project health assessment (tech stack,
>    architecture, testing, CI/CD, docs). ~15-25 min.
> 2. **Best Practices** - Micro-level code quality check against Flutter
>    standards. ~10-15 min.
> 3. **Security Audit** - Vulnerability scan, secret detection, dependency
>    audit. ~10-15 min.
> 4. **All** - Run health audit + best practices + security. ~40-55 min.
>
> Enter a number or name:"

**For NestJS projects, ask:**
> "Detected **NestJS** project. Which audit would you like to run?
>
> 1. **Health Audit** - Comprehensive project health assessment (tech stack,
>    architecture, API design, data layer, testing, CI/CD, docs). ~15-25 min.
> 2. **Best Practices** - Micro-level code quality check against NestJS
>    standards. ~10-15 min.
> 3. **Security Audit** - Vulnerability scan, secret detection, dependency
>    audit. ~10-15 min.
> 4. **All** - Run health audit + best practices + security. ~40-55 min.
>
> Enter a number or name:"

**For unknown/security-only projects, ask:**
> "Only security audit is available for this project type. Proceed?
> (yes/no)"

Map the user's response to the appropriate type and scope, then proceed to
Phase 3.

## Phase 2b — Scope Selection (type provided, scope missing)

If `$1` was provided but `$2` was not, use AskUserQuestion to ask:

**For flutter or nestjs:**
> "Which scope for the **$1** audit?
>
> 1. **health** - Comprehensive project health assessment
> 2. **best-practices** - Micro-level code quality check
> 3. **all** - Both health + best practices + security
>
> Enter a number or name:"

**For security:**
> Skip this phase -- security has no sub-scope. Proceed directly to Phase 3
> with type=security.

## Phase 3 — Resolve Skills to Execute

Based on the resolved type and scope, build the execution list:

| Type | Scope | Skills to run |
|------|-------|---------------|
| `flutter` | `health` | `flutter-health-audit` |
| `flutter` | `best-practices` | `flutter-best-practices` |
| `flutter` | `all` | `flutter-health-audit`, then `flutter-best-practices`, then `security-audit` |
| `nestjs` | `health` | `nestjs-health-audit` |
| `nestjs` | `best-practices` | `nestjs-best-practices` |
| `nestjs` | `all` | `nestjs-health-audit`, then `nestjs-best-practices`, then `security-audit` |
| `security` | (any) | `security-audit` |

## Phase 4 — Pre-Flight Confirmation

Before launching, confirm with the user via AskUserQuestion:

> "Ready to run the following audit(s):
>
> [list each skill with its display name]
>
> Project directory: [current working directory]
>
> This will create reports in `./reports/`. Proceed? (yes/no)"

If the user says no, stop and report that the audit was cancelled.

## Phase 5 — Execute Audits

For each skill in the execution list, launch it using the Skill tool:

- For `flutter-health-audit`: invoke Skill with `skill: "flutter-health-audit"`
- For `flutter-best-practices`: invoke Skill with `skill: "flutter-best-practices"`
- For `nestjs-health-audit`: invoke Skill with `skill: "nestjs-health-audit"`
- For `nestjs-best-practices`: invoke Skill with `skill: "nestjs-best-practices"`
- For `security-audit`: invoke Skill with `skill: "security-audit"`

Execute skills **sequentially** -- each must complete before starting the next.
If a skill fails, report the failure and ask the user whether to continue with
remaining skills or abort.

**Between skills in "all" mode:** Briefly summarize what the completed skill
found before proceeding to the next one.

## Phase 6 — Summary

After all skills complete, provide a consolidated summary:

1. List each audit that was run and its overall score (if applicable).
2. Note where reports were saved (typically `./reports/`).
3. Highlight the top 3 most critical findings across all audits.
4. Suggest next steps based on the findings.

Format the summary clearly with headers and bullet points so it is easy to
scan.
