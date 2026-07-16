// coverage:ignore-file
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import '../content/skill_bundle.dart';
import '../content/skill_registry.dart';
import '../content/workflow_skill.dart';
import '../installers/interactive_install.dart';
import '../utils/command_helpers.dart';
import '../utils/prompts.dart';

/// Installs skills to a specific agent or all detected agents.
///
/// Usage:
///   somnio install                     # interactive wizard (agents + skills)
///   somnio install --agent claude
///   somnio install --all
///   somnio install --agent claude --skills flutter_health,security_audit
///   somnio install --agent claude --all-skills
class InstallCommand extends Command<int> {
  InstallCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'agent',
        abbr: 'a',
        help: 'Target agent to install to.',
        allowed: AgentRegistry.installableAgents.map((a) => a.id).toList(),
      )
      ..addFlag(
        'all',
        help: 'Install to all detected agents.',
      )
      ..addFlag(
        'all-skills',
        help: 'Install every skill without prompting for a selection.',
      )
      ..addOption(
        'skills',
        help: 'Comma-separated skill ids/names to install (skips the wizard).',
      );
  }

  final Logger _logger;

  @override
  String get name => 'install';

  @override
  String get description =>
      'Install skills to a specific agent or all detected agents.';

  @override
  Future<int> run() async {
    // Resolve repo root / content.
    final ResolvedContent content;
    try {
      content = await CommandHelpers.resolveContent();
    } catch (e) {
      _logger.err('$e');
      return ExitCode.software.code;
    }

    final flow = InteractiveInstall(_logger);

    // 1. Resolve which agents to install to.
    final agents = await _resolveAgents(flow);
    if (agents == null) return ExitCode.usage.code;
    if (agents.isEmpty) {
      _logger.info('No agents selected.');
      return ExitCode.success.code;
    }

    // 2. Resolve which skills to install.
    final selection = _resolveSkills(flow);
    if (selection == null) return ExitCode.usage.code;
    if (selection.isEmpty) {
      _logger.info('No skills selected.');
      return ExitCode.success.code;
    }

    // 3. Install the selected skills to each selected agent.
    return flow.installToAgents(agents, content.loader, selection);
  }

  // ──────────────────────────────────────────────────────────────────
  // Agent resolution
  // ──────────────────────────────────────────────────────────────────

  /// Returns the agents to install to, or `null` on a usage error.
  Future<List<AgentConfig>?> _resolveAgents(InteractiveInstall flow) async {
    final agentId = argResults!['agent'] as String?;
    final installAll = argResults!['all'] as bool;

    if (installAll) {
      return flow.detectedAgents();
    }

    if (agentId != null) {
      final agent = AgentRegistry.findById(agentId);
      if (agent == null) {
        _logger.err('Unknown agent: $agentId');
        return null;
      }
      return [agent];
    }

    // No flag given: prompt interactively, or error when non-interactive.
    if (!Prompts.isInteractive) {
      _logger.err('Specify --agent <name> or --all.');
      _logger.info('');
      _logger.info('Available agents:');
      for (final agent in AgentRegistry.installableAgents) {
        _logger.info('  ${agent.id.padRight(12)} ${agent.displayName}');
      }
      return null;
    }

    return flow.promptForAgents();
  }

  // ──────────────────────────────────────────────────────────────────
  // Skill resolution
  // ──────────────────────────────────────────────────────────────────

  /// Returns the skills to install, or `null` on a usage error.
  SkillSelection? _resolveSkills(InteractiveInstall flow) {
    final allSkills = argResults!['all-skills'] as bool;
    final skillsCsv = argResults!['skills'] as String?;

    if (allSkills) {
      return SkillSelection.all();
    }

    if (skillsCsv != null) {
      return _parseSkillsCsv(skillsCsv);
    }

    // No flag: prompt interactively, or install everything when there is
    // no terminal (CI, pipes) so the command never hangs on stdin.
    if (!Prompts.isInteractive) {
      return SkillSelection.all();
    }

    return flow.promptForSkills();
  }

  /// Resolves a comma-separated list of skill ids/names against the registry.
  SkillSelection? _parseSkillsCsv(String csv) {
    final ids = csv.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);

    final audit = <SkillBundle>[];
    final workflow = <WorkflowSkill>[];
    final unknown = <String>[];

    for (final id in ids) {
      final bundle = SkillRegistry.findById(id) ?? SkillRegistry.findByName(id);
      if (bundle != null) {
        audit.add(bundle);
        continue;
      }
      final wf = SkillRegistry.findWorkflowById(id);
      if (wf != null) {
        workflow.add(wf);
        continue;
      }
      unknown.add(id);
    }

    if (unknown.isNotEmpty) {
      _logger.err('Unknown skill(s): ${unknown.join(', ')}');
      _logger.info('');
      _logger.info('Available skills:');
      for (final s in SkillRegistry.skills) {
        _logger.info('  ${s.id.padRight(18)} ${s.displayName}');
      }
      for (final s in SkillRegistry.workflowSkills) {
        _logger.info('  ${s.id.padRight(18)} ${s.displayName}');
      }
      return null;
    }

    return SkillSelection(audit, workflow);
  }
}