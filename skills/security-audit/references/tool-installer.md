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

# --- SOURCE SCOPE ---------------------------------------------------------
# Which files the source scans (secret-patterns, SAST) read. Derived from
# the detected project types plus the tracked files of the repo, never from
# a fixed directory list: app/, components/, hooks/, apps/*/lib and root
# files like auth.ts are all in scope when they hold that language's code.
S=reports/.artifacts/security-audit/scope
mkdir -p "$S"
find "$S" -name '*.lst' -delete

LANGS=""
for entry in $(echo "$RESULTS" | tr '|' ' '); do
  case "${entry%%@*}" in
    flutter) LANGS="$LANGS dart" ;;
    nodejs|nestjs) LANGS="$LANGS js" ;;
    python) LANGS="$LANGS py" ;;
    go) LANGS="$LANGS go" ;;
    rust) LANGS="$LANGS rs" ;;
    gradle) LANGS="$LANGS kt java" ;;
    maven) LANGS="$LANGS java" ;;
    swift|cocoapods) LANGS="$LANGS swift" ;;
    dotnet) LANGS="$LANGS cs" ;;
    generic) LANGS="$LANGS dart js py go rs kt java swift cs" ;;
  esac
done

ext_re() {
  case "$1" in
    dart) echo '\.dart$' ;;
    js) echo '\.[cm]?[jt]sx?$' ;;
    py) echo '\.py$' ;;
    go) echo '\.go$' ;;
    rs) echo '\.rs$' ;;
    kt) echo '\.kt$' ;;
    java) echo '\.java$' ;;
    swift) echo '\.swift$' ;;
    cs) echo '\.cs$' ;;
  esac
}

# Dependencies, build outputs and generated code. Mostly untracked already;
# this catches the ones committed by mistake.
BUILD_RE='(^|/)(node_modules|\.venv|venv|vendor|dist|build|\.next|\.nuxt|\.output|\.turbo|\.svelte-kit|coverage|target|\.dart_tool|Pods|DerivedData|\.gradle|__pycache__|site-packages)/|\.min\.js$|\.d\.ts$|\.(g|freezed|gr|mocks|pb)\.dart$|\.pb\.go$'
TEST_RE='(^|/)(test|tests|__tests__|__mocks__|spec|integration_test|test_driver|testing)/|\.(test|spec)\.[cm]?[jt]sx?$|_test\.(go|dart|py)$|(^|/)(test_[^/]*|conftest)\.py$|Tests?\.(cs|kt|java|swift)$'

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  SCOPE_SOURCE="git ls-files (tracked files only)"
  git ls-files | grep -Ev "$BUILD_RE" > "$S/tracked.lst"
else
  SCOPE_SOURCE="find (not a git repo: untracked files included)"
  find . -type f -not -path './.git/*' | sed 's|^\./||' | grep -Ev "$BUILD_RE" > "$S/tracked.lst"
fi

{
  echo "SCOPE_SOURCE=$SCOPE_SOURCE"
  echo "EXCLUDED=dependencies, build outputs, generated code, tests (Gitleaks still scans tests)"
  for lang in dart js py go rs kt java swift cs; do
    case " $LANGS " in *" $lang "*) ;; *) continue ;; esac
    grep -E "$(ext_re "$lang")" "$S/tracked.lst" > "$S/$lang.all.lst"
    grep -Ev "$TEST_RE" "$S/$lang.all.lst" > "$S/$lang.src.lst"
    DIRS=$(awk -F/ '{ k = (NF >= 3) ? $1 "/" $2 : (NF == 2 ? $1 : "."); c[k]++ }
      END { for (k in c) print c[k], k }' "$S/$lang.src.lst" | sort -rn |
      awk 'NR <= 12 { printf "%s%s (%s)", (NR > 1 ? ", " : ""), $2, $1 } END { if (NR > 12) printf ", +%d more", NR - 12 }')
    echo "SOURCE_SCOPE $lang: $(wc -l < "$S/$lang.src.lst" | tr -d ' ') src files ($(wc -l < "$S/$lang.all.lst" | tr -d ' ') incl. tests) - ${DIRS:-none}"
  done
  # Tracked code of a language no manifest declared: not scanned, but visible.
  for lang in dart js py go rs kt java swift cs; do
    case " $LANGS " in *" $lang "*) continue ;; esac
    n=$(grep -cE "$(ext_re "$lang")" "$S/tracked.lst")
    [ "$n" -gt 0 ] && echo "UNSCANNED $lang: $n tracked files (no $lang manifest detected)"
  done
} | tee "$S/summary.txt"

# Scan helper for the downstream steps. Each step sources it:
#   . reports/.artifacts/security-audit/scope/scan.sh
cat > "$S/scan.sh" <<'EOF'
S=reports/.artifacts/security-audit/scope
scope_count() { if [ -f "$S/$1.lst" ]; then wc -l < "$S/$1.lst" | tr -d ' '; else echo 0; fi; }
# scan [-v DROP_REGEX] <list> <label> <grep args...>
#   <list> is <lang>.src (tests excluded) or <lang>.all (tests included).
#   Prints up to SCAN_MAX (default 20) matches, then always one summary line
#   with the match count and the number of files scanned.
scan() {
  drop='^$'
  if [ "$1" = "-v" ]; then drop=$2; shift 2; fi
  list=$1; label=$2; shift 2
  n=$(scope_count "$list")
  if [ "$n" -eq 0 ]; then echo "[$label] not applicable: 0 files in scope ($list)"; return 0; fi
  out=$(tr '\n' '\0' < "$S/$list.lst" | xargs -0 grep -Hn "$@" 2>/dev/null | grep -v -- "$drop")
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | head -n "${SCAN_MAX:-20}"
    echo "[$label] $(printf '%s\n' "$out" | wc -l | tr -d ' ') match(es) across $n files ($list)"
  else
    echo "[$label] 0 matches across $n files ($list)"
  fi
}
EOF
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
- SOURCE SCOPE: the contents of `scope/summary.txt` verbatim (scope
  source, one `SOURCE_SCOPE` line per language with file counts and
  directories, and any `UNSCANNED` lines). The per-language file lists and
  `scan.sh` stay in `reports/.artifacts/security-audit/scope/` for the
  secret-patterns and SAST steps.
