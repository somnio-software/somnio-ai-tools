# SOC 2 Data Protection & Confidentiality (Family D)

> Gather PLATFORM-AUDITABLE evidence for data protection — TLS 1.2+ in transit, AES-256/KMS at rest, tenant/data segregation, data minimization, classification, retention with secure disposal, residency disclosure, DLP, and encrypted, restore-tested backups (CC6.1, CC6.7, C1.1-C1.2). Framework-agnostic. Read-only. Redact secret values.

---

Goal: Assess how the platform protects data in transit and at rest, segregates
tenants, and manages retention and disposal. Family D is heavily
PLATFORM-AUDITABLE. Record Status + Owner/lane + evidence for each control.

PROJECT DETECTION (execute first):
- Read reports/.artifacts/step_01_soc2_project_detection.md for stack and IaC.

CONTROL RECORDING FORMAT: control ref (e.g. `D1`), criterion, Status, Owner/lane,
Evidence. Family D controls are PLATFORM-AUDITABLE unless noted.

EVIDENCE GATHERING:

1. Encryption in transit — TLS 1.2+ / HTTPS / HSTS (CC6.7, C1.1):
```bash
echo "=== D: ENCRYPTION IN TRANSIT ==="
grep -rniE "https://|force.?ssl|hsts|strict-transport-security|tls_version|ssl_policy|minimum_protocol_version|TLSv1\.[23]|redirect.*https|require_tls" \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.rb" --include="*.go" --include="*.tf" --include="*.yaml" --include="*.yml" --include="*.conf" . 2>/dev/null | grep -v "node_modules\|dist\|vendor" | head -20 || echo "No TLS/HTTPS enforcement patterns detected"
```

2. Encryption at rest — KMS / AES-256 / encrypted volumes/DB/S3 (CC6.1, C1.1):
```bash
echo "=== D: ENCRYPTION AT REST ==="
grep -rniE "kms|aws_kms_key|encrypt(ed|ion)?\s*[:=]\s*true|server_side_encryption|sse_algorithm|AES256|aws:kms|storage_encrypted|encryption_at_rest" \
  --include="*.tf" --include="*.yaml" --include="*.yml" --include="*.json" . 2>/dev/null | grep -v "node_modules" | head -20 || echo "No encryption-at-rest configuration detected"
```

3. Tenant / data segregation & minimization (C1.1):
```bash
echo "=== D: TENANT SEGREGATION & MINIMIZATION ==="
grep -rniE "tenant_?id|organization_?id|account_?id|row.level.security|RLS|schema_per_tenant|WHERE.*tenant|scopeTo" \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.rb" --include="*.sql" . 2>/dev/null | grep -v "node_modules\|dist\|vendor\|spec\|test" | head -15 || echo "No tenant-segregation patterns detected"
```

4. Data classification, retention & secure disposal (C1.2):
```bash
echo "=== D: CLASSIFICATION, RETENTION & DISPOSAL ==="
find . -type f -not -path "*/node_modules/*" \( -iname "*data-classification*" -o -iname "*retention*" -o -iname "*data-map*" -o -iname "*data-flow*" \) 2>/dev/null | head -10
grep -rniE "retention|ttl|expire|lifecycle_rule|purge|soft.?delete|hard.?delete|anonymiz|data residency|region\s*=" \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.tf" --include="*.yaml" . 2>/dev/null | grep -v "node_modules\|dist\|vendor" | head -15 || echo "No retention/disposal patterns detected"
```

5. Encrypted, restore-tested backups (A1.2, C1.1):
```bash
echo "=== D: BACKUPS ==="
grep -rniE "backup|snapshot|aws_backup|pg_dump|point.in.time|restore|rds.*backup_retention|dump" \
  --include="*.tf" --include="*.yaml" --include="*.yml" --include="*.sh" . 2>/dev/null | grep -v "node_modules" | head -15 || echo "No backup configuration detected"
```

6. DLP / secret leakage prevention (C1.1):
```bash
echo "=== D: DLP / LEAKAGE PREVENTION ==="
ls .gitleaks.toml .github/workflows/*secret* 2>/dev/null
grep -rniE "gitleaks|trufflehog|detect-secrets|dlp" .github/ 2>/dev/null | head -10 || echo "No DLP/secret-scanning in CI detected"
```

Controls to record (PLATFORM-AUDITABLE unless noted):
- D1 TLS 1.2+ enforced in transit (CC6.7, C1.1)
- D2 Encryption at rest via KMS/AES-256 (CC6.1, C1.1)
- D3 Tenant/data segregation (C1.1)
- D4 Data minimization (C1.1)
- D5 Data classification scheme (C1.2) — may be ORGANIZATIONAL (doc artifact)
- D6 Retention + secure disposal/purge (C1.2)
- D7 Data residency disclosure (C1.2) — often ORGANIZATIONAL
- D8 DLP / secret-leakage prevention (C1.1)
- D9 Encrypted backups (C1.1)
- D10 Backup restore tested (A1.2) — restore-test evidence often ORGANIZATIONAL

STATUS RULES:
- Encryption/segregation verifiable in code/IaC -> met.
- Config present but incomplete (e.g. encryption on some resources only) -> partial.
- No evidence -> gap; state the exact evidence that would satisfy it.

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/step_04_soc2_data_protection.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Family D control table (control ref, criterion, Status, Owner/lane, Evidence path)
- Encryption coverage summary (transit / at rest / backups)
- Gaps with the exact evidence that would satisfy each
