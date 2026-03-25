# Security Dependency Audit

> Run package-manager-native vulnerability scans and identify outdated or vulnerable dependencies. Framework-agnostic with runtime project type detection.

---

Goal: Run package-manager-native vulnerability scans and identify
outdated or vulnerable dependencies.

PROJECT DETECTION (execute first):
- Read reports/.artifacts/step_01_security_tool_installer.md for
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
# Check for Dependabot
if [ -f ".github/dependabot.yml" ] || [ -f ".github/dependabot.yaml" ]; then
  echo "Dependabot: CONFIGURED"
  cat .github/dependabot.y*ml 2>/dev/null | head -30
else
  echo "Dependabot: NOT CONFIGURED"
fi

# Check CI/CD for security scanning
grep -rl "npm audit\|yarn audit\|pnpm audit\|snyk\|trivy\|grype\|safety\|pip.audit\|cargo.audit\|govulncheck\|dependencyCheck\|dependency-check\|dotnet.*package" \
  .github/workflows/ 2>/dev/null | head -10 || echo "No security scanning in CI/CD workflows"

# Check for Snyk
if [ -f ".snyk" ]; then
  echo "Snyk: CONFIGURED"
fi

# Check for Renovate
if [ -f "renovate.json" ] || [ -f ".github/renovate.json" ]; then
  echo "Renovate: CONFIGURED"
fi

# Check pre-commit hooks for security
if [ -f ".pre-commit-config.yaml" ]; then
  echo "Pre-commit: CONFIGURED"
  grep -E "gitleaks|detect-secrets|secret|security" .pre-commit-config.yaml 2>/dev/null || echo "No security hooks found"
else
  echo "Pre-commit: NOT CONFIGURED"
fi
```

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/step_05_security_dependency_audit.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Detected project type and package manager
- Vulnerability scan results (count by severity: critical, high, medium, low)
- Outdated dependencies summary
- Lock file integrity status
- Automated security tooling status (Dependabot, Snyk, Renovate)
- CI/CD security scanning status
- Recommendations for improvement
