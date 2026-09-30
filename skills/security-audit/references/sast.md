# Security SAST Scan

> Run basic SAST-style grep for OWASP vulnerability patterns (SQL injection, XSS, path traversal) per detected project type. Findings feed Consolidated Findings as LOW/MEDIUM; does not affect main scoring.

---

Goal: Scan source code for common OWASP vulnerability patterns. Run
per detected project type. Findings are LOW/MEDIUM severity for
Consolidated Findings; do not affect main section scores.

SCAN SCOPE (execute first):
- Step 1 (tool-installer) wrote the scope to
  `reports/.artifacts/security-audit/scope/`: one file list per language
  in PROJECT_DETECTION_RESULTS, built from `git ls-files` by extension
  (tracked files only; dependencies, build outputs and generated code
  excluded), plus `summary.txt` and the `scan.sh` helper.
- If `scope/scan.sh` is missing, re-run the detection block in
  `references/tool-installer.md` from the repository root first.
- Run every block below from the repository root, and start each one with
  `. reports/.artifacts/security-audit/scope/scan.sh` (shell functions do
  not survive between separate commands). Do not cd into project paths and
  do not pass directories to grep: the lists already cover every project,
  so a nested project is scanned once, not twice.
- SAST reads the `<lang>.src` lists (tests excluded). A language that was
  not detected prints "not applicable: 0 files in scope" — that is not a
  clean result, it is no result.
- `scan [-v DROP_REGEX] <list> <label> <pattern>` prints up to 20 matches
  and always ends with `[<label>] N match(es) across M files`. Copy those
  summary lines into the artifact as the evidence for each count.

Record the scope first:
```bash
cat reports/.artifacts/security-audit/scope/summary.txt
```

SAST PATTERNS BY LANGUAGE:

SQL Injection (concatenation with user input):
```bash
. reports/.artifacts/security-audit/scope/scan.sh
# JavaScript/TypeScript: string concat in query
scan js.src "SQL concat (JS/TS)" "\.query\s*(\s*['\"].*\+.*\|.*\+.*['\"]"

# Python: string format / % in execute
scan py.src "SQL concat (Python)" "execute\s*(\s*['\"].*%\|\.format\s*("

# C#: string concat in SqlCommand/Execute
scan cs.src "SQL concat (C#)" "SqlCommand.*\+ \|ExecuteNonQuery.*\+ \|string\.Format.*SELECT\|string\.Format.*INSERT"

# Go: Sprintf / concatenation in Query/Exec
scan go.src "SQL concat (Go)" "Query\s*(\s*.*fmt\.Sprintf\|Exec\s*(\s*.*fmt\.Sprintf\|db\.Query.*\+"

# Java/Kotlin: Statement with concat
scan java.src "SQL concat (Java)" "Statement\s*\|executeQuery\s*(\s*.*+"
scan kt.src "SQL concat (Kotlin)" "Statement\s*\|executeQuery\s*(\s*.*+"
```

XSS (innerHTML, document.write, dangerouslySetInnerHTML):
```bash
. reports/.artifacts/security-audit/scope/scan.sh
# JavaScript/TypeScript/React
scan js.src "XSS (JS/TS)" "innerHTML\s*=\|document\.write\s*(\|dangerouslySetInnerHTML"

# Dart: innerHtml, HtmlEscape bypass
scan dart.src "XSS (Dart)" "innerHtml\s*=\|HtmlEscape\.bypass\|allowInterop.*innerHTML"
```

Path Traversal (Path.Combine with user input, unchecked paths):
```bash
. reports/.artifacts/security-audit/scope/scan.sh
# C# / .NET
scan cs.src "Path traversal (C#)" "Path\.Combine\s*(\s*.*Request\|File\.ReadAllText\s*(\s*.*Request\|Path\.GetFullPath.*input"

# Node.js: path.join with req.params, req.query
scan js.src "Path traversal (Node)" "path\.join\s*(\s*.*req\.\|fs\.readFile.*req\.\|readFileSync.*req\.\|require.*req\."

# Python: open() with user input
scan py.src "Path traversal (Python)" "open\s*(\s*.*request\.\|open\s*(\s*.*input\s*("

# Go: filepath.Join with user input
scan go.src "Path traversal (Go)" "filepath\.Join.*r\.URL\|ioutil\.ReadFile.*r\.\|os\.Open.*r\."
```

Eval / Code Injection:
```bash
. reports/.artifacts/security-audit/scope/scan.sh
EVAL_RE="eval\s*(\|new Function\s*(\|exec\s*(\s*.*+\|Runtime\.getRuntime\|Process\.start.*shell"
for l in js py java kt; do
  SCAN_MAX=15 scan "$l.src" "Eval/exec ($l)" "$EVAL_RE"
done
```

Firebase Auth Abuse Protection (App Check) — only run if the project uses
Firebase Auth (`firebase_auth` in any tracked `pubspec.yaml` for Flutter,
or `firebase-admin`/`firebase-functions` for Node/TypeScript):

```bash
. reports/.artifacts/security-audit/scope/scan.sh
# Flutter/Dart client: phone sign-in without the App Check package.
# Every tracked pubspec counts, so apps/*/pubspec.yaml in a monorepo does too.
PUBSPECS=$(git ls-files '*pubspec.yaml' 2>/dev/null || find . -name pubspec.yaml -not -path '*/.*')
if [ -n "$PUBSPECS" ] && echo "$PUBSPECS" | tr '\n' '\0' | xargs -0 grep -l "firebase_auth" 2>/dev/null; then
  SCAN_MAX=10 scan dart.src "Phone sign-in (Dart)" "signInWithPhoneNumber\|verifyPhoneNumber"
  echo "$PUBSPECS" | tr '\n' '\0' | xargs -0 grep -Hn "firebase_app_check" 2>/dev/null \
    || echo "No firebase_app_check dependency in any pubspec.yaml"
  scan dart.src "App Check activation (Dart)" "FirebaseAppCheck"
fi

# Node.js/TypeScript backend (e.g. Firebase Functions): Auth verification without App Check enforcement
SCAN_MAX=5 scan js.src "Firebase Auth verification (Node)" "firebase-admin/auth\|verifyIdToken"
scan js.src "App Check verification (Node)" "getAppCheck\|appCheck()\|X-Firebase-AppCheck\|enforceAppCheck"
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

Start the artifact with a Scope line, then report per language:
0. **Scope:** the directories and file count per language from
   `scope/summary.txt`, e.g. `Scope: js - 254 src files - app/dashboard
   (115), components/dashboard (30), lib (28), ... (git ls-files)`, plus
   any `UNSCANNED` lines. A zero-findings result is only valid next to
   a non-zero scope: if a detected language has 0 files in scope, say
   "no files scanned" instead of "no findings".
1. Language and the `scan` summary lines for it
2. SQL injection: count and sample file:line
3. XSS: count and sample file:line
4. Path traversal: count and sample file:line
5. Eval/Code injection: count and sample file:line
6. Firebase Auth abuse protection (App Check): code-level status (present/missing) plus live enforcement status (ENFORCED/UNENFORCED/UNVERIFIED) with evidence — only if Firebase Auth is detected
7. SMS region policy: configured (with allowed regions) or unrestricted — only if phone sign-in is detected

Classify each finding as LOW or MEDIUM. Do not affect main scoring.

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/security-audit/step_08_security_sast.md
Run before finishing: mkdir -p reports/.artifacts/security-audit
