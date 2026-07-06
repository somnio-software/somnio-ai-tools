# Python Report Generator

> Generate the final Python Project Health Audit report by integrating all analysis results and calculating scores using the standardized format structure from assets/report-template.md.

---

Goal: Generate the final Python Project Health Audit report by
integrating all analysis results and calculating scores using the
standardized format structure from assets/report-template.md.

Apply the "Python Project Health Audit" rule to generate the full
report with:
- 8 section scores (0-100 integer): Tech Stack, Architecture, API /
  Interface Design, Data Layer, Testing, Code Quality, Documentation &
  Operations, CI/CD
- Weighted overall score using: Tech Stack 0.20, Architecture 0.20,
  API / Interface Design 0.20, Data Layer 0.11, Testing 0.11,
  Code Quality 0.11, Documentation & Operations 0.035, CI/CD 0.035
- ROUNDING RULE: Use standard mathematical rounding (0.5 rounds up).
  Do NOT apply subjective adjustments.
- Important exclusions:
  * Do NOT recommend adding new languages or translations
  * Do NOT recommend CODEOWNERS or SECURITY.md files - these are
    governance decisions, not technical requirements
  * Do NOT recommend platform-specific deploy or runbook docs - these
    are deployment decisions, not technical requirements
- Labels: 85-100=Strong, 70-84=Fair, 0-69=Weak
- Markdown-formatted report ready for reading and sharing
- All sections with: Description, Score, Key Findings, Evidence,
  Risks, Recommendations, Counts & Metrics

NOTE: For security analysis, run the standalone Security Audit (/somnio-sa).

MANDATORY REPORT STRUCTURE (15 sections in exact order):
1. Executive Summary
2. At-a-Glance Scorecard
3. Tech Stack
4. Architecture
5. API / Interface Design
6. Data Layer
7. Testing
8. Code Quality (Linter & Warnings)
9. Documentation & Operations
10. CI/CD (Configs Found in Repo)
11. Additional Metrics
12. Quality Index
13. Risks & Opportunities
14. Recommendations
15. Appendix: Evidence Index

Integrate results from all previous analysis steps:
- Version Alignment results
- Repository Inventory findings
- Configuration Analysis results
- CI/CD Analysis findings
- Testing Analysis results
- Code Quality Analysis results
- API Design Analysis results
- Data Layer Analysis results
- Documentation Analysis results

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
package/module).

HOW TO EXTRACT: Read the artifact file at
  reports/.artifacts/python_health/step_00_test_coverage.md
Copy the "Code Coverage:" and "Coverage Breakdown:" lines VERBATIM
from that file into Section 7 of the report. Do NOT summarize,
reformat, or omit any line.

If the artifact file does not exist or is empty, output:
  Code Coverage: 0% (coverage data unavailable)
  Coverage Breakdown:
    (no coverage data — artifact missing)

Coverage categories: Excellent 90-100, Good 80-89, Fair 70-79,
Poor 60-69, Critical <60. Target 70%+ (floor, not a quality proxy).

EXAMPLE OUTPUT for Section 7 (single package):

  Score: 35/100 (Weak)

  Code Coverage: 3% (overall)
  Coverage Breakdown:
    src/myapp: 2%
    src/myapp/api: 5%
    src/myapp/services: 0%
    src/myapp/repositories: 10%
    src/myapp/models: 4%

  Key Findings:
  - ...

EXAMPLE OUTPUT for Section 7 (monorepo):

  Score: 42/100 (Weak)

  Code Coverage: App appA: 15%, App appB: 22%
  Coverage Breakdown:
    appA/src: 12%
    appA/packages/shared: 20%
    appB/src: 18%
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
- API / Interface Design: [Score]/100 ([Label])
- Data Layer: [Score]/100 ([Label])
- Testing: [Score]/100 ([Label])
- Code Quality (Linter & Warnings): [Score]/100 ([Label])
- Documentation & Operations: [Score]/100 ([Label])
- CI/CD (Configs Found in Repo): [Score]/100 ([Label])
- Overall: [Score]/100 ([Label])

11. Additional Metrics:
- Python version: [Version or range]
- Package manager: [uv / pip / poetry / pdm]
- Number of packages/apps: [Count] ([Breakdown if monorepo])
- Coverage %: [Percentage or status] (per package if monorepo)
- Coverage breakdown by component:
  [PackageName]/src: X%
  packages/[package_name]: X%
  [Continue for each package]
- Overall aggregated coverage %: [Total percentage combining all
  packages]
- Framework detected: [FastAPI / Django / Flask / library / CLI / other]
- Type checker: [pyright / basedpyright / mypy / none]
- Linter/formatter: [Ruff / flake8+black / other]
- API versioning strategy: [Status]
- OpenAPI/schema docs enforcement: [Status]

12. Quality Index:
Section Summary with Scores:
- Tech Stack: [Score]/100 ([Label])
- Architecture: [Score]/100 ([Label])
- API / Interface Design: [Score]/100 ([Label])
- Data Layer: [Score]/100 ([Label])
- Testing: [Score]/100 ([Label])
- Code Quality: [Score]/100 ([Label])
- Documentation & Operations: [Score]/100 ([Label])
- CI/CD: [Score]/100 ([Label])
Overall Score: [Score]/100 ([Label])
[One-sentence interpretation]

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

MONOREPO HANDLING:
For monorepo repositories:
- Include package-specific metrics in Counts & Metrics
- Report per-package coverage in Additional Metrics
- Include package-specific evidence in Evidence sections
- Mention package names in descriptions where relevant
- Report cross-package consistency in Key Findings

VALIDATION CHECKLIST:
Before finalizing the report, verify:
✓ All 15 sections are present
✓ All sections follow the required format
✓ All scores are integers with proper labels
✓ All evidence references actual files
✓ All recommendations are actionable
✓ Markdown formatting is used consistently
✓ Monorepo metrics are included if applicable
✓ Overall score calculation is correct
✓ Report uses proper Markdown headings and formatting

Format: Markdown-formatted report (use proper Markdown syntax,
no # headings, no bold markers, no fenced code blocks).
