# Category B - Human Resources Security Evidence (A.6.1-A.6.4, A.6.6, A.8.1, A.8.7)

> Gather in-repo evidence for background checks, confidentiality/security terms, awareness training, and asset/endpoint controls. Framework-agnostic, read-only. Most People (A.6) controls are ORGANIZATIONAL documentation-evidence checks; a few asset/endpoint controls are PLATFORM-AUDITABLE or CLIENT-lane.

---

Goal: Determine whether the repository contains evidence of human-resources
security controls. Record a Status and Owner/lane for every control.

PROJECT DETECTION (execute first):
- Read `reports/.artifacts/step_01_iso27001_project_detection.md` for
  PROJECT_DETECTION_RESULTS and governance/policy docs.

STATUS + OWNER/LANE:
- People controls (A.6.x) are ORGANIZATIONAL - check "policy artifact present?
  yes/no". Background checks and training records are usually CLIENT-lane
  (the deploying organization's HR responsibility) - LIST them, do NOT
  penalize the score.
- A.8.1 (user endpoint devices) and A.8.7 (malware protection) may be
  PLATFORM-AUDITABLE where the repo configures endpoints/CI runners.

CONTROL EVIDENCE:

A.6.1 Screening / background checks (ORGANIZATIONAL / CLIENT)
```bash
grep -rniE "background check|screening|pre-?employment|vetting" . --include=*.md -l 2>/dev/null | grep -v node_modules | head -10 || echo "No screening evidence found (typically CLIENT/HR responsibility)"
```

A.6.2 Terms and conditions of employment - confidentiality/security terms
(ORGANIZATIONAL); A.6.6 Confidentiality / NDA (ORGANIZATIONAL)
```bash
find . -maxdepth 5 -type f \( -iname "*nda*" -o -iname "*confidential*" -o -iname "*acceptable-use*" -o -iname "*code-of-conduct*" -o -iname "CONTRIBUTING.md" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -20 || echo "No confidentiality/AUP artifacts found"
grep -rniE "confidential|acceptable use|security responsib" . --include=*.md -l 2>/dev/null | grep -v node_modules | head -10 || echo "No security-terms evidence found"
```

A.6.3 Information security awareness, education and training (ORGANIZATIONAL /
CLIENT)
```bash
find . -maxdepth 5 -type f \( -iname "*awareness*" -o -iname "*training*" -o -iname "*onboarding*security*" -o -path "*/docs/security/onboarding*" \) -not -path "*/node_modules/*" 2>/dev/null | head -20 || echo "No security-awareness/training artifacts found"
```

A.6.4 Disciplinary process (ORGANIZATIONAL / CLIENT)
```bash
grep -rniE "disciplinary|sanction|violation.*polic" . --include=*.md -l 2>/dev/null | grep -v node_modules | head -10 || echo "No disciplinary-process evidence found"
```

A.8.1 User endpoint devices (PLATFORM-AUDITABLE if configured, else CLIENT)
- Look for endpoint hardening / MDM references, devcontainer or CI-runner
  hardening, or documented endpoint policy.
```bash
find . \( -name "devcontainer.json" -o -path "*/.devcontainer/*" -o -iname "*mdm*" -o -iname "*endpoint*polic*" \) -not -path "*/node_modules/*" 2>/dev/null | head -15 || echo "No endpoint-configuration evidence found"
```

A.8.7 Protection against malware (PLATFORM-AUDITABLE where CI scans / image
scanning present)
```bash
grep -rniE "clamav|malware|virus.?scan|trivy|image scan|anti-?malware" . --include=*.yml --include=*.yaml -l 2>/dev/null | grep -vE "node_modules" | head -15 || echo "No malware-protection tooling evidence found"
```

READ-ONLY + SECRET SAFETY: read only; redact any secret VALUE as `[REDACTED]`.

ARTIFACT SAVE (mandatory):
Save output to: reports/.artifacts/step_03_iso27001_human_resources_security.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Category B control table: Annex A ref | control name | Status | Owner/lane |
  evidence (path) or "No evidence found" | gap statement + satisfying artifact
- Clearly mark CLIENT-lane controls (do not penalize score)
- Summary: count of Met / Partial / Gap / Organizational, and count of
  CLIENT-lane controls listed
