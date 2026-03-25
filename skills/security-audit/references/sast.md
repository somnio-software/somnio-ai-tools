# Security SAST Scan

> Run basic SAST-style grep for OWASP vulnerability patterns (SQL injection, XSS, path traversal) per detected project type. Findings feed Consolidated Findings as LOW/MEDIUM; does not affect main scoring.

---

Goal: Scan source code for common OWASP vulnerability patterns. Run
per detected project type. Findings are LOW/MEDIUM severity for
Consolidated Findings; do not affect main section scores.

PROJECT DETECTION (execute first):
- Read reports/.artifacts/step_01_security_tool_installer.md for
  PROJECT_DETECTION_RESULTS (type@path|type@path...)
- If multiple projects: for each type@path, cd to path and run
  SAST patterns for that language; concatenate results
- If single project: run from project root
Same type-order as security_audit:
- pubspec.yaml -> Flutter/Dart
- package.json -> Node.js/NestJS
- go.mod -> Go
- Cargo.toml -> Rust
- pyproject.toml -> Python
- build.gradle/build.gradle.kts -> Kotlin
- pom.xml -> Java
- Package.swift/Podfile -> Swift
- *.sln / *.csproj -> .NET

SAST PATTERNS BY LANGUAGE:

SQL Injection (concatenation with user input):
```bash
# JavaScript/TypeScript: string concat in query
grep -rn "\.query\s*(\s*['\"].*\+.*\|.*\+.*['\"]" --include="*.js" \
  --include="*.ts" src/ lib/ apps/ 2>/dev/null | grep -v node_modules | head -20 \
  || echo "No SQL concat patterns (JS/TS) found"

# Python: string format / % in execute
grep -rn "execute\s*(\s*['\"].*%\|\.format\s*(" --include="*.py" src/ app/ 2>/dev/null \
  | head -20 || echo "No SQL concat patterns (Python) found"

# C#: string concat in SqlCommand/Execute
grep -rn "SqlCommand.*\+ \|ExecuteNonQuery.*\+ \|string\.Format.*SELECT\|string\.Format.*INSERT" \
  --include="*.cs" . 2>/dev/null | head -20 || echo "No SQL concat patterns (C#) found"

# Go: Sprintf / concatenation in Query/Exec
grep -rn "Query\s*(\s*.*fmt\.Sprintf\|Exec\s*(\s*.*fmt\.Sprintf\|db\.Query.*\+" \
  --include="*.go" . 2>/dev/null | head -20 || echo "No SQL concat patterns (Go) found"

# Java/Kotlin: Statement with concat
grep -rn "Statement\s*\|executeQuery\s*(\s*.*+" --include="*.java" \
  --include="*.kt" . 2>/dev/null | head -20 || echo "No SQL concat patterns (Java/Kotlin) found"
```

XSS (innerHTML, document.write, dangerouslySetInnerHTML):
```bash
# JavaScript/TypeScript/React
grep -rn "innerHTML\s*=\|document\.write\s*(\|dangerouslySetInnerHTML" \
  --include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx" \
  src/ lib/ apps/ 2>/dev/null | grep -v node_modules | head -20 \
  || echo "No XSS patterns (JS) found"

# Dart: innerHtml, HtmlEscape bypass
grep -rn "innerHtml\s*=\|HtmlEscape\.bypass\|allowInterop.*innerHTML" \
  --include="*.dart" lib/ packages/ 2>/dev/null | head -20 \
  || echo "No XSS patterns (Dart) found"
```

Path Traversal (Path.Combine with user input, unchecked paths):
```bash
# C# / .NET
grep -rn "Path\.Combine\s*(\s*.*Request\|File\.ReadAllText\s*(\s*.*Request\|Path\.GetFullPath.*input" \
  --include="*.cs" . 2>/dev/null | head -20 || echo "No path traversal patterns (C#) found"

# Node.js: path.join with req.params, req.query
grep -rn "path\.join\s*(\s*.*req\.\|fs\.readFile.*req\.\|readFileSync.*req\.\|require.*req\." \
  --include="*.js" --include="*.ts" src/ 2>/dev/null | grep -v node_modules | head -20 \
  || echo "No path traversal patterns (Node) found"

# Python: open() with user input
grep -rn "open\s*(\s*.*request\.\|open\s*(\s*.*input\s*(" \
  --include="*.py" src/ app/ 2>/dev/null | head -20 \
  || echo "No path traversal patterns (Python) found"

# Go: filepath.Join with user input
grep -rn "filepath\.Join.*r\.URL\|ioutil\.ReadFile.*r\.\|os\.Open.*r\." \
  --include="*.go" . 2>/dev/null | head -20 || echo "No path traversal patterns (Go) found"
```

Eval / Code Injection:
```bash
grep -rn "eval\s*(\|new Function\s*(\|exec\s*(\s*.*+\|Runtime\.getRuntime\|Process\.start.*shell" \
  --include="*.js" --include="*.ts" --include="*.py" --include="*.java" \
  --include="*.kt" src/ lib/ apps/ . 2>/dev/null \
  | grep -v node_modules | head -15 || echo "No eval/exec patterns found"
```

OUTPUT FORMAT (mandatory):

For each project type detected, report:
1. Language and scan scope
2. SQL injection: count and sample file:line
3. XSS: count and sample file:line
4. Path traversal: count and sample file:line
5. Eval/Code injection: count and sample file:line

Classify each finding as LOW or MEDIUM. Do not affect main scoring.

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/step_08_security_sast.md
Run before finishing: mkdir -p reports/.artifacts
