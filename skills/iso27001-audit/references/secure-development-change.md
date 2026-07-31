# Category E - Secure Development & Change Management Evidence (A.8.25-A.8.28, A.8.31, A.8.32, A.8.9)

> Gather in-repo evidence for the secure SDLC, dev/test/prod separation, secure coding, change management, configuration management, and application security testing. Framework-agnostic, read-only. Heavily PLATFORM-AUDITABLE - score it heavily.

---

Goal: Determine whether the repository demonstrates a secure development
lifecycle and controlled change management. Record Status + Owner/lane per
control.

PROJECT DETECTION (execute first):
- Read `reports/.artifacts/step_01_iso27001_project_detection.md` for
  PROJECT_DETECTION_RESULTS and CI/CD surfaces.

CONTROL EVIDENCE:

A.8.25 Secure development lifecycle (PLATFORM-AUDITABLE) - documented SDLC,
branch protection, PR templates, review gates:
```bash
find . \( -path "*/.github/*" -name "*.md" -o -name "CONTRIBUTING.md" -o -path "*/.github/pull_request_template*" -o -path "*/.github/workflows/*" \) -not -path "*/node_modules/*" 2>/dev/null | head -30
find . -maxdepth 5 -iname "*sdlc*" -o -iname "*secure*develop*" 2>/dev/null | grep -v node_modules | head -10 || echo "No documented SDLC artifact found"
```

A.8.26 Application security requirements / A.8.27 Secure system architecture
(PLATFORM-AUDITABLE / ORGANIZATIONAL) - threat models, security requirements,
architecture docs:
```bash
find . -maxdepth 5 \( -iname "*threat*model*" -o -iname "*security*require*" -o -iname "*architecture*" -o -path "*/docs/adr/*" -o -iname "*.mmd" \) -not -path "*/node_modules/*" 2>/dev/null | head -25 || echo "No security-requirements/architecture artifacts found"
```

A.8.28 Secure coding (PLATFORM-AUDITABLE) - linters, static analysis config,
secure-coding standards, input validation:
```bash
find . \( -name ".eslintrc*" -o -name ".pylintrc" -o -name "ruff.toml" -o -name ".rubocop.yml" -o -name "analysis_options.yaml" -o -name ".golangci.yml" -o -name "tslint.json" -o -name ".editorconfig" \) -not -path "*/node_modules/*" 2>/dev/null | head -20 || echo "No linter/static-analysis config found"
grep -rniE "class-validator|@IsString|joi|zod|yup|pydantic|validate|sanitiz|escape|parameterized" . 2>/dev/null | grep -vE "node_modules|dist|test" | head -15 || echo "No input-validation evidence found"
```

A.8.29 Security testing in development and acceptance (PLATFORM-AUDITABLE) -
SAST/DAST/security tests in CI (also feeds Category G):
```bash
grep -rniE "codeql|semgrep|snyk|sonar|bandit|gosec|brakeman|owasp|zap|dast|sast|security.?test" $(find . -path "*/.github/workflows/*" -o -name ".gitlab-ci.yml" 2>/dev/null | grep -v node_modules | head -20) 2>/dev/null | head -20 || echo "No security-testing-in-CI evidence found"
```

A.8.31 Separation of development, test and production environments
(PLATFORM-AUDITABLE) - per-env config, IaC workspaces/envs:
```bash
find . \( -name ".env.development" -o -name ".env.staging" -o -name ".env.production" -o -name ".env.test" -o -path "*environments/*" -o -path "*/env/*" -o -name "*.staging.*" -o -name "*.production.*" \) -not -path "*/node_modules/*" 2>/dev/null | head -30 || echo "No environment-separation evidence found"
grep -rniE "workspace|terraform.workspace|NODE_ENV|APP_ENV|stage|environment" . --include=*.tf --include=*.yml --include=*.yaml 2>/dev/null | grep -v node_modules | head -15 || echo "No environment-config evidence found"
```

A.8.32 Change management (PLATFORM-AUDITABLE) - PR-based flow, required
reviews, CODEOWNERS, protected branches, changelog:
```bash
find . \( -iname "CODEOWNERS" -o -iname "CHANGELOG*" -o -path "*/.github/pull_request_template*" \) -not -path "*/node_modules/*" 2>/dev/null | head -15 || echo "No change-management artifacts found"
grep -rniE "required_?reviews|require pull request|branch protection|approvals" $(find . -path "*/.github/*" 2>/dev/null | head -20) 2>/dev/null | head -10 || echo "No documented branch-protection evidence in-repo (may be configured in the git host settings - CLIENT/ORGANIZATIONAL)"
```

A.8.9 Configuration management (PLATFORM-AUDITABLE) - IaC, config as code,
hardened baselines:
```bash
find . \( -name "*.tf" -o -name "docker-compose*.yml" -o -name "Dockerfile*" -o -path "*/k8s/*" -o -path "*/helm/*" -o -name "ansible*" -o -name "*.hcl" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -30 || echo "No configuration-as-code / IaC evidence found"
```

READ-ONLY + SECRET SAFETY: read only; redact secret VALUES as `[REDACTED]`.

ARTIFACT SAVE (mandatory):
Save output to: reports/.artifacts/step_06_iso27001_secure_development_change.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Category E control table: Annex A ref | control name | Status | Owner/lane |
  evidence (path) or "No evidence found" | gap + satisfying artifact
- Note where branch-protection enforcement lives in git-host settings
  (ORGANIZATIONAL / not fully verifiable from the repo alone)
- Summary: count of Met / Partial / Gap / Organizational
