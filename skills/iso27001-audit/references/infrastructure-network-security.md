# Category F - Infrastructure & Network Security Evidence (A.8.20-A.8.23, A.8.15, A.8.16, A.8.24)

> Gather in-repo evidence for network security/segmentation, service security, web filtering, event logging + clock synchronization, monitoring, and secrets/key management at the infrastructure layer. Framework-agnostic, read-only. PLATFORM-AUDITABLE where IaC exists; otherwise CLIENT-lane.

---

Goal: Determine whether the infrastructure/network posture is secured. Record
Status + Owner/lane per control. Where the repository has no IaC and
infrastructure is provisioned by the deploying customer, mark controls
CLIENT-lane and LIST them without penalizing the score.

PROJECT DETECTION (execute first):
- Read `reports/.artifacts/step_01_iso27001_project_detection.md` for IaC/CI
  surfaces.

CONTROL EVIDENCE:

A.8.20 Networks security / A.8.22 Segregation of networks (PLATFORM-AUDITABLE
via IaC) - VPC/subnets/security groups/network policies:
```bash
grep -rniE "vpc|subnet|security_?group|nacl|network_?policy|ingress|egress|firewall|private_?subnet|peering|cidr" . --include=*.tf --include=*.yaml --include=*.yml 2>/dev/null | grep -v node_modules | head -30 || echo "No network-security IaC evidence found (infra may be CLIENT-managed)"
```

A.8.21 Security of network services (PLATFORM-AUDITABLE) - TLS termination,
API gateway, WAF, mTLS:
```bash
grep -rniE "waf|web.?application.?firewall|api.?gateway|load.?balancer|listener|mtls|mutual tls|cloudfront|cloudflare|nginx|ingress" . --include=*.tf --include=*.conf --include=*.yaml --include=*.yml 2>/dev/null | grep -v node_modules | head -25 || echo "No network-service-security evidence found"
```

A.8.23 Web filtering (PLATFORM-AUDITABLE / CLIENT)
```bash
grep -rniE "web.?filter|url.?filter|allowlist|blocklist|denylist|egress.?filter|proxy" . 2>/dev/null | grep -vE "node_modules|dist|test" | head -15 || echo "No web-filtering evidence found"
```

A.8.15 Logging - event logging (PLATFORM-AUDITABLE) - structured logging,
audit logging:
```bash
grep -rniE "winston|pino|bunyan|logrus|zap|structlog|serilog|nestjs.*Logger|audit.?log|log4j|slf4j|cloudwatch|datadog|opentelemetry|otel" . 2>/dev/null | grep -vE "node_modules|dist|test|spec" | head -25 || echo "No logging framework/audit-log evidence found"
```

A.8.16 Monitoring activities (PLATFORM-AUDITABLE) - metrics, alerting, health:
```bash
grep -rniE "prometheus|grafana|datadog|sentry|newrelic|cloudwatch alarm|alert|/health|/metrics|healthcheck|liveness|readiness|pagerduty|opsgenie" . 2>/dev/null | grep -vE "node_modules|dist|test" | head -25 || echo "No monitoring/alerting evidence found"
```

A.8.17 Clock synchronization (PLATFORM-AUDITABLE / CLIENT) - NTP/time sync:
```bash
grep -rniE "ntp|chrony|timesyncd|clock.?sync|time.?server|utc" . --include=*.tf --include=*.yaml --include=Dockerfile* 2>/dev/null | grep -v node_modules | head -10 || echo "No clock-synchronization evidence found (often CLIENT/host-managed)"
```

A.8.24 Cryptography at the infrastructure layer (PLATFORM-AUDITABLE) - TLS
policy, cert management, KMS at infra level (cross-reference Category D):
```bash
grep -rniE "acm|cert-?manager|letsencrypt|tls_?policy|ssl_?policy|kms_?key|certificate" . --include=*.tf --include=*.yaml --include=*.yml 2>/dev/null | grep -v node_modules | head -20 || echo "No infra-layer cryptography evidence found"
```

Secrets/key management at infra layer (PLATFORM-AUDITABLE) - no plaintext
secrets in IaC:
```bash
grep -rniE "secrets?manager|ssm.*secure|vault|sealed.?secret|external-?secrets|kms" . --include=*.tf --include=*.yaml --include=*.yml 2>/dev/null | grep -v node_modules | head -15 || echo "No infra secrets-management evidence found"
```

READ-ONLY + SECRET SAFETY: read only; if IaC/state files contain secret
VALUES, note the location and redact as `[REDACTED]` - never copy the value.

ARTIFACT SAVE (mandatory):
Save output to: reports/.artifacts/step_07_iso27001_infrastructure_network_security.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Category F control table: Annex A ref | control name | Status | Owner/lane |
  evidence (path) or "No evidence found" | gap + satisfying artifact
- Clearly mark CLIENT-lane controls where infra is customer-managed
- Summary: count of Met / Partial / Gap / Organizational; CLIENT-lane count
