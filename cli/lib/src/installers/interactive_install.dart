// coverage:ignore-file
import 'package:mason_logger/mason_logger.dart';

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import '../content/content_loader.dart';
import '../content/skill_bundle.dart';
import '../content/skill_registry.dart';
import '../content/workflow_skill.dart';
import '../utils/platform_utils.dart';
import '../utils/prompts.dart';
import 'agent_installer.dart';

/// The skills chosen for installation, split by kind.
class SkillSelection {
  const SkillSelection(this.audit, this.workflow);

  /// Every registered skill (audit + workflow).
  SkillSelection.all()
      : audit = SkillRegistry.skills,
        workflow = SkillRegistry.workflowSkills;

  final List<SkillBundle> audit;
  final List<WorkflowSkill> workflow;

  bool get isEmpty => audit.isEmpty && workflow.isEmpty;
}

/// Shared interactive selection + installation flow used by both
/// `somnio install` and `somnio update`.
///
/// Centralizes the agent/skill pickers (powered by [Prompts] / `interact_cli`)
/// and the per-agent install loop so the two commands stay in sync.
class InteractiveInstall {
  InteractiveInstall(this._logger);

  final Logger _logger;

  /// Installable agents detected on this machine — binary present, or IDE
  /// agents that have no binary requirement. Mirrors the legacy `--all`
  /// behavior.
  Future<List<AgentConfig>> detectedAgents() async {
    final detected = <AgentConfig>[];
    for (final agent in AgentRegistry.installableAgents) {
      if (agent.binary != null) {
        final path = await PlatformUtils.whichBinary(agent.binary!);
        if (path == null) continue;
      }
      detected.add(agent);
    }
    return detected;
  }

  /// Interactive multi-select over all installable agents, pre-selecting the
  /// ones detected on this machine.
  Future<List<AgentConfig>> promptForAgents() async {
    final agents = AgentRegistry.installableAgents;

    final detectedIds = <String>{};
    for (final agent in agents) {
      if (agent.binary == null) continue;
      final path = await PlatformUtils.whichBinary(agent.binary!);
      if (path != null) detectedIds.add(agent.id);
    }

    final options = agents
        .map(
          (a) => detectedIds.contains(a.id)
              ? '${a.displayName} (detected)'
              : a.displayName,
        )
        .toList();
    final defaults = agents.map((a) => detectedIds.contains(a.id)).toList();

    final indexes = Prompts.selectMany(
      prompt: 'Select agents to install to',
      options: options,
      defaults: defaults,
    );

    return indexes.map((i) => agents[i]).toList();
  }

  /// Interactive multi-select over all skills (audit + workflow), all
  /// pre-selected by default.
  SkillSelection promptForSkills() {
    final audit = SkillRegistry.skills;
    final workflow = SkillRegistry.workflowSkills;

    final options = <String>[
      ...audit.map((s) => s.displayName),
      ...workflow.map((s) => s.displayName),
    ];
    final defaults = List<bool>.filled(options.length, true);

    final indexes = Prompts.selectMany(
      prompt: 'Select the skills to install',
      options: options,
      defaults: defaults,
    );

    final selectedAudit = <SkillBundle>[];
    final selectedWorkflow = <WorkflowSkill>[];
    for (final i in indexes) {
      if (i < audit.length) {
        selectedAudit.add(audit[i]);
      } else {
        selectedWorkflow.add(workflow[i - audit.length]);
      }
    }

    return SkillSelection(selectedAudit, selectedWorkflow);
  }

  /// Installs [selection] to each agent in [agents].
  Future<int> installToAgents(
    List<AgentConfig> agents,
    ContentLoader loader,
    SkillSelection selection, {
    bool force = false,
  }) async {
    final single = agents.length == 1;
    var totalSkills = 0;
    var agentCount = 0;
    String? lastLocation;

    for (final agent in agents) {
      final progress = _logger.progress(agent.displayName);

      final installer = AgentInstaller(
        logger: _logger,
        loader: loader,
        agentConfig: agent,
      );

      final result = await installer.install(
        bundles: selection.audit,
        force: force,
      );
      final wfCount = installer.installWorkflowSkills(selection.workflow);
      final agentTotal = result.skillCount + wfCount;

      totalSkills += agentTotal;
      if (agentTotal > 0) agentCount++;
      lastLocation = result.targetDirectory;

      final label = agent.contentLabel;
      final plural = agentTotal == 1 ? label : '${label}s';
      final parts = <String>['$agentTotal $plural'];
      if (result.skippedCount > 0) {
        parts.add('${result.skippedCount} skipped');
      }
      progress.complete('${agent.displayName}  ${parts.join(', ')}');
    }

    _logger.info('');
    if (single && lastLocation != null) {
      _logger.info('Location: $lastLocation');
    } else if (agentCount > 0) {
      _logger.success(
        'Installed $totalSkills skills across $agentCount agents.',
      );
    } else {
      _logger.info('No agents detected. Run "somnio setup" for guided setup.');
    }

    return ExitCode.success.code;
  }
}