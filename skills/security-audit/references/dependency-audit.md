# Security Dependency Audit

> Run package-manager-native vulnerability scans and identify outdated or vulnerable dependencies. Framework-agnostic with runtime project type detection.

---

Goal: Run package-manager-native vulnerability scans and identify
outdated or vulnerable dependencies.

PROJECT DETECTION (execute first):
- Read reports/.artifacts/security-audit/step_01_security_tool_installer.md for
  PROJECT_DETECTION_RESULTS (format: type@path|type@path...)
- If multiple projects: for each type@path, cd to path and run
  dependency audit for that project; concatenate all results
- If single project: run from project root
- Per-type tools: Flutter (pub), Node/NestJS (npm/yarn/pnpm),
  Go (go, govulncheck), Rust (cargo audit), Python (pip audit),
  Gradle/Maven, Swift (pod, swift), .NET (dotnet)

DEPENDENCY AUDIT PER PROJECT TYPE:

Flutter/Dart:
```bash
echo "=== Flutter/Dart Dependency Audit ==="
# Check for outdated packages
fvm flutter pub outdated 2>/dev/null || flutter pub outdated 2>/dev/null \
  || echo "pub outdated failed"

# Check dependency tree
fvm flutter pub deps --style=compact 2>/dev/null | head -50 \
  || flutter pub deps --style=compact 2>/dev/null | head -50 \
  || echo "pub deps failed"

# Classify path: and git: dependencies across all pubspec.yaml files
echo ""
echo "=== Path/Git Dependency Classification ==="
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
echo "Repo root: $REPO_ROOT"

# Use Python to reliably parse YAML path: entries and classify them
find . -name "pubspec.yaml" -not -path "*/.*" -not -path "*/build/*" 2>/dev/null | while IFS= read -r pubspec; do
  PUBSPEC_DIR=$(dirname "$pubspec")
  python3 - "$pubspec" "$PUBSPEC_DIR" "$REPO_ROOT" <<'PYEOF' 2>/dev/null
import sys, os, re

pubspec_path, pubspec_dir, repo_root = sys.argv[1], sys.argv[2], sys.argv[3]
repo_root = os.path.realpath(repo_root)

try:
    content = open(pubspec_path).read()
except:
    sys.exit(0)

current_pkg = None
for line in content.splitlines():
    pkg_match = re.match(r'^  (\S+):\s*$', line)
    if pkg_match:
        current_pkg = pkg_match.group(1)
        continue
    path_match = re.match(r'^\s+path:\s+(.+)$', line)
    if path_match and current_pkg:
        raw = path_match.group(1).strip().strip('"\'')
        if os.path.isabs(raw):
            resolved = os.path.realpath(raw)
        else:
            resolved = os.path.realpath(os.path.join(pubspec_dir, raw))
        if resolved.startswith(repo_root):
            print(f"PATH_INTERNAL|{current_pkg}|{raw}")
        else:
            print(f"PATH_EXTERNAL|{current_pkg}|{raw}")
        current_pkg = None
        continue
    git_match = re.match(r'^\s+git:\s*$', line)
    if git_match and current_pkg:
        print(f"GIT_SOURCED|{current_pkg}")
        current_pkg = None
PYEOF
done

echo ""
echo "Classification legend:"
echo "  PATH_INTERNAL = path resolves inside repo root — in-repo/monorepo package, NOT a supply-chain risk"
echo "  PATH_EXTERNAL = absolute path or resolves outside repo root — flag as supply-chain risk (-5 each)"
echo "  GIT_SOURCED   = git-sourced dep — flag as supply-chain risk (-10 each)"
```

NestJS/Node.js:
```bash
echo "=== Node.js Dependency Audit ==="
# Detect package manager
if [ -f "pnpm-lock.yaml" ]; then
  PM="pnpm"
elif [ -f "yarn.lock" ]; then
  PM="yarn"
else
  PM="npm"
fi
echo "Package manager: $PM"

# Run vulnerability audit
if [ "$PM" = "npm" ]; then
  npm audit --json 2>/dev/null | head -100 || npm audit 2>/dev/null | head -50
elif [ "$PM" = "yarn" ]; then
  yarn audit --json 2>/dev/null | head -100 || yarn audit 2>/dev/null | head -50
elif [ "$PM" = "pnpm" ]; then
  pnpm audit --json 2>/dev/null | head -100 || pnpm audit 2>/dev/null | head -50
fi

# Check for outdated packages
$PM outdated 2>/dev/null | head -30 || echo "outdated check skipped"

# Verify lock file integrity
if [ "$PM" = "npm" ]; then
  echo "Lock file: package-lock.json $([ -f package-lock.json ] && echo 'EXISTS' || echo 'MISSING')"
elif [ "$PM" = "yarn" ]; then
  echo "Lock file: yarn.lock $([ -f yarn.lock ] && echo 'EXISTS' || echo 'MISSING')"
elif [ "$PM" = "pnpm" ]; then
  echo "Lock file: pnpm-lock.yaml $([ -f pnpm-lock.yaml ] && echo 'EXISTS' || echo 'MISSING')"
fi
```

Go:
```bash
echo "=== Go Dependency Audit ==="
# Check for vulnerabilities using govulncheck if available
if command -v govulncheck &> /dev/null; then
  govulncheck ./... 2>/dev/null | head -50 || echo "govulncheck failed"
else
  echo "govulncheck not installed (install: go install golang.org/x/vuln/cmd/govulncheck@latest)"
fi
# Check for outdated modules
go list -m -u all 2>/dev/null | head -30 || echo "go list failed"
```

Rust:
```bash
echo "=== Rust Dependency Audit ==="
if command -v cargo-audit &> /dev/null; then
  cargo audit 2>/dev/null | head -50 || echo "cargo audit failed"
else
  echo "cargo-audit not installed (install: cargo install cargo-audit)"
fi
```

Python:
```bash
echo "=== Python Dependency Audit ==="
if command -v pip-audit &> /dev/null; then
  pip-audit 2>/dev/null | head -50 || echo "pip-audit failed"
elif command -v safety &> /dev/null; then
  safety check 2>/dev/null | head -50 || echo "safety check failed"
else
  echo "No Python audit tool found (install: pip install pip-audit)"
fi
```

Java/Kotlin (Gradle):
```bash
echo "=== Java/Kotlin Gradle Dependency Audit ==="
if [ -f "gradlew" ]; then
  ./gradlew dependencyCheckAnalyze 2>/dev/null | head -80 \
    || echo "dependencyCheckAnalyze failed (requires OWASP plugin)"
  ./gradlew dependencies --configuration compileClasspath 2>/dev/null \
    | head -50 || echo "dependencies failed"
else
  echo "No gradlew found"
fi
```

Java/Kotlin (Maven):
```bash
echo "=== Java/Kotlin Maven Dependency Audit ==="
if [ -f "pom.xml" ]; then
  mvn dependency-check:check 2>/dev/null | head -80 \
    || echo "dependency-check failed (requires OWASP plugin)"
  mvn dependency:tree 2>/dev/null | head -50 || echo "dependency:tree failed"
else
  echo "No pom.xml found"
fi
```

Swift (CocoaPods):
```bash
echo "=== Swift CocoaPods Dependency Audit ==="
if [ -f "Podfile" ] && command -v pod &> /dev/null; then
  pod outdated 2>/dev/null | head -30 || echo "pod outdated failed"
  pod list 2>/dev/null | head -30 || echo "pod list failed"
else
  echo "Podfile not found or CocoaPods not installed"
fi
```

Swift (SPM):
```bash
echo "=== Swift Package Manager Audit ==="
if [ -f "Package.swift" ] && command -v swift &> /dev/null; then
  swift package show-dependencies 2>/dev/null | head -50 \
    || echo "swift package show-dependencies failed"
  echo "Note: SPM has no built-in vulnerability scan; consider Xcode \
    or third-party tools"
else
  echo "Package.swift not found or swift not in PATH"
fi
```

.NET:
```bash
echo "=== .NET Dependency Audit ==="
if command -v dotnet &> /dev/null; then
  PROJ=$(find . -maxdepth 2 -name "*.sln" 2>/dev/null | head -1)
  [ -z "$PROJ" ] && PROJ=$(find . -maxdepth 2 -name "*.csproj" 2>/dev/null | head -1)
  if [ -n "$PROJ" ]; then
    dotnet list "$PROJ" package --vulnerable --include-transitive 2>/dev/null \
      | head -80 || echo "dotnet list package --vulnerable failed"
  else
    echo "No .sln or .csproj found"
  fi
else
  echo "dotnet CLI not found"
fi
```

AUTOMATED SECURITY TOOLING CHECK (ALL project types):
```bash
echo ""
echo "=== Automated Security Tooling ==="

# --- Automated Dependency Updates (platform-agnostic) ---
# Priority: Dependabot (GitHub) > Renovate (any platform) > GitLab built-in DS
DEP_UPDATE_TOOL=""
if [ -f ".github/dependabot.yml" ] || [ -f ".github/dependabot.yaml" ]; then
  DEP_UPDATE_TOOL="Dependabot"
  cat .github/dependabot.y*ml 2>/dev/null | head -30
elif [ -f "renovate.json" ] || [ -f "renovate.json5" ] || \
     [ -f ".renovaterc" ] || [ -f ".renovaterc.json" ] || [ -f ".renovaterc.json5" ] || \
     [ -f ".github/renovate.json" ] || [ -f ".gitlab/renovate.json" ] || \
     ([ -f "package.json" ] && grep -q '"renovate"' package.json 2>/dev/null); then
  DEP_UPDATE_TOOL="Renovate"
elif [ -f ".gitlab-ci.yml" ] && grep -qE "dependency.scanning|Dependency-Scanning\.gitlab-ci\.yml|gemnasium|DEPENDENCY_SCANNING" .gitlab-ci.yml 2>/dev/null; then
  DEP_UPDATE_TOOL="GitLab Dependency Scanning"
fi

if [ -n "$DEP_UPDATE_TOOL" ]; then
  echo "DepUpdate: CONFIGURED ($DEP_UPDATE_TOOL)"
else
  echo "DepUpdate: NOT CONFIGURED"
fi

# --- CI Platform Detection ---
echo ""
echo "=== CI Platform Detection ==="
CI_DETECTED=""
[ -d ".github/workflows" ]       && echo "CI: GitHub Actions (.github/workflows/)"           && CI_DETECTED="YES"
[ -f ".gitlab-ci.yml" ]          && echo "CI: GitLab CI (.gitlab-ci.yml)"                    && CI_DETECTED="YES"
[ -f "bitbucket-pipelines.yml" ] && echo "CI: Bitbucket Pipelines (bitbucket-pipelines.yml)" && CI_DETECTED="YES"
[ -z "$CI_DETECTED" ] && echo "CI: NONE DETECTED"

# --- CI/CD Security Scanning (GitHub Actions, GitLab CI, Bitbucket Pipelines) ---
echo ""
echo "=== CI Security Scanning ==="
SECURITY_KEYWORDS="npm audit|yarn audit|pnpm audit|snyk|trivy|grype|safety|pip.audit|cargo.audit|govulncheck|dependencyCheck|dependency-check|dotnet.*package|dependency.scanning|container.scanning|secret.detection|gemnasium"

CI_SCAN_FOUND=""
[ -d ".github/workflows" ]       && grep -rlE "$SECURITY_KEYWORDS" .github/workflows/ 2>/dev/null      | grep -q . && CI_SCAN_FOUND="YES" && echo "Security scanning in GitHub Actions: YES"
[ -f ".gitlab-ci.yml" ]          && grep -qE  "$SECURITY_KEYWORDS" .gitlab-ci.yml 2>/dev/null          && CI_SCAN_FOUND="YES" && echo "Security scanning in GitLab CI: YES"
[ -f "bitbucket-pipelines.yml" ] && grep -qE  "$SECURITY_KEYWORDS" bitbucket-pipelines.yml 2>/dev/null && CI_SCAN_FOUND="YES" && echo "Security scanning in Bitbucket Pipelines: YES"
[ -z "$CI_SCAN_FOUND" ] && echo "CI_SECURITY_SCANNING: NOT CONFIGURED"

# --- CI runs on PRs / MRs ---
echo ""
echo "=== CI PR/MR Trigger Detection ==="
PR_TRIGGER_FOUND=""
[ -d ".github/workflows" ]       && grep -rlE "pull_request"                 .github/workflows/ 2>/dev/null | grep -q . && PR_TRIGGER_FOUND="YES" && echo "PR trigger: GitHub Actions pull_request"
[ -f ".gitlab-ci.yml" ]          && grep -qE  "merge_request|merge_requests"  .gitlab-ci.yml 2>/dev/null               && PR_TRIGGER_FOUND="YES" && echo "PR trigger: GitLab CI merge_request"
[ -f "bitbucket-pipelines.yml" ] && grep -q   "pull-requests"                 bitbucket-pipelines.yml 2>/dev/null        && PR_TRIGGER_FOUND="YES" && echo "PR trigger: Bitbucket Pipelines pull-requests"
[ -z "$PR_TRIGGER_FOUND" ] && echo "CI_PR_TRIGGERS: NOT CONFIGURED"

# --- Lock file validation in CI ---
echo ""
echo "=== Lock File Validation in CI ==="
LOCKFILE_PATTERN="npm ci|--frozen-lockfile|cargo --locked|pip install --require-hashes|poetry install --no-root"
LOCKFILE_CI_FOUND=""
[ -d ".github/workflows" ]       && grep -rlE "$LOCKFILE_PATTERN" .github/workflows/ 2>/dev/null       | grep -q . && LOCKFILE_CI_FOUND="YES" && echo "Lock file validation in GitHub Actions: YES"
[ -f ".gitlab-ci.yml" ]          && grep -qE  "$LOCKFILE_PATTERN" .gitlab-ci.yml 2>/dev/null           && LOCKFILE_CI_FOUND="YES" && echo "Lock file validation in GitLab CI: YES"
[ -f "bitbucket-pipelines.yml" ] && grep -qE  "$LOCKFILE_PATTERN" bitbucket-pipelines.yml 2>/dev/null  && LOCKFILE_CI_FOUND="YES" && echo "Lock file validation in Bitbucket Pipelines: YES"
[ -z "$LOCKFILE_CI_FOUND" ] && echo "CI_LOCKFILE_VALIDATION: NOT CONFIGURED"

# --- Snyk ---
if [ -f ".snyk" ]; then
  echo "Snyk: CONFIGURED"
else
  echo "Snyk: NOT CONFIGURED"
fi

# --- Pre-commit hooks for security ---
if [ -f ".pre-commit-config.yaml" ]; then
  echo "Pre-commit: CONFIGURED"
  grep -E "gitleaks|detect-secrets|secret|security" .pre-commit-config.yaml 2>/dev/null || echo "No security hooks found"
else
  echo "Pre-commit: NOT CONFIGURED"
fi
```

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/security-audit/step_05_security_dependency_audit.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Detected project type and package manager
- Vulnerability scan results (count by severity: critical, high, medium, low)
- Outdated dependencies summary
- Lock file integrity status
- Automated dependency updates status: DepUpdate CONFIGURED/NOT CONFIGURED with tool name (Dependabot / Renovate / GitLab Dependency Scanning / equivalent)
- CI platform(s) detected (GitHub Actions / GitLab CI / Bitbucket Pipelines)
- CI security scanning status per platform (CI_SECURITY_SCANNING CONFIGURED/NOT CONFIGURED)
- CI PR/MR trigger status (CI_PR_TRIGGERS CONFIGURED/NOT CONFIGURED)
- CI lock file validation status (CI_LOCKFILE_VALIDATION CONFIGURED/NOT CONFIGURED)
- Snyk status
- Pre-commit security hooks status
- Path dependency classification (Flutter/Dart and Node file: deps):
  - PATH_INTERNAL_COUNT: [N] — in-repo/monorepo packages (NOT a supply-chain risk, do not penalise)
  - PATH_INTERNAL_LIST: [package names] — informational only
  - PATH_EXTERNAL_COUNT: [N] — absolute or out-of-repo paths (supply-chain risk, penalise -5 each)
  - PATH_EXTERNAL_LIST: [package names with paths]
  - GIT_SOURCED_COUNT: [N] — git-sourced deps (supply-chain risk, penalise -10 each)
  - GIT_SOURCED_LIST: [package names]
- Recommendations for improvement
