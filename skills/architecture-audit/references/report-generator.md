# Architecture Audit Report Generator

> Synthesize the module map, dependency graph, composition, control and
> scoring artifacts into the Architecture Audit report: the profile, the
> contour scores, the total and band, the quality criteria reading, rule
> compliance, anti-patterns, the module map and an ordered remediation
> plan. MUST follow the exact section structure from
> `assets/report-template.md`. Every section is MANDATORY - do not merge,
> skip, or rename sections.

---

Goal: Generate the final Architecture Audit report from the step artifacts,
using the standardized format in `assets/report-template.md`.

READ-ONLY DISCIPLINE:
- Do NOT re-scan or modify the audited repository. Operate on artifact
  files. Your only writes in this step (step 5 has already saved its
  artifact) are `reports/<YYYY-MM-DD>-<project>-architecture-audit.md`,
  `reports/<YYYY-MM-DD>-<project>-architecture-audit.json` and
  `reports/.history/last_architecture_scores.json`.

STEP ARTIFACT INTEGRATION:
Read these artifacts for this run under `reports/.artifacts/architecture-audit/`.
Of the `data/` directory read only `data/metrics.json`: the TSV files and
the script there are raw inputs of the earlier steps, and can be large.
- `step_*_module-map.md` - stack, documentation found, module table, mixed
  modules, drivers, ownership, profile override; drives Section 7.
- `step_*_dependency-graph.md` and `data/metrics.json` - profile,
  coupling, violations, cycles, sizes, change locality, AP1, AP4 and AP5
  signals; drive Sections 1, 2, 3 and 4.
- `step_*_composition-analysis.md` - implementation selection, root,
  routes, navigation, layering, AP2 and AP3 signals; drives Section 3.
- `step_*_control-analysis.md` - written rules, enforcement table,
  baselines, local feedback; drives Sections 3 and 5.
- `step_*_architecture-scoring.md` - per-check outcomes and points,
  contour scores, total, band, criteria reading, rule compliance,
  anti-patterns, remediation plan; drives Sections 1, 3, 4, 5, 6 and 8.

If the scoring artifact is absent, you cannot produce a valid report: run
the scoring instructions (`architecture-scoring.md`, in the same directory
as this file) first. If an earlier artifact is absent, the scoring artifact
already records which checks scored 0 as "Not measured"; carry that wording
into the report. Never fill a missing value with an estimate.

MANDATORY REPORT STRUCTURE (10 sections):
1. Architecture Scoring Breakdown (profile + four contours + Total + Maturity Band + legend)
2. Executive Summary (total, band and profile reading, key figures, up to three first actions)
3. Contour Detail (one block per contour with its checks)
4. Quality Criteria Reading
5. Rule Compliance (R1-R10)
6. Anti-pattern Findings (AP1-AP5)
7. Module Map
8. Remediation Plan
9. Appendix: Evidence Index
10. Report Metadata

## SCORING SYSTEM (reproduce exactly from references/architecture-scoring.md)

Four contours of 25 points each before N/A:
- Structural: S1 boundary form fits the profile 8, S2 feature size balance
  6, S3 file size 5, S4 lower roles point down 6.
- Integration: I1 feature isolation 7, I2 acyclic graph 6, I3 public
  surfaces 4, I4 navigation contracts 4, I5 layering and containment 4.
- Composition: C1 substitutable wiring 8, C2 root holds composition only 7,
  C3 route assembly 5, C4 proportionate root 5.
- Control: K1 written standard 5, K2 mechanical enforcement 10, K3 debt
  ratchet 5, K4 local feedback 5.

A check is scored, N/A (it leaves both earned and possible points), or not
measured (0 points, still possible). Each contour shows
`earned / possible`. Total = round(100 × Σ earned ÷ Σ possible), rounding
halves up. When K2 earns 0, the Total is capped at 64; when K2 earns 3
or 6, or is N/A because no rule class is required yet, at 84. When a cap
lowers the Total, the uncapped value and the cap's reason are shown
beside it.

Maturity Band mapping:
- 0-39 = Monolithic
- 40-64 = Partially modular
- 65-84 = Modular
- 85-100 = Governed modular

## SECTION FORMAT REQUIREMENTS

### Section 1 - Architecture Scoring Breakdown

- A **Profile** line first: `**Profile:** [effective] (measured:
  [measured])`, with the override reason when there is one, then
  `**Drivers:**` and the drivers that apply, or "none".
- Table with exactly four contour rows (Structural, Integration,
  Composition, Control), each `[earned]/[possible]`, then a **Total Score**
  row `[total]/100`, followed by `(capped from [N]: [reason])` when an
  enforcement cap lowers the Total. The reason is "no required rule class
  is enforced" for the 64 cap, and "not every required rule class is
  enforced" or "no rule class is required yet" for the 84 cap.
- Followed by a **Maturity Band: [band]** line, the band legend, and the
  sentence "Scores are relative to the profile; scores of different
  profiles are not comparable."
- This is the first thing a reader sees; it must be complete on its own.

### Section 2 - Executive Summary

- Must include `**Total Score:** [total]/100 ([band])` and the effective
  profile.
- One paragraph on what the score means for this codebase at its profile.
- **Key Figures** from `data/metrics.json`: files, handwritten lines,
  modules, features and their physical share; feature-to-feature edges and
  per feature; largest cycle over allowed edges; root share; largest
  feature against the mean.
- Up to the first three actions of the remediation plan, one line each,
  or the plan's one line when it has no action.
- If `reports/.history/last_architecture_scores.json` exists, add
  `Previous: [N]/100, Change: [+/-M] ([improving|declining|unchanged])`,
  and say when the previous audit used a different profile.

### Section 3 - Contour Detail

One block per contour, in the fixed order Structural, Integration,
Composition, Control. Each block has:
- the heading `### [Contour] - [earned]/[possible]`;
- a table with one row per check of that contour: check ID and name,
  `[awarded]/[max]`, `N/A` with its condition, or `0/[max] Not measured`,
  and the evidence in one line (metric value or `file:line`);
- **Findings**: bullets on what the evidence shows, citing files.

### Section 4 - Quality Criteria Reading

One row per metric M1-M11 of standard section 7: criterion, metric, value,
and Healthy / Watch / Risk / N/A / Not measured; then each criterion's
status. Change locality carries its trend when a previous audit exists.

### Section 5 - Rule Compliance

One row per rule R1-R10: status (Met / Partial / Violated / Not applicable),
enforced (Yes / Partial / No, or "—" for R3, R4, R9 and R10), and evidence with counts and an example
site.

### Section 6 - Anti-pattern Findings

One row per anti-pattern AP1-AP5: verdict (Confirmed / Warning / Not found
/ Not applicable) and the signals found, naming the modules.

### Section 7 - Module Map

- Stack, the audited application's path, the profile inputs, the drivers
  and the code each concerns.
- One row per module: name, role, physical, lines, and notes (mixed roles,
  notable fan-in or fan-out). For more than 40 modules, list every
  non-feature module and the ten largest features, then state how many
  features were omitted.

### Section 8 - Remediation Plan

Reproduce the plan from the scoring artifact: at most eight actions in
stage order, or its one line saying nothing needs restoring, each with the modules or files, stage, rule restored, and
checks and points recovered.

### Section 9 - Appendix: Evidence Index

Render as `## 9. Appendix: Evidence Index`, immediately before Section 10.
One labelled group per evidence source, in this order, each with one or more
bullets citing concrete evidence (file path, count, `file:line`):
- **Module map**
- **Dependency graph**
- **Composition**
- **Control**
- **Change locality**

A group with no evidence still appears, with the single bullet `Not found`.
Never leave a group blank and never fabricate a path.

### Section 10 - Report Metadata

Scan date, project path, profile, scope (production code; tests are not
audited), modules mapped (and features), total score, band, generated-by
line, skill name, and the Somnio AI Tools URL.

## FORMATTING RULES

- Follow `assets/report-template.md` structure exactly.
- Use Markdown: `#` headers, tables, `- ` bullets, `1.` numbered lists, and
  `backtick` file paths.
- Every score references evidence from the artifacts.
- The report starts with the `# Architecture Audit Report` title and nothing
  before it.

## VALIDATION CHECKLIST

Before finalizing, verify:
- All 10 sections are present and in order.
- Section 1 has the profile line, the four contour rows, the Total, the
  band line, the legend and the comparability sentence.
- No check exceeds its maximum; each contour's earned and possible points
  equal the sums of its checks; the Total equals
  round(100 × Σ earned ÷ Σ possible) with halves rounded up, capped at 64
  when K2 earns 0 and at 84 when K2 earns 3 or 6 or is N/A.
- Every N/A is one the scoring reference allows for the effective profile.
- The Total in Section 1 matches Section 2 and the JSON export.
- The band matches the Total's range.
- Section 5 has all ten rules; Section 6 has all five anti-patterns.
- Section 8 lists at most eight actions in stage order, none padded, and recommends
  physical feature modules only in the Large profile or where a module
  driver applies.
- Section 9 sits immediately before Section 10 with all five groups.
- The metadata block from SKILL.md is the last block of the report.

## JSON EXPORT (mandatory)

After writing the report, write `reports/<YYYY-MM-DD>-<project>-architecture-audit.json`:

    {
      "totalScore": [integer 0-100, after the enforcement cap],
      "uncappedScore": [integer 0-100, or null when no cap lowers the Total],
      "band": "[Monolithic|Partially modular|Modular|Governed modular]",
      "profile": {
        "measured": "[compact|standard|large]",
        "effective": "[compact|standard|large]",
        "drivers": ["[D1-D4 that apply, as step 5 decided]", "..."]
      },
      "contours": {
        "structural": { "earned": [number], "possible": [number] },
        "integration": { "earned": [number], "possible": [number] },
        "composition": { "earned": [number], "possible": [number] },
        "control": { "earned": [number], "possible": [number] }
      },
      "checks": {
        "S1": [number earned, 0 when not measured, or the string "N/A"], "S2": [...], "S3": [...], "S4": [...],
        "I1": [...], "I2": [...], "I3": [...], "I4": [...], "I5": [...],
        "C1": [...], "C2": [...], "C3": [...], "C4": [...],
        "K1": [...], "K2": [...], "K3": [...], "K4": [...]
      },
      "metrics": {
        "srcLines": [integer],
        "features": [integer],
        "featureEdges": [integer],
        "largestCycle": [integer],
        "deepEdgeShare": [number or null],
        "rootShare": [number or null],
        "largestFeatureRatioToMean": [number or null],
        "physicalFeatureShare": [number or null],
        "meanFeaturesPerChange": [number or null]
      },
      "antiPatterns": {
        "AP1": "[Confirmed|Warning|Not found|Not applicable]",
        "AP2": "[...]", "AP3": "[...]", "AP4": "[...]", "AP5": "[...]"
      },
      "remediation": ["[action 1]", "[action 2]", "..."],
      "timestamp": "[ISO8601 datetime]",
      "projectPath": "[absolute path of the audited repository]"
    }

Metric values are copied from `data/metrics.json` as they are there,
including for a metric whose check is N/A; `null` only where it is `null`
there.

Run before saving: `mkdir -p reports`

## SCORE HISTORY (mandatory, after report + JSON)

Write `reports/.history/last_architecture_scores.json`:

    { "overall": [total], "timestamp": "[ISO8601]",
      "profile": "[effective profile]",
      "contours": { "structural": { "earned": N, "possible": N },
        "integration": {...}, "composition": {...}, "control": {...} },
      "metrics": { "featureEdges": N, "largestCycle": N,
        "rootShare": N, "physicalFeatureShare": N,
        "meanFeaturesPerChange": N },
      "band": "[band]" }

Run: `mkdir -p reports/.history`
