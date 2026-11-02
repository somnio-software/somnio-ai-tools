# Next.js Framework Vulnerabilities and Support Status

> Check the installed versions resolved in step 2 against live advisory sources, and the support (end-of-life) status of the installed Next.js and Node.js release lines. Every version and advisory in this step's output comes from the lockfile or a live query, never from memory.

---

Goal: Decide, per app, whether the installed `next`, `react`, `react-dom`,
`react-server-dom-*` and related packages are affected by a published
advisory, and whether their release line still receives security fixes.

## INPUT

Read `reports/.artifacts/nextjs-security-audit/step_02_version-resolution.md`.
Use only the **Installed version** column. A row marked `Unknown` is not
queried; it is carried to the output as `Unknown — installed version not
resolved`.

## PROCEDURE

Read `references/live-vulnerability-sources.md` and follow it exactly. It is
the single procedure for live lookups in this skill: the sources, their
order, the commands, the rules (installed version only, at least two
independent sources, merge by GHSA/CVE ID, record query time and URLs,
`Unknown` when unreachable) and the output table. Do not repeat or shorten
it here; run it for:

1. Every distinct (package, installed version) pair from step 2 in the
   "Always" and "When present" lists of that file. Query each pair once,
   then map the result back to every app that uses it.
2. Source 3 (Next.js repository advisories) for the installed `next`
   version(s): it carries the newest Next.js-only advisories.
3. Source 4 (support status) for the installed `next` major(s).
4. The same support check for each Node.js major recorded in step 2:

   ```bash
   curl -s https://endoflife.date/api/nodejs.json \
     | jq -r '.[] | select(.cycle == "'"$NODE_MAJOR"'") | {cycle, eol, lts, latest}'
   ```

5. Source 5 (npm registry) to name the latest patch of the installed major
   and to flag a deprecated installed version.

## CLASSIFICATION

For each advisory that affects an installed version:

| Advisory severity (as the source states it) | Package | Finding severity |
|---|---|---|
| CRITICAL or HIGH | `next`, `react`, `react-dom`, `react-server-dom-*` | **HIGH — report first** |
| CRITICAL or HIGH | other packages in the list (`@next/*`, `next-auth`, `@auth/*`, `sharp`, ...) | HIGH |
| MODERATE / MEDIUM | any | MEDIUM |
| LOW | any | LOW |

- **EOL `next` major** (`eol` is a date in the past, or the support policy
  says the line is unsupported): HIGH, whatever the advisory lookup
  returned. Quote the `eol` date and the source URL.
- **EOL Node.js major** in a declared runtime target: HIGH when it is the
  production runtime (Dockerfile, engines, CI deploy job), MEDIUM when the
  evidence is only `.nvmrc` / local tooling.
- **Deprecated installed version** (npm registry `deprecated` field):
  MEDIUM; quote the deprecation message.
- **Not verified** (every source failed for a package): no severity; carry
  `Unknown — could not verify against live sources` into the report. The
  report must not call that package "not vulnerable".

When two sources disagree on severity, use the higher one and say so.

For each HIGH framework finding write, ready for the report:
- the app path and the installed version (from step 2),
- every matching advisory ID (GHSA and CVE),
- the advisory title/summary,
- the patched version for the installed release line **quoted from the
  advisory** (`first_patched_version`, `patched_versions`, or the OSV
  `fixed` event), and the latest patch of the same major from source 5,
- the source URL(s) and the UTC query time.

## REMEDIATION WORDING

- Recommend upgrading to the newest patch of the installed major that the
  advisory data shows as fixed. Never recommend a version that no source
  returned.
- For an EOL major, recommend moving to a supported major listed by
  source 4 and point to the upgrade guides on https://nextjs.org/docs
  (do not invent codemod names or steps).
- Many React Server Components advisories are fixed only by upgrading the
  framework; a config change is not a mitigation unless the advisory says so.

## ARTIFACT SAVE (mandatory)

Save the full output to: reports/.artifacts/nextjs-security-audit/step_03_framework-vulnerabilities.md
Run before finishing: mkdir -p reports/.artifacts/nextjs-security-audit

Output format:
- The per-package table from `references/live-vulnerability-sources.md`
  (OUTPUT section), one row per matching advisory, plus one row per checked
  package with no matching advisory
- `FRAMEWORK_ADVISORIES`: counts by severity (critical, high, moderate, low)
  for `next` / `react` / `react-dom` / `react-server-dom-*`
- `OTHER_LISTED_ADVISORIES`: counts by severity for the other listed packages
- `ADVISORY_IDS`: every matching GHSA/CVE ID (step 4 uses it to avoid
  counting the same advisory twice)
- `NEXT_EOL`: per app, YES (date) / NO / Unknown, with source URL
- `NODE_EOL`: per runtime target, YES (date) / NO / Unknown, with source URL
- `DEPRECATED_INSTALLED`: list or none
- `LATEST_PATCH_SAME_MAJOR`: per package, from the npm registry
- `UNVERIFIED`: packages whose verdict is Unknown, with the failure reason
- Sources reached / failed, one line each, with the UTC query time
- `TOP_FINDINGS`: the HIGH framework findings, fully written as described
  above, in the order the report must show them
