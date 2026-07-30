# AngularJS Health Audit Report Generator

> Generate the final AngularJS Project Health Audit report by integrating all analysis results and calculating scores using the standardized format structure from assets/report-template.md.

---

Goal: Generate the final AngularJS Project Health Audit report by
integrating all analysis results and calculating scores using the
standardized format structure from
assets/report-template.md.

Apply the "AngularJS Project Health Audit" rule to generate the full
report with:
- 9 section scores (0-100 integer): Tech Stack, Architecture, State
  Management, Testing, Code Quality, Performance, Documentation
  & Operations, CI/CD, AI Harness & Adoption
- Weighted overall score using: Tech Stack 0.18, Architecture 0.18,
  State Management 0.135, Testing 0.135, Code Quality 0.135,
  Performance 0.075, Documentation & Operations 0.03, CI/CD 0.03,
  AI Harness & Adoption 0.10
- ROUNDING RULE: Use standard mathematical rounding (0.5 rounds up).
  Do NOT apply subjective adjustments.
- Important exclusions:
  * Do NOT recommend CODEOWNERS or SECURITY.md files - these are
    governance decisions, not technical requirements
  * Do NOT recommend deployment-specific workflows - these are
    deployment decisions, not technical requirements
- Labels: 85-100=Strong, 70-84=Fair, 0-69=Weak
- Markdown-formatted report ready for reading and sharing
- All sections with: Description, Score, Key Findings, Evidence,
  Risks, Recommendations, Counts & Metrics
- Judge AngularJS on its own (legacy/EOL) terms; surface the AngularJS EOL /
  Bower-abandonment migration risk in Risks & Opportunities.

NOTE: For security analysis, run the standalone Security Audit (/somnio-sa).

MANDATORY REPORT STRUCTURE (16 sections in exact order):
1. Executive Summary
2. At-a-Glance Scorecard
3. Tech Stack
4. Architecture
5. State Management
6. Testing
7. Code Quality (Linter & Warnings)
8. Performance
9. Documentation & Operations
10. CI/CD (Configs Found in Repo)
11. AI Harness & Adoption
12. Additional Metrics
13. Quality Index
14. Risks & Opportunities
15. Recommendations
16. Appendix: Evidence Index

The section titles above are fixed for scoring consistency; the BODY of each
section is calibrated to AngularJS 1.x concepts:
- Section 5 "State Management" = AngularJS services/factories, `$http`/
  interceptors, and `$rootScope` data flow.
- Section 8 "Performance" = digest-cycle/`$watch`/one-way-binding hygiene plus
  template/DOM patterns (`ng-repeat track by`, `ng-if` vs `ng-show`,
  `$sce.trustAsHtml`, direct DOM/jQuery).
- Section 7 "Code Quality" = JSHint/ESLint, minification-safe DI, and
  IIFE/`'use strict'` module hygiene.
- Section 10 "CI/CD" = the Grunt/gulp/webpack build & asset pipeline plus any
  CI workflow.

Integrate results from all previous analysis steps:
- Node.js Version Alignment results
- Repository Inventory findings
- Configuration Analysis results
- Build & Asset Pipeline / CI Analysis findings
- Testing Analysis results
- Code Quality Analysis results
- Services & Data Flow Analysis results
- Documentation Analysis results
- AI Harness & Adoption Analysis results
- Coverage results from the test-coverage step

PERFORMANCE SECTION (Section 8):
Since there is no dedicated performance reference step in the health
audit, derive the Performance score from evidence gathered across
all previous steps:
- Digest-cycle hygiene: `$watch`/`$watchCollection` count and any deep
  watches (from Services & Data Flow)
- Binding discipline: one-time (`::`) and one-way (`<`) bindings vs pervasive
  two-way (`=`) bindings
- `ng-repeat` with `track by` on large collections (grep the templates);
  missing `track by` on big lists is a real perf defect
- `ng-if` (removes from DOM) vs `ng-show` (keeps and toggles) usage on heavy
  subtrees
- Unsafe/expensive template patterns: function calls in bindings that run
  every digest, `$sce.trustAsHtml` on hot paths, direct DOM/jQuery mutation
- Template caching (`$templateCache`) and a minify/concat build (from the
  build pipeline) reducing runtime fetches
Score this section based on available evidence or mark as "Unknown"
if no evidence could be gathered.

Verify the Overall Score calculation:
- Check that the Overall Score uses the correct weighted formula
- Calculate: overall_score = round( sum(section_score x weight) )
- Ensure the Overall Score is an integer value (0-100)
- Verify the label assignment: 85-100=Strong, 70-84=Fair, 0-69=Weak

Address any "Unknown" items by referencing missing files/artifacts.

SECTION FORMAT REQUIREMENTS:
Each section MUST follow this exact format:

[Section Number]. [Section Name]

Description: [One-sentence description of the section's purpose]

Score: [Score]/100 ([Label])

Section 6 (Testing) EXCEPTION: MUST include "Code Coverage:" on a line
immediately after Score, before Key Findings. Extract from
test_coverage results (format: "Code Coverage: XX% lines / XX%
branches / XX% functions").

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
- Testing: [Score]/100 ([Label])
- Code Quality (Linter & Warnings): [Score]/100 ([Label])
- Performance: [Score]/100 ([Label])
- Documentation & Operations: [Score]/100 ([Label])
- CI/CD (Configs Found in Repo): [Score]/100 ([Label])
- AI Harness & Adoption: [Score]/100 ([Label])
- Overall: [Score]/100 ([Label])

11. AI Harness & Adoption:
Description: [One-sentence description of the state of the harness]
Score: [Score]/100 ([Label])
Maturity: [sin harness | harness basico | harness solido | paved path]
Coverage:
- CLAUDE.md: [Status] - [Points]/13
- Rules: [Status] - [Points]/9
- Permissions: [Status] - [Points]/13
- Hooks: [Status] - [Points]/14
- Pre-push git hook: [Status] - [Points]/11
- Agents: [Status] - [Points]/11
- Commands / Skills: [Status] - [Points]/9
- Advanced orchestration: [Status] - [Points]/5
- Lifecycle: [Status] - [Points]/3
- Harness versioning: [Status] - [Points]/12
- Total: [Points]/100
Key Findings:
- [Bullet point 1]
- [Bullet point 2]
- [Continue as needed]
Evidence:
- [Real file path or configuration reference, never invented]
- [Continue as needed]
Risks:
- [Risk item 1]
- [Continue as needed]
Actions to Raise the Score:
1. [+N] [Concrete how-to for this repo] -> dimension D, X/Y -> Y/Y.
2. [Continue, sorted by points recovered descending]
Counts & Metrics:
- [Metric name]: [Value]
- [Continue as needed]

12. Additional Metrics:
- Node.js version: [Version]
- AngularJS version: [Version] (>=1.8? Yes/No)
- Companion modules: [ui-router/ngRoute/ngResource/ngSanitize/...]
- Dependency manager: [Bower/npm/CDN-only/Mixed]
- Build tool: [Grunt/gulp/webpack/None]
- Router: [ngRoute/ui-router/None]
- Total controllers/directives/components count: [Count]
- Total services/factories count: [Count]
- Coverage %: [Percentage or status]
- Minification-safe DI: [Consistent annotations/ngAnnotate/UNSAFE]
- Template caching: [Configured/Missing]
- Test runner: [Karma/None]

13. Quality Index:
Section Summary with Scores:
- Tech Stack: [Score]/100 ([Label])
- Architecture: [Score]/100 ([Label])
- State Management: [Score]/100 ([Label])
- Testing: [Score]/100 ([Label])
- Code Quality: [Score]/100 ([Label])
- Performance: [Score]/100 ([Label])
- Documentation & Operations: [Score]/100 ([Label])
- CI/CD: [Score]/100 ([Label])
- AI Harness & Adoption: [Score]/100 ([Label])
Overall Score: [Score]/100 ([Label])
[One-sentence interpretation]

14. Risks & Opportunities:
- [Risk/Opportunity 1]
- [Risk/Opportunity 2]
- [Continue as needed - include the AngularJS EOL / Bower-abandonment
  migration risk]

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
- USE MARKDOWN SYNTAX: Use # headers, **bold**, `backtick` paths
- NO BOLD MARKERS: No **text** or __text__
- NO CODE FENCES: No fenced code blocks
- NO TABLES: Use bullet points instead
- SECTION HEADERS: Use "X. Section Name" format
- SUBSECTION HEADERS: Use "Description:", "Score:", etc.
- BULLET POINTS: Use "- " for all lists
- NUMBERED LISTS: Use "1. ", "2. " format
- SCORES: Always format as "[Score]/100 ([Label])"
- LABELS: Use "Strong" (85-100), "Fair" (70-84), "Weak" (0-69)

MONOREPO HANDLING:
For the rare AngularJS monorepo (multiple apps under one repo):
- Include app-specific metrics in Counts & Metrics
- Report per-app coverage in Additional Metrics
- Include app-specific evidence in Evidence sections
- Mention app names in descriptions where relevant
- Report cross-app consistency in Key Findings

Format: Markdown-formatted report (use proper Markdown syntax,
no bold markers, no fenced code blocks).
