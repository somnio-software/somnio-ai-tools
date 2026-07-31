# Category D - Data Protection & Confidentiality Evidence (A.8.24, A.8.3, A.5.12-A.5.13, A.8.10, A.8.12)

> Gather in-repo evidence for cryptography in transit + at rest / key management, data segregation, classification/labelling, retention + secure deletion, DLP, and masking. Framework-agnostic, read-only. Heavily PLATFORM-AUDITABLE - score it heavily.

---

Goal: Determine whether the application/repository protects data through
cryptography, access to information (A.8.3), classification, retention/deletion,
masking, and leakage prevention. Record Status + Owner/lane per control.

PROJECT DETECTION (execute first):
- Read `reports/.artifacts/step_01_iso27001_project_detection.md`.

CONTROL EVIDENCE (adapt to detected stack):

A.8.24 Use of cryptography - in transit, at rest, key management
(PLATFORM-AUDITABLE)
- TLS in transit (enforced HTTPS, TLS config, HSTS):
```bash
grep -rniE "https://|forceSSL|force_ssl|hsts|tls|ssl_?context|require.?tls|min_?tls|sslmode=require|rejectUnauthorized" . --include=*.ts --include=*.js --include=*.py --include=*.go --include=*.tf --include=*.yaml --include=*.yml --include=*.conf 2>/dev/null | grep -vE "node_modules|dist|test" | head -25 || echo "No TLS/in-transit encryption evidence found"
```
- Encryption at rest (DB/storage/volume encryption, KMS):
```bash
grep -rniE "encrypt(ed|ion)?|kms|storage_encrypted|server_side_encryption|sse|encryption_at_rest|encrypted = true|cmk|customer.?managed.?key" . --include=*.tf --include=*.yaml --include=*.yml --include=*.ts --include=*.py 2>/dev/null | grep -v node_modules | head -25 || echo "No at-rest encryption evidence found"
```
- Key management (secrets manager / vault / KMS, no plaintext keys):
```bash
grep -rniE "secrets?manager|ssm|parameter store|vault|kms|key ?vault|keyManagement|rotate.?key|key rotation" . 2>/dev/null | grep -vE "node_modules|dist|test" | head -20 || echo "No key-management evidence found"
```

A.8.3 Information access restriction (PLATFORM-AUDITABLE) - row/tenant scoping,
field-level access:
```bash
grep -rniE "tenant|multi-?tenant|row.?level|rls|scope.*user|where.*user_?id|ownership|@Restrict|field.?level" . 2>/dev/null | grep -vE "node_modules|dist|test" | head -20 || echo "No information-access-restriction evidence found"
```

A.5.12 Classification of information / A.5.13 Labelling of information
(ORGANIZATIONAL; PLATFORM-AUDITABLE if data models carry sensitivity labels)
```bash
find . -maxdepth 5 -iname "*data*classif*" -o -iname "*classification*polic*" 2>/dev/null | grep -v node_modules | head -10 || echo "No data-classification policy artifact found"
grep -rniE "sensitivity|classification|confidential|pii|phi|restricted|@Sensitive|dataClass" . 2>/dev/null | grep -vE "node_modules|dist|test" | head -15 || echo "No in-code data-labelling evidence found"
```

A.8.10 Information deletion - retention + secure deletion (PLATFORM-AUDITABLE)
```bash
grep -rniE "retention|ttl|expire|purge|soft.?delete|hard.?delete|secure.?delete|shred|data.?deletion|right to be forgotten|gdpr" . 2>/dev/null | grep -vE "node_modules|dist|test" | head -20 || echo "No retention/deletion evidence found"
```

A.8.12 Data leakage prevention - secrets in repo (PLATFORM-AUDITABLE) + DLP:
- Secret scanning tooling present:
```bash
find . \( -name ".gitleaks.toml" -o -name ".pre-commit-config.yaml" -o -path "*/.github/workflows/*" \) -not -path "*/node_modules/*" 2>/dev/null | xargs grep -liE "gitleaks|trufflehog|detect-secrets|secret.?scan" 2>/dev/null | head -10 || echo "No secret-scanning tooling found"
```
- Env-file hygiene (never report secret VALUES - report presence/tracking):
```bash
git ls-files 2>/dev/null | grep -E "^\.env($|\.)" | grep -vE "\.example|\.sample" | head -10 || echo "No tracked .env files (SAFE)"
grep -E "^\.env" .gitignore 2>/dev/null | head -3 || echo "No .env pattern in root .gitignore"
```
- A.8.11 Data masking (bonus): masking/redaction in logs or outputs:
```bash
grep -rniE "mask|redact|\\*\\*\\*\\*|obfuscate|anonymiz|pseudonymiz|tokeniz" . 2>/dev/null | grep -vE "node_modules|dist|test" | head -15 || echo "No data-masking evidence found"
```

READ-ONLY + SECRET SAFETY (CRITICAL for this category):
- If any grep surfaces an actual secret VALUE, record ONLY the file path and
  line and the fact that a secret-shaped string was present. Redact the value
  as `[REDACTED]`. NEVER copy a secret value into the artifact or report.

ARTIFACT SAVE (mandatory):
Save output to: reports/.artifacts/step_05_iso27001_data_protection_confidentiality.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Category D control table: Annex A ref | control name | Status | Owner/lane |
  evidence (path:line, VALUES REDACTED) or "No evidence found" | gap +
  satisfying artifact
- Summary: count of Met / Partial / Gap / Organizational
