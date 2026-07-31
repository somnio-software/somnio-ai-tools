# SOC 2 Infrastructure & Network Security (Family F)

> Gather PLATFORM-AUDITABLE evidence from IaC and configuration — network segmentation/private subnets, WAF/IDS, control-plane audit logging (e.g. CloudTrail), flow logs, edge access logs, log retention over 30 days, monitoring with security-event alerting, and a managed secrets store with rotation (CC6.6, CC7.2). Framework-agnostic. Read-only. Redact secret values.

---

Goal: Assess the infrastructure and network security posture from IaC,
container, and platform configuration. Family F is heavily PLATFORM-AUDITABLE.
Record Status + Owner/lane + evidence for each control. When no IaC is present,
mark infrastructure controls as gap/organizational and note that provisioning
may be manual (unauditable from the repo).

PROJECT DETECTION (execute first):
- Read reports/.artifacts/step_01_soc2_project_detection.md for IaC presence
  (Terraform / CloudFormation / Kubernetes / Pulumi) and cloud provider hints.

CONTROL RECORDING FORMAT: control ref (e.g. `F1`), criterion, Status, Owner/lane,
Evidence.

EVIDENCE GATHERING:

1. Network segmentation / private subnets (CC6.6):
```bash
echo "=== F: NETWORK SEGMENTATION ==="
grep -rniE "private_subnet|public_subnet|aws_vpc|security_group|network_acl|nacl|ingress|egress|NetworkPolicy|private_link|vpc_endpoint" \
  --include="*.tf" --include="*.yaml" --include="*.yml" . 2>/dev/null | grep -v "node_modules" | head -20 || echo "No network segmentation config detected"
```

2. WAF / IDS / edge protection (CC6.6, CC7.2):
```bash
echo "=== F: WAF / IDS ==="
grep -rniE "waf|web_?acl|aws_wafv2|cloudflare|shield|guardduty|ids|ips|intrusion|rate_?limit|firewall" \
  --include="*.tf" --include="*.yaml" --include="*.yml" . 2>/dev/null | grep -v "node_modules" | head -15 || echo "No WAF/IDS config detected"
```

3. Control-plane audit logging & flow/access logs (CC7.2):
```bash
echo "=== F: AUDIT & ACCESS LOGGING ==="
grep -rniE "cloudtrail|aws_cloudtrail|config_recorder|flow_?log|access_?log|s3.*logging|audit_?log|activity_?log|log_group|cloudwatch_log" \
  --include="*.tf" --include="*.yaml" --include="*.yml" . 2>/dev/null | grep -v "node_modules" | head -20 || echo "No control-plane/audit logging config detected"
```

4. Log retention over 30 days (CC7.2):
```bash
echo "=== F: LOG RETENTION ==="
grep -rniE "retention_in_days|retention_days|retention_period|log_retention|expiration" \
  --include="*.tf" --include="*.yaml" --include="*.yml" . 2>/dev/null | grep -v "node_modules" | head -15 || echo "No explicit log retention config detected"
```

5. Monitoring & security-event alerting (CC7.2):
```bash
echo "=== F: MONITORING & ALERTING ==="
grep -rniE "cloudwatch_alarm|metric_alarm|prometheus|grafana|datadog|sentry|pagerduty|opsgenie|sns_topic|alert|alarm|new relic|honeycomb" \
  --include="*.tf" --include="*.yaml" --include="*.yml" --include="*.ts" --include="*.js" . 2>/dev/null | grep -v "node_modules\|dist" | head -20 || echo "No monitoring/alerting config detected"
```

6. Managed secrets store with rotation (CC6.6):
```bash
echo "=== F: SECRETS STORE & ROTATION ==="
grep -rniE "secrets_?manager|aws_secretsmanager|ssm_parameter|vault|kms|rotation|rotate|parameter_store|sealed-secrets|external-secrets|doppler" \
  --include="*.tf" --include="*.yaml" --include="*.yml" . 2>/dev/null | grep -v "node_modules" | head -15 || echo "No managed secrets store detected"
# Confirm no plaintext secrets committed (report LOCATIONS only, values REDACTED)
grep -rniE "AKIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|OPENSSH|PRIVATE) KEY-----|sk_live_" . 2>/dev/null | grep -v "node_modules\|\.git/" | head -5 | sed -E 's/(AKIA[0-9A-Z]{4}).*/\1[REDACTED]/' || echo "No obvious plaintext cloud secrets found"
```

Controls to record (PLATFORM-AUDITABLE unless noted):
- F1 Network segmentation / private subnets (CC6.6)
- F2 WAF present (CC6.6)
- F3 IDS / threat & anomaly detection (CC7.2)
- F4 Control-plane audit logging, e.g. CloudTrail (CC7.2)
- F5 Flow logs / edge access logs (CC7.2)
- F6 Log retention over 30 days (CC7.2)
- F7 Monitoring with security-event alerting (CC7.2)
- F8 Managed secrets store (CC6.6)
- F9 Secret rotation configured (CC6.6)
- F10 No plaintext secrets in repo (CC6.6) — VALUES REDACTED

STATUS RULES:
- Config verifiable in IaC -> met. Partial coverage -> partial.
- No IaC in repo -> mark infra controls gap and note "infrastructure may be
  provisioned manually / outside this repo (unauditable here)".
- Plaintext secret found -> F10 gap; redact the value.

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/step_06_soc2_infrastructure_network.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Family F control table (control ref, criterion, Status, Owner/lane, Evidence path)
- IaC coverage summary (segmentation / WAF / logging / retention / alerting / secrets)
- Any plaintext-secret locations (VALUES REDACTED)
- Gaps with the exact evidence that would satisfy each
