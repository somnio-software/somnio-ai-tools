// coverage:ignore-file
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../content/command_bundle.dart';
import '../content/command_registry.dart';
import '../installers/command_installer.dart';
import '../utils/package_resolver.dart';

/// Supported agents for `somnio commands install`.
const _supportedAgents = ['claude', 'cursor'];

const _agentDisplayNames = {
  'claude': 'Claude Code',
  'cursor': 'Cursor',
};

/// Top-level `somnio commands` command — install root-level slash commands
/// (`commands/*.md`) to an agent's project-level commands directory.
///
/// Subcommands:
///   somnio commands install   — install commands to Claude and/or Cursor
class CommandsCommand extends Command<int> {
  CommandsCommand({required Logger logger}) {
    addSubcommand(_CommandsInstallCommand(logger: logger));
    addSubcommand(_CommandsStatusCommand(logger: logger));
  }

  @override
  String get name => 'commands';

  @override
  String get description =>
      'Install Somnio slash commands (ship / audit / quick-check / '
      'clockify-tracker) to Claude and/or Cursor, in the current project.';
}

// ── Install subcommand ──────────────────────────────────────────────────────

class _CommandsInstallCommand extends Command<int> {
  _CommandsInstallCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'agent',
      abbr: 'a',
      help: 'Target agent.',
      allowed: _supportedAgents,
    );
    argParser.addFlag(
      'all',
      help: 'Install to all supported agents (Claude and Cursor).',
    );
    argParser.addMultiOption(
      'commands',
      abbr: 'c',
      help:
          'Commands to install (comma-separated). Skip to select interactively.',
      allowed: CommandRegistry.commands.map((c) => c.name).toList(),
    );
  }

  final Logger _logger;

  @override
  String get name => 'install';

  @override
  String get description => 'Install Somnio commands to the current project '
      '(${CommandRegistry.commands.map((c) => c.name).join(' / ')}).\n'
      '\n'
      'Commands install at project scope only — under `.claude/commands/` '
      'and/or `.cursor/commands/` in the current directory.\n'
      '\n'
      'Examples:\n'
      '  somnio commands install                                  # interactive\n'
      '  somnio commands install --agent claude --commands ship   # non-interactive\n'
      '  somnio commands install --all --commands ship,audit';

  @override
  Future<int> run() async {
    final agentId = argResults!['agent'] as String?;
    final installAll = argResults!['all'] as bool;
    final cliCommands = (argResults!['commands'] as List<String>).toList();

    // Resolve repo root for the installer
    final String repoRoot;
    try {
      repoRoot = await PackageResolver().resolveRepoRoot();
    } catch (e) {
      _logger.err('Could not locate somnio-ai-tools repo: $e');
      return ExitCode.software.code;
    }

    final installer = CommandInstaller(repoRoot: repoRoot);

    // ── Select commands ─────────────────────────────────────────────
    final List<CommandBundle> selectedCommands;
    if (cliCommands.isNotEmpty) {
      selectedCommands = [];
      for (final name in cliCommands) {
        final bundle = CommandRegistry.findByName(name);
        if (bundle == null) {
          _logger.err('Unknown command: $name');
          return ExitCode.usage.code;
        }
        selectedCommands.add(bundle);
      }
    } else {
      _logger.info('');
      final bundles = CommandRegistry.commands;
      _logger.info('Which commands do you want to install?');
      _logger.info('');
      for (var i = 0; i < bundles.length; i++) {
        _logger.info(
            '  ${i + 1}) ${bundles[i].name}  —  ${bundles[i].description}');
      }
      _logger.info('  ${bundles.length + 1}) All commands');
      _logger.info('');
      final commandInput = _logger.prompt(
        'Select commands (comma-separated, e.g. 1,3 or ${bundles.length + 1} for all)',
      );

      final parts = commandInput.split(',').map((s) => s.trim()).toList();
      final picked = <CommandBundle>[];
      for (final part in parts) {
        final choice = int.tryParse(part);
        if (choice == null || choice < 1 || choice > bundles.length + 1) {
          _logger.err('Invalid selection: $part');
          return ExitCode.usage.code;
        }
        if (choice == bundles.length + 1) {
          picked
            ..clear()
            ..addAll(bundles);
          break;
        } else {
          final bundle = bundles[choice - 1];
          if (!picked.contains(bundle)) picked.add(bundle);
        }
      }

      if (picked.isEmpty) {
        _logger.err('No commands selected.');
        return ExitCode.usage.code;
      }
      selectedCommands = picked;
    }

    // ── Select agents ───────────────────────────────────────────────
    final List<String> targetAgents;
    if (installAll) {
      targetAgents = List.of(_supportedAgents);
    } else if (agentId != null) {
      targetAgents = [agentId];
    } else {
      _logger.info('');
      _logger.info('  1) Claude Code (.claude/commands)');
      _logger.info('  2) Cursor (.cursor/commands)');
      _logger.info('  3) Both');
      _logger.info('');
      final agentInput = _logger.prompt('Select agent (1-3)');
      final choice = int.tryParse(agentInput.trim());
      switch (choice) {
        case 1:
          targetAgents = ['claude'];
        case 2:
          targetAgents = ['cursor'];
        case 3:
          targetAgents = List.of(_supportedAgents);
        default:
          _logger.err('Invalid selection: $agentInput');
          return ExitCode.usage.code;
      }
    }

    // ── Install ─────────────────────────────────────────────────────
    var successCount = 0;
    var attemptCount = 0;

    for (final agent in targetAgents) {
      final targetDir = CommandInstaller.resolveTargetDir(agent);
      final agentName = _agentDisplayNames[agent] ?? agent;

      for (final bundle in selectedCommands) {
        attemptCount++;
        final progress = _logger.progress('$agentName — ${bundle.name}');
        final result = installer.install(bundle, targetDir);

        if (result.success) {
          progress.complete('$agentName — ${bundle.name}  installed');
          _logger.info('  Location: ${result.targetPath}');
          successCount++;
        } else {
          progress.fail('$agentName — ${bundle.name}  failed: ${result.error}');
        }
      }
    }

    _logger.info('');
    if (successCount > 0 && successCount == attemptCount) {
      _logger.success(
        'Installed $successCount ${successCount == 1 ? 'command' : 'commands'}.',
      );
    } else if (successCount > 0) {
      _logger.warn(
        'Installed $successCount of $attemptCount commands — see errors above.',
      );
    } else {
      _logger.err('No commands were installed.');
    }

    return successCount > 0 ? ExitCode.success.code : ExitCode.software.code;
  }
}

// ── Status subcommand ───────────────────────────────────────────────────────

class _CommandsStatusCommand extends Command<int> {
  _CommandsStatusCommand({required Logger logger}) : _logger = logger;

  final Logger _logger;

  @override
  String get name => 'status';

  @override
  String get description =>
      'Show which commands are installed in this project.';

  @override
  Future<int> run() async {
    final String repoRoot;
    try {
      repoRoot = await PackageResolver().resolveRepoRoot();
    } catch (e) {
      _logger.err('Could not locate somnio-ai-tools repo: $e');
      return ExitCode.software.code;
    }

    final installer = CommandInstaller(repoRoot: repoRoot);

    _logger.info('');
    _logger.info('Commands Status');
    _logger.info('─' * 50);
    _logger.info('');

    for (final bundle in CommandRegistry.commands) {
      final statuses = <String>[];
      for (final agent in _supportedAgents) {
        final targetDir = CommandInstaller.resolveTargetDir(agent);
        final installed = installer.isInstalled(bundle, targetDir);
        final label = _agentDisplayNames[agent] ?? agent;
        final wrapped =
            installed ? lightGreen.wrap('✓ $label') : darkGray.wrap('✗ $label');
        statuses.add(wrapped ?? (installed ? '✓ $label' : '✗ $label'));
      }
      _logger.info('  ${bundle.name.padRight(18)} ${statuses.join('  |  ')}');
    }

    _logger.info('');
    _logger.info(
      'Run `somnio commands install` to install commands for this project.',
    );

    return ExitCode.success.code;
  }
}
