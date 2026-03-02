import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../utils/cli_installer.dart';
import '../utils/command_helpers.dart';

/// Full guided setup wizard.
///
/// 1. Detect CLIs and offer to install missing ones (unless --skip-cli)
/// 2. Detect all agents and install skills to everything found
class SetupCommand extends Command<int> {
  SetupCommand({required Logger logger}) : _logger = logger {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Skip prompts and install all missing CLIs.',
    );
    argParser.addFlag(
      'skip-cli',
      help: 'Skip CLI detection and installation (same as "somnio init").',
    );
  }

  final Logger _logger;

  @override
  String get name => 'setup';

  @override
  String get description =>
      'Full guided setup: install CLIs, detect agents, and install skills.';

  @override
  Future<int> run() async {
    final force = argResults!['force'] as bool;
    final skipCli = argResults!['skip-cli'] as bool;

    if (!skipCli) {
      final cliInstaller = CliInstaller(logger: _logger);

      // ── Step 1: Detect CLIs ─────────────────────────────────────────
      _logger.info('');
      _logger.info(
        '${lightCyan.wrap('Step 1/3')}  Checking installed CLIs...',
      );
      _logger.info('');

      final cliChecks = await cliInstaller.detectAll();

      for (final check in cliChecks) {
        if (check.installed) {
          _logger.info(
            '  ${lightGreen.wrap('✓')} ${check.agent.displayName}'
            '  (${check.path})',
          );
        } else {
          _logger.info(
            '  ${lightRed.wrap('✗')} ${check.agent.displayName}'
            '  (not found)',
          );
        }
      }
      _logger.info('');

      // ── Step 2: Install missing CLIs ────────────────────────────────
      final missingClis = cliChecks.where((c) => !c.installed).toList();

      if (missingClis.isNotEmpty) {
        _logger.info(
          '${lightCyan.wrap('Step 2/3')}  Install missing CLIs',
        );
        _logger.info('');

        final hasNpm = await cliInstaller.isNpmAvailable();

        for (final missing in missingClis) {
          final agent = missing.agent;

          final shouldInstall = force ||
              _logger.confirm(
                'Install ${agent.displayName}?',
                defaultValue: true,
              );

          if (!shouldInstall) continue;

          if (agent.npmPackage != null && hasNpm) {
            final success = await cliInstaller.installViaNpm(agent);
            if (!success) {
              cliInstaller.showManualInstructions(agent);
            }
          } else {
            cliInstaller.showManualInstructions(agent);
            if (agent.npmPackage != null && !hasNpm) {
              _logger.warn(
                '  npm not found — install Node.js first for auto-install.',
              );
            }
          }
          _logger.info('');
        }
      } else {
        _logger.info(
          '${lightCyan.wrap('Step 2/3')}  Install missing CLIs',
        );
        _logger.success('  All CLIs already installed!');
        _logger.info('');
      }

      // ── Step 3 label ────────────────────────────────────────────────
      _logger.info(
        '${lightCyan.wrap('Step 3/3')}  Installing skills...',
      );
      _logger.info('');
    }

    // ── Detect agents & install skills ──────────────────────────────
    return CommandHelpers.installToDetectedAgents(_logger);
  }
}
