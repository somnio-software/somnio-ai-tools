# .NET Health Audit Report Generator

> Generate the final .NET Project Health Audit report by integrating all analysis results and calculating scores using the standardized format structure from assets/report-template.md.

---

Goal: Generate the final .NET Project Health Audit report by
integrating all analysis results and calculating scores using the
standardized format structure from
assets/report-template.md.

Apply the ".NET Project Health Audit" rule to generate the full
report with:
- 9 section scores (0-100 integer): Tech Stack, Architecture, API
  Design, Data Layer, Testing, Code Quality, Documentation
  & Operations, CI/CD, AI Harness & Adoption
- Weighted overall score using: Tech Stack 0.18, Architecture 0.18,
  API Design 0.18, Data Layer 0.10, Testing 0.10, Code Quality 0.10,
  Documentation & Operations 0.03, CI/CD 0.03, AI Harness & Adoption 0.10
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
two trailing unnumbered blocks):
1. Executive Summary
2. At-a-Glance Scorecard
3. Tech Stack
4. Architecture
5. API Design
6. Data Layer
7. Testing
8. Code Quality (Linter & Warnings)
9. Documentation & Operations
10. CI/CD (Configs Found in Repo)
11. AI Harness & Adoption
12. Additional Metrics
13. Risks & Opportunities
14. Recommendations
15. Appendix: Evidence Index

Followed by two unnumbered blocks, in this order: "Appendix: Scoring
Methodology" (see assets/report-template.md for its exact shape — the
weights below are its authoritative source), then "Report Metadata".

Section 8 keeps the canonical "Code Quality (Linter & Warnings)" name
shared by every health audit; for .NET its content is the Roslyn
analyzer, `TreatWarningsAsErrors`, `.editorconfig` severity, nullable
and sync-over-async findings from the code-quality step.

Integrate results from all previous analysis steps:
- .NET SDK Alignment results
- Repository Inventory findings (including the identified architecture pattern)
- Configuration Analysis results
- Support Lifecycle Analysis results (blend into Tech Stack — NOT a new section)
- CI/CD Analysis findings
- Testing Analysis results
- Code Quality Analysis results
- Dependency Security Analysis results (blend into Tech Stack — NOT a new section)
- API Design Analysis results
- Data Layer Analysis results
- SOLID Compliance and Cyclomatic Complexity Analysis results (blend into Architecture — NOT a new section)
- Documentation Analysis results
- AI Harness & Adoption findings
- Coverage results from test-coverage step

TECH STACK SECTION COMPOSITION (Section 3): this section now blends THREE
upstream steps — do not write three sub-reports, synthesize one coherent
section:
- SDK/TargetFramework/tooling findings (from version-alignment, version-validator, repository-inventory, config-analysis)
- .NET support lifecycle status (from support-lifecycle-analysis): per-TFM
  in-support/out-of-support verdict, months remaining/elapsed, recommended
  LTS target
- Dependency security findings (from dependency-security-analysis):
  vulnerable package count by severity, outdated package count, NuGet
  source hygiene
A codebase with a current SDK but an unsupported TargetFramework or
unpatched Critical vulnerabilities should NOT score Strong on Tech Stack —
weigh all three inputs, do not let a clean SDK/tooling picture mask a
lifecycle or security problem.

ARCHITECTURE SECTION COMPOSITION (Section 4): this section now blends TWO
upstream steps:
- Architecture pattern findings (from repository-inventory): which of
  Vertical Slice / Onion / Clean Architecture / N-Layer / Flat is used,
  and dependency-direction confirmation for multi-project patterns
- SOLID compliance and cyclomatic complexity findings (from
  solid-compliance-analysis): SRP/OCP/LSP/ISP/DIP violation counts, real
  CA1502/CA1506 complexity/coupling numbers
A codebase with a clean, consistent architecture pattern but pervasive
SOLID violations or high real complexity should NOT score Strong on
Architecture — the folder-level pattern is necessary but not sufficient
for a good architecture score.

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

Section 7 (Testing) EXCEPTION: MUST include the canonical coverage
fields between Score and Key Findings — "Code Coverage:" (with its
multi-dimension/monorepo/no-tool fallback sub-lines) and "Coverage
Breakdown:" — exactly as shown in assets/report-template.md. Extract
the values from the @dotnet_test_coverage artifact. Coverlet's
Cobertura output carries line and branch rates (no function rate), so
when both were extracted render the multi-dimension form as
`[X]% lines / [Y]% branches`; render only what the artifact actually
contains. When the artifact reports "Unknown — no test projects
detected", use the no-coverage-tool fallback. Do NOT restate the
coverage percentage anywhere else in the section (Counts & Metrics
must not repeat it).

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
| Section | Score | Label |
|---------|-------|-------|
| Tech Stack | [Score]/100 | [Label] |
| Architecture | [Score]/100 | [Label] |
| API Design | [Score]/100 | [Label] |
| Data Layer | [Score]/100 | [Label] |
| Testing | [Score]/100 | [Label] |
| Code Quality (Linter & Warnings) | [Score]/100 | [Label] |
| Documentation & Operations | [Score]/100 | [Label] |
| CI/CD (Configs Found in Repo) | [Score]/100 | [Label] |
| AI Harness & Adoption | [Score]/100 | [Label] |
| **Overall** | **[Score]/100** | **[Label]** |

The scorecard has exactly the template's columns (`| Section | Score | Label |`). Never add Weight, Previous, Baseline, Change or Delta columns; trend data goes only in its defined slot.

Immediately below the scorecard, in this exact order: a
"> Test Coverage: [X]% (lines) — full breakdown in the Testing
section." blockquote (with its "no coverage tool detected" fallback as
a second line inside the SAME blockquote), the
"> Scoring: Strong (85–100) · Fair (70–84) · Weak (0–69)" legend, then
a one-sentence interpretation of the Overall Score. See
assets/report-template.md for the exact wording and punctuation (en
dash, middle dot).

11. AI Harness & Adoption:
Render this section from the AI Harness & Adoption artifact (produced
by references/harness-analysis.md), exactly as assets/report-template.md
shows it: Description, Score, Maturity, the "### Harness Coverage"
10-dimension table (never a bare "### Coverage" heading), Key
Findings, Evidence, Risks, "Actions to Raise the Score" and Counts &
Metrics. Copy the dimension points and the total from the artifact; do
not re-score them. If the harness rubric's 60-point cap applied (no
harness file tracked in git), say so in the Score line and give the
uncapped sum, as the artifact reports it.

12. Additional Metrics:
- .NET SDK version: [Version] (global.json pin: [Version or "none"])
- TargetFramework(s): [net8.0/etc, note inconsistencies]
- .NET support status: [In support (LTS/STS) / Out of support since [month year] / Supported via OS lifecycle]
- Recommended LTS upgrade target: [e.g. net8.0]
- Project type: [Web API/Blazor/Worker Service/Class Library/Mixed]
- Architecture pattern: [Vertical Slice/Onion/Clean Architecture/N-Layer/Flat/Mixed]
- API style: [Controllers/Minimal APIs/Hybrid]
- Solution project count: [Count]
- Total controllers or endpoint groups count: [Count]
- Total services count: [Count]
- Total DTOs count: [Count]
- Database ORM: [Entity Framework Core/Dapper/none]
- Test framework: [xUnit/NUnit/MSTest/none]
- API versioning strategy: [URI/Header/None]
- OpenAPI/Swagger enabled: [Yes/No]
- Central Package Management: [Yes/No]
- Nullable reference types: [Enabled/Disabled/Partial]
- Authentication method: [JWT/Cookie/Identity/none]
- Vulnerable packages: [Count] (Critical: N, High: N, Moderate: N, Low: N)
- Outdated packages (3+ major versions behind): [Count]
- SOLID violations: [Count] (SRP: N, OCP: N, LSP: N, ISP: N, DIP: N)
- Cyclomatic complexity hits: [CA1502 count] / Class coupling hits: [CA1506 count]

Do NOT include a coverage percentage bullet here (no "Coverage %:" or
"Overall aggregated coverage %:"). Coverage lives only in the At-a-
Glance Scorecard's "Test Coverage" line and in the Testing section's
"Code Coverage:" / "Coverage Breakdown:" fields (see Section 7 above).

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
- USE MARKDOWN SYNTAX: Use ## headings, **bold**, `backtick` paths
- USE BOLD: Bold the field label only; never bold the numeric value after `**Score:**`.
- USE CODE BLOCKS: Backticks for file paths and inline code
- USE TABLES: Markdown pipe tables wherever the template renders one
- SECTION HEADERS: Use "## X. Section Name"; subsections use "### Name"
- FIELD LABELS: Bold them — "**Description:**", "**Score:**", etc.
- BULLET POINTS: Use "- " for all lists
- NUMBERED LISTS: Use "1. ", "2. " format
- SCORES: Always format as "[Score]/100 ([Label])"
- LABELS: Use "Strong" (85-100), "Fair" (70-84), "Weak" (0-69)

MULTI-PROJECT SOLUTION HANDLING:
For solutions with multiple deployable projects (e.g. an API plus a
Worker Service, or multiple microservice-style API projects):
- Include per-project metrics in Counts & Metrics
- Report per-project coverage in the Testing section's "Coverage
  Breakdown:" field (e.g. `App [name]: [X]%, App [name2]: [Y]%`), never
  in Additional Metrics
- Include per-project evidence in Evidence sections
- Mention project names in descriptions where relevant
- Report cross-project consistency (TargetFramework, package versions) in Key Findings

VALIDATION CHECKLIST:
Before finalizing the report, verify:
✓ All 15 numbered sections are present, plus the two trailing
  unnumbered blocks (Appendix: Scoring Methodology, Report Metadata)
✓ All sections follow the required format
✓ All scores are integers with proper labels
✓ All evidence references actual files
✓ All recommendations are actionable
✓ Markdown formatting is used consistently
✓ Multi-project metrics are included if applicable
✓ Overall score calculation is correct
✓ Report uses proper Markdown headings and formatting

Format: Markdown-formatted report — ## headings, **bold** field
labels and pipe tables, exactly as assets/report-template.md renders
them. That template and references/report-format-enforcer.md are
authoritative on formatting; this file must not contradict them.
