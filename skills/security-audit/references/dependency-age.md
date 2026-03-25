# Security Dependency Age

> Identify outdated and deprecated dependencies across the project. Framework-agnostic with runtime project type detection. Produces structured output for dependency age and deprecation analysis.

---

Goal: Identify outdated and deprecated dependencies, produce
structured output for the Security Audit report.

PROJECT DETECTION (execute first):
- Read reports/.artifacts/step_01_security_tool_installer.md for
  PROJECT_DETECTION_RESULTS (format: type@path|type@path...)
- If multiple projects: for each type@path, cd to path and run
  dependency age check for that project; concatenate all results
- If single project: run from project root
- Per-type tools: Flutter (pub outdated), Node (npm outdated),
  Go (go list -m -u), Rust (cargo outdated), Python (pip),
  Gradle/Maven, Swift, .NET (dotnet list package --outdated)

DEPENDENCY AGE PER PROJECT TYPE:

Flutter/Dart:
```bash
echo "=== Flutter/Dart Dependency Age ==="
fvm flutter pub outdated 2>/dev/null || flutter pub outdated 2>/dev/null \
  || dart pub outdated 2>/dev/null || echo "pub outdated failed"
# Parse output for "discontinued" or "deprecated" in package names
```

NestJS/Node.js:
```bash
echo "=== Node.js Dependency Age ==="
if [ -f "pnpm-lock.yaml" ]; then
  PM="pnpm"
elif [ -f "yarn.lock" ]; then
  PM="yarn"
else
  PM="npm"
fi
echo "Package manager: $PM"
$PM outdated 2>/dev/null | head -50 || echo "outdated check skipped"
# Check for deprecated packages (npm only): list direct deps and check
# npm view <pkg> deprecated 2>/dev/null for each
if [ "$PM" = "npm" ] && [ -f "package.json" ]; then
  echo ""
  echo "=== Deprecated Package Check (npm) ==="
  for pkg in $(node -e "try{const p=require('./package.json'); \
    Object.keys({...p.dependencies,...(p.devDependencies||{})}).forEach( \
    k=>console.log(k));}catch(e){}" 2>/dev/null); do
    dep=$(npm view "$pkg" deprecated 2>/dev/null)
    [ -n "$dep" ] && echo "$pkg: $dep"
  done | head -20 || true
fi
```

Go:
```bash
echo "=== Go Dependency Age ==="
go list -m -u all 2>/dev/null | head -50 || echo "go list failed"
```

Rust:
```bash
echo "=== Rust Dependency Age ==="
if command -v cargo-outdated &> /dev/null; then
  cargo outdated 2>/dev/null | head -50 || echo "cargo outdated failed"
else
  cargo tree --depth 1 2>/dev/null | head -30
  echo "Tip: install cargo-outdated for better analysis (cargo install cargo-outdated)"
fi
```

Python:
```bash
echo "=== Python Dependency Age ==="
pip list --outdated 2>/dev/null | head -50 || echo "pip list --outdated failed"
```

Java/Kotlin (Gradle):
```bash
echo "=== Java/Kotlin Gradle Dependency Age ==="
if [ -f "gradlew" ]; then
  ./gradlew dependencyUpdates 2>/dev/null | head -80 \
    || echo "dependencyUpdates failed (requires gradle-versions-plugin)"
else
  echo "No gradlew found"
fi
```

Java/Kotlin (Maven):
```bash
echo "=== Java/Kotlin Maven Dependency Age ==="
if [ -f "pom.xml" ]; then
  mvn versions:display-dependency-updates 2>/dev/null | head -80 \
    || echo "versions:display-dependency-updates failed"
else
  echo "No pom.xml found"
fi
```

Swift (CocoaPods):
```bash
echo "=== Swift CocoaPods Dependency Age ==="
if [ -f "Podfile" ] && command -v pod &> /dev/null; then
  pod outdated 2>/dev/null | head -50 || echo "pod outdated failed"
else
  echo "Podfile not found or CocoaPods not installed"
fi
```

Swift (SPM):
```bash
echo "=== Swift Package Manager Dependency Age ==="
if [ -f "Package.swift" ] && command -v swift &> /dev/null; then
  swift package show-dependencies 2>/dev/null | head -50 \
    || echo "swift package show-dependencies failed"
  echo "Note: SPM has no native outdated check; consider CocoaPods or \
    manual version comparison"
else
  echo "Package.swift not found or swift not in PATH"
fi
```

.NET:
```bash
echo "=== .NET Dependency Age ==="
if command -v dotnet &> /dev/null; then
  PROJ=$(find . -maxdepth 2 -name "*.sln" 2>/dev/null | head -1)
  [ -z "$PROJ" ] && PROJ=$(find . -maxdepth 2 -name "*.csproj" 2>/dev/null | head -1)
  if [ -n "$PROJ" ]; then
    dotnet list "$PROJ" package --outdated 2>/dev/null | head -80 \
      || echo "dotnet list package --outdated failed"
    dotnet list "$PROJ" package --deprecated 2>/dev/null | head -50 \
      || echo "dotnet list package --deprecated failed"
  else
    echo "No .sln or .csproj found"
  fi
else
  echo "dotnet CLI not found"
fi
```

OUTPUT FORMAT (mandatory - structure the analysis for report integration):

Include these sections in the artifact output:

1. OUTDATED COUNT: [integer] (direct dependencies; add transitive if available)
2. DEPRECATED COUNT: [integer]
3. OUTDATED LIST: For each outdated package, list:
   - Package name, Current version, Latest version, Delta (major/minor/patch)
4. DEPRECATED LIST: For each deprecated package:
   - Package name, Deprecation message (if available)
5. SUMMARY: Brief recommendation (prioritize major updates, replace deprecated)

ARTIFACT SAVE:
Save the full analysis to: reports/.artifacts/step_06_security_dependency_age.md

Run this after completing the analysis:
mkdir -p reports/.artifacts
