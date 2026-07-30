# AngularJS Configuration Analysis

> Read and analyze AngularJS/Node configuration files for version info, dependencies, JSHint/ESLint setup, and the build tool (Grunt/gulp/webpack).

---

Goal: Read and analyze all AngularJS project configuration files to
understand the technical foundation and tooling setup.

CONFIGURATION FILES TO ANALYZE:

1. **bower.json / package.json** (at least one REQUIRED):
   - Extract the AngularJS version and companion Angular modules
     (`angular-route`/`ui-router`, `angular-resource`, `angular-animate`,
     `angular-sanitize`, `angular-mocks`)
   - If Angular is loaded only via a CDN `<script>` tag, extract the version
     from that URL instead
   - Extract devDependencies (JSHint/ESLint, Karma, Jasmine, Grunt/gulp plugins)
   - Check `scripts` (package.json) or registered tasks for build, test, lint
   - Check `engines` field for a Node.js version requirement
   - Count total dependencies (dependencies + devDependencies, bower + npm)
   - Identify outdated patterns (Angular < 1.5 with no `.component()`, Angular
     < 1.8, abandoned/unmaintained Bower libs)

2. **Bower Configuration**:
   - Read `bower.json` + `.bowerrc` if present
   - Check for a `resolutions` block (unresolved version conflicts)
   - Note pinned vs range (`~`/`^`/`*`) versions
   - Note that Bower is deprecated/abandoned — a migration-risk signal

3. **JSHint / ESLint Configuration**:
   - Read `.jshintrc`, `.eslintrc.*`, or `eslint.config.*`
   - For JSHint: check `globals` (does it declare `angular`, `$`?), `strict`,
     `undef`, `unused`
   - For ESLint: check for `eslint-plugin-angular` (or the community
     `angular` plugin) and the `env: { browser: true }` / angular globals
   - Note any disabled rules important for AngularJS (e.g. rules that guard
     minification-safe DI)

4. **Formatting Configuration**:
   - Read `.editorconfig`, `.prettierrc`, or `prettier.config.*`
   - Check if any formatter is configured at all
   - Check for JSHint/ESLint + formatter integration

5. **Build Tool Configuration**:
   - Grunt: read `Gruntfile.js`
     * Check tasks: `concat`, `uglify`/`ngmin`/`ngAnnotate`, `karma`, `jshint`,
       `html2js`/`ngtemplates` (`$templateCache`), `cssmin`, `usemin`
   - gulp: read `gulpfile.js` (equivalent tasks)
   - webpack: read `webpack.config.*` (rarer for Angular 1.x, but possible)
   - Note if there is NO build step (raw `<script>` tags only)

6. **Environment / Constant Configuration**:
   - Check for an Angular constants/value config module
     (`angular.module('config').constant('ENV', {...})`) or a generated
     `config.js`
   - Check for `.env`-style files or a `config.sample.*` template
   - Check for `.env`/secrets committed to the repo (security risk)

OUTPUT FORMAT:

Provide structured analysis:
- AngularJS version: [Version] (≥1.8? Yes/No)
- Companion modules: [ui-router/ngRoute/ngResource/ngSanitize/...]
- Dependency manager: [Bower/npm/CDN-only/Mixed]
- Node.js requirement: [Version or Not specified]
- Build tool: [Grunt/gulp/webpack/None]
- Linter: [JSHint/ESLint/Missing]
  * angular plugin/globals declared: [Yes/No]
  * minification-safe DI rule: [Yes/No/N/A]
- Formatter: [Prettier/.editorconfig/Missing]
- Template caching ($templateCache): [Configured/Missing]
- Config/env template: [Present/Missing]
- Key risks from configuration (include Bower-abandonment / Angular-EOL)
- Recommendations
