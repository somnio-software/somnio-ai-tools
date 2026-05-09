import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import '../content/content_loader.dart';
import '../content/skill_registry.dart';
import '../installers/agent_installer.dart';
import '../utils/command_helpers.dart';
import '../utils/platform_utils.dart';

/// Installs skills to a specific agent or all detected agents.
///
/// Usage:
///   somnio install --agent claude
///   somnio install --agent copilot
///   somnio install --all
class InstallCommand extends Command<int> {
  InstallCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'agent',
      abbr: 'a',
      help: 'Target agent to install to.',
      allowed: AgentRegistry.installableAgents.map((a) => a.id).toList(),
    );
    argParser.addFlag(
      'all',
      help: 'Install to all detected agents.',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Force reinstall of all skills.',
    );
    argParser.addFlag(
      'all-configs',
      help: 'Install to every ~/.<agent>* config directory found '
          '(e.g. .claude-work, .cursor-personal). Composes with --all. '
          'Overrides CLAUDE_CONFIG_DIR for Claude.',
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
    final agentId = argResults!['agent'] as String?;
    final installAll = argResults!['all'] as bool;
    final force = argResults!['force'] as bool;
    final allConfigs = argResults!['all-configs'] as bool;

    if (agentId == null && !installAll) {
      _logger.err('Specify --agent <name> or --all.');
      _logger.info('');
      _logger.info('Available agents:');
      for (final agent in AgentRegistry.installableAgents) {
        _logger.info('  ${agent.id.padRight(12)} ${agent.displayName}');
      }
      return ExitCode.usage.code;
    }

    // Resolve repo root
    final ResolvedContent content;
    try {
      content = await CommandHelpers.resolveContent();
    } catch (e) {
      _logger.err('$e');
      return ExitCode.software.code;
    }

    if (installAll) {
      return _installToAll(
        content.loader,
        content.bundles,
        force,
        allConfigs: allConfigs,
      );
    }

    final agent = AgentRegistry.findById(agentId!);
    if (agent == null) {
      _logger.err('Unknown agent: $agentId');
      return ExitCode.usage.code;
    }

    return _installToAgent(
      agent,
      content.loader,
      content.bundles,
      force,
      allConfigs: allConfigs,
    );
  }

  Future<int> _installToAgent(
    AgentConfig agent,
    ContentLoader loader,
    List<dynamic> bundles,
    bool force, {
    bool allConfigs = false,
  }) async {
    // Check binary availability for CLI agents
    if (agent.binary != null) {
      final path = await PlatformUtils.whichBinary(agent.binary!);
      if (path == null) {
        _logger.warn(
          '${agent.displayName} CLI (${agent.binary}) not found in PATH.',
        );
        final proceed = _logger.confirm('Install skills anyway?');
        if (!proceed) return ExitCode.success.code;
      }
    }

    // Claude: resolve target dir(s) honoring CLAUDE_CONFIG_DIR or scanning
    // ~/.claude* when --all-configs is set. Other agents use the default
    // path resolution (no override).
    final targetDirs = _resolveTargetDirs(agent, allConfigs: allConfigs);

    var totalSkipped = 0;
    final locations = <String>[];

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
        bundles: SkillRegistry.skills,
        force: force,
      );

      final wfCount = installer.installWorkflowSkills(
        SkillRegistry.workflowSkills,
      );
      final installed = result.skillCount + wfCount;
      totalSkipped += result.skippedCount;
      locations.add(result.targetDirectory);

      final label = agent.contentLabel;
      final plural = installed == 1 ? label : '${label}s';
      progress.complete(
        '${agent.displayName}  '
        '$installed $plural installed',
      );
    }

    if (totalSkipped > 0) {
      _logger.info(
        '  $totalSkipped '
        '${totalSkipped == 1 ? 'skill' : 'skills'} '
        'skipped (not yet supported)',
      );
    }

    _logger.info('');
    if (locations.length == 1) {
      _logger.info('Location: ${locations.first}');
    } else {
      _logger.info('Locations:');
      for (final loc in locations) {
        _logger.info('  $loc');
      }
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

  Future<int> _installToAll(
    ContentLoader loader,
    List<dynamic> bundles,
    bool force, {
    bool allConfigs = false,
  }) async {
    var totalSkills = 0;
    var agentCount = 0;

    for (final agent in AgentRegistry.installableAgents) {
      // Only auto-install to agents that are detected
      if (agent.binary != null) {
        final path = await PlatformUtils.whichBinary(agent.binary!);
        if (path == null) continue;
      }

      // When allConfigs is set, fan out across every discovered config dir
      // for this agent; otherwise use the single default target.
      final targetDirs = _resolveTargetDirs(agent, allConfigs: allConfigs);

      var agentTotal = 0;
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
          bundles: SkillRegistry.skills,
          force: force,
        );

        final wfCount = installer.installWorkflowSkills(
          SkillRegistry.workflowSkills,
        );
        final dirTotal = result.skillCount + wfCount;
        agentTotal += dirTotal;

        final label = agent.contentLabel;
        final plural = dirTotal == 1 ? label : '${label}s';
        final parts = <String>['$dirTotal $plural'];
        if (result.skippedCount > 0) {
          parts.add('${result.skippedCount} skipped');
        }
        progress.complete(
          '${agent.displayName}  ${parts.join(', ')}',
        );
      }

      totalSkills += agentTotal;
      if (agentTotal > 0) agentCount++;
    }

    _logger.info('');
    if (agentCount > 0) {
      _logger.success(
        'Installed $totalSkills skills across $agentCount agents.',
      );
    } else {
      _logger.info('No agents detected. Run "somnio setup" for guided setup.');
    }

    return ExitCode.success.code;
  }
}
