# Dependency Graph

> Extract every source-level dependency between modules with the fixed
> metrics script, and record the profile, violations, cycles, deep imports,
> module sizes and change locality the scoring step needs.

---

Goal: Turn the module map into numbers: the codebase's profile, who depends
on whom, which edges the standard forbids, where the cycles are, how large
each module is, and how local recent changes have been. Every number in the
final report traces back to `data/metrics.json` written here.

INPUT (artifacts in `reports/.artifacts/architecture-audit/`):
- `data/graph_metrics.py`, `data/files.tsv`, `data/inventory.json`,
  `data/module_map.tsv`, and the step 1 artifact (`step_*_module-map.md`).
  If any is missing, re-run step 1's instructions first (`module-map.md`,
  in the same directory as this file); never invent a module map.
- `architecture-standard.md`, in the same directory as this file: sections
  2 (profile), 4 (allowed dependencies), 6 (anti-pattern signals) and 7
  (metrics).

READ-ONLY DISCIPLINE:
- Never modify the audited repository. The script only reads it (including
  read-only `git log`) and writes under
  `reports/.artifacts/architecture-audit/data/`.

## 1. Run the script

```bash
python3 reports/.artifacts/architecture-audit/data/graph_metrics.py metrics \
  --root . --dir reports/.artifacts/architecture-audit/data --lang <lang> \
  [--driver D1 ...] [--profile compact|standard|large]
```

- Pass one `--driver` per driver step 1 found to apply (the script
  records them under `profile.drivers`; they change no number), and
  `--profile` only when step 1 recorded an operator override.
- Do not edit the script: the thresholds assume exactly its definitions.
- For `--lang none` (any other stack), first write `data/edges.in.tsv`
  yourself, one edge per line: `<source file>\t<target file>\t<line>`,
  both paths repo-relative and present in `files.tsv`, using the language's
  import syntax (`grep -n` over `files.tsv`). The script reads that file
  instead of extracting.

What the script does: it extracts import, export, `require`,
`from ... import` and conditional-import edges for Dart, TypeScript or
JavaScript and Python; it resolves `package:` URIs, tsconfig path aliases
(nearest config, following `extends`), `#` subpath imports from the
nearest `package.json` (after the tsconfig aliases), workspace package
names and relative paths; it maps every edge to modules by the longest module path;
and it flags edges the matrix forbids. It also finds cycles over the
allowed edges, sums handwritten lines per unique module, and measures change
locality from `git log` on the first-parent line. Besides `edges.tsv` it
writes `module_edges.tsv`: every resolved internal edge with its source
and target modules and roles and a status (`internal`, `allowed`, `deep`,
`unchecked`, the rule it violates, or `unmapped` when a file matches no
module row, which the map must fix), so later steps never map files to
modules by hand.

## 2. Check the output before going on

- Exit 3 means the script text was altered: extract it again (step 1).
  Any other non-zero exit means the input is wrong (a module-map error, or
  no import between the source files resolved although some looked
  internal). Read the message, fix the cause (the map, the language, the
  source roots), and run again.
- A `warning` in `metrics.json` says the graph has no edges at all and no
  import was left unresolved: the files import only packages. Confirm it by
  opening two or three files, and check `externalImportsByModule` for an
  application path alias read as a package (`@/…`, `~/…`, the app's own
  package name); if there is one, fix the alias input and run again. A
  confirmed empty graph is a result, not a failure.
- `totals.unmappedFiles` must be 0. If not, fix `module_map.tsv` (step 1
  rules) and run again.
- `totals.unresolvedInternal` should be small next to `edgesExtracted`.
  Many unresolved relative or alias imports mean resolution failed; look at
  `unresolvedExamples`, fix what the input can fix, and record the rest as
  a limitation.
- `totals.parseErrorFiles` should be 0. A file the parser cannot read
  loses all its imports; for Python this usually means syntax newer than
  the interpreter running the script, so run it under a newer `python3.x`.
  If errors remain, list the files (`parseErrors` shows the first 20) and
  read their internal imports by hand; when one of them is a cross-module
  edge, the checks it would change (S4, I1, I2, I3, C2) are not measured.
- Every numeric `changeLocality` field is `null`, with a `reason`, when
  there is no usable history (no repository, a shallow clone, a git error
  or too old a git, or no qualifying change). A history failure never
  stops the script. Change locality is then not measured.
- If changes land as plain commits on the first-parent line (pull
  requests merged by rebase, or direct commits: no merge commits and no
  squash subjects naming a pull request), say so: every such commit then
  counts as a change (M4, M5).

## 3. Read the results

From `data/metrics.json`, record in the artifact. Shares there are
percentages (0 to 100) and ratios are plain numbers, both unrounded:
compare them with a threshold as they are, and round only when you write
them (one decimal).

- **Profile**: `profile.measured`, `profile.effective`, the inputs and the
  drivers.
- **Structural coupling**: `featureEdges`, `featureEdgesPerFeature`,
  `featureCycles` (the largest in full), `cycles` and `largestCycle`
  (cycles over allowed edges; say whether one runs through the root;
  `cyclesAllEdges`, over every edge, is context only, because forbidden
  edges are already counted as violations),
  `mutualFeaturePairs`, `deepEdges`, `deepEdgeShare` and
  `uncheckedEdgeShare`.
- **Violations by kind** (`violations`): the rule, the count, the module
  pairs, and up to five example sites (`file:line -> target`) per kind.
- **Fan-out and fan-in**: the top modules of each, counted in distinct
  modules (modules with 0 are left out of the lists). `modules` holds every
  module's role, physical flag, handwritten files and lines, generated
  files, fan-in and fan-out; use it for any per-module figure.
- **Sizes**: `rootShare`, `largestFeature` (with `ratioToMean`),
  `largestSharedModule` (shared, global-service and foundation modules
  only), `physicalFeatureShare`, `filesOver1000` (count and the five
  largest), `filesOver2000`, and `filesOver1000Share`.
- **External and platform imports**: `externalImportsByModule` maps each
  module to the packages it imports, with a file count and an example
  site; `platformImportsByModule` maps it to the platform libraries it
  imports, with a count (Dart `dart:io`, `dart:html`, `dart:ffi` and the
  JS interop libraries; Node built-ins that reach the file system, network,
  processes or the host, as `node:<name>`; Python standard-library modules
  for files, storage, sockets, HTTP, processes and native code). List the feature
  and shared modules that import packages likely to be vendor SDKs, HTTP
  clients or platform APIs; step 3 judges them against R8.
- **Change locality**: `meanFeaturesPerChange`,
  `changesTouching3PlusFeatures` (a share), the qualifying `changes`,
  `droppedOversized`, `changesWithoutFeatures` and `topCoChangedPairs`.

Then evaluate, with the evidence that decides each:
- **Metrics M1, M2, M3, M4, M5, M7, M8, M9, M10** (standard section 7):
  each Healthy, Watch, Risk, not applicable (with the condition that makes
  it so) or not measured.
- **AP1 signals** (shared module as a warehouse): `largestSharedModule`
  over 50 %; mixed shared, global-service or foundation modules from step
  1 (root relocations are counted under C2, not here); contract modules
  holding implementations; a shared module with the highest fan-in whose
  name states no purpose; shared modules with an edge into a feature.
  Features, including a Compact codebase mapped as one `app` feature, are
  never AP1 evidence.
- **AP4 signals** (feature monolith): `ratioToMean` over 3 (four or more
  features only); that feature also has the highest fan-out among features
  (from `modules`);
  a file in it over 2,000 lines. Also open the largest state holder in
  the largest feature (BLoC, store, view model, controller) and count its
  event or action handlers and injected collaborators. With fewer than
  four features the size signal is left out, and with one feature the
  fan-out signal too; the others still apply.
- **AP5 signals** (premature modularisation): the profile is Compact and
  features are physical modules that no module driver (standard section
  2) calls for; more than 30 % of physical
  modules, contract modules excepted, hold fewer than three handwritten
  files and have a single dependent module (`files` and `fanIn` in
  `modules`).

## ARTIFACT SAVE (mandatory)

Keep `edges.tsv`, `module_edges.tsv` and `metrics.json` in
`reports/.artifacts/architecture-audit/data/`, and write
`reports/.artifacts/architecture-audit/step_02_dependency-graph.md` with
the sections of part 3: profile, metrics with their values and status,
violations with example sites, cycles, fan-in and fan-out, sizes, external
and platform imports, change locality, the AP1, AP4 and AP5 signals, and
any extraction limitation you observed.

If the runner gave you a different artifact path for this step, write the
artifact there instead and keep the data files where listed above.
