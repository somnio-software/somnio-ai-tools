# Canonical Best-Practices Report Template

**Status:** authoritative reference · **Applies to:** the six `skills/<stack>-best-practices/`
bundles (`flutter`, `react`, `angular`, `angularjs`, `python`, `nestjs`) · **Consumed by:** nobody.
This file is **not** read by the CLI, the runner, or any `references/*.md` rule. It is the single
written source of truth a skill author copies from when hand-editing a skill's
`assets/report-template.md`. It plays the same role for the six `*-best-practices` skills that
[`report-template-canonical.md`](report-template-canonical.md) plays for the six
`*-health-audit` skills — read that file first if you haven't; this one mirrors its shape.

The two families are **not interchangeable**: best-practices reports are micro-level code-quality
checks (a fixed, small number of analysis dimensions per stack, each backed by exactly one
`references/*.md` analyzer), while health-audits are macro-level project audits (15 numbered
sections, two of them stack-variable slots). Do not copy health-audit section names, the
`Evidence`/`Risks`/`Counts & Metrics` subsection split, or the 15-section skeleton into a
best-practices template — the two skeletons are documented separately on purpose.

---

## 1. Target skeleton

```
        Title
        Project-metadata block (Project / Date / Auditor)
        ---
 1.     Executive Summary
 2.     Score Breakdown
 …      [one numbered section per analysis step — stack-variable, 3 to 7 of them]
 N.     Prioritized Recommendations
 N+1.   Evidence Index
        Appendix: Scoring Methodology  (UNNUMBERED)
        Report Metadata                (UNNUMBERED, | Field | Value | table)
```

Numbering is **relative, not absolute**. The number of scored sections is stack-variable (see
[§2](#2-stack-variable-table)), so "Prioritized Recommendations" and "Evidence Index" land at
different absolute numbers per skill — what must be identical across all six is the **shape**:
title → metadata → `## 1. Executive Summary` → `## 2. Score Breakdown` → one `## N. <Name>` per
analysis rule, in the same order the rules run → `Prioritized Recommendations` →
`Evidence Index` → the two unnumbered trailing blocks.

Every scored section's body follows this shape (verified against all six templates — see
[§4](#4-per-block-rules)):

```
Description / Score / [stack-specific structured sub-fields, e.g. **RTL Query Analysis:**] /
### Key Findings / ### Violations / ### Recommendations
```

This is **not** the health-audit family's 7-field body (`Description` / `Score` / `Key Findings` /
`Evidence` / `Risks` / `Recommendations` / `Counts & Metrics`). Best-practices sections use three
subsections — `### Key Findings`, `### Violations`, `### Recommendations` — plus whatever
stack-specific bolded sub-fields the analysis needs (e.g. react's `**RTL Query Analysis:**`,
angular's `**TestBed Analysis:**`). Do not port the health-audit subsection names into a
best-practices template.

---

## 2. Stack-variable table

Read from each skill's `assets/report-template.md` and `references/` directory — do not assume:

| Skill | Scored sections (Score Breakdown row order) | # scored sections | # `references/` files (analysis + generator + enforcer) |
|---|---|---|---|
| flutter | Testing Quality, Architecture Compliance, Code Standards | 3 | 5 |
| nestjs | Testing Quality, Architecture Compliance, Code Standards, DTO Validation, Error Handling | 5 | 7 |
| react | Testing Quality, Component Architecture, Hooks Patterns, State Management, Performance, TypeScript Standards | 6 | 8 |
| angular | Testing Quality, Component Architecture, Lifecycle & DI Patterns, Services & State Management, Change Detection & Performance, TypeScript Standards | 6 | 8 |
| angularjs | Testing Quality, Component Architecture, Scope & Binding Patterns, State Management, Performance, JavaScript Standards | 6 | 8 |
| python | Typing, Code Style, Function Design, Data Validation, Error Handling, Module Structure, Testing Quality | 7 | 9 |

flutter has exactly **3** scored sections and exactly **3** analysis files in `references/`
(`testing-quality.md`, `architecture-compliance.md`, `code-standards.md`) — see the hard
constraint in [§6](#6-hard-constraints) about never adding a fourth.

---

## 3. Header

```markdown
# <Stack> Best Practices [Check | Audit] Report

**Project:** [PROJECT_NAME]
**Date:** [AUDIT_DATE]
**Auditor:** AI-Assisted Analysis

---
```

Rules:

- Keep each skill's existing H1 title text verbatim — the six templates do not agree on
  "Check Report" vs. "Audit Report" (flutter uses "Check Report"; the other five use
  "Audit Report") and that inconsistency is pre-existing, not something to normalize here.
- There is no Exclusions blockquote in this family (that's a health-audit-only block) and no
  `**Framework:**` field.

---

## 4. Per-block rules

### 4.1 Score Breakdown (`## 2. Score Breakdown`)

```markdown
| Section | Score | Label |
|---------|-------|-------|
| <Section 1> | [XX]/100 | [Label] |
| ... one row per scored section, in the same order as the numbered sections that follow ... |
| **Weighted Overall** | **[XX]/100** | **[Label]** |

> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)
```

- Exactly three columns: `| Section | Score | Label |`. **No Weight column** — weights live only
  in the trailing `## Appendix: Scoring Methodology` block and in
  `references/best-practices-generator.md`, never as a column here ([§6](#6-hard-constraints), C6).
- The scoring-legend blockquote sits directly beneath the table (see [§5](#5-legend-byte-exact)
  for its exact bytes) — no blank paragraph, no second blockquote in between.
- Unlike the health-audit family's At-a-Glance Scorecard, this table carries **no** `Test
  Coverage` summary line and no interpretation sentence underneath the legend — that convention
  is health-audit-only.

### 4.2 Each scored section (`## N. <Name>`)

```markdown
## [N]. <Section Name>

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of this section's findings]

**<Stack-specific structured sub-field 1>:**
- [bullet]

### Key Findings
- [Finding 1]
- [Continue as needed]

### Violations
- `[path/to/file:XX]` — [Issue description]
- [Continue as needed]

### Recommendations
1. [Recommendation 1]
2. [Continue as needed]
```

- flutter's field order is `**Description:**` then `**Score:**`; the other five put
  `**Score:**` first, then `**Description:**`. This is a pre-existing inconsistency across the
  six templates — read the skill's own current template for its field order before editing it,
  do not silently reorder it to match the other five.
- The bolded structured sub-fields between `Description` and `### Key Findings` (e.g. react's
  `**RTL Query Analysis:**` / `**Async Testing:**` / `**Custom Hook Testing:**`, or flutter's
  absence of any) are entirely stack- and section-specific. They exist because a section with a
  scored number but no structured sub-fields behind it is exactly the invention risk flagged in
  [§6](#6-hard-constraints) (C3) — every structured field must trace to something the matching
  `references/<name>.md` analyzer actually inspects.
- `### Violations` (not `### Evidence`) is this family's name for the file-reference list —
  again, do not import the health-audit family's naming.

### 4.3 Prioritized Recommendations

flutter uses a flat numbered list (`1. **[High Priority]:** ...`). The other five skills use four
priority sub-headings: `### 🔴 Critical (Must Fix Immediately)`, `### 🟠 High Priority`,
`### 🟡 Medium Priority`, `### 🟢 Low Priority (Nice to Have)`. Both shapes are correct as
currently rendered — this is a real, pre-existing split between flutter and the other five, not
a drift to fix.

### 4.4 Evidence Index

A set of `**<Category> Files Analyzed:**` bolded sub-lists, one per file category the section set
produces (e.g. flutter: Test / Architecture-Layer / Model files; react: Test / Component / Hook /
Store-Context files). The categories are stack-variable and must match what the skill's own
scored sections actually cite.

---

## 5. Legend, byte-exact

```
> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)
```

En dash (U+2013) inside each range (`85–100`, `70–84`), middle dot (U+00B7) as the separator
between bands. All six templates render this identically today, including angularjs's — unlike
the health-audit family, there was no ASCII-hyphen legend to fix in this family's angularjs
template. The scale is `/100` in the Score Breakdown, in every per-section `**Score:**` line, and
in the Appendix bands — never `/10` anywhere in a `/100` template.

**flutter migrated from `/10`.** Before this unification, flutter's template scored `[Score]/10`
with bands `Strong (9–10) · Fair (7–8) · Weak (0–6)` (confirmed via `git diff` against
`skills/flutter-best-practices/assets/report-template.md`, `references/best-practices-generator.md`
and `references/best-practices-format-enforcer.md`). It is now `/100` with the same
`Strong (85–100) · Fair (70–84) · Weak (0–69)` bands as the other five skills. **This is an
intentional, documented break in comparability: a flutter best-practices report generated before
this change cannot be compared numerically to one generated after it.** Do not average, chart or
trend a pre-migration flutter score against a post-migration one.

---

## 6. Appendix: Scoring Methodology

Unnumbered, last-but-one block. Each skill's own weights, copied from that skill's own
`references/best-practices-generator.md` (verified figures below — do not cross-apply another
skill's weights):

```markdown
## Appendix: Scoring Methodology

**Weighted formula** (weights sum to 100% — the authoritative source is this skill's
`references/best-practices-generator.md`; this table is a read-only summary of what was applied):

| Section | Weight |
|---------|--------|
| ... one row per scored section, matching the Score Breakdown rows in order ... |
| **Total** | **100%** |

**Rounding rule:** Standard mathematical rounding (0.5 rounds up). No subjective adjustment.

**Scoring bands:** Strong (85–100) · Fair (70–84) · Weak (0–69)
```

Weights, by skill (each sums to 100 — verified by hand, not taken on an agent's word):

| Skill | Weights |
|---|---|
| flutter | Testing Quality 30 / Architecture Compliance 40 / Code Standards 30 |
| nestjs | Testing Quality 20 / Architecture Compliance 25 / Code Standards 20 / DTO Validation 15 / Error Handling 20 |
| react | Testing Quality 20 / Component Architecture 25 / Hooks Patterns 15 / State Management 15 / Performance 15 / TypeScript Standards 10 |
| angular | Testing Quality 20 / Component Architecture 25 / Lifecycle & DI Patterns 15 / Services & State Management 15 / Change Detection & Performance 15 / TypeScript Standards 10 |
| angularjs | Testing Quality 20 / Component Architecture 25 / Scope & Binding Patterns 15 / State Management 15 / Performance 15 / JavaScript Standards 10 |
| python | Typing 15 / Code Style 10 / Function Design 15 / Data Validation 15 / Error Handling 15 / Module Structure 10 / Testing Quality 20 |

**Each skill keeps its own weights. Never cross-apply weights between skills** — flutter's
Testing Quality is weighted 30, python's is weighted 20; they are different formulas measuring
different rubrics, not the same number that drifted.

**Weights appear in exactly two places**: this Appendix block, and
`references/best-practices-generator.md`'s own "COMPUTE OVERALL SCORE" step. They must never
appear as a column in the `## 2. Score Breakdown` table ([§4.1](#41-score-breakdown--2-score-breakdown)).

---

## 7. Report Metadata

Trailing unnumbered `| Field | Value |` table:

```markdown
## Report Metadata

| Field | Value |
|-------|-------|
| Generated by | [Plugin Name] v[Plugin Version] |
| Skill | <stack>-best-practices |
| Date | [YYYY-MM-DD] |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
```

Five of the six additionally render a trailing `| Standards Source | ... |` row, and they do not
agree on its value: react, angular and angularjs point it at
`https://github.com/somnio-software/somnio-ai-tools`, while python and nestjs point it at
`https://github.com/somnio-software/cursor-rules`. **flutter is the only skill with no
`Standards Source` row.** This is stack-variable as currently rendered — leave each skill's
existing row set alone.

---

## 7b. The template is not the only file that decides a report's shape

**Editing `assets/report-template.md` alone does not change what a produced report
contains.** This is the single easiest way to do this work wrong, and it has already
happened once — read this before adding, removing or renaming any section.

On the `somnio run` path the model is fed `references/best-practices-generator.md`,
and it follows **that** file's `## REPORT SECTIONS` list. The template is a layout
reference; the generator is the instruction. When the `Appendix: Scoring Methodology`
block was added to all six templates but the generators' section lists were left
ending at `Evidence Index`, a real run produced a report with **no appendix at all** —
and, having nowhere sanctioned to put the weights, the model added a `Weight` column
to the Score Breakdown table instead, violating [C6](#8-hard-constraints). Neither
`dart analyze` nor `dart test` saw anything wrong, because at that point the drift
test only read the template.

So a section change has to land in **four** places, per skill:

| File | What it needs |
|------|---------------|
| `assets/report-template.md` | The rendered block itself |
| `references/best-practices-generator.md` | The section in `## REPORT SECTIONS`, in the same order and by the same name; weights in `COMPUTE OVERALL SCORE` matching the appendix per label |
| `references/best-practices-format-enforcer.md` | The requirement, so the enforcer pass corrects a report that omits it |
| `agents/report-writer.md` | The same structure, for the in-session multi-agent path (`SKILL.md`'s waves), which does not read the generator |

`SKILL.md`'s prose description of the trailing metadata block is a fifth surface; keep
it describing the `| Field | Value |` table the template renders, never a plain-text
`---` list. **Never touch `SKILL.md`'s "Rule Execution Order"** — the plan parser reads
it and `plan_parser_integration_test.dart` hardcodes its step counts
([C2](#8-hard-constraints)).

Invariants 10–12 of the drift test now enforce the template↔generator agreement, so
this specific regression fails the build. Nothing checks `report-writer.md` or the
enforcer automatically — those stay on the author.

---

## 8. Hard constraints

| # | Constraint | Why |
|---|---|---|
| C1 | Never rename, move or delete `references/best-practices-generator.md` or `references/best-practices-format-enforcer.md` in any of the six skills | `cli/lib/src/runner/rule_names.dart:31,35` (`kBestPracticesGeneratorRuleName = 'best-practices-generator'`, `kBestPracticesFormatEnforcerRuleName = 'best-practices-format-enforcer'`) string-matches those exact rule names — which the plan parser derives from the filename — to dispatch report generation. Renaming either file silently disables report generation: no crash, no warning |
| C2 | Do not add, remove or rename any file under any skill's `references/` directory | `cli/test/src/runner/plan_parser_integration_test.dart` hardcodes per-skill `stepCount`/`firstRule`/`lastRule`. As read, it covers four of the six skills directly — `flutter-best-practices` (stepCount 4), `nestjs-best-practices` (6), `python-best-practices` (8), `react-best-practices` (7); `angular-best-practices` and `angularjs-best-practices` are not in that test file's expectations map today. The constraint still applies to all six: the file count in `references/` drives the plan parser's step count for every skill, tested or not |
| C3 | Never add a scored section to `flutter-best-practices` | It has exactly three analysis references (`testing-quality.md`, `architecture-compliance.md`, `code-standards.md`, per [§2](#2-stack-variable-table)). A scored section with no analyzer behind it is a section the model fills by invention, not evidence |
| C4 | `angularjs-best-practices/references/typescript-standards.md` documents JavaScript standards, and `hooks-patterns.md` documents `$scope` patterns — the filenames are misleading, the content is correct. Never rename these files (that's C2) and never "correct" their content to match the filename | The Score Breakdown row these two references back is already named correctly (`JavaScript Standards`, `Scope & Binding Patterns`) — only the `references/` filenames are misnomers, inherited from being copied off the react/angular file set. Renaming would violate C2; rewriting the content to match the wrong filename would delete correct analysis instructions |
| C5 | Each skill keeps its own weights ([§6](#6-appendix-scoring-methodology)); never cross-apply between skills | They are six independent formulas over six independent rubrics — cross-applying silently changes every score a skill produces |
| C6 | Weights appear only in the `## Appendix: Scoring Methodology` block and in `references/best-practices-generator.md` — never as a column in the `## 2. Score Breakdown` table | A Weight column in the scorecard duplicates the appendix and risks drifting out of sync with it; the enforcer for each skill (e.g. `skills/flutter-best-practices/references/best-practices-format-enforcer.md`, rule 8, "WEIGHTS APPEAR IN ONE PLACE ONLY") already states this as the single-source-of-truth rule for that skill |

---

## 9. Automated check

`cli/test/src/content/best_practices_template_drift_test.dart` reads all six
`skills/<stack>-best-practices/assets/report-template.md` files **and all six
`references/best-practices-generator.md` files** and fails the build on
divergence — the counterpart, for this family, of `report_template_drift_test.dart` for the
health-audit family. It tolerates the stack-variable middle (the differing scored-section count
and names per skill) and asserts what every one of the six genuinely shares: the section
skeleton, the `/100` scale, the scoring legend, the absence of a Weight column in the Score
Breakdown table, and that each skill's own Appendix weights match its own Score Breakdown row
labels and sum to 100. Invariants 10-12 additionally hold the generator to the
template: its `## REPORT SECTIONS` list must match the template's numbered sections in
count, name and order; it must specify both unnumbered closing blocks; and its
`COMPUTE OVERALL SCORE` weights must equal the appendix's per label, not merely sum to
100 (see [§7b](#7b-the-template-is-not-the-only-file-that-decides-a-reports-shape)).

If you edit a template, run it:

```bash
cd cli && dart test test/src/content/best_practices_template_drift_test.dart
```

A failure names the offending skill and what diverged. If the test and this document ever
disagree, **one of them is a bug** — decide which, and fix that one. Do not weaken the test to
make an edit pass.
