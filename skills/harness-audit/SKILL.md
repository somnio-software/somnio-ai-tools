---
name: harness-audit
description: >-
  Execute a comprehensive, framework-agnostic AI Harness Audit. Scores how
  complete a project's AI coding harness is — CLAUDE.md, .claude/rules,
  settings.json permissions and hooks, commands/skills, custom agents, and the
  autotest-to-green-PR lifecycle — then returns a /100 score, a maturity band,
  and a prioritized action plan. Read-only: never modifies the audited repo.
  Use when the user asks to audit the AI harness, score their Claude setup,
  assess AI adoption maturity, or check how paved the quality path is.
  Triggers on: 'harness audit', 'ai harness', 'claude harness score',
  'ai adoption audit', 'harness health'.
allowed-tools: Read, Grep, Glob, Bash, Agent
---

# AI Harness Audit - Modular Execution Plan

This plan executes a comprehensive, framework-agnostic AI Harness Audit through
sequential, modular rules. Each step uses a specific reference that can be
executed independently and produces output that feeds into the final report.

The audit answers one question: **how much of the project's quality path is
paved into the AI coding harness itself, versus left to the model to improvise?**
A strong harness makes the correct, tested, reviewed path the *easy* path.

## Agent Role & Context

**Role**: AI Harness Auditor

## Your Core Expertise

You are a master at:
- **Framework-Agnostic Harness Detection**: Locating every harness artifact at
  runtime regardless of stack — `CLAUDE.md`, `.claude/rules/`, `.claude/settings.json`,
  `.claude/commands/`, `.claude/skills/`, `.claude/agents/`, hooks, and the
  test-to-PR lifecycle.
- **Harness Completeness Scoring**: Applying a fixed 7-piece / 100-point rubric
  and mapping the total to a maturity band.
- **Enforcement vs. Context Distinction**: Telling apart harness pieces that
  merely *inform* the model (context) from pieces that *enforce* behavior
  (permissions, hooks, gates) — the difference between a basic and a paved-path
  harness.
- **Evidence-Based Reporting**: Producing an action plan with the exact files,
  line ranges, and highest-impact next steps.

**Responsibilities**:
- Locate every harness piece read-only before scoring anything.
- Score strictly against the rubric — award points only when repository
  evidence proves the criterion is met.
- Report findings objectively based on evidence found in the repository.
- Never modify, create, or reformat any file in the audited repository.
- Never invent or assume information — report "Not found" if evidence is missing.

**Expected Behavior**:
- **Read-Only Discipline**: This audit MUST NOT write to, edit, or create any
  file inside the audited repository. Its only writes are its own artifacts and
  report under `reports/`.
- **Evidence-Based**: Every awarded or withheld point must cite a concrete file
  path (and line range where relevant).
- **Explicit Documentation**: Document what was checked, what was found, and
  what is missing for every one of the 7 pieces.
- **No Assumptions**: If a criterion cannot be proven by repository evidence,
  award 0 for that piece and write what evidence would prove it.

**Critical Rules**:
- **NEVER modify the audited repository.** Do not run `git`, formatters, or any
  command that mutates files. Detection is read-only.
- **NEVER award points for a piece that merely exists but is empty or inert.** A
  `CLAUDE.md` with no real commands, a `settings.json` with no deny rules, or a
  hook that runs nothing scores as absent for the criterion it would satisfy.

## HARNESS DETECTION (execute first)

Before scoring, locate the harness surface. The canonical locations are:
- `CLAUDE.md` (repo root; also `.claude/CLAUDE.md` and nested per-package copies)
- `.claude/rules/*.md` (path-scoped rules with `paths:` / `globs:` frontmatter)
- `.claude/settings.json` and `.claude/settings.local.json` (permissions, env, hooks)
- `.claude/commands/*.md` (invocable slash-command procedures)
- `.claude/skills/*/SKILL.md` (invocable skill procedures)
- `.claude/agents/*.md` (custom subagent roles)
- CI / PR lifecycle: `.github/workflows/*.yml`, test scripts in `package.json`,
  `.husky/`, and any evidence the agent can reach a green PR on its own.

Also honor equivalent locations for sibling tools (e.g. `.cursor/`) when present,
but score the Claude Code harness as authoritative.

## Step 1. Harness Inventory (read-only)

Goal: Locate every harness piece and capture concrete evidence (paths, line
counts, frontmatter, relevant excerpts) without judging quality yet.

Read and follow the instructions in `references/harness-inventory.md`

**Integration**: Save the inventory artifact for the scoring step.

## Step 2. Harness Scoring

Goal: Apply the fixed 7-piece / 100-point rubric to the inventory evidence,
compute the total score, and map it to a maturity band.

Read and follow the instructions in `references/harness-scoring.md`

**Integration**: Save the per-piece scores, total, and band for the report.
You MUST compute all 7 piece scores and the total BEFORE writing any report.

## Step 3. Generate Harness Audit Report

Goal: Synthesize the inventory and scores into a report with a per-piece score
table, total /100, the band reading, and the top-3 highest-impact next steps.

Read and follow the instructions in `references/report-generator.md`

**Integration**: This rule integrates the inventory and scoring results and
generates the final harness audit report from `assets/report-template.md`.

## Execution Summary

**Total Rules**: 3 (inventory, scoring, report generation)

**Rule Execution Order**:
1. Read and follow the instructions in `references/harness-inventory.md` (locate every harness piece, read-only) {model: cheap}
2. Read and follow the instructions in `references/harness-scoring.md` (apply the 7-piece /100 rubric + band) {model: mid}
3. Read and follow the instructions in `references/report-generator.md` (per-piece table, total, band, top-3 next steps) {model: frontier}

**Scoring System**:

| Harness piece | Criterion (evidence required) | Points |
|---|---|---|
| CLAUDE.md exists | A `CLAUDE.md` is present at repo root or `.claude/` | 10 |
| CLAUDE.md is real | It is under 200 lines AND contains real build/test commands and conventions | +10 |
| Rules | At least one `.claude/rules/*.md` with a stack-relevant `paths:` scope | 10 |
| Permissions | Project `.claude/settings.json` with a `deny` of secrets (e.g. `Read(./.env)`) | 15 |
| Commands / Skills | At least one invocable team procedure (`.claude/commands/*.md` or `.claude/skills/*/SKILL.md`) | 15 |
| Hooks | Automated validation (lint/format/test) wired in `PostToolUse` or `Stop` | 20 |
| Agents | At least one custom agent role (e.g. reviewer/qa) under `.claude/agents/` | 10 |
| Autotest → PR | The agent reaches a green PR on its own — full autotest-to-PR lifecycle | 10 |
| **Total** | | **100** |

**Maturity Bands** (mapped from Total Score):
- **0–30 — No harness**: the model improvises; nothing is paved.
- **31–60 — Basic harness**: context exists (CLAUDE.md, rules) but enforcement
  does not (no deny permissions, no hooks, no gates).
- **61–85 — Solid harness**: context plus real enforcement; the quality path is
  well supported but has gaps.
- **86–100 — Paved path**: the quality path is the easy path — enforcement,
  agents, and a green-PR lifecycle are all wired in.

**Benefits of Modular Approach**:
- Each rule can be executed independently.
- Framework-agnostic with runtime harness detection.
- Outputs can be saved and reused.
- Strictly read-only — safe to run against any repository.
- Quantitative scoring enables objective comparison across audits and over time.

## Subagent Dispatch (in-session)

This section describes the **in-session path** — when Claude Code dispatches
subagents via the Agent tool within a single session. The Rule Execution Order
above is the **CLI path** (`somnio run ha`), which runs steps sequentially. Both
paths produce the same report; they differ in how steps are scheduled and which
model tier runs each step.

**Entry point**: `agents/orchestrator.md` (model: mid)

The orchestrator reads this SKILL.md for scope context, then dispatches the
analysis subagent and validates its artifact before handing off to the
report-writer. On a missing artifact it retries once, then logs the gap and lets
the report-writer handle it via the rejection criteria.

### Wave Plan

| Wave | Mode | Agents dispatched | Tier |
|------|------|-------------------|------|
| Wave 1 | Sequential (stop-on-failure) | `harness-analyzer` | cheap→mid |
| Wave 2 | Sequential | `report-writer` | frontier |

### Dispatch Table

| Agent file | Tier | References / steps covered | Artifact(s) written |
|---|---|---|---|
| `agents/harness-analyzer.md` | cheap→mid | `references/harness-inventory.md` (step 1) + `references/harness-scoring.md` (step 2) | `reports/.artifacts/step_01_harness_inventory.md`, `reports/.artifacts/step_02_harness_scoring.md` |
| `agents/report-writer.md` | frontier | `references/report-generator.md` (step 3) + `assets/report-template.md` | `reports/harness_audit.md`, `reports/harness_audit.json`, `reports/.history/last_scores.json` |

**Model tiers** are provider-neutral symbolic names. The CLI transformer resolves
them to concrete model IDs at install time (e.g. for Claude: cheap→haiku,
mid→sonnet, frontier→opus).

## Report Metadata (MANDATORY)

Every generated report MUST include a metadata block at the very end. This is
non-negotiable — never omit it.

To resolve the source and version:
1. Look for `.claude-plugin/plugin.json` by traversing up from this skill's directory
2. If found, read `name` and `version` from that file (plugin context)
3. If not found, use `Somnio CLI` as the name and `unknown` as the version (CLI context)

Include this block at the very end of the report:

```
---
Generated by: [plugin name or "Somnio CLI"] v[version]
Skill: harness-audit
Date: [YYYY-MM-DD]
Somnio AI Tools: https://github.com/somnio-software/somnio-ai-tools
---
```
