// coverage:ignore-file
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

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
  ///
  /// Claude honors `CLAUDE_CONFIG_DIR` by default. When [allConfigs] is
  /// true, every agent fans out across each `~/.<agent>*` directory found on
  /// the machine (e.g. `.claude-work`, `.cursor-personal`) instead of just
  /// its single default target — for Claude this overrides
  /// `CLAUDE_CONFIG_DIR`, since the explicit "all configs" intent wins.
  Future<int> installToAgents(
    List<AgentConfig> agents,
    ContentLoader loader,
    SkillSelection selection, {
    bool force = false,
    bool allConfigs = false,
  }) async {
    final single = agents.length == 1;
    var totalSkills = 0;
    var agentCount = 0;
    final locations = <String>[];
    var multiLocation = false;

    for (final agent in agents) {
      final targetDirs = _resolveTargetDirs(agent, allConfigs: allConfigs);
      var agentTotal = 0;
      if (targetDirs.length > 1) multiLocation = true;

      for (final targetDir in targetDirs) {
        final progress = _logger.progress(
          targetDirs.length == 1
              ? agent.displayName
              : '${agent.displayName} (${p.basename(p.dirname(targetDir))})',
        );

        final installer = AgentInstaller(
          logger: _logger,
          loader: loader,
          agentConfig: agent,
          installDirOverride: targetDir,
        );

        final result = await installer.install(
          bundles: selection.audit,
          force: force,
        );
        final wfCount = installer.installWorkflowSkills(selection.workflow);
        final dirTotal = result.skillCount + wfCount;
        agentTotal += dirTotal;
        locations.add(result.targetDirectory);

        final label = agent.contentLabel;
        final plural = dirTotal == 1 ? label : '${label}s';
        final parts = <String>['$dirTotal $plural'];
        if (result.skippedCount > 0) {
          parts.add('${result.skippedCount} skipped');
        }
        progress.complete('${agent.displayName}  ${parts.join(', ')}');
      }

      totalSkills += agentTotal;
      if (agentTotal > 0) agentCount++;
    }

    _logger.info('');
    if (single && !multiLocation && locations.length == 1) {
      _logger.info('Location: ${locations.first}');
    } else if (single && multiLocation) {
      _logger.info('Locations:');
      for (final loc in locations) {
        _logger.info('  $loc');
      }
    } else if (agentCount > 0) {
      _logger.success(
        'Installed $totalSkills skills across $agentCount agents.',
      );
    } else {
      _logger.info('No agents detected. Run "somnio setup" for guided setup.');
    }

    return ExitCode.success.code;
  }

  /// Computes the install target directories for [agent].
  ///
  /// When [allConfigs] is true, scans `$HOME` for every directory whose name
  /// starts with the agent's [AgentConfig.configDirName] and joins each with
  /// the agent's [AgentConfig.installSubpath]. For Claude this overrides
  /// `CLAUDE_CONFIG_DIR` — the explicit "all configs" intent wins.
  ///
  /// When [allConfigs] is false, returns the single default target: Claude
  /// honors `CLAUDE_CONFIG_DIR`; every other agent uses its declared
  /// `resolvedInstallPath` unchanged.
  List<String> _resolveTargetDirs(
    AgentConfig agent, {
    bool allConfigs = false,
  }) {
    if (allConfigs) {
      final bases =
          PlatformUtils.discoverConfigDirs(prefix: agent.configDirName);
      return bases.map((dir) => p.join(dir, agent.installSubpath)).toList();
    }
    if (agent.id == 'claude') {
      return [p.join(PlatformUtils.claudeConfigDir, agent.installSubpath)];
    }
    return [agent.resolvedInstallPath(home: PlatformUtils.homeDirectory)];
  }
}