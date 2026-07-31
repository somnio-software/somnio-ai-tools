# SOC 2 Identity & Access Management (Family C)

> Gather PLATFORM-AUDITABLE evidence for logical access — authentication, authorization/RBAC, privileged-access approval, access reviews/revocation, password standards, MFA, SSO/OIDC, and session management (CC6.1-CC6.3, CC6.6). Framework-agnostic. Read-only. Redact secret values.

---

Goal: Assess the platform's logical access controls from code, configuration,
and IaC. Family C is heavily PLATFORM-AUDITABLE and drives a large share of the
readiness score. Record Status + Owner/lane + evidence for each control.

READ-ONLY and REDACTION: report only the LOCATION of a secret (file + line);
never copy the secret value. If a hardcoded credential is found, mark the
related control as a gap and redact the value in the artifact.

PROJECT DETECTION (execute first):
- Read reports/.artifacts/step_01_soc2_project_detection.md for
  PROJECT_DETECTION_RESULTS. Scan targets per type: Node/NestJS (*.ts,*.js),
  Flutter (*.dart), Go (*.go), Python (*.py), Ruby (*.rb), PHP (*.php),
  .NET (*.cs), plus IaC (*.tf) for IAM.

CONTROL RECORDING FORMAT: for each control record control ref (e.g. `C1`),
criterion, Status (met/partial/gap), Owner/lane, and Evidence (path). Family C
controls are PLATFORM-AUDITABLE unless noted.

EVIDENCE GATHERING:

1. Authentication (CC6.1):
```bash
echo "=== C: AUTHENTICATION ==="
grep -rniE "passport|@nestjs/(passport|jwt)|next-auth|devise|authlib|omniauth|firebase-auth|cognito|auth0|clerk" \
  --include="*.ts" --include="*.js" --include="*.dart" --include="*.py" --include="*.rb" --include="*.go" --include="*.cs" . 2>/dev/null | grep -v "node_modules\|dist\|vendor" | head -20 || echo "No auth library detected"
grep -rniE "AuthGuard|@UseGuards|requireAuth|authenticate|login|signIn" \
  --include="*.ts" --include="*.js" . 2>/dev/null | grep -v "node_modules\|dist\|spec\|test" | head -15 || echo "No auth guard usage detected"
```

2. Authorization / RBAC / privileged access (CC6.1, CC6.3):
```bash
echo "=== C: AUTHORIZATION & RBAC ==="
grep -rniE "rbac|role[s]?[:=]|permission[s]?|@Roles|CanActivate|casl|pundit|cancancan|policy|authorize|isAdmin|scope" \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.rb" --include="*.go" . 2>/dev/null | grep -v "node_modules\|dist\|vendor\|spec\|test" | head -20 || echo "No RBAC/authorization patterns detected"
```

3. MFA / SSO / OIDC / SAML (CC6.1):
```bash
echo "=== C: MFA / SSO / OIDC ==="
grep -rniE "\bmfa\b|totp|two-factor|2fa|otp|webauthn|oidc|openid|saml|single sign|sso" \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.rb" --include="*.go" --include="*.tf" . 2>/dev/null | grep -v "node_modules\|dist\|vendor" | head -20 || echo "No MFA/SSO/OIDC patterns detected"
```

4. Password standards — complexity, lockout, expiry, reuse history (CC6.1):
```bash
echo "=== C: PASSWORD STANDARDS ==="
grep -rniE "bcrypt|argon2|scrypt|pbkdf2|passwordPolicy|minLength|complexity|lockout|maxAttempts|password.*exp_ir|reuse|passwordHistory" \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.rb" --include="*.go" . 2>/dev/null | grep -v "node_modules\|dist\|vendor\|spec\|test" | head -20 || echo "No password-policy/hashing patterns detected"
```

5. Session management — timeout, expiry, revocation (CC6.1):
```bash
echo "=== C: SESSION MANAGEMENT ==="
grep -rniE "session|cookie|httpOnly|sameSite|secure:\s*true|maxAge|expiresIn|refreshToken|revoke|logout|jwt.*exp" \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.rb" --include="*.go" . 2>/dev/null | grep -v "node_modules\|dist\|vendor\|spec\|test" | head -20 || echo "No session-management patterns detected"
```

6. Access reviews & timely revocation, least-privilege IAM (CC6.2, CC6.3):
```bash
echo "=== C: ACCESS REVIEW & IAM LEAST PRIVILEGE ==="
grep -rniE "aws_iam_policy|iam_role|Action\"?\s*[:=]|Effect|least.privilege|assume_role_policy|principalOrgID" \
  --include="*.tf" --include="*.json" --include="*.yaml" --include="*.yml" . 2>/dev/null | grep -v "node_modules" | head -20 || echo "No IAM policy definitions detected"
find . -type f -not -path "*/node_modules/*" \( -iname "*access-review*" -o -iname "*deprovision*" -o -iname "*offboarding*" \) 2>/dev/null | head -5
grep -rniE "\"\\*\"|Resource.*\\*|Action.*\\*" --include="*.tf" . 2>/dev/null | head -10 && echo "(wildcard IAM = least-privilege risk if present)"
```

Controls to record (all PLATFORM-AUDITABLE unless noted):
- C1 Unique accounts / no shared credentials (CC6.1)
- C2 Authentication implemented (CC6.1)
- C3 Authorization/RBAC enforced (CC6.1, CC6.3)
- C4 Privileged-access approval workflow (CC6.3) — often ORGANIZATIONAL
- C5 Access reviews + timely revocation (CC6.2) — often ORGANIZATIONAL
- C6 Password standards: complexity/lockout/expiry/reuse (CC6.1)
- C7 MFA enforced, especially for admins (CC6.1)
- C8 SSO/OIDC/SAML (CC6.1)
- C9 Session management: timeout/expiry/revocation (CC6.1)
- C10 Least-privilege IAM in IaC — no wildcard actions (CC6.3, CC6.6)

STATUS RULES:
- Control implemented and verifiable in code/IaC -> met.
- Partial implementation (e.g. auth present but no MFA) -> partial.
- No evidence -> gap; state the exact evidence that would satisfy it.
- Hardcoded secret found -> C-secrets gap; redact the value.

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/step_03_soc2_access_management.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Family C control table (control ref, criterion, Status, Owner/lane, Evidence path)
- Any hardcoded-credential locations (VALUES REDACTED)
- Gaps with the exact evidence that would satisfy each
