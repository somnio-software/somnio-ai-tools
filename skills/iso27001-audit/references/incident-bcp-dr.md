# Category H - Incident Management, BCP/DR Evidence (A.5.24-A.5.28, A.5.29, A.5.30, A.8.13, A.8.14)

> Gather in-repo evidence for incident management + evidence handling, ICT readiness for business continuity, redundancy, and backups. Framework-agnostic, read-only. Mixed lanes: incident/continuity docs are ORGANIZATIONAL; backup/redundancy config is PLATFORM-AUDITABLE.

---

Goal: Determine whether the repository demonstrates incident response and
resilience controls. Record Status + Owner/lane per control.

PROJECT DETECTION (execute first):
- Read `reports/.artifacts/step_01_iso27001_project_detection.md`.

CONTROL EVIDENCE:

A.5.24-A.5.26 Incident management planning, assessment, response
(ORGANIZATIONAL) - incident response plan / runbook / on-call:
```bash
find . -maxdepth 5 \( -iname "*incident*response*" -o -iname "*incident*.md" -o -iname "*runbook*" -o -iname "*playbook*" -o -iname "*on-?call*" -o -iname "*escalation*" -o -path "*/docs/incident*" \) -not -path "*/node_modules/*" 2>/dev/null | head -20 || echo "No incident-response artifacts found"
grep -rniE "incident|escalat|severity|sev-?[0-9]|postmortem|post-?mortem|blameless" . --include=*.md -l 2>/dev/null | grep -v node_modules | head -15 || echo "No incident-process evidence found"
```

A.5.27 Learning from incidents / A.5.28 Collection of evidence
(ORGANIZATIONAL) - postmortems, evidence-handling procedure:
```bash
find . -maxdepth 5 \( -iname "*postmortem*" -o -iname "*post-mortem*" -o -iname "*lessons*learned*" -o -iname "*evidence*handling*" -o -iname "*forensic*" \) -not -path "*/node_modules/*" 2>/dev/null | head -15 || echo "No postmortem / evidence-handling artifacts found"
```

A.5.29 Information security during disruption / A.5.30 ICT readiness for
business continuity (ORGANIZATIONAL + PLATFORM-AUDITABLE) - BCP/DR plan, RTO/RPO,
failover:
```bash
find . -maxdepth 5 \( -iname "*business*continuity*" -o -iname "*bcp*" -o -iname "*disaster*recovery*" -o -iname "*dr-plan*" -o -iname "*rto*" -o -iname "*rpo*" -o -iname "*failover*" \) -not -path "*/node_modules/*" 2>/dev/null | head -15 || echo "No BCP/DR artifacts found"
grep -rniE "rto|rpo|failover|multi-?az|multi-?region|standby|disaster recovery|high availability" . 2>/dev/null | grep -vE "node_modules|dist|test" | head -15 || echo "No continuity/failover evidence found"
```

A.8.13 Information backup (PLATFORM-AUDITABLE) - backup config, snapshots,
retention:
```bash
grep -rniE "backup|snapshot|point.?in.?time|pitr|retention|dump|pg_?dump|restore|s3.*backup|rds.*backup|backup_?retention" . --include=*.tf --include=*.yaml --include=*.yml --include=*.sh 2>/dev/null | grep -v node_modules | head -25 || echo "No backup configuration evidence found"
```

A.8.14 Redundancy of information processing facilities (PLATFORM-AUDITABLE) -
replicas, auto-scaling, multi-AZ:
```bash
grep -rniE "replica|replicas: ?[2-9]|auto.?scal|min_?size|desired_?capacity|multi-?az|read.?replica|cluster" . --include=*.tf --include=*.yaml --include=*.yml 2>/dev/null | grep -v node_modules | head -20 || echo "No redundancy/scaling evidence found"
```

READ-ONLY + SECRET SAFETY: read only; redact secret VALUES as `[REDACTED]`.

ARTIFACT SAVE (mandatory):
Save output to: reports/.artifacts/step_09_iso27001_incident_bcp_dr.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Category H control table: Annex A ref | control name | Status | Owner/lane |
  evidence (path) or "No evidence found" | gap + satisfying artifact
- Note whether backup/DR is repo-verifiable (PLATFORM) or customer-operated
  (CLIENT)
- Summary: count of Met / Partial / Gap / Organizational
