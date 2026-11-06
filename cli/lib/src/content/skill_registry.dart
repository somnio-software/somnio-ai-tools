import 'skill_bundle.dart';
import 'workflow_skill.dart';

/// Static registry of all available skill bundles.
///
/// Each bundle maps to a set of source files in `skills/` and defines
/// how they are installed into each agent.
class SkillRegistry {
  SkillRegistry._(); // coverage:ignore-line

  /// All registered skill bundles.
  static const List<SkillBundle> skills = [
    SkillBundle(
      id: 'flutter_health',
      name: 'flutter-health-audit',
      aliases: ['somnio-fh', 'fh'],
      displayName: 'Flutter Project Health Audit',
      description:
          'Flutter project health audit, scored report. Triggers: '
          "'flutter audit', 'health audit', 'flutter health', 'tech "
          "debt assessment', 'project quality check'.",
      planRelativePath: 'skills/flutter-health-audit/SKILL.md',
      rulesDirectory: 'skills/flutter-health-audit/references',
      workflowPath:
          'skills/flutter-health-audit/.agent/workflows/flutter_health_audit.md',
      templatePath: 'skills/flutter-health-audit/assets/report-template.md',
      agentsDirectory: 'skills/flutter-health-audit/agents',
    ),
    SkillBundle(
      id: 'angular_health',
      name: 'angular-health-audit',
      aliases: ['somnio-ah', 'ah'],
      displayName: 'Angular Project Health Audit',
      description:
          'Modern Angular 2+ (not AngularJS) project health audit, '
          "scored report. Triggers: 'angular audit', 'angular "
          "health', 'angular cli audit', 'ngx audit'.",
      planRelativePath: 'skills/angular-health-audit/SKILL.md',
      rulesDirectory: 'skills/angular-health-audit/references',
      workflowPath:
          'skills/angular-health-audit/.agent/workflows/angular_health_audit.md',
      templatePath: 'skills/angular-health-audit/assets/report-template.md',
      agentsDirectory: 'skills/angular-health-audit/agents',
    ),
    SkillBundle(
      id: 'flutter_plan',
      name: 'flutter-best-practices',
      aliases: ['somnio-fp', 'fp'],
      displayName: 'Flutter Best Practices Check',
      description:
          "Flutter code quality audit. Triggers: 'flutter best "
          "practices', 'flutter standards', 'code quality', 'code "
          "review', 'architecture compliance'.",
      planRelativePath: 'skills/flutter-best-practices/SKILL.md',
      rulesDirectory: 'skills/flutter-best-practices/references',
      workflowPath:
          'skills/flutter-best-practices/.agent/workflows/flutter_best_practices.md',
      templatePath: 'skills/flutter-best-practices/assets/report-template.md',
      agentsDirectory: 'skills/flutter-best-practices/agents',
    ),
    SkillBundle(
      id: 'soc2_audit',
      name: 'soc2-audit',
      aliases: ['somnio-s2', 's2'],
      displayName: 'SOC 2 Readiness Audit',
      description:
          'Read-only SOC 2 readiness audit against the Trust Services '
          "Criteria, /100 score. Triggers: 'soc 2 audit', 'soc2 "
          "readiness', 'soc2 gap analysis', 'compliance audit'.",
      planRelativePath: 'skills/soc2-audit/SKILL.md',
      rulesDirectory: 'skills/soc2-audit/references',
      workflowPath: 'skills/soc2-audit/.agent/workflows/soc2_audit.md',
      templatePath: 'skills/soc2-audit/assets/report-template.md',
      agentsDirectory: 'skills/soc2-audit/agents',
    ),
    SkillBundle(
      id: 'nestjs_health',
      name: 'nestjs-health-audit',
      aliases: ['somnio-nh', 'nh'],
      displayName: 'NestJS Project Health Audit',
      description:
          'NestJS project health audit, scored report. Triggers: '
          "'nestjs audit', 'nestjs health', 'health audit', 'backend "
          "audit', 'node audit', 'api audit'.",
      planRelativePath: 'skills/nestjs-health-audit/SKILL.md',
      rulesDirectory: 'skills/nestjs-health-audit/references',
      workflowPath:
          'skills/nestjs-health-audit/.agent/workflows/nestjs_health_audit.md',
      templatePath: 'skills/nestjs-health-audit/assets/report-template.md',
      agentsDirectory: 'skills/nestjs-health-audit/agents',
    ),
    SkillBundle(
      id: 'angularjs_plan',
      name: 'angularjs-best-practices',
      aliases: ['somnio-ajp', 'ajp'],
      displayName: 'AngularJS Best Practices Check',
      description:
          'AngularJS (Angular 1.x) code quality audit. Triggers: '
          "'angularjs best practices', 'angular 1 code quality', "
          "'minification-safe DI review'.",
      planRelativePath: 'skills/angularjs-best-practices/SKILL.md',
      rulesDirectory: 'skills/angularjs-best-practices/references',
      workflowPath:
          'skills/angularjs-best-practices/.agent/workflows/angularjs_best_practices.md',
      templatePath: 'skills/angularjs-best-practices/assets/report-template.md',
      agentsDirectory: 'skills/angularjs-best-practices/agents',
    ),
    SkillBundle(
      id: 'nestjs_plan',
      name: 'nestjs-best-practices',
      aliases: ['somnio-np', 'np'],
      displayName: 'NestJS Best Practices Check',
      description:
          "NestJS code quality audit. Triggers: 'nestjs best "
          "practices', 'nestjs standards', 'backend code quality', "
          "'code review', 'dto validation'.",
      planRelativePath: 'skills/nestjs-best-practices/SKILL.md',
      rulesDirectory: 'skills/nestjs-best-practices/references',
      workflowPath:
          'skills/nestjs-best-practices/.agent/workflows/nestjs_best_practices.md',
      templatePath: 'skills/nestjs-best-practices/assets/report-template.md',
      agentsDirectory: 'skills/nestjs-best-practices/agents',
    ),
    SkillBundle(
      id: 'angular_plan',
      name: 'angular-best-practices',
      aliases: ['somnio-ap', 'ap'],
      displayName: 'Angular Best Practices Check',
      description:
          'Modern Angular 2+ (not AngularJS) code quality audit. '
          "Triggers: 'angular best practices', 'angular code "
          "quality', 'rxjs review', 'ngx best practices'.",
      planRelativePath: 'skills/angular-best-practices/SKILL.md',
      rulesDirectory: 'skills/angular-best-practices/references',
      workflowPath:
          'skills/angular-best-practices/.agent/workflows/angular_best_practices.md',
      templatePath: 'skills/angular-best-practices/assets/report-template.md',
      agentsDirectory: 'skills/angular-best-practices/agents',
    ),
    SkillBundle(
      id: 'react_health',
      name: 'react-health-audit',
      aliases: ['somnio-rh', 'rh'],
      displayName: 'React Project Health Audit',
      description:
          'React project health audit, scored report; hands off to '
          "nextjs-health-audit on Next.js. Triggers: 'react audit', "
          "'react health', 'health audit', 'frontend audit'.",
      planRelativePath: 'skills/react-health-audit/SKILL.md',
      rulesDirectory: 'skills/react-health-audit/references',
      workflowPath:
          'skills/react-health-audit/.agent/workflows/react_health_audit.md',
      templatePath: 'skills/react-health-audit/assets/report-template.md',
      agentsDirectory: 'skills/react-health-audit/agents',
    ),
    SkillBundle(
      id: 'angularjs_health',
      name: 'angularjs-health-audit',
      aliases: ['somnio-ajh', 'ajh'],
      displayName: 'AngularJS Project Health Audit',
      description:
          'AngularJS (Angular 1.x) project health audit, scored '
          "report. Triggers: 'angularjs audit', 'angular 1 audit', "
          "'legacy frontend audit', 'bower audit'.",
      planRelativePath: 'skills/angularjs-health-audit/SKILL.md',
      rulesDirectory: 'skills/angularjs-health-audit/references',
      workflowPath:
          'skills/angularjs-health-audit/.agent/workflows/angularjs_health_audit.md',
      templatePath: 'skills/angularjs-health-audit/assets/report-template.md',
      agentsDirectory: 'skills/angularjs-health-audit/agents',
    ),
    SkillBundle(
      id: 'react_plan',
      name: 'react-best-practices',
      aliases: ['somnio-rp', 'rp'],
      displayName: 'React Best Practices Check',
      description:
          "React code quality audit. Triggers: 'react best "
          "practices', 'react code quality', 'react standards', "
          "'component review', 'hooks review'.",
      planRelativePath: 'skills/react-best-practices/SKILL.md',
      rulesDirectory: 'skills/react-best-practices/references',
      workflowPath:
          'skills/react-best-practices/.agent/workflows/react_best_practices.md',
      templatePath: 'skills/react-best-practices/assets/report-template.md',
      agentsDirectory: 'skills/react-best-practices/agents',
    ),
    SkillBundle(
      id: 'python_health',
      name: 'python-health-audit',
      aliases: ['somnio-ph', 'ph'],
      displayName: 'Python Project Health Audit',
      description:
          'Python project health audit (FastAPI, Django, Flask), '
          "scored report. Triggers: 'python audit', 'python health', "
          "'fastapi audit', 'django audit', 'flask audit'.",
      planRelativePath: 'skills/python-health-audit/SKILL.md',
      rulesDirectory: 'skills/python-health-audit/references',
      workflowPath:
          'skills/python-health-audit/.agent/workflows/python_health_audit.md',
      templatePath: 'skills/python-health-audit/assets/report-template.md',
      agentsDirectory: 'skills/python-health-audit/agents',
    ),
    SkillBundle(
      id: 'iso27001_audit',
      name: 'iso27001-audit',
      aliases: ['somnio-iso', 'iso'],
      displayName: 'ISO 27001 Readiness Audit',
      description:
          'Read-only ISO/IEC 27001:2022 readiness audit (ISMS, Annex '
          "A), /100 score. Triggers: 'iso 27001 audit', 'isms audit', "
          "'annex a gap analysis', 'iso compliance audit'.",
      planRelativePath: 'skills/iso27001-audit/SKILL.md',
      rulesDirectory: 'skills/iso27001-audit/references',
      workflowPath: 'skills/iso27001-audit/.agent/workflows/iso27001_audit.md',
      templatePath: 'skills/iso27001-audit/assets/report-template.md',
      agentsDirectory: 'skills/iso27001-audit/agents',
    ),
    SkillBundle(
      id: 'python_plan',
      name: 'python-best-practices',
      aliases: ['somnio-pp', 'pp'],
      displayName: 'Python Best Practices Check',
      description:
          "Python code quality audit. Triggers: 'python best "
          "practices', 'python code quality', 'python standards', "
          "'code review', 'type hints review', 'pytest review'.",
      planRelativePath: 'skills/python-best-practices/SKILL.md',
      rulesDirectory: 'skills/python-best-practices/references',
      workflowPath:
          'skills/python-best-practices/.agent/workflows/python_best_practices.md',
      templatePath: 'skills/python-best-practices/assets/report-template.md',
      agentsDirectory: 'skills/python-best-practices/agents',
    ),
    SkillBundle(
      id: 'dotnet_health',
      name: 'dotnet-health-audit',
      aliases: ['somnio-dh', 'dh'],
      displayName: '.NET Project Health Audit',
      description:
          '.NET / ASP.NET Core Web API project health audit, scored '
          "report. Triggers: 'dotnet audit', 'health audit', '.net "
          "audit', 'aspnet audit', 'csharp audit'.",
      planRelativePath: 'skills/dotnet-health-audit/SKILL.md',
      rulesDirectory: 'skills/dotnet-health-audit/references',
      workflowPath:
          'skills/dotnet-health-audit/.agent/workflows/dotnet_health_audit.md',
      templatePath: 'skills/dotnet-health-audit/assets/report-template.md',
      agentsDirectory: 'skills/dotnet-health-audit/agents',
    ),
    SkillBundle(
      id: 'dotnet_plan',
      name: 'dotnet-best-practices',
      aliases: ['somnio-dp', 'dp'],
      displayName: '.NET Best Practices Check',
      description:
          ".NET / ASP.NET Core code quality audit. Triggers: 'dotnet "
          "best practices', '.net code quality', 'aspnet code "
          "review', 'csharp standards', 'dto validation review'.",
      planRelativePath: 'skills/dotnet-best-practices/SKILL.md',
      rulesDirectory: 'skills/dotnet-best-practices/references',
      workflowPath:
          'skills/dotnet-best-practices/.agent/workflows/dotnet_best_practices.md',
      templatePath: 'skills/dotnet-best-practices/assets/report-template.md',
      agentsDirectory: 'skills/dotnet-best-practices/agents',
    ),
    SkillBundle(
      id: 'nextjs_health',
      name: 'nextjs-health-audit',
      aliases: ['somnio-nxh', 'nxh'],
      displayName: 'Next.js Project Health Audit',
      description:
          'Next.js project health audit (versions, App Router, '
          "caching, CI/CD), scored report. Triggers: 'nextjs audit', "
          "'nextjs health', 'app router audit'.",
      planRelativePath: 'skills/nextjs-health-audit/SKILL.md',
      rulesDirectory: 'skills/nextjs-health-audit/references',
      workflowPath:
          'skills/nextjs-health-audit/.agent/workflows/nextjs_health_audit.md',
      templatePath: 'skills/nextjs-health-audit/assets/report-template.md',
      agentsDirectory: 'skills/nextjs-health-audit/agents',
    ),
    SkillBundle(
      id: 'nextjs_plan',
      name: 'nextjs-best-practices',
      aliases: ['somnio-nxp', 'nxp'],
      displayName: 'Next.js Best Practices Check',
      description:
          'Version-aware Next.js code quality audit (App Router, '
          "Server Components). Triggers: 'nextjs best practices', "
          "'nextjs code review', 'app router best practices'.",
      planRelativePath: 'skills/nextjs-best-practices/SKILL.md',
      rulesDirectory: 'skills/nextjs-best-practices/references',
      workflowPath:
          'skills/nextjs-best-practices/.agent/workflows/nextjs_best_practices.md',
      templatePath: 'skills/nextjs-best-practices/assets/report-template.md',
      agentsDirectory: 'skills/nextjs-best-practices/agents',
    ),
    SkillBundle(
      id: 'nextjs_security_audit',
      name: 'nextjs-security-audit',
      aliases: ['somnio-nxs', 'nxs'],
      displayName: 'Next.js Security Audit',
      description:
          'Next.js security audit: live advisory checks of installed '
          "versions, secrets, Server Actions. Triggers: 'nextjs "
          "security audit', 'nextjs cve', 'is my next version "
          "vulnerable'.",
      planRelativePath: 'skills/nextjs-security-audit/SKILL.md',
      rulesDirectory: 'skills/nextjs-security-audit/references',
      workflowPath:
          'skills/nextjs-security-audit/.agent/workflows/nextjs_security_audit.md',
      templatePath: 'skills/nextjs-security-audit/assets/report-template.md',
      agentsDirectory: 'skills/nextjs-security-audit/agents',
    ),
    SkillBundle(
      id: 'security_audit',
      name: 'security-audit',
      aliases: ['somnio-sa', 'sa'],
      displayName: 'Security Audit',
      description:
          'Framework-agnostic security audit: secrets, sensitive '
          "files, dependency vulnerabilities. Triggers: 'security "
          "audit', 'vulnerability scan', 'secret scan', 'owasp'.",
      planRelativePath: 'skills/security-audit/SKILL.md',
      rulesDirectory: 'skills/security-audit/references',
      workflowPath: 'skills/security-audit/.agent/workflows/security_audit.md',
      templatePath: 'skills/security-audit/assets/report-template.md',
      agentsDirectory: 'skills/security-audit/agents',
    ),
    SkillBundle(
      id: 'harness_audit',
      name: 'harness-audit',
      aliases: ['somnio-ha', 'ha'],
      displayName: 'Harness Audit',
      description:
          'Read-only AI harness audit: scores CLAUDE.md, rules, hooks '
          "and agents out of 100. Triggers: 'harness audit', 'ai "
          "harness', 'claude harness score'.",
      planRelativePath: 'skills/harness-audit/SKILL.md',
      rulesDirectory: 'skills/harness-audit/references',
      workflowPath: 'skills/harness-audit/.agent/workflows/harness_audit.md',
      templatePath: 'skills/harness-audit/assets/report-template.md',
      agentsDirectory: 'skills/harness-audit/agents',
    ),
    SkillBundle(
      id: 'architecture_audit',
      name: 'architecture-audit',
      aliases: ['somnio-aa', 'aa'],
      displayName: 'Architecture Audit',
      description: 'Audit a codebase against a written modular architecture '
          'standard — module roles, allowed dependencies, feature '
          'isolation, composition and navigation, and which rules tools '
          'enforce — in proportion to its size and team (Compact, '
          'Standard or Large profile), and return a score out of 100 '
          'with a maturity band and a staged remediation plan. Measures '
          'Dart/Flutter, TypeScript/JavaScript and Python import graphs '
          'with a fixed script.',
      planRelativePath: 'skills/architecture-audit/SKILL.md',
      rulesDirectory: 'skills/architecture-audit/references',
      workflowPath:
          'skills/architecture-audit/.agent/workflows/architecture_audit.md',
      templatePath: 'skills/architecture-audit/assets/report-template.md',
      agentsDirectory: 'skills/architecture-audit/agents',
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
          'Clockify time tracking via the REST API: list projects, '
          'create time entries (UTC). Use to log time, track hours, '
          'or when Clockify is mentioned.',
      planRelativePath: 'skills/clockify-tracker/SKILL.md',
    ),
    WorkflowSkill(
      id: 'git_commit_format',
      name: 'git-commit-format',
      displayName: 'Git Commit Format',
      description:
          'Generates Conventional Commits messages (title + '
          'description). Use for "write a commit for these changes", '
          '"how should I commit this?".',
      planRelativePath: 'skills/git-commit-format/SKILL.md',
    ),
    WorkflowSkill(
      id: 'git_branch_format',
      name: 'git-branch-format',
      displayName: 'Git Branch Format',
      description:
          'Generates Git branch names following project conventions. '
          'Use when naming or creating a branch: "what should I call '
          'this branch?".',
      planRelativePath: 'skills/git-branch-format/SKILL.md',
    ),
    WorkflowSkill(
      id: 'git_pr_format',
      name: 'git-pr-format',
      displayName: 'Git PR Format',
      description:
          'Generates PR titles and descriptions with no AI '
          'attribution. Use before `gh pr create` or `gh pr edit '
          '--body`, or for "open a PR for this".',
      planRelativePath: 'skills/git-pr-format/SKILL.md',
    ),
    WorkflowSkill(
      id: 'workflow_builder',
      name: 'workflow-builder',
      displayName: 'Workflow Builder',
      description:
          'Creates and runs multi-step workflows with per-step AI '
          "models and parallel waves. Triggers: 'create workflow', "
          "'run workflow', 'resume workflow', 'task pipeline'.",
      planRelativePath: 'skills/workflow-builder/SKILL.md',
      referencesRelativePath: 'skills/workflow-builder/references',
    ),
    WorkflowSkill(
      id: 'dart_model_from_json',
      name: 'dart-model-from-json',
      displayName: 'Dart Model from JSON',
      description:
          'Generates Dart models from JSON with json_annotation and '
          "equatable. Triggers: 'dart model from json', 'generate a "
          "Dart model for this JSON'.",
      planRelativePath: 'skills/dart-model-from-json/SKILL.md',
    ),
    WorkflowSkill(
      id: 'optimize_claude_config',
      name: 'optimize-claude-config',
      displayName: 'Optimize Claude Config',
      description:
          'Audits Claude Code config: lazy-load `paths:` rules '
          'checked against the tree, slim CLAUDE.md index, '
          'PreToolUse(Write) hook. --audit-only skips applying.',
      planRelativePath: 'skills/optimize-claude-config/SKILL.md',
    ),
    WorkflowSkill(
      id: 'dora_metrics',
      name: 'dora-metrics',
      displayName: 'DORA Metrics',
      description:
          'DORA metrics (deployment frequency, lead time) from '
          'GitHub, GitLab, Bitbucket or Azure DevOps APIs. Triggers: '
          "'run the DORA metrics', 'lead time for [project]'.",
      planRelativePath: 'skills/dora-metrics/SKILL.md',
      assetDirectories: [
        'skills/dora-metrics/scripts',
        'skills/dora-metrics/config',
        'skills/dora-metrics/agents',
        'skills/dora-metrics/assets',
      ],
      referencesRelativePath: 'skills/dora-metrics/references',
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

  /// Find a workflow skill by its id or name.
  static WorkflowSkill? findWorkflowById(String idOrName) {
    for (final skill in workflowSkills) {
      if (skill.id == idOrName || skill.name == idOrName) return skill;
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
    return skills.where((s) => techNames.contains(s.techDisplayName)).toList();
  }
}
