// coverage:ignore-file
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import '../agents/installed_skill_names.dart';
import '../content/agent_rule.dart';
import '../content/agent_rule_registry.dart';
import '../installers/rules_installer.dart';
import '../utils/package_resolver.dart';
import '../utils/platform_utils.dart';

/// Removes all Somnio-installed skills, commands, and workflows.
class UninstallCommand extends Command<int> {
  UninstallCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Skip confirmation prompt.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Show each removed file.',
        negatable: false,
      );
  }

  final Logger _logger;
  bool _verbose = false;

  @override
  String get name => 'uninstall';

  @override
  String get description =>
      'Remove all Somnio skills, commands, workflows, and rules.';

  @override
  Future<int> run() async {
    final force = argResults!['force'] as bool;
    _verbose = argResults!['verbose'] as bool;

    _logger.info('');

    if (!force) {
      _logger.warn(
        'This will remove all Somnio skills and rules from all agents.',
      );
      _logger.info('');
      final confirmed = _logger.confirm(
        'Proceed with uninstall?',
        defaultValue: false,
      );
      if (!confirmed) {
        _logger.info('');
        _logger.info('Uninstall cancelled.');
        return ExitCode.success.code;
      }
      _logger.info('');
    }

    final removeProgress = _logger.progress('Removing all installations');

    var removedAnything = removeAgentInstalls(
      home: PlatformUtils.homeDirectory,
      onRemoved: _verbose ? _logger.info : null,
    );

    // Remove agent rules (installed via `somnio rules install`)
    removedAnything |= await _removeRules();

    if (removedAnything) {
      removeProgress.complete('Uninstall complete');
    } else {
      removeProgress.complete('Nothing to uninstall');
    }

    return ExitCode.success.code;
  }

  /// Somnio block markers used by the rules installer for single-file formats.
  static const _beginMarker =
      '<!-- BEGIN SOMNIO RULES — do not edit this block manually -->';
  static const _endMarker = '<!-- END SOMNIO RULES -->';

  /// Removes all agent rules installed via `somnio rules install`.
  ///
  /// For single-file rules (Claude, Windsurf, Copilot, Codex): strips the
  /// somnio block from the file, or deletes the file if it only contains the
  /// block.
  ///
  /// For directory rules (Cursor, Antigravity): removes files prefixed with
  /// `somnio-`.
  Future<bool> _removeRules() async {
    final home = PlatformUtils.homeDirectory;
    var removed = false;

    for (final rule in AgentRuleRegistry.rules) {
      // Try global path
      if (rule.supportsGlobal) {
        final globalPath = rule.resolvedGlobalPath(home);
        final result = await _removeRuleAt(rule, globalPath);
        removed |= result;
      }

      // Try project path (relative to cwd)
      final projectPath = p.join(Directory.current.path, rule.projectPath);
      final result = await _removeRuleAt(rule, projectPath);
      removed |= result;
    }

    return removed;
  }

  /// Removes a single rule installation at [targetPath].
  Future<bool> _removeRuleAt(AgentRule rule, String targetPath) async {
    switch (rule.format) {
      case RulesInstallFormat.singleFile:
        return _removeRuleSingleFile(rule, targetPath);
      case RulesInstallFormat.directory:
        return _removeRuleDirectory(rule, targetPath);
      case RulesInstallFormat.claudeModular:
        return _removeRuleClaudeModular(rule, targetPath);
    }
  }

  /// Uninstalls Claude's hybrid layout: strips the CLAUDE.md block and removes
  /// the rule files somnio installed under `.claude/rules/<stack>/`.
  ///
  /// Only manifest-listed files are deleted — a user's own files in the same
  /// directory are left alone, and the stack dir is removed only once empty.
  Future<bool> _removeRuleClaudeModular(AgentRule rule, String filePath) async {
    var removed = _removeRuleSingleFile(rule, filePath);

    final projectDir = p.dirname(filePath);
    String? repoRoot;
    var repoRootResolved = false;

    for (final stack in rule.stacks) {
      final stackDir = Directory(p.join(projectDir, '.claude', 'rules', stack));
      if (!RulesInstaller.removeManifestFiles(stackDir)) {
        if (!stackDir.existsSync()) continue;

        if (!repoRootResolved) {
          repoRootResolved = true;
          try {
            repoRoot = await PackageResolver().resolveRepoRoot();
          } catch (_) {
            repoRoot = null;
          }
        }

        final fallbackRemoved = repoRoot != null &&
            RulesInstaller.removeKnownAdapterFiles(
              stackDir,
              repoRoot,
              rule.adapterPath,
              stack,
            );
        if (!fallbackRemoved) {
          _logger.warn(
            '  Skipping $stack: no somnio manifest found, '
            'leaving files in place',
          );
          continue;
        }
      }

      if (stackDir.existsSync() && stackDir.listSync().isEmpty) {
        stackDir.deleteSync();
      }
      if (_verbose) {
        _logger.info('  Removed ${rule.displayName} $stack rules');
      }
      removed = true;
    }

    // Tidy empty parents — `.claude/rules/` and `.claude/` if nothing else is
    // there. Leaves user-authored content untouched.
    final rulesDir = Directory(p.join(projectDir, '.claude', 'rules'));
    if (rulesDir.existsSync() && rulesDir.listSync().isEmpty) {
      rulesDir.deleteSync();
    }
    final claudeDir = Directory(p.join(projectDir, '.claude'));
    if (claudeDir.existsSync() && claudeDir.listSync().isEmpty) {
      claudeDir.deleteSync();
    }

    return removed;
  }

  /// Strips the somnio block from a single-file rule. Deletes the file if
  /// only the block remains.
  bool _removeRuleSingleFile(AgentRule rule, String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    final content = file.readAsStringSync();
    final begin = content.indexOf(_beginMarker);
    final end = content.indexOf(_endMarker);
    if (begin == -1 || end == -1 || end <= begin) return false;

    final before = content.substring(0, begin);
    final after = content.substring(end + _endMarker.length);
    final remaining = '$before$after'.trim();

    if (remaining.isEmpty) {
      file.deleteSync();
      if (_verbose) {
        _logger.info(
          '  Removed ${rule.displayName} rules: ${p.basename(filePath)}',
        );
      }
    } else {
      file.writeAsStringSync('$remaining\n');
      if (_verbose) {
        _logger.info(
          '  Stripped Somnio rules block from ${p.basename(filePath)}',
        );
      }
    }
    return true;
  }

  /// Removes somnio-prefixed files from a directory rule installation.
  bool _removeRuleDirectory(AgentRule rule, String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return false;

    var removed = false;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!p.basename(entity.path).startsWith('somnio-')) continue;
      entity.deleteSync();
      if (_verbose) {
        _logger.info(
          '  Removed ${rule.displayName} rule: ${p.relative(entity.path, from: dirPath)}',
        );
      }
      removed = true;
    }
    return removed;
  }
}


/// Removes every somnio-installed skill, command and workflow for all
/// registered agents under [home].
///
/// Every agent is dispatched from this one loop, so the set of agents needing
/// bespoke handling can never drift out of sync with the set the generic
/// cleanup covers. [_removeGenericInstall] handles any agent whose content
/// lives directly under its registered `installPath`; only the two agents that
/// write outside it need their own remover.
///
/// Returns `true` if anything was removed. [onRemoved] receives one message per
/// removed entry, for `--verbose` output. Exposed at the top level (not as a
/// class member) so it can be exercised directly in unit tests without spinning
/// up the full command.
bool removeAgentInstalls({
  required String home,
  void Function(String message)? onRemoved,
}) {
  var removed = false;

  for (final agent in AgentRegistry.installableAgents) {
    removed |= switch (agent.id) {
      // Also writes skills.sh symlinks and the canonical ~/.agents/skills copy.
      'claude' => _removeClaudeInstall(home, onRemoved),
      // Workflows live one level down, in global_workflows/.
      'antigravity' => _removeAntigravityInstall(home, onRemoved) |
          _removeGenericInstall(agent, home, onRemoved),
      _ => _removeGenericInstall(agent, home, onRemoved),
    };
  }

  return removed;
}

bool _removeClaudeInstall(String home, void Function(String)? onRemoved) {
  final names = InstalledSkillNames.all;
  var removed = false;

  final globalDir = Directory(p.join(home, '.claude', 'skills'));
  if (globalDir.existsSync()) {
    for (final name in names) {
      // Remove directories (built-in installer)
      final dir = Directory(p.join(globalDir.path, name));
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
        onRemoved?.call('  Removed Claude skill: $name');
        removed = true;
      }
      // Remove symlinks (skills.sh installer)
      final link = Link(p.join(globalDir.path, name));
      if (link.existsSync()) {
        link.deleteSync();
        onRemoved?.call('  Removed Claude symlink: $name');
        removed = true;
      }
    }
  }

  // ~/.agents/skills/ is skills.sh's canonical location. It is cleaned
  // independently: it outlives ~/.claude/skills/ when the symlinks are gone.
  final agentsDir = Directory(p.join(home, '.agents', 'skills'));
  if (agentsDir.existsSync()) {
    for (final name in names) {
      final dir = Directory(p.join(agentsDir.path, name));
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
        onRemoved?.call('  Removed agents registry: $name');
        removed = true;
      }
    }
  }

  return removed;
}

bool _removeAntigravityInstall(String home, void Function(String)? onRemoved) {
  final baseDir = p.join(home, '.gemini', 'antigravity');
  var removed = false;

  // Remove workflow files
  final workflowsDir = Directory(p.join(baseDir, 'global_workflows'));
  if (workflowsDir.existsSync()) {
    final files = workflowsDir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('somnio_'))
        .toList();

    for (final file in files) {
      final name = p.basename(file.path);
      file.deleteSync();
      onRemoved?.call('  Removed Antigravity workflow: $name');
      removed = true;
    }
  }

  // Remove somnio_rules directory
  final rulesDir = Directory(p.join(baseDir, 'somnio_rules'));
  if (rulesDir.existsSync()) {
    rulesDir.deleteSync(recursive: true);
    onRemoved?.call('  Removed Antigravity rules: somnio_rules/');
    removed = true;
  }

  return removed;
}

bool _removeGenericInstall(
  AgentConfig agent,
  String home,
  void Function(String)? onRemoved,
) {
  final dir = Directory(agent.resolvedInstallPath(home: home));

  var removed = false;
  if (dir.existsSync()) {
    for (final entity in dir.listSync()) {
      if (InstalledSkillNames.matches(agent, p.basename(entity.path))) {
        if (entity is File) {
          entity.deleteSync();
        } else if (entity is Directory) {
          entity.deleteSync(recursive: true);
        }
        onRemoved?.call(
          '  Removed ${agent.displayName}: ${p.basename(entity.path)}',
        );
        removed = true;
      }
    }
  }

  removed |= _removeExecutionRulesFor(agent, home, onRemoved);
  return removed;
}

/// Removes the somnio-owned execution rules directory written by
/// `AgentInstaller._installExecutionRules` (e.g. `~/.codex/somnio_rules/`).
bool _removeExecutionRulesFor(
  AgentConfig agent,
  String home,
  void Function(String)? onRemoved,
) {
  if (agent.executionRulesPath == null) return false;
  final rulesDir = Directory(agent.resolvedExecutionRulesPath(home: home));
  if (!rulesDir.existsSync()) return false;

  rulesDir.deleteSync(recursive: true);
  onRemoved?.call(
    '  Removed ${agent.displayName} rules: ${p.basename(rulesDir.path)}/',
  );
  return true;
}
