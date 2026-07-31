# SOC 2 Secure Development & Change Management (Family E)

> Gather PLATFORM-AUDITABLE evidence for secure development and change management — documented SDLC, dev/test/prod separation, PR review and branch protection, tested/approved changes, emergency-change path, dependency/SAST/vulnerability scanning in the pipeline, migration discipline, and patching SLAs (CC7.1, CC8.1). Framework-agnostic. Read-only.

---

Goal: Assess how changes are authorized, reviewed, tested, and scanned before
reaching production. Family E is heavily PLATFORM-AUDITABLE from CI/CD config,
repository settings evidence, and IaC. Record Status + Owner/lane + evidence.

PROJECT DETECTION (execute first):
- Read reports/.artifacts/step_01_soc2_project_detection.md for the CI/CD
  system, IaC presence, and lock files.

CONTROL RECORDING FORMAT: control ref (e.g. `E1`), criterion, Status, Owner/lane,
Evidence.

EVIDENCE GATHERING:

1. PR review requirement & branch protection (CC8.1):
```bash
echo "=== E: PR REVIEW & BRANCH PROTECTION ==="
ls .github/CODEOWNERS CODEOWNERS 2>/dev/null && echo "CODEOWNERS present (review routing)"
ls .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE* 2>/dev/null
find . -path "*.github/*" -name "*.yml" -o -path "*.github/*" -name "*.yaml" 2>/dev/null | head -20
# Repository ruleset / branch-protection config committed to repo (if any)
grep -rniE "required_pull_request_reviews|required_status_checks|branch.?protection|dismiss_stale|require_code_owner" .github/ 2>/dev/null | head -10 || echo "No committed branch-protection config (may be set in repo settings - ORGANIZATIONAL evidence)"
```

2. CI pipeline & gates — lint / test / build (CC8.1):
```bash
echo "=== E: CI GATES ==="
for wf in .github/workflows/*.y*ml; do [ -f "$wf" ] && echo "--- $wf ---" && grep -niE "lint|eslint|test|jest|vitest|pytest|go test|rspec|phpunit|build|tsc|compile" "$wf" 2>/dev/null | head -8; done
# Other CI systems
grep -niE "lint|test|build" .gitlab-ci.yml Jenkinsfile bitbucket-pipelines.yml azure-pipelines.yml 2>/dev/null | head -15
```

3. Dependency / SAST / vulnerability scanning in the pipeline (CC7.1, CC8.1):
```bash
echo "=== E: PIPELINE SCANNING ==="
ls .github/dependabot.yml renovate.json .snyk 2>/dev/null
grep -rniE "dependabot|renovate|snyk|npm audit|yarn audit|pip-audit|trivy|grype|codeql|semgrep|sonar|gitleaks|trufflehog|osv-scanner" .github/ .gitlab-ci.yml Jenkinsfile 2>/dev/null | head -20 || echo "No dependency/SAST/secret scanning in pipeline detected"
```

4. Dev/test/prod separation & IaC (CC8.1):
```bash
echo "=== E: ENVIRONMENT SEPARATION & IaC ==="
find . -type d \( -iname "environments" -o -iname "envs" -o -iname "stages" \) -not -path "*/node_modules/*" 2>/dev/null | head -10
ls .env.example .env.sample 2>/dev/null
find . -name "*.tf" -not -path "*/.terraform/*" 2>/dev/null | head -10
grep -rniE "environment[s]?\s*[:=]|staging|production|prod|dev\b" .github/workflows/ 2>/dev/null | head -10
```

5. Migration discipline (CC8.1):
```bash
echo "=== E: MIGRATION DISCIPLINE ==="
find . -type d \( -iname "migrations" -o -iname "migrate" \) -not -path "*/node_modules/*" 2>/dev/null | head -10
grep -rniE "migration|typeorm migration|prisma migrate|alembic|flyway|liquibase|knex migrate|rails db:migrate" \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.json" . 2>/dev/null | grep -v "node_modules\|dist" | head -10 || echo "No migration tooling detected"
```

6. Patching SLAs & release process (CC7.1, CC8.1):
```bash
echo "=== E: PATCHING & RELEASE PROCESS ==="
ls CHANGELOG.md RELEASING.md release.config.js .releaserc* 2>/dev/null
find . -type f -not -path "*/node_modules/*" \( -iname "*patch*policy*" -o -iname "*sdlc*" -o -iname "*change-management*" \) 2>/dev/null | head -10
grep -rniE "semantic-release|changesets|conventional|version" package.json 2>/dev/null | head -5
```

Controls to record (PLATFORM-AUDITABLE unless noted):
- E1 Documented SDLC (CC8.1) — may be ORGANIZATIONAL (doc artifact)
- E2 Dev/test/prod separation (CC8.1)
- E3 PR review required / branch protection (CC8.1)
- E4 Changes tested before merge — CI test gate (CC8.1)
- E5 Emergency-change path documented (CC8.1) — ORGANIZATIONAL
- E6 Dependency scanning in pipeline (CC7.1)
- E7 SAST in pipeline (CC7.1)
- E8 Secret scanning in pipeline (CC7.1)
- E9 Migration discipline (CC8.1)
- E10 Patching SLA / release process (CC7.1) — SLA doc may be ORGANIZATIONAL

STATUS RULES:
- Gate present and enforced in CI -> met. Present but not blocking -> partial.
- Branch protection not committed to repo -> partial/organizational (note it
  may be configured in repo settings, which the audit cannot read).
- No evidence -> gap; state the exact evidence that would satisfy it.

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/step_05_soc2_change_management.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Family E control table (control ref, criterion, Status, Owner/lane, Evidence path)
- CI gate inventory (lint/test/build/scan per workflow)
- Gaps with the exact evidence that would satisfy each
