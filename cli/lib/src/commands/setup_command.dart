// coverage:ignore-file
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../content/skill_registry.dart';
import 'attribution_command.dart';
import '../installers/skills_sh_cleaner.dart';
import '../installers/skills_sh_cleanup_flow.dart';
import '../utils/cli_installer.dart';
import '../utils/command_helpers.dart';
import '../utils/prompts.dart';

/// Primary installation command.
///
/// Installs Somnio skills to every detected agent with the built-in,
/// manifest-tracked installer, so `somnio skills update` can refresh them.
///
/// Optionally detects and installs missing AI CLIs first. Before installing
/// it offers to remove Somnio skills a previous skills.sh install left in
/// the global scope (see [SkillsShCleaner]); `--force` skips that prompt.
class SetupCommand extends Command<int> {
  SetupCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Skip prompts and auto-approve all steps.',
      )
      ..addFlag(
        'yes',
        abbr: 'y',
        help: 'Same as --force.',
        negatable: false,
      )
      ..addFlag(
        'skip-cli',
        help: 'Skip CLI detection and installation.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Show detailed output for each step, including every '
            'skills.sh path removed.',
        negatable: false,
      )
      // Deprecated no-op kept so existing scripts don't break: the built-in
      // installer is now the only one.
      ..addFlag(
        'legacy',
        hide: true,
        negatable: false,
      );
  }

  final Logger _logger;

  @override
  String get name => 'setup';

  @override
  String get description => 'Install Somnio skills to all detected AI agents.\n'
      '\n'
      'Installs every skill globally with the built-in installer and\n'
      'records it in .somnio-skills.json, so "somnio skills update" keeps\n'
      'it current. Somnio skills previously installed by skills.sh\n'
      '(npx skills add) are removed first, after confirmation.';

  @override
  Future<int> run() async {
    final force =
        (argResults!['force'] as bool) || (argResults!['yes'] as bool);
    final skipCli = argResults!['skip-cli'] as bool;
    final verbose = argResults!['verbose'] as bool;

    if (argResults!['legacy'] as bool) {
      _logger.warn(
        '--legacy is deprecated and has no effect: setup always uses the '
        'built-in installer.',
      );
    }

    // ── Step 1: Optional CLI detection & installation ──────────────
    if (!skipCli) {
      await _detectAndInstallClis(force);
    }

    // ── Step 2: Install skills ──────────────────────────────────────
    final step = skipCli ? 'Step 1/1' : 'Step 2/2';
    _logger.info('');
    _logger.info('${lightCyan.wrap(step)}  Installing skills...');

    // Only clean up skills.sh installs once we know the install can go
    // ahead: removing them and then failing would leave no skills at all.
    final agents = await CommandHelpers.detectInstallTargets(_logger);
    if (agents.isEmpty) return ExitCode.software.code;

    final ResolvedContent content;
    try {
      content = await CommandHelpers.resolveContent();
    } catch (e) {
      _logger.err('$e');
      return ExitCode.software.code;
    }

    runSkillsShCleanup(
      logger: _logger,
      cleaner: SkillsShCleaner(),
      assumeYes: force,
      interactive: Prompts.isInteractive,
      verbose: verbose,
      reinstalled: CommandHelpers.skillNames(
        content.bundles,
        SkillRegistry.workflowSkills,
      ),
    );

    final exitCode =
        await CommandHelpers.installAllSkills(_logger, agents, content);

    if (agents.any((agent) => agent.id == 'claude')) {
      _offerAttributionOff(force);
    }

    return exitCode;
  }

  /// Offers to turn off Claude Code's commit and PR attribution.
  ///
  /// It changes the user's Claude Code settings, so it is only done after an
  /// explicit yes: `--force` and non-interactive runs skip it and print the
  /// command instead.
  void _offerAttributionOff(bool force) {
    final settingsPath = claudeSettingsPath();
    final ClaudeAttributionState state;
    try {
      state = readClaudeAttribution(settingsPath);
    } on FormatException {
      return;
    }
    if (state == ClaudeAttributionState.disabled) return;

    final hint = 'Run ${lightCyan.wrap('somnio attribution off')} to remove '
        'Claude Code\'s "Generated with Claude Code" footer and '
        'Co-Authored-By trailer.';
    _logger.info('');
    if (force || !Prompts.isInteractive) {
      _logger.info(hint);
      return;
    }

    final confirmed = _logger.confirm(
      'Remove Claude Code\'s AI attribution from commits and PRs?',
      defaultValue: true,
    );
    if (!confirmed) {
      _logger.info(hint);
      return;
    }
    setClaudeAttribution(settingsPath, enabled: false);
    _logger.success('Claude Code attribution turned off ($settingsPath).');
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
}
