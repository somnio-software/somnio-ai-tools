---
name: architecture-audit
description: >-
  Execute a Modular Architecture Audit against a written standard: module
  roles, an allowed-dependency matrix, ten rules and five anti-patterns,
  applied in proportion to the codebase's size and team (Compact, Standard
  or Large profile). Maps every module, extracts the import graph with a
  fixed script (Dart/Flutter, TypeScript/JavaScript and Python; other
  stacks by hand), inspects composition and navigation, checks which rules
  tools enforce, and scores four contours out of 100 with a maturity band
  and a staged remediation plan. Read-only. Use when the user asks to audit a codebase's
  architecture, modularity, feature boundaries or dependency structure.
  Triggers on: 'architecture audit', 'modularity audit', 'feature
  boundaries', 'dependency graph audit', 'module coupling'.
allowed-tools: Read, Grep, Glob, Bash, Write, Agent
---

# Modular Architecture Audit - Modular Execution Plan

This plan audits an application codebase against the **Modular Application
Architecture Standard** (`references/architecture-standard.md`) through
sequential, modular rules. Each step uses a specific reference and saves an
artifact that feeds the final report.

The audit answers one question: **do the codebase's module boundaries hold
by construction, or only by convention — to the degree its size calls
for?** It first measures the codebase's profile (Compact, Standard or
Large) from its size, feature count and team, then measures the structure,
the dependencies between modules, how the application is assembled, and
which rules tools enforce, and says in what order to fix what it finds. It
never asks a small codebase for the structure of a large one, and flags
modularisation a codebase does not need.

## Agent Role & Context

**Role**: Software Architecture Auditor

## Your Core Expertise

You are a master at:
- **Module Mapping**: Identifying physical and logical modules in any stack
  and classifying each into one role: composition root, contract, feature,
  shared-domain, shared-common, global service or foundation.
- **Dependency Graph Analysis**: Extracting import edges, mapping them to
  modules, and finding forbidden edges, cycles, deep imports and fan-in/out
  hot spots.
- **Composition Review**: Reading dependency wiring, route assembly and
  navigation to tell centralised composition from scattered assembly and
  hidden navigation coupling.
- **Governance Assessment**: Telling a rule that a tool enforces from a rule
  that is only written down.

**Responsibilities**:
- Read the standard before judging anything; apply it as written.
- Score strictly against the rubric in `references/architecture-scoring.md`.
- Report findings objectively, from evidence found in the repository.
- Never modify, create or reformat any file in the audited repository.
- Never invent or assume information; report "Not found" or "Not measured".

**Expected Behavior**:
- **Read-Only Discipline**: This audit MUST NOT write to, edit or create any
  file inside the audited repository outside `reports/`. It never runs the
  project's own linters, tests or builds, which can write into the tree.
- **Evidence-Based**: Every score cites a metric from `metrics.json` or a
  concrete `file:line`.
- **Deterministic Measurement**: Inventory, profile and graph metrics come
  from the script in `references/graph-metrics-script.md`, extracted
  mechanically; the script checks its own digest, so two runs over the
  same tree give the same numbers.
- **Proportionate**: Expectations follow the measured profile and the
  drivers; a check the profile does not call for is N/A and leaves the
  score's denominator.
- **No Assumptions**: When a check applies but cannot be measured, award 0
  for it and say what evidence was missing.

**Critical Rules**:
- **NEVER modify the audited repository.** Use only read and search
  commands and read-only `git log`.
- **NEVER classify a module by its directory name alone.** A role follows
  from what the module holds and who depends on it.
- **NEVER count a rule as enforced because it is documented.** Enforcement
  means a violation fails CI or a required hook.

## STANDARD (read first)

`references/architecture-standard.md` is the normative document every step
measures against: terms, project profiles and drivers, module roles, the
allowed-dependency matrix, rules R1-R10, anti-patterns AP1-AP5, metrics
M1-M11 with their thresholds, the four contours, the order of remediation,
and stack notes. Each step reference points to the sections it applies.

If the operator states a profile for this audit (for example "audit as
Large: two more teams join next quarter"), step 1 records it with the
reason and step 2 passes it to the script; the report shows both the
measured and the effective profile.

## Before Step 1. Disposable checkouts

`reports/` and `reports/.history/last_architecture_scores.json` are written
inside the audited checkout, so a temporary clone takes them away when it
is deleted. Step 1 (`references/module-map.md`, section 1) checks the
audited path for this, which every way of running the audit reads, and
records the warning so the report shows it in Section 2. A warning is not a stop: the audit carries on.

## Step 1. Module Map

Goal: Detect the stack and workspace, inventory the source files with the
fixed script, classify every module into one role, and record the drivers,
writing `data/files.tsv`, `data/inventory.json` and `data/module_map.tsv`.

Read and follow the instructions in `references/module-map.md`

**Integration**: Save the module map artifact and the `data/` files for
every later step.

## Step 2. Dependency Graph

Goal: Extract import edges with the fixed metrics script and compute the
profile, coupling, violations, cycles, deep imports, sizes and change
locality.

Read and follow the instructions in `references/dependency-graph.md`

**Integration**: Save `data/metrics.json` and the dependency graph
artifact.

## Step 3. Composition Analysis

Goal: Inspect implementation selection, the composition root, route
assembly, navigation between features, and layering and containment.

Read and follow the instructions in `references/composition-analysis.md`

**Integration**: Save the composition artifact.

## Step 4. Control Analysis

Goal: Find which rules are written down, which are enforced by tools that
fail on new violations, how legacy violations are tracked, and whether the
checks run locally.

Read and follow the instructions in `references/control-analysis.md`

**Integration**: Save the control artifact.

## Step 5. Architecture Scoring

Goal: Apply the four-contour rubric for the effective profile, map the
total to a band, read the quality criteria, judge rules and anti-patterns,
and order the remediation plan.

Read and follow the instructions in `references/architecture-scoring.md`

**Integration**: You MUST decide every check's outcome, the four contour
scores and the total BEFORE writing any report.

## Step 6. Generate Architecture Audit Report

Goal: Synthesize the artifacts into the report from
`assets/report-template.md`.

Read and follow the instructions in `references/report-generator.md`

## Step 7. Validate and Export Architecture Audit Report

Goal: Validate the generated report against structural and Markdown
formatting rules, then save the final report.

Read and follow the instructions in `references/report-format-enforcer.md`

**Validation**: Read the generated report and validate ALL structural checks
from the format enforcer rule: exactly 10 sections, Section 1 has the
profile line, the four contour rows, the Total, the Maturity Band and the
legend, the point arithmetic holds with N/A checks left out of the
possible points, the Total matches Section 2 and the JSON export, the band
matches the Total's range, Sections 5 and 6 are complete, Section 8 has
at most eight staged actions that fit the profile, none padded, the Evidence Index has
all five groups, and no secret values appear. Fix any issues in place. If
the scores are missing entirely, re-run Step 5 and Step 6 before exporting.

**Export**: Save the validated report to `./reports/<YYYY-MM-DD>-<project>-architecture-audit.md`

**Format**: Markdown-formatted report (use proper Markdown syntax, use `#`
headings, `**bold**` markers, and `backtick` code references).

**Command**:
```bash
mkdir -p reports
# Save validated report to ./reports/<YYYY-MM-DD>-<project>-architecture-audit.md
```

## Execution Summary

**Total Rules**: 7 (module map, dependency graph, composition, control, scoring, report generation, format enforcement)

**Rule Execution Order**:
1. Read and follow the instructions in `references/module-map.md` (stack, inventory, module roles, drivers; read-only) {model: mid}
2. Read and follow the instructions in `references/dependency-graph.md` (profile, import graph and metrics with the fixed script) {model: mid}
3. Read and follow the instructions in `references/composition-analysis.md` (implementation selection, root, routes, navigation, layering) {model: mid}
4. Read and follow the instructions in `references/control-analysis.md` (written rules, enforcement, baselines, hooks) {model: mid}
5. Read and follow the instructions in `references/architecture-scoring.md` (four contours /100 for the profile, band, criteria, rules, anti-patterns, plan) {model: frontier}
6. Read and follow the instructions in `references/report-generator.md` (10-section report, JSON export, score history) {model: frontier}

**Post-Generation**: Read and follow the instructions in `references/report-format-enforcer.md` to validate and fix
the report (runs automatically after step 6) {model: frontier}

**Scoring System**:

| Contour | Checks | Points |
|---|---|---|
| Structural | S1 boundary form fits the profile 8 · S2 feature size balance 6 · S3 file size 5 · S4 lower roles point down 6 | 25 |
| Integration | I1 feature isolation 7 · I2 acyclic graph 6 · I3 public surfaces 4 · I4 navigation contracts 4 · I5 layering and containment 4 | 25 |
| Composition | C1 substitutable wiring 8 · C2 root holds composition only 7 · C3 route assembly 5 · C4 proportionate root 5 | 25 |
| Control | K1 written standard 5 · K2 mechanical enforcement 10 · K3 debt ratchet 5 · K4 local feedback 5 | 25 |
| **Total** | | **100** |

A check the profile or stack does not call for is **N/A**: it leaves both
the earned and the possible points, and Total = round(100 × earned ÷
possible), halves rounded up. A check that applies but lacks evidence is
**Not measured** and scores 0. Rule classes are required only where the
module graph can break them. When none of the required classes is
enforced (K2 earns 0), the Total is capped at 64; when only some are, or
none is required yet, at 84, so Governed modular needs every required
class enforced. Scores are relative to the profile.

**Maturity Bands** (mapped from Total Score):
- **0–39 — Monolithic**: boundaries are conventions at best; the codebase
  behaves as one unit.
- **40–64 — Partially modular**: some modules are real, but features are
  coupled or the rules are not enforced.
- **65–84 — Modular**: modules, roles and dependencies mostly follow the
  standard for this profile; gaps remain in enforcement or in a contour.
- **85–100 — Governed modular**: the standard holds for this profile and
  tools enforce every rule class it requires.

**Benefits of Modular Approach**:
- Each rule can be executed independently.
- Graph metrics are computed by a fixed script, so audits are comparable
  across runs and across projects.
- Strictly read-only - safe to run against any repository.
- The remediation plan follows a fixed order, so each step makes the next
  one cheaper.

## Subagent Dispatch (in-session)

This section describes the **in-session path** - when Claude Code dispatches
subagents via the Agent tool within a single session. The Rule Execution
Order above is the **CLI path** (`somnio run aa`), which runs steps
sequentially. Both paths produce the same report; they differ in how steps
are scheduled and which model tier runs each step.

**Entry point**: `agents/orchestrator.md` (model: mid)

The orchestrator reads this SKILL.md for scope context, dispatches the
analysis subagents wave by wave, and validates each wave's artifacts before
starting the next. On a missing artifact it retries once, then logs the gap
and lets the next wave handle it through its rejection criteria.

### Wave Plan

| Wave | Mode | Agents dispatched | Tier |
|------|------|-------------------|------|
| Wave 1 | Sequential (stop-on-failure) | `graph-analyzer` | mid |
| Wave 2 | Sequential | `composition-analyzer` | mid |
| Wave 3 | Sequential (reads step 3) | `control-analyzer` | mid |
| Wave 4 | Sequential | `report-writer` | frontier |

### Dispatch Table

| Agent file | Tier | References / steps covered | Artifact(s) written |
|---|---|---|---|
| `agents/graph-analyzer.md` | mid | `references/module-map.md` (step 1) + `references/dependency-graph.md` (step 2) | `reports/.artifacts/architecture-audit/step_01_module-map.md`, `step_02_dependency-graph.md`, and under `data/`: `graph_metrics.py`, `files.tsv`, `inventory.json`, `module_map.tsv`, `edges.tsv`, `module_edges.tsv`, `metrics.json` |
| `agents/composition-analyzer.md` | mid | `references/composition-analysis.md` (step 3) | `reports/.artifacts/architecture-audit/step_03_composition-analysis.md` |
| `agents/control-analyzer.md` | mid | `references/control-analysis.md` (step 4) | `reports/.artifacts/architecture-audit/step_04_control-analysis.md` |
| `agents/report-writer.md` | frontier | `references/architecture-scoring.md` (step 5) + `references/report-generator.md` (step 6) + `references/report-format-enforcer.md` (step 7) + `assets/report-template.md` | `reports/.artifacts/architecture-audit/step_05_architecture-scoring.md`, `reports/<YYYY-MM-DD>-<project>-architecture-audit.md`, `reports/<YYYY-MM-DD>-<project>-architecture-audit.json`, `reports/.history/last_architecture_scores.json` |

**Model tiers** are provider-neutral symbolic names. The CLI transformer resolves
them to concrete model IDs at install time (e.g. for Claude: cheap→haiku,
mid→sonnet, frontier→opus).

## Report File Name (MANDATORY)

The report file name is always:

```
<YYYY-MM-DD>-<project>-architecture-audit.md
```

`<YYYY-MM-DD>-<project>-architecture-audit.json` — the JSON export, same name, `.json` extension.

- `<YYYY-MM-DD>` — the date of this run.
- `<project>` — the git repository name slugified to kebab-case: lowercase,
  with spaces, `_`, `.` and `/` turned into `-`, every other character dropped,
  and repeated `-` collapsed. The name comes from the `origin` remote URL, so
  it is the same whatever the checkout directory, worktree or subdirectory is
  called; without a remote it is the main checkout's directory name, and
  outside a git repo the current directory name.
- The trailing segment is this skill's name and never changes.

Derive it once, before writing anything:

```bash
mkdir -p reports
REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#/+$##; s#.*[/:]##; s#\.git$##')"
if [ -z "$REPO" ]; then
  COMMON="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  [ -n "$COMMON" ] && REPO="$(basename "${COMMON%/.git}" .git)"
fi
[ -n "$REPO" ] || REPO="$(basename "$PWD")"
REPORT="reports/$(date +%F)-$(printf '%s' "$REPO" \
  | tr '[:upper:]' '[:lower:]' | tr ' _./' '-' \
  | sed -E 's/[^a-z0-9-]//g; s/-+/-/g; s/^-|-$//g')-architecture-audit.md"
```

Everywhere this skill writes `reports/<YYYY-MM-DD>-<project>-architecture-audit.md`, it
means that resolved path.

The JSON export uses the same base name with a `.json` extension. `reports/.history/last_architecture_scores.json` is **not** a report — it is trend state read back on the next run from the same checkout, so it keeps its fixed name and is never dated. A temporary clone takes it away when it is deleted.

**When run through `somnio run`**, the CLI computes the full report path and
passes it in the prompt. Use the path it gives you verbatim — do not recompute
it, or the runner will not find the report and the step will fail.

## Report Metadata (MANDATORY)

Every generated report MUST include a metadata block at the very end. This is
non-negotiable — never omit it.

Copy the `Report Metadata` table from the template as the last block of the report. Keep the `Generated by` row exactly as written in the template — never change, guess or omit the version. Fill the remaining rows as described.

Include this block at the very end of the report:

```markdown
## 10. Report Metadata

| Field | Value |
|-------|-------|
| Scan date | [Date] |
| Project | [the `<project>` name used in the report file name] |
| Project path | [absolute path of the audited repository] |
| Profile | [effective] (measured: [measured]) |
| Scope | Production code; tests are not audited |
| Modules mapped | [N] ([N] features) |
| Total score | [Score]/100 |
| Maturity band | [Band] |
| Generated by | Somnio CLI v3.3.2 |
| Skill | architecture-audit |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
```

## Drive Upload (optional)

Upload the report to the project's Google Drive folder **only when the user asks for it**: an `upload` argument (`/architecture-audit upload`), a request such as "and upload it to Drive", or `somnio run architecture-audit --upload`. Without that request, never upload anything.

When it was requested, wait until the final report is written (in session, after the orchestrator returns), then read `references/drive-upload.md` and follow it **from the main session**, not from a subagent: subagents do not have the Google Drive MCP tools. If the audit did not produce a report, there is nothing to upload.
