# .NET Health Audit CI/CD Analysis

> Read CI/CD pipeline configuration and Docker setup for ASP.NET Core Web API projects to verify build, test, and deployment automation.

---

Goal: Detect the CI provider in use, verify the pipeline runs restore/build/test/coverage/format
steps, and assess SDK pinning, dependency caching, containerization, and publish/deploy readiness.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire analysis
- List `.github/workflows/`, root files (`azure-pipelines.yml`, `.gitlab-ci.yml`), and `Dockerfile`
  in a single batched pass
- Read all matching pipeline files in parallel rather than one at a time
- Use batch grep across workflow/pipeline files to find `dotnet restore|build|test|format` and
  `actions/setup-dotnet` in one pass instead of per-file searches
- Reference cached artifacts (e.g. `global.json` SDK version from config-analysis) instead of
  re-reading files already inspected in a prior step

1. CI PROVIDER DETECTION:
   - GitHub Actions: list `.github/workflows/*.yml` and `.github/workflows/*.yaml`
   - Azure Pipelines: check for `azure-pipelines.yml` (root or `.azuredevops/`)
   - GitLab CI: check for `.gitlab-ci.yml`
   - Read whichever provider's file(s) are present; if multiple exist, analyze each and note
     the duplication
   - If none present, record "No CI/CD configuration detected" and skip to recommendations

2. PIPELINE STEPS PRESENT:
   - Verify `dotnet restore` (or implicit restore via `dotnet build`/`dotnet test`) runs before
     build
   - Verify `dotnet build -c Release` (or equivalent `--configuration Release`) step exists
   - Verify `dotnet test` step exists and check for coverage collection flags:
     * `--collect:"XPlat Code Coverage"` (coverlet.collector, the .NET 8 default)
     * `/p:CollectCoverage=true` (coverlet.msbuild)
     * `dotnet-coverage collect` (Microsoft.CodeCoverage CLI tool)
   - Check for `dotnet format --verify-no-changes` (or `dotnet format whitespace --verify-no-changes`)
     as a formatting gate — flag as a missed opportunity if absent, not a hard failure
   - Check for `dotnet build` warnings-as-errors enforcement in CI (may duplicate
     `TreatWarningsAsErrors` from csproj — cross-reference code-quality step)

3. SDK PINNING (setup-dotnet / equivalent):
   - GitHub Actions: look for `actions/setup-dotnet@v4` (or v3) step with a `dotnet-version` input
   - Azure Pipelines: look for `UseDotNet@2` task with `version` input
   - GitLab CI: look for an explicit `mcr.microsoft.com/dotnet/sdk:8.0` image pin
   - Cross-reference the pinned version against `global.json`'s `sdk.version` (from config-analysis
     step, if available) — flag a mismatch as a risk (CI could silently drift from local dev SDK)
   - If no `global.json` exists and no explicit version pin in CI, flag "unpinned SDK version" as
     a reproducibility risk

4. NUGET CACHING:
   - GitHub Actions: look for `actions/cache@v4` (or `actions/setup-dotnet`'s built-in
     `cache: true` / `cache-dependency-path` inputs) keyed on `packages.lock.json` or `**/*.csproj`
     hashes
   - Azure Pipelines: look for a `Cache@2` task targeting `~/.nuget/packages`
   - GitLab CI: look for a `cache:` block keyed on `**/*.csproj` or `packages.lock.json`
   - Missing caching is a build-speed opportunity, not a correctness failure — note it as a
     recommendation, not a risk

5. DOCKER:
   - Check for a `Dockerfile` (root or `src/<Project>/Dockerfile`)
   - Verify multi-stage build pattern:
     * Build/publish stage: `FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build`
     * Runtime stage: `FROM mcr.microsoft.com/dotnet/aspnet:8.0`
     * `dotnet restore`, `dotnet publish -c Release -o /app` in the build stage
     * `COPY --from=build /app .` into the runtime stage
   - FLAG as bloated/insecure: single-stage Dockerfiles that `FROM mcr.microsoft.com/dotnet/sdk`
     for the final image (ships the full SDK + compilers in production, larger attack surface and
     image size)
   - Check for `.dockerignore` excluding `bin/`, `obj/`, `.git`, `*.user`
   - Check for a non-root `USER` directive in the runtime stage (security best practice)

6. PUBLISH/DEPLOY STEP:
   - Check for `dotnet publish -c Release` (with `-o`/`--output` or
     `--self-contained`/`-r <RID>` for runtime-specific publishes)
   - Check for build artifact upload (`actions/upload-artifact`, `PublishBuildArtifacts@1`)
   - Check for a containerized deploy step: `docker build` + `docker push` to a registry
     (ACR, ECR, GHCR, Docker Hub), or a deploy task targeting Azure App Service / AKS / ECS
   - If no publish/deploy step exists, note the pipeline is build/test-only (may be intentional
     for a library or internal service — do not over-penalize without deploy context)

7. QUALITY GATES:
   - Check whether `dotnet test` failures are configured to fail the job (default behavior unless
     `continue-on-error: true` / `continueOnError: true` is set — flag if present, as it silently
     masks failing tests)
   - Best-effort branch protection check: look for a `CODEOWNERS` reference to required reviewers
     or a documented required-status-checks list in repo docs/README — note explicitly that full
     branch protection state is a GitHub/Azure DevOps setting not fully visible from repo files
     alone
   - Check for a required coverage threshold gate (e.g. a step that fails below a coverage %,
     ReportGenerator threshold check, or a SonarQube/SonarCloud quality gate)

OUTPUT FORMAT:

Provide structured analysis:
- CI provider detected: [GitHub Actions/Azure Pipelines/GitLab CI/None]
- Pipeline steps present: restore [Yes/No], build [Yes/No], test [Yes/No], format check [Yes/No]
- Coverage collection in CI: [Yes/No] (mechanism: [XPlat Code Coverage/coverlet.msbuild/dotnet-coverage/None])
- SDK pinning in CI: [Yes/No] (version: [X.X], matches global.json: [Yes/No/N-A])
- NuGet caching: [Yes/No]
- Dockerfile present: [Yes/No], multi-stage: [Yes/No], non-root user: [Yes/No]
- Publish/deploy step present: [Yes/No] (mechanism: [artifact upload/container push/platform deploy/None])
- Quality gates: test failures block merge [Yes/No], coverage threshold gate [Yes/No], branch
  protection [best-effort note]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- CI provider detected with restore, build, test (with coverage collection), and format-check
  steps all present
- SDK version explicitly pinned in CI and matches `global.json`
- NuGet caching configured
- Multi-stage Dockerfile with non-root runtime user, or a clear publish/deploy step present
- Test failures block the pipeline; no `continue-on-error` masking test steps

Fair (70-84):
- CI provider detected with restore, build, and test steps, but missing coverage collection or
  format-check
- SDK version not explicitly pinned, or pinned but mismatched with `global.json`
- No NuGet caching configured
- Dockerfile present but single-stage, or missing `.dockerignore`

Weak (0-69):
- No CI/CD configuration detected, or pipeline only builds without running tests
- Test failures do not block the pipeline (`continue-on-error` on test step)
- Dockerfile uses the SDK image for the runtime stage (bloated/insecure), or no Dockerfile despite
  a containerized deployment target
- No publish/deploy step and no artifact output of any kind
