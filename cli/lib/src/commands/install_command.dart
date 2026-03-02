import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

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
      return _installToAll(content.loader, content.bundles, force);
    }

    final agent = AgentRegistry.findById(agentId!);
    if (agent == null) {
      _logger.err('Unknown agent: $agentId');
      return ExitCode.usage.code;
    }

    return _installToAgent(agent, content.loader, content.bundles, force);
  }

  Future<int> _installToAgent(
    AgentConfig agent,
    ContentLoader loader,
    List<dynamic> bundles,
    bool force,
  ) async {
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

    final progress = _logger.progress(agent.displayName);

    final installer = AgentInstaller(
      logger: _logger,
      loader: loader,
      agentConfig: agent,
    );

    final result = await installer.install(
      bundles: SkillRegistry.skills,
      force: force,
    );

    final label = agent.contentLabel;
    final plural = result.skillCount == 1 ? label : '${label}s';
    progress.complete(
      '${agent.displayName}  '
      '${result.skillCount} $plural installed',
    );

    if (result.skippedCount > 0) {
      _logger.info(
        '  ${result.skippedCount} '
        '${result.skippedCount == 1 ? 'skill' : 'skills'} '
        'skipped (not yet supported)',
      );
    }

    _logger.info('');
    _logger.info('Location: ${result.targetDirectory}');

    return ExitCode.success.code;
  }

  Future<int> _installToAll(
    ContentLoader loader,
    List<dynamic> bundles,
    bool force,
  ) async {
    var totalSkills = 0;
    var agentCount = 0;

    for (final agent in AgentRegistry.installableAgents) {
      // Only auto-install to agents that are detected
      if (agent.binary != null) {
        final path = await PlatformUtils.whichBinary(agent.binary!);
        if (path == null) continue;
      }

      final progress = _logger.progress(agent.displayName);

      final installer = AgentInstaller(
        logger: _logger,
        loader: loader,
        agentConfig: agent,
      );

      final result = await installer.install(
        bundles: SkillRegistry.skills,
        force: force,
      );

      totalSkills += result.skillCount;
      if (result.skillCount > 0) agentCount++;

      final label = agent.contentLabel;
      final plural = result.skillCount == 1 ? label : '${label}s';
      final parts = <String>['${result.skillCount} $plural'];
      if (result.skippedCount > 0) {
        parts.add('${result.skippedCount} skipped');
      }
      progress.complete(
        '${agent.displayName}  ${parts.join(', ')}',
      );
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
