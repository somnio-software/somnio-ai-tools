# Category A - Governance & Program Evidence (A.5.1, A.5.2, A.5.4, A.5.7; Clauses 5-6)

> Gather in-repo evidence for the information security policy set + annual review, security leadership/roles, risk assessment + treatment, and the exception process. Framework-agnostic, read-only, evidence-based. Most Category A controls are ORGANIZATIONAL: the audit checks whether the artifact EXISTS in the repository.

---

Goal: Determine whether the repository contains evidence of an information
security governance program. Record a Status and an Owner/lane for every
control below.

PROJECT DETECTION (execute first):
- Read `reports/.artifacts/step_01_iso27001_project_detection.md` for
  PROJECT_DETECTION_RESULTS and the enumerated governance/policy docs.

STATUS + OWNER/LANE (record for every control):
- Status: Met | Partial | Gap | Organizational
- Owner/lane: PLATFORM-AUDITABLE | ORGANIZATIONAL | CLIENT
- Category A controls are predominantly ORGANIZATIONAL. Report each as
  "policy artifact present? yes/no" with the path if present. Do NOT invent
  policy content - only report what the repository actually contains.

CONTROL EVIDENCE:

A.5.1 Policies for information security (Clause 5.2 policy; ORGANIZATIONAL)
- Look for an information security policy set and evidence of review cadence.
```bash
find . -maxdepth 5 -type f \( -iname "*security*polic*" -o -iname "*information-security*" -o -iname "*infosec*" -o -iname "SECURITY.md" -o -path "*/policies/*" -o -path "*/docs/security/*" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -40
# Review cadence / last-reviewed evidence:
grep -rniE "last reviewed|review date|reviewed annually|next review|version history" $(find . -maxdepth 5 -iname "*polic*.md" -not -path "*/node_modules/*" 2>/dev/null | head -20) 2>/dev/null | head -20 || echo "No policy review-cadence evidence found"
```
- Met = policy set present WITH review-cadence evidence; Partial = policy
  present but no review cadence; Gap = no policy artifact.

A.5.2 Information security roles and responsibilities (ORGANIZATIONAL)
- Look for defined security roles / responsibility matrix / RACI.
```bash
grep -rniE "security (officer|lead|owner|team|responsib)|CISO|responsibility matrix|RACI" . --include=*.md --include=CODEOWNERS -l 2>/dev/null | grep -v node_modules | head -20 || echo "No documented security roles found"
```

A.5.4 Management responsibilities (Clause 5.1 leadership; ORGANIZATIONAL)
- Look for evidence of management commitment / leadership sign-off / policy
  approval by named role.
```bash
grep -rniE "approved by|management (approval|commitment|review)|leadership|sign-?off|endorsed by" $(find . -maxdepth 5 -iname "*polic*.md" -o -iname "*isms*" 2>/dev/null | grep -v node_modules | head -20) 2>/dev/null | head -20 || echo "No management-responsibility evidence found"
```

A.5.7 Threat intelligence (may be PLATFORM-AUDITABLE if automated)
- Look for automated threat-intel / advisory ingestion (e.g. GitHub security
  advisories, dependabot alerts config, feeds) or a documented process.
```bash
find . \( -path "*/.github/dependabot.yml" -o -name "dependabot.yml" -o -iname "*threat*intel*" -o -iname "*advisory*" \) -not -path "*/node_modules/*" 2>/dev/null | head -20 || echo "No threat-intelligence evidence found"
```

Clause 6 Planning - Risk assessment & treatment (ORGANIZATIONAL; also feeds
Category K):
- Look for a risk assessment methodology, risk register, and risk treatment
  plan, plus an exception/deviation process.
```bash
find . -maxdepth 5 -type f \( -iname "*risk*assess*" -o -iname "*risk*register*" -o -iname "*risk*treatment*" -o -iname "*risk-methodology*" -o -iname "*exception*" -o -iname "*deviation*" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -30 || echo "No risk-assessment / treatment / exception artifacts found"
```

READ-ONLY + SECRET SAFETY:
- Only read files. If any matched file contains a secret VALUE, do NOT copy
  it; note the location and redact as `[REDACTED]`.

ARTIFACT SAVE (mandatory):
Save output to: reports/.artifacts/step_02_iso27001_governance_program.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Category A control table, one row per control:
  Annex A ref | control name | Status (Met/Partial/Gap/Organizational) |
  Owner/lane | evidence (path) or "No evidence found" | gap statement +
  the artifact that would satisfy it
- Note which ISMS clauses (5-6) this evidence supports (feeds Category K /
  ISMS Clause Coverage)
- Summary: count of Met / Partial / Gap / Organizational controls
