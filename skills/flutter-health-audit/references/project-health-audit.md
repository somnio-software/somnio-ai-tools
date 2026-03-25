# Flutter Project Health Audit

> Analyze a Flutter repository (Flutter + Android/iOS + Web + Desktop) and produce a highly scannable, Google-Docs-ready report. Analysis-only. Per-section integer scores and weighted overall score. Neutral rules as specified. No code changes, no fixes, no CI proposals.

---

Analyze ONLY repository evidence (files and tracked configs). Do NOT
invent data. Do NOT propose or create CI jobs. If something cannot be
proven by repository evidence, write "Unknown" and name the exact missing
artifact/file that would prove it.

STEP 0 - MANDATORY FLUTTER ENVIRONMENT SETUP:
Before executing ANY analysis, you MUST perform the following steps
in order:

1. Execute Flutter Version Alignment
  (@flutter_version_alignment) - MANDATORY
   - This rule will automatically configure FVM global version to
     match project requirements
   - Extract Flutter version from pubspec.yaml
   - Install FVM if not present
   - Set project Flutter version as global using FVM
   - Clean and prepare project environment

2. Execute Flutter Version Validator
  (@flutter_version_validator) - VERIFICATION
   - Verify FVM global configuration is correct
   - Confirm Flutter version alignment
   - Validate project environment setup

3. Execute Flutter Test Coverage (@flutter_test_coverage) -
  COVERAGE GENERATION
   - Generate test coverage data
   - Create coverage reports
   - Verify test execution

ENVIRONMENT SETUP FAILURE HANDLING:
- If Flutter environment setup failed in Step 0, note this in the
  Executive Summary and include as a top risk
- If FVM files/folders are missing (.fvm/, .fvm/fvm_config.json,
  .fvmrc), include this in the Tech Stack section findings
- If test coverage could not be generated, include the failure
  reason in the Testing section and add as a recommendation
- Continue analysis with available evidence, marking affected
  sections as "Unknown" where necessary
- CRITICAL: FVM global configuration is MANDATORY - if it fails,
  document as critical risk

OUTPUT PRINCIPLES (PLAIN TEXT, GOOGLE DOCS–READY, NO MARKDOWN)
• Produce a plain text document. No Markdown, no bold markers, no
  code fences, no tables.
• Use simple numbered headings and bullet lists. Each section MUST
  include, in this order:
  1) Description (one-sentence takeaway)
  2) Score (0–100, integer)
  3) Key Findings (3–7 items, evidence-first)
  4) Evidence (file paths / workflow filenames)
  5) Risks
  6) Recommendations (prioritized, actionable, concise)
  7) Counts & Metrics (only if applicable)
• At-a-Glance labels: 85–100 = Strong; 70–84 = Fair; 0–69 = Weak.

SCORING MODEL (INTEGER SCORES)
• Sections to score (0–100):
  - Tech Stack
  - Architecture
  - State Management
  - Repositories & Data Layer
  - Testing
  - Code Quality (Linter & Warnings)
  - Security
  - Documentation & Operations
  - CI/CD (Configs Found in Repo)
• For each section:
  - Define expected checks (below).
  - Mark each check PASS / FAIL / UNKNOWN.
  - section_failed_ratio = failed_checks / expected_checks
  - section_score = 100 − round(section_failed_ratio × 100)
  - Neutral (do NOT count as failed or expected):
       ▸ Absence of platform folders (ios/android/web/desktop) →
         neutral
      ▸ Using BLoC without a written guide → neutral
      ▸ Absence of lcov.info → neutral
      ▸ No stored analyzer outputs → neutral
• Overall Score (integer):
  - Weighted average: Tech Stack 0.18, Architecture 0.18, State
    Management 0.18, Repositories & Data Layer 0.10, Testing 0.10,
    Code Quality 0.10, Security 0.10, Documentation & Operations
    0.03, CI/CD 0.03
  - overall_score = round( Σ(section_score × weight) )
  - Provide one-sentence interpretation.

EVIDENCE GATHERING ORDER (READ-ONLY)
1) Repository layout (top 2–3 levels), presence of: android/, ios/,
   web/, macos/, windows/, linux/, packages/, apps/.
2) Monorepo detection: Check for apps/ directory structure
   (apps/app1/, apps/app2/, etc.) or packages/ structure. Also check
   for nested packages (apps/<app>/packages/) and shared packages
   (apps/packages/).
3) pubspec.yaml (Flutter/Dart versions, dev_dependencies like
   very_good_analysis; test deps like bloc_test).
4) analysis_options.yaml (or inclusion of package:very_good_analysis).
5) .fvm/fvm_config.json or FVM files (Flutter channel/SDK).
6) i18n configuration: l10n.yaml, lib/l10n/*.arb files,
   flutter_localizations dependency.
7) Tests: test/** (count, presence of bloc_test, testWidgets).
8) Coverage: coverage/lcov.info, coverage analysis results from
   Flutter Test Coverage Runner.
9) Per-app coverage: For monorepos with apps/ structure, check
   coverage/app1/, coverage/app2/, etc. for individual app
   coverage.
10) Workflows: .github/workflows/*.yml|yaml content; other
  .github configs (dependabot.yaml, PULL_REQUEST_TEMPLATE.md,
  cspell.json).
11) Docs/Ops: README*, CHANGELOG*, .env.example.

CHECKS & HEURISTICS
A) Tech Stack — expected checks:
   - pubspec.yaml exists with sdk constraints → PASS/FAIL
   - very_good_analysis present either in dev_dependencies OR
     included via analysis_options.yaml → PASS/FAIL/UNKNOWN
   - FVM config present (.fvm/fvm_config.json) OR Flutter version
     pinned in README/docs → PASS/FAIL/UNKNOWN
   - Supported platforms detected by presence of ios/, android/,
     web/, desktop folders (absence is NEUTRAL; do not count)
   - i18n configuration: l10n.yaml or lib/l10n/*.arb present →
     PASS/FAIL/UNKNOWN
   - FVM missing files/folders: If .fvm/, .fvm/fvm_config.json, or
     .fvmrc are missing, include in findings as "FVM configuration
     missing"

B) Architecture — expected checks:
   - Clear separation (e.g., lib/src/**, domain/data/presentation
     or similar) evidenced by folder structure → PASS/FAIL/UNKNOWN
   - Monorepo structure detected: apps/ directory with multiple
     apps OR packages/ directory → PASS/FAIL/UNKNOWN
   - Per-app structure: Each app in apps/ has its own pubspec.yaml
     and proper structure → PASS/FAIL/UNKNOWN
   - Nested packages structure: apps/<app>/packages/ with proper
     package structure → PASS/FAIL/UNKNOWN
   - Shared packages structure: apps/packages/ with proper package
     structure → PASS/FAIL/UNKNOWN
   - Native configs align (android/app/build.gradle,
     ios/Runner/*.plist present if platform exists) →
     PASS/FAIL/UNKNOWN

C) State Management — expected checks:
   - Detect BLoC / Riverpod / Provider via imports; at least one
     consistent pattern across features → PASS/FAIL/UNKNOWN
   - Basic guidance found (README/CONTRIBUTING) → NEUTRAL if absent;
     PASS if present; UNKNOWN if unclear

D) Repositories & Data Layer — expected checks:
   - Presence of data/repository abstractions or equivalent →
     PASS/FAIL/UNKNOWN
   - Error handling strategy (exceptions/result types) evident in
     code → PASS/FAIL/UNKNOWN
   - Decoupling from UI (no heavy I/O inside widgets) detectable
     by file organization → PASS/FAIL/UNKNOWN

E) Testing — expected checks:
   - Unit tests exist (any *_test.dart not using flutter_test) →
     PASS/FAIL/UNKNOWN
   - bloc_test present for business logic (if BLoC used) →
     PASS/FAIL/NEUTRAL (neutral if BLoC not detected)
   - Widget tests present (import flutter_test/testWidgets) →
     PASS/FAIL/UNKNOWN
   - Coverage script/mention (e.g., --coverage in workflows or
     scripts) → PASS/FAIL/UNKNOWN
   - Test counts > 0 and distributed (unit/bloc/widget) as
     applicable → PASS/FAIL/UNKNOWN
   - Coverage data available (coverage/lcov.info, coverage
     analysis results) → PASS/FAIL/UNKNOWN
   - Per-app coverage data: For monorepos with apps/, individual
     coverage files (coverage/app1/lcov.info,
     coverage/app2/lcov.info) → PASS/FAIL/UNKNOWN
   - Coverage percentage meets thresholds (70%+ overall, 80%+
     business logic) → PASS/FAIL/UNKNOWN
   - Per-app coverage thresholds: Each app meets individual
     coverage thresholds → PASS/FAIL/UNKNOWN
   - Coverage execution failure: If coverage could not be
     generated, include failure reason in findings and add as
     recommendation

F) Code Quality (Linter & Warnings) — expected checks:
   - analysis_options.yaml present or extends
     package:very_good_analysis → PASS/FAIL/UNKNOWN
   - Minimal justified excludes in analysis_options.yaml →
     PASS/FAIL/UNKNOWN
   - Format policy visible (script, README, or workflow step with
     dart format) → PASS/FAIL/UNKNOWN

G) Security — expected checks:
   - Sensitive files pattern checked vs .gitignore (keys in repo
     not ignored → FAIL; keys present and ignored → PASS)
   - dependabot config present (.github/dependabot.yaml) →
     PASS/FAIL/UNKNOWN
   - Secret scanning patterns / deny-lists found (if any) →
     PASS/FAIL/UNKNOWN
   - "copy" files containing keys → WARNING only (do not count as
     FAIL); "copy" without keys → ignore
   - CODEOWNERS / SECURITY.md → NEUTRAL / IGNORED (do not report
     as missing)

H) Documentation & Technical Setup — expected checks:
   - README con instrucciones de build, incl. --dart-define si
     aplica → PASS/FAIL/UNKNOWN
   - Technical onboarding docs (env samples: .env.example) →
     PASS/FAIL/UNKNOWN
   - CHANGELOG present → PASS / NEUTRAL (missing is neutral)
   - CONTRIBUTING present → PASS / NEUTRAL (missing is neutral)
   - PR template .github/PULL_REQUEST_TEMPLATE.md → PASS/FAIL/UNKNOWN
   - Do NOT check for operational documentation (runbooks,
     troubleshooting, deployment procedures)

I) CI/CD (Configs Found in Repo) — expected checks:
   - At least one workflow in .github/workflows → PASS/FAIL
   - For each workflow, detect presence (by string/step) of:
     analyze, format check, tests, coverage, spellcheck, release
     tagging → count matches
   - Monorepo rule: if packages/ exists, expect
     .github/workflows/<package>.yml|yaml for each package →
     missing counts as FAIL; if packages/ absent → NEUTRAL
   - Per-app workflow rule: if apps/ exists, expect
     .github/workflows/<app>.yml|yaml for each app → missing
     counts as FAIL; if apps/ absent → NEUTRAL
   - Nested packages rule: if apps/<app>/packages/ exists, expect
     .github/workflows/<app>_<package>.yml|yaml for each nested
     package → missing counts as FAIL; if absent → NEUTRAL
   - Shared packages rule: if apps/packages/ exists, expect
     .github/workflows/shared_<package>.yml|yaml for each shared
     package → missing counts as FAIL; if absent → NEUTRAL
   - Per-app coverage workflows: Each app workflow should include
     coverage collection → PASS/FAIL/UNKNOWN
   - Workflows enforce min_coverage >= 70 (check all coverage
     workflows) → PASS/FAIL (List failing files in Findings)
   - CRITICAL VERIFICATION: Check CI/CD files in CORRECT locations only:
     * Single app: .github/dependabot.yaml, .github/cspell.json,
       .github/PULL_REQUEST_TEMPLATE.md
     * Multi-app: .github/ (root) AND apps/<app>/.github/ (per app)
       for dependabot, cspell, PR template
     * Packages: NO dependabot/cspell/PR template expected
       (workflows only)
   - Branch protection: only score if evidence in repo; UI-only
     evidence → UNKNOWN (neutral)

EVIDENCE INTERPRETATION RULES
• Prefer exact file paths and quotes from files when asserting PASS.
• If a check relies on a file that does not exist or was not
  opened, mark UNKNOWN and name the exact file needed.
• Neutral cases explicitly listed above must not count as FAIL nor
  as expected.
 • Heuristics for workflows: search step names and run lines for
   keywords:
  "flutter analyze", "dart format", "flutter test", "coverage",
  "lcov", "cspell", "release", "tag".
• Heuristics for testing types:
  - bloc tests: import 'package:bloc_test/bloc_test.dart'
  - widget tests: testWidgets(…), import
    'package:flutter_test/flutter_test.dart'
• Important: Do NOT recommend adding new languages or translations
• Do NOT generate recommendations about "limited
  internationalization" or "English only" - these are not
  actionable improvements
• Do NOT recommend CODEOWNERS or SECURITY.md files - these are
  governance decisions, not technical requirements
• Do NOT recommend platform-specific workflows for Android/iOS
  builds - these are deployment decisions, not technical
  requirements
• Do NOT recommend operational documentation (runbooks,
  troubleshooting, deployment procedures, monitoring)
• Do NOT recommend release automation beyond basic tagging
• Do NOT recommend vulnerability scanning beyond dependabot

OUTPUT SECTIONS (IN THIS EXACT ORDER - 16 SECTIONS)
1. Executive Summary
   - Description: [One-sentence comprehensive analysis description]
   - Overall Score: [Score]/100 ([Label])
   - Top Strengths: [3-5 bullet points]
   - Top Risks: [3-5 bullet points]
   - Priority Recommendations: [5-7 numbered recommendations]
2. At-a-Glance Scorecard
   - Tech Stack: [Score]/100 ([Label])
   - Architecture: [Score]/100 ([Label])
   - State Management: [Score]/100 ([Label])
   - Repositories & Data Layer: [Score]/100 ([Label])
   - Testing: [Score]/100 ([Label])
   - Code Quality (Linter & Warnings): [Score]/100 ([Label])
   - Security: [Score]/100 ([Label])
   - Documentation & Operations: [Score]/100 ([Label])
   - CI/CD (Configs Found in Repo): [Score]/100 ([Label])
   - Overall: [Score]/100 ([Label])
3. Tech Stack
4. Architecture
5. State Management
6. Repositories & Data Layer
7. Testing
8. Code Quality (Linter & Warnings)
9. Security
10. Documentation & Operations
11. CI/CD (Configs Found in Repo)
12. Additional Metrics
13. Quality Index
14. Risks & Opportunities
15. Recommendations
16. Appendix: Evidence Index

SECTION FORMAT REQUIREMENTS:
Each section (3-11) MUST follow this exact format:

[Section Number]. [Section Name]

Description: [One-sentence description of the section's purpose]

Score: [Score]/100 ([Label])

Key Findings:
- [Bullet point 1]
- [Bullet point 2]
- [Continue as needed]

Evidence:
- [File path or configuration reference]
- [Specific evidence item]
- [Continue as needed]

Risks:
- [Risk item 1]
- [Risk item 2]
- [Continue as needed]

Recommendations:
- [Recommendation 1]
- [Recommendation 2]
- [Continue as needed]

Counts & Metrics:
- [Metric name]: [Value]
- [Metric name]: [Value]
- [Continue as needed]

SPECIAL SECTION FORMATS:

12. Additional Metrics:
- Supported platforms: [Platform list]
- Number of feature folders: [Count] ([App breakdown if multi-app])
- Root-level packages count: [Count]
- Nested packages count: [Count] (per app breakdown)
- Shared packages count: [Count]
- Total packages count: [Count] (root + nested + shared)
- Coverage %: [Percentage or status] (per app if multi-app)
- Overall aggregated coverage %: [Total percentage combining
  all apps and packages]
- State management detected: [Pattern]
- Force-upgrade/maintenance mode: [Status]
- Spell-check scope: [Scope]
- Public API docs enforcement: [Status]

13. Quality Index:
Section Summary with Scores:
- Tech Stack: [Score]/100 ([Label])
- Architecture: [Score]/100 ([Label])
- State Management: [Score]/100 ([Label])
- Repositories & Data Layer: [Score]/100 ([Label])
- Testing: [Score]/100 ([Label])
- Code Quality: [Score]/100 ([Label])
- Security: [Score]/100 ([Label])
- Documentation & Operations: [Score]/100 ([Label])
- CI/CD: [Score]/100 ([Label])
Overall Score: [Score]/100 ([Label])
[One-sentence interpretation]

14. Risks & Opportunities:
- [Risk/Opportunity 1]
- [Risk/Opportunity 2]
- [Continue as needed]

15. Recommendations:
1. [Priority Level]: [Recommendation 1]
2. [Priority Level]: [Recommendation 2]
3. [Continue as needed]

16. Appendix: Evidence Index:
File Paths and Configs by Area:
[Area Name]:
- [File path or config reference]
- [Continue as needed]

FORMATTING RULES:
- NO MARKDOWN SYNTAX: Use plain text only
- NO BOLD MARKERS: No **text** or __text__
- NO CODE FENCES: No ```code``` blocks
- NO TABLES: Use bullet points instead
- SECTION HEADERS: Use "X. Section Name" format
- SUBSECTION HEADERS: Use "Description:", "Score:", etc.
- BULLET POINTS: Use "- " for all lists
- NUMBERED LISTS: Use "1. ", "2. " format
- SCORES: Always format as "[Score]/100 ([Label])"
- LABELS: Use "Strong" (85-100), "Fair" (70-84), "Weak" (0-69)

LABELING
• After each section's Score, append label: Strong (85–100), Fair
  (70–84), Weak (0–69).

MONOREPO MULTI-APP HANDLING
• When apps/ directory is detected with multiple applications:
  - List each app found in apps/ directory
  - Check individual pubspec.yaml for each app
  - Verify individual test directories (apps/app1/test/, apps/app2/test/)
  - Check individual coverage data (coverage/app1/lcov.info,
    coverage/app2/lcov.info)
  - Report per-app coverage percentages in format: "coverage
    app1: X%", "coverage app2: Y%"
  - Verify individual CI/CD workflows for each app
  - Check individual analysis_options.yaml for each app (if present)
  - Check for nested packages in apps/<app>/packages/ (if exists)
  - Check for shared packages in apps/packages/ (if exists)
  - Verify CI/CD workflows for nested packages
    (.github/workflows/<app>_<package>.yaml)
  - Verify CI/CD workflows for shared packages
    (.github/workflows/shared_<package>.yaml)
  - Report per-app metrics in Additional Metrics section
• If apps/ directory is not present, treat as single-app
  repository (neutral)
• Coverage aggregation: Report both individual app coverage and
  overall monorepo coverage if available

IMPORTANT
• Analysis-only. No fixes. No CI proposals.
• Always cite concrete files in "Evidence".
• If any crucial artifact wasn't opened, explicitly say "Unknown:
  requires <path>".
• Integrate coverage analysis results from Flutter Test Coverage
  Runner when available.

• Include coverage percentages and threshold verification in
  Testing section.
• Reference coverage data in Additional Metrics section.
• For monorepos: Report individual app coverage percentages and
  overall metrics.
