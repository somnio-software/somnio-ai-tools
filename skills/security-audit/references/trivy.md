# Security Trivy Scan

> Run Trivy filesystem scan for vulnerabilities if Trivy is installed. Optional step; skips gracefully if Trivy is not installed. If not installed, adds installation recommendation to report.

---

Goal: Run Trivy filesystem scan if installed. If not installed,
output NOT_INSTALLED status and installation instruction for report
integration.

TRIVY DETECTION (execute first):

```bash
echo "=== Trivy Filesystem Scan ==="
mkdir -p reports/.artifacts

if ! command -v trivy &> /dev/null; then
  echo "Trivy: NOT_INSTALLED"
  echo "Recommendation: Install Trivy for comprehensive vulnerability scan"
  echo "  macOS: brew install trivy"
  echo "  Linux: see https://github.com/aquasecurity/trivy"
else
  echo "Trivy: INSTALLED"
fi
```

TRIVY SCAN (only if installed):

```bash
if command -v trivy &> /dev/null; then
  trivy fs . -f table 2>/dev/null | head -100 \
    || echo "Trivy fs scan complete"
fi
```

OUTPUT FORMAT (mandatory):

Include in artifact:
1. TRIVY STATUS: INSTALLED or NOT_INSTALLED
2. If INSTALLED: Vulnerability count by severity, critical findings
   summary, affected packages
3. If NOT_INSTALLED: Installation instruction (brew install trivy
   for macOS)

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/step_07_security_trivy.md
