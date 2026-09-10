# Security Tool Installer

> Detect project type for the framework-agnostic Security Audit. Supports multi-tech monorepos.

---

Goal: Detect the project type(s) present in the repository for the
security audit.

PROJECT DETECTION (execute first - multi-tech monorepo support):

Detect ALL project types in the repository. For each manifest found,
record (type, basePath). Output format for downstream steps.

Priority order when same directory has multiple manifests: pubspec.yaml >
package.json > go.mod > Cargo.toml > pyproject.toml > build.gradle >
pom.xml > Package.swift > Podfile > .sln/.csproj

```bash
echo "=== MULTI-TECH PROJECT DETECTION ==="

RESULTS=""
SEEN=""

add_project() {
  local ptype="$1"
  local base="$2"
  local key="${ptype}:${base}"
  if ! echo "$SEEN" | grep -qF "$key"; then
    SEEN="${SEEN}${key}
"
    if [ -z "$RESULTS" ]; then
      RESULTS="${ptype}@${base}"
    else
      RESULTS="${RESULTS}|${ptype}@${base}"
    fi
  fi
}

# Find pubspec.yaml (Flutter/Dart)
for f in $(find . -name "pubspec.yaml" -not -path "*/.*" 2>/dev/null | head -20); do
  d=$(dirname "$f")
  add_project "flutter" "$d"
done

# Find package.json (NestJS if @nestjs/core, else Node.js)
for f in $(find . -name "package.json" -not -path "*/node_modules/*" 2>/dev/null | head -20); do
  d=$(dirname "$f")
  if grep -q "@nestjs/core" "$f" 2>/dev/null; then
    add_project "nestjs" "$d"
  else
    add_project "nodejs" "$d"
  fi
done

# Find go.mod
for f in $(find . -name "go.mod" -not -path "*/.*" 2>/dev/null | head -20); do
  add_project "go" "$(dirname "$f")"
done

# Find Cargo.toml
for f in $(find . -name "Cargo.toml" -not -path "*/.*" 2>/dev/null | head -20); do
  add_project "rust" "$(dirname "$f")"
done

# Find pyproject.toml or requirements.txt
for f in $(find . \( -name "pyproject.toml" -o -name "requirements.txt" \) -not -path "*/.*" 2>/dev/null | head -20); do
  add_project "python" "$(dirname "$f")"
done

# Find build.gradle / build.gradle.kts
for f in $(find . \( -name "build.gradle" -o -name "build.gradle.kts" \) -not -path "*/.*" 2>/dev/null | head -20); do
  add_project "gradle" "$(dirname "$f")"
done

# Find pom.xml
for f in $(find . -name "pom.xml" -not -path "*/.*" 2>/dev/null | head -20); do
  add_project "maven" "$(dirname "$f")"
done

# Find Package.swift
for f in $(find . -name "Package.swift" -not -path "*/.*" 2>/dev/null | head -20); do
  add_project "swift" "$(dirname "$f")"
done

# Find Podfile
for f in $(find . -name "Podfile" -not -path "*/.*" 2>/dev/null | head -20); do
  add_project "cocoapods" "$(dirname "$f")"
done

# Find .sln / .csproj
for f in $(find . \( -name "*.sln" -o -name "*.csproj" \) -not -path "*/.*" 2>/dev/null | head -20); do
  add_project "dotnet" "$(dirname "$f")"
done

# Fallback if nothing found
if [ -z "$RESULTS" ]; then
  RESULTS="generic@."
  echo "PROJECT_TYPE=generic"
  echo "Detected: Generic project (no manifest found)"
else
  echo "PROJECT_TYPES=$RESULTS"
  echo "Detected N project types. Auditing each."
fi

echo "PROJECT_DETECTION_RESULTS=$RESULTS"
```

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/security-audit/step_01_security_tool_installer.md
Run before finishing: mkdir -p reports/.artifacts/security-audit

Output format (in artifact):
- PROJECT_DETECTION_RESULTS: pipe-separated list of type@path (e.g.
  flutter@.|nodejs@apps/web). Downstream steps use this to audit each
  project when multiple are detected.
- Detected project type(s) and technology
- Source file extensions to scan
- Package manager detected
