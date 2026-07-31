# Category K - Evidence / ISMS Artifacts + ISMS Clauses 4-10 (Clauses 6, 9)

> Gather in-repo evidence for the Statement of Applicability, risk treatment plan, ISO 27001 certificate, internal-audit and management-review records, AND assess the ISMS management-system clauses 4-10. This is ISO 27001's delta versus SOC 2 - it is FIRST-CLASS. Framework-agnostic, read-only. These controls are ORGANIZATIONAL: the audit checks whether the artifact EXISTS in the repository.

---

Goal: Determine whether the ISMS management-system artifacts (clauses 4-10)
and the mandatory documented information exist in the repository. Record Status
+ Owner/lane per artifact/clause, and produce the raw material for the report's
ISMS Clause Coverage section and Statement of Applicability starter.

PROJECT DETECTION (execute first):
- Read `reports/.artifacts/step_01_iso27001_project_detection.md` for the
  governance/policy docs already enumerated.

STATUS + OWNER/LANE:
- Category K controls are ORGANIZATIONAL - report each as
  "ISMS artifact present? yes/no" with the path if present. Absence IS a valid
  gap. Do NOT fabricate artifact contents.

MANDATORY ISMS DOCUMENTED INFORMATION (Clause 7.5) - search for each:

Statement of Applicability (Clause 6.1.3 d; the central ISO 27001 artifact):
```bash
find . -maxdepth 6 \( -iname "*statement*applicab*" -o -iname "*soa*.md" -o -iname "*soa*.xlsx" -o -iname "*soa*.csv" -o -iname "annex*a*" \) -not -path "*/node_modules/*" 2>/dev/null | head -10 || echo "No Statement of Applicability found"
```

Risk assessment methodology + risk register + risk treatment plan (Clause 6.1):
```bash
find . -maxdepth 6 \( -iname "*risk*assess*" -o -iname "*risk*register*" -o -iname "*risk*treatment*" -o -iname "*risk*methodolog*" \) -not -path "*/node_modules/*" 2>/dev/null | head -15 || echo "No risk assessment / treatment artifacts found"
```

ISMS scope + information security policy + objectives (Clauses 4.3, 5.2, 6.2):
```bash
find . -maxdepth 6 \( -iname "*isms*scope*" -o -iname "*scope*statement*" -o -iname "*security*objective*" -o -iname "*information-security-policy*" -o -iname "*isms*" \) -not -path "*/node_modules/*" 2>/dev/null | head -15 || echo "No ISMS scope / objectives artifacts found"
```

Internal audit + management review records (Clause 9.2, 9.3):
```bash
find . -maxdepth 6 \( -iname "*internal*audit*" -o -iname "*management*review*" -o -iname "*audit*log*record*" -o -iname "*audit*program*" \) -not -path "*/node_modules/*" 2>/dev/null | head -15 || echo "No internal-audit / management-review records found"
```

Nonconformity / corrective action + continual improvement (Clause 10):
```bash
find . -maxdepth 6 \( -iname "*nonconform*" -o -iname "*corrective*action*" -o -iname "*capa*" -o -iname "*continual*improve*" -o -iname "*improvement*log*" \) -not -path "*/node_modules/*" 2>/dev/null | head -15 || echo "No nonconformity / continual-improvement records found"
```

ISO 27001 certificate / external audit evidence (if already certified):
```bash
find . -maxdepth 6 \( -iname "*iso*27001*cert*" -o -iname "*certificate*" -o -iname "*stage*[12]*audit*" \) -not -path "*/node_modules/*" 2>/dev/null | head -10 || echo "No ISO 27001 certificate found"
```

ISMS CLAUSE 4-10 EVIDENCE CHECK (FIRST-CLASS - map each clause to an artifact):
For each management-system clause, record present/absent + the artifact path:
- Clause 4 Context of the organization & ISMS scope -> ISMS scope statement,
  interested parties, boundaries
- Clause 5 Leadership -> information security policy, roles/responsibilities,
  management commitment/approval
- Clause 6 Planning -> risk assessment methodology, risk register, risk
  treatment plan, Statement of Applicability, security objectives
- Clause 7 Support -> competence/awareness evidence, documented information
  control, communication plan, resources
- Clause 8 Operation -> operational controls, operational risk assessments
  performed at planned intervals
- Clause 9 Performance evaluation -> monitoring/measurement, internal audit
  program, management review records
- Clause 10 Improvement -> nonconformity & corrective action, continual
  improvement records

READ-ONLY + SECRET SAFETY: read only; redact secret VALUES as `[REDACTED]`.

ARTIFACT SAVE (mandatory):
Save output to: reports/.artifacts/step_12_iso27001_evidence_isms_artifacts.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Category K artifact table: artifact/clause | related Annex A / clause ref |
  present? (yes/no) | Status (Met/Partial/Gap/Organizational) | Owner/lane
  (ORGANIZATIONAL) | path or "No evidence found" | the artifact that would
  satisfy it
- ISMS CLAUSE COVERAGE table (clauses 4-10): clause | expected artifact |
  present? | evidence path | gap
- SoA SEEDING: for each Annex A category (A-K) covered by the other steps,
  note whether an SoA row can be pre-filled (control applicable? status?) so
  the report generator can assemble the SoA starter
- Summary: count of present vs missing mandatory ISMS artifacts; overall ISMS
  documentation maturity note
