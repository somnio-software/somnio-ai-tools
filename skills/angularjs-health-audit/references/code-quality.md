# AngularJS Code Quality Analysis

> Analyze JSHint/ESLint configuration, formatter setup, module hygiene ('use strict'/IIFE), and minification-safe DI annotation.

---

Goal: Analyze the JSHint/ESLint configuration, formatter setup, and code
quality enforcement to evaluate overall code quality infrastructure — with
special attention to minification-safe dependency injection.

ANALYSIS TARGETS:

1. **Linter Configuration**:
   - Read `.jshintrc`, `.eslintrc.*`, or `eslint.config.*`
   - For AngularJS-aware linting, check for:
     * `eslint-plugin-angular` (community) or JSHint globals declaring
       `angular`, `$`, `module`, `inject`
     * rules guarding minification-safe DI (e.g. `angular/di`,
       `angular/no-service-method`), `no-unused-vars`, `no-undef`
   - Verify the linter actually covers the source tree (not just a stray file)
   - Flag disabled rules that matter for AngularJS quality

2. **Minification-Safe DI (CRITICAL for Angular 1.x)**:
   - Grep for unsafe DI: functions taking injectables positionally with NO
     annotation, e.g.
     `.controller('X', function ($scope, $http) {...})` without a matching
     `['$scope', '$http', function(...)]` array or `X.$inject = [...]`
     ```bash
     grep -rn "\.\(controller\|service\|factory\|directive\|filter\|run\|config\)(" \
       app/ scripts/ src/ 2>/dev/null | head -40
     ```
   - Confirm ONE of these is present and consistent:
     * inline array annotation `['$scope', function($scope){}]`
     * explicit `$inject` property
     * an `ngAnnotate`/`ng-annotate` build step (see cicd-analysis.md)
   - If the app is minified AND none of the above is present, that is a
     CRITICAL runtime-breakage finding, not a style nit

3. **Module Hygiene**:
   - Check for `'use strict';` at the top of files or inside IIFEs
   - Check for IIFE wrapping `(function () { ... })();` to avoid leaking
     globals (or a module bundler that provides scope)
   - Flag code that attaches to `window`/global scope directly

4. **Formatter Setup**:
   - Check `.prettierrc`/`prettier.config.*` or `.editorconfig`
   - Note if no formatting configuration exists

5. **Code Quality Metrics**:
   - Count `console.log` in source (excluding specs/vendor):
     `grep -rn "console.log" app/ scripts/ src/ --include="*.js" | wc -l`
   - Count `eslint-disable` / `jshint ignore` comments
   - Count direct DOM/jQuery manipulation inside controllers/services
     (`$('...')`, `document.getElementById`) — an AngularJS anti-pattern
   - Count `$scope.$watch` registrations (digest-cost signal; also relevant
     to Services & Data Flow)

6. **Lint Script**:
   - Check `package.json` scripts / Grunt / gulp for a lint task
   - Verify the lint task targets the source directory
   - Check if lint runs in CI (from cicd-analysis.md results)

OUTPUT FORMAT:

Provide structured analysis:
- Linter configured: [JSHint/ESLint/No]
- Angular-aware linting: [Yes/No]
- Minification-safe DI: [Consistent annotations / ngAnnotate build / UNSAFE]
- 'use strict' present: [Yes/Partial/No]
- IIFE / no-globals module hygiene: [Yes/Partial/No]
- Formatter configured: [Yes/No]
- console.log in source: [XX]
- Direct DOM/jQuery in controllers/services: [XX]
- eslint-disable / jshint ignore count: [XX]
- Lint script present: [Yes/No]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Angular-aware JSHint/ESLint enforced over the source tree
- Minification-safe DI guaranteed (consistent annotations or ngAnnotate)
- 'use strict' + IIFE/module hygiene throughout
- Formatter configured; minimal disabled rules

Fair (70-84):
- Linter configured but missing angular awareness or partial coverage
- DI mostly safe but inconsistent
- Some console.log / disabled rules

Weak (0-69):
- No linter or minimal configuration
- Unsafe DI on a minified build (runtime breakage risk)
- Globals leaked, no 'use strict'
- No formatting enforcement
