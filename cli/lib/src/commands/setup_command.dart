import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../utils/cli_installer.dart';
import '../utils/command_helpers.dart';

/// Primary installation command.
///
/// Installs Somnio skills via `npx skills add` (skills.sh) which supports
/// 40+ AI agents. Falls back to the built-in installer if npx is unavailable.
///
/// Optionally detects and installs missing AI CLIs first.
class SetupCommand extends Command<int> {
  SetupCommand({required Logger logger}) : _logger = logger {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Skip prompts and auto-approve all steps.',
    );
    argParser.addFlag(
      'skip-cli',
      help: 'Skip CLI detection and installation.',
    );
    argParser.addFlag(
      'legacy',
      help: 'Use built-in installer instead of skills.sh.',
    );
  }

  final Logger _logger;

  /// GitHub repo for skills.sh installation.
  static const _skillsRepo = 'somnio-software/technology-tools';

  @override
  String get name => 'setup';

  @override
  String get description =>
      'Install Somnio skills to all AI agents via skills.sh.\n'
      '\n'
      'Uses `npx skills add` to install skills globally across all\n'
      'detected agents (Claude Code, Cursor, Codex, Gemini CLI, etc.).\n'
      'Falls back to built-in installer if npx is unavailable.';

  @override
  Future<int> run() async {
    final force = argResults!['force'] as bool;
    final skipCli = argResults!['skip-cli'] as bool;
    final useLegacy = argResults!['legacy'] as bool;

    // ── Step 1: Optional CLI detection & installation ──────────────
    if (!skipCli) {
      await _detectAndInstallClis(force);
    }

    // ── Step 2: Install skills ─────────────────────────────────────
    if (useLegacy) {
      _logger.info('');
      _logger.info(
        '${lightCyan.wrap('Installing')}  Using built-in installer...',
      );
      _logger.info('');
      return CommandHelpers.installToDetectedAgents(_logger);
    }

    return _installViaSkillsSh(force);
  }

  /// Detects installed AI CLIs and offers to install missing ones.
  Future<void> _detectAndInstallClis(bool force) async {
    final cliInstaller = CliInstaller(logger: _logger);

    _logger.info('');
    _logger.info(
      '${lightCyan.wrap('Step 1/2')}  Checking installed CLIs...',
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

    final missingClis = cliChecks.where((c) => !c.installed).toList();

    if (missingClis.isNotEmpty) {
      _logger.info('Install missing CLIs:');
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
      _logger.success('  All CLIs already installed!');
      _logger.info('');
    }
  }

  /// Installs skills via `npx skills add` (skills.sh).
  ///
  /// Falls back to built-in installer if npx is not available.
  Future<int> _installViaSkillsSh(bool force) async {
    _logger.info(
      '${lightCyan.wrap('Step 2/2')}  Installing skills via skills.sh...',
    );
    _logger.info('');

    // Check if npx is available
    final npxPath = await _whichNpx();
    if (npxPath == null) {
      _logger.warn(
        'npx not found. Falling back to built-in installer.',
      );
      _logger.info(
        'To use skills.sh, install Node.js: https://nodejs.org',
      );
      _logger.info('');
      return CommandHelpers.installToDetectedAgents(_logger);
    }

    // Build the npx skills add command
    final args = <String>[
      'skills',
      'add',
      _skillsRepo,
      '-g', // global install
      '--all', // all skills + all agents
    ];

    if (force) {
      args.add('-y'); // skip prompts
    }

    _logger.info('  Running: npx ${args.join(' ')}');
    _logger.info('');

    // Execute npx skills add
    final result = await Process.run(
      'npx',
      args,
      environment: Platform.environment,
      runInShell: true,
    );

    // Print stdout (contains the skills.sh progress UI)
    final stdout = (result.stdout as String).trim();
    if (stdout.isNotEmpty) {
      // Strip ANSI escape codes for cleaner output
      final clean = stdout.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '');
      for (final line in clean.split('\n')) {
        if (line.trim().isNotEmpty) {
          _logger.info('  $line');
        }
      }
    }

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      if (stderr.isNotEmpty) {
        _logger.err('skills.sh error: $stderr');
      }
      _logger.warn('');
      _logger.warn(
        'skills.sh installation failed. Falling back to built-in installer.',
      );
      _logger.info('');
      return CommandHelpers.installToDetectedAgents(_logger);
    }

    _logger.info('');
    _logger.success('Skills installed via skills.sh!');
    _logger.info('');

    CommandHelpers.printNextSteps(_logger);

    return ExitCode.success.code;
  }

  /// Checks if npx is available in PATH.
  Future<String?> _whichNpx() async {
    try {
      final result = await Process.run(
        'which',
        ['npx'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim();
        return path.isNotEmpty ? path : null;
      }
    } catch (_) {}
    return null;
  }
}
