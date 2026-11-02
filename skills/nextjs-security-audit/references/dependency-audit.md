# Next.js Dependency Tree Audit

> Audit the whole dependency tree (direct and transitive) of every Next.js app with the package manager's audit and OSV-Scanner. Explain how each HIGH/CRITICAL package enters the tree and whether an override already pins it.

---

Goal: Count and list the advisories that affect any installed package,
separate direct from transitive, and give the dependency path for every
HIGH/CRITICAL one.

The sources and rules for live lookups are in
`references/live-vulnerability-sources.md` (source 6 covers the whole tree).
Follow its rules: installed versions only, advisory IDs and source for every
finding, `Unknown` when a source cannot be reached.

## INPUT

- `PACKAGE_MANAGER`, lockfiles and tools from
  `reports/.artifacts/nextjs-security-audit/step_01_tool-installer.md`
- `ADVISORY_IDS` from
  `reports/.artifacts/nextjs-security-audit/step_03_framework-vulnerabilities.md`
  (when present). An advisory already listed there is shown as
  "see framework section" and is **not counted again** in this step.

Run every command from the repository root (workspace roots audit all
workspaces). Never run `audit fix`, `install`, `update` or anything that
writes the lockfile.

## 1. PACKAGE MANAGER AUDIT

```bash
mkdir -p reports/.artifacts/nextjs-security-audit/raw
R=reports/.artifacts/nextjs-security-audit/raw
case "$PACKAGE_MANAGER" in
  pnpm) pnpm audit --json > "$R/pm_audit.json" 2> "$R/pm_audit.err"
        jq '.metadata.vulnerabilities' "$R/pm_audit.json" ;;
  npm)  npm audit --json > "$R/pm_audit.json" 2> "$R/pm_audit.err"
        jq '.metadata.vulnerabilities' "$R/pm_audit.json" ;;
  yarn) # berry: NDJSON per advisory; classic: NDJSON with auditAdvisory/auditSummary
        (yarn npm audit --all --recursive --json || yarn audit --json) > "$R/pm_audit.json" 2> "$R/pm_audit.err"
        head -c 3000 "$R/pm_audit.json" ;;
  bun)  bun audit --json > "$R/pm_audit.json" 2> "$R/pm_audit.err" || echo "bun audit unavailable" ;;
esac
echo "exit/err:"; head -5 "$R/pm_audit.err"
```

If the audit command fails (registry without an audit endpoint, network,
auth, a changed endpoint), record the error verbatim and continue with
OSV-Scanner. Do not report zero vulnerabilities for a failed audit.

Per-advisory listing (npm shown; pnpm's JSON has an `advisories` map with
`module_name`, `severity`, `github_advisory_id`, `cves`, `findings[].paths`,
`patched_versions`):

```bash
# npm: name, severity, direct?, advisory IDs/URLs, fix available
jq -r '.vulnerabilities | to_entries[] | .value
  | "\(.name)\t\(.severity)\tdirect=\(.isDirect)\t\([.via[] | objects | .url] | unique | join(","))\tfix=\(.fixAvailable | tostring)"' \
  "$R/pm_audit.json" | head -60
# pnpm
jq -r '.advisories // {} | to_entries[] | .value
  | "\(.module_name)\t\(.severity)\t\(.github_advisory_id // "")\t\((.cves // []) | join(","))\tpatched=\(.patched_versions)\tpaths=\([.findings[].paths[]] | .[0:3] | join(" | "))"' \
  "$R/pm_audit.json" | head -60
```

## 2. OSV-SCANNER (if installed)

```bash
if command -v osv-scanner >/dev/null 2>&1; then
  for lf in pnpm-lock.yaml package-lock.json yarn.lock bun.lock; do
    [ -f "$lf" ] || continue
    # v2 syntax first, v1 fallback
    osv-scanner scan source --lockfile="$lf" --format json > "$R/osv_$lf.json" 2>"$R/osv.err" \
      || osv-scanner --lockfile="$lf" --format json > "$R/osv_$lf.json" 2>>"$R/osv.err"
    jq -r '.results[]?.packages[]? | .package as $p | .vulnerabilities[]?
      | "\($p.name)@\($p.version)\t\(.id)\t\((.aliases // []) | join(","))\t\(.database_specific.severity // "n/a")"' \
      "$R/osv_$lf.json" | sort -u | head -80
  done
else
  echo "osv-scanner: NOT_INSTALLED (brew install osv-scanner)"
fi
```

Note: osv-scanner exits non-zero when it finds vulnerabilities; that is a
result, not a failure. Check whether the JSON has `results`.

## 3. MERGE AND DE-DUPLICATE

- Merge the package manager audit and OSV results by advisory ID (GHSA,
  CVE, or OSV ID with its aliases). One advisory affecting one package
  version counts once, even when several paths pull it in.
- Drop (and list as "see framework section") every ID already in step 3's
  `ADVISORY_IDS`.
- Severity: use the advisory's severity; if the sources disagree, take the
  higher and note it. Map `moderate` to MEDIUM.
- Mark each finding **direct** (declared in an app's or the root
  `package.json`) or **transitive**.

## 4. PATHS FOR HIGH / CRITICAL

For every HIGH or CRITICAL package, show how it enters the tree:

```bash
pnpm why "$PKG" --depth 10 2>/dev/null | head -30      # pnpm
npm explain "$PKG" 2>/dev/null | head -30              # npm
yarn why "$PKG" 2>/dev/null | head -30                 # yarn
bun pm why "$PKG" 2>/dev/null | head -30               # bun (if supported)
```

Record the top-level dependency that pulls it in, and whether upgrading that
top-level dependency is the fix (from the advisory's patched range and the
parent's published versions; never guess).

## 5. OVERRIDES

```bash
jq '{pnpm_overrides: .pnpm.overrides, overrides: .overrides, resolutions: .resolutions}' package.json
grep -A30 -E '^overrides:' pnpm-workspace.yaml 2>/dev/null | head -35
```

- An override that already forces a patched version of a flagged package:
  note it (the audit output should then be clean for it; if not, the
  override does not apply to that path).
- An override that pins a package to a version inside an advisory's
  affected range: MEDIUM finding.
- Overrides with no comment or ticket reference are informational only.

## 6. OUTDATED (informational)

```bash
case "$PACKAGE_MANAGER" in
  pnpm) pnpm outdated -r --format json 2>/dev/null | head -c 6000 ;;
  npm)  npm outdated --json 2>/dev/null | head -c 6000 ;;
  yarn) yarn outdated 2>/dev/null | head -60 || echo "yarn outdated unavailable (berry has no built-in outdated command)" ;;
  bun)  bun outdated 2>/dev/null | head -60 ;;
esac
```

Report the count of direct dependencies behind by a major version and list
up to 10. This does not affect the score on its own; deprecated packages do
(check `npm view <pkg> deprecated` for direct dependencies, up to 30).

## ARTIFACT SAVE (mandatory)

Save the full output to: reports/.artifacts/nextjs-security-audit/step_04_dependency-audit.md
Run before finishing: mkdir -p reports/.artifacts/nextjs-security-audit

Output format:
- Package manager, audit command used, exit status / error
- OSV-Scanner status and command
- `TREE_ADVISORIES` (after de-duplication): counts by severity —
  critical, high, medium, low — split `direct` / `transitive`
- Table: Package | Installed | Advisory ID(s) | Severity | Direct/Transitive | Patched in (per advisory) | Path (for HIGH/CRITICAL) | Source
- `ALREADY_IN_FRAMEWORK_SECTION`: IDs dropped as duplicates of step 3
- `OVERRIDES`: list and assessment
- `DEPRECATED_COUNT` / `DEPRECATED_LIST`
- `OUTDATED_MAJOR_COUNT` and top 10
- `AUDIT_STATUS`: OK / PARTIAL (one source failed) / FAILED (every source failed — counts are Unknown)
