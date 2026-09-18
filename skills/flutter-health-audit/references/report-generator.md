# Flutter Report Generator

> Generate the final Flutter Project Health Audit report by integrating all analysis results and calculating scores using the standardized format structure from assets/report-template.md.

---

Goal: Generate the final Flutter Project Health Audit report by
integrating all analysis results and calculating scores using the
standardized format structure from assets/report-template.md.

Apply the "Flutter Project Health Audit" rule to generate the full
report with:
- 9 section scores (0-100 integer): Tech Stack, Architecture, State
  Management, Repositories & Data Layer, Testing, Code Quality,
  Documentation & Operations, CI/CD, AI Harness & Adoption
- Weighted overall score using: Tech Stack 0.18, Architecture 0.18,
  State Management 0.18, Repositories & Data Layer 0.10, Testing 0.10,
  Code Quality 0.10, Documentation & Operations 0.03, CI/CD 0.03,
  AI Harness & Adoption 0.10
- ROUNDING RULE: Use standard mathematical rounding (0.5 rounds up).
  Do NOT apply subjective adjustments.
- Important exclusions:
  * Do NOT recommend adding new languages or translations
  * Do NOT recommend CODEOWNERS or SECURITY.md files - these are
    governance decisions, not technical requirements
  * Do NOT recommend platform-specific workflows for Android/iOS
    builds - these are deployment decisions, not technical
    requirements
- Labels: 85-100=Strong, 70-84=Fair, 0-69=Weak
- Markdown-formatted report ready for reading and sharing
- All sections with: Description, Score, Key Findings, Evidence,
  Risks, Recommendations, Counts & Metrics

NOTE: For security analysis, run the standalone Security Audit (/somnio-sa).

MANDATORY REPORT STRUCTURE (15 numbered sections + 2 trailing
unnumbered blocks, in exact order). Section 13 "Quality Index" no
longer exists — it was a byte-for-byte duplicate of the Section 2
scorecard and has been deleted; its one non-duplicate line (a trailing
interpretation sentence) now lives at the end of Section 2:
1. Executive Summary
2. At-a-Glance Scorecard
3. Tech Stack
4. Architecture
5. State Management
6. Repositories & Data Layer
7. Testing
8. Code Quality (Linter & Warnings)
9. Documentation & Operations
10. CI/CD (Configs Found in Repo)
11. AI Harness & Adoption
12. Additional Metrics
13. Risks & Opportunities
14. Recommendations
15. Appendix: Evidence Index
Appendix: Scoring Methodology (UNNUMBERED — see the special format below)
Report Metadata (UNNUMBERED — content specified in SKILL.md)

Integrate results from all previous analysis steps:
- Flutter Version Alignment results
- Repository Inventory findings
- Configuration Analysis results
- CI/CD Analysis findings
- Testing Analysis results
- Code Quality Analysis results
- Documentation Analysis results
- AI Harness & Adoption Analysis results

Verify the Overall Score calculation:
- Check that the Overall Score uses the correct weighted formula
- Calculate: overall_score = round( Σ(section_score × weight) )
- Ensure the Overall Score is an integer value (0-100)
- Verify the label assignment: 85-100=Strong, 70-84=Fair, 0-69=Weak

Address any "Unknown" items by referencing missing files/artifacts.

SECTION FORMAT REQUIREMENTS:
Each section MUST follow this exact format:

[Section Number]. [Section Name]

Description: [One-sentence description of the section's purpose]

Score: [Score]/100 ([Label])

Section 7 (Testing) EXCEPTION — NON-NEGOTIABLE:
MUST include "Code Coverage:" on a line immediately after Score, before
Key Findings. MUST also include "Coverage Breakdown:" immediately after
"Code Coverage:", listing per-component coverage (one line per
lib/package).

HOW TO EXTRACT: In this run's artifacts directory (the directory
under reports/.artifacts/ where this audit's step artifacts were
written), find the single file matching the glob:
  step_*_test?coverage.md
(this matches both step_NN_test-coverage.md and
step_NN_test_coverage.md, whatever the step index). Read that file.
Copy the "Code Coverage:" and "Coverage Breakdown:" lines VERBATIM
from that file into Section 7 of the report. Do NOT summarize,
reformat, or omit any line.

If no file matches the glob, or the matching file is empty, output:
  Code Coverage: 0% (coverage data unavailable)
  Coverage Breakdown:
    (no coverage data — artifact missing)

EXAMPLE OUTPUT for Section 7 (single app with packages):

  Score: 35/100 (Weak)

  Code Coverage: 3% (overall: lib + packages)
  Coverage Breakdown:
    locl/lib: 2%
    packages/app_config_repository: 10%
    packages/community_repository: 0%
    packages/location_service: 85%
    packages/locl_api_client: 10%
    packages/locl_app_ui: 4%
    packages/media_service: 88%
    packages/notification_badge_service: 11%
    packages/notification_repository: 0%
    packages/permission_service: 3%
    packages/post_repository: 0%
    packages/proto_http_client: 4%
    packages/share_service: 60%

  Key Findings:
  - ...

EXAMPLE OUTPUT for Section 7 (multi-app monorepo):

  Score: 42/100 (Weak)

  Code Coverage: App appA: 15%, App appB: 22%
  Coverage Breakdown:
    appA/lib: 12%
    appA/packages/shared_ui: 20%
    appB/lib: 18%
    packages/common_utils: 45%
    packages/api_client: 8%

  Key Findings:
  - ...

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

1. Executive Summary:
Description: [Comprehensive analysis description]
Overall Score: [Score]/100 ([Label])
Top Strengths:
- [Strength 1]
- [Strength 2]
- [Continue as needed]
Top Risks:
- [Risk 1]
- [Risk 2]
- [Continue as needed]
Priority Recommendations:
1. [Recommendation 1]
2. [Recommendation 2]
3. [Continue as needed]

2. At-a-Glance Scorecard:
- Tech Stack: [Score]/100 ([Label])
- Architecture: [Score]/100 ([Label])
- State Management: [Score]/100 ([Label])
- Repositories & Data Layer: [Score]/100 ([Label])
- Testing: [Score]/100 ([Label])
- Code Quality (Linter & Warnings): [Score]/100 ([Label])
- Documentation & Operations: [Score]/100 ([Label])
- CI/CD (Configs Found in Repo): [Score]/100 ([Label])
- AI Harness & Adoption: [Score]/100 ([Label])
- Overall: [Score]/100 ([Label])
Do NOT add a Weight column to this table — weights appear ONLY in the
Appendix: Scoring Methodology block.
Immediately below the scorecard rows, in this exact order:
- Test Coverage: [X]% (lines) — full breakdown in the Testing section.
  Fallback when no coverage tool is detected: "Not measured (no
  coverage tool detected/configured)"
- Scoring: Strong (85-100), Fair (70-84), Weak (0-69)
- [One-sentence interpretation of the Overall Score] — this is the
  sentence absorbed from the deleted Quality Index section; if Quality
  Index used to end with a concrete interpretation sentence, move it
  here adapted, otherwise use a placeholder.
The label is always "Test Coverage", never a bare "Coverage" — that
word is the AI Harness rubric heading in Section 11 (Harness Coverage).

11. AI Harness & Adoption:
Description: [One-sentence description of the harness analysis].
Score: [Score]/100 ([Label])
Maturity: [sin harness | harness básico | harness sólido | paved path]
Harness Coverage:
- CLAUDE.md: [Status] — [Points]/13
- Rules: [Status] — [Points]/9
- Permissions: [Status] — [Points]/13
- Hooks: [Status] — [Points]/14
- Pre-push git hook: [Status] — [Points]/11
- Agents: [Status] — [Points]/11
- Commands / Skills: [Status] — [Points]/9
- Advanced orchestration: [Status] — [Points]/5
- Lifecycle: [Status] — [Points]/3
- Harness versioning: [Status] — [Points]/12
- Total: [Score]/100
Key Findings:
- [Finding 1]
- [Continue as needed]
Evidence:
- [Real file path only, never invented]
- [Continue as needed]
Risks:
- [Risk item 1]
- [Continue as needed]
Actions to Raise the Score:
1. [+N] [Action naming the file/key to add and the how-to] → dimension D, X/Y → Y/Y.
2. [Continue as needed, sorted by points recovered descending]
Counts & Metrics:
- [Metric name]: [Value]
- [Continue as needed]

12. Additional Metrics:
- Supported platforms: [Platform list]
- Number of feature folders: [Count] ([App breakdown if multi-app])
- Packages count: [Count]
- State management detected: [Pattern]
- Force-upgrade/maintenance mode: [Status]
- Spell-check scope: [Scope]
- Public API docs enforcement: [Status]
Do NOT restate any coverage percentage here (no "Coverage %:", no
"Coverage breakdown by component:", no "Overall aggregated coverage
%:"). Coverage appears in exactly two places in the whole report: the
Test Coverage line under the Section 2 scorecard, and the Code
Coverage / Coverage Breakdown fields in Section 7 (Testing). Nowhere
else, including here.

13. Risks & Opportunities:
- [Risk/Opportunity 1]
- [Risk/Opportunity 2]
- [Continue as needed]

14. Recommendations:
1. [Priority Level]: [Recommendation 1]
2. [Priority Level]: [Recommendation 2]
3. [Continue as needed]

15. Appendix: Evidence Index:
File Paths and Configs by Area:
[Area Name]:
- [File path or config reference]
- [Continue as needed]

Appendix: Scoring Methodology (UNNUMBERED, follows Section 15, comes
before Report Metadata):
This is the ONLY report-facing surface where weights may appear. Do
NOT put a Weight column in the Section 2 scorecard table.
Weighted formula (weights sum to 1.00):
- Tech Stack: 0.18
- Architecture: 0.18
- State Management: 0.18
- Repositories & Data Layer: 0.10
- Testing: 0.10
- Code Quality (Linter & Warnings): 0.10
- Documentation & Operations: 0.03
- CI/CD (Configs Found in Repo): 0.03
- AI Harness & Adoption: 0.10
- Total: 1.00
Rounding rule: Standard mathematical rounding (0.5 rounds up). No
subjective adjustment.
Scoring bands: Strong (85-100), Fair (70-84), Weak (0-69)
These are the same weight literals used to compute the Overall Score
above — this file is their single source of truth. The report-writer
agent renders this exact table into the report; it must not invent or
alter these numbers.

FORMATTING RULES:
- USE MARKDOWN SYNTAX: Use # headers, **bold**, `backtick` paths
- NO BOLD MARKERS: No **text** or __text__
- NO CODE FENCES: No ```code``` blocks
- NO TABLES: Use bullet points instead
- SECTION HEADERS: Use "X. Section Name" format
- SUBSECTION HEADERS: Use "Description:", "Score:", etc.
- BULLET POINTS: Use "- " for all lists
- NUMBERED LISTS: Use "1. ", "2. " format
- SCORES: Always format as "[Score]/100 ([Label])"
- LABELS: Use "Strong" (85-100), "Fair" (70-84), "Weak" (0-69)

MULTI-APP HANDLING:
For multi-app repositories:
- Include app-specific metrics in Counts & Metrics
- Report per-app coverage in Additional Metrics
- Include app-specific evidence in Evidence sections
- Mention app names in descriptions where relevant
- Report cross-app consistency in Key Findings

VALIDATION CHECKLIST:
Before finalizing the report, verify:
✓ All 15 numbered sections are present (no Quality Index), plus the
  unnumbered Appendix: Scoring Methodology and Report Metadata blocks
✓ All sections follow the required format
✓ All scores are integers with proper labels
✓ All evidence references actual files
✓ All recommendations are actionable
✓ Markdown formatting is used consistently
✓ Multi-app metrics are included if applicable
✓ Overall score calculation is correct
✓ Report uses proper Markdown headings and formatting
✓ Coverage appears exactly twice (Section 2 Test Coverage line, Section
  7 Code Coverage/Coverage Breakdown fields) and nowhere else
✓ No Weight column in the Section 2 scorecard table; weights appear
  only in the Appendix: Scoring Methodology

Format: Markdown-formatted report (use proper Markdown syntax,
syntax, no # headings, no bold markers, no fenced code blocks).
