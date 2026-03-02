import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../agents/agent_registry.dart';
import '../installers/agent_installer.dart';
import '../utils/command_helpers.dart';

/// Updates the CLI and reinstalls all skills.
class UpdateCommand extends Command<int> {
  UpdateCommand({required Logger logger}) : _logger = logger;

  final Logger _logger;

  static const _repoUrl = 'https://github.com/somnio-software/technology-tools';

  @override
  String get name => 'update';

  @override
  String get description =>
      'Update CLI to latest version and reinstall all skills.';

  @override
  Future<int> run() async {
    // Step 1: Update CLI from git
    final updateProgress = _logger.progress('Updating somnio CLI');
    try {
      final result = await Process.run('dart', [
        'pub',
        'global',
        'activate',
        '--source',
        'git',
        _repoUrl,
        '--git-path',
        'cli',
      ]);
      if (result.exitCode != 0) {
        updateProgress.fail('Failed to update CLI');
        _logger.err(result.stderr as String);
        _logger.info('');
        _logger.info(
          'You can update manually:\n'
          '  dart pub global activate --source git $_repoUrl --git-path cli',
        );
        return ExitCode.software.code;
      }
      updateProgress.complete('CLI updated');
    } catch (e) {
      updateProgress.fail('Failed to update CLI: $e');
      return ExitCode.software.code;
    }

    // Step 2: Resolve repo root
    final ResolvedContent content;
    try {
      content = await CommandHelpers.resolveContent();
    } catch (e) {
      _logger.err('$e');
      return ExitCode.software.code;
    }

    _logger.info('');

    // Step 3: Detect previously installed agents and reinstall
    var updated = 0;

    for (final agent in AgentRegistry.installableAgents) {
      final installer = AgentInstaller(
        logger: _logger,
        loader: content.loader,
        agentConfig: agent,
      );
      if (installer.isInstalled()) {
        final progress = _logger.progress(agent.displayName);
        final result = await installer.install(
          bundles: content.bundles,
          force: true,
        );
        progress.complete(
          '${agent.displayName}  '
          '${CommandHelpers.installSummary(result, agent)} updated',
        );
        updated++;
      }
    }

    if (updated == 0) {
      _logger.info(
        '  No previously installed agents found. '
        'Run "somnio init" to install.',
      );
    }

    _logger.info('');
    _logger.success('All up to date!');

    return ExitCode.success.code;
  }
}
