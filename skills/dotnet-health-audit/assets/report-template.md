# .NET Project Health Audit Report

**Project:** [PROJECT_NAME]
**Date:** [AUDIT_DATE]
**Auditor:** AI-Assisted Analysis
**Framework:** [.NET/ASP.NET Core — Web API/Blazor/Worker Service/Class Library]

> **Exclusions:** Never recommend CODEOWNERS/SECURITY.md files or deployment-specific workflows.

---

## 1. Executive Summary

**Description:** [Comprehensive analysis description]

**Overall Score:** [XX]/100 ([Label])

**Top Strengths:**
- [Strength 1]
- [Strength 2]
- [Strength 3]

**Top Risks:**
- [Risk 1]
- [Risk 2]
- [Risk 3]

**Priority Recommendations:**
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 2. At-a-Glance Scorecard

| Section | Score | Label |
|---------|-------|-------|
| Tech Stack | [XX]/100 | [Label] |
| Architecture | [XX]/100 | [Label] |
| API Design | [XX]/100 | [Label] |
| Data Layer | [XX]/100 | [Label] |
| Testing | [XX]/100 | [Label] |
| Code Quality (Linter & Warnings) | [XX]/100 | [Label] |
| Documentation & Operations | [XX]/100 | [Label] |
| CI/CD (Configs Found in Repo) | [XX]/100 | [Label] |
| AI Harness & Adoption | [XX]/100 | [Label] |
| **Overall** | **[XX]/100** | **[Label]** |

> **Test Coverage:** [X]% (lines) — full breakdown in the Testing section.
> Fallback when no coverage tool is detected: `Not measured (no coverage tool detected/configured)`

> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)

[One-sentence interpretation of the Overall Score.]

---

## 3. Tech Stack

**Description:** Analysis of .NET SDK version, TargetFramework(s), official Microsoft support lifecycle status, NuGet dependency vulnerabilities/currency, and tooling setup.

**Score:** [XX]/100 ([Label])

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Evidence
- [File path or configuration reference]
- [Specific evidence item]
- [Continue as needed]

### Risks
- [Risk item 1]
- [Continue as needed]

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 4. Architecture

**Description:** [One-sentence description of the solution's architecture pattern (Vertical Slice/Onion/Clean Architecture/N-Layer), SOLID compliance, and real cyclomatic complexity].

**Score:** [XX]/100 ([Label])

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Evidence
- [File path or configuration reference]
- [Continue as needed]

### Risks
- [Risk item 1]
- [Continue as needed]

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 5. API Design

**Description:** [One-sentence description of the API design analysis].

**Score:** [XX]/100 ([Label])

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Evidence
- [File path or configuration reference]
- [Continue as needed]

### Risks
- [Risk item 1]
- [Continue as needed]

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 6. Data Layer

**Description:** [One-sentence description of the data layer analysis].

**Score:** [XX]/100 ([Label])

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Evidence
- [File path or configuration reference]
- [Continue as needed]

### Risks
- [Risk item 1]
- [Continue as needed]

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 7. Testing

**Description:** [One-sentence description of the testing analysis].

**Score:** [XX]/100 ([Label])

**Code Coverage:** [X]% (lines)
> Multi-dimension stacks (JS/TS): `[X]% lines / [Y]% branches / [Z]% functions`
> Monorepo / multi-app: `App [name]: [X]%, App [name2]: [Y]%`
> No coverage tool: `Not measured (no coverage tool detected/configured)`

**Coverage Breakdown:**
- `[module/package/app]`: [X]% (lines[, [Y]% branches, [Z]% functions — where extracted])
- [Continue per module/package/app]
- [Single-package projects: "N/A — single package, see Code Coverage above"]
- [No data: "(no coverage data — artifact missing or no coverage tool configured)"]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Evidence
- [File path or configuration reference]
- [Continue as needed]

### Risks
- [Risk item 1]
- [Continue as needed]

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 8. Code Quality (Linter & Warnings)

**Description:** [One-sentence description of the code quality analysis — Roslyn analyzers, `TreatWarningsAsErrors`, `.editorconfig` severities, nullable compliance, and sync-over-async patterns].

**Score:** [XX]/100 ([Label])

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Evidence
- [File path or configuration reference]
- [Continue as needed]

### Risks
- [Risk item 1]
- [Continue as needed]

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 9. Documentation & Operations

**Description:** [One-sentence description of the documentation and operations analysis].

**Score:** [XX]/100 ([Label])

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Evidence
- [File path or configuration reference]
- [Continue as needed]

### Risks
- [Risk item 1]
- [Continue as needed]

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 10. CI/CD (Configs Found in Repo)

**Description:** [One-sentence description of the CI/CD analysis].

**Score:** [XX]/100 ([Label])

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Evidence
- [File path or configuration reference]
- [Continue as needed]

### Risks
- [Risk item 1]
- [Continue as needed]

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 11. AI Harness & Adoption

**Description:** [One-sentence description of the AI harness state].

**Score:** [XX]/100 ([Label])

**Maturity:** [sin harness | harness básico | harness sólido | paved path]

### Harness Coverage
| Dimension | Status | Points |
|---|---|---|
| CLAUDE.md | [Status] | [Score]/13 |
| Rules | [Status] | [Score]/9 |
| Permissions | [Status] | [Score]/13 |
| Hooks | [Status] | [Score]/14 |
| Pre-push git hook | [Status] | [Score]/11 |
| Agents | [Status] | [Score]/11 |
| Commands / Skills | [Status] | [Score]/9 |
| Advanced orchestration | [Status] | [Score]/5 |
| Lifecycle | [Status] | [Score]/3 |
| Harness versioning | [Status] | [Score]/12 |
| **Total** | | **[Score]/100** |

### Key Findings
- [Finding 1]
- [Finding 2]
- [Continue as needed]

### Evidence
- [File path or configuration reference]
- [Continue as needed]

### Risks
- [Risk item 1]
- [Continue as needed]

### Actions to Raise the Score
1. **[+N] [Action 1].** [Concrete how-to] → dimension D, X/Y → Y/Y.
2. **[+N] [Action 2].** [Concrete how-to] → dimension D, X/Y → Y/Y.
- [Continue as needed, sorted by points recovered descending]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 12. Additional Metrics

- **.NET SDK version:** [Version] (global.json pin: [Version or "none"])
- **TargetFramework(s):** [net8.0/etc, note inconsistencies]
- **.NET support status:** [In support (LTS/STS) / Out of support since [month year] / Supported via OS lifecycle]
- **Recommended LTS upgrade target:** [e.g. net8.0]
- **Project type:** [Web API/Blazor/Worker Service/Class Library/Mixed]
- **Architecture pattern:** [Vertical Slice/Onion/Clean Architecture/N-Layer/Flat/Mixed]
- **API style:** [Controllers/Minimal APIs/Hybrid]
- **Solution project count:** [Count]
- **Total controllers or endpoint groups count:** [Count]
- **Total services count:** [Count]
- **Total DTOs count:** [Count]
- **Database ORM:** [Entity Framework Core/Dapper/none]
- **Test framework:** [xUnit/NUnit/MSTest/none]
- **API versioning strategy:** [URI/Header/None]
- **OpenAPI/Swagger enabled:** [Yes/No]
- **Central Package Management:** [Yes/No]
- **Nullable reference types:** [Enabled/Disabled/Partial]
- **Authentication method:** [JWT/Cookie/Identity/none]
- **Vulnerable packages:** [Count] (Critical: N, High: N, Moderate: N, Low: N)
- **Outdated packages (3+ major versions behind):** [Count]
- **SOLID violations:** [Count] (SRP: N, OCP: N, LSP: N, ISP: N, DIP: N)
- **Cyclomatic complexity hits:** [CA1502 count] / Class coupling hits: [CA1506 count]

---

## 13. Risks & Opportunities

- [Risk/Opportunity 1]
- [Risk/Opportunity 2]
- [Risk/Opportunity 3]
- [Risk/Opportunity 4]
- [Risk/Opportunity 5]

---

## 14. Recommendations

1. **[Priority Level]:** [Recommendation 1]
2. **[Priority Level]:** [Recommendation 2]
3. **[Priority Level]:** [Recommendation 3]
4. **[Priority Level]:** [Recommendation 4]
5. **[Priority Level]:** [Recommendation 5]
6. **[Priority Level]:** [Recommendation 6]
7. **[Priority Level]:** [Recommendation 7]
8. **[Priority Level]:** [Recommendation 8]
9. **[Priority Level]:** [Recommendation 9]
10. **[Priority Level]:** [Recommendation 10]

---

## 15. Appendix: Evidence Index

**Tech Stack:**
- [File path or config reference]
- [Continue as needed]

**Architecture:**
- [File path or config reference]
- [Continue as needed]

**API Design:**
- [File path or config reference]
- [Continue as needed]

**Data Layer:**
- [File path or config reference]
- [Continue as needed]

**Testing:**
- [File path or config reference]
- [Continue as needed]

**Code Quality:**
- [File path or config reference]
- [Continue as needed]

**Documentation:**
- [File path or config reference]
- [Continue as needed]

**CI/CD:**
- [File path or config reference]
- [Continue as needed]

**AI Harness & Adoption:**
- [File path or config reference]
- [Continue as needed]

---

## Appendix: Scoring Methodology

**Weighted formula** (weights sum to 1.00 — the authoritative source is this skill's
`references/report-generator.md`; this table is a read-only summary of what was applied):

| Section | Weight |
|---------|--------|
| Tech Stack | 0.18 |
| Architecture | 0.18 |
| API Design | 0.18 |
| Data Layer | 0.10 |
| Testing | 0.10 |
| Code Quality (Linter & Warnings) | 0.10 |
| Documentation & Operations | 0.03 |
| CI/CD (Configs Found in Repo) | 0.03 |
| AI Harness & Adoption | 0.10 |
| **Total** | **1.00** |

**Rounding rule:** Standard mathematical rounding (0.5 rounds up). No subjective adjustment.

**Scoring bands:** Strong (85–100) · Fair (70–84) · Weak (0–69)

---

## Report Metadata

| Field | Value |
|-------|-------|
| Generated by | Somnio CLI v3.2.8 |
| Skill | dotnet-health-audit |
| Date | [YYYY-MM-DD] |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
