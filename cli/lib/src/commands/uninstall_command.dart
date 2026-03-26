import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import '../content/agent_rule.dart';
import '../content/agent_rule_registry.dart';
import '../utils/platform_utils.dart';

/// Removes all Somnio-installed skills, commands, and workflows.
class UninstallCommand extends Command<int> {
  UninstallCommand({required Logger logger}) : _logger = logger {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Skip confirmation prompt.',
    );
  }

  final Logger _logger;

  @override
  String get name => 'uninstall';

  @override
  String get description =>
      'Remove all Somnio skills, commands, workflows, and rules.';

  @override
  Future<int> run() async {
    final force = argResults!['force'] as bool;

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

    var removedAnything = false;

    // Claude Code: ~/.claude/skills/somnio-*
    final claudeRemoved = _removeClaude();
    removedAnything |= claudeRemoved;

    // Cursor: ~/.cursor/commands/somnio-*.md
    final cursorRemoved = _removeCursor();
    removedAnything |= cursorRemoved;

    // Antigravity: ~/.gemini/antigravity/global_workflows/somnio_* + somnio_rules/
    final antigravityRemoved = _removeAntigravity();
    removedAnything |= antigravityRemoved;

    // Remove files for any other registered agents
    for (final agent in AgentRegistry.installableAgents) {
      if (['claude', 'cursor', 'gemini'].contains(agent.id)) continue;
      final removed = _removeGenericAgent(agent);
      removedAnything |= removed;
    }

    // Remove agent rules (installed via `somnio rules install`)
    final rulesRemoved = _removeRules();
    removedAnything |= rulesRemoved;

    _logger.info('');
    if (removedAnything) {
      _logger.success('Uninstall complete.');
    } else {
      _logger.info('Nothing to uninstall.');
    }

    return ExitCode.success.code;
  }

  /// All skill names to clean up (old v1.x + new v2.x naming).
  static const _allSkillNames = [
    'somnio-fh', 'somnio-fp', 'somnio-nh', 'somnio-np', 'somnio-sa',
    'workflow-plan', 'workflow-run',
    'flutter-health-audit', 'flutter-best-practices',
    'nestjs-health-audit', 'nestjs-best-practices',
    'security-audit', 'workflow-builder',
  ];

  bool _removeClaude() {
    final globalDir = Directory(PlatformUtils.claudeGlobalSkillsDir);
    if (!globalDir.existsSync()) return false;

    var removed = false;
    for (final name in _allSkillNames) {
      // Remove directories (built-in installer)
      final dir = Directory(p.join(globalDir.path, name));
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
        _logger.info('  Removed Claude skill: $name');
        removed = true;
      }
      // Remove symlinks (skills.sh installer)
      final link = Link(p.join(globalDir.path, name));
      if (link.existsSync()) {
        link.deleteSync();
        _logger.info('  Removed Claude symlink: $name');
        removed = true;
      }
    }

    // Also clean ~/.agents/skills/ (skills.sh canonical location)
    final home = PlatformUtils.homeDirectory;
    final agentsDir = Directory(p.join(home, '.agents', 'skills'));
    if (agentsDir.existsSync()) {
      for (final name in _allSkillNames) {
        final dir = Directory(p.join(agentsDir.path, name));
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
          _logger.info('  Removed agents registry: $name');
          removed = true;
        }
      }
    }

    return removed;
  }

  bool _removeCursor() {
    final commandsDir = Directory(PlatformUtils.cursorGlobalCommandsDir);
    if (!commandsDir.existsSync()) return false;

    final files = commandsDir
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.md') && p.basename(f.path).startsWith('somnio-'))
        .toList();

    if (files.isEmpty) return false;

    for (final file in files) {
      final name = p.basename(file.path);
      file.deleteSync();
      _logger.info('  Removed Cursor command: $name');
    }
    return true;
  }

  bool _removeAntigravity() {
    final baseDir = PlatformUtils.antigravityGlobalDir;
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
        _logger.info('  Removed Antigravity workflow: $name');
        removed = true;
      }
    }

    // Remove somnio_rules directory
    final rulesDir = Directory(p.join(baseDir, 'somnio_rules'));
    if (rulesDir.existsSync()) {
      rulesDir.deleteSync(recursive: true);
      _logger.info('  Removed Antigravity rules: somnio_rules/');
      removed = true;
    }

    return removed;
  }

  bool _removeGenericAgent(AgentConfig agent) {
    final home = PlatformUtils.homeDirectory;
    final installDir = agent.resolvedInstallPath(home: home);
    final dir = Directory(installDir);
    if (!dir.existsSync()) return false;

    final prefix = agent.filePrefix;
    var removed = false;
    for (final entity in dir.listSync()) {
      if (p.basename(entity.path).startsWith(prefix)) {
        if (entity is File) {
          entity.deleteSync();
        } else if (entity is Directory) {
          entity.deleteSync(recursive: true);
        }
        _logger.info(
          '  Removed ${agent.displayName}: ${p.basename(entity.path)}',
        );
        removed = true;
      }
    }
    return removed;
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
  bool _removeRules() {
    final home = PlatformUtils.homeDirectory;
    var removed = false;

    for (final rule in AgentRuleRegistry.rules) {
      // Try global path
      if (rule.supportsGlobal) {
        final globalPath = rule.resolvedGlobalPath(home);
        final result = _removeRuleAt(rule, globalPath);
        removed |= result;
      }

      // Try project path (relative to cwd)
      final projectPath = p.join(Directory.current.path, rule.projectPath);
      final result = _removeRuleAt(rule, projectPath);
      removed |= result;
    }

    return removed;
  }

  /// Removes a single rule installation at [targetPath].
  bool _removeRuleAt(AgentRule rule, String targetPath) {
    switch (rule.format) {
      case RulesInstallFormat.singleFile:
        return _removeRuleSingleFile(rule, targetPath);
      case RulesInstallFormat.directory:
        return _removeRuleDirectory(rule, targetPath);
    }
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
      _logger.info('  Removed ${rule.displayName} rules: ${p.basename(filePath)}');
    } else {
      file.writeAsStringSync('$remaining\n');
      _logger.info(
        '  Stripped Somnio rules block from ${p.basename(filePath)}',
      );
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
      _logger.info(
        '  Removed ${rule.displayName} rule: ${p.relative(entity.path, from: dirPath)}',
      );
      removed = true;
    }
    return removed;
  }
}
