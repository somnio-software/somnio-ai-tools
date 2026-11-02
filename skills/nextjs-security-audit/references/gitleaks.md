# Next.js Gitleaks Scan

> Scan the repository for secrets in the working directory and git history using Gitleaks. Optional step; skips gracefully if Gitleaks is not installed. If not installed, adds an installation recommendation to the report.

---

Goal: Run Gitleaks to scan for secrets. If Gitleaks is not installed,
output NOT_INSTALLED status and installation instruction for report
integration. Unlike step 6, Gitleaks also covers test files, build
scripts and every file type.

GITLEAKS DETECTION (execute first):

```bash
echo "=== Gitleaks Secret Scan ==="
mkdir -p reports/.artifacts/nextjs-security-audit

if ! command -v gitleaks &> /dev/null; then
  echo "Gitleaks: NOT_INSTALLED"
  echo "Recommendation: Install Gitleaks for git history secret scanning"
  echo "  macOS: brew install gitleaks"
  echo "  Linux: see https://github.com/gitleaks/gitleaks"
else
  echo "Gitleaks: INSTALLED ($(gitleaks version 2>/dev/null))"
fi
```

GITLEAKS SCAN (only if installed; skip if NOT_INSTALLED):

Use a JSON report so the secret values can be redacted before anything is
written to the artifact. Never copy a `Secret` or `Match` value into the
artifact.

```bash
if command -v gitleaks &> /dev/null; then
  R=reports/.artifacts/nextjs-security-audit/raw
  mkdir -p "$R"
  # Working directory (no git history). Dependencies and build output are
  # skipped through a path allowlist on top of the default rules: `.next/`
  # alone can hold hundreds of generated hits and turn a seconds-long scan
  # into many minutes. Untracked local files (.env.local, reports/) are still
  # scanned, since a secret there is a finding.
  CFG="$R/gitleaks-skip-build.toml"
  cat > "$CFG" <<'TOML'
[extend]
useDefault = true

[allowlist]
description = "dependencies and build output"
paths = ['(^|/)(node_modules|\.next|\.turbo|\.vercel|coverage|dist|build|out)/']
TOML
  gitleaks detect --source . --no-git --redact --config "$CFG" \
    --report-format json --report-path "$R/gitleaks_dir.json" 2>/dev/null
  # Full git history
  gitleaks detect --source . --redact --report-format json \
    --report-path "$R/gitleaks_git.json" 2>/dev/null

  for f in "$R/gitleaks_dir.json" "$R/gitleaks_git.json"; do
    echo "--- $f"
    jq -r '.[] | select(.File | test("(^|/)(node_modules|\\.next|\\.turbo|dist|build|out)/") | not)
      | "\(.RuleID)\t\(.File):\(.StartLine)\t\((.Commit // "working-dir")[0:12])"' "$f" 2>/dev/null | sort -u | head -60
    echo "count: $(jq '[.[] | select(.File | test("(^|/)(node_modules|\\.next|\\.turbo|dist|build|out)/") | not)] | length' "$f" 2>/dev/null)"
  done
fi
```

Gitleaks exits non-zero when it finds leaks; that is a result, not a
failure. If this Gitleaks version rejects the `[allowlist]` table (newer
releases use `[[allowlists]]`), use the form its documentation gives with
the same paths rather than dropping the exclusion. Newer Gitleaks releases also offer `gitleaks dir` and
`gitleaks git` subcommands; use them if `detect` is reported as
deprecated, with the same flags.

CLASSIFICATION:
- Findings only in history (not in the working directory): the secret was
  committed and later removed; it must be treated as exposed and rotated.
- Findings in `.env.example`, fixtures or docs with obvious placeholders:
  list as false positives with the reason.
- Do not double count: if step 6 already reported the same file:line, note
  "also found by step 6".

OUTPUT FORMAT (mandatory):

Include in artifact:
1. GITLEAKS STATUS: INSTALLED (version) or NOT_INSTALLED
2. If INSTALLED: findings count (working dir, git history), list of
   rule IDs with file:line and short commit SHA, false positives with reason
3. If NOT_INSTALLED: installation instruction (brew install gitleaks
   for macOS, etc.)
4. GIT_HISTORY_FINDINGS: count of real (non-false-positive) history
   findings (0 if none or not installed)

ARTIFACT SAVE (mandatory):
Save the full analysis output to: reports/.artifacts/nextjs-security-audit/step_09_gitleaks.md
