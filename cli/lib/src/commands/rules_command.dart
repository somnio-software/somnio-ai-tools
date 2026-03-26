import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../agents/agent_registry.dart';
import '../content/agent_rule.dart';
import '../content/agent_rule_registry.dart';
import '../installers/rules_installer.dart';
import '../utils/package_resolver.dart';
import '../utils/platform_utils.dart';

/// Top-level `somnio rules` command — install and inspect agent coding rules.
///
/// Subcommands:
///   somnio rules install   — install rules to an agent (global or project)
///   somnio rules status    — show which agents have rules installed
class RulesCommand extends Command<int> {
  RulesCommand({required Logger logger}) {
    addSubcommand(_RulesInstallCommand(logger: logger));
    addSubcommand(_RulesStatusCommand(logger: logger));
  }

  @override
  String get name => 'rules';

  @override
  String get description =>
      'Install agent coding standards (NestJS & Flutter rules) globally '
      'or per project.';
}

// ── Install subcommand ────────────────────────────────────────────────────────

class _RulesInstallCommand extends Command<int> {
  _RulesInstallCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'agent',
      abbr: 'a',
      help: 'Target agent (e.g., claude, cursor, windsurf).',
      allowed: AgentRuleRegistry.rules.map((r) => r.agentId).toList(),
    );
    argParser.addFlag(
      'all',
      help: 'Install to all detected agents.',
    );
    argParser.addFlag(
      'global',
      abbr: 'g',
      help: 'Install globally (agent config dir). Mutually exclusive with --project.',
    );
    argParser.addFlag(
      'project',
      abbr: 'p',
      help: 'Install in the current project directory. Mutually exclusive with --global.',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Overwrite without prompting.',
    );
  }

  final Logger _logger;

  @override
  String get name => 'install';

  @override
  String get description =>
      'Install agent coding rules globally or in the current project.\n'
      '\n'
      'Examples:\n'
      '  somnio rules install                          # interactive\n'
      '  somnio rules install --agent claude --global  # non-interactive\n'
      '  somnio rules install --all --project          # all detected, project scope';

  @override
  Future<int> run() async {
    final agentId = argResults!['agent'] as String?;
    final installAll = argResults!['all'] as bool;
    final forceGlobal = argResults!['global'] as bool;
    final forceProject = argResults!['project'] as bool;

    if (forceGlobal && forceProject) {
      _logger.err('Use either --global or --project, not both.');
      return ExitCode.usage.code;
    }

    // Resolve repo root for the installer
    final String repoRoot;
    try {
      repoRoot = await PackageResolver().resolveRepoRoot();
    } catch (e) {
      _logger.err('Could not locate somnio-ai-tools repo: $e');
      return ExitCode.software.code;
    }

    final installer = RulesInstaller(repoRoot: repoRoot);

    // ── Detect agents ───────────────────────────────────────────────
    _logger.info('');
    _logger.info('Detecting agents on your machine...');

    final checks = await _detectAgents();

    _logger.info('');
    final detected = checks.where((c) => c.detected).length;
    for (var i = 0; i < checks.length; i++) {
      final check = checks[i];
      final mark =
          check.detected ? lightGreen.wrap('✓') : lightRed.wrap('✗');
      final suffix =
          check.detected ? '  (${check.path})' : '  (not found)';
      _logger.info('  ${i + 1}) $mark ${check.rule.displayName}$suffix');
    }
    _logger.info(
      '  ${checks.length + 1}) All detected agents ($detected)',
    );
    _logger.info('');

    // ── Select agents ───────────────────────────────────────────────
    List<_AgentRuleCheck> targets;

    if (installAll) {
      targets = checks.where((c) => c.detected).toList();
      if (targets.isEmpty) {
        _logger.warn('No supported agents detected.');
        _logger.info(
          'Run `somnio rules install --agent <id>` to install for a '
          'specific agent regardless.',
        );
        return ExitCode.success.code;
      }
    } else if (agentId != null) {
      final rule = AgentRuleRegistry.findById(agentId);
      if (rule == null) {
        _logger.err('No agent-rules adapter found for: $agentId');
        return ExitCode.usage.code;
      }
      targets = [
        checks.firstWhere(
          (c) => c.rule.agentId == agentId,
          orElse: () => _AgentRuleCheck(rule: rule, detected: false),
        ),
      ];
    } else {
      // Interactive: numbered prompt avoids ANSI redraw flicker
      // that chooseOne causes on each keystroke.
      final input = _logger.prompt(
        'Select agent (1-${checks.length + 1})',
      );
      final choice = int.tryParse(input.trim());

      if (choice == null || choice < 1 || choice > checks.length + 1) {
        _logger.err('Invalid selection: $input');
        return ExitCode.usage.code;
      }

      if (choice == checks.length + 1) {
        targets = checks.where((c) => c.detected).toList();
        if (targets.isEmpty) {
          _logger.warn('No supported agents detected.');
          return ExitCode.success.code;
        }
      } else {
        targets = [checks[choice - 1]];
      }
    }

    // ── Select scope ────────────────────────────────────────────────
    RulesInstallScope scope;

    if (forceGlobal) {
      scope = RulesInstallScope.global;
    } else if (forceProject) {
      scope = RulesInstallScope.project;
    } else {
      _logger.info('  1) global (agent config dir)');
      _logger.info('  2) project (current directory)');
      _logger.info('');
      final scopeInput = _logger.prompt('Install scope (1-2)');
      final scopeChoice = int.tryParse(scopeInput.trim());
      if (scopeChoice == 1) {
        scope = RulesInstallScope.global;
      } else if (scopeChoice == 2) {
        scope = RulesInstallScope.project;
      } else {
        _logger.err('Invalid selection: $scopeInput');
        return ExitCode.usage.code;
      }
    }

    // ── Install ─────────────────────────────────────────────────────
    var successCount = 0;

    for (final check in targets) {
      final rule = check.rule;

      if (scope == RulesInstallScope.global && !rule.supportsGlobal) {
        _logger.warn(
          '  ${rule.displayName}: no global config path defined — '
          'use --project to install in a project instead.',
        );
        continue;
      }

      final targetPath = RulesInstaller.resolveTargetPath(rule, scope);
      final progress = _logger.progress('${rule.displayName}');

      final result = installer.install(rule, targetPath);

      if (result.success) {
        final scopeLabel =
            scope == RulesInstallScope.global ? 'global' : 'project';
        progress.complete(
          '${rule.displayName}  rules installed ($scopeLabel)',
        );
        _logger.info('  Location: $targetPath');
        successCount++;
      } else {
        progress.fail('${rule.displayName}  failed: ${result.error}');
      }
    }

    _logger.info('');
    if (successCount > 0) {
      _logger.success(
        'Rules installed for $successCount '
        '${successCount == 1 ? 'agent' : 'agents'}.',
      );
    } else {
      _logger.err('No rules were installed.');
    }

    return ExitCode.success.code;
  }

  /// Detects which supported agents are available on the machine.
  ///
  /// Mirrors [AgentDetector._detectAgent] logic: checks binary, then
  /// detectionBinaries, then detectionPaths, then installPath fallback.
  Future<List<_AgentRuleCheck>> _detectAgents() async {
    final results = <_AgentRuleCheck>[];

    for (final rule in AgentRuleRegistry.rules) {
      final agentConfig = AgentRegistry.findById(rule.agentId);
      String? path;

      if (agentConfig != null) {
        // 1. Check primary binary on PATH
        if (agentConfig.binary != null) {
          path = await PlatformUtils.whichBinary(agentConfig.binary!);
        }

        // 2. Check additional detection binaries
        if (path == null) {
          for (final bin in agentConfig.detectionBinaries) {
            path = await PlatformUtils.whichBinary(bin);
            if (path != null) break;
          }
        }

        // 3. Check detection paths (app bundles, etc.)
        if (path == null) {
          for (final detPath in agentConfig.detectionPaths) {
            final resolved = detPath.replaceAll(
              '{home}',
              PlatformUtils.homeDirectory,
            );
            if (await _pathExists(resolved)) {
              path = resolved;
              break;
            }
          }
        }

        // 4. Check install directory (installed but binary not in PATH)
        if (path == null) {
          final home = PlatformUtils.homeDirectory;
          final installDir = agentConfig.resolvedInstallPath(home: home);
          if (await _pathExists(installDir)) {
            path = installDir;
          }
        }
      }

      results.add(_AgentRuleCheck(
        rule: rule,
        detected: path != null,
        path: path,
      ));
    }

    return results;
  }

  Future<bool> _pathExists(String path) async {
    try {
      return await Future.value(
        Directory(path).existsSync() || File(path).existsSync(),
      );
    } catch (_) {
      return false;
    }
  }
}

// ── Status subcommand ─────────────────────────────────────────────────────────

class _RulesStatusCommand extends Command<int> {
  _RulesStatusCommand({required Logger logger}) : _logger = logger;

  final Logger _logger;

  @override
  String get name => 'status';

  @override
  String get description => 'Show which agents have rules installed.';

  @override
  Future<int> run() async {
    final String repoRoot;
    try {
      repoRoot = await PackageResolver().resolveRepoRoot();
    } catch (e) {
      _logger.err('Could not locate somnio-ai-tools repo: $e');
      return ExitCode.software.code;
    }

    final installer = RulesInstaller(repoRoot: repoRoot);

    _logger.info('');
    _logger.info('Agent Rules Status');
    _logger.info('─' * 50);
    _logger.info('');

    for (final rule in AgentRuleRegistry.rules) {
      final globalPath = rule.supportsGlobal
          ? rule.resolvedGlobalPath(PlatformUtils.homeDirectory)
          : null;
      final projectPath = RulesInstaller.resolveTargetPath(
        rule,
        RulesInstallScope.project,
      );

      final globalInstalled =
          globalPath != null && installer.isInstalled(rule, globalPath);
      final projectInstalled = installer.isInstalled(rule, projectPath);

      final globalStatus = rule.supportsGlobal
          ? (globalInstalled ? lightGreen.wrap('✓ global') : darkGray.wrap('✗ global'))
          : darkGray.wrap('— global n/a');
      final projectStatus = projectInstalled
          ? lightGreen.wrap('✓ project')
          : darkGray.wrap('✗ project');

      _logger.info(
        '  ${rule.displayName.padRight(20)} $globalStatus  |  $projectStatus',
      );
    }

    _logger.info('');
    _logger.info(
      'Run `somnio rules install` to install rules for an agent.',
    );

    return ExitCode.success.code;
  }
}

// ── Helper types ──────────────────────────────────────────────────────────────

class _AgentRuleCheck {
  const _AgentRuleCheck({
    required this.rule,
    required this.detected,
    this.path,
  });

  final AgentRule rule;
  final bool detected;
  final String? path;
}
