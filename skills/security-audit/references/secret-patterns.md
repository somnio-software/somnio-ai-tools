# Security Secret Patterns

> Search source code for dangerous secret usage patterns, hardcoded credentials, API keys, and tokens. Framework-agnostic with runtime project type detection.

---

Goal: Search source code for dangerous secret usage patterns. This is
a MANDATORY check that must appear in the artifact even if no issues
are found.

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
  do not pass directories to grep: the lists already cover every project.
- Secret patterns read the `<lang>.src` lists: test files are excluded by
  path (Gitleaks, step 4, still covers them). A language that was not
  detected prints "not applicable: 0 files in scope" — that is not a clean
  result, it is no result.
- `scan [-v DROP_REGEX] <list> <label> <pattern>` prints up to 20 matches
  and always ends with `[<label>] N match(es) across M files`. Copy those
  summary lines into the artifact as the evidence for each count.

Record the scope first:
```bash
cat reports/.artifacts/security-audit/scope/summary.txt
```

SOURCE CODE SECRET PATTERNS (CRITICAL - MANDATORY CHECK):

For Flutter/Dart projects, scan *.dart files:

1. Client-side secret key usage (HIGH severity):
   ```bash
   . reports/.artifacts/security-audit/scope/scan.sh
   # Bearer token patterns with secret keys
   scan dart.src "Bearer secret (Dart)" "Bearer.*secret\|Bearer.*_secret\|secretKey\|secret_key"

   # Stripe secret keys used in client code
   scan dart.src "Stripe secret (Dart)" "sk_live_\|sk_test_\|stripeSecret\|stripe_secret\|stripe.*[Ss]ecret"

   # API secret/private keys in HTTP headers or Authorization
   scan dart.src "API secret header (Dart)" "Authorization.*[Ss]ecret\|x-api-key\|private.key\|api_secret"
   ```

2. Hardcoded credentials (MEDIUM severity):
   ```bash
   . reports/.artifacts/security-audit/scope/scan.sh
   # Password patterns in source (excluding test/mock files)
   scan -v "mock\|fake\|example\|sample" dart.src "Hardcoded password (Dart)" \
     "password\s*[:=]\s*['\"][^'\"]\+"

   # AWS/GCP/Azure credential patterns
   scan dart.src "Cloud credential (Dart)" "AKIA\|aws_secret\|gcp_credentials\|azure_secret\|service_account"
   ```

For NestJS/Node.js projects, scan *.ts/*.js files:

1. Hardcoded secrets in source code (HIGH severity):
   ```bash
   . reports/.artifacts/security-audit/scope/scan.sh
   # Direct process.env usage (should use ConfigService in NestJS)
   SCAN_MAX=30 scan js.src "Direct process.env" "process\.env\."

   # Hardcoded JWT secrets
   scan js.src "Hardcoded secret (JS/TS)" "secret.*[:=].*['\"][^'\"]\{8,\}"

   # Database connection strings with credentials
   scan -v "\.env" js.src "DB connection string (JS/TS)" "postgres://\|mysql://\|mongodb://\|redis://"

   # API keys and tokens in source
   scan js.src "API key (JS/TS)" "Bearer.*['\"][A-Za-z0-9]\{20,\}\|api_key.*[:=].*['\"]"
   ```

2. Cloud credential patterns (MEDIUM severity):
   ```bash
   . reports/.artifacts/security-audit/scope/scan.sh
   # AWS/GCP/Azure credentials
   scan js.src "Cloud credential (JS/TS)" "AKIA\|aws_secret\|gcp_credentials\|azure_secret\|service.account"

   # Stripe/payment secret keys
   scan js.src "Payment secret (JS/TS)" "sk_live_\|sk_test_\|stripe.*[Ss]ecret\|payment.*secret"
   ```

For Go projects, scan *.go files:

1. Hardcoded secrets (HIGH severity):
   ```bash
   . reports/.artifacts/security-audit/scope/scan.sh
   scan go.src "Hardcoded secret (Go)" "password.*=.*\"\|secret.*=.*\"\|apiKey.*=.*\""

   scan go.src "Cloud credential (Go)" "AKIA\|aws_secret\|Bearer.*['\"]"
   ```

For Python projects, scan *.py files:

1. Hardcoded secrets (HIGH severity):
   ```bash
   . reports/.artifacts/security-audit/scope/scan.sh
   scan -v "example" py.src "SECRET_KEY (Python)" "SECRET_KEY.*=.*['\"].\+['\"]"

   scan -v "example\|mock" py.src "Hardcoded password (Python)" "password.*=.*['\"].\+['\"]"
   ```

For Kotlin projects, scan *.kt files:

1. Hardcoded secrets (HIGH severity):
   ```bash
   . reports/.artifacts/security-audit/scope/scan.sh
   scan -v "Mock" kt.src "Secret access (Kotlin)" "BuildConfig\.\w*[Ss]ecret\|System\.getenv\|getString.*[Ss]ecret"

   SCAN_MAX=15 scan kt.src "SharedPreferences (Kotlin)" "SharedPreferences\|getSharedPreferences.*putString"

   scan kt.src "Cloud credential (Kotlin)" "AKIA\|aws_secret\|gcp_credentials\|api[Kk]ey.*="
   ```

For Swift projects, scan *.swift files:

1. Hardcoded secrets (HIGH severity):
   ```bash
   . reports/.artifacts/security-audit/scope/scan.sh
   scan -v "Mock" swift.src "Secret usage (Swift)" "UserDefaults.*set\|apiKey\|api_key\|secretKey\|secret"

   SCAN_MAX=15 scan swift.src "Keychain/plist (Swift)" "Bundle\.main\.path\|Info\.plist.*secret\|Keychain"

   scan swift.src "Cloud credential (Swift)" "AKIA\|Bearer.*[\"'][A-Za-z0-9]\{20,\}"
   ```

For .NET projects, scan *.cs files:

1. Hardcoded secrets (HIGH severity):
   ```bash
   . reports/.artifacts/security-audit/scope/scan.sh
   scan -v "Mock\|Example" cs.src "Secret usage (.NET)" "ConnectionStrings\|Password\s*=\|Secret\s*=\|ApiKey\|Bearer"

   SCAN_MAX=15 scan -v "Mock\|Example" cs.src "Configuration (.NET)" "Configuration\[\"\|IConfiguration\|GetSection.*Secret"

   SCAN_MAX=10 scan -v "Mock" cs.src "Key Vault (.NET)" "KeyVault\|Azure\.Identity\|DefaultAzureCredential"

   scan -v "Mock\|Example" cs.src "Cloud credential (.NET)" "AKIA\|aws_secret\|gcp_credentials\|azure_secret"
   ```

For Generic/Rust projects, apply a broad scan over every language list
that step 1 produced (a generic project gets all of them):

1. Generic secret patterns (HIGH severity):
   ```bash
   . reports/.artifacts/security-audit/scope/scan.sh
   for l in rs java kt cs; do
     SCAN_MAX=30 scan -v "mock\|example" "$l.src" "Generic secret ($l)" "AKIA\|sk_live_\|sk_test_\|password\s*[:=]"
   done
   ```

3. For each finding report: file path, line number, the pattern
   matched, and severity (HIGH for secret keys in source, MEDIUM for
   cloud credentials, LOW for informational).

If no issues are found, explicitly state:
"No hardcoded secret patterns detected in source code."

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/security-audit/step_03_security_secret_patterns.md
Run before finishing: mkdir -p reports/.artifacts/security-audit

Output format:
- **Scope:** the directories and file count per language from
  `scope/summary.txt` (plus any `UNSCANNED` lines), first in the artifact.
  "No hardcoded secret patterns detected" is only valid next to a non-zero
  scope; if a detected language has 0 files in scope, say "no files
  scanned" instead.
- Detected project type and scan targets
- SOURCE CODE SECRET PATTERNS results (MANDATORY section)
- Findings grouped by severity (HIGH, MEDIUM, LOW)
- File path, line number, and pattern matched for each finding
- Summary count of findings per severity level
