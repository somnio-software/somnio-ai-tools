# SOC 2 Project & Tooling Detection

> Detect project type(s), stack, package managers, CI/CD system, IaC, and compliance-relevant tooling to establish the evidence surface for a framework-agnostic SOC 2 readiness audit. Read-only.

---

Goal: Detect the project type(s) and stack so every downstream evidence step
adapts to the technology. SOC 2 controls live across code, IaC, CI/CD, and
documentation, so this step maps the WHOLE evidence surface, not only the app.

READ-ONLY: run detection commands only. Never modify any file in the audited
repository.

PROJECT DETECTION (multi-tech monorepo support):

Detect ALL project types in the repository. For each manifest found, record
(type, basePath). Repository-level control surfaces (`.github/`, IaC, docs)
are recorded once at the repository root.

Priority order when the same directory has multiple manifests: package.json >
pubspec.yaml > go.mod > Cargo.toml > pyproject.toml > build.gradle > pom.xml >
Gemfile > composer.json > .sln/.csproj

```bash
echo "=== MULTI-TECH PROJECT DETECTION ==="

RESULTS=""
SEEN=""

add_project() {
  local ptype="$1"; local base="$2"; local key="${ptype}:${base}"
  if ! echo "$SEEN" | grep -qF "$key"; then
    SEEN="${SEEN}${key}
"
    if [ -z "$RESULTS" ]; then RESULTS="${ptype}@${base}"; else RESULTS="${RESULTS}|${ptype}@${base}"; fi
  fi
}

for f in $(find . -name "package.json" -not -path "*/node_modules/*" 2>/dev/null | head -20); do
  d=$(dirname "$f")
  if grep -q "@nestjs/core" "$f" 2>/dev/null; then add_project "nestjs" "$d";
  elif grep -q "\"next\"" "$f" 2>/dev/null; then add_project "nextjs" "$d";
  else add_project "node" "$d"; fi
done
for f in $(find . -name "pubspec.yaml" -not -path "*/.*" 2>/dev/null | head -20); do add_project "flutter" "$(dirname "$f")"; done
for f in $(find . -name "go.mod" -not -path "*/.*" 2>/dev/null | head -20); do add_project "go" "$(dirname "$f")"; done
for f in $(find . -name "Cargo.toml" -not -path "*/.*" 2>/dev/null | head -20); do add_project "rust" "$(dirname "$f")"; done
for f in $(find . \( -name "pyproject.toml" -o -name "requirements.txt" \) -not -path "*/.*" 2>/dev/null | head -20); do add_project "python" "$(dirname "$f")"; done
for f in $(find . \( -name "build.gradle" -o -name "build.gradle.kts" -o -name "pom.xml" \) -not -path "*/.*" 2>/dev/null | head -20); do add_project "jvm" "$(dirname "$f")"; done
for f in $(find . -name "Gemfile" -not -path "*/.*" 2>/dev/null | head -20); do add_project "ruby" "$(dirname "$f")"; done
for f in $(find . -name "composer.json" -not -path "*/vendor/*" 2>/dev/null | head -20); do add_project "php" "$(dirname "$f")"; done
for f in $(find . \( -name "*.sln" -o -name "*.csproj" \) -not -path "*/.*" 2>/dev/null | head -20); do add_project "dotnet" "$(dirname "$f")"; done

if [ -z "$RESULTS" ]; then RESULTS="generic@."; echo "PROJECT_TYPE=generic"; fi
echo "PROJECT_DETECTION_RESULTS=$RESULTS"
```

CONTROL-SURFACE DETECTION (record presence only; do not read secret values):

```bash
echo ""
echo "=== CONTROL SURFACE DETECTION ==="

# CI/CD system
[ -d .github/workflows ] && echo "CICD=github-actions ($(ls .github/workflows/*.y*ml 2>/dev/null | wc -l | tr -d ' ') workflows)"
[ -f .gitlab-ci.yml ] && echo "CICD=gitlab-ci"
[ -f Jenkinsfile ] && echo "CICD=jenkins"
[ -d .circleci ] && echo "CICD=circleci"
ls azure-pipelines.yml bitbucket-pipelines.yml 2>/dev/null

# Infrastructure as Code
echo "IAC_TERRAFORM=$(find . -name '*.tf' -not -path '*/.terraform/*' 2>/dev/null | head -1)"
ls -d k8s kubernetes helm charts 2>/dev/null
find . -name "*.tf" -o -name "*.bicep" -o -name "cloudformation*.y*ml" -o -name "serverless.y*ml" -o -name "Pulumi.yaml" 2>/dev/null | grep -v node_modules | head -10

# Containerization
ls Dockerfile docker-compose*.y*ml 2>/dev/null

# Governance/policy document surface (family A/B/J artifact presence)
ls SECURITY.md CODEOWNERS CONTRIBUTING.md CODE_OF_CONDUCT.md LICENSE 2>/dev/null
find . -type d \( -iname "compliance" -o -iname "policies" -o -iname "security" \) -not -path "*/node_modules/*" 2>/dev/null | head -10
find . -type d -iname "docs" -not -path "*/node_modules/*" 2>/dev/null | head -5

# Package managers / lock files (supply-chain surface for family E)
ls package-lock.json yarn.lock pnpm-lock.yaml pubspec.lock go.sum Cargo.lock poetry.lock Gemfile.lock composer.lock 2>/dev/null

# Dependency / scanning tooling config (family E/G)
ls .github/dependabot.yml renovate.json .snyk .gitleaks.toml .trivyignore 2>/dev/null
find .github/workflows -type f 2>/dev/null | head -20
```

TOOLING NOTE (optional external CLIs):
- Note whether `trivy`, `grype`, `gitleaks`, `semgrep`, or cloud CLIs are
  available with `command -v <tool>`. Presence is informational; the audit
  never requires them and skips gracefully when absent.

ARTIFACT SAVE (mandatory):
Save the full detection output to: reports/.artifacts/step_01_soc2_project_detection.md
Run before finishing: mkdir -p reports/.artifacts

Output format (in artifact):
- PROJECT_DETECTION_RESULTS: pipe-separated list of type@path (downstream steps
  use this to gather evidence for each project)
- Detected project type(s), framework/runtime, and package manager(s)
- CI/CD system detected (and workflow count)
- IaC present (Terraform / CloudFormation / Kubernetes / Pulumi / none)
- Containerization present (Dockerfile / compose)
- Governance/policy document surface found (paths only)
- Lock files present (supply-chain surface)
- Dependency/secret/vuln scanning config detected
- Repository structure: single app / monorepo / multi-tech monorepo
