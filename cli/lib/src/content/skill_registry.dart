import 'skill_bundle.dart';
import 'workflow_skill.dart';

/// Static registry of all available skill bundles.
///
/// Each bundle maps to a set of source files in `skills/` and defines
/// how they are installed into each agent.
class SkillRegistry {
  SkillRegistry._();

  /// All registered skill bundles.
  static const List<SkillBundle> skills = [
    SkillBundle(
      id: 'flutter_health',
      name: 'flutter-health-audit',
      aliases: ['somnio-fh', 'fh'],
      displayName: 'Flutter Project Health Audit',
      description:
          'Execute a comprehensive Flutter Project Health Audit. '
          'Analyzes tech stack, architecture, state management, testing, '
          'code quality, CI/CD, and documentation. Produces a '
          'Google Docs-ready report with section scores and weighted '
          'overall score.',
      planRelativePath:
          'skills/flutter-health-audit/SKILL.md',
      rulesDirectory:
          'skills/flutter-health-audit/references',
      templatePath:
          'skills/flutter-health-audit/assets/report-template.txt',
    ),
    SkillBundle(
      id: 'flutter_plan',
      name: 'flutter-best-practices',
      aliases: ['somnio-fp', 'fp'],
      displayName: 'Flutter Best Practices Check',
      description:
          'Execute a micro-level Flutter code quality audit. '
          'Validates code against live GitHub standards for testing, '
          'architecture, and code implementation. Produces a detailed '
          'violations report with prioritized action plan.',
      planRelativePath:
          'skills/flutter-best-practices/SKILL.md',
      rulesDirectory:
          'skills/flutter-best-practices/references',
      templatePath:
          'skills/flutter-best-practices/assets/report-template.txt',
    ),
    SkillBundle(
      id: 'nestjs_health',
      name: 'nestjs-health-audit',
      aliases: ['somnio-nh', 'nh'],
      displayName: 'NestJS Project Health Audit',
      description:
          'Execute a comprehensive NestJS Project Health Audit. '
          'Analyzes tech stack, architecture, API design, data layer, '
          'testing, code quality, CI/CD, and documentation. '
          'Produces a Google Docs-ready report with section scores and '
          'weighted overall score.',
      planRelativePath:
          'skills/nestjs-health-audit/SKILL.md',
      rulesDirectory:
          'skills/nestjs-health-audit/references',
      templatePath:
          'skills/nestjs-health-audit/assets/report-template.txt',
    ),
    SkillBundle(
      id: 'nestjs_plan',
      name: 'nestjs-best-practices',
      aliases: ['somnio-np', 'np'],
      displayName: 'NestJS Best Practices Check',
      description:
          'Execute a micro-level NestJS code quality audit. '
          'Validates code against live GitHub standards for testing, '
          'architecture, DTO validation, error handling, and code '
          'implementation. Produces a detailed violations report with '
          'prioritized action plan.',
      planRelativePath:
          'skills/nestjs-best-practices/SKILL.md',
      rulesDirectory:
          'skills/nestjs-best-practices/references',
      templatePath:
          'skills/nestjs-best-practices/assets/report-template.txt',
    ),
    SkillBundle(
      id: 'react_health',
      name: 'react-health-audit',
      aliases: ['somnio-rh', 'rh'],
      displayName: 'React Project Health Audit',
      description:
          'Execute a comprehensive React Project Health Audit. '
          'Analyzes tech stack, architecture, state management, testing, '
          'code quality, CI/CD, and documentation. Produces a '
          'Google Docs-ready report with section scores and weighted '
          'overall score.',
      planRelativePath:
          'skills/react-health-audit/SKILL.md',
      rulesDirectory:
          'skills/react-health-audit/references',
      templatePath:
          'skills/react-health-audit/assets/report-template.txt',
    ),
    SkillBundle(
      id: 'react_plan',
      name: 'react-best-practices',
      aliases: ['somnio-rp', 'rp'],
      displayName: 'React Best Practices Check',
      description:
          'Execute a micro-level React code quality audit. '
          'Validates code against live GitHub standards for testing, '
          'component architecture, hooks patterns, state management, '
          'and TypeScript. Produces a detailed violations report with '
          'prioritized action plan.',
      planRelativePath:
          'skills/react-best-practices/SKILL.md',
      rulesDirectory:
          'skills/react-best-practices/references',
      templatePath:
          'skills/react-best-practices/assets/report-template.txt',
    ),
    SkillBundle(
      id: 'security_audit',
      name: 'security-audit',
      aliases: ['somnio-sa', 'sa'],
      displayName: 'Security Audit',
      description:
          'Execute a comprehensive, framework-agnostic Security Audit. '
          'Detects project type at runtime and adapts security checks '
          'accordingly. Analyzes sensitive files, source code secrets, '
          'dependency vulnerabilities, and optionally uses Gemini AI '
          'for advanced analysis. Produces a severity-classified report.',
      planRelativePath:
          'skills/security-audit/SKILL.md',
      rulesDirectory:
          'skills/security-audit/references',
      templatePath:
          'skills/security-audit/assets/report-template.txt',
    ),
  ];

  /// Workflow skill bundles (standalone markdown, no YAML rules).
  ///
  /// Installed to all agents as `/workflow-builder`.
  static const List<WorkflowSkill> workflowSkills = [
    WorkflowSkill(
      id: 'workflow_builder',
      name: 'workflow-builder',
      displayName: 'Workflow Builder',
      description:
          'Create and execute custom, repeatable workflows with multiple '
          'steps that can each use different AI models and run in '
          'parallel waves.',
      planRelativePath:
          'skills/workflow-builder/SKILL.md',
    ),
  ];

  /// Find a skill bundle by its ID.
  static SkillBundle? findById(String id) {
    for (final skill in skills) {
      if (skill.id == id) return skill;
    }
    return null;
  }

  /// Find a skill bundle by its name or alias.
  static SkillBundle? findByName(String name) {
    for (final skill in skills) {
      if (skill.name == name) return skill;
      if (skill.aliases.contains(name)) return skill;
    }
    return null;
  }

  /// Returns unique technology display names derived from registered bundles.
  ///
  /// Driven entirely by [SkillBundle.techDisplayName], so adding a new
  /// tech via `somnio add` automatically surfaces it.
  static List<String> get technologies {
    final techs = <String>{};
    for (final skill in skills) {
      techs.add(skill.techDisplayName);
    }
    return techs.toList()..sort();
  }

  /// Returns bundles matching the given technology display names.
  static List<SkillBundle> byTechnologies(List<String> techNames) {
    return skills
        .where((s) => techNames.contains(s.techDisplayName))
        .toList();
  }
}
