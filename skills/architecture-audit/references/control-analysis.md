# Control Analysis

> Find out which of the standard's rules are written down and which are
> enforced by a tool that fails on a new violation, where those tools run,
> and how existing violations are tracked. Covers rule R9.

---

Goal: For each rule class the profile requires, decide whether the codebase
enforces it, by what, over which modules, where it runs, and whether
existing violations are held in a baseline that can only shrink.

INPUT (artifacts in `reports/.artifacts/architecture-audit/`):
- The step 1 to 3 artifacts (`step_*_module-map.md`,
  `step_*_dependency-graph.md`, `step_*_composition-analysis.md`): the
  architecture documentation found, the module map, the profile, and the
  violation counts by rule.
- `architecture-standard.md`, in the same directory as this file: section 2
  (rule classes per profile), rule R9, and the stack notes in section 10.

READ-ONLY DISCIPLINE:
- Never modify the audited repository and never run its checks: running a
  linter or a test suite can write caches or reports into the tree. Read
  configuration and scripts instead.

## 1. Written rules

Using the documentation step 1 found, record for each document:
- whether it contains a **module map** (which modules exist and their roles
  or layers);
- whether it contains **dependency rules** (what may depend on what: a
  matrix, a layering diagram with direction, or explicit "must not import"
  rules);
- whether it is current (yes, partly or no): spot-check two or three
  module or directory names and one dependency rule it states against the
  tree and the graph. When documents contradict each other and none is
  marked as superseded, say so: K1 reads them as stale.

In the Large profile, also record the ownership coverage step 1 found
(M11).

## 2. Enforcement per rule class

The checkable rule classes are **R1** (feature isolation), **R2**
(acyclicity), **R5** (nothing depends on the root), **R6** (public
surface), **R7** (lower roles point down) and **R8** (layering and
containment).

A class is required when the effective profile lists it (standard
section 2) and the module graph can break it:
- R1 with at least two features;
- R2 with at least three modules;
- R6 when a module declares a public surface;
- R7 when a contract, shared, global-service or foundation module exists;
- R5 and R8 whenever the profile lists them.

Take the counts from the step 1 and step 2 artifacts. Assess every
required class; record the others too when a mechanism exists. When no
class is required, say so: K2 is then N/A.

For each class, find any mechanism that fails a build or a CI job when the
rule is broken (branch protection is not visible from the repository, so
a merge check counts only where the repository itself declares it):

- **Build-system boundaries**: physical modules whose manifests do not
  list each other, where the build rejects an undeclared dependency.
  Read standard section 10 first: a Dart pub workspace, a hoisting
  JavaScript package manager or a shared Python environment resolves
  undeclared siblings, so physical packages there count only together with
  a check that rejects such imports. For Dart, that is
  `depend_on_referenced_packages` and `implementation_imports` enabled, not
  suppressed, and failing CI: raised to `error`, or run by `flutter
  analyze` (fatal on infos and warnings by default), or by
  `dart analyze --fatal-infos`. Gradle `api` dependencies and SwiftPM
  without its explicit import check let undeclared imports through as
  well (section 10).
- **Lint and analyser rules**: Dart analyzer plugins (`plugins:` in
  `analysis_options.yaml`), `custom_lint` (only when CI runs
  `dart run custom_lint`), DCM banned imports (only when CI runs DCM),
  `@internal` with `invalid_use_of_internal_member` failing CI (between
  packages only), Kotlin `internal` or Java package-private declarations
  for R6, ESLint
  `import/no-restricted-paths`, `import/no-cycle`,
  `eslint-plugin-boundaries`, Nx `@nx/enforce-module-boundaries`,
  `dependency-cruiser` (`.dependency-cruiser.*`), Python `import-linter`
  (`.importlinter`, `[tool.importlinter]`), `tach`, ArchUnit, Konsist,
  NetArchTest, Go `depguard`.
- **Custom checks**: scripts in CI or hooks that parse imports. Read them
  and state which rule classes they actually check.

For every mechanism record: the rule classes it covers, the file that
configures it, its severity, which modules it covers, and where it runs (CI
workflow and job, required or optional; pre-commit or pre-push hook; editor
only).

Rate each class:
- **enforced**: a violation anywhere in the handwritten modules fails CI on
  pull requests or a required merge check. Where changes land as plain
  commits on the trunk with no pull requests (step 2's merge workflow),
  CI that fails on every push to the trunk counts. Branch protection is
  not visible from the repository: rate from the workflow triggers and do
  not assume a required check;
- **partial**: it does, but only for some modules or packages (it counts
  as half). Record the share of handwritten lines the covered modules
  hold. Judge a check by what escapes it in the modules it scans: when a
  violation of another form passes (it catches one import pattern, or a
  test checks some directory pairs but not others), it rates **no** for
  the class; record it anyway;
- **warn-only**: it reports at a severity CI does not fail on (info or
  warning, unless the CI command is fatal on them, as `flutter analyze` is
  by default), or runs where it cannot block a merge. When CI calls a
  shared template from another repository whose severity cannot be seen,
  take it from the repository's own statements about that job (comments,
  scripts, documentation); with none, rate warn-only and say so;
- **no**: nothing checks it, or only prose states it.

## 3. Existing violations

For each enforced or partial class that has existing violations inside
the modules its check covers (by the `rule` field of the violation kinds
in step 2, the R4 and R8 sites in step 3), find how the check tolerates
them. Violations outside the covered modules are a coverage gap, which K2
already scores; list their count, but they are not held or tolerated by
the check:
- a **baseline or allowlist** file the check reads (path, entry count);
- whether the check fails on growth, and whether it fails on, or
  automatically prunes, entries that no longer occur (a ratchet that can
  only shrink);
- ignore comments, disabled rules or suppressions in source (count them
  with `grep`).

When no enforced or partial class has existing violations inside its
covered modules, write "none to hold": K3 is then not applicable.

## 4. Local feedback

Find whether the enforcing checks also run before code leaves a developer's
machine: Git hooks (`.githooks/`, `.husky/`, `lefthook.yml`,
`.pre-commit-config.yaml`), or analyzer and lint rules that the editor
shows as errors (info and warning severities do not count). A tracked
hook with a documented install step counts even though its activation
cannot be seen; record that it is opt-in. Record the hook or rule and the command it runs.

## ARTIFACT SAVE (mandatory)

Write `reports/.artifacts/architecture-audit/step_04_control-analysis.md`:
- **Written rules**: each document with module map yes/no, dependency rules
  yes/no, current yes/partly/no, and the evidence; ownership coverage in the Large
  profile.
- **Enforcement table**: one row per rule class R1, R2, R5, R6, R7, R8 with
  required (yes/no, and the condition when the profile lists the class but
  the module graph cannot break it), rating (enforced / partial / warn-only /
  no), mechanism, configuring file, modules covered, where it runs.
- **Existing violations**: per enforced class, baseline path and size,
  ratchet behaviour, source suppressions; or "none to hold".
- **Local feedback**: hook or editor check, and what it runs.

If the runner gave you a different artifact path for this step, write the
artifact there instead.
