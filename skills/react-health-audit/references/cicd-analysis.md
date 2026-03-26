# React CI/CD Analysis

> Read all GitHub Actions workflows and CI/CD configuration files to evaluate automation coverage.

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
   - Check multi-stage build usage
   - Check Node.js base image versions

ANALYSIS TARGETS:

4. **Lint Step**:
   - Check for `npm run lint` or `eslint` command in workflows
   - Verify lint runs on PRs and pushes
   - Flag missing lint step

5. **Test Step**:
   - Check for `npm test`, `npm run test:ci`, or `vitest run`
   - Verify tests run with `--ci` flag or equivalent
   - Check for coverage reporting (Codecov, Coveralls, etc.)
   - Flag missing test step

6. **Build Step**:
   - Check for `npm run build` in workflows
   - Verify build artifacts are produced correctly
   - Check for type checking step (`tsc --noEmit`)

7. **Dependency Caching**:
   - Check for `actions/cache` or built-in cache in workflows
   - Verify `node_modules` or package manager cache is cached
   - Note performance impact if caching is missing

8. **Branch Protection**:
   - Check if workflow names suggest required status checks
   - Note workflow triggers for main/master branch

OUTPUT FORMAT:

Provide structured analysis:
- CI/CD system: [GitHub Actions/CircleCI/Jenkins/None]
- Workflow files found: [XX]
- Lint step: [Present/Missing]
- Test step: [Present/Missing]
- Build step: [Present/Missing]
- Type check step: [Present/Missing]
- Coverage reporting: [Present/Missing]
- Dependency caching: [Present/Missing]
- Docker configuration: [Present/Missing]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- CI/CD present with lint, test, build steps
- Coverage reporting configured
- Dependency caching in place

Fair (70-84):
- CI/CD present but missing some steps (e.g., no coverage)
- Caching absent

Weak (0-69):
- No CI/CD configured
- Only partial automation (e.g., build only)
