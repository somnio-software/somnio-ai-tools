import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import 'command_helpers.dart';

/// Generates the folder structure and template files for a new
/// technology skill bundle.
class ScaffoldGenerator {
  ScaffoldGenerator({required this.repoRoot, required Logger logger})
      : _logger = logger;

  final String repoRoot;
  final Logger _logger;

  /// Scaffolds a health audit bundle for the given technology.
  Future<void> generateHealthAudit({
    required String tech,
    required String displayName,
  }) async {
    final techTitle = CommandHelpers.titleCase(tech);
    final baseDir = p.join(repoRoot, 'skills', '$tech-health-audit');

    // Create directories
    await _createDir(p.join(baseDir, 'references'));
    await _createDir(p.join(baseDir, 'assets'));

    // SKILL.md plan file
    await _writeFile(
      p.join(baseDir, 'SKILL.md'),
      _healthPlanTemplate(tech, techTitle, displayName),
    );

    // Sample reference file
    await _writeFile(
      p.join(baseDir, 'references', '${tech}_repository_inventory.md'),
      _sampleReferenceTemplate(tech, techTitle),
    );

    // Report template
    await _writeFile(
      p.join(baseDir, 'assets', 'report-template.md'),
      _reportTemplate(tech, techTitle, displayName),
    );
  }

  /// Scaffolds a best practices bundle for the given technology.
  Future<void> generateBestPractices({
    required String tech,
    required String displayName,
  }) async {
    final techTitle = CommandHelpers.titleCase(tech);
    final baseDir = p.join(repoRoot, 'skills', '$tech-best-practices');

    // Create directories
    await _createDir(p.join(baseDir, 'references'));
    await _createDir(p.join(baseDir, 'assets'));

    // SKILL.md plan file
    await _writeFile(
      p.join(baseDir, 'SKILL.md'),
      _bestPracticesPlanTemplate(tech, techTitle, displayName),
    );

    // Report template
    await _writeFile(
      p.join(baseDir, 'assets', 'report-template.md'),
      _bestPracticesReportTemplate(tech, techTitle, displayName),
    );
  }

  /// Generates a README.md for the skills/ directory (if not present).
  Future<void> generateReadme(String tech) async {
    final techTitle = CommandHelpers.titleCase(tech);
    final readmePath = p.join(repoRoot, 'skills', 'README.md');
    // Only create if not already present (shared by all skills)
    if (!File(readmePath).existsSync()) {
      await _writeFile(readmePath, _readmeTemplate(tech, techTitle));
    }
  }

  // ---------------------------------------------------------------------------
  // Templates
  // ---------------------------------------------------------------------------

  String _readmeTemplate(String tech, String techTitle) => '''
# $techTitle Project Analysis

Analysis tools and rules for $techTitle projects.

## Overview

This directory contains skill bundles for automated $techTitle project
analysis:

- **Health Audit**: Comprehensive project infrastructure analysis
- **Best Practices Check**: Micro-level code quality validation

## Usage

Install via Somnio CLI:

```bash
somnio setup
```

Then use in your $techTitle project:

- `/$tech-health-audit` - Health audit
- `/$tech-best-practices` - Best practices check

## Structure

- `$tech-health-audit/` - Health audit skill bundle
- `$tech-best-practices/` - Best practices skill bundle

## Contributing

See the main repository README for contribution guidelines.
''';

  String _healthPlanTemplate(
    String tech,
    String techTitle,
    String displayName,
  ) =>
      '''
---
name: $tech-health-audit
description: $displayName
---

# $displayName - Modular Execution Plan

This plan executes the $displayName through sequential,
modular references. Each step uses a specific reference that can be
executed independently and produces output that feeds into the final
report.

## Agent Role & Context

**Role**: $techTitle Project Health Auditor

## Your Core Expertise

You are a master at:
- **Comprehensive Project Auditing**: Evaluating all aspects of $techTitle
  project health (tech stack, architecture, testing, security, CI/CD,
  documentation)
- **Evidence-Based Analysis**: Analyzing repository evidence objectively
  without inventing data or making assumptions
- **Modular Rule Execution**: Coordinating sequential execution of
  specialized analysis references
- **Score Calculation**: Calculating section scores (0-100) and weighted
  overall scores accurately
- **Technical Risk Assessment**: Identifying technical risks, technical
  debt, and project maturity indicators
- **Report Integration**: Synthesizing findings from multiple analysis
  references into unified reports

**Responsibilities**:
- Execute technical audits following the plan steps sequentially
- Report findings objectively based on evidence found in the repository
- Stop execution immediately if MANDATORY steps fail
- Never invent or assume information - report "Unknown" if evidence is
  missing
- Focus exclusively on technical aspects

**Expected Behavior**:
- **Professional and Evidence-Based**: All findings must be supported
  by actual repository evidence
- **Objective Reporting**: Distinguish clearly between critical issues,
  recommendations, and neutral items
- **Explicit Documentation**: Document what was checked, what was found,
  and what is missing
- **Error Handling**: Stop execution on MANDATORY step failures;
  continue with warnings for non-critical issues
- **No Assumptions**: If something cannot be proven by repository
  evidence, write "Unknown" and specify what would prove it

## Plan Steps

TODO: Add your execution steps below. Each step is a numbered line naming its
reference file, e.g.
\`1. Read and follow the instructions in \`references/testing-quality.md\`\`.

Reference files use hyphens and carry no tech prefix: the runner takes the rule
name verbatim from \`references/<rule-name>.md\`, and
\`cli/lib/src/runner/rule_names.dart\` string-matches \`report-generator\`
exactly to dispatch report generation. Naming that file
\`report_generator.md\` disables the report with no error.

### Step 1. Repository Inventory

Execute: \`references/repository-inventory.md\`

Purpose: Analyze repository structure and organization.

### Step 2. Configuration Analysis

TODO: Create \`config-analysis.md\` reference and reference it
here.

### Step 3. Testing Analysis

TODO: Create \`testing-analysis.md\` reference and reference it
here.

### Step 4. Code Quality

TODO: Create \`code-quality.md\` reference and reference it here.

### Step 5. Security Analysis

TODO: Create \`security-analysis.md\` reference and reference it
here.

### Step 6. Documentation Analysis

TODO: Create \`documentation-analysis.md\` reference and
reference it here.

### Step 7. CI/CD Analysis

TODO: Create \`cicd-analysis.md\` reference and reference it
here.

### Step 8. Generate Report

TODO: Create \`report-generator.md\` reference and reference it
here. Keep that exact filename.

Output: Save report to
\`./reports/<YYYY-MM-DD>-<project-slug>-${tech}-health-audit.md\`
(date of the run, then the project directory name slugified to kebab-case)
''';

  String _sampleReferenceTemplate(String tech, String techTitle) => '''
# $techTitle Repository Inventory

> Analyze $techTitle repository structure and organization patterns.

---

Goal: Identify the repository structure, modules, and code organization
patterns for a $techTitle project.

Instructions:

You are an elite repository structure analyst with deep expertise
in $techTitle project organization patterns.

## Your Core Expertise

You are a master at:
- **Repository Type Detection**: Identifying project structures
  (monorepo, single-app, micro-services, etc.)
- **Package Analysis**: Analyzing module dependencies and
  relationships
- **Feature Organization**: Evaluating code organization patterns
  and separation of concerns

## Task

Analyze the $techTitle repository structure:

1. **Repository Type**
   - Identify project structure (monorepo, single-app, etc.)
   - Document directory organization

2. **Module Analysis**
   - List all modules/packages
   - Analyze dependencies between modules

3. **Code Organization**
   - Evaluate feature folder structure
   - Assess separation of concerns

## Output Format

Provide findings in structured sections:

### Repository Structure
- Type: [structure type]
- Organization: [description]

### Modules/Packages
- List all modules with brief descriptions

### Code Organization
- Evaluation of organization patterns
- Recommendations for improvements

TODO: Customize this reference for $techTitle-specific patterns
and conventions.
''';

  /// Canonical 15-numbered-section report skeleton (see
  /// `docs/report-template-canonical.md`). A freshly scaffolded skill has
  /// no stack yet, so it has neither a real slot-B section nor a
  /// Performance section — it uses the "both slots, no Performance" (Group
  /// A) arrangement with generic `[Domain-Specific Section]` placeholders
  /// for slot A/B that the skill author renames (or, for a Group-B-shaped
  /// stack, replaces with a real slot A and a Performance section instead
  /// — see the canonical doc).
  String _reportTemplate(String tech, String techTitle, String displayName) =>
      '''
# $displayName Report

**Project:** [PROJECT_NAME]
**Date:** [AUDIT_DATE]
**Auditor:** AI-Assisted Analysis
**Framework:** [$techTitle — describe the stack/runtime this audit targets]

> **Exclusions:** [Describe what this audit should never recommend, e.g. unrelated language/tooling changes or out-of-scope files].

---

## 1. Executive Summary

**Description:** Comprehensive analysis of [Project Name] $techTitle [describe project shape, e.g. single app/monorepo].

**Overall Score:** [Score]/100 ([Label])

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
| Tech Stack | [Score]/100 | [Label] |
| Architecture | [Score]/100 | [Label] |
| [Domain-Specific Section] | [Score]/100 | [Label] |
| [Additional Domain-Specific Section] | [Score]/100 | [Label] |
| Testing | [Score]/100 | [Label] |
| Code Quality (Linter & Warnings) | [Score]/100 | [Label] |
| Documentation & Operations | [Score]/100 | [Label] |
| CI/CD (Configs Found in Repo) | [Score]/100 | [Label] |
| AI Harness & Adoption | [Score]/100 | [Label] |
| **Overall** | **[Score]/100** | **[Label]** |

> **Test Coverage:** [X]% (lines) — full breakdown in the Testing section.
> Fallback when no coverage tool is detected: `Not measured (no coverage tool detected/configured)`

> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)

[One-sentence interpretation of the Overall Score.]

---

## 3. Tech Stack

**Description:** [One-sentence description of the tech stack analysis].

**Score:** [Score]/100 ([Label])

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

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 4. Architecture

**Description:** [One-sentence description of the architecture analysis].

**Score:** [Score]/100 ([Label])

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

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 5. [Domain-Specific Section]

> TODO(author): rename this section (and its rows in the Scorecard above and the Scoring Methodology appendix below) to whatever your stack's "slot A" category is — e.g. "State Management" or "API Design". See `docs/report-template-canonical.md`.

**Description:** [One-sentence description of the analysis].

**Score:** [Score]/100 ([Label])

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

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 6. [Additional Domain-Specific Section]

> TODO(author): rename this section (and its rows in the Scorecard above and the Scoring Methodology appendix below) to whatever your stack's "slot B" category is — e.g. "Data Layer" or "Repositories & Data Layer". If your stack has no natural slot B, delete this section (and its Scorecard/appendix rows) and add a "Performance" section instead (weight 0.075), right after Code Quality — see `docs/report-template-canonical.md`.

**Description:** [One-sentence description of the analysis].

**Score:** [Score]/100 ([Label])

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

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 7. Testing

**Description:** [One-sentence description of the testing analysis].

**Score:** [Score]/100 ([Label])

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
- [Continue as needed]

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
- Test count: [Value]
- Test framework: [Value]
- [Do NOT restate the coverage percentage here — it lives only in the fields above]

---

## 8. Code Quality (Linter & Warnings)

**Description:** [One-sentence description of the code quality analysis].

**Score:** [Score]/100 ([Label])

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

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 9. Documentation & Operations

**Description:** [One-sentence description of the documentation and operations analysis].

**Score:** [Score]/100 ([Label])

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

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 10. CI/CD (Configs Found in Repo)

**Description:** [One-sentence description of the CI/CD analysis].

**Score:** [Score]/100 ([Label])

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

### Recommendations
- [Recommendation 1]
- [Continue as needed]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 11. AI Harness & Adoption

**Description:** [One-sentence description of the harness analysis].

**Score:** [Score]/100 ([Label])

**Maturity:** [sin harness | harness básico | harness sólido | paved path]

### Harness Coverage
| Dimension | Status | Points |
|---|---|---|
| CLAUDE.md | [Status] | [Points]/13 |
| Rules | [Status] | [Points]/9 |
| Permissions | [Status] | [Points]/13 |
| Hooks | [Status] | [Points]/14 |
| Pre-push git hook | [Status] | [Points]/11 |
| Agents | [Status] | [Points]/11 |
| Commands / Skills | [Status] | [Points]/9 |
| Advanced orchestration | [Status] | [Points]/5 |
| Lifecycle | [Status] | [Points]/3 |
| Harness versioning | [Status] | [Points]/12 |
| **Total** | | **[Score]/100** |

### Key Findings
- [Finding 1]
- [Continue as needed]

### Evidence
- [Real file path only, never invented]
- [Continue as needed]

### Risks
- [Risk item 1]
- [Continue as needed]

### Actions to Raise the Score
1. **[+N] [Action title].** [Concrete how-to naming the file/key to create or edit]. → dimension D, X/Y → Y/Y.
2. [Continue as needed, sorted by points recovered descending]

### Counts & Metrics
- [Metric name]: [Value]
- [Continue as needed]

---

## 12. Additional Metrics

- **[Metric name]:** [Value]
- **[Metric name]:** [Value]
- [Continue as needed — stack-variable field list]

---

## 13. Risks & Opportunities

- [Risk/Opportunity 1]
- [Risk/Opportunity 2]
- [Risk/Opportunity 3]
- [Continue as needed]

---

## 14. Recommendations

1. **[Priority Level]:** [Recommendation 1]
2. **[Priority Level]:** [Recommendation 2]
3. **[Priority Level]:** [Recommendation 3]
4. [Continue as needed]

---

## 15. Appendix: Evidence Index

**Tech Stack:**
- [File path or config reference]
- [Continue as needed]

**Architecture:**
- [File path or config reference]
- [Continue as needed]

**[Domain-Specific Section]:**
- [File path or config reference]
- [Continue as needed]

**[Additional Domain-Specific Section]:**
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
| [Domain-Specific Section] | 0.18 |
| [Additional Domain-Specific Section] | 0.10 |
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
| Generated by | [Plugin Name] v[Plugin Version] |
| Skill | $tech-health-audit |
| Date | [YYYY-MM-DD] |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
''';

  String _bestPracticesPlanTemplate(
    String tech,
    String techTitle,
    String displayName,
  ) =>
      '''
---
name: $tech-best-practices
description: $displayName
---

# $displayName - Modular Execution Plan

This plan executes the $displayName through sequential,
modular references. Each reference validates code against $techTitle
best practices and produces a violations report.

## Agent Role & Context

**Role**: $techTitle Code Quality Auditor

## Your Core Expertise

You are a master at:
- **Code Quality Analysis**: Evaluating $techTitle code against
  established best practices and standards
- **Pattern Recognition**: Identifying anti-patterns and violations
  across codebases
- **Actionable Reporting**: Producing clear, prioritized violation
  reports with specific remediation steps

**Responsibilities**:
- Execute code quality checks following the plan steps sequentially
- Report violations objectively with evidence
- Prioritize issues by severity (Critical, High, Medium, Low)

## Plan Steps

TODO: Add your execution steps below. Each step is a numbered line naming its
reference file, e.g.
\`1. Read and follow the instructions in \`references/testing-quality.md\`\`.

Reference files use hyphens, never underscores: the runner takes the rule name
verbatim from \`references/<rule-name>.md\`, and
\`cli/lib/src/runner/rule_names.dart\` string-matches
\`best-practices-generator\` exactly to dispatch report generation. Naming that
file \`best_practices_generator.md\` disables the report with no error.

### Step 1. Testing Quality

TODO: Create \`testing-quality.md\` reference and reference it here.

### Step 2. Architecture Compliance

TODO: Create \`architecture-compliance.md\` reference and reference it
here.

### Step 3. Code Standards

TODO: Create \`code-standards.md\` reference and reference it here.

### Step 4. Generate Report

TODO: Create \`best-practices-generator.md\` reference and reference it
here. Keep that exact filename.

Output: Save report to
\`./reports/<YYYY-MM-DD>-<project-slug>-${tech}-best-practices.md\`
(date of the run, then the project directory name slugified to kebab-case)
''';

  /// A freshly scaffolded best-practices template must already conform to the
  /// shared skeleton documented in `docs/best-practices-template-canonical.md`
  /// and enforced by `cli/test/src/content/best_practices_template_drift_test.dart`
  /// — otherwise a new skill is born divergent and nothing catches it (that
  /// test lists the known skills by name). The three scored sections below
  /// match the three analysis steps `_bestPracticesPlanTemplate` scaffolds.
  String _bestPracticesReportTemplate(
    String tech,
    String techTitle,
    String displayName,
  ) =>
      '''
# $displayName Report

**Project:** [PROJECT_NAME]
**Date:** [AUDIT_DATE]
**Auditor:** AI-Assisted Analysis

---

## 1. Executive Summary

**Overall Score:** [XX]/100 ([Label])

**Description:**
[One paragraph summary of the codebase quality and key findings]

**Top Strengths:**
- [Strength 1]
- [Strength 2]

**Critical Issues:**
- [Critical Issue 1]
- [Critical Issue 2]

**Immediate Action Items:**
1. [Most urgent action]
2. [Second priority action]

---

## 2. Score Breakdown

> TODO(author): one row per analysis step in this skill's `references/`, in the
> order the steps run, then the `**Weighted Overall**` row. Never add a Weight
> column here — weights live only in the Scoring Methodology appendix below and
> in `references/best-practices-generator.md`.

| Section | Score | Label |
|---------|-------|-------|
| Testing Quality | [XX]/100 | [Label] |
| Architecture Compliance | [XX]/100 | [Label] |
| Code Standards | [XX]/100 | [Label] |
| **Weighted Overall** | **[XX]/100** | **[Label]** |

> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)

---

## 3. Testing Quality

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of testing quality findings for $techTitle]

### Key Findings
- [Finding 1]
- [Finding 2]

### Violations
- `[path/to/file:XX]` — [Issue description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]

---

## 4. Architecture Compliance

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of architecture compliance findings]

### Key Findings
- [Finding 1]
- [Finding 2]

### Violations
- `[path/to/file:XX]` — [Issue description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]

---

## 5. Code Standards

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of code standards findings]

### Key Findings
- [Finding 1]
- [Finding 2]

### Violations
- `[path/to/file:XX]` — [Issue description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]

---

## 6. Prioritized Recommendations

> TODO(author): keep this heading name. Renumber this and the Evidence Index if
> you add or remove scored sections above.

### 🔴 Critical (Must Fix Immediately)
1. [Critical recommendation with file reference]

### 🟠 High Priority
1. [High priority recommendation]

### 🟡 Medium Priority
1. [Medium priority recommendation]

### 🟢 Low Priority (Nice to Have)
1. [Low priority recommendation]

---

## 7. Evidence Index

> TODO(author): group the analysed files by category, one group per analysis step.

**Test Files Analyzed:**
- `[path/to/test file]`

**Source Files Analyzed:**
- `[path/to/source file]`

---

## Appendix: Scoring Methodology

**Weighted formula** (weights sum to 100% — the authoritative source is this skill's
`references/best-practices-generator.md`; this table is a read-only summary of what was applied):

> TODO(author): choose weights that suit $techTitle, one row per Score Breakdown
> row above and in the same order. They MUST sum to 100 and MUST match the
> `COMPUTE OVERALL SCORE` block in `references/best-practices-generator.md`.
> These placeholders are equal thirds — replace them with a considered split.
> Never copy another skill's weights: each skill keeps its own.

| Section | Weight |
|---------|--------|
| Testing Quality | 34% |
| Architecture Compliance | 33% |
| Code Standards | 33% |
| **Total** | **100%** |

**Rounding rule:** Standard mathematical rounding (0.5 rounds up). No subjective adjustment.

**Scoring bands:** Strong (85–100) · Fair (70–84) · Weak (0–69)

---

## Report Metadata

| Field | Value |
|-------|-------|
| Generated by | [Plugin Name] v[Plugin Version] |
| Skill | $tech-best-practices |
| Date | [YYYY-MM-DD] |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
''';

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _createDir(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
      _logger.detail('  Created: ${p.relative(path, from: repoRoot)}');
    }
  }

  Future<void> _writeFile(String path, String content) async {
    final file = File(path);
    final parent = file.parent;
    if (!parent.existsSync()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(content);
    _logger.detail('  Created: ${p.relative(path, from: repoRoot)}');
  }
}
