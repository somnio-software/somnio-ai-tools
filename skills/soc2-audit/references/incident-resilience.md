# SOC 2 Incident Management, BCP & DR (Family H)

> Gather evidence for incident management and resilience — incident-response plan with postmortems, breach-notification SLA (e.g. 48h), business-continuity and disaster-recovery plans tested annually, RPO/RTO targets, and restore drills (CC7.3-CC7.5, CC9.1). Framework-agnostic. Read-only.

---

Goal: Assess incident-response and resilience readiness. Family H mixes
ORGANIZATIONAL artifacts (IR plan, BCP/DR plan, breach-notification SLA) with
PLATFORM-AUDITABLE evidence (multi-AZ, backups, restore automation, RPO/RTO in
IaC). Record Status + Owner/lane + evidence for each control.

PROJECT DETECTION (execute first):
- Read reports/.artifacts/step_01_soc2_project_detection.md for IaC presence
  and cloud provider hints (drives DR evidence).

CONTROL RECORDING FORMAT: control ref (e.g. `H1`), criterion, Status, Owner/lane,
Evidence.

EVIDENCE GATHERING:

1. Incident-response plan & postmortems (CC7.3, CC7.4):
```bash
echo "=== H: INCIDENT RESPONSE ==="
find . -type f -not -path "*/node_modules/*" \( -iname "*incident*response*" -o -iname "*incident*" -o -iname "*runbook*" -o -iname "*playbook*" -o -iname "*postmortem*" -o -iname "*post-mortem*" -o -iname "*oncall*" -o -iname "*on-call*" \) 2>/dev/null | head -15 || echo "No incident-response/runbook/postmortem docs found"
```

2. Breach-notification SLA (CC7.4, CC9.1):
```bash
echo "=== H: BREACH NOTIFICATION SLA ==="
grep -rniE "breach|notification.*(hour|day|48|72)|notify.*(customer|authorit)|data breach|disclosure" docs/ SECURITY.md 2>/dev/null | head -10 || echo "No breach-notification SLA documented"
```

3. Business continuity & disaster recovery, tested annually (CC7.5, A1.2, A1.3):
```bash
echo "=== H: BCP / DR ==="
find . -type f -not -path "*/node_modules/*" \( -iname "*bcp*" -o -iname "*business-continuity*" -o -iname "*disaster*recovery*" -o -iname "*dr-plan*" -o -iname "*continuity*" \) 2>/dev/null | head -10 || echo "No BCP/DR docs found"
```

4. RPO/RTO targets & restore drills, redundancy (CC7.5, A1.2):
```bash
echo "=== H: RPO/RTO, REDUNDANCY & RESTORE ==="
grep -rniE "\brpo\b|\brto\b|recovery point|recovery time|multi.?az|multi_az|availability_zone|replica|failover|standby|cross.region|restore.*(test|drill)" \
  --include="*.tf" --include="*.yaml" --include="*.yml" --include="*.md" . 2>/dev/null | grep -v "node_modules" | head -20 || echo "No RPO/RTO/redundancy evidence detected"
```

Controls to record:
- H1 Incident-response plan present (CC7.3) — ORGANIZATIONAL
- H2 Postmortem / lessons-learned process (CC7.4) — ORGANIZATIONAL
- H3 Breach-notification SLA, e.g. 48h (CC7.4, CC9.1) — ORGANIZATIONAL
- H4 Business-continuity plan (CC7.5) — ORGANIZATIONAL
- H5 Disaster-recovery plan tested annually (CC7.5) — ORGANIZATIONAL (test evidence) / PLATFORM (DR IaC)
- H6 RPO/RTO targets defined (CC9.1) — ORGANIZATIONAL / PLATFORM (backup config)
- H7 Redundancy / multi-AZ / failover (A1.2) — PLATFORM-AUDITABLE
- H8 Restore drill evidence (A1.2) — ORGANIZATIONAL

STATUS RULES:
- Plan/doc artifact found -> met (organizational met = artifact present).
- Redundancy/backup config in IaC -> met for H5-H7 platform portions.
- No evidence -> gap; state the exact artifact or config that would satisfy it.

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/step_08_soc2_incident_resilience.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Family H control table (control ref, criterion, Status, Owner/lane, Evidence path)
- IR / BCP / DR artifact-presence summary
- Redundancy & RPO/RTO evidence summary
- Gaps with the exact artifact or config that would satisfy each
