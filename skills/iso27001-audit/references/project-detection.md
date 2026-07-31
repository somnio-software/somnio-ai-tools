# ISO 27001 Project & Control-Evidence Toolchain Detection

> Detect all project types in the repository and record the evidence surfaces (source, config, IaC, CI/CD, docs) that later control-evidence steps inspect. Framework-agnostic, whole-project, read-only. This is a readiness / gap assessment, not a certification.

---

Goal: Detect the project type(s) and enumerate the evidence surfaces the
ISO 27001 readiness audit will inspect. This is the first, MANDATORY step.

READ-ONLY DISCIPLINE:
- This step and every downstream step ONLY read the repository. NEVER modify,
  stage, or commit files. NEVER run remediation or install anything into the
  audited repo.

PROJECT DETECTION (execute first - multi-tech monorepo support):

Detect ALL project types in the repository. For each manifest found, record
(type, basePath). An ISMS audit is a WHOLE-PROJECT audit, so audit every
detected stack, not just the first.

Priority order when the same directory has multiple manifests: pubspec.yaml >
package.json > go.mod > Cargo.toml > pyproject.toml > build.gradle > pom.xml >
Package.swift > Podfile > .sln/.csproj > *.tf

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

for f in $(find . -name "pubspec.yaml" -not -path "*/.*" 2>/dev/null | head -20); do add_project "flutter" "$(dirname "$f")"; done
for f in $(find . -name "package.json" -not -path "*/node_modules/*" 2>/dev/null | head -20); do
  d=$(dirname "$f")
  if grep -q "@nestjs/core" "$f" 2>/dev/null; then add_project "nestjs" "$d"; else add_project "nodejs" "$d"; fi
done
for f in $(find . -name "go.mod" -not -path "*/.*" 2>/dev/null | head -20); do add_project "go" "$(dirname "$f")"; done
for f in $(find . -name "Cargo.toml" -not -path "*/.*" 2>/dev/null | head -20); do add_project "rust" "$(dirname "$f")"; done
for f in $(find . \( -name "pyproject.toml" -o -name "requirements.txt" \) -not -path "*/.*" 2>/dev/null | head -20); do add_project "python" "$(dirname "$f")"; done
for f in $(find . \( -name "build.gradle" -o -name "build.gradle.kts" \) -not -path "*/.*" 2>/dev/null | head -20); do add_project "gradle" "$(dirname "$f")"; done
for f in $(find . -name "pom.xml" -not -path "*/.*" 2>/dev/null | head -20); do add_project "maven" "$(dirname "$f")"; done
for f in $(find . -name "Package.swift" -not -path "*/.*" 2>/dev/null | head -20); do add_project "swift" "$(dirname "$f")"; done
for f in $(find . -name "Podfile" -not -path "*/.*" 2>/dev/null | head -20); do add_project "cocoapods" "$(dirname "$f")"; done
for f in $(find . \( -name "*.sln" -o -name "*.csproj" \) -not -path "*/.*" 2>/dev/null | head -20); do add_project "dotnet" "$(dirname "$f")"; done
if find . -name "*.tf" -not -path "*/.*" 2>/dev/null | head -1 | grep -q .; then add_project "terraform" "$(dirname "$(find . -name '*.tf' -not -path '*/.*' 2>/dev/null | head -1)")"; fi

if [ -z "$RESULTS" ]; then
  RESULTS="generic@."
  echo "PROJECT_TYPE=generic"
else
  echo "Detected project types (audit each)."
fi
echo "PROJECT_DETECTION_RESULTS=$RESULTS"
```

EVIDENCE SURFACE ENUMERATION (record what exists - downstream steps use this):

```bash
echo ""
echo "=== EVIDENCE SURFACES ==="

# IaC / infrastructure
echo "-- IaC --"; find . \( -name "*.tf" -o -name "*.tfvars" -o -name "docker-compose*.yml" -o -name "Dockerfile*" -o -name "*.k8s.yaml" -o -path "*/k8s/*" -o -path "*/helm/*" -o -name "serverless.yml" -o -name "*.cloudformation.*" \) -not -path "*/.*" 2>/dev/null | head -40

# CI/CD
echo "-- CI/CD --"; find . \( -path "*/.github/workflows/*" -o -name ".gitlab-ci.yml" -o -name "*.circleci*" -o -name "Jenkinsfile" -o -name "azure-pipelines.yml" -o -name "bitbucket-pipelines.yml" \) -not -path "*/node_modules/*" 2>/dev/null | head -40

# Governance / policy docs
echo "-- Governance docs --"; find . -maxdepth 4 \( -iname "SECURITY.md" -o -iname "CODEOWNERS" -o -iname "*polic*.md" -o -iname "*isms*" -o -iname "*soa*" -o -iname "*statement-of-applicability*" -o -iname "*risk*.md" -o -iname "*incident*.md" -o -iname "*compliance*" -o -path "*/docs/security/*" -o -path "*/docs/compliance/*" -o -path "*/compliance/*" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -60

# Config / secrets management surfaces
echo "-- Config/secrets --"; find . -maxdepth 4 \( -name ".env.example" -o -name ".env.sample" -o -name "*.tfvars.example" -o -name "*secrets*" -o -name "*vault*" -o -name ".gitleaks.toml" -o -name ".pre-commit-config.yaml" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -40
```

STANDARD REFERENCE NOTE:
- ISO/IEC 27001:2022 has 93 Annex A controls in 4 themes: A.5 Organizational
  (37), A.6 People (8), A.7 Physical (14), A.8 Technological (34).
- The audit organizes evidence into 11 categories (A-K). People (A.6) and
  Physical (A.7) controls are documentation-evidence checks.

ARTIFACT SAVE (mandatory):
Save the full detection output to: reports/.artifacts/step_01_iso27001_project_detection.md
Run before finishing: mkdir -p reports/.artifacts

Output format (in artifact):
- PROJECT_DETECTION_RESULTS: pipe-separated list of type@path (downstream
  steps audit each project when multiple are detected)
- Detected project type(s) and technology, source file extensions to scan
- Package manager(s) detected
- Evidence surfaces present: IaC files, CI/CD workflows, governance/policy
  docs, config/secrets-management files (list actual paths found)
- Repository structure: single app / monorepo / multi-tech monorepo
