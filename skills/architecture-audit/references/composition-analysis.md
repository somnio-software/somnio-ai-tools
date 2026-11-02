# Composition Analysis

> Inspect how the application is assembled: who selects implementations,
> whether the composition root does anything else, how routes are
> assembled, whether features navigate to each other through contracts, and
> whether layers point inward. Covers rules R3, R4, R5 and R8 and
> anti-patterns AP2 and AP3.

---

Goal: Decide, with file-level evidence, whether composition is substitutable
and lean, and whether navigation or layering couples modules behind the
dependency rules' back.

INPUT (artifacts in `reports/.artifacts/architecture-audit/`):
- `data/module_map.tsv`, `data/module_edges.tsv`, `data/metrics.json`, and
  the step 1 and step 2 artifacts (`step_*_module-map.md`,
  `step_*_dependency-graph.md`). If they are missing, say so in the
  artifact and work from the repository alone; do not invent module roles.
- `architecture-standard.md`, in the same directory as this file: rules
  R3, R4, R5, R8, anti-patterns AP2, AP3, and the stack notes in section
  10.

READ-ONLY DISCIPLINE:
- Never modify the audited repository. Read and search its source and the
  artifacts with `grep`, `cat`, `head`, `wc`, `awk` and `python3`; write
  only the artifact below.

## 1. Implementation selection (R4)

Find how dependencies are constructed and handed out, and record the
mechanism with its file and line:
- **Constructor injection from the root**: providers, bindings or
  constructor calls in the entry point or a wiring module (`main*`,
  `bootstrap*`, `app.*`, `di/`, `injection*`, `container*`, `Startup`,
  `Program`).
- **Framework-native injection**: Riverpod providers with root overrides,
  `injectable`/`get_it` modules (including per-package micro-packages),
  Angular or NestJS modules and providers, Spring, .NET
  `IServiceCollection`, Hilt or Dagger modules.
- **Service locator lookups**: `GetIt`/`getIt`/`locator`, `Injector`,
  `Container` lookups, `inject(`, module-level singletons imported across
  modules. A lookup of what the root binds (an interface, or a class the
  root constructs and provides), or of a provider the root can override,
  through a locator or scope the root configures (get_it, `provider` or
  `flutter_bloc` scopes such as `RepositoryProvider` and `BlocProvider`
  with `context.read` or `context.watch`, Riverpod's `ref`) conforms to
  R4.

R4 does not require every registration to sit in the root. A feature may
export its own registration module, and providers declared next to their
code conform, as long as the root and tests can replace every dependency a
feature consumes without editing the feature. Count these **R4 violation
sites**, each with file and line, in any module other than the composition
root. The root constructing, reaching, looking up or registering
implementations is how it selects them, and is never a site.
- constructing another module's implementation (`SomeRepositoryImpl(` or a
  client constructor called from a feature that does not own it); a
  default value the root or a test can replace (an optional constructor
  parameter) is not a site;
- reaching another module's static singleton: `Foo.instance`,
  `Foo.shared`, a factory that returns one shared instance, static methods
  over a hidden static instance (`Foo.show(...)`), or a top-level mutable
  global. Static helpers that hold no state are not singletons. The
  locator itself (`GetIt.I`, `GetIt.instance`) is not one, and neither is
  a singleton of the framework or platform (`WidgetsBinding.instance`);
- looking up another module's implementation type where the root binds
  an interface for it;
- registering another module's bindings: providing, again and in its own
  scope, an instance another module owns.

If there is no injection mechanism at all and features construct their own
collaborators, say so: C1 scores that as 0.

## 2. Composition root contents (R5, AP2)

For every `root` row in `data/module_map.tsv`:
- List its files with line counts. A **wiring file** is a handwritten file
  whose main content is constructing or registering dependencies (the
  entry point, bootstrap, a DI module, the widget that provides the
  scopes). Name the largest wiring file and its line count.
- A **binding** is an instance made available to other code: a provider,
  a locator registration, a module binding. Constructing an object is not
  registering it. Find the handwritten wiring file that registers the most bindings, and
  count how many features' bindings it registers itself (rather than
  including a per-feature registration module); shared bindings do not
  count toward it. Generated wiring
  (injectable's `*.config.dart` and the like) is left out: its
  registrations are declared next to the code they bind.
- List each **non-composition file** inside the root: product logic, or
  shared widgets, localisation, assets or services meant for other
  modules. Configuration only the root uses to start the application (the
  theme or shell it hands the framework, environment and startup setup) is
  composition, not a site. Add the files of every row step 1 split out of
  the root's directories, whatever its role: they are counted here, once,
  and not again under AP1.
- Count the **imports of the root from outside it**: the sites of the
  `*->root` violation kinds in `metrics.json`, one per importing file and
  imported root file, as `metrics.json` lists them. A file already counted
  as split out is not counted again.

**C2 sites** = non-composition files in the root + split-out files +
imports of the root from outside it.

AP2 signals (standard section 6), each present or absent with evidence:
`rootShare` in Risk (over 25 %); a handwritten wiring file over 500
lines; one handwritten wiring file registering the bindings of more than
five features.

## 3. Route assembly (R4)

Find where the route tree, URL configuration or HTTP route registration is
built (`GoRouter(`, `MaterialApp(routes:`, `createBrowserRouter`,
`<Routes>`, Angular `RouterModule.forRoot`, Django `urlpatterns` with
`include()`, Express or NestJS routers and modules).
- Is there one place, in a root module, that assembles the tree from
  per-feature groups?
- Does any feature assemble another feature's routes (a route file in
  feature A that imports feature B's routes)? List each case with file and
  line.
- **Not applicable** when the framework derives routes from the file system
  (Next.js `app/` or `pages/`, Nuxt, SvelteKit, Expo Router) or the product
  has a single route. Record which, and why.

## 4. Navigation between features (R3, AP3)

- **Contracts**: list the contract modules that carry route keys, typed
  locations or path templates (neutral modules or features' API modules),
  with paths. A typed route class that also builds the screen is a
  binding, not a contract.
- **Screen imports**: from `data/module_edges.tsv`, take each row whose
  source role and target role are both `feature`, whose source and target
  modules differ, and whose target file is a screen, page, route or
  navigation file (names such as `*_page.*`, `*_screen.*`, `*Page.*`,
  `*Screen.*`, `*routes*`, `*route*`, `navigation/`, `pages/`,
  `screens/`). When features import each other through barrels, the
  target file is the barrel: read what the importing file uses from it,
  and count the edge when that is a screen, page or route. Confirm a
  sample by opening the importing line. Record the count, up to ten
  examples, and their share of all file-level feature-to-feature edges
  (with none, write "0 of 0"). Of these, also count the edges whose only
  use is a route path, a route class or a navigation call: contracts
  alone remove them, and the remediation plan needs that number. These
  edges are AP3 evidence; I1 already scores them.
- **Literal route sites**: route-like string literals (`'/`-prefixed paths
  or route names, including interpolated ones that write a path segment
  out, such as `'/orders/$id'`) passed to a push, go, navigate,
  redirect or link call in any module that is not a contract module. A
  path built only from constants (`'${A.path}/${B.path}'`) is not a
  literal; record where those constants are declared. The router's own
  configuration is a binding, not a site: route definitions
  (`GoRoute(path: ...)` and the like), redirects and error routes declared
  with it; note whether bindings reuse the contract's constants. Record
  the count and up to ten examples. This is what I4 scores.
- **Object arguments**: note navigation calls to another feature's screen
  that pass a whole object (`extra:`, navigation state) where R3 asks for
  a primitive identifier, with file and line; they are R3 findings, not
  I4 sites.
- **Compact profile**: also record whether the route names or paths are
  declared in one contract file that is not in the root, and which; I4
  scores that instead of per-feature contracts.
- **Not applicable** when features do not navigate to each other (a
  backend, a single-flow app) or there are fewer than two features: I4 is
  then not assessed. AP3 is not applicable only with fewer than two
  features; otherwise its route-assembly signal still applies. Record what
  you saw anyway, for the remediation plan.

AP3 signals: screen or route imports between features; a feature
assembling another feature's routes; literal route sites outside contract
modules.

## 5. Layering and containment (R8)

Within feature modules, look for edges that skip or reverse layers:
- presentation files (views, pages, screens, widgets, components)
  importing data sources, API or storage clients, or transport models
  directly;
- state holders (BLoC, store, view model, controller) importing clients or
  data sources instead of repositories;
- data or domain files importing presentation.

Then check containment of the outside world. `externalImportsByModule` in
`metrics.json` maps each module to the packages it imports, each with a
file count and an example site; `platformImportsByModule` maps it to the
platform libraries it imports, with a count (for Dart: `dart:io`,
`dart:html`, `dart:ffi`, JS interop). Keep the packages that are vendor SDKs as standard R8 defines
them (clients for a backend, authentication, analytics, crash reporting,
payments, storage or push messaging), HTTP clients and platform APIs;
general-purpose libraries, the UI framework and UI-widget packages are
not. A plugin that reaches an operating-system capability (files,
camera, location, sharing, opening URLs) is a platform API. A
**containment site** is one (module, package) pair in which the module
imports such a package from code other than the composition root, a
foundation module, a global-service implementation or a data layer (the
feature's own, which is the code its state reaches through a repository
or an interface: data sources, clients and adapters; or a shared-domain
repository module); open the
importing files (`grep` for the package within the module) to decide
which layer they sit in.

For the layer direction, use `data/module_edges.tsv`: every row already
carries its source and target modules and roles, and same-module edges
have status `internal`. The file carries no layers: classify each file of
a feature by its directory and name (`view/`, `widgets/`, `*_page`,
`bloc/`, `cubit/`, `repository`, `data_source`, `models/` and the like),
and confirm by reading it. A **layering site** is one file-level edge against
the layer direction. Confirm each reported site by reading the line.
Report the count per kind and every site (or the first ten per kind if
there are more). Layering sites plus containment sites are the R8 site
count I5 scores.

## ARTIFACT SAVE (mandatory)

Write `reports/.artifacts/architecture-audit/step_03_composition-analysis.md`:
- **Implementation selection**: mechanism, R4 violation sites by kind
  (count and examples), or "no injection mechanism".
- **Composition root**: files and sizes, largest wiring file, the most
  features one wiring file registers, non-composition files, files
  importing the root, C2 site total, AP2 signals present/absent.
- **Route assembly**: where, by whom, cross-feature assembly cases, or
  "Not applicable" with the reason.
- **Navigation**: contract modules (paths or "none"), screen imports
  between features (count, share of feature edges, examples), literal
  route sites (count, examples), AP3 signals present/absent, or "Not
  applicable" with the reason.
- **Layering and containment**: R8 violations by kind with sites, and the
  total.

If the runner gave you a different artifact path for this step, write the
artifact there instead.
