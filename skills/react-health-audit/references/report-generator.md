# React Health Audit Report Generator

> Generate the final React Project Health Audit report by integrating all analysis results and calculating scores using the standardized format structure from assets/report-template.txt.

---

Goal: Generate the final React Project Health Audit report by
integrating all analysis results and calculating scores using the
standardized format structure from
assets/report-template.txt.

Apply the "React Project Health Audit" rule to generate the full
report with:
- 8 section scores (0-100 integer): Tech Stack, Architecture, State
  Management, Testing, Code Quality, Performance, Documentation
  & Operations, CI/CD
- Weighted overall score using: Tech Stack 0.20, Architecture 0.20,
  State Management 0.15, Testing 0.15, Code Quality 0.15,
  Performance 0.10, Documentation & Operations 0.035, CI/CD 0.035
- ROUNDING RULE: Use standard mathematical rounding (0.5 rounds up).
  Do NOT apply subjective adjustments.
- Important exclusions:
  * Do NOT recommend CODEOWNERS or SECURITY.md files - these are
    governance decisions, not technical requirements
  * Do NOT recommend deployment-specific workflows - these are
    deployment decisions, not technical requirements
- Labels: 85-100=Strong, 70-84=Fair, 0-69=Weak
- Plain-text format ready for Google Docs (NO markdown syntax)
- All sections with: Description, Score, Key Findings, Evidence,
  Risks, Recommendations, Counts & Metrics

NOTE: For security analysis, run the standalone Security Audit (/somnio-sa).

MANDATORY REPORT STRUCTURE (15 sections in exact order):
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
11. Additional Metrics
12. Quality Index
13. Risks & Opportunities
14. Recommendations
15. Appendix: Evidence Index

Integrate results from all previous analysis steps:
- Node.js Version Alignment results
- Repository Inventory findings
- Configuration Analysis results
- CI/CD Analysis findings
- Testing Analysis results
- Code Quality Analysis results
- State Management Analysis results
- Documentation Analysis results
- Coverage results from test-coverage step

PERFORMANCE SECTION (Section 8):
Since there is no dedicated performance reference step in the health
audit, derive the Performance score from evidence gathered across
all previous steps:
- React.memo usage detected in repository inventory
- Code splitting (React.lazy) detected in repository inventory
- Bundle optimization in bundler config (vite.config, next.config)
- Array index as key violations found via code grep
- List virtualization libraries in package.json
Score this section based on available evidence or mark as "Unknown"
if no evidence could be gathered.

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
- Overall: [Score]/100 ([Label])

11. Additional Metrics:
- Node.js version: [Version]
- React version: [Version]
- TypeScript version: [Version or Not used]
- Package manager: [npm/yarn/pnpm]
- Framework: [CRA/Vite/Next.js/Remix/Other]
- Monorepo tool: [nx/turborepo/lerna/none]
- Total components count: [Count]
- Total hooks count: [Count]
- Coverage %: [Percentage or status]
- State management: [useState/Context/Zustand/Redux/Mixed]
- Server state library: [TanStack Query/SWR/None]
- Rendering strategy: [CSR/SSR/SSG/ISR/Mixed]
- Styling approach: [CSS Modules/Styled Components/Tailwind/Other]

12. Quality Index:
Section Summary with Scores:
- Tech Stack: [Score]/100 ([Label])
- Architecture: [Score]/100 ([Label])
- State Management: [Score]/100 ([Label])
- Testing: [Score]/100 ([Label])
- Code Quality: [Score]/100 ([Label])
- Performance: [Score]/100 ([Label])
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

MONOREPO HANDLING:
For monorepo repositories (nx, turborepo, lerna):
- Include app-specific metrics in Counts & Metrics
- Report per-app coverage in Additional Metrics
- Include app-specific evidence in Evidence sections
- Mention app names in descriptions where relevant
- Report cross-app consistency in Key Findings

Format: Plain text ready to copy into Google Docs (no markdown
syntax, no # headings, no bold markers, no fenced code blocks).
