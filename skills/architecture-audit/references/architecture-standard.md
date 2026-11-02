# Modular Application Architecture Standard

> The normative standard the architecture audit measures against: project
> profiles, module roles, the allowed-dependency matrix, ten rules, five
> anti-patterns, the metrics with their thresholds, and the order in which a
> codebase is brought into line. Every audit step reads this file; it is
> reference material, not a step of its own.

---

## 1. Scope and terms

This standard applies to an application codebase that ships a product built
from several capabilities: a mobile or web client, a desktop app, or a
backend organised by business capability. It does not apply to a library or
SDK repository with no application in it. It is stack-neutral; section 10
and the audit's measurement steps say how each term maps onto a stack.

The key words MUST, MUST NOT, SHOULD and MAY are used as in RFC 2119.

- **Module**: a unit of code with one purpose and a public surface. It is
  **physical** when the build system knows its boundary (a package,
  library, workspace member or project with its own manifest), and
  **logical** when the boundary is a directory convention. A logical module
  MAY span several directories, for example one feature folder under each
  layer of a layer-first tree.
- **Feature**: one user-facing capability — a flow of one or more screens,
  or a backend domain module — together with the state, domain and data
  code only it uses. A screen with its view model is part of a feature,
  not a feature of its own.
- **Public surface**: the files a module offers to others: its barrel,
  index, declared `exports`, or the non-`src/` part of a package. Everything
  else is internal.
- **Edge**: a source-level dependency from a file in one module to a file in
  another (an import, export, `require`, `from ... import`, or a
  conditional import). Type-only imports are edges. Rules and module-level
  metrics count distinct module pairs; site counts and the deep-edge share
  count file-level edges.
- **Contract**: an identifier, interface or value type that one module uses
  and another implements or binds, so that neither depends on the other. It
  lives in a contract module (section 3).
- **Handwritten code**: source a person edits. Generated files (code
  generator output, localisation output, platform registrants) are excluded
  from every size metric, but their edges count: generated wiring and route
  files are real compile-time dependencies. Build output and vendored code
  are excluded entirely.
- Tests are out of scope: the graph covers production code only, and the
  report says so. A test that reaches into another module's internals is
  real coupling the audit does not see.

## 2. Project profile

Modularity has a cost: manifests, wiring, ceremony and build configuration.
The standard asks each codebase for the structure its size and team
justify, no more. Every audit first measures the codebase's **profile**, and
the profile decides which expectations apply (table below) and which checks
are scored.

| Profile | Measured when |
|---|---|
| **Compact** | under 20,000 handwritten lines **and** at most 8 features **and** at most 3 peak monthly contributors |
| **Large** | at least 80,000 handwritten lines **or** at least 20 features **or** at least 8 peak monthly contributors |
| **Standard** | every other codebase |

- *Peak monthly contributors* is the largest number of distinct people,
  bots excluded, who changed the codebase in any calendar month of the last
  twelve. When the history is unavailable (shallow clone, no repository),
  the profile is measured on lines and features alone and the report says
  so.
- The operator MAY override the measured profile with a stated reason, for
  example a team about to triple or a prototype to be discarded. The report
  shows both the measured and the effective profile.
- Scores are relative to the effective profile. A score says how well a
  codebase fits what its profile calls for; scores of different profiles
  are not comparable.

**Drivers** call for hard boundaries independently of the profile, usually
physical modules. A driver applies to the code it concerns, not to the
whole codebase:

- **D1. Shared delivery.** Code is included in some deliverables but not
  others, or is shared with another app or repository. Per-environment
  entry points of one app (flavours such as development, staging and
  production) are one deliverable, and so are white-label builds that each
  ship the whole app.
- **D2. Several owning teams.** Two or more teams own parts of the
  codebase.
- **D3. Deferred delivery.** Parts of the app load on demand. Where the
  platform delivers them as build modules (Android dynamic feature
  modules), the deferred code MUST be a physical module. Where it defers by
  library or chunk (Dart `deferred as`, including Flutter deferred
  components, and JavaScript dynamic `import()`), the deferred code MUST
  NOT also be imported eagerly anywhere, and needs no module of its own.
- **D4. Published package.** The repository publishes part of its code as a
  package for others.

D1, D2 and D4, and D3 where the platform delivers build modules, are
**module drivers**: they call for physical modules. D3 code deferred by
library or chunk calls only for the absence of eager imports.

What each profile expects:

| Expectation | Compact | Standard | Large |
|---|---|---|---|
| Features separated into their own directories | SHOULD; a layer-first tree is acceptable | MUST | MUST |
| Physical feature modules (R10) | not expected; splitting is AP5 | MAY | MUST, for at least 90 % of features |
| Driver requirements met for the code a driver concerns (R10) | MUST | MUST | MUST |
| Navigation through contracts (R3) | route names or paths declared in one contract file, not in the root | MUST | MUST |
| Rule classes enforced by tools (R9) | R1, R2 | R1, R2, R5, R7 | R1, R2, R5, R6, R7, R8 |
| Public surfaces respected (R6) | not assessed | MUST | MUST |
| Checks runnable before push | not expected | SHOULD | SHOULD |
| An owner declared for every module | not expected | not expected | MUST |

A rule class the R9 row lists for the profile is required only when the
codebase's module graph can break it: R1 with at least two features, R2
with at least three modules, R6 when at least one module declares a public
surface, R7 when at least one contract, shared, global-service or
foundation module exists, and R5 and R8 whenever the row lists them. A small codebase can therefore require no class at
all; it has nothing to enforce yet, and its first required class appears
with its second feature or third module.

## 3. Module roles

Every module has exactly one role.

| Role | Purpose | Typical contents |
|---|---|---|
| **Composition root** | Assembles the application | Entry point, selection of implementations, aggregation of registration modules and route groups, composition widgets or slots that place several features side by side |
| **Contract** | Lets modules meet without depending on each other | Route keys and typed locations with primitive arguments, path templates, interfaces, value types. Either a neutral contract module, or one feature's **API module** (the feature's own contracts, split from its implementation) |
| **Feature** | One user-facing capability (section 1) | Its screens or endpoints, their state, the domain and data code only it uses, the bindings of its own contracts |
| **Shared** | Code two or more features need | *Shared-common*: product-agnostic UI or utilities, localisation and shared assets. *Shared-domain*: domain models and logic several features use |
| **Global service** | An application-wide capability features call through an interface | Session and auth state, analytics, remote configuration, feature flags, notifications |
| **Foundation** | Infrastructure with no product knowledge | Network and storage clients, logging, design-system primitives, platform adapters |

A data or repository layer kept in its own modules takes the role of what it
serves: product-specific repositories are shared-domain; product-agnostic
clients are foundation. A contract module holds no screens, state or
implementations; one that does is a feature in disguise and is reported
under AP1. A module holding domain models (entities and their failure
types) is shared-domain even when it also declares interfaces; contract is
for modules that hold only route keys, interfaces and the value types they
carry.

Some modules straddle two rows. A design system that also holds product
widgets is shared-common, and its product widgets are AP1's mixed-roles
signal. A
utility module is foundation when it imports no other in-repo module and
names no product concept, shared-common otherwise. Session and auth state
that features reach through an interface is a global service; a module
that also holds the user's domain models and their repository is
shared-domain. A data or repository package that only one feature uses is
that feature's data code kept apart: it stays its own shared-domain module,
with the feature it serves recorded, and it does not make the feature
physical.

A module that holds code of two roles (for example a directory that is both
the composition root and a home for widgets the features import) is
classified by its most-depended-upon role and reported as mixed: under R5
when one of its roles is the composition root, otherwise under AP1.

## 4. Allowed dependencies

Rows depend on columns. ✓ allowed, ✗ forbidden.

| From \ To | Root | Contract | Feature | Shared-domain | Shared-common | Global service | Foundation |
|---|---|---|---|---|---|---|---|
| **Composition root** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Contract** | ✗ | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ |
| **Feature** | ✗ | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ |
| **Shared-domain** | ✗ | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ |
| **Shared-common** | ✗ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ |
| **Global service** | ✗ | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ |
| **Foundation** | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |

Every ✓, within a role or across roles, holds only while the graph stays
acyclic (R2). A feature that needs another feature goes through a contract:
the other feature's API module or a neutral contract module, never the
other feature's implementation. A global service is used through its
interface; its implementation is bound in the root.

## 5. Rules

**R1. Features do not depend on features.** A feature MUST NOT import
another feature's implementation. What two features both need moves down to
a shared module; how one feature reaches another goes through a contract
(R3). Edges into contract modules, including another feature's API module,
are not feature edges.

**R2. The module graph is acyclic.** No cycle may exist among the edges the
matrix allows. Edges the matrix forbids are violations of R1, R3, R5 or R7
and are counted there, not again as cycles. Within a module, cycles between
files are the module's own business.

**R3. Navigation goes through contracts.** A feature that opens another
feature's screen MUST address it through a contract: a route key, typed
location or path template that carries primitive identifiers, declared in a
contract module. The binding from contract to screen lives in the target
feature or in the composition root; a typed route class that also builds
the screen is a binding, not a contract. The deep-link table is part of the
contract. A route string literal passed to a navigation call outside a
contract module is a violation; bindings SHOULD refer to the contract's
path constant rather than repeat the literal. A contract module MUST NOT
depend on a feature. R3 applies once there are two features.

**R4. The root selects implementations.** The composition root decides which
implementation backs each interface and aggregates registration and routes.
A feature MAY export its own registration module and route group for the
root to include, and framework-native injection that declares providers
next to their code conforms when the root and tests can override them. Every
dependency a feature consumes MUST be replaceable by the root and by tests
without editing the feature. Violations, by any module other than the
root: constructing another module's implementation (a default the root
or a test can replace, such as an optional constructor parameter, is not
one); reaching a static
singleton of another module; looking up another module's implementation
type where the root binds an interface for it; registering another
module's bindings; and a feature assembling another feature's routes. A
locator or scope that the root configures (a service locator such as
get_it, `provider`'s `context.read`, Riverpod's `ref`) is not a static
singleton: looking up what the root binds through it conforms, whether
that is an interface or a class the root constructs, because the root and
tests still choose the instance.

**R5. The composition root holds composition only.** The root MUST NOT hold
product logic, or shared widgets, localisation, assets or services meant
for other modules, and no module outside the root may depend on it. What
features need from the root moves to a contract, shared or foundation
module. App-wide configuration that only the root uses to start the
application (the theme or shell it hands the framework, environment and
startup setup) is composition.

**R6. Modules are used through their public surface.** An edge into a module
MUST target its public surface. A deep edge into another module's internals
is a violation even when the dependency itself is allowed. A module whose
surface is not declared cannot be checked, and an audit that cannot check
most edges reports R6 as not measured.

**R7. Lower roles point down and stay single-purpose.** Contract, shared,
global-service and foundation modules depend only as the matrix allows. A
shared module SHOULD have one purpose that its name states, and MUST NOT
mix roles (UI kit, platform services and domain logic in one place).

**R8. Layers point inward and contain the outside world.** Inside a feature,
presentation depends on state, state on domain or repositories,
repositories on data sources and clients, never the reverse, and
presentation does not reach data sources or clients directly. Vendor SDKs,
HTTP clients and platform APIs are imported only by the composition root
(to initialise and bind them), foundation modules, global-service
implementations, or a data layer (a feature's own, or a shared-domain
module of repositories). A **vendor
SDK** is a client for an external service: a backend, authentication,
analytics, crash reporting, payments, storage or push messaging. A
**platform API** is a platform library (`dart:io` and the like) or a
plugin that reaches an operating-system capability (files, camera,
location, sharing, opening URLs).
General-purpose libraries, the UI framework and UI-widget packages (maps,
web views, video players, image loaders that fetch their own content) are
not vendor SDKs.

**R9. Rules are enforced mechanically.** The rule classes the profile
requires (section 2, among those the module graph can break) MUST be
checked by a tool that fails CI or a required merge check on a new
violation.

- A class counts as enforced when the check covers every handwritten
  module. Coverage of only some modules counts as half.
- Where changes land as plain commits on the trunk, with no pull requests,
  CI that fails on every push to the trunk counts as failing CI. Branch
  protection is not visible from the repository: rate from the workflow
  triggers, and do not assume a required check that nothing shows.
- A lint that reports at info or warning severity without failing CI does
  not count.
- Build-system boundaries count only where the build rejects an undeclared
  dependency. Section 10 lists where it does not.
- Existing violations are held in a baseline that fails on growth and
  fails on, or automatically prunes, stale entries, so it can only shrink.
- A rule that exists only in prose is treated as absent.

**R10. Boundaries become physical when the profile or a driver calls for
it.** In the Large profile, at least 90 % of features MUST be physical
modules. Code that D1, D2 or D4 concerns MUST be a physical module in any
profile, and code that D3 concerns MUST meet D3's requirement (section 2).
Below that, logical modules with the profile's enforced rule
classes satisfy the standard, and splitting further is AP5.

## 6. Anti-patterns

Each anti-pattern has signals the audit checks. One signal is a **warning**;
two or more **confirm** the anti-pattern.

**AP1. Shared module as a warehouse.** A shared, global-service,
foundation or contract module collects whatever has no obvious home.
Features and the root are judged elsewhere (AP4, AP2, R5).
Signals: one shared, global-service or foundation module holds more than
50 % of handwritten code; such a module mixes two or more roles (R7); it
has the highest fan-in of any module while its name states no purpose
(`common`, `core`, `utils`, `app`, `shared` alone); it depends on a
feature; a contract module holds screens, state or implementations.
Shared code found inside the root's directories is counted once, under R5,
not here: its modules give no AP1 signal, though their R7 sites still
count.

**AP2. Composition monolith.** The composition root grows into the place
where the application actually lives.
Signals: the root's share of handwritten code is in Risk (M9); a single
handwritten wiring file exceeds 500 lines; one handwritten wiring file
registers the bindings of more than five features instead of including
per-feature registration modules. Generated wiring (for example
injectable's output) is left out: its registrations are declared next to
the code they bind.

**AP3. Hidden navigation coupling.** Features look independent in the
dependency rules but are tied together through navigation.
Signals: a feature imports another feature's screen, page or route binding
to navigate; a feature assembles another feature's routes (R4); route
string literals are passed to navigation calls outside contract modules
(R3). With fewer than two features AP3 is not applicable.

**AP4. Feature monolith.** One feature carries a disproportionate share of
the product.
Signals: the largest feature is more than three times the mean feature size
(M7 Risk); it has the highest fan-out of any feature; a single file in it
exceeds 2,000 lines; a single state holder in it handles more than 25 event
types or takes more than 6 injected collaborators. With fewer than four
features the size signal is not applicable, and with one feature the
fan-out signal is not either.

**AP5. Premature modularisation.** The codebase pays for boundaries its
profile does not need.
Signals: the profile is Compact and features are physical modules that
no module driver (section 2) calls for; more than 30 % of physical modules, contract modules
excepted, hold fewer than three handwritten files and have a single
dependent module.

## 7. Metrics and thresholds

Every threshold the audit uses is defined here, once. **Healthy** needs no
action; **Watch** should be tracked; **Risk** needs a plan. A metric outside
its *Applies when* condition is **not applicable**; a metric whose evidence
is missing is **not measured**, which is never read as Healthy.

| ID | Metric | Healthy | Watch | Risk | Applies when |
|---|---|---|---|---|---|
| M1 | Feature-to-feature module edges per feature | 0 | ≤ 1 | > 1 | ≥ 2 features |
| M2 | Modules in the largest cycle over allowed edges | 0 | 2–3 | ≥ 4 | ≥ 3 modules |
| M3 | Deep edges as a share of checked allowed cross-module edges | 0 % | ≤ 5 % | > 5 % | not Compact; not measured when more than half of allowed cross-module edges go into modules without a declared surface |
| M4 | Mean features touched per change | ≤ 1.2 | ≤ 1.5 | > 1.5 | ≥ 4 features, ≥ 50 qualifying changes, full history |
| M5 | Changes touching three or more features | ≤ 5 % | ≤ 10 % | > 10 % | as M4 |
| M6 | Required rule classes enforced (R9; half credit for partial coverage) | all | ≥ half | < half | at least one class is required (section 2) |
| M7 | Largest feature's size ÷ mean feature size | ≤ 2 | ≤ 3 | > 3 | ≥ 4 features |
| M8 | Handwritten files over 1,000 lines, as a share of files | 0 | ≤ 1 % | > 1 % | always |
| M9 | Composition root's share of handwritten code | ≤ 10 % | ≤ 25 % | > 25 % | always |
| M10 | Features that are physical modules | ≥ 90 % | ≥ 50 % | < 50 % | Large profile |
| M11 | Modules with a declared owner | 100 % | ≥ 50 % | < 50 % | Large profile |

How the change metrics are counted (M4, M5): the last 300 changes on the
audited branch's first-parent line, so a merged pull request counts once
in squash and merge-commit workflows (in a rebase-merge repository every
rebased commit counts, and the report says so);
only handwritten source files count; changes touching more than 50 such
files are dropped as mechanical; changes touching no feature are left out.
They are read as a trend against the previous audit, since no published
anchor exists.

Where the numbers come from: 1,000 lines per file matches SonarQube's
default for its file-length rule, and six collaborators matches common
constructor-parameter limits in static analysers. The other thresholds,
including the profile limits in section 2, are this standard's own
heuristics: fixed so that audits stay comparable, and revised only with
this file.

The audit reads the metrics through five quality criteria. A criterion's
status is the worst status among its applicable metrics.

| Criterion | Metrics |
|---|---|
| Structural coupling | M1, M2, M3 |
| Change locality | M4, M5 |
| Manageability | M6 |
| Maintainability | M7, M8 |
| Development scalability | M9, M10, M11 |

## 8. The four contours

The standard is applied through four contours. Each answers one question,
and the audit scores each.

| Contour | Question | Rules |
|---|---|---|
| **Structural** | Do the modules exist in the form the profile calls for, with clear roles and proportionate sizes? | R7, R10, AP1, AP4, AP5 |
| **Integration** | Do modules depend on each other only as the matrix allows? | R1, R2, R3, R6, R8, AP3 |
| **Composition** | Is the application assembled in one place that does nothing else? | R4, R5, AP2 |
| **Control** | Are the rules written down and enforced by tools? | R9 |

## 9. Order of remediation

Bring a codebase into line in this order. Each stage makes the next one
cheaper and keeps the previous one from eroding. A stage the profile does
not call for is skipped.

1. **Rules and control first.** Write the module map and the dependency
   matrix down; add mechanical checks for the profile's rule classes with a
   baseline of current violations that may only shrink (R9).
2. **Navigation contracts.** Replace screen imports with contracts and move
   route assembly into the root (R3, R4). This usually removes a large
   share of feature-to-feature edges mechanically.
3. **Empty the root.** Move shared widgets and localisation to
   shared-common, platform services to foundation, domain logic to its
   owning module (R5, AP1).
4. **Break cycles through shared modules.** Extract what the modules in a
   cycle share, starting with the most depended-upon pieces (R1, R2).
5. **Make boundaries physical where the profile or a driver calls for it.**
   Start with code a module driver concerns, then features with no edges
   to other features, then pure providers (fan-out 0), then the rest
   (R10). In the Compact profile, the matching action is to merge modules
   that AP5 flags. For D3 code deferred by library or chunk, the action is
   to remove its eager imports and add a check that keeps them out.
6. **Split monoliths last.** Decompose a feature monolith (AP4) once it no
   longer sits in a cycle; earlier, the split only moves the cycle.

Work no stage names goes with the nearest one: R4 wiring (singletons,
cross-module construction) and AP2 with stage 3, R6, R7 and R8 with stage
4, and oversized files (M8) with stage 6.

## 10. Stack notes

What a boundary means and which tools can enforce it differs by stack. The
audit's control step uses these notes when it decides whether a class is
enforced.

**Dart and Flutter.**
- A pub workspace (Dart 3.6 and later) resolves every member through one
  shared package configuration, so a member's import of a sibling it never
  declared resolves and compiles. Outside a workspace, a package resolves
  only its own dependency closure: an unrelated sibling fails to resolve,
  but a transitive dependency still resolves. In both layouts
  `depend_on_referenced_packages` reports the undeclared import, and
  `implementation_imports` reports an import of another package's `src/`.
  Physical packages enforce, between packages, every rule class their
  manifests encode: R5 and R6 for every package (a package cannot declare
  the app, and `implementation_imports` guards `src/`); R1 for feature
  packages; and R7, and R8 containment of a vendor SDK only a data package
  declares, for lower-role packages whose manifests list only what the
  matrix allows. They do so only when both lints are enabled, not
  suppressed, and fail CI: raised to `error`, or run by `flutter analyze`
  (which fails on infos and warnings unless told otherwise with
  `--no-fatal-infos` or `--no-fatal-warnings`), or by
  `dart analyze --fatal-infos`. Run from a directory, either command
  analyzes every package beneath it. Logical modules inside the app's own
  package get none of this.
- No analyzer lint detects import cycles. `lakos --no-cycles-allowed`, run
  in CI over a package, fails on any cycle between its libraries; that is
  stricter than R2 and enforces it for the logical modules inside the
  package. Cycles between packages need a CI script over the manifests or
  the import graph.
- `@internal` (package `meta`) with `invalid_use_of_internal_member`
  failing CI enforces a public surface between packages. Inside one
  package it does nothing: logical modules there need a custom rule for
  R6.
- Custom boundary rules can run as analyzer plugins (Dart 3.10 and later,
  configured under `plugins:` in `analysis_options.yaml`), which the
  analyzer itself reports; through `custom_lint`, which counts only when CI
  runs `dart run custom_lint`, because its diagnostics do not reach
  `dart analyze`, and whose releases have lagged the analyzer's; through
  DCM (commercial) when CI runs it; or as a CI script over the import
  graph.
- Physical packages pay off in declared dependencies and in scoped
  analysis, tests and code generation more than in build caching. With
  workspaces, they share one lockfile.
- gen-l10n writes its output into the app's own source tree. That output
  belongs to a shared-common module, not to the root.
- Lookups through get_it, `provider` or `flutter_bloc` scopes
  (`RepositoryProvider`, `BlocProvider`, `context.read`, `context.watch`)
  or Riverpod's `ref` of what the root binds, or of a provider the root
  overrides, conform to R4, and so do Riverpod providers declared next to their code and
  overridden in the root's `ProviderScope`, and injectable micro-packages
  included by the root.
- `deferred as` splits loading units by library, and Flutter's deferred
  components require every import of a deferred library to be deferred
  (D3).

**TypeScript and JavaScript.** Nx module-boundary rules (with tags for role
and scope), dependency-cruiser, and `eslint-plugin-boundaries` or
`no-restricted-imports` enforce R1, R2, R5–R7 when they run as failing CI
checks. With a hoisting package manager (npm, Yarn classic), a workspace
package resolves siblings it never declared, so package boundaries need
such a check as well. pnpm rejects an undeclared sibling unless a
`tsconfig` `paths` alias maps it (many Nx workspaces define such aliases)
or the root manifest depends on it; Yarn Plug'n'Play rejects it unless
such an alias maps it. Dynamic `import()` splits by chunk, so D3 code needs a check that no
static import reaches it. Frameworks that derive routes from the file
system assemble routes themselves; route-assembly checks do not apply to
them.

**Python.** import-linter contracts (forbidden, layers, independence, and
acyclic siblings for R2) enforce R1, R2, R7 and R8 as a failing CI step.
Workspace members (for example uv workspaces) share one environment, so an
undeclared sibling import resolves unless such a check rejects it.

**JVM and native.** Gradle (`implementation` dependencies) and Bazel
(`visibility`, and strict dependencies, on by default for Java rules only)
reject an undeclared dependency, though Gradle's `api` dependencies still
reach consumers transitively.
SwiftPM rejects one only with `--explicit-target-dependency-import-check
error`; otherwise a target can import a module another target already
built. Under those conditions physical modules enforce R1 and R5 by
themselves. R6 holds by itself only where the default access is
module-internal (Swift's `internal`). Kotlin defaults to public, and
Java's package-private default hides a declaration only within its
package, so R6 needs Kotlin `internal`, Java declarations kept
package-private or unexported, or an architecture test. Architecture tests (ArchUnit, Konsist) cover the rest.
