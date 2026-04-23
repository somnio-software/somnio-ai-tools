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
      workflowPath:
          'skills/flutter-health-audit/.agent/workflows/flutter_health_audit.md',
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
      workflowPath:
          'skills/flutter-best-practices/.agent/workflows/flutter_best_practices.md',
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
      workflowPath:
          'skills/nestjs-health-audit/.agent/workflows/nestjs_health_audit.md',
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
      workflowPath:
          'skills/nestjs-best-practices/.agent/workflows/nestjs_best_practices.md',
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
      workflowPath:
          'skills/react-health-audit/.agent/workflows/react_health_audit.md',
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
      workflowPath:
          'skills/react-best-practices/.agent/workflows/react_best_practices.md',
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
      workflowPath:
          'skills/security-audit/.agent/workflows/security_audit.md',
      templatePath:
          'skills/security-audit/assets/report-template.txt',
    ),
  ];

  /// Workflow skill bundles (standalone markdown, no YAML rules).
  ///
  /// Installed to all agents as slash commands.
  static const List<WorkflowSkill> workflowSkills = [
    WorkflowSkill(
      id: 'clockify_tracker',
      name: 'clockify-tracker',
      displayName: 'Clockify Tracker',
      description:
          'Manages Clockify time tracking via the official Clockify REST '
          'API (v1): list workspaces and projects, create time entries '
          'with correct UTC timestamps.',
      planRelativePath:
          'skills/clockify-tracker/SKILL.md',
    ),
    WorkflowSkill(
      id: 'git_commit_format',
      name: 'git-commit-format',
      displayName: 'Git Commit Format',
      description:
          'Generates properly formatted Git commit messages (title + '
          'description) following Conventional Commits.',
      planRelativePath:
          'skills/git-commit-format/SKILL.md',
    ),
    WorkflowSkill(
      id: 'git_branch_format',
      name: 'git-branch-format',
      displayName: 'Git Branch Format',
      description:
          'Generates properly formatted Git branch names following '
          'project conventions.',
      planRelativePath:
          'skills/git-branch-format/SKILL.md',
    ),
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
    WorkflowSkill(
      id: 'ship',
      name: 'ship',
      displayName: 'Ship',
      description:
          'Fully automated ship workflow: merges the base branch, runs '
          'tests, reviews the diff, bumps VERSION, updates CHANGELOG, '
          'commits, pushes, and opens a pull request. Invoke when the '
          'user asks to ship, deploy, push to main, or create a PR.',
      planRelativePath:
          'skills/ship/SKILL.md',
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
