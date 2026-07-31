# SOC 2 Governance, People & AI Program (Families A, B, J)

> Gather evidence for the organizational-heavy control families — Governance & Program (A: CC1.x/CC3.x/CC5.x), Human Resources Security (B: CC1.4), and AI Governance (J: CC1.x/CC4.x). Mostly ORGANIZATIONAL controls: the check is whether the policy artifact EXISTS in the repository. Read-only, evidence-based.

---

Goal: Determine whether the governance, people-security, and AI-governance
policy artifacts exist in the repository, and record each control's Status and
ownership lane. These families are dominated by ORGANIZATIONAL controls, so the
audit reports "policy artifact present? yes/no" and awards limited partial
credit for a present artifact. It never invents a policy that is not there.

PROJECT DETECTION (execute first):
- Read reports/.artifacts/step_01_soc2_project_detection.md for the governance
  document surface and repository structure.

CONTROL RECORDING FORMAT (use for every control below):
For each control, record: control ref (e.g. `A1`), SOC 2 criterion (e.g.
`CC1.1`), Status (met / partial / gap / organizational), Owner/lane
(PLATFORM-AUDITABLE / ORGANIZATIONAL / CLIENT-CUEC), Evidence (file path found
or "not found"), and — when a gap — the exact artifact that would satisfy it.
NEVER copy secret values into the artifact.

FAMILY A — GOVERNANCE & PROGRAM (CC1.x, CC3.x, CC5.x):
Check for the presence of policy artifacts (ORGANIZATIONAL — artifact-presence):

```bash
echo "=== FAMILY A: GOVERNANCE & PROGRAM ==="
# Information security policy set / security leadership
ls SECURITY.md .github/SECURITY.md docs/security/*.md 2>/dev/null
find . -type f -not -path "*/node_modules/*" \( -iname "*security-policy*" -o -iname "*information-security*" -o -iname "*isms*" -o -iname "*acceptable-use*" \) 2>/dev/null | head -10
# Compliance program docs, risk assessment, exception/waiver process
find . -type d \( -iname "compliance" -o -iname "policies" \) -not -path "*/node_modules/*" 2>/dev/null | head -5
find . -type f -not -path "*/node_modules/*" \( -iname "*risk-assessment*" -o -iname "*risk-register*" -o -iname "*exception*" -o -iname "*waiver*" \) 2>/dev/null | head -10
# Code of conduct / ownership (segregation of duties signal)
ls CODE_OF_CONDUCT.md CODEOWNERS .github/CODEOWNERS 2>/dev/null
```

Controls to record:
- A1 Information security policy set exists (CC5.1) — ORGANIZATIONAL
- A2 Security leadership / ownership defined, e.g. CODEOWNERS (CC1.3) — ORGANIZATIONAL
- A3 Annual/periodic risk assessment documented (CC3.1-CC3.2) — ORGANIZATIONAL
- A4 Exception/waiver process documented (CC5.3) — ORGANIZATIONAL
- A5 Code of conduct present (CC1.1) — ORGANIZATIONAL

FAMILY B — HUMAN RESOURCES SECURITY (CC1.4):
Most B controls are CLIENT/CUEC or ORGANIZATIONAL (HR processes rarely live in
a code repo). Check only for artifacts that can appear in-repo:

```bash
echo "=== FAMILY B: HUMAN RESOURCES SECURITY ==="
find . -type f -not -path "*/node_modules/*" \( -iname "*onboarding*" -o -iname "*offboarding*" -o -iname "*awareness*training*" -o -iname "*nda*" -o -iname "*confidentiality*" -o -iname "*workstation*" -o -iname "*device-policy*" -o -iname "*mdm*" \) 2>/dev/null | head -15
```

Controls to record:
- B1 Security-awareness training material/policy present (CC1.4) — ORGANIZATIONAL
- B2 Confidentiality/NDA clause referenced (CC1.4) — ORGANIZATIONAL
- B3 Background-check process — CLIENT/CUEC (mark out-of-scope; do not penalize)
- B4 Workstation / device (MDM) controls documented (CC1.4) — ORGANIZATIONAL

FAMILY J — AI GOVERNANCE (CC1.x, CC4.x):
Check for an AI usage policy and data-handling statements:

```bash
echo "=== FAMILY J: AI GOVERNANCE ==="
find . -type f -not -path "*/node_modules/*" \( -iname "*ai-policy*" -o -iname "*ai-usage*" -o -iname "*ai-governance*" -o -iname "*model-card*" -o -iname "*responsible-ai*" \) 2>/dev/null | head -10
# Statement on training data / PII removal / human review (grep docs)
grep -rniE "does not train on|not used to train|training data|pii removal|human review|human-in-the-loop|bias" docs/ README.md 2>/dev/null | head -20 || echo "No AI data-handling statements found in docs"
```

Controls to record:
- J1 AI usage policy present (CC1.x) — ORGANIZATIONAL
- J2 Statement on whether client data trains models + PII removal (CC1.x) — ORGANIZATIONAL
- J3 Human review of AI outputs for accuracy/bias documented (CC4.x) — ORGANIZATIONAL

STATUS RULES:
- Artifact found and substantive -> met (for ORGANIZATIONAL controls, "met"
  means the policy artifact exists in-repo).
- Artifact found but thin/placeholder -> partial.
- No artifact -> gap, and note "organizational" lane (policy/process work).
- CLIENT/CUEC controls -> record as CUEC; never mark as a platform gap.

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/step_02_soc2_governance_program.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Family A / B / J control tables (control ref, criterion, Status, Owner/lane, Evidence)
- Policy-artifact-present summary (yes/no per artifact)
- List of CUEC controls surfaced (for the CUEC report section)
- Gaps with the exact artifact that would satisfy each
