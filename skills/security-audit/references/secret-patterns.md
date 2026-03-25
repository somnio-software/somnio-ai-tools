# Security Secret Patterns

> Search source code for dangerous secret usage patterns, hardcoded credentials, API keys, and tokens. Framework-agnostic with runtime project type detection.

---

Goal: Search source code for dangerous secret usage patterns. This is
a MANDATORY check that must appear in the artifact even if no issues
are found.

PROJECT DETECTION (execute first):
- Read reports/.artifacts/step_01_security_tool_installer.md for
  PROJECT_DETECTION_RESULTS (format: type@path|type@path...)
- If multiple projects: for each type@path, cd to path and run
  secret pattern scan for that project; concatenate all results
- If single project: run from project root
- Scan targets per type: Flutter (*.dart), NestJS/Node (*.ts,*.js),
  Go (*.go), Rust (*.rs), Python (*.py), .NET (*.cs)

SOURCE CODE SECRET PATTERNS (CRITICAL - MANDATORY CHECK):

For Flutter/Dart projects, scan *.dart files:

1. Client-side secret key usage (HIGH severity):
   ```bash
   # Bearer token patterns with secret keys
   grep -rn "Bearer.*secret\|Bearer.*_secret\|secretKey\|secret_key" \
     lib/ packages/ --include="*.dart" 2>/dev/null || echo "No Bearer secret patterns found"

   # Stripe secret keys used in client code
   grep -rn "sk_live_\|sk_test_\|stripeSecret\|stripe_secret\|stripe.*[Ss]ecret" \
     lib/ packages/ --include="*.dart" 2>/dev/null || echo "No Stripe secret patterns found"

   # API secret/private keys in HTTP headers or Authorization
   grep -rn "Authorization.*[Ss]ecret\|x-api-key\|private.key\|api_secret" \
     lib/ packages/ --include="*.dart" 2>/dev/null || echo "No API secret header patterns found"
   ```

2. Hardcoded credentials (MEDIUM severity):
   ```bash
   # Password patterns in source (excluding test/mock files)
   grep -rn "password\s*[:=]\s*['\"][^'\"]\+" lib/ packages/ \
     --include="*.dart" 2>/dev/null | grep -v "test\|mock\|fake\|example\|sample" \
     | head -20 || echo "No hardcoded password patterns found"

   # AWS/GCP/Azure credential patterns
   grep -rn "AKIA\|aws_secret\|gcp_credentials\|azure_secret\|service_account" \
     lib/ packages/ --include="*.dart" 2>/dev/null | head -20 \
     || echo "No cloud credential patterns found"
   ```

For NestJS/Node.js projects, scan *.ts files:

1. Hardcoded secrets in source code (HIGH severity):
   ```bash
   # Direct process.env usage (should use ConfigService in NestJS)
   grep -rn "process\.env\." src/ apps/ libs/ --include="*.ts" 2>/dev/null \
     | grep -v "node_modules\|dist\|test\|spec\|\.d\.ts" \
     | head -30 || echo "No direct process.env usage found"

   # Hardcoded JWT secrets
   grep -rn "secret.*[:=].*['\"][^'\"]\{8,\}" src/ apps/ libs/ \
     --include="*.ts" 2>/dev/null | grep -v "node_modules\|dist\|test\|spec" \
     | head -20 || echo "No hardcoded secret patterns found"

   # Database connection strings with credentials
   grep -rn "postgres://\|mysql://\|mongodb://\|redis://" src/ apps/ libs/ \
     --include="*.ts" 2>/dev/null | grep -v "node_modules\|dist\|test\|spec\|\.env" \
     | head -20 || echo "No hardcoded DB connection strings found"

   # API keys and tokens in source
   grep -rn "Bearer.*['\"][A-Za-z0-9]\{20,\}\|api_key.*[:=].*['\"]" \
     src/ apps/ libs/ --include="*.ts" 2>/dev/null \
     | grep -v "node_modules\|dist\|test\|spec" \
     | head -20 || echo "No API key patterns found"
   ```

2. Cloud credential patterns (MEDIUM severity):
   ```bash
   # AWS/GCP/Azure credentials
   grep -rn "AKIA\|aws_secret\|gcp_credentials\|azure_secret\|service.account" \
     src/ apps/ libs/ --include="*.ts" 2>/dev/null \
     | grep -v "node_modules\|dist\|test\|spec" \
     | head -20 || echo "No cloud credential patterns found"

   # Stripe/payment secret keys
   grep -rn "sk_live_\|sk_test_\|stripe.*[Ss]ecret\|payment.*secret" \
     src/ apps/ libs/ --include="*.ts" 2>/dev/null \
     | grep -v "node_modules\|dist\|test\|spec" \
     | head -20 || echo "No payment secret patterns found"
   ```

For Go projects, scan *.go files:

1. Hardcoded secrets (HIGH severity):
   ```bash
   grep -rn "password.*=.*\"\|secret.*=.*\"\|apiKey.*=.*\"" \
     --include="*.go" . 2>/dev/null | grep -v "test\|_test\.go\|vendor" \
     | head -20 || echo "No hardcoded secret patterns found"

   grep -rn "AKIA\|aws_secret\|Bearer.*['\"]" \
     --include="*.go" . 2>/dev/null | grep -v "test\|_test\.go\|vendor" \
     | head -20 || echo "No cloud credential patterns found"
   ```

For Python projects, scan *.py files:

1. Hardcoded secrets (HIGH severity):
   ```bash
   grep -rn "SECRET_KEY.*=.*['\"].\+['\"]" \
     --include="*.py" . 2>/dev/null | grep -v "test\|\.pyc\|venv\|example" \
     | head -20 || echo "No hardcoded secret patterns found"

   grep -rn "password.*=.*['\"].\+['\"]" \
     --include="*.py" . 2>/dev/null | grep -v "test\|\.pyc\|venv\|example\|mock" \
     | head -20 || echo "No hardcoded password patterns found"
   ```

For Kotlin projects, scan *.kt files:

1. Hardcoded secrets (HIGH severity):
   ```bash
   grep -rn "BuildConfig\.\w*[Ss]ecret\|System\.getenv\|getString.*[Ss]ecret" \
     --include="*.kt" . 2>/dev/null | grep -v "test\|Test\|Mock" \
     | head -20 || echo "No Kotlin secret patterns found"

   grep -rn "SharedPreferences\|getSharedPreferences.*putString" \
     --include="*.kt" . 2>/dev/null | grep -v "test\|Test" \
     | head -15 || echo "No Kotlin preferences patterns found"

   grep -rn "AKIA\|aws_secret\|gcp_credentials\|api[Kk]ey.*=" \
     --include="*.kt" . 2>/dev/null | grep -v "test\|Test" \
     | head -20 || echo "No cloud credential patterns found"
   ```

For Swift projects, scan *.swift files:

1. Hardcoded secrets (HIGH severity):
   ```bash
   grep -rn "UserDefaults.*set\|apiKey\|api_key\|secretKey\|secret" \
     --include="*.swift" . 2>/dev/null | grep -v "test\|Test\|Mock" \
     | head -20 || echo "No Swift secret patterns found"

   grep -rn "Bundle\.main\.path\|Info\.plist.*secret\|Keychain" \
     --include="*.swift" . 2>/dev/null | grep -v "test\|Test" \
     | head -15 || echo "No Swift keychain/plist patterns found"

   grep -rn "AKIA\|Bearer.*[\"'][A-Za-z0-9]\{20,\}" \
     --include="*.swift" . 2>/dev/null | grep -v "test\|Test" \
     | head -20 || echo "No cloud credential patterns found"
   ```

For .NET projects, scan *.cs files:

1. Hardcoded secrets (HIGH severity):
   ```bash
   grep -rn "ConnectionStrings\|Password\s*=\|Secret\s*=\|ApiKey\|Bearer" \
     --include="*.cs" . 2>/dev/null | grep -v "Test\|Mock\|Example\|\\/obj\/\|\\/bin\/" \
     | head -20 || echo "No .NET secret patterns found"

   grep -rn "Configuration\[\"\|IConfiguration\|GetSection.*Secret" \
     --include="*.cs" . 2>/dev/null | grep -v "Test\|Mock\|Example" \
     | head -15 || echo "No .NET Configuration patterns found"

   grep -rn "KeyVault\|Azure\.Identity\|DefaultAzureCredential" \
     --include="*.cs" . 2>/dev/null | grep -v "Test\|Mock" \
     | head -10 || echo "No Key Vault patterns found"

   grep -rn "AKIA\|aws_secret\|gcp_credentials\|azure_secret" \
     --include="*.cs" . 2>/dev/null | grep -v "Test\|Mock\|Example" \
     | head -20 || echo "No cloud credential patterns found"
   ```

For Generic/Rust projects, apply a broad scan:

1. Generic secret patterns (HIGH severity):
   ```bash
   grep -rn "AKIA\|sk_live_\|sk_test_\|password\s*[:=]" \
     --include="*.rs" --include="*.rb" --include="*.java" --include="*.kt" \
     --include="*.cs" . 2>/dev/null | grep -v "test\|spec\|mock\|example\|target\|vendor" \
     | head -30 || echo "No secret patterns found"
   ```

3. For each finding report: file path, line number, the pattern
   matched, and severity (HIGH for secret keys in source, MEDIUM for
   cloud credentials, LOW for informational).

If no issues are found, explicitly state:
"No hardcoded secret patterns detected in source code."

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/step_03_security_secret_patterns.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Detected project type and scan targets
- SOURCE CODE SECRET PATTERNS results (MANDATORY section)
- Findings grouped by severity (HIGH, MEDIUM, LOW)
- File path, line number, and pattern matched for each finding
- Summary count of findings per severity level
