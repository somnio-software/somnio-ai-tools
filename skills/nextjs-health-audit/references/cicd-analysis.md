# Next.js CI/CD Analysis

> Read all CI workflow and pipeline configuration files to evaluate automation coverage for a Next.js project: frozen installs, lint, type check, tests, `next build`, `.next/cache` caching and preview deployments.

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
   - `.circleci/config.yml`, `Jenkinsfile`, `bitbucket-pipelines.yml`,
     `.gitlab-ci.yml`, `azure-pipelines.yml`, `buildspec.yml`

3. **Deployment configuration** (record, do not score deployment
   strategy — that is a deployment decision):
   - `vercel.json` (Vercel Git integration builds preview deployments
     per PR without a workflow file — note it so missing preview steps
     are not misreported)
   - `netlify.toml`, `amplify.yml`, `fly.toml`, `render.yaml`
   - `Dockerfile` / `docker-compose.yml`: multi-stage build, Node.js base
     image version matching `.nvmrc`, `output: 'standalone'` copied from
     `.next/standalone`, non-root user

ANALYSIS TARGETS:

4. **Install Step**:
   - Frozen/immutable install: `pnpm install --frozen-lockfile`,
     `npm ci`, `yarn install --immutable` (Berry) / `--frozen-lockfile`
     (Yarn 1), `bun install --frozen-lockfile`. A plain `npm install` /
     `pnpm install` in CI lets the lockfile drift — flag it
   - pnpm setup: `pnpm/action-setup` or `corepack enable` before install,
     honouring the `packageManager` pin
   - Node.js version from `.nvmrc` (`actions/setup-node` with
     `node-version-file: .nvmrc`) vs hard-coded in the workflow (drift risk)
   - Record `PACKAGE MANAGER FINDING: not using pnpm` when CI uses
     npm/yarn (cross-check with `tool-installer.md`)

5. **Lint Step**:
   - `pnpm lint` / `eslint .` in workflows. `next lint` was removed in
     Next.js 16 — a CI step calling it will fail on 16+; flag it
   - Runs on pull requests, not only on push to main

6. **Type Check Step**:
   - `tsc --noEmit` or a `typecheck` script. `next build` also type
     checks unless `typescript.ignoreBuildErrors` is set — if that flag
     is set and there is no separate type-check step, type errors reach
     production unchecked

7. **Test Steps**:
   - Unit/component: `vitest run` / `jest --ci`
   - Coverage reporting (Codecov, Coveralls, an artifact upload)
   - E2E: Playwright (`playwright test`, browser install step,
     `webServer` or a preview URL as base URL) or Cypress
   - Flag missing test step

8. **Build Step**:
   - `next build` (directly or via `pnpm build`) runs in CI on PRs
   - Required env vars for the build provided via secrets / placeholder
     values, not committed `.env` files
   - Monorepo: `turbo run build --filter=...` / affected-only builds

9. **Caching**:
   - Package-manager cache: `actions/setup-node` `cache: pnpm` (or npm/yarn),
     or `actions/cache` on the pnpm store
   - **Next.js build cache**: `.next/cache` persisted between builds —
     GitHub Actions `actions/cache` with
     `${{ github.workspace }}/.next/cache` (per app in a monorepo:
     `apps/<app>/.next/cache`), keyed on the lockfile and source hashes.
     Without it Next.js warns "No Cache Detected" and rebuilds from
     scratch. Vercel configures this automatically. Reference:
     https://nextjs.org/docs/app/guides/ci-build-caching
   - Turborepo remote cache (`TURBO_TOKEN` / `TURBO_TEAM`) in monorepos

10. **Preview Deploys**:
    - PR preview deployments (Vercel/Netlify Git integration, or a
      workflow deploying a preview and commenting the URL)
    - E2E tests running against the preview URL is a strong signal
    - Absence is a recommendation, never a hard penalty (deployment
      decision)

11. **Dependency and supply-chain automation** (presence only):
    - Dependabot / Renovate config (`.github/dependabot.yml`,
      `renovate.json`) covering npm and GitHub Actions
    - `pnpm audit` / `npm audit` step — depth belongs to the
      dependency-security step and `nextjs-security-audit`

12. **Branch Protection signals**:
    - Workflow names that suggest required status checks
    - Triggers for main/master branch

OUTPUT FORMAT:

Provide structured analysis:
- CI/CD system: [GitHub Actions/CircleCI/GitLab/Jenkins/None]
- Workflow files found: [XX]
- Install step: [frozen (command) / non-frozen (command) / Missing]
- Package manager in CI: [pnpm/npm/yarn/bun] (Node.js version source: [.nvmrc/hard-coded])
- Lint step: [Present/Missing/uses removed `next lint`]
- Type check step: [Present/Missing] (ignoreBuildErrors: [Yes/No])
- Unit test step: [Present/Missing]
- E2E test step: [Playwright/Cypress/Missing]
- Coverage reporting: [Present/Missing]
- `next build` step: [Present/Missing]
- Package-manager cache: [Present/Missing]
- `.next/cache` cache: [Present/Missing/Automatic on Vercel]
- Preview deployments: [Vercel/Netlify/workflow/None detected]
- Dependabot/Renovate: [Present/Missing]
- Docker configuration: [Present/Missing] (standalone output used: [Yes/No/N/A])
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Frozen install, lint, type check, tests and `next build` on every PR
- Coverage reporting and E2E tests (ideally against a preview)
- Package-manager cache and `.next/cache` persisted

Fair (70-84):
- CI present but missing some steps (no type check, no E2E, no coverage)
- `.next/cache` not cached, or non-frozen install

Weak (0-69):
- No CI/CD configured
- Only partial automation (e.g., build only), or CI calling `next lint`
  on a Next.js version where it no longer exists
