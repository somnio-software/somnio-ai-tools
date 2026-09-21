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
  (These weights are the authoritative source for this skill — every
  other file, including references/report-format-enforcer.md and
  agents/report-writer.md, must point back here rather than restate
  them.)
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

MANDATORY REPORT STRUCTURE (15 numbered sections in exact order, plus
two trailing UNNUMBERED blocks — Appendix: Scoring Methodology and
Report Metadata):
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

Section 6 (Testing) EXCEPTION: immediately after Score, before Key
Findings, include BOTH canonical coverage fields (never just one):
- "Code Coverage: [X]% (lines)" — or, when applicable, the
  multi-dimension ("[X]% lines / [Y]% branches / [Z]% functions"),
  monorepo/multi-app, or "no coverage tool detected" fallback wording
  from assets/report-template.md.
- "Coverage Breakdown:" — a bullet list, one line per module/package/
  app, or the single-package / no-data fallback wording from
  assets/report-template.md.
Extract from test_coverage results. These two Testing fields, plus the
At-a-Glance Scorecard's "Test Coverage:" summary line (Section 2), are
the ONLY places a coverage percentage may appear anywhere in the
report — never restate it in Counts & Metrics or in Additional
Metrics (Section 12).

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
Immediately below the scorecard, in this order (see
assets/report-template.md for exact wording):
- Test Coverage: [X]% (lines) — full breakdown in the Testing
  section. (Fallback when no coverage tool is detected: "Not measured
  (no coverage tool detected/configured)".)
- Scoring legend: "Strong (85–100) · Fair (70–84) · Weak (0–69)"
  (en dash in the ranges, middle dot as separator — do not use ASCII
  hyphens).
- [One-sentence interpretation of the Overall Score]. This sentence is
  what used to close the old Quality Index section — carry that
  interpretation here instead of reintroducing a Quality Index section.

11. AI Harness & Adoption:
Description: [One-sentence description of the state of the harness]
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
- State management: [Signals/NgRx/NGXS/ComponentStore/BehaviorSubject services/Mixed]
- Change detection: [OnPush usage count / Default]
- Rendering strategy: [CSR/SSR (Angular Universal)/SSG (prerender)/Mixed]
- Styling approach: [CSS/SCSS/Tailwind/Component styles/Other]
Do NOT add a coverage percentage bullet here (e.g. "Coverage %:" or
similar) — coverage is reported exactly twice in the whole document:
the Section 2 scorecard's "Test Coverage:" line and the Section 6
Testing "Code Coverage:" / "Coverage Breakdown:" fields. Nowhere else.

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

Appendix: Scoring Methodology (UNNUMBERED, trailing — after Section 15
and before Report Metadata):
- Render the weighted formula (see the weights list at the top of this
  file) as a "| Section | Weight |" table, one row per scored section
  using this skill's own scorecard row labels, plus a
  "| Total | 1.00 |" row.
- State the rounding rule (standard mathematical rounding, 0.5 rounds
  up, no subjective adjustment) and the scoring bands
  ("Strong (85–100) · Fair (70–84) · Weak (0–69)").
- This appendix is the ONLY report-facing surface where weights may
  appear — never add a Weight column to the Section 2 scorecard table.
- See assets/report-template.md for the exact block shape.

FORMATTING RULES:
- USE MARKDOWN SYNTAX: Use ## headings, **bold**, `backtick` paths
- USE BOLD: Bold field labels and key values (**Score:**, **Overall**)
- USE CODE BLOCKS: Backticks for file paths and inline code
- USE TABLES: Markdown pipe tables wherever the template renders one
- SECTION HEADERS: Use "## X. Section Name"; subsections use "### Name"
- FIELD LABELS: Bold them — "**Description:**", "**Score:**", etc.
- BULLET POINTS: Use "- " for all lists
- NUMBERED LISTS: Use "1. ", "2. " format
- SCORES: Always format as "[Score]/100 ([Label])"
- LABELS: Use "Strong" (85-100), "Fair" (70-84), "Weak" (0-69)

MULTI-PROJECT WORKSPACE HANDLING:
For multi-project Angular workspaces (multiple projects, Nx):
- Include project-specific metrics in Counts & Metrics
- Report per-project coverage in the Section 6 Testing Coverage
  Breakdown (not in Additional Metrics)
- Include project-specific evidence in Evidence sections
- Mention project names in descriptions where relevant
- Report cross-project consistency in Key Findings

Format: Markdown-formatted report — ## headings, **bold** field
labels and pipe tables, exactly as assets/report-template.md renders
them. That template and references/report-format-enforcer.md are
authoritative on formatting; this file must not contradict them.
