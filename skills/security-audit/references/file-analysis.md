# Security File Analysis

> Identify sensitive files, check .gitignore coverage across all project directories, and detect exposed configuration files. Framework-agnostic with runtime project type detection.

---

Goal: Identify sensitive files, check .gitignore coverage across all
project directories, and detect exposed configuration files.

EFFICIENCY REQUIREMENTS:
- Target: <= 10 total tool calls for this entire analysis
- Use batch grep/find commands instead of reading files one by one
- Read 3-5 .gitignore files per tool call using parallel reads
- Pipe large outputs through `| head -50`

ENV FILE VERIFICATION (execute before reporting .env findings):
Run these commands to avoid false positives:
- git ls-files .env .env.local .env.development .env.production .env.staging .env.test 2>/dev/null
  (empty output = .env not tracked = SAFE, do not report as risk)
- grep -E "^\\.env" .gitignore 2>/dev/null
  (match found = .env in .gitignore = do not apply "missing .gitignore" penalty)

IMPORTANT EXCLUSIONS:
- Do NOT analyze, recommend, or consider missing SECURITY.md files
- Do NOT analyze, recommend, or consider missing CODEOWNERS files
- These are governance decisions, not technical security requirements

PROJECT DETECTION (execute first):
- Read reports/.artifacts/step_01_security_tool_installer.md for
  PROJECT_DETECTION_RESULTS (format: type@path|type@path...)
- If multiple projects: for each type@path, cd to path and run
  sensitive file checks for that project; concatenate all results
- If single project: run from project root
- Fallback: pubspec.yaml -> Flutter, package.json -> Node/NestJS,
  go.mod -> Go, Cargo.toml -> Rust, pyproject.toml -> Python,
  *.sln/.csproj -> .NET, else Generic

SENSITIVE FILES DETECTION (adapt per project type):

1. Environment Files (ALL project types):
   - Find all .env files present in the filesystem:
     * .env, .env.local, .env.development, .env.production,
       .env.staging, .env.test
   - MANDATORY: Before reporting .env as a risk, you MUST verify:
     a) Is .env TRACKED by git? Run: git ls-files .env .env.local .env.* 2>/dev/null
       - If output is empty: .env is NOT tracked (SAFE, do NOT report as risk)
       - If files are listed: .env IS tracked (RISK)
     b) Is .env in .gitignore? Run: grep -E "^\\.env" .gitignore 2>/dev/null
       - If pattern exists: .env is properly ignored (SAFE for "missing .gitignore" penalty)
       - Only report "Missing .gitignore for env files" if NO .env pattern exists
   - Only report as RISK: (a) .env tracked in git, OR (b) .env pattern missing from .gitignore
   - A .env file that exists locally but is in .gitignore and NOT tracked is SAFE
   - Check for .env.example or .env.sample (should exist without secrets)

2. Credentials and Keys (ALL project types):
   - Search for potential credential files:
     * **/*.pem, **/*.key, **/*.cert, **/*.p12, **/*.pfx
     * **/secrets/**, **/credentials/**
     * **/*-key.json, **/*-credentials.json
     * **/service-account*.json
   - Check if found files are in .gitignore

3. Flutter/Dart-Specific Files:
   - google-services.json, firebase_app_id_file.json
   - *.keystore, *.jks files
   - android/.gitignore (check for key.properties, **/*.keystore,
     **/*.jks patterns)
   - ios/.gitignore, web/.gitignore, platform-specific .gitignore files
   - Verify android/.gitignore contains the security block:
     key.properties, **/*.keystore, **/*.jks

4. NestJS/Node.js-Specific Files:
   - ormconfig.json (should not have production credentials)
   - JWT_SECRET, SESSION_SECRET in .env.example
   - Database connection strings in code
   - Docker secrets, docker-compose secrets

5. Go/Rust/Python-Specific Files:
   - Go: config.yaml with credentials, *.key files
   - Rust: .cargo/credentials, *.pem files
   - Python: settings.py with SECRET_KEY, *.pem files

6. .NET-Specific Files:
   - appsettings.json, appsettings.*.json (check for ConnectionStrings,
     secrets; appsettings.Development.json often has local overrides)
   - appsettings.Production.json (must not have production secrets)
   - *.pubxml (Publish profiles may contain credentials)
   - Check if secrets in appsettings are in .gitignore or use User Secrets

.GITIGNORE ANALYSIS:

1. Find and read ALL .gitignore files in the project
2. Verify essential patterns per project type:
   - Common: node_modules, .env*, *.log, coverage, .DS_Store
   - Flutter: build/, .dart_tool/, *.keystore, key.properties
   - Node.js: node_modules, dist, .env*, coverage
   - Go: vendor/ (if not vendored), *.exe
   - Rust: target/, *.pdb
   - Python: __pycache__, *.pyc, .venv/, dist/
   - .NET: bin/, obj/, *.user, appsettings.Production.json (if has secrets)
3. For each sensitive file found, check if it's properly ignored
4. CRITICAL RULE: Only report as risks those sensitive files that are either:
   (a) tracked by git (git ls-files shows them), OR
   (b) not covered by any .gitignore pattern
   A file that exists locally but is in .gitignore and NOT tracked is SAFE.

MONOREPO DETECTION:
- If apps/ directory exists, analyze each app individually
- If packages/ or libs/ directory exists, analyze each package
- Compare .gitignore patterns across apps for consistency

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/step_02_security_file_analysis.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Detected project type
- Repository structure type (single app / monorepo)
- List all .gitignore files found (per app if monorepo)
- Sensitive files detected and their protection status
- .gitignore coverage gaps
- Security risks identified
- Missing technical security configurations
