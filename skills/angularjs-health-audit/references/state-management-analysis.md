# AngularJS Services & Data Flow Analysis

> Analyze service/factory layering, $http/$resource centralization and interceptors, $rootScope misuse, binding discipline, and digest-cycle hygiene. Feeds the State Management section.

---

Goal: Analyze the AngularJS project's data-flow architecture — how state and
server data move through services, `$http`, `$rootScope`, and `$scope` — to
evaluate layering quality and digest hygiene.

ANALYSIS TARGETS:

1. **Service / Factory Layering**:
   - Find service definitions:
     `grep -rn "\.\(factory\|service\|provider\|value\|constant\)(" app/ scripts/ src/ | wc -l`
   - Check that business logic and server access live in `.factory`/`.service`
     units, NOT inline in controllers
   - Flag "fat controllers" that call `$http` directly instead of delegating
     to a data service

2. **HTTP Centralization & Interceptors**:
   - Count direct `$http` calls:
     `grep -rn "\$http\b" app/ scripts/ src/ | wc -l`
   - Are `$http`/`$resource` calls centralized in a small set of data
     services, or scattered across controllers?
   - Check for `$httpProvider.interceptors` (auth token injection, error
     handling, spinner) — a strong signal of a disciplined data layer
   - Note `$resource` usage (declarative REST) vs raw `$http`

3. **$rootScope Misuse (anti-pattern)**:
   - Count `$rootScope` usage:
     `grep -rn "\$rootScope" app/ scripts/ src/ | wc -l`
   - Distinguish legitimate use (`$rootScope.$on`/`$broadcast` for a few
     global events) from misuse ($rootScope as a global data store / bus for
     everything). Heavy `$rootScope` data storage is a Weak signal.

4. **Binding Discipline (two-way vs one-way)**:
   - Check components/directives for `bindToController` + `controllerAs`
     (isolated, testable) vs `$scope`-soup
   - Look for one-way binding usage: `::` one-time bindings in templates,
     `<` one-way bindings in `.component()` `bindings`, vs pervasive `=`
     two-way bindings
   - Excessive two-way bindings inflate the digest and are a data-flow smell

5. **Digest-Cycle Hygiene**:
   - Count `$scope.$watch` / `$scope.$watchCollection` registrations:
     `grep -rn "\$watch" app/ scripts/ src/ | wc -l`
   - Look for deep watches (`$watch(..., true)`) — expensive
   - Look for manual `$scope.$apply()` / `$timeout` used to force digests
     (often a smell around non-Angular async)
   - Look for `$scope.$on('$destroy', ...)` cleanup of watches/listeners
     (its absence is a leak signal)

6. **Anti-Pattern Detection**:
   - Controllers manipulating the DOM directly instead of via directives
   - Server data cached in `$rootScope` or a `$scope` instead of a service
   - Business logic duplicated across controllers rather than in a shared
     service

OUTPUT FORMAT:

Provide structured analysis:
- Service/factory layer: [Well-layered/Partial/Thin (fat controllers)]
- $http centralization: [Centralized in services/Scattered]
- Interceptors configured: [Yes/No]
- $resource usage: [Yes/No]
- $rootScope usage: [XX] ([Reasonable/Misused as a bus])
- Binding discipline: [One-way/`::` favored / Pervasive two-way]
- controllerAs + bindToController: [Yes/Partial/No ($scope-soup)]
- $watch registrations: [XX] (deep watches: [XX])
- $destroy cleanup present: [Yes/No]
- Anti-patterns found: [list]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Server access centralized in services with interceptors
- Thin controllers, `controllerAs`/`bindToController`, one-way bindings
  favored
- `$rootScope` used only for a handful of global events
- Watches are few, shallow, and cleaned up on `$destroy`

Fair (70-84):
- Some services but a few controllers call `$http` directly
- Mixed one-way/two-way bindings
- Moderate `$rootScope` use; some uncleaned watches

Weak (0-69):
- `$http` scattered through fat controllers, no interceptors
- `$rootScope` used as a global data store/bus
- Pervasive two-way binding and deep watches, no `$destroy` cleanup
