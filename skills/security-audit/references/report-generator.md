# Security Report Generator

> Synthesize all security findings into a comprehensive security audit report with quantitative scoring, severity classifications, and actionable recommendations. MUST follow the exact 13-section structure from assets/report-template.txt. Every section in the template is MANDATORY. Do not merge, skip, or rename sections. Scored detail sections (3-7) MUST be dynamically ordered by score ascending.

---

Goal: Generate the final Security Audit report by integrating all
analysis results using the standardized format structure from
assets/report-template.txt.

IMPORTANT EXCLUSIONS (generator instructions only - do NOT include in output):
- NEVER recommend CODEOWNERS or SECURITY.md files (governance decisions,
  not technical requirements)
- NEVER recommend operational documentation (runbooks, deployment
  procedures, monitoring)

OUTPUT DIRECTIVE: Do NOT include the EXCLUSIONS block above in the
report output. These are instructions for the generator only.

MANDATORY REPORT STRUCTURE (13 sections):
1. Security Scoring Breakdown (5 scored lines with weights + Overall + Formula + Posture)
2. Executive Summary (Overall Score + top findings + priority recommendations)
3-7. Scored Detail Sections (DYNAMIC ORDER — sorted by score ascending, lowest first):
   - Sensitive File Protection (scored)
   - Secret Detection (scored)
   - Dependency Security (scored)
   - Supply Chain Integrity (scored)
   - Security Automation & CI/CD (scored)
8. Consolidated Findings by Severity
9. Remediation Priority Matrix
10. Gemini AI Analysis (if available)
11. Project Detection Results
12. Appendix: Evidence Index
13. Scan Metadata

DYNAMIC ORDERING INSTRUCTION:
After computing all 5 section scores in Step B, sort the scored detail
sections (3-7) by score ascending. The section with the LOWEST score
gets number 3, the next lowest gets 4, and so on up to 7. This ensures
the CTO sees the weakest areas first. In case of tied scores, use this
tiebreaker order: Secret Detection, Sensitive File Protection,
Dependency Security, Supply Chain Integrity, Security Automation & CI/CD.

STEP ARTIFACT INTEGRATION:
Read and cross-reference the following step artifact files to extract
findings, evidence, and compute section scores:
- reports/.artifacts/step_01_security_tool_installer.md (tool detection,
  PROJECT_DETECTION_RESULTS for multi-tech; use for Section 11)
- reports/.artifacts/step_02_security_file_analysis.md (file protection
  findings, .gitignore coverage, environment file status)
- reports/.artifacts/step_03_security_secret_patterns.md (secret scan
  results, severity counts, pattern matches)
- reports/.artifacts/step_04_security_gitleaks.md (git history secrets;
  GIT_HISTORY_FINDINGS count; NOT_INSTALLED adds install recommendation)
- reports/.artifacts/step_05_security_dependency_audit.md (CVE counts,
  outdated deps, lock file status, automated tooling, CI/CD status)
- reports/.artifacts/step_06_security_dependency_age.md (outdated count,
  deprecated count and list, dependency age evidence)
- reports/.artifacts/step_07_security_trivy.md (Trivy scan; if
  INSTALLED and used, apply +15 Security Automation bonus)
- reports/.artifacts/step_08_security_sast.md (SAST OWASP findings;
  add to Consolidated Findings as LOW/MEDIUM; does not affect scoring)
- reports/.artifacts/step_09_security_gemini_analysis.md (AI findings,
  if available; otherwise note "Skipped")

For each scored section (3-7), extract the relevant findings from the
artifacts above, apply the scoring rubric, and show the computed score
with the deductions/additions that led to it. The score computation
must be traceable from evidence in the artifacts.

SCORING SYSTEM:

5 Scored Sections with Weights:
- Sensitive File Protection (Weight: 0.25) - Source: Step 2
- Secret Detection (Weight: 0.30) - Source: Step 3
- Dependency Security (Weight: 0.20) - Source: Steps 5+6 (step_06
  authoritative for age/deprecation)
- Supply Chain Integrity (Weight: 0.10) - Source: Step 5 subset
- Security Automation & CI/CD (Weight: 0.15) - Source: Steps 2+5+7
  (step_07 Trivy used = +15 if INSTALLED)

Score Labels and Security Posture Mapping:
- 85-100 = Strong = "Secure"
- 70-84 = Fair = "Needs Attention"
- 50-69 = Weak = "At Risk"
- 0-49 = Critical = "Critical"

SCORING RUBRICS:

Sensitive File Protection - Start at 100, deduct:
- .env tracked in git (verified via git ls-files in step_02): -30 per file
- Private key or cert tracked: -25 per file
- Missing .gitignore for env files (only if step_02 confirms no .env pattern): -15
- Missing platform patterns: -10 per category
- Cloud credential file tracked: -25 per file
- Bonus: .env.example with safe placeholders: +5
- Bonus: Multi-directory .gitignore: +5

Secret Detection - Start at 100, deduct:
- HIGH finding (hardcoded secret/API key): -20 per finding (max -60)
- MEDIUM finding (cloud/payment keys): -10 per finding (max -40)
- LOW finding: -3 per finding (max -15)
- Secrets in git history (from step_04 Gitleaks GIT_HISTORY_FINDINGS): -15
- Bonus: Pre-commit secret hooks: +5
- Bonus: .gitleaks.toml present: +5

Dependency Security - Start at 100, deduct:
- Critical CVE: -25
- High CVE: -15
- Medium CVE: -5
- Low CVE: -2
- More than 5 outdated deps: -10 (use step_06 count if available)
- More than 10 outdated deps: -20 (use step_06 count if available)
- Deprecated package: -10 per package (max -30)
- Missing lock file: -20
- Bonus: All deps at latest: +5
- Bonus: Lock file with SHA256: +5

Supply Chain Integrity - Start at 100, deduct:
- Git-sourced dependency: -10 per dep
- Path-based dependency: -5 per dep
- No lock file: -25
- Missing integrity hashes: -15
- Unknown registry dependency: -20 per dep
- Tree depth greater than 6: -5
- Circular dependencies: -10
- Bonus: 100% official registry: +10
- Bonus: Verified checksums: +5

Security Automation & CI/CD - Start at 0, add:
- Dependabot configured: +20 (or Renovate: +15, take max)
- Snyk configured: +15
- CI/CD vulnerability scanning: +20
- CI runs on PRs: +10
- Pre-commit security hooks: +10
- Lock file validation in CI: +10
- Additional scanner (trivy/grype): +15
- Cap at 100

OVERALL SCORE FORMULA:
overall = round(file_protection * 0.25 + secret_detection * 0.30
          + dependency * 0.20 + supply_chain * 0.10
          + automation * 0.15)

All section scores must be clamped to 0-100 range before applying
the formula. The Overall Score in the Security Scoring Breakdown
(Section 1) and Executive Summary (Section 2) must match.

MANDATORY SCORING COMPUTATION (execute before writing report):

You MUST compute all scores BEFORE generating any report content.
A report without scores is INVALID and must not be produced.

SCORE COMPARISON (before generating):
If reports/.history/last_scores.json exists, read it and extract:
- previous "overall" score
- previous "timestamp"
After computing the new overall score in Step C, calculate the change
(current - previous). If history exists, add to Executive Summary
(Section 2): "Previous: [N]/100, Change: [+/-M] ([improving|declining|unchanged])"

Step A - Extract scoring data from each artifact:
  - From step_02: .env tracked count (only count if step_02 verified via
    git ls-files and reported as tracked; .env in .gitignore = 0 count),
    key/cert count, .gitignore coverage, platform patterns, .env.example
    status, multi-dir .gitignore count
  - From step_03: HIGH/MEDIUM/LOW finding counts, pre-commit hooks,
    .gitleaks.toml presence
  - From step_04: GIT_HISTORY_FINDINGS count (if >0 apply -15); if
    Gitleaks NOT_INSTALLED add recommendation to install Gitleaks
  - From step_05: Critical/High/Medium/Low CVE counts, outdated dep
    count, lock file status, SHA256 hashes, automated tooling
    (Dependabot/Snyk/Renovate), CI/CD scanning, pre-commit security
    hooks, git-sourced deps, path-based deps, registry sources
  - From step_06: outdated dep count (authoritative if more detailed
    than step_05), deprecated dep count, deprecated package list
  - From step_07: Trivy INSTALLED and used (apply +15 Security
    Automation bonus); Trivy findings if any
  - From step_08: SAST OWASP findings (SQL injection, XSS, path
    traversal) - add to Consolidated Findings (Section 8) as LOW/MEDIUM;
    include in Remediation Priority Matrix if applicable

Step B - Compute each section score using the rubrics above:
  1. Sensitive File Protection: Base 100, apply deductions/bonuses,
     clamp 0-100
  2. Secret Detection: Base 100, apply deductions/bonuses, clamp 0-100
  3. Dependency Security: Base 100, apply deductions/bonuses,
     clamp 0-100
  4. Supply Chain Integrity: Base 100, apply deductions/bonuses,
     clamp 0-100
  5. Security Automation & CI/CD: Base 0, apply additions,
     clamp 0-100

Step C - Compute Overall Score:
  overall = round(file_protection*0.25 + secret_detection*0.30
            + dependency*0.20 + supply_chain*0.10 + automation*0.15)

Step D - Determine labels for each score and Overall using the
mapping: 85-100 = Strong, 70-84 = Fair, 50-69 = Weak, 0-49 = Critical

Step E - Verify all 6 scores (5 sections + overall) are computed
before proceeding to write any report content.

REJECTION CRITERIA:
If you cannot compute a score for any section due to missing artifact
data, assign score 0 and note "Score: 0/100 (Critical) - Insufficient
data from [missing artifact]". Never omit a scored section.

SEVERITY CLASSIFICATION:
- HIGH: Hardcoded secrets, exposed credentials, critical vulnerabilities
- MEDIUM: Missing .gitignore patterns, outdated dependencies with
  known CVEs, insecure configurations
- LOW: Informational findings, missing automated tooling, best
  practice suggestions

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
    - Missing .gitignore for env files: -15
    - Missing platform patterns (Flutter): -10
    + Multi-directory .gitignore: +5
    Final: 80/100 (Fair)
- Key Findings: Bullet list of findings with severity tags
- Dependency Age Analysis (Dependency Security section only):
  Outdated count, Deprecated count, Top outdated/deprecated packages
- Evidence: File paths, line numbers, and concrete references
  (sourced from step artifact .md files)
- Risks: What could go wrong if findings are not addressed
- Recommendations: Numbered, prioritized actions to improve

SPECIAL SECTION FORMATS:

Security Scoring Breakdown (Section 1):
- 5 scored lines, one per scored section, each with weight
- Each line: "[Section Name]: [Score]/100 ([Label]) - Weight: [X]%"
- Followed by "Overall Score: [Score]/100 ([Label])"
- Followed by "Formula: Overall = round(File Protection * 0.25 + Secret Detection * 0.30 + Dependency Security * 0.20 + Supply Chain * 0.10 + Automation * 0.15)"
- Followed by "Security Posture: [Posture]"
- This is THE FIRST THING a CTO sees when opening the report

Executive Summary (Section 2):
- Must include "Overall Score: [Score]/100 ([Label])"
- Must include Top Findings and Priority Recommendations

FORMATTING RULES:
- NO MARKDOWN SYNTAX: Use plain text only
- NO BOLD MARKERS: No **text** or __text__
- NO CODE FENCES: No ```code``` blocks
- NO TABLES: Use bullet points instead
- SECTION HEADERS: Use "X. Section Name" format
- BULLET POINTS: Use "- " for all lists
- NUMBERED LISTS: Use "1. ", "2. " format
- SEVERITY: Always format as "[SEVERITY]: [Finding]"
- SCORES: Always format as "[Score]/100 ([Label])"

VALIDATION CHECKLIST:
Before finalizing the report, verify:
- All 13 sections are present
- Section 1 (Security Scoring Breakdown) has 5 scored lines with weights + Overall + Formula + Posture
- All 5 scored sections (3-7) have Score line with [Score]/100 ([Label])
- All scored sections have Description/Score/Score Breakdown/Key Findings/Evidence/Risks/Recommendations
- Scored sections (3-7) are ordered by score ascending (lowest first)
- Executive Summary (Section 2) includes Overall Score
- Scores in Section 1 match scores in their respective detail sections (3-7)
- All findings have severity classifications
- All evidence references actual files and line numbers
- All recommendations are actionable and prioritized
- No markdown syntax is used
- No EXCLUSIONS block appears in the output
- Security posture label matches the Overall Score range
- Report starts with "Security Audit Report" (no other text before it)
- Report is ready for Google Docs copy-paste
- No duplicate score displays (old At-a-Glance Scorecard and Score Index are gone)

Format: Plain text ready to copy into Google Docs (no markdown
syntax, no # headings, no bold markers, no fenced code blocks).

JSON EXPORT (mandatory):
In addition to the text report, produce a machine-readable JSON file.
After writing the report, write a second file to reports/security_audit.json
with the following schema (extract values from the generated report):

{
  "overallScore": [integer 0-100],
  "posture": "[Secure|Needs Attention|At Risk|Critical]",
  "scores": {
    "sensitiveFile": [0-100],
    "secretDetection": [0-100],
    "dependencySecurity": [0-100],
    "supplyChainIntegrity": [0-100],
    "securityAutomation": [0-100]
  },
  "findings": {
    "high": [integer],
    "medium": [integer],
    "low": [integer]
  },
  "timestamp": "[ISO8601 datetime]",
  "projectType": "[detected type string]"
}

Run before saving: mkdir -p reports

SCORE HISTORY (mandatory after writing report and JSON):
After writing reports/security_audit.txt and reports/security_audit.json,
write reports/.history/last_scores.json with:
{ "overall": [current overall score], "timestamp": "[ISO8601]",
  "scores": { "sensitiveFile": N, "secretDetection": N, "dependencySecurity": N,
    "supplyChainIntegrity": N, "securityAutomation": N },
  "findings": { "high": N, "medium": N, "low": N },
  "projectType": "[string]" }
Run: mkdir -p reports/.history
