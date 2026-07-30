# AngularJS Repository Inventory

> Detect repository structure, AngularJS version and bootstrap, Bower/npm layout, and module/feature folder organization for Angular 1.x projects.

---

Goal: Detect repository structure, module/component organization, and
validate architecture patterns for clean, maintainable code.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 6 total tool calls for this entire analysis
- Use batch find/ls commands to inventory directory structure in one pass
- Read `bower.json` + `package.json` (and any CDN `<script>` tags in index.html)
  per tool call using parallel reads
- Do NOT read individual source files to count them — use find + wc
- EXCLUDE from all counts: `bower_components/`, `node_modules/`, minified
  vendor bundles (`*.min.js`), `dist/`/build output, and concatenated assets

ANGULARJS DETECTION:

1. **AngularJS Detection & Version**:
   - `bower.json` with an `angular` dependency, OR `package.json` with
     `angular` (1.x), OR a CDN `<script src=".../angular(.min).js">` tag in
     `index.html`
   - Extract the Angular 1.x version (e.g. 1.2, 1.5, 1.8). Note whether it is
     ≥ 1.8 (the last line with `$sce`/CSP fixes) — anything older is a risk
   - Confirm a bootstrap: `ng-app` attribute in HTML, or `angular.bootstrap(`
     in JS, plus at least one `angular.module('name', [...])` registration
   - Note jQuery presence and whether Angular uses jqLite or full jQuery

2. **Layout / Bower vs npm Handling**:
   - Detect `bower.json` (+ `.bowerrc`) and/or `package.json`
   - Note whether vendor libs live in `bower_components/` or `node_modules/`
     or are vendored/committed
   - Don't penalize a Bower-based layout by itself; note it as legacy context
   - Detect a modular seed layout (angular-seed) vs a flat single-file app

3. **Standard Project Structure**:
   - Check for an app root: `app/`, `public/`, `src/`, or `client/`
   - Check for entry point: `index.html`, `app.js`, `app.module.js`
   - Check for `scripts/`, `views/` (templates), `styles/` sub-trees

FOLDER ORGANIZATION ANALYSIS:

4. **Feature-Based Organization Check** (PREFERRED):
   - Detect if the app is grouped by feature (`app/dashboard/`, `app/users/`
     each holding its own controller + template + spec)
   - vs grouped by type (`controllers/`, `services/`, `directives/`,
     `views/` — the classic type-first AngularJS layout)
   - Note flat structure if everything is in one `scripts/` or `app.js`

5. **Directory Inventory**:
   - List top-level directories in the app root
   - Count: controllers, directives, components (`.component(`), services,
     factories, filters, templates/views
   - Check for a `shared/` or `common/` module

COMPONENT / CONTROLLER FILE SIZE ANALYSIS:

6. **File Size**:
   For all `*.js` files under the app root (excluding vendor/min/dist):
   - Files < 150 lines: Healthy
   - Files 150-300 lines: Acceptable
   - Files > 300 lines: FLAG for review (likely god-controller)
   - Files > 500 lines: CRITICAL FLAG

NAMING CONVENTIONS:

7. **Naming Check**:
   - Consistent module/controller naming: `UserProfileController` /
     `userProfile.controller.js` ✓
   - kebab-case or dot-suffixed files: `user-list.directive.js`,
     `auth.service.js` ✓
   - One module registration per file, `angular.module('app.x')` ✓
   - Flag: mixed conventions, many components in one file, globals not
     wrapped in a module

OUTPUT FORMAT:

Provide structured analysis:
- AngularJS version: [1.x version] (≥1.8? Yes/No)
- Dependency manager: [Bower/npm/CDN-only/Mixed]
- Total controllers/directives/components/services count: [Numbers]
- Organization pattern: [Feature-based/Type-based/Flat/Mixed]
- Feature-based structure: [Yes/Partial/No]
- File size analysis:
  * Files < 150 lines: [Count]
  * Files 150-300 lines: [Count]
  * Files > 300 lines: [Count] (flag for review)
  * Files > 500 lines: [Count] (critical - list files)
- Naming convention compliance: [XX]%
- Shared/common modules: [Present/Missing]
- Risks identified (include AngularJS version / EOL context)
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Feature-based (or clean type-based) module organization
- Files reasonably sized (most < 300 lines)
- Consistent naming, one module registration per file
- Shared/common modules present

Fair (70-84):
- Mixed organization (some features, some flat)
- Some large controllers
- Minor naming inconsistencies

Weak (0-69):
- Completely flat structure or a single monolithic app.js
- Multiple oversized god-controllers
- Inconsistent naming, globals not wrapped in a module
