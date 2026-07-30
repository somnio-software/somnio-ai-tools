# Angular Health Audit Report Generator

> Generate the final Angular Project Health Audit report by integrating all analysis results and calculating scores using the standardized format structure from assets/report-template.md.

---

Goal: Generate the final Angular Project Health Audit report by
integrating all analysis results and calculating scores using the
standardized format structure from
assets/report-template.md.

Apply the "Angular Project Health Audit" rule to generate the full
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

Integrate results from all previous analysis steps:
- Node.js Version Alignment results
- Repository Inventory findings
- Configuration Analysis results
- CI/CD Analysis findings
- Testing Analysis results
- Code Quality Analysis results
- State Management Analysis results
- Documentation Analysis results
- AI Harness & Adoption Analysis results
- Coverage results from test-coverage step

PERFORMANCE SECTION (Section 8):
Since there is no dedicated performance reference step in the health
audit, derive the Performance score from evidence gathered across
all previous steps (Angular change-detection and build concerns):
- ChangeDetectionStrategy.OnPush usage detected via code grep
- trackBy on *ngFor / track on @for detected via code grep
- Lazy-loaded routes (loadChildren / loadComponent) in routing config
- Bundle budgets defined in angular.json and production optimization
- Heavy work in templates (functions/getters called from bindings)
- Unsafe [innerHTML] bindings detected via code grep (safety/perf signal)
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
- AI Harness & Adoption: [Score]/100 ([Label])
- Overall: [Score]/100 ([Label])

11. AI Harness & Adoption:
Description: [One-sentence description of the state of the harness]
Score: [Score]/100 ([Label])
Maturity: [sin harness | harness básico | harness sólido | paved path]
Coverage:
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
- Angular version: [Version] (support status)
- TypeScript version: [Version]
- RxJS version: [Version]
- Package manager: [npm/yarn/pnpm]
- Build system: [Angular CLI application/browser builder — esbuild/webpack]
- Workspace type: [single-project/multi-project/Nx/none]
- Module strategy: [NgModules/Standalone/Mixed]
- Total components count: [Count]
- Total services count: [Count]
- Coverage %: [Percentage or status]
- State management: [Signals/NgRx/NGXS/ComponentStore/BehaviorSubject services/Mixed]
- Change detection: [OnPush usage count / Default]
- Rendering strategy: [CSR/SSR (Angular Universal)/SSG (prerender)/Mixed]
- Styling approach: [CSS/SCSS/Tailwind/Component styles/Other]

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

MULTI-PROJECT WORKSPACE HANDLING:
For multi-project Angular workspaces (multiple projects, Nx):
- Include project-specific metrics in Counts & Metrics
- Report per-project coverage in Additional Metrics
- Include project-specific evidence in Evidence sections
- Mention project names in descriptions where relevant
- Report cross-project consistency in Key Findings

Format: Markdown-formatted report (use proper Markdown syntax,
syntax, no # headings, no bold markers, no fenced code blocks).
