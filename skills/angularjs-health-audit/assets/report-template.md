# AngularJS Project Health Audit Report

**Project:** [PROJECT_NAME]
**Date:** [AUDIT_DATE]
**Auditor:** AI-Assisted Analysis
**Framework:** AngularJS (Angular 1.x) [VERSION]

> **Exclusions:** Never recommend adding new languages/translations, CODEOWNERS/SECURITY.md files, or deployment-specific workflows.

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
| State Management | [XX]/100 | [Label] |
| Testing | [XX]/100 | [Label] |
| Code Quality (Linter & Warnings) | [XX]/100 | [Label] |
| Performance | [XX]/100 | [Label] |
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

**Description:** Analysis of AngularJS version, vendor dependencies, and tooling setup.

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

**Description:** Analysis of module organization, controllers/directives/components, and separation of concerns.

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

## 5. State Management

**Description:** Analysis of services/factories, `$http`/interceptors, and `$rootScope` data flow.

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

## 6. Testing

**Description:** Analysis of Karma/Jasmine setup, angular-mocks usage, and test coverage.

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

## 7. Code Quality (Linter & Warnings)

**Description:** Analysis of JSHint/ESLint, minification-safe DI, and IIFE/`'use strict'` module hygiene.

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

## 8. Performance

**Description:** Analysis of digest-cycle/`$watch` hygiene, binding discipline, `ng-repeat track by`, and template/DOM patterns.

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

**Description:** Analysis of README quality, module map, directive/component documentation, and setup instructions.

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

**Description:** Analysis of the Grunt/gulp/webpack build & asset pipeline and any CI workflow files found in the repository.

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

**Description:** [One-sentence description of the state of the harness]

**Score:** [XX]/100 ([Label])

**Maturity:** [sin harness | harness basico | harness solido | paved path]

### Harness Coverage
| Dimension | Status | Points |
|---|---|---|
| CLAUDE.md | [Status] | [XX]/13 |
| Rules | [Status] | [XX]/9 |
| Permissions | [Status] | [XX]/13 |
| Hooks | [Status] | [XX]/14 |
| Pre-push git hook | [Status] | [XX]/11 |
| Agents | [Status] | [XX]/11 |
| Commands / Skills | [Status] | [XX]/9 |
| Advanced orchestration | [Status] | [XX]/5 |
| Lifecycle | [Status] | [XX]/3 |
| Harness versioning | [Status] | [XX]/12 |
| **Total** | | **[XX]/100** |

### Key Findings
- [Finding 1]
- [Finding 2]
- [Continue as needed]

### Evidence
- [Real file path or configuration reference, never invented]
- [Continue as needed]

### Risks
- [Risk item 1]
- [Continue as needed]

### Actions to Raise the Score
1. **[+N]** [Concrete how-to for this repo]. -> dimension D, X/Y -> Y/Y.
2. [Continue, sorted by points recovered descending]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 12. Additional Metrics

- **AngularJS:** version [X.Y.Z]
- **Router:** [ngRoute/ui-router/None]
- **Dependency manager:** [Bower/npm/CDN-only/Mixed]
- **Build tool:** [Grunt/gulp/webpack/None]
- **Test runner:** [Karma/None]
- **Minification-safe DI:** [Consistent annotations/ngAnnotate/UNSAFE]

---

## 13. Risks & Opportunities

- [Risk/Opportunity 1]
- [Risk/Opportunity 2]
- [Risk/Opportunity 3]
- [Risk/Opportunity 4]
- [Risk/Opportunity 5 - include the AngularJS EOL / Bower-abandonment migration risk]

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

**State Management:**
- [File path or config reference]
- [Continue as needed]

**Testing:**
- [File path or config reference]
- [Continue as needed]

**Code Quality:**
- [File path or config reference]
- [Continue as needed]

**Performance:**
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
| State Management | 0.135 |
| Testing | 0.135 |
| Code Quality (Linter & Warnings) | 0.135 |
| Performance | 0.075 |
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
| Generated by | [Plugin Name] v[Plugin Version] |
| Skill | angularjs-health-audit |
| Date | [YYYY-MM-DD] |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
