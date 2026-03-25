# NestJS CI/CD Analysis

> Read all GitHub Actions workflows and related CI/CD configuration files including Docker setup for NestJS projects (single app or monorepo).

---

Goal: Read all GitHub Actions workflows and related CI/CD configuration
files for single app or monorepo repositories.

IMPORTANT EXCLUSIONS:
- Do NOT recommend operational workflows (deployment, monitoring,
  performance tracking)
- Do NOT recommend platform-specific deployment beyond basic Docker
- Focus ONLY on technical CI/CD (lint, test, build, coverage, security)
- Do NOT analyze, recommend, or consider CODEOWNERS files
- Do NOT analyze, recommend, or consider SECURITY.md files
- These are governance decisions, not technical CI/CD requirements

MONOREPO DETECTION:
- First detect repository structure: single app or monorepo
  (nx, turborepo, lerna, apps/ structure)
- If apps/ directory exists, analyze each app individually
- If packages/ or libs/ directory exists, analyze each package/library
  individually

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire analysis
- Read 3-5 workflow files per tool call using parallel reads
- Use batch grep commands to search across all workflow files at once
- Do NOT read workflow files one at a time
- Reference cached artifacts from previous steps when available

SINGLE APP CI/CD ANALYSIS:

1. GitHub Actions Workflows:
   - List all .github/workflows/*.yaml and .github/workflows/*.yml files
   - Read each workflow file completely
   - For each workflow, identify:
     * Trigger events (push, pull_request, schedule)
     * Node.js version matrix
     * Lint steps (ESLint)
     * Format checks (Prettier)
     * Type checking (tsc --noEmit)
     * Test steps (unit, integration, e2e)
     * Coverage thresholds
     * Build steps
     * Security scanning (npm audit, Snyk)
     * Docker build/push
   - CRITICAL: Verify coverage thresholds are >= 70%
   
2. CI/CD Configuration Files:
   - Read .github/dependabot.yaml or .github/dependabot.yml
   - Read .github/PULL_REQUEST_TEMPLATE.md
   - Check for .github/workflows/codeql-analysis.yml (security scanning)
   
3. Docker Configuration:
   - Check for Dockerfile
   - Analyze Dockerfile:
     * Base image (node:18-alpine recommended)
     * Multi-stage build usage
     * Non-root user configuration
     * ENV variable handling
     * WORKDIR setup
     * Dependencies installation
     * Build process
     * Healthcheck configuration
   - Check for .dockerignore
   - Verify .dockerignore patterns:
     * node_modules
     * npm-debug.log
     * .env
     * .git
     * dist (if building in container)
   - Check for docker-compose.yml
   - Analyze docker-compose services:
     * Application service
     * Database service
     * Redis/cache service
     * Environment variables
     * Volume mounts
     * Network configuration

VERIFICATION CHECKLIST FOR SINGLE APP:
- [ ] .github/workflows/ directory exists
- [ ] At least one workflow file present
- [ ] Lint workflow or lint step exists
- [ ] Test workflow or test step exists
- [ ] Build workflow or build step exists
- [ ] Coverage threshold >= 70%
- [ ] Dependabot configuration exists
- [ ] Dockerfile exists (if containerized)
- [ ] .dockerignore exists (if containerized)

MULTI-APP MONOREPO CI/CD ANALYSIS:

1. Root-Level CI/CD:
   - List all .github/workflows/*.yaml and .github/workflows/*.yml files
   - Read each workflow file completely
   - Identify root-level workflows:
     * Lint entire monorepo
     * Test entire monorepo
     * Build all apps
     * Security scanning
     * Dependency updates
   - Check for .github/dependabot.yaml (monorepo configuration)
   - Check for .github/PULL_REQUEST_TEMPLATE.md
   
2. Per-App CI/CD:
   - For each app in apps/ directory:
      * Verify .github/workflows/<app_name>.yaml or
        .github/workflows/<app_name>.yml exists
     * Read app-specific workflow files
     * For each app workflow, identify:
       - Trigger events (path filters for app changes)
       - Node.js version
       - Lint steps specific to app
       - Test steps specific to app
       - Coverage thresholds >= 70%
       - Build steps specific to app
       - Docker build for app
     * Check for apps/<app_name>/Dockerfile
     * Check for apps/<app_name>/.dockerignore
   
3. Package/Library Workflows:
   - For each package in packages/ or libs/:
     * Verify .github/workflows/<package_name>.yaml exists
     * Read package-specific workflow files
     * For each package workflow, identify:
       - Lint steps
       - Test steps
       - Coverage thresholds >= 70%
       - Build steps
       - Publish steps (if publishable)
     * NO dependabot expected in packages/ (root-level only)
     * NO PR template expected in packages/ (root-level only)
   
4. Monorepo-Specific Tools:
   - Check for nx workflow caching
   - Check for turborepo remote caching
   - Check for affected:* commands (nx, lerna)
   - Verify incremental builds
   - Check for parallel job execution

WORKFLOW ANALYSIS DETAILS:

1. Linting and Formatting:
   - Check for "npm run lint" or "yarn lint" or "pnpm lint"
   - Check for "npm run format:check" or similar
   - Verify --max-warnings 0 flag
   - Check for type checking step
   
2. Testing:
   - Check for "npm run test" or "yarn test" or "pnpm test"
   - Check for "npm run test:e2e" or similar
   - Verify test coverage collection
   - CRITICAL: Coverage threshold must be >= 70%
   - Check for test result reporting
   - Check for test artifacts upload
   
3. Building:
   - Check for "npm run build" or "yarn build" or "pnpm build"
   - Verify build artifacts are created
   - Check for build artifact upload/caching
   - Verify production build configuration
   
4. Security:
   - Check for "npm audit" or "yarn audit" or "pnpm audit"
   - Check for Snyk scanning
   - Check for CodeQL analysis
   - Check for dependency review on PRs
   - Verify security scan fails on high/critical issues
   
5. Docker:
   - Check for docker build step
   - Check for docker push to registry
   - Verify image tagging strategy
   - Check for security scanning of images (Trivy, Snyk)
   
6. Performance:
   - Check for job caching (node_modules, build artifacts)
   - Check for matrix strategies (multiple Node versions)
   - Verify parallel job execution
   - Check for conditional job execution (on: paths)

BEST PRACTICES VALIDATION:

1. Workflow Triggers:
   - pull_request triggers for validation
   - push to main/master for deployment
   - schedule for periodic tasks (security scans, dependency updates)
   - Path filters to run only on relevant changes (monorepo)
   
2. Environment Variables:
   - Verify secrets usage (github.secrets)
   - Check for environment-specific variables
   - Verify no hardcoded credentials
   
3. Job Dependencies:
   - Check for proper job ordering (needs: [previous-job])
   - Verify parallel execution where possible
   - Check for fail-fast: false (for matrix)
   
4. Notifications:
   - Check for failure notifications (Slack, email, etc.)
   - Check for PR status checks
   - Verify branch protection rules (implied)

MONOREPO-SPECIFIC CHECKS:

1. Changed Files Detection:
   - Check for path filters in workflows
   - Verify affected:* commands (nx, lerna)
   - Check for conditional job execution
   
2. Cross-Package Dependencies:
   - Verify build order for dependent packages
   - Check for topological build sorting
   
3. Caching Strategy:
   - Check for workspace-level caching
   - Verify per-package caching
   - Check for remote caching (turborepo, nx cloud)

Output format:
- Repository structure type (single app / monorepo with type)
- List all workflow files found (per app if monorepo)
- Document each workflow's checks (per app if monorepo):
  * Lint/format steps
  * Type checking
  * Test steps (unit, integration, e2e)
  * Coverage thresholds
  * Build steps
  * Security scanning
  * Docker build
- Docker configuration analysis (per app if monorepo)
- Dependabot configuration status
- Coverage threshold compliance (list failing if < 70%)
- Missing workflows (per app if monorepo)
- CI/CD configuration completeness (per app if monorepo)
- Best practices compliance (per app if monorepo)
- Monorepo-specific optimizations (if monorepo)
- Missing CI/CD files (.github/dependabot.yaml, etc.)
- Recommendations for improvement (per app if monorepo)

CRITICAL VERIFICATION RULES:
- Single app: Check ONLY .github/ directory
- Monorepo: Check .github/ AND optionally apps/<app>/.github/ directories
- Packages: Check ONLY .github/workflows/<package>.yaml files
- Do NOT expect dependabot/PR template in packages/ directories
- Do NOT recommend CODEOWNERS or SECURITY.md files

CRITICAL: Do NOT report missing CODEOWNERS or SECURITY.md files as CI/CD
configuration gaps.
These are governance decisions, not technical CI/CD requirements.
