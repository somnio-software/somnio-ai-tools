# Architecture Audit Report

---

## 1. Architecture Scoring Breakdown

**Profile:** [Compact/Standard/Large] (measured: [Compact/Standard/Large]) - [override reason, or omit] - **Drivers:** [D1, D3, D4 with the code each concerns, or "none"]

| Contour | Score |
|---------|-------|
| Structural (modules, roles, sizes) | [earned]/[possible] |
| Integration (dependencies between modules) | [earned]/[possible] |
| Composition (assembly in the root) | [earned]/[possible] |
| Control (rules written and enforced) | [earned]/[possible] |
| **Total Score** | **[Score]/100** [(capped from [N]: [reason of each cap that applies]) - omit when no cap lowers the Total] |

**Maturity Band:** [Monolithic / Partially modular / Modular / Governed modular]

> **Bands:** Monolithic (0-39) - Partially modular (40-64) - Modular (65-84) - Governed modular (85-100)
>
> Scores are relative to the profile; scores of different profiles are not comparable.

---

## 2. Executive Summary

**Description:** Modular architecture analysis of [Project Name] against the Modular Application Architecture Standard, at the [profile] profile.

**Total Score:** [Score]/100 ([Band])

[One paragraph: what the score means for this codebase at its profile - where its boundaries hold, where they are conventions only, and what that costs.]

**Previous:** [N]/100, **Change:** [+/-M] ([improving/declining/unchanged])
_(omit this line if no history exists; note a profile change since the previous audit)_

**Key Figures:**
- Handwritten code: [N] files, [N] lines; [N] modules, [N] features ([N] % physical)
- Feature-to-feature edges: [N] ([N] per feature); largest cycle over allowed edges: [N] modules
- Composition root share: [N] %; largest feature: [feature], [N]x the mean feature size (or "not applicable" with one feature)

**First Steps (detail in Section 8):**
1. [Action 1 - one line]
2. [Action 2 - one line]
3. [Action 3 - one line]
_(up to three, as many as the plan holds; with no action, the plan's one line instead)_

---

## 3. Contour Detail

> _Contours in fixed order: Structural, Integration, Composition, Control. N/A checks leave the possible points._

### [Contour Name] - [earned]/[possible]

| Check | Score | Evidence |
|-------|-------|----------|
| [ID. Check name] | [awarded]/[max], N/A, or 0/[max] Not measured | [metric value, `file:line`, or the N/A condition, one line] |

**Findings:**
- [What the evidence shows, with `file` references]

_(Repeat this block for all four contours.)_

---

## 4. Quality Criteria Reading

| Criterion | Metric | Value | Status |
|-----------|--------|-------|--------|
| Structural coupling | [M1-M3] | [value] | [Healthy/Watch/Risk/N/A/Not measured] |
| Change locality | [M4-M5] | [value, trend; note a rebase-merge history] | [Status] |
| Manageability | [M6] | [value] | [Status] |
| Maintainability | [M7-M8] | [value] | [Status] |
| Development scalability | [M9-M10] | [value] | [Status] |

_(One row per metric M1-M10 of the standard's section 7; a criterion spans several rows. Then each criterion's status, the worst among its applicable metrics.)_

---

## 5. Rule Compliance

| Rule | Status | Enforced | Evidence |
|------|--------|----------|----------|
| R1. Features do not depend on features | [Met/Partial/Violated/Not applicable] | [Yes/Partial/No; "—" for R3, R4, R9, R10] | [count, example `file:line`] |
| R2. The module graph is acyclic | [Status] | [Enforced] | [evidence] |
| R3. Navigation goes through contracts | [Status] | [Enforced] | [evidence] |
| R4. The root selects implementations | [Status] | [Enforced] | [evidence] |
| R5. The composition root holds composition only | [Status] | [Enforced] | [evidence] |
| R6. Modules are used through their public surface | [Status] | [Enforced] | [evidence] |
| R7. Lower roles point down and stay single-purpose | [Status] | [Enforced] | [evidence] |
| R8. Layers point inward and contain the outside world | [Status] | [Enforced] | [evidence] |
| R9. Rules are enforced mechanically | [Status] | [Enforced] | [evidence] |
| R10. Boundaries become physical when the profile or a driver calls for it | [Status] | [Enforced] | [evidence] |

---

## 6. Anti-pattern Findings

| Anti-pattern | Verdict | Signals |
|--------------|---------|---------|
| AP1. Shared module as a warehouse | [Confirmed/Warning/Not found/Not applicable] | [signals found, with modules] |
| AP2. Composition monolith | [Verdict] | [signals] |
| AP3. Hidden navigation coupling | [Verdict] | [signals] |
| AP4. Feature monolith | [Verdict] | [signals] |
| AP5. Premature modularisation | [Verdict] | [signals] |

---

## 7. Module Map

**Stack:** [languages, workspace tooling] - **Application:** `[path]`

**Profile inputs:** [N] handwritten lines, [N] features - **Drivers:** [each driver and the code it concerns, or "none"]

| Module | Role | Physical | Lines | Notes |
|--------|------|----------|-------|-------|
| [name] | [role] | [yes/no] | [N] | [mixed roles, fan-in/fan-out, or blank] |

---

## 8. Remediation Plan

> _Ordered by the standard's remediation stages: rules and control, navigation contracts, empty the root, break cycles, physical boundaries where the profile or a driver calls for them, split monoliths._

1. **[Action - modules or files involved]**
   - Stage: [stage]
   - Restores: [rule]
   - Recovers: [checks] (+[N] points, or a range when a threshold decides it)

_(At most eight actions, none padded; with nothing to restore, one line saying so.)_

---

## 9. Appendix: Evidence Index

**Module map:**
- [`data/module_map.tsv` summary, mixed modules, drivers, or "Not found"]

**Dependency graph:**
- [edge counts, cycles, deep-edge examples with `file:line`]

**Composition:**
- [wiring files, router assembly, contract module paths]

**Control:**
- [documents, enforcing configs and CI jobs, baselines, hooks]

**Change locality:**
- [changes read, mean features per change, or "Not measured"]

---

## 10. Report Metadata

| Field | Value |
|-------|-------|
| Scan date | [Date] |
| Project path | [absolute path of the audited repository] |
| Profile | [effective] (measured: [measured]) |
| Scope | Production code; tests are not audited |
| Modules mapped | [N] ([N] features) |
| Total score | [Score]/100 |
| Maturity band | [Band] |
| Generated by | Somnio CLI v3.3.2 |
| Skill | architecture-audit |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
