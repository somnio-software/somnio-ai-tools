# Next.js Dependency & Security Analysis

> Resolve the installed `next`, `react` and `react-dom` versions from the lockfile, check them and the whole dependency tree against live advisory sources (OSV, GitHub Advisory Database), check the support status of the installed Next.js major (endoflife.date), and record package-manager hygiene. Feeds the existing **Tech Stack** section.

---

Goal: Give the Tech Stack score a dependency-risk input that reflects
the advisories published up to the moment the audit runs.

**Report integration**: This step's findings feed into the existing
**Tech Stack** section of the final report (alongside the Node.js and
configuration findings from `version-alignment.md`, `version-validator.md`
and `config-analysis.md`) — it is NOT a new standalone report section.
The report structure remains the 9 scored sections / 15 numbered
sections defined in `references/report-generator.md`. For a deeper
security review (Server Action authorization, Proxy bypass patterns,
secrets, headers, image optimizer configuration, cache poisoning),
recommend the standalone Next.js Security Audit
(`/somnio:nextjs-security-audit`) — this step is a first-pass
dependency summary, not exhaustive security coverage.

THE LIVE-SOURCES RULE (NON-NEGOTIABLE):
Follow `references/live-vulnerability-sources.md` for every
vulnerability and support-status claim. That file is the single source
of truth for which sources to query, in which order, and how to record
evidence. In short:
- The installed version comes from the lockfile / package manager,
  never from the `package.json` range and never from memory.
- The affected range and the patched version come from the advisory
  returned by a live query, never from memory or from this skill's text.
  This file deliberately contains no vulnerable or patched version.
- Query at least OSV and the GitHub Advisory Database; merge by
  GHSA / CVE ID.
- If every source is unreachable, write `Unknown — could not verify
  against live sources` and list what failed. Never write "no known
  vulnerabilities" for a version that was not checked.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire analysis
- Do NOT reinstall dependencies — reuse the install from
  `version-alignment.md`
- Batch the OSV lookups with `querybatch` (one call for all key packages)
- Reuse the installed versions recorded by `version-validator.md` when
  present

1. INSTALLED VERSIONS (from the lockfile):
   - Per Next.js app (monorepo: each workspace package that depends on
     `next`), resolve the installed versions of `next`, `react`,
     `react-dom` and, when present in the lockfile, the other packages
     listed under "PACKAGES TO CHECK" in
     `references/live-vulnerability-sources.md`:
     ```bash
     pnpm list next react react-dom --depth 0 --json   # pnpm
     npm ls next react react-dom --json                # npm
     yarn why next                                     # yarn
     ```
   - Record the declared range next to the installed version so the
     report can say when the range allows a patched version the lockfile
     has not picked up yet
   - Flag `react` / `react-dom` installed version mismatch
   - Flag a canary / rc / beta `next` version in production apps

2. LIVE ADVISORY LOOKUP (key packages):
   - Execute sources 1-3 of `references/live-vulnerability-sources.md`
     (OSV `querybatch` + per-ID details, GitHub Advisory Database,
     Next.js repository advisories) for the installed versions
   - For each matching advisory record: GHSA / CVE, severity, summary,
     whether it affects the installed version, the patched version AS
     STATED BY THE ADVISORY for the installed release line, the source
     URL, and the UTC time of the query

3. SUPPORT STATUS (endoflife.date):
   - Execute source 4: `curl -s https://endoflife.date/api/nextjs.json`
   - For the installed `next` major: `eol` (date or `false`), whether
     it is still `lts`, and the `latest` patch of that line
   - An end-of-life major receives no security fixes: that is a Tech
     Stack finding on its own, whatever the advisory lookup returned
   - Optionally do the same for React
     (`https://endoflife.date/api/react.json`) and Node.js
     (`https://endoflife.date/api/nodejs.json`) against the active
     Node.js version from `version-validator.md`
   - Use source 5 (npm registry) to name the latest patch of the
     installed major and to detect a deprecated installed version

4. WHOLE-TREE AUDIT (transitives included):
   - Run the project's own package manager audit (source 6):
     ```bash
     pnpm audit --json        # pnpm-lock.yaml
     npm audit --json         # package-lock.json
     yarn npm audit --json    # Yarn Berry (yarn audit --json on Yarn 1)
     ```
   - If `osv-scanner` is installed, also run it against the lockfile
   - Summarize counts by severity (critical / high / moderate / low),
     direct vs transitive, and list every critical/high advisory with
     package, installed version, advisory ID and the fix path the tool
     reports (direct upgrade, parent upgrade, or an `overrides` /
     `pnpm.overrides` / `resolutions` pin)
   - Existing overrides/resolutions in `package.json`: list them; each
     one is either a deliberate security pin (good, if documented) or a
     stale pin blocking upgrades

5. PACKAGE-MANAGER HYGIENE (from `tool-installer.md`,
   `version-alignment.md` and the CI step):
   - `PACKAGE MANAGER FINDING: not using pnpm (uses <pm>)` — recommend
     pnpm (strict, content-addressed store; `pnpm audit`; workspace
     support). Recommendation only — never migrate during the audit
   - `packageManager` pin present / missing
   - Multiple lockfiles, no lockfile, or lockfile out of sync with
     `package.json`
   - Frozen install in CI (from `cicd-analysis.md`)
   - Dependabot / Renovate configured for the npm ecosystem

6. RISK ASSESSMENT:
   - A matching critical/high advisory on `next`, `react`,
     `react-dom` or `react-server-dom-*` = the most urgent Tech Stack
     finding — name it first, with the advisory ID and the patched
     version from the advisory
   - An end-of-life `next` major = urgent even with no matching advisory
   - Critical/high in transitive dependencies = urgent, with the fix path
   - Moderate/low = list, do not let them dominate the narrative
   - Always add the recommendation to run `/somnio:nextjs-security-audit`
     for depth when any critical/high advisory or EOL major is found

OUTPUT FORMAT:

Provide structured analysis (feeds into the Tech Stack section):
- Installed versions (lockfile): per app — next [X.Y.Z] (range [R]), react [X.Y.Z], react-dom [X.Y.Z]
- Key-package advisory table (the OUTPUT table defined in `references/live-vulnerability-sources.md`)
- Release line support: next major [N] — eol [date/false], latest patch [X.Y.Z], source URL
- Sources reached / failed: one line each, with the error for failures
- Verdict per key package: `Vulnerable` / `No matching advisory in <sources> at <time>` / `Unknown — could not verify`
- Whole-tree audit: tool [pnpm audit/npm audit/yarn npm audit/osv-scanner], counts (Critical: N, High: N, Moderate: N, Low: N), direct vs transitive
- Critical/high list: [package@version — advisory ID — fix path]
- Overrides/resolutions in use: [list or none]
- Package-manager findings: [not using pnpm / no packageManager pin / multiple lockfiles / out of sync / none]
- Risks identified
- Recommendations (upgrade to the patched version named by the advisory on the same major first; plan a major upgrade when the major is EOL; run `/somnio:nextjs-security-audit` for depth)

SCORING GUIDANCE (one input into the Tech Stack section score, not a standalone score):

Strong (85-100):
- No matching critical/high advisory on any key package or in the tree
- Installed `next` major supported, close to the latest patch of its line
- pnpm (or a consistent, pinned package manager) with a frozen install in CI

Fair (70-84):
- No critical advisory on key packages; some high/moderate in the tree with a clear fix path
- Supported major but several patches behind
- Package-manager hygiene gaps (not using pnpm, no `packageManager` pin)

Weak (0-69):
- A matching critical/high advisory on `next` / `react` / `react-dom` / `react-server-dom-*`
- End-of-life `next` major
- No lockfile committed (the installed tree cannot be reproduced or audited)

If every live source was unreachable, do not score this input from
memory: mark it `Unknown — could not verify against live sources` and
let the report-generator score Tech Stack on the remaining evidence,
stating the gap.
