# Flutter Report Format Enforcer

> Enforce consistent report format structure for Flutter Project Health Audit reports based on the established template located in assets/report-template.txt

---

When generating the final report, you MUST follow this exact structure
and format based on the template in assets/report-template.txt:

----------------------------------------------------------------------
IMPORTANT EXCLUSIONS
----------------------------------------------------------------------

NEVER include recommendations for:
- Adding new languages or translations (internationalization
  expansion)
- CODEOWNERS or SECURITY.md files (governance decisions, not
  technical requirements)
- Platform-specific workflows for Android/iOS builds (deployment
  decisions, not technical requirements)

----------------------------------------------------------------------
MANDATORY REPORT STRUCTURE
----------------------------------------------------------------------

The report MUST contain exactly these 16 sections in this order:

1. Executive Summary
2. At-a-Glance Scorecard
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

----------------------------------------------------------------------
SECTION FORMAT REQUIREMENTS
----------------------------------------------------------------------

Each section MUST follow this exact format:

[Section Number]. [Section Name]

Description: [One-sentence description of the section's purpose]

Score: [Score]/100 ([Label])

Section 7 (Testing) MUST include "Code Coverage:" on a line immediately
after Score, before Key Findings. Extract from @flutter_test_coverage
artifact (line starting with "Code Coverage:").
MUST also include "Coverage Breakdown:" immediately after "Code Coverage:",
listing per-component coverage (one line per lib/package). Extract from
@flutter_test_coverage artifact (lines under "COVERAGE BREAKDOWN:").
For monorepos, separate by application and by package.

Example (single app with packages):
  Code Coverage: 3% (overall: lib + packages)
  Coverage Breakdown:
    locl/lib: 2%
    packages/app_config_repository: 10%
    packages/community_repository: 0%
    packages/location_service: 85%

Example (multi-app monorepo):
  Code Coverage: App appA: 15%, App appB: 22%
  Coverage Breakdown:
    appA/lib: 12%
    appA/packages/shared_ui: 20%
    appB/lib: 18%
    packages/common_utils: 45%

Key Findings:
- [Bullet point 1]
- [Bullet point 2]
- [Bullet point 3]
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

----------------------------------------------------------------------
SPECIAL SECTION FORMATS
----------------------------------------------------------------------

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
- Security: [Score]/100 ([Label])
- Documentation & Operations: [Score]/100 ([Label])
- CI/CD (Configs Found in Repo): [Score]/100 ([Label])
- Workflows with min_coverage < 70: [Count]
- Overall: [Score]/100 ([Label])

12. Additional Metrics:
- Supported platforms: [Platform list]
- Number of feature folders: [Count] ([App breakdown if multi-app])
- Packages count: [Count]
- Coverage %: [Percentage or status] (per app if multi-app)
- Coverage breakdown by component:
  [ProjectName]/lib: X%
  packages/[package_name]: X%
  [Continue for each component]
- Overall aggregated coverage %: [Total percentage combining all
  apps and packages]
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
- CI/CD: [Score]/100 ([Label]) (min_coverage check included)
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

----------------------------------------------------------------------
FORMATTING RULES
----------------------------------------------------------------------

1. NO MARKDOWN SYNTAX: Use plain text only
2. NO BOLD MARKERS: No **text** or __text__
3. NO CODE FENCES: No ```code``` blocks
4. NO TABLES: Use bullet points instead
5. SECTION HEADERS: Use "X. Section Name" format
6. SUBSECTION HEADERS: Use "Description:", "Score:", etc.
7. BULLET POINTS: Use "- " for all lists
8. NUMBERED LISTS: Use "1. ", "2. " format
9. SCORES: Always format as "[Score]/100 ([Label])"
10. LABELS: Use "Strong" (85-100), "Fair" (70-84), "Weak" (0-69)

----------------------------------------------------------------------
CONTENT REQUIREMENTS
----------------------------------------------------------------------

1. All sections must be present and in order
2. Each section must have all required subsections
3. Scores must be integers (0-100)
4. Labels must match score ranges
5. Evidence must reference actual file paths
6. Recommendations must be actionable
7. Risks must be specific and relevant
8. Metrics must be quantifiable when possible

----------------------------------------------------------------------
MULTI-APP HANDLING
----------------------------------------------------------------------

For multi-app repositories:
1. Include app-specific metrics in Counts & Metrics
2. Report per-app coverage in Additional Metrics
3. Include app-specific evidence in Evidence sections
4. Mention app names in descriptions where relevant
5. Report cross-app consistency in Key Findings

----------------------------------------------------------------------
VALIDATION CHECKLIST
----------------------------------------------------------------------

Before finalizing the report, verify:
✓ All 16 sections are present
✓ All sections follow the required format
✓ All scores are integers with proper labels
✓ All evidence references actual files
✓ All recommendations are actionable
✓ No markdown syntax is used
✓ Multi-app metrics are included if applicable
✓ Overall score calculation is correct
✓ Report is ready for Google Docs copy-paste

Remember: This format ensures consistency, readability, and
professional presentation of Flutter project health audit results.
