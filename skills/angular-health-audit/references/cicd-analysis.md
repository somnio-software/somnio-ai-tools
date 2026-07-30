# Angular CI/CD Analysis

> Read all GitHub Actions workflows and CI/CD configuration files to evaluate automation coverage for an Angular project.

---

Goal: Read and analyze all CI/CD workflow files found in the
repository to assess automation quality.

EFFICIENCY REQUIREMENTS:
- Read all workflow files in one batch
- Do NOT execute workflows — only analyze their configuration

FILES TO ANALYZE:

1. **GitHub Actions**:
   - Read all files in `.github/workflows/`
   - Identify workflow triggers (push, pull_request, schedule)
   - List all jobs and their steps

2. **Other CI Configurations** (if present):
   - `.circleci/config.yml`
   - `Jenkinsfile`
   - `bitbucket-pipelines.yml`
   - `gitlab-ci.yml`

3. **Docker Files**:
   - `Dockerfile`, `docker-compose.yml`
   - Check multi-stage build usage (build stage + nginx static-serve stage
     is the common Angular pattern)
   - Check Node.js base image versions

ANALYSIS TARGETS:

4. **Lint Step**:
   - Check for `npm run lint`, `ng lint`, or `nx lint` in workflows
   - Verify lint runs on PRs and pushes
   - Flag missing lint step

5. **Test Step**:
   - Check for `ng test` / `npm test` run headless in CI, e.g.
     `ng test --watch=false --browsers=ChromeHeadless` (Karma) or
     `jest --ci` (Jest builder)
   - Verify tests run non-interactively (no watch mode)
   - Check for coverage reporting (Codecov, Coveralls, `--code-coverage`)
   - Flag missing test step

6. **Build Step**:
   - Check for `ng build --configuration production` (or `npm run build`)
     in workflows
   - Verify production build artifacts are produced
   - Angular build already type-checks via ngc; a separate `tsc --noEmit`
     is optional

7. **Dependency Caching**:
   - Check for `actions/cache` or `setup-node` built-in cache
   - Verify `node_modules` / package-manager cache and (for Nx) the Nx
     cache are cached
   - Note performance impact if caching is missing

8. **Branch Protection**:
   - Check if workflow names suggest required status checks
   - Note workflow triggers for main/master branch

OUTPUT FORMAT:

Provide structured analysis:
- CI/CD system: [GitHub Actions/CircleCI/Jenkins/None]
- Workflow files found: [XX]
- Lint step (ng lint): [Present/Missing]
- Test step (headless ng test / jest): [Present/Missing]
- Production build step: [Present/Missing]
- Coverage reporting: [Present/Missing]
- Dependency caching: [Present/Missing]
- Docker configuration: [Present/Missing]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- CI/CD present with lint, headless test, and production build steps
- Coverage reporting configured
- Dependency caching in place

Fair (70-84):
- CI/CD present but missing some steps (e.g., no coverage)
- Caching absent

Weak (0-69):
- No CI/CD configured
- Only partial automation (e.g., build only)
