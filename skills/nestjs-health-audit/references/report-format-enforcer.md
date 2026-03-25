# NestJS Report Format Enforcer

> Enforce consistent report format structure for NestJS Project Health Audit reports based on the established template located in assets/report-template.txt

---

When generating the final report, you MUST follow this exact
structure and format based on the template in
assets/report-template.txt:

--------------------------------------------------------------------
IMPORTANT EXCLUSIONS
--------------------------------------------------------------------

NEVER include recommendations for:
- CODEOWNERS or SECURITY.md files (governance decisions, not
  technical requirements)
- Deployment-specific workflows (deployment decisions, not
  technical requirements)

--------------------------------------------------------------------
MANDATORY REPORT STRUCTURE
--------------------------------------------------------------------

The report MUST contain exactly these 16 sections in this order:

1. Executive Summary
2. At-a-Glance Scorecard
3. Tech Stack
4. Architecture
5. API Design
6. Data Layer
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

--------------------------------------------------------------------
SECTION FORMAT REQUIREMENTS
--------------------------------------------------------------------

Each section MUST follow this exact format:

[Section Number]. [Section Name]

Description: [One-sentence description of the section's purpose]

Score: [Score]/100 ([Label])

Section 7 (Testing) MUST include "Code Coverage:" on a line after Score.
Extract from @nestjs_test_coverage artifact.

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

--------------------------------------------------------------------
SPECIAL SECTION FORMATS
--------------------------------------------------------------------

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
- API Design: [Score]/100 ([Label])
- Data Layer: [Score]/100 ([Label])
- Testing: [Score]/100 ([Label])
- Code Quality (Linter & Warnings): [Score]/100 ([Label])
- Security: [Score]/100 ([Label])
- Documentation & Operations: [Score]/100 ([Label])
- CI/CD (Configs Found in Repo): [Score]/100 ([Label])
- Overall: [Score]/100 ([Label])

12. Additional Metrics:
- Node.js version: [Version]
- NestJS version: [Version]
- TypeScript version: [Version]
- Package manager: [npm/yarn/pnpm]
- Monorepo tool: [nx/turborepo/lerna/none]
- Total modules count: [Count] ([App breakdown if monorepo])
- Total controllers count: [Count]
- Total services count: [Count]
- Total DTOs count: [Count]
- Coverage %: [Percentage or status] (per app if monorepo)
- Overall aggregated coverage %: [Total percentage]
- API type detected: [REST/GraphQL/Hybrid]
- OpenAPI/Swagger enabled: [Yes/No]
- Database ORM: [TypeORM/Prisma/Sequelize/MikroORM/none]
- Authentication method: [JWT/Passport/Session/none]

13. Quality Index:
Section Summary with Scores:
- Tech Stack: [Score]/100 ([Label])
- Architecture: [Score]/100 ([Label])
- API Design: [Score]/100 ([Label])
- Data Layer: [Score]/100 ([Label])
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

--------------------------------------------------------------------
FORMATTING RULES
--------------------------------------------------------------------

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

--------------------------------------------------------------------
CONTENT REQUIREMENTS
--------------------------------------------------------------------

1. All sections must be present and in order
2. Each section must have all required subsections
3. Scores must be integers (0-100)
4. Labels must match score ranges
5. Evidence must reference actual file paths
6. Recommendations must be actionable
7. Risks must be specific and relevant
8. Metrics must be quantifiable when possible

--------------------------------------------------------------------
MONOREPO HANDLING
--------------------------------------------------------------------

For monorepo repositories (nx, turborepo, lerna):
1. Include app-specific metrics in Counts & Metrics
2. Report per-app coverage in Additional Metrics
3. Include app-specific evidence in Evidence sections
4. Mention app names in descriptions where relevant
5. Report cross-app consistency in Key Findings

--------------------------------------------------------------------
VALIDATION CHECKLIST
--------------------------------------------------------------------

Before finalizing the report, verify:
✓ All 16 sections are present
✓ All sections follow the required format
✓ All scores are integers with proper labels
✓ All evidence references actual files
✓ All recommendations are actionable
✓ No markdown syntax is used
✓ Monorepo metrics are included if applicable
✓ Overall score calculation is correct
✓ Report is ready for Google Docs copy-paste

Remember: This format ensures consistency, readability, and
professional presentation of NestJS project health audit results.
