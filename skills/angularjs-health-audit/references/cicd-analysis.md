# AngularJS Build & Asset Pipeline / CI Analysis

> Read the build/asset-pipeline configuration (Grunt/gulp/webpack) plus any CI/CD workflow files to evaluate build and automation coverage. Feeds the CI/CD section.

---

Goal: Read and analyze the AngularJS build/asset pipeline and any CI/CD
workflow files found in the repository to assess build and automation quality.

EFFICIENCY REQUIREMENTS:
- Read all pipeline and workflow files in one batch
- Do NOT execute the build — only analyze its configuration

FILES TO ANALYZE:

1. **Build / Asset Pipeline** (primary for Angular 1.x):
   - Grunt: `Gruntfile.js` — inspect the registered tasks
   - gulp: `gulpfile.js` — inspect the defined tasks
   - webpack: `webpack.config.*` (less common for 1.x)
   - Raw script includes: note if `index.html` just lists many `<script>`
     tags with no build step at all

2. **Pipeline Task Targets** (score what the build actually does):
   - Concatenation: `concat` (bundling many small files)
   - Minification / uglification: `uglify`, `cssmin`
   - Minification-safe DI: `ngAnnotate` / `ng-annotate` / `ngmin` (CRITICAL —
     without it, uglified DI breaks at runtime unless every dependency is
     manually annotated)
   - Template caching: `html2js` / `ngtemplates` / `angularTemplatecache`
     (`$templateCache`) so templates are not fetched at runtime
   - Cache-busting / revving: `filerev` + `usemin`, or hashed filenames
   - Sourcemaps: generated for concatenated/minified output
   - CSS/SCSS/LESS compilation: `sass`/`less`/`compass`

3. **CI/CD Workflows** (if present):
   - Read all files in `.github/workflows/`
   - `.circleci/config.yml`, `Jenkinsfile`, `bitbucket-pipelines.yml`,
     `.gitlab-ci.yml`, `.travis.yml` (common in legacy AngularJS repos)
   - Identify triggers and the jobs/steps

4. **Docker Files** (if present):
   - `Dockerfile`, `docker-compose.yml`
   - Check multi-stage build usage and the base image (node/nginx)

ANALYSIS TARGETS:

5. **Lint Step**:
   - Check for a `jshint`/`eslint` task in Grunt/gulp, or `npm run lint` in CI
   - Flag missing lint step

6. **Test Step**:
   - Check for a `karma` task (single-run) in the build, or a `karma start`
     / `npm test` invocation in CI
   - Check for coverage reporting (karma-coverage, Coveralls, Codecov)
   - Flag missing test step

7. **Build Step**:
   - Check that a production build task exists (`grunt build` / `gulp build`)
     and produces `dist/`
   - Verify it performs ngAnnotate + concat + uglify + templateCache

8. **Dependency Caching** (CI):
   - Check for cached `node_modules` / `bower_components` in CI
   - Note performance impact if caching is missing

OUTPUT FORMAT:

Provide structured analysis:
- Build tool: [Grunt/gulp/webpack/None]
- CI/CD system: [GitHub Actions/CircleCI/Travis/Jenkins/None]
- Workflow/pipeline files found: [XX]
- Concat/bundle: [Present/Missing]
- Minify + ngAnnotate: [Present/Missing]
- Template caching ($templateCache): [Present/Missing]
- Cache-busting / sourcemaps: [Present/Missing]
- Lint step: [Present/Missing]
- Test step: [Present/Missing]
- Build step: [Present/Missing]
- Coverage reporting: [Present/Missing]
- Docker configuration: [Present/Missing]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Full build pipeline: concat + ngAnnotate + uglify + templateCache +
  cache-busting
- CI present with lint, test, build steps and coverage reporting

Fair (70-84):
- Build pipeline present but missing pieces (e.g. no ngAnnotate or no
  templateCache), or CI present but missing some steps

Weak (0-69):
- No build step (raw `<script>` tags), or no ngAnnotate on a minified build
  (runtime DI breakage risk)
- No CI configured / only partial automation
