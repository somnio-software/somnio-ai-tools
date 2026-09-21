# Canonical Health-Audit Report Template

**Status:** authoritative reference · **Applies to:** the six `skills/<stack>-health-audit/`
bundles (`flutter`, `react`, `angular`, `angularjs`, `python`, `nestjs`) · **Consumed by:** nobody.
This file is **not** read by the CLI, the runner, or any `references/*.md` rule. It is the single
written source of truth a skill author copies from when hand-editing a skill's
`assets/report-template.md`. Analogous in spirit to `agent-rules/rules/<stack>/*.md` being the
canonical source for adapters.

> **Quality Index is gone.** The old skeleton had 16 numbered sections; `## 13. Quality Index` — a
> byte-for-byte duplicate of the `## 2. At-a-Glance Scorecard` table — has been deleted. **The
> canonical section count is now 15.** Every following section renumbers down by one. Its one piece
> of non-duplicate content (a trailing interpretation sentence) is absorbed into section 2 (see
> [§4](#4-section-2--at-a-glance-scorecard)).

---

## 1. Target skeleton (15 numbered sections + 2 trailing unnumbered blocks)

```
        Title
        Project-metadata block (Project / Date / Auditor / Framework)
        Exclusions blockquote
        ---
 1.     Executive Summary
 2.     At-a-Glance Scorecard          ← + Test Coverage line, + interpretation sentence
 3.     Tech Stack
 4.     Architecture
 5.     [State Management | API Design]                        (stack-variable, slot A)
 6.     [Repositories & Data Layer | Data Layer | omitted]      (stack-variable, slot B)
 …      Testing                        ← canonical coverage contract
 …      Code Quality (Linter & Warnings)
 …      [Performance]                                          (react/angular/angularjs only)
 …      Documentation & Operations
 …      CI/CD (Configs Found in Repo)
 …      AI Harness & Adoption          ← "### Coverage" renamed "### Harness Coverage"
 …      Additional Metrics             ← no coverage bullets anywhere (stack-variable field list)
 …      Risks & Opportunities
 …      Recommendations
15.     Appendix: Evidence Index
        Appendix: Scoring Methodology  (UNNUMBERED, new)
        Report Metadata                (UNNUMBERED, | Field | Value | table)
```

Numbering is **relative, not absolute**. Skills without slot B (react/angular/angularjs) don't
compress the count, because they gain a Performance section that flutter/python/nestjs don't have —
every skill lands on exactly **15** numbered sections, but *which* numbered slot Testing/Code
Quality/Performance sit in differs. What must be identical across all six is the **order and the
set** of sections, never the absolute numbers.

Every scored section keeps the same 7-field body shape it has today (verified against
`skills/flutter-health-audit/assets/report-template.md`): `Description` / `Score` / `Key Findings` /
`Evidence` / `Risks` / `Recommendations` / `Counts & Metrics`. The Testing section additionally
carries two coverage fields between `Score` and `Key Findings` — see [§5](#5-testing-section--canonical-coverage-contract).

---

## 2. Stack-variable slot table

Which skill uses which slot, and where each lands after Quality Index is removed:

| Skill | §5 (slot A) | §6 (slot B) | Testing § | Code Quality § | Performance § | Total numbered sections |
|---|---|---|---|---|---|---|
| flutter | State Management | Repositories & Data Layer | 7 | 8 | — | 15 |
| python | API Design | Data Layer | 7 | 8 | — | 15 |
| nestjs | API Design | Data Layer | 7 | 8 | — | 15 |
| react | State Management | — (no slot B) | 6 | 7 | 8 | 15 |
| angular | State Management | — (no slot B) | 6 | 7 | 8 | 15 |
| angularjs | State Management | — (no slot B) | 6 | 7 | 8 | 15 |

flutter/python/nestjs have both slots and no Performance section (weight family **A**).
react/angular/angularjs have only slot A, no slot B, and a Performance section (weight family
**B** — see [§9](#9-appendix-scoring-methodology)). Both groups still total 15 numbered sections;
the Performance section fills the numbering gap left by the missing slot B.

---

## 3. Header

**D1 (user decision, overrides plan §4.4): keep BOTH header blocks.** Every template's header is
the project-metadata block **and** the Exclusions blockquote — do not drop the metadata block from
any skill.

```markdown
# <Stack> Project Health Audit Report

**Project:** [PROJECT_NAME]
**Date:** [AUDIT_DATE]
**Auditor:** AI-Assisted Analysis
**Framework:** [<stack-specific hint>]

> **Exclusions:** <stack-specific exclusions sentence>

---
```

Rules:

- Keep each skill's existing H1 title text verbatim (e.g. "Flutter Project Health Audit Report").
- `**Framework:**` hint per stack — if a template already has a `**Framework:**` value, **keep it,
  do not churn it**:

  | Stack | Framework hint |
  |---|---|
  | flutter | `[Flutter/Dart — single app/monorepo]` |
  | react | `[React/Next.js/Remix/Vite]` (keep react/angular/angularjs's existing value verbatim if one is already present) |
  | angular | `[Angular CLI/Nx]` |
  | angularjs | `[AngularJS 1.x]` |
  | python | `[FastAPI/Django/Flask]` |
  | nestjs | `[NestJS/Node.js]` |

- Exclusions text:
  - **flutter, python, nestjs already have one** — keep the existing line **verbatim**, unchanged.
    Confirmed example (flutter, `skills/flutter-health-audit/assets/report-template.md:3`):
    `> **Exclusions:** Never recommend adding new languages/translations, CODEOWNERS/SECURITY.md files, or platform-specific Android/iOS build workflows.`
    (python's and nestjs's existing exclusion lines were not re-read for this document — copy
    whatever each of those two templates already renders, verbatim; do not invent their wording.)
  - **react, angular, angularjs have none today** — add exactly:
    `> **Exclusions:** Never recommend adding new languages/translations, CODEOWNERS/SECURITY.md files, or deployment-specific workflows.`

---

## 4. Section 2 — At-a-Glance Scorecard

Keep the existing `| Section | Score | Label |` table and its existing row set exactly as each
skill renders it today — rows are stack-variable (see [§2](#2-stack-variable-slot-table)); do
**not** add or remove rows, and do **not** add a Weight column (weights live only in the appendix,
[§9](#9-appendix-scoring-methodology)).

Immediately below the table, in this exact order:

```markdown
> **Test Coverage:** [X]% (lines) — full breakdown in the Testing section.
> Fallback when no coverage tool is detected: `Not measured (no coverage tool detected/configured)`

> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)

[One-sentence interpretation of the Overall Score.]
```

Rules:

- The fallback line is the **second line inside the same blockquote** as `Test Coverage` — not a
  separate blockquote, not a separate paragraph.
- Normalise the scoring-legend blockquote to **exactly**
  `> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)` — en dash (U+2013) inside each
  range, middle dot (U+00B7) as separator. This is also the angularjs punctuation fix: angularjs
  today renders this line with plain ASCII hyphens and must be corrected to the same typography as
  the other five.
- The `[One-sentence interpretation of the Overall Score.]` line is the sentence **absorbed from
  the deleted Quality Index section**. If a skill's old Quality Index ended with a concrete
  interpretation sentence, move that sentence here (adapted to sit under the scorecard); otherwise
  use the bracketed placeholder.
- The label is **`Test Coverage`, never a bare `Coverage`** — `Coverage` is already the AI Harness
  rubric heading in section 11 ([§8](#8-ai-harness--adoption)); a bare label would collide with it.

---

## 5. Testing section — canonical coverage contract

Between `**Score:**` and `### Key Findings`, insert exactly these two fields:

```markdown
**Code Coverage:** [X]% (lines)
> Multi-dimension stacks (JS/TS): `[X]% lines / [Y]% branches / [Z]% functions`
> Monorepo / multi-app: `App [name]: [X]%, App [name2]: [Y]%`
> No coverage tool: `Not measured (no coverage tool detected/configured)`

**Coverage Breakdown:**
- `[module/package/app]`: [X]% (lines[, [Y]% branches, [Z]% functions — where extracted])
- [Continue per module/package/app]
- [Single-package projects: "N/A — single package, see Code Coverage above"]
- [No data: "(no coverage data — artifact missing or no coverage tool configured)"]
```

Full section shape (the real 7-field body, with the two coverage fields inserted after `Score`,
matching the shape verified in `skills/flutter-health-audit/assets/report-template.md:191-230`):

```markdown
## [N]. Testing

**Description:** [One-sentence description of the testing analysis].

**Score:** [Score]/100 ([Label])

**Code Coverage:** [X]% (lines)
> Multi-dimension stacks (JS/TS): `[X]% lines / [Y]% branches / [Z]% functions`
> Monorepo / multi-app: `App [name]: [X]%, App [name2]: [Y]%`
> No coverage tool: `Not measured (no coverage tool detected/configured)`

**Coverage Breakdown:**
- `[module/package/app]`: [X]% (lines[, [Y]% branches, [Z]% functions — where extracted])
- [Continue per module/package/app]
- [Single-package projects: "N/A — single package, see Code Coverage above"]
- [No data: "(no coverage data — artifact missing or no coverage tool configured)"]

### Key Findings
- [Finding 1]
- [Continue as needed]

### Evidence
- [File path or configuration reference]
- [Continue as needed]

### Risks
- [Risk item 1]
- [Continue as needed]

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- Test count: [Value]
- Test framework: [Value]
- [Do NOT restate the coverage percentage here — it lives only in the fields above]
```

Rules:

- `### Counts & Metrics` must **not** restate any coverage percentage. Delete any coverage bullet
  found there (e.g. python's current `**Test coverage:**` / `**Coverage by module:**` bullets in
  Counts & Metrics — their content is fully carried by the two fields above; do not leave a
  duplicate).
- flutter already has a coverage block in Testing — **reshape it** to match this canonical wording
  rather than appending a second one alongside it.
- **Net result: coverage appears exactly twice per report** — the scorecard summary line
  ([§4](#4-section-2--at-a-glance-scorecard)) and these Testing fields. Nowhere else in the report.

---

## 6. Quality Index removal

Delete the whole `## 13. Quality Index` section (heading through the line before the next `## `).
Renumber every following numbered section down by one, so the file ends with
`## 15. Appendix: Evidence Index`. Its trailing interpretation sentence, if it has one, is absorbed
into section 2's interpretation line ([§4](#4-section-2--at-a-glance-scorecard)) — nothing else
about it survives, since the rest of it was a byte-for-byte duplicate of the scorecard table.

---

## 7. Additional Metrics

No coverage bullets, anywhere. flutter currently has three coverage bullets in Additional Metrics
(`**Coverage %:**`, `**Coverage breakdown by component:**`, `**Overall aggregated coverage %:**`) —
delete all three; that data now lives solely in the Testing section fields
([§5](#5-testing-section--canonical-coverage-contract)). The other five skills have no coverage
bullets there today — leave their existing field lists alone; those lists are legitimately
stack-variable and this task does not touch them.

---

## 8. AI Harness & Adoption

Rename the `### Coverage` subheading inside the AI Harness & Adoption section to
`### Harness Coverage`. Do not touch anything else in that section (the 10-dimension rubric table,
its rows, or its scoring), and do not rename any other `Coverage` occurrence in the file — this
rename applies to exactly one subheading, in exactly one section.

---

## 9. Appendix: Scoring Methodology

New, unnumbered block. Insert between `## 15. Appendix: Evidence Index` and `## Report Metadata`:

```markdown
## Appendix: Scoring Methodology

**Weighted formula** (weights sum to 1.00 — the authoritative source is this skill's
`references/report-generator.md`; this table is a read-only summary of what was applied):

| Section | Weight |
|---------|--------|
| ... one row per scored section, matching the scorecard rows in order ... |
| **Total** | **1.00** |

**Rounding rule:** Standard mathematical rounding (0.5 rounds up). No subjective adjustment.

**Scoring bands:** Strong (85–100) · Fair (70–84) · Weak (0–69)
```

This appendix is the **only** report-facing surface where weights may appear anywhere in the
report. Use your own skill's weight family — **never cross-apply the two families.**

### Weight family A — flutter, python, nestjs (no Performance section)

| Section | Weight |
|---------|--------|
| Tech Stack | 0.18 |
| Architecture | 0.18 |
| [State Management \| API Design] | 0.18 |
| [Repositories & Data Layer \| Data Layer] | 0.10 |
| Testing | 0.10 |
| Code Quality | 0.10 |
| Documentation & Operations | 0.03 |
| CI/CD | 0.03 |
| AI Harness & Adoption | 0.10 |
| **Total** | **1.00** |

### Weight family B — react, angular, angularjs (with Performance section)

| Section | Weight |
|---------|--------|
| Tech Stack | 0.18 |
| Architecture | 0.18 |
| State Management | 0.135 |
| Testing | 0.135 |
| Code Quality | 0.135 |
| Performance | 0.075 |
| Documentation & Operations | 0.03 |
| CI/CD | 0.03 |
| AI Harness & Adoption | 0.10 |
| **Total** | **1.00** |

The row labels in each skill's own appendix table must match that skill's own scorecard row labels
exactly (e.g. use "Code Quality (Linter & Warnings)" if that's how the scorecard row reads).

---

## 10. Report Metadata

Stays the trailing unnumbered `| Field | Value |` table exactly as the templates already render it
(verified shape, `skills/flutter-health-audit/assets/report-template.md:488-495`):

```markdown
## Report Metadata

| Field | Value |
|-------|-------|
| Generated by | [Plugin Name] v[Plugin Version] |
| Skill | <stack>-health-audit |
| Date | [YYYY-MM-DD] |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
```

Note: each skill's `SKILL.md` currently *describes* this block as plain text between `---` rules
(`Generated by: … / Skill: … / Date: …`). That is a `SKILL.md` documentation bug, not a template
bug — the templates already render the table form above and are correct as-is. Fix the `SKILL.md`
prose to match the table, not the other way around.

---

## 11. Hard constraints

| # | Constraint | Why |
|---|---|---|
| C1 | Never rename, move or delete `references/report-generator.md` or `references/report-format-enforcer.md` | `cli/lib/src/runner/rule_names.dart` string-matches those exact file names; renaming silently disables report generation |
| C2 | Do not add, remove or rename any file in `references/`. Content edits only | `cli/test/.../plan_parser_integration_test.dart` hardcodes per-skill step counts |
| C3 | Renumbering demands a full literal `Section N` prose sweep across `references/report-generator.md`, `references/report-format-enforcer.md` and `references/harness-analysis.md` | A missed literal reference makes the rubric validate the wrong section, silently |
| C4 | Do not touch `harness-analysis.md`'s internal `Section 6` (or similar) references | Those point at sections of that document's own 10-dimension rubric, not at report sections. Only renumber a reference if it unambiguously points at a numbered section of the generated report |
| C5 | Weight family A and family B stay separate; never cross-apply | They are different formulas for a reason (presence of a Performance section); cross-applying changes every score the skill produces |
| C6 | Nothing in Dart validates a **generated report** | `cli/test/src/content/report_template_drift_test.dart` validates the six **templates**, but no code parses a produced report. For the report itself, the format-enforcer pass (`references/report-format-enforcer.md`) is still the only safety net, so its instructions must be exactly right |


---

## 12. Automated check — the templates are not hand-verified any more

`cli/test/src/content/report_template_drift_test.dart` reads all six
`skills/<stack>-health-audit/assets/report-template.md` files and fails the build on
divergence. It enforces the invariants in this document: the 15-section numbering, the canonical
section-name sequence (tolerating only the documented stack-variable slots), the two trailing
unnumbered blocks, the single `> **Test Coverage:**` line, the Testing coverage fields, the
`### Harness Coverage` rename, the byte-identical scoring legend, the absence of a `Weight` column
in the scorecard, and that each skill's Scoring Methodology weights match its family and sum to 1.00.

If you edit a template, run it:

```bash
cd cli && dart test test/src/content/report_template_drift_test.dart
```

A failure names the offending skill and what diverged. If the test and this document ever disagree,
**one of them is a bug** — decide which, and fix that one. Do not weaken the test to make an edit pass.

---

## 13. Worked examples

Two fully filled-in example reports live in `docs/examples/`, one per weight family:

| File | Stack | Weight family |
|------|-------|---------------|
| `sample-flutter-health-audit-report.md` | Flutter (slot A + slot B, no Performance) | A |
| `sample-react-health-audit-report.md` | React (slot A, Performance, no slot B) | B |

Both audit **fictional projects that do not exist**, and every score, percentage, path and finding
in them is invented. They exist to show what a conforming, fully-populated report looks like — in
particular how the Overall Score reconciles against the section scores and weights, and how the
coverage figure stays consistent between the scorecard and the Testing section. Each file opens with
an admonition saying so. Never cite them as audit results.
