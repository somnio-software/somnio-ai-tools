# Security Gitleaks Scan

> Scan repository for secrets in working directory and git history using Gitleaks. Optional step; skips gracefully if Gitleaks is not installed. If not installed, adds installation recommendation to report.

---

Goal: Run Gitleaks to scan for secrets. If Gitleaks is not installed,
output NOT_INSTALLED status and installation instruction for report
integration.

GITLEAKS DETECTION (execute first):

```bash
echo "=== Gitleaks Secret Scan ==="
mkdir -p reports/.artifacts

if ! command -v gitleaks &> /dev/null; then
  echo "Gitleaks: NOT_INSTALLED"
  echo "Recommendation: Install Gitleaks for git history secret scanning"
  echo "  macOS: brew install gitleaks"
  echo "  Linux: see https://github.com/gitleaks/gitleaks"
else
  echo "Gitleaks: INSTALLED"
fi
```

GITLEAKS SCAN (only if installed; skip if NOT_INSTALLED):

```bash
if command -v gitleaks &> /dev/null; then
  # Scan working directory only (no git history)
  echo ""
  echo "=== Working Directory Scan ==="
  gitleaks detect --source . --no-git 2>/dev/null | head -50 \
    || echo "Working dir scan complete (0 findings or error)"

  # Scan including git history (may take longer)
  echo ""
  echo "=== Git History Scan ==="
  gitleaks detect --source . 2>/dev/null | head -80 \
    || echo "Git history scan complete"
fi
```

OUTPUT FORMAT (mandatory):

Include in artifact:
1. GITLEAKS STATUS: INSTALLED or NOT_INSTALLED
2. If INSTALLED: Findings count (working dir, git history), list of
   affected files/commits if any, severity
3. If NOT_INSTALLED: Installation instruction (brew install gitleaks
   for macOS, etc.)
4. GIT_HISTORY_FINDINGS: count (0 if none or not installed)

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/step_04_security_gitleaks.md
