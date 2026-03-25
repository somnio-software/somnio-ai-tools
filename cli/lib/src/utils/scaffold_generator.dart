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
      p.join(baseDir, 'assets', 'report-template.txt'),
      _reportTemplate(techTitle, displayName),
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
      p.join(baseDir, 'assets', 'report-template.txt'),
      _bestPracticesReportTemplate(techTitle, displayName),
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

TODO: Add your execution steps below. Reference rules using
the \`@rule_name\` syntax (without the .md extension).

### Step 1. Repository Inventory

Execute: \`@${tech}_repository_inventory\`

Purpose: Analyze repository structure and organization.

### Step 2. Configuration Analysis

TODO: Create \`${tech}_config_analysis.md\` reference and reference it
here.

### Step 3. Testing Analysis

TODO: Create \`${tech}_testing_analysis.md\` reference and reference it
here.

### Step 4. Code Quality

TODO: Create \`${tech}_code_quality.md\` reference and reference it here.

### Step 5. Security Analysis

TODO: Create \`${tech}_security_analysis.md\` reference and reference it
here.

### Step 6. Documentation Analysis

TODO: Create \`${tech}_documentation_analysis.md\` reference and
reference it here.

### Step 7. CI/CD Analysis

TODO: Create \`${tech}_cicd_analysis.md\` reference and reference it
here.

### Step 8. Generate Report

TODO: Create \`${tech}_report_generator.md\` reference and reference it
here.

Output: Save report to \`./reports/${tech}_audit.txt\`
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

  String _reportTemplate(String techTitle, String displayName) => '''
$displayName Report

1. Executive Summary

Description: Comprehensive analysis of [Project Name].

Overall Score: [Score]/100 ([Label])

Top Strengths:
- [Strength 1]
- [Strength 2]
- [Strength 3]

Top Risks:
- [Risk 1]
- [Risk 2]
- [Risk 3]

Priority Recommendations:
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

2. At-a-Glance Scorecard

- Tech Stack: [Score]/100 ([Label])
- Architecture: [Score]/100 ([Label])
- Testing: [Score]/100 ([Label])
- Code Quality: [Score]/100 ([Label])
- Security: [Score]/100 ([Label])
- Documentation: [Score]/100 ([Label])
- CI/CD: [Score]/100 ([Label])
- Overall: [Score]/100 ([Label])

TODO: Add detailed sections for each category.

3. Tech Stack

Description: [One-sentence description].
Score: [Score]/100 ([Label])

Key Findings:
- [Finding 1]
- [Finding 2]

Evidence:
- [Evidence 1]
- [Evidence 2]

Recommendations:
- [Recommendation 1]
- [Recommendation 2]
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

TODO: Add your execution steps below. Reference rules using
the \`@rule_name\` syntax (without the .md extension).

### Step 1. Testing Quality

TODO: Create \`testing_quality.md\` reference and reference it here.

### Step 2. Architecture Compliance

TODO: Create \`architecture_compliance.md\` reference and reference it
here.

### Step 3. Code Standards

TODO: Create \`code_standards.md\` reference and reference it here.

### Step 4. Generate Report

TODO: Create \`best_practices_generator.md\` reference and reference it
here.

Output: Save report to \`./reports/${tech}_best_practices.txt\`
''';

  String _bestPracticesReportTemplate(
    String techTitle,
    String displayName,
  ) =>
      '''
$displayName Report

1. Executive Summary

Description: Code quality analysis of [Project Name].

Total Violations: [Count]
Critical: [Count] | High: [Count] | Medium: [Count] | Low: [Count]

2. Violations by Category

TODO: Add category sections (Testing, Architecture, Code Standards).

3. Prioritized Action Plan

1. [Action 1] - [Severity]
2. [Action 2] - [Severity]
3. [Action 3] - [Severity]
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
