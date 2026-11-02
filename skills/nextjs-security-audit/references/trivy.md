# Next.js Trivy Scan

> Run a Trivy filesystem scan for vulnerabilities and misconfigurations (Dockerfile, IaC) if Trivy is installed. Optional step; skips gracefully if Trivy is not installed. If not installed, adds an installation recommendation to the report.

---

Goal: Get a second opinion on dependency vulnerabilities and check the
container/infrastructure files that ship the Next.js app. The rules for
vulnerability evidence are in `references/live-vulnerability-sources.md`
(installed versions only, advisory ID for every finding).

TRIVY DETECTION (execute first):

```bash
echo "=== Trivy Filesystem Scan ==="
mkdir -p reports/.artifacts/nextjs-security-audit

if ! command -v trivy &> /dev/null; then
  echo "Trivy: NOT_INSTALLED"
  echo "Recommendation: Install Trivy for vulnerability and misconfiguration scanning"
  echo "  macOS: brew install trivy"
  echo "  Linux: see https://github.com/aquasecurity/trivy"
else
  echo "Trivy: INSTALLED ($(trivy --version 2>/dev/null | head -1))"
fi
```

TRIVY SCAN (only if installed):

```bash
if command -v trivy &> /dev/null; then
  R=reports/.artifacts/nextjs-security-audit/raw
  mkdir -p "$R"
  trivy fs . --scanners vuln,misconfig --skip-dirs node_modules --skip-dirs .next \
    --format json --output "$R/trivy.json" 2>/dev/null \
    || echo "Trivy fs scan failed (record the error)"
  # Vulnerabilities
  jq -r '.Results[]? | .Target as $t | .Vulnerabilities[]?
    | "\(.Severity)\t\(.PkgName)@\(.InstalledVersion)\t\(.VulnerabilityID)\tfixed=\(.FixedVersion // "none")\t\($t)"' \
    "$R/trivy.json" 2>/dev/null | sort -u | head -80
  # Misconfigurations (Dockerfile etc.)
  jq -r '.Results[]? | .Target as $t | .Misconfigurations[]?
    | "\(.Severity)\t\(.ID)\t\(.Title)\t\($t)"' "$R/trivy.json" 2>/dev/null | sort -u | head -40
fi
```

DE-DUPLICATION:
- Compare each vulnerability ID (and its CVE/GHSA alias) with
  `ADVISORY_IDS` in step 3 and the advisory list in step 4. Already
  reported: mark "seen in step 3/4". Only **new** IDs are
  `TRIVY_NEW_ADVISORIES`; before counting a new one, confirm with the
  lockfile that the package version is really installed.

OUTPUT FORMAT (mandatory):

Include in artifact:
1. TRIVY STATUS: INSTALLED (version) or NOT_INSTALLED
2. If INSTALLED: vulnerability count by severity, `TRIVY_NEW_ADVISORIES`
   (list with severity and fixed version as Trivy reports it), and
   misconfiguration findings by severity with target file
3. If NOT_INSTALLED: installation instruction (brew install trivy
   for macOS)

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/nextjs-security-audit/step_10_trivy.md
