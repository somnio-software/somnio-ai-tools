# Architecture Scoring

> Apply the fixed four-contour rubric to the evidence of steps 1 to 4 for
> the codebase's effective profile, map the result to a maturity band, read
> the five quality criteria, judge every rule and anti-pattern, and order
> the remediation plan. This step computes; it does not re-scan the
> repository.

---

Goal: Turn the step artifacts into a defensible score out of 100, a band,
and a plan whose order follows the standard and fits the profile.

INPUT (artifacts in `reports/.artifacts/architecture-audit/`):
- The step artifacts matching `step_*_module-map.md`,
  `step_*_dependency-graph.md`, `step_*_composition-analysis.md` and
  `step_*_control-analysis.md`.
- `data/metrics.json` (written by step 2). Read no other file under
  `data/`; the TSV files there are raw data for the earlier steps.
- `architecture-standard.md`, in the same directory as this file. Every
  metric ID (M1–M11), rule (R1–R10), anti-pattern (AP1–AP5), profile and
  driver below is defined there.

READ-ONLY DISCIPLINE:
- Do not modify or re-read the audited repository; work from the
  artifacts. A fact they do not settle is Not measured.

## THREE OUTCOMES PER CHECK

Every check ends in exactly one of these:

- **Scored**: points awarded from the table, with a one-line justification
  citing the artifact value or file.
- **Not applicable (N/A)**: the check's N/A condition below holds for this
  profile or stack. The check drops out of both the points earned and the
  points possible.
- **Not measured**: the check applies, but its evidence is missing (an
  artifact is absent, a metric is `null` where it should not be,
  extraction failed). Award 0 and write "Not measured: <reason>". Never
  estimate a value the artifacts do not hold, and never read a missing
  value as Healthy.

Read the effective profile (`profile.effective` in `metrics.json`) and the
drivers from the step 1 artifact before awarding anything.

## THE RUBRIC (4 contours × 25 points before N/A)

### Structural contour — 25

| Check | Points | Award | N/A when |
|---|---|---|---|
| **S1. Boundary form fits the profile** (R10, AP5) | 8 | Base by profile. **Compact**: 8. **Standard**: features each map to their own directory or directories → 8; some feature code lives in layer-wide or shared directories → 4; fewer than two features can be told apart → 0. **Large**: M10 ≥ 90 % → 8; ≥ 50 % → 4; < 50 % → 0. Then subtract 4 if code a driver concerns does not meet the driver's requirement (R10), and 4 if AP5 is Confirmed. Floor at 0. | never |
| **S2. Feature size balance** (M7, AP4) | 6 | M7 ≤ 2 → 6; ≤ 3 → 3; > 3 → 0. | fewer than four features |
| **S3. File size** (M8) | 5 | M8 = 0 → 5; ≤ 1 % → 3; > 1 % → 0. | never |
| **S4. Lower roles point down** (R7, AP1) | 6 | Count the sites of violation kinds whose `rule` is R7 or R3 (`contract->feature`) in `metrics.json`. Judge AP1 here on its signals other than "depends on a feature", which these sites already count. 0 sites and no such AP1 signal → 6; 1–5 sites, or one such signal → 3; more sites, or two or more such signals → 0. | never |

### Integration contour — 25

| Check | Points | Award | N/A when |
|---|---|---|---|
| **I1. Feature isolation** (R1, M1) | 7 | M1 = 0 → 7; ≤ 1 → 4; > 1 → 0. In the Standard and Large profiles, fewer than two features → 0, because isolation cannot be shown. | Compact profile with fewer than two features |
| **I2. Acyclic graph** (R2, M2) | 6 | `largestCycle` 0 → 6; 2–3 → 3; ≥ 4 → 0. Cycles are counted over allowed edges only (`cycles`, not `cyclesAllEdges`). | fewer than three modules |
| **I3. Public surfaces** (R6, M3) | 4 | M3 = 0 % → 4; ≤ 5 % → 2; > 5 % → 0. When `uncheckedEdgeShare` is above 50 %, or `deepEdgeShare` is `null` while allowed cross-module edges exist → Not measured (0). | Compact profile; no allowed cross-module edges |
| **I4. Navigation contracts** (R3, AP3) | 4 | Sites = route string literals passed to navigation calls outside contract modules. **Compact**: route names or paths are declared in one contract file and there are 0 sites → 4; 1–5 sites → 2; no such file, or more sites → 0. **Standard and Large**: cross-feature navigation goes through contract identifiers and there are 0 sites → 4; contracts exist and 1–5 sites remain → 2; no contracts, or more sites → 0. A feature importing another feature's screen is already counted by I1; do not count it here. | no navigation between features (a backend, a single-flow app); fewer than two features |
| **I5. Layering and containment** (R8) | 4 | R8 sites from step 3: each file-level edge against the layer direction, plus each (module, package) pair in which the module imports a vendor SDK (as R8 defines it), an HTTP client or a platform API (as R8 defines them) from code other than the composition root, a foundation module, a global-service implementation or a data layer (a feature's own, or a shared-domain repository module). 0 → 4; 1–5 → 2; more → 0. | never |

### Composition contour — 25

| Check | Points | Award | N/A when |
|---|---|---|---|
| **C1. Substitutable wiring** (R4) | 8 | Count the R4 violation sites from step 3, in any module other than the composition root: constructing another module's implementation (not a default the root or a test can replace), reaching another module's static singleton, looking up another module's implementation type where the root binds an interface for it, registering another module's bindings. Framework-native injection that the root and tests can override is not a violation, and neither is a lookup of what the root binds through a locator or scope it configures (get_it, `provider` or `flutter_bloc`'s `context.read`, Riverpod's `ref`). 0 sites → 8; 1–5 → 4; more, or no injection mechanism at all with features constructing their own collaborators → 0. | never |
| **C2. Root holds composition only** (R5) | 7 | Sites = non-composition files inside the root (product logic, or shared widgets, localisation, assets or services meant for other modules, including code step 1 split out of the root's directories, counted here once and not again under AP1; configuration only the root uses to start the application is composition) + imports of the root from outside it, one per importing file and imported root file (the `*->root` sites in `metrics.json`), leaving out files already counted as split out. 0 → 7; 1–5 → 3; more → 0. | never |
| **C3. Route assembly** (R4) | 5 | The route tree (or HTTP route registration) is assembled in the root, from per-feature groups or directly, and no feature assembles another's routes → 5; central assembly, but 1–2 features assemble another's routes → 2; no central assembly, or more → 0. | the framework derives routes from the file system; the product has a single route |
| **C4. Proportionate root** (AP2) | 5 | Count the AP2 signals from step 3: M9 in Risk; a handwritten wiring file over 500 lines; one handwritten wiring file registering the bindings of more than five features. Generated wiring is left out. None → 5; one → 2; two or three → 0. | never |

### Control contour — 25

| Check | Points | Award | N/A when |
|---|---|---|---|
| **K1. Written standard** | 5 | A module map and dependency rules are written and match the code → 5; only one, or stale → 2; neither → 0. **Large** profile: if an owner is not declared for every module (M11 below 100 %), cap at 2. | never |
| **K2. Mechanical enforcement** (R9, M6) | 10 | Required classes are the profile's classes (standard section 2) that the module graph can break: R1 with at least two features, R2 with at least three modules, R6 when a module declares a public surface, R7 when a contract, shared, global-service or foundation module exists, R5 and R8 whenever the profile lists them. Enforced = 1 per class, 0.5 per class with partial coverage (step 4). Ratio = enforced ÷ required: 1 → 10; ≥ 0.5 → 6; > 0 → 3; 0 → 0. | no class is required (Compact profile with fewer than two features and fewer than three modules) |
| **K3. Debt ratchet** (R9) | 5 | For each class rated enforced or partial that has existing violations inside the modules its check covers (step 4): all of them are held in a baseline that fails on growth and fails on or prunes stale entries → 5; a baseline exists but misses growth or staleness → 2; violations are silenced ad hoc (ignore comments, a disabled rule, an allowlist nothing shrinks), or neither held nor silenced → 0. | no class rated enforced or partial, required or not, has existing violations inside the modules its check covers, including when nothing is enforced |
| **K4. Local feedback** | 5 | At least one enforcing check also runs before code leaves the machine (a Git hook) or shows as an error in the editor (an analyzer or lint rule at error severity) → 5; otherwise → 0. | Compact profile |

## COMPUTATION (execute before writing anything)

Step A. Decide every check's outcome (scored, N/A or not measured) and
award it, with a one-line justification citing the artifact value or file.
Only the condition in a check's *N/A when* column makes it N/A, and only
for the profile that column names; a check whose column says *never* is
scored or not measured.

Step B. For each contour, *earned* is the sum of its scored and not-measured
checks, and *possible* is the sum of the maxima of its checks that are not
N/A. Show each contour as `earned / possible`.

Step C. **Total** = round(100 × Σ earned ÷ Σ possible), over all four
contours, rounding halves up (62.5 → 63). With no N/A check, possible is
100 and the Total is the plain sum.

**Enforcement caps.** The Total is capped by K2:
- K2 earns 0 (scored 0 or not measured): at most 64. A codebase that
  enforces none of its required rule classes is at most Partially
  modular, however few checks apply to it.
- K2 earns 3 or 6, or is N/A because no class is required yet: at most 84.
  Governed modular means tools hold every required class, which takes
  K2 = 10.
- K2 earns 10: no cap.

A cap applies when it lowers the Total; then state the uncapped value and
the cap's reason next to the capped one.

Step D. Map the Total to a maturity band. The band describes fitness for
the effective profile:
- **0–39 — Monolithic**: boundaries are conventions at best; the codebase
  behaves as one unit.
- **40–64 — Partially modular**: some modules are real, but features are
  coupled or the rules are not enforced.
- **65–84 — Modular**: modules, roles and dependencies mostly follow the
  standard for this profile; gaps remain in enforcement or in a contour.
- **85–100 — Governed modular**: the standard holds for this profile and
  tools enforce every rule class it requires (K2 = 10).

Step E. **Quality criteria reading**: for every metric M1–M11 in standard
section 7, state the value and Healthy, Watch, Risk, N/A or Not measured.
A criterion's status is the worst status among its applicable metrics; a
criterion with no applicable metric is N/A. Change locality (M4, M5) is
read, not scored; when a previous audit's history exists, state the trend.

Step F. **Rule compliance**: for each of R1–R10, state **Met** (nothing
breaks it), **Partial** (only a SHOULD clause is broken), **Violated** (a
MUST clause is broken at any site) or **Not applicable** (the standard
says when), with the evidence, and whether it is enforced (from step 4:
Yes, Partial or No for the rule classes R1, R2 and R5–R8, and "—" for R3,
R4, R9 and R10, which step 4 does not rate). Map violation kinds to rules by the `rule` field in
`metrics.json`. When no rule class is required, R9 is Not applicable; say
which class becomes required first (R1 with a second feature, R2 with a
third module).

Step G. **Anti-patterns**: for each of AP1–AP5, list its signals from steps
1 to 3. Two or more → **Confirmed**; one → **Warning**; none → **Not
found**. A signal that does not apply (the AP4 size signal with fewer than
four features, its fan-out signal with one) is left out, and an
anti-pattern the standard calls not applicable (AP3 with fewer than two
features) is **Not applicable**, whatever step 3 recorded.

Step H. **Remediation plan**: at most eight actions, each restoring a rule
or recovering points; never pad it, and with nothing to restore say so in
one line; with more than eight, merge actions of one stage. Order them by the stages
of standard section 9. Skip a stage the profile does not call for: never
recommend physical feature modules for a Compact or Standard codebase
unless a module driver applies (standard section 2), and recommend
merging modules when AP5 is Confirmed. For D3 code deferred by library or
chunk, the action is removing its eager imports, in stage 5. Within a stage, order by points recovered. Each action names
the modules or files involved, the rule it restores, the checks and points
it recovers, and the stage.

## ARTIFACT SAVE (mandatory)

Write `reports/.artifacts/architecture-audit/step_05_architecture-scoring.md`:
- **Profile**: measured and effective, the inputs, any override with its
  reason, and the drivers that apply.
- **Per-check table**: contour · check · outcome · points awarded / max ·
  justification with the evidence.
- **Contour scores** as `earned / possible`, and the **Total**:
  `[total]/100`, with the uncapped value and the reason when an
  enforcement cap lowers it.
- **Maturity band** with a one-sentence reading that names the profile.
- **Quality criteria reading** (Step E).
- **Rule compliance** (Step F).
- **Anti-patterns** (Step G).
- **Remediation plan** (Step H).

If the runner gave you a different artifact path for this step, write the
artifact there instead.
