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

Firebase Auth Abuse Protection (App Check) — only run if the project uses
Firebase Auth (`firebase_auth` in `pubspec.yaml` for Flutter, or
`firebase-admin`/`firebase-functions` for Node/TypeScript):

```bash
# Flutter/Dart client: phone sign-in without the App Check package
grep -q "firebase_auth" pubspec.yaml 2>/dev/null && {
  grep -rn "signInWithPhoneNumber\|verifyPhoneNumber" --include="*.dart" lib/ 2>/dev/null | head -10 \
    || echo "No phone sign-in usage found"
  grep -rn "firebase_app_check\|FirebaseAppCheck" pubspec.yaml lib/ --include="*.dart" 2>/dev/null \
    || echo "No firebase_app_check dependency or FirebaseAppCheck.instance.activate() found"
}

# Node.js/TypeScript backend (e.g. Firebase Functions): Auth verification without App Check enforcement
grep -rl "firebase-admin/auth\|verifyIdToken" --include="*.ts" --include="*.js" . 2>/dev/null \
  | grep -v node_modules | head -5
grep -rn "getAppCheck\|appCheck()\|X-Firebase-AppCheck\|enforceAppCheck" \
  --include="*.ts" --include="*.js" . 2>/dev/null | grep -v node_modules \
  || echo "No App Check verification (getAppCheck/verifyToken, enforceAppCheck) found"
```

If Firebase Auth is in use (especially phone sign-in) and no App Check
evidence is found on either the client or the backend, report a MEDIUM
finding: "Firebase Auth in use without App Check enforcement — vulnerable
to SMS pumping / automated abuse of phone sign-in. Recommend enabling
Firebase App Check (Play Integrity / App Attest / reCAPTCHA v3 as the
attestation provider) and verifying the `X-Firebase-AppCheck` token
server-side." Treat reCAPTCHA as an optional, additive control on top of
App Check — never as a substitute for it.

IMPORTANT CAVEAT: the code-level check above only proves the App Check SDK
is *wired up* (package present, `activate()`/token verification called).
It does NOT prove enforcement is actually turned on — Firebase App Check
enforcement for Authentication, Firestore, and Storage is a per-project
toggle (Console: Build > App Check > APIs, or the Management API), separate
from any code in this repo. A project can have the SDK fully integrated and
still be unprotected if enforcement was never flipped to "Enforced". Always
attempt the live check below before concluding App Check is effective.

LIVE ENFORCEMENT CHECK (optional — only if `gcloud` is installed and
authenticated with access to the Firebase project; skip gracefully
otherwise):

```bash
if command -v gcloud &> /dev/null && gcloud auth print-access-token &> /dev/null 2>&1; then
  PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
  if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "(unset)" ]; then
    TOKEN=$(gcloud auth print-access-token 2>/dev/null)
    curl -s -H "Authorization: Bearer $TOKEN" \
      "https://firebaseappcheck.googleapis.com/v1/projects/${PROJECT_ID}/services" \
      | grep -E '"name"|"enforcementMode"' \
      || echo "App Check services query failed (missing Firebase App Check Admin permission on this account, or the API is not enabled for the project)"
  else
    echo "No active gcloud project configured — run 'gcloud config set project <id>' to enable the live check, or skip"
  fi
else
  echo "gcloud CLI not installed/authenticated — reporting code-level App Check detection only, flag enforcement status as UNVERIFIED"
fi
```

Interpret the response: `"enforcementMode": "ENFORCED"` for
`identitytoolkit.googleapis.com` (Authentication), `firestore.googleapis.com`,
or `firebasestorage.googleapis.com` means that product is actually rejecting
unverified requests. `"UNENFORCED"` means App Check is registered but NOT
protecting that product — report this as a MEDIUM finding regardless of
what the code-level scan found. If the live check could not run (`gcloud`
unavailable/unauthenticated), report enforcement status as "UNVERIFIED —
could not confirm via gcloud; verify manually in Firebase Console > App
Check" rather than assuming it is safe.

SMS REGION POLICY CHECK (optional, complementary — only if phone sign-in
was found above; only if `gcloud` is installed and authenticated):

Firebase Auth also supports an **SMS region policy** — an allow/deny list
of country codes eligible to receive Auth SMS. It is a defense-in-depth
control alongside App Check (not a substitute): even a request that passes
App Check can still be pointed at an unexpected country, and region
restriction blocks that at zero cost when the app's real user base is
geographically bounded.

```bash
if command -v gcloud &> /dev/null && gcloud auth print-access-token &> /dev/null 2>&1; then
  PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
  if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "(unset)" ]; then
    TOKEN=$(gcloud auth print-access-token 2>/dev/null)
    curl -s -H "Authorization: Bearer $TOKEN" \
      "https://identitytoolkit.googleapis.com/v2/projects/${PROJECT_ID}/config" \
      | grep -A5 '"smsRegionConfig"' \
      || echo "No smsRegionConfig found — SMS region policy is not configured (allowed from any country)"
  fi
else
  echo "gcloud CLI not installed/authenticated — skipping SMS region policy check"
fi
```

Interpret the response: a present `smsRegionConfig.allowlistOnly` with a
non-empty `allowedRegions` list means SMS delivery is already restricted to
those countries. If `smsRegionConfig` is absent, or set to
`allowByDefault`/`disallowedRegions` with an empty deny list, SMS can be
sent to any country. Report this as a LOW/informational finding — not a
required control like App Check, but a recommended one when the app's
expected user base is geographically bounded: "Consider restricting the
Firebase Auth SMS region policy (Authentication > Settings > SMS region
policy) to the countries the app actually serves, as a complementary layer
to App Check against SMS pumping."

OUTPUT FORMAT (mandatory):

For each project type detected, report:
1. Language and scan scope
2. SQL injection: count and sample file:line
3. XSS: count and sample file:line
4. Path traversal: count and sample file:line
5. Eval/Code injection: count and sample file:line
6. Firebase Auth abuse protection (App Check): code-level status (present/missing) plus live enforcement status (ENFORCED/UNENFORCED/UNVERIFIED) with evidence — only if Firebase Auth is detected
7. SMS region policy: configured (with allowed regions) or unrestricted — only if phone sign-in is detected

Classify each finding as LOW or MEDIUM. Do not affect main scoring.

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/step_08_security_sast.md
Run before finishing: mkdir -p reports/.artifacts
