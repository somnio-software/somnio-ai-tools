# Next.js Security Report Generator

> Synthesize all Next.js security findings into a comprehensive audit report with quantitative scoring, severity classifications, and actionable recommendations. MUST follow the exact 12-section structure from assets/report-template.md. Every section in the template is MANDATORY. Do not merge, skip, or rename sections. Scored detail sections (3-7) MUST be dynamically ordered by score ascending.

---

Goal: Generate the final Next.js Security Audit report by integrating all
analysis results using the standardized format structure from
assets/report-template.md.

IMPORTANT EXCLUSIONS (generator instructions only - do NOT include in output):
- NEVER recommend CODEOWNERS or SECURITY.md files (governance decisions,
  not technical requirements)
- NEVER recommend operational documentation (runbooks, deployment
  procedures, monitoring)
- NEVER write a vulnerable or patched version that does not appear in a
  step artifact (lockfile or live-source evidence). No versions from memory.

OUTPUT DIRECTIVE: Do NOT include the EXCLUSIONS block above in the
report output. These are instructions for the generator only.

MANDATORY REPORT STRUCTURE (12 sections):
1. Security Scoring Breakdown (`| Area | Score |` table: 5 area rows + the Overall Score row, then the Security Posture line)
2. Executive Summary (Overall Score + Trend + top findings + priority recommendations)
3-7. Scored Detail Sections (DYNAMIC ORDER — sorted by score ascending, lowest first):
   - Sensitive File & Env Protection (scored)
   - Secret Detection (scored)
   - Framework & Dependency Security (scored)
   - Supply Chain Integrity (scored)
   - Next.js App Security (scored)
8. Consolidated Findings by Severity
9. Remediation Priority Matrix
10. Project Detection Results
11. Appendix: Evidence Index
Appendix: Scoring Methodology (unnumbered `## Appendix: Scoring Methodology`,
   placed between 11. Appendix: Evidence Index and 12. Report Metadata,
   so Report Metadata stays the last block; carries the area weights and
   the Overall Score formula)
12. Report Metadata

DYNAMIC ORDERING INSTRUCTION:
After computing all 5 section scores in Step B, sort the scored detail
sections (3-7) by score ascending. The section with the LOWEST score
gets number 3, the next lowest gets 4, and so on up to 7. In case of tied
scores, use this tiebreaker order: Framework & Dependency Security,
Secret Detection, Sensitive File & Env Protection, Next.js App Security,
Supply Chain Integrity.

FRAMEWORK FINDINGS FIRST (MANDATORY):
- Every HIGH framework finding from step_03 `TOP_FINDINGS` (an installed
  `next` / `react` / `react-dom` / `react-server-dom-*` version matched by
  a HIGH or CRITICAL advisory, then an end-of-life `next` major) is listed
  FIRST in the Executive Summary "Top Findings", FIRST under
  "🔴 [HIGH]" in Section 8, and as priority 1 in Section 9.
- Each such finding states: the app path, the installed version, every
  advisory ID (GHSA and CVE), the advisory title, the patched version for
  that release line **quoted from the advisory**, the latest patch of the
  same major (from the npm registry query), and the source URL. Copy these
  values from the artifact; never complete them from memory.
- If step_03 recorded `Unknown — could not verify` for `next` or `react`,
  the Executive Summary must say so in its Top Findings (as a MEDIUM
  "framework vulnerability status unverified" item). Never write that the
  framework has no known vulnerabilities when it was not verified.

STEP ARTIFACT INTEGRATION:
Read ALL step artifact files in this run's artifacts directory —
`reports/.artifacts/nextjs-security-audit/` (both the in-session subagent
path and `somnio run` write there, both as `step_NN_<rule>.md`). Match each
artifact by its step-number prefix; if two files share a prefix, they are
copies of one step — read one, never count its findings twice:
- step_01_* (Next.js detection, apps, router, package manager, tools,
  scope; Section 10)
- step_02_* (installed versions per app, Node.js runtime targets;
  Section 10 and Framework & Dependency Security)
- step_03_* (framework advisories, EOL status, deprecated installed
  version, unverified packages, TOP_FINDINGS; Framework & Dependency Security)
- step_04_* (dependency tree advisories after de-duplication, paths,
  overrides, deprecated and outdated; Framework & Dependency Security)
- step_05_* (package manager hardening; Supply Chain Integrity)
- step_06_* (Part A: Sensitive File & Env Protection; Part B: Secret Detection)
- step_07_* (Next.js SAST; Next.js App Security)
- step_08_* (header checklist and header/cache/rewrite findings;
  Next.js App Security)
- step_09_* (Gitleaks; GIT_HISTORY_FINDINGS for Secret Detection;
  NOT_INSTALLED adds an install recommendation)
- step_10_* (Trivy; new advisories for Framework & Dependency Security,
  misconfigurations to Section 8; Trivy used = Supply Chain bonus)

If an expected step_NN_* artifact is absent, note it as missing rather
than searching other directories.

For each scored section (3-7), extract the relevant findings from the
artifacts above, apply the scoring rubric, and show the computed score
with the deductions/additions that led to it. The score computation
must be traceable from evidence in the artifacts. A rubric item whose
input is `Unknown` gets no deduction unless the rubric says otherwise;
say "Unknown" in Key Findings.

SCORING SYSTEM:

5 Scored Sections, weights:
- Sensitive File & Env Protection (Weight: 0.15) - Source: step_06 Part A
- Secret Detection (Weight: 0.20) - Source: step_06 Part B + step_09
- Framework & Dependency Security (Weight: 0.30) - Source: steps 02, 03,
  04, 10
- Supply Chain Integrity (Weight: 0.15) - Source: step_05 (+ step_10
  Trivy used)
- Next.js App Security (Weight: 0.20) - Source: steps 07 + 08

Score Labels and Security Posture Mapping:
- 85-100 = Strong = "Secure"
- 70-84 = Fair = "Needs Attention"
- 50-69 = Weak = "At Risk"
- 0-49 = Critical = "Critical"

SCORING RUBRICS:

Sensitive File & Env Protection - Start at 100, deduct:
- `.env*.local` tracked, or `.env*` tracked with secret-looking values: -30 per file (max -60)
- Private key / credential / service-account file tracked: -25 per file (max -50)
- `NEXT_PUBLIC_` secret-like variable, HIGH: -20 per variable (max -40)
- `NEXT_PUBLIC_` secret-like variable, MEDIUM: -10 per variable (max -20)
- next.config `env` key exposing a secret: -15 per key (max -30)
- Secret passed to a Client Component or returned from a Server Action (HIGH): -20 per occurrence (max -40)
- Client file importing a secret-reading module (MEDIUM): -5 per file (max -15)
- `.env*.local` not covered by .gitignore: -15
- Production browser source maps public: -10
- `.vercel/` tracked: -5
- Bonus: `server-only` used in secret-reading modules: +5
- Bonus: `.env.example` with safe placeholders: +5

Secret Detection - Start at 100, deduct:
- HIGH finding (hardcoded secret/API key/private key): -20 per finding (max -60)
- MEDIUM finding: -10 per finding (max -40)
- LOW finding: -3 per finding (max -15)
- Secrets in git history (step_09 GIT_HISTORY_FINDINGS > 0): -15
- Bonus: Pre-commit secret hooks: +5
- Bonus: .gitleaks.toml present: +5

Framework & Dependency Security - Start at 100, deduct:
- Framework package (`next`, `react`, `react-dom`, `react-server-dom-*`)
  installed version affected by a CRITICAL advisory: -40 per advisory (max -80)
- Framework package affected by a HIGH advisory: -30 per advisory (max -60)
- Framework package affected by a MEDIUM advisory: -10 per advisory (max -30)
- Framework package affected by a LOW advisory: -3 per advisory (max -9)
- Installed `next` major end-of-life: -30 (once)
- Node.js production runtime end-of-life: -15 (local-only target: -5)
- Framework vulnerability status Unknown (live sources unreachable): -10 (once)
- Other packages (step_03 other listed packages + step_04 tree advisories +
  step_10 TRIVY_NEW_ADVISORIES, each advisory counted once):
  Critical -15 each (max -45), High -8 each (max -32), Medium -3 each
  (max -15), Low -1 each (max -5)
- Installed framework version deprecated on npm: -10
- Deprecated direct dependency: -5 per package (max -15)
- Dependency tree audit FAILED (every source failed): -10
- Bonus: `next` on the latest patch of a supported major (step_03): +5

Supply Chain Integrity - Start at 100, deduct:
- No committed lockfile: -30
- More than one lockfile type committed: -10
- Package manager is not pnpm (npm / yarn / bun): -15
- No `packageManager` field: -5
- CI installs not frozen (CI_FROZEN_INSTALL = NO): -10 (PARTIAL: -5; NO_CI: 0, note it)
- pnpm only (effective values; Unknown = 0):
  release-age gate off -5; all builds allowed (`dangerouslyAllowAllBuilds`) -10;
  strict build check off -5; exotic sub-dependencies allowed -5;
  trust policy off -3
- npm / yarn / bun: no lifecycle-script control configured: -5
- Registry auth token committed: -25 per file (max -50)
- git / tarball / URL direct dependency: -10 per dependency (max -30; pinned to a commit SHA: -3)
- External path dependency (outside the repository): -5 per dependency
- Dependency-confusion risk (unscoped non-default registry or unpinned scope): -10
- Ungated lifecycle scripts in direct dependencies: -2 per package (max -10)
- Bonus: Dependabot / Renovate configured: +5
- Bonus: CI dependency scanning (audit / osv-scanner / trivy / snyk): +5
- Bonus: Trivy used in this audit (step_10 INSTALLED): +5

Next.js App Security - Start at 100, deduct:
- SAST HIGH (step_07): -15 per finding (max -60)
- SAST MEDIUM: -6 per finding (max -30)
- SAST LOW: -1 per finding (max -5)
- Header/cache/rewrite finding HIGH (step_08): -15 per finding (max -30)
- Header/cache/rewrite finding MEDIUM: -5 per finding (max -15)
- Header/cache/rewrite finding LOW: -1 per finding (max -5)
- Header checklist (worst app; Unknown = 0):
  H1 CSP missing -10 (partial -5); H2 HSTS missing -5 (partial -2);
  H3 framing missing -5; H4 nosniff missing -3; H5 Referrer-Policy
  missing -2; H6 Permissions-Policy missing -2; H7 poweredByHeader not
  disabled -2
- Bonus: nonce- or hash-based CSP in production: +5
- Bonus: Data Access Layer with `server-only` and schema validation in
  every Server Action / Route Handler (step_07 positive controls): +5

All section scores must be clamped to 0-100 range.

OVERALL SCORE FORMULA:
overall = round(file_env * 0.15 + secret_detection * 0.20
          + framework_dependency * 0.30 + supply_chain * 0.15
          + nextjs_app * 0.20)

The Overall Score in the Security Scoring Breakdown (Section 1) and
Executive Summary (Section 2) must match. The weights and the formula are
reproduced, unchanged, in the unnumbered "## Appendix: Scoring
Methodology" block (never in Section 1).

MANDATORY SCORING COMPUTATION (execute before writing report):

You MUST compute all scores BEFORE generating any report content.
A report without scores is INVALID and must not be produced.

SCORE COMPARISON (before generating):
If reports/.history/last_nextjs_security_scores.json exists, read it and
extract the previous "overall" score and "timestamp". After computing the
new overall score in Step C, calculate the change (current - previous).
Always write the one defined Trend line in the Executive Summary
(Section 2), directly after the Overall Score line:
"**Trend:** Previous [N]/100, change [+/-M] ([improving|declining|unchanged])"
or, when no history exists, "**Trend:** first run". Trend data goes only
in that slot.

Step A - Extract scoring data from each artifact (the keys named in each
reference's ARTIFACT SAVE section):
  - step_06 Part A: ENV_FILES_TRACKED, MISSING_ENV_IGNORE, KEY_FILES_TRACKED,
    VERCEL_DIR_TRACKED, NEXT_PUBLIC_SECRET_HIGH/MEDIUM, CONFIG_ENV_SECRET,
    CLIENT_REACHABLE_SECRET_HIGH, CLIENT_IMPORTS_SECRET_MODULE,
    SERVER_ONLY_USED, PUBLIC_SOURCE_MAPS, ENV_EXAMPLE_SAFE
  - step_06 Part B: SECRET_HIGH/MEDIUM/LOW, PRECOMMIT_SECRET_HOOK,
    GITLEAKS_CONFIG
  - step_09: GIT_HISTORY_FINDINGS, GITLEAKS STATUS
  - step_02: installed versions per app, Node.js runtime targets
  - step_03: FRAMEWORK_ADVISORIES, OTHER_LISTED_ADVISORIES, NEXT_EOL,
    NODE_EOL, DEPRECATED_INSTALLED, LATEST_PATCH_SAME_MAJOR, UNVERIFIED,
    TOP_FINDINGS
  - step_04: TREE_ADVISORIES, DEPRECATED_COUNT/LIST, OUTDATED_MAJOR_COUNT,
    AUDIT_STATUS, OVERRIDES
  - step_10: TRIVY STATUS, TRIVY_NEW_ADVISORIES, misconfigurations
  - step_05: every KEY listed in its ARTIFACT SAVE section
  - step_07: SAST_HIGH/MEDIUM/LOW, AUTH_ONLY_IN_MIDDLEWARE, positive controls
  - step_08: checklist H1-H7 per app, CSP_MODE,
    HEADER_FINDINGS_HIGH/MEDIUM/LOW

Step B - Compute each section score using the rubrics above (base 100,
apply deductions/bonuses, clamp 0-100).

Step C - Compute Overall Score with the formula.

Step D - Determine labels for each score and Overall using the
mapping: 85-100 = Strong, 70-84 = Fair, 50-69 = Weak, 0-49 = Critical

Step E - Verify all 6 scores (5 sections + overall) are computed
before proceeding to write any report content.

REJECTION CRITERIA:
If you cannot compute a score for any section due to missing artifact
data, assign score 0 and note "Score: 0/100 (Critical) - Insufficient
data from [missing artifact]". Never omit a scored section.

SEVERITY CLASSIFICATION (use the severity each step assigned; when a step
gave none):
- HIGH: installed framework version with a HIGH/CRITICAL advisory, EOL
  `next` major, hardcoded or client-exposed secrets, missing authorization
  on Server Actions / Route Handlers, injection with user input, per-user
  data in shared caches
- MEDIUM: other known vulnerabilities, npm/yarn instead of pnpm,
  permissive next.config, missing validation, open redirect, CSRF exposure,
  insecure cookie flags
- LOW: hardening suggestions, missing optional headers, informational

SECURITY POSTURE LABELS (score-based):
- Secure: Overall Score 85-100
- Needs Attention: Overall Score 70-84
- At Risk: Overall Score 50-69
- Critical: Overall Score 0-49

SECTION FORMAT REQUIREMENTS:
Scored sections (3-7) MUST each follow this exact format:
- Description: Brief explanation of what this section evaluates
- Score: [Score]/100 ([Label])
- Score Breakdown: Show starting score, each deduction/bonus applied
  with its value, and the final clamped score. Example:
    Base: 100
    - Package manager is not pnpm: -15
    - CI installs not frozen: -10
    + Dependabot configured: +5
    Final: 80/100 (Fair)
- Key Findings: Bullet list of findings with severity tags
- Evidence: File paths, line numbers, advisory IDs and source URLs
  (sourced from step artifact .md files)
- Risks: What could go wrong if findings are not addressed
- Recommendations: Numbered, prioritized actions to improve

SPECIAL SECTION CONTENT:
- Framework & Dependency Security MUST include the "Framework Version
  Status" table from the template (one row per app and framework package:
  installed version, matching advisories, patched in per advisory, latest
  patch of the major, support status, verdict) before Key Findings, and
  the dependency tree counts (direct / transitive by severity).
- Supply Chain Integrity, when the package manager is not pnpm, MUST
  include the migration recipe from step_05 (condensed: commands,
  hardened `pnpm-workspace.yaml`, CI and Dockerfile changes) under
  Recommendations, with a pointer to https://pnpm.io/supply-chain-security.
- Next.js App Security MUST include the header checklist (H1-H7 status)
  and cite the official guides when recommending fixes:
  https://nextjs.org/docs/app/guides/data-security and
  https://nextjs.org/docs/app/guides/content-security-policy

Security Scoring Breakdown (Section 1):
- A `| Area | Score |` table with one row per scored section; each Score
  cell is "[Score]/100 ([Label])"
- The last row is "| **Overall Score** | **[Score]/100 ([Label])** |"
- Followed by "**Security Posture:** [Posture]"
- No table may have a column beyond the template's: never add Weight,
  Previous, Baseline, Change or Delta columns
- Weights and the formula do not appear here; they live in the
  "## Appendix: Scoring Methodology" block

Executive Summary (Section 2):
- Must include "Overall Score: [Score]/100 ([Label])" and the Trend line
- Must include Top Findings (framework findings first) and Priority
  Recommendations

FORMATTING RULES:
- USE MARKDOWN SYNTAX: Use ## headings, **bold**, `backtick` paths
- USE BOLD: Bold the field label only; never bold the numeric value after `**Score:**`.
- USE CODE BLOCKS: Backticks for file paths and inline code
- USE TABLES: Markdown pipe tables wherever the template renders one
- SECTION HEADERS: Use "## X. Section Name"; subsections use "### Name"
- BULLET POINTS: Use "- " for all lists
- NUMBERED LISTS: Use "1. ", "2. " format
- SEVERITY: Always format as "**[HIGH]** — [Finding]" (also MEDIUM, LOW), as the template does
- SCORES: Always format as "[Score]/100 ([Label])"
- SECRETS: Never print a secret value; use the redacted form from the artifact

VALIDATION CHECKLIST:
Before finalizing the report, verify:
- All 12 sections are present
- Section 1 is a `| Area | Score |` table with 5 area rows + the Overall Score row + the Security Posture line, and no extra columns
- All 5 scored sections (3-7) have Score line with [Score]/100 ([Label])
- All scored sections have Description/Score/Score Breakdown/Key Findings/Evidence/Risks/Recommendations
- Scored sections (3-7) are ordered by score ascending (lowest first)
- Framework HIGH findings (advisories, then EOL) appear first in Top Findings, Section 8 HIGH and Section 9
- Every version and advisory ID in the report appears in a step artifact
- Executive Summary includes Overall Score and the Trend line
- "## Appendix: Scoring Methodology" sits between 11 and 12, so Report Metadata is the last block
- Scores in Section 1 match scores in their respective detail sections (3-7)
- No EXCLUSIONS block appears in the output
- Security posture label matches the Overall Score range
- Report starts with "Next.js Security Audit Report" (no other text before it)

Format: Markdown-formatted report — ## headings, **bold** field
labels and pipe tables, exactly as assets/report-template.md renders
them. That template and references/report-format-enforcer.md are
authoritative on formatting; this file must not contradict them.

Run before saving: mkdir -p reports

SCORE HISTORY (mandatory after writing report):
After writing reports/<YYYY-MM-DD>-<project>-nextjs-security-audit.md,
write reports/.history/last_nextjs_security_scores.json with:
{ "overall": [current overall score], "timestamp": "[ISO8601]",
  "scores": { "sensitiveFileEnv": N, "secretDetection": N,
    "frameworkDependency": N, "supplyChain": N, "nextjsAppSecurity": N },
  "findings": { "high": N, "medium": N, "low": N },
  "nextVersions": { "[app path]": "[installed next version from step_02]" },
  "projectType": "nextjs" }
Run: mkdir -p reports/.history
