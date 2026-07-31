# Category C - Identity & Access Management Evidence (A.5.15-A.5.18, A.8.2, A.8.5)

> Gather in-repo evidence for unique identities, access control, privileged access, access reviews/revocation, authentication/password policy, MFA, and SSO. Framework-agnostic, read-only. This category is heavily PLATFORM-AUDITABLE - score it heavily.

---

Goal: Determine whether the application/repository implements identity and
access controls. Record a Status and Owner/lane for every control.

PROJECT DETECTION (execute first):
- Read `reports/.artifacts/step_01_iso27001_project_detection.md` for
  PROJECT_DETECTION_RESULTS. Scan the source of each detected project.

STATUS + OWNER/LANE:
- Most controls here are PLATFORM-AUDITABLE (auth code, guards, IaC IAM).
- The access-control POLICY document (A.5.15) is ORGANIZATIONAL; the
  ENFORCEMENT is PLATFORM-AUDITABLE.
- Provisioning of real human accounts is often CLIENT-lane - list, don't
  penalize.

CONTROL EVIDENCE (adapt greps to the detected stack; examples cover common
stacks - extend to *.dart, *.go, *.py, *.cs, *.rs, *.kt as detected):

A.5.15 Access control (policy + enforcement)
- Policy doc (ORGANIZATIONAL):
```bash
find . -maxdepth 5 -iname "*access*control*polic*" -o -iname "*rbac*polic*" 2>/dev/null | grep -v node_modules | head -10 || echo "No access-control policy artifact found"
```
- Enforcement (PLATFORM-AUDITABLE) - authz guards / middleware / RBAC:
```bash
grep -rniE "authoriz|@Roles|RolesGuard|AuthGuard|require_?role|can(can|cancan)|casl|permission|policy|@PreAuthorize|middleware.*auth" . --include=*.ts --include=*.js --include=*.py --include=*.rb --include=*.go --include=*.cs 2>/dev/null | grep -vE "node_modules|dist|test|spec" | head -30 || echo "No authorization enforcement found"
```

A.5.16 Identity management / A.5.17 Authentication information (PLATFORM-AUDITABLE)
- Auth mechanisms, password hashing, token issuance:
```bash
grep -rniE "bcrypt|argon2|scrypt|pbkdf2|passport|next-?auth|jwt|oauth|oidc|session" . --include=*.ts --include=*.js --include=*.py --include=*.go --include=*.cs --include=pubspec.yaml --include=package.json 2>/dev/null | grep -vE "node_modules|dist|test|spec" | head -30 || echo "No authentication mechanism evidence found"
# Password policy / complexity:
grep -rniE "password.{0,20}(min|length|complexity|policy|strength|zxcvbn)" . 2>/dev/null | grep -vE "node_modules|dist|test" | head -15 || echo "No password-policy evidence found"
```

A.5.17 MFA / SSO (PLATFORM-AUDITABLE)
```bash
grep -rniE "mfa|multi-?factor|totp|otp|webauthn|saml|sso|single sign|okta|auth0|entra|azure ad|cognito" . 2>/dev/null | grep -vE "node_modules|dist|test|spec" | head -20 || echo "No MFA/SSO evidence found"
```

A.5.18 Access rights - provisioning, review, revocation (PLATFORM-AUDITABLE
where IaC-managed; else ORGANIZATIONAL/CLIENT)
- IaC IAM (Terraform/cloud roles), joiner-mover-leaver evidence:
```bash
grep -rniE "aws_iam|iam_role|iam_policy|role_binding|ClusterRole|azurerm_role|google_project_iam|least privilege" . --include=*.tf --include=*.yaml --include=*.yml 2>/dev/null | grep -v node_modules | head -25 || echo "No IaC IAM evidence found"
find . -maxdepth 5 -iname "*access*review*" -o -iname "*joiner*mover*leaver*" -o -iname "*offboarding*" 2>/dev/null | grep -v node_modules | head -10 || echo "No access-review/revocation process artifact found"
```

A.8.2 Privileged access rights (PLATFORM-AUDITABLE)
```bash
grep -rniE "admin|superuser|root|privileged|sudo|is_?admin|elevated|break-?glass" . --include=*.ts --include=*.tf --include=*.yaml --include=*.py 2>/dev/null | grep -vE "node_modules|dist|test" | head -20 || echo "No privileged-access evidence found"
```

A.8.5 Secure authentication (PLATFORM-AUDITABLE) - secure session/cookie flags,
rate limiting on auth, lockout:
```bash
grep -rniE "httpOnly|secure: ?true|sameSite|rate.?limit|throttle|lockout|failed.?login|helmet" . 2>/dev/null | grep -vE "node_modules|dist|test" | head -20 || echo "No secure-authentication hardening evidence found"
```

READ-ONLY + SECRET SAFETY: read only; if a hardcoded credential VALUE is
matched, record the file/line and redact the value as `[REDACTED]`. Do NOT
reproduce the secret. (Deep secret scanning is Category D / F.)

ARTIFACT SAVE (mandatory):
Save output to: reports/.artifacts/step_04_iso27001_identity_access_management.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Category C control table: Annex A ref | control name | Status | Owner/lane |
  evidence (path:line) or "No evidence found" | gap + satisfying artifact
- Summary: count of Met / Partial / Gap / Organizational; note CLIENT-lane
