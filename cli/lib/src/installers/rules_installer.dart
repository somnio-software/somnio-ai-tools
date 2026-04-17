import 'dart:io';

import 'package:path/path.dart' as p;

import '../content/agent_rule.dart';
import '../utils/platform_utils.dart';

/// Result of a rules installation attempt.
class RulesInstallResult {
  const RulesInstallResult({
    required this.agentId,
    required this.displayName,
    required this.targetPath,
    required this.success,
    this.error,
  });

  final String agentId;
  final String displayName;
  final String targetPath;
  final bool success;
  final String? error;
}

/// Installs agent-rules adapters to global or project-level config paths.
///
/// Adapters are organised per stack (flutter / nestjs / react), so the caller
/// passes the list of stacks to install. Three install shapes are supported:
///
/// - [RulesInstallFormat.singleFile]: concatenates per-stack fragments into a
///   single target file, wrapped in somnio block markers so updates are
///   idempotent.
/// - [RulesInstallFormat.directory]: copies per-stack subdirectories into the
///   target directory, preserving the `<stack>/` subfolder and prefixing each
///   file with `somnio-` so it's easy to spot and uninstall.
/// - [RulesInstallFormat.claudeModular]: Claude's hybrid layout — writes a
///   combined `CLAUDE.md` fragment and a `.claude/rules/<stack>/` tree.
class RulesInstaller {
  RulesInstaller({required this.repoRoot});

  /// Absolute path to the repository root.
  final String repoRoot;

  static const _beginMarker =
      '<!-- BEGIN SOMNIO RULES — do not edit this block manually -->';
  static const _endMarker = '<!-- END SOMNIO RULES -->';

  /// Installs [stacks] of [rule] at [targetPath].
  ///
  /// [targetPath] should already be resolved (no `{home}` placeholders).
  RulesInstallResult install(
    AgentRule rule,
    String targetPath,
    List<String> stacks,
  ) {
    try {
      if (stacks.isEmpty) {
        throw Exception('No stacks selected.');
      }

      switch (rule.format) {
        case RulesInstallFormat.singleFile:
          _installSingleFile(rule, targetPath, stacks);
        case RulesInstallFormat.directory:
          _installDirectory(rule, targetPath, stacks);
        case RulesInstallFormat.claudeModular:
          _installClaudeModular(rule, targetPath, stacks);
      }
      return RulesInstallResult(
        agentId: rule.agentId,
        displayName: rule.displayName,
        targetPath: targetPath,
        success: true,
      );
    } catch (e) {
      return RulesInstallResult(
        agentId: rule.agentId,
        displayName: rule.displayName,
        targetPath: targetPath,
        success: false,
        error: e.toString(),
      );
    }
  }

  // ── Single-file format ──────────────────────────────────────────────────────

  /// Concatenates per-stack fragments into [targetPath], wrapped in somnio
  /// block markers.
  void _installSingleFile(
    AgentRule rule,
    String targetPath,
    List<String> stacks,
  ) {
    final fileName = p.basename(targetPath);
    final buffer = StringBuffer();

    for (final stack in stacks) {
      final source = File(p.join(repoRoot, rule.adapterPath, stack, fileName));
      if (!source.existsSync()) {
        throw Exception('Adapter file not found: ${source.path}');
      }
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(source.readAsStringSync().trim());
      buffer.writeln();
    }

    final block = '$_beginMarker\n${buffer.toString().trim()}\n$_endMarker';
    _writeBlock(File(targetPath), block);
  }

  // ── Directory format ────────────────────────────────────────────────────────

  /// Copies files from `<adapterPath>/<stack>/**` into `<targetDir>/<stack>/`,
  /// prefixing each file with `somnio-`. Previously installed somnio files for
  /// the same stacks are wiped first so uninstall/reinstall is clean.
  void _installDirectory(
    AgentRule rule,
    String targetDir,
    List<String> stacks,
  ) {
    for (final stack in stacks) {
      final sourceDir = Directory(p.join(repoRoot, rule.adapterPath, stack));
      if (!sourceDir.existsSync()) {
        throw Exception('Adapter directory not found: ${sourceDir.path}');
      }

      final stackTarget = Directory(p.join(targetDir, stack));
      _clearSomnioFiles(stackTarget);
      stackTarget.createSync(recursive: true);

      for (final entity in sourceDir.listSync(recursive: true)) {
        if (entity is! File) continue;
        final rel = p.relative(entity.path, from: sourceDir.path);
        final parts = p.split(rel);
        parts[parts.length - 1] = parts.last.startsWith('somnio-')
            ? parts.last
            : 'somnio-${parts.last}';
        final destFile = File(p.joinAll([stackTarget.path, ...parts]));
        destFile.parent.createSync(recursive: true);
        destFile.writeAsStringSync(entity.readAsStringSync());
      }
    }
  }

  // ── Claude modular format ───────────────────────────────────────────────────

  /// Installs Claude's hybrid layout: writes a concatenated `CLAUDE.md`
  /// containing only `@imports`, and copies each selected stack's rule files
  /// under `.claude/rules/<stack>/`.
  void _installClaudeModular(
    AgentRule rule,
    String targetPath,
    List<String> stacks,
  ) {
    final projectDir = p.dirname(targetPath);
    final rulesRoot = Directory(p.join(projectDir, '.claude', 'rules'));

    final buffer = StringBuffer();
    for (final stack in stacks) {
      final fragment = File(
        p.join(repoRoot, rule.adapterPath, stack, 'CLAUDE.md'),
      );
      if (!fragment.existsSync()) {
        throw Exception('Adapter fragment not found: ${fragment.path}');
      }
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(fragment.readAsStringSync().trim());
      buffer.writeln();

      // Copy rule files into .claude/rules/<stack>/
      final stackRulesSrc =
          Directory(p.join(repoRoot, rule.adapterPath, stack, 'rules'));
      if (!stackRulesSrc.existsSync()) {
        throw Exception('Rules directory not found: ${stackRulesSrc.path}');
      }
      final stackRulesDest = Directory(p.join(rulesRoot.path, stack));
      if (stackRulesDest.existsSync()) {
        stackRulesDest.deleteSync(recursive: true);
      }
      stackRulesDest.createSync(recursive: true);

      for (final entity in stackRulesSrc.listSync(recursive: true)) {
        if (entity is! File) continue;
        final rel = p.relative(entity.path, from: stackRulesSrc.path);
        final destFile = File(p.join(stackRulesDest.path, rel));
        destFile.parent.createSync(recursive: true);
        destFile.writeAsStringSync(entity.readAsStringSync());
      }
    }

    final block = '$_beginMarker\n${buffer.toString().trim()}\n$_endMarker';
    _writeBlock(File(targetPath), block);
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────

  void _writeBlock(File targetFile, String block) {
    if (targetFile.existsSync()) {
      final existing = targetFile.readAsStringSync();
      targetFile.parent.createSync(recursive: true);
      targetFile.writeAsStringSync(_replaceOrAppendBlock(existing, block));
    } else {
      targetFile.parent.createSync(recursive: true);
      targetFile.writeAsStringSync('$block\n');
    }
  }

  /// Replaces the somnio block in [content] if present, or appends it.
  String _replaceOrAppendBlock(String content, String block) {
    final begin = content.indexOf(_beginMarker);
    final end = content.indexOf(_endMarker);

    if (begin != -1 && end != -1 && end > begin) {
      final before = content.substring(0, begin);
      final after = content.substring(end + _endMarker.length);
      return '$before$block$after';
    }

    final separator = content.endsWith('\n') ? '\n' : '\n\n';
    return '$content$separator$block\n';
  }

  /// Removes any file starting with `somnio-` in [dir] recursively.
  /// Leaves other user-authored files untouched.
  void _clearSomnioFiles(Directory dir) {
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && p.basename(entity.path).startsWith('somnio-')) {
        entity.deleteSync();
      }
    }
  }

  /// Checks whether rules are currently installed at [targetPath].
  bool isInstalled(AgentRule rule, String targetPath) {
    switch (rule.format) {
      case RulesInstallFormat.singleFile:
      case RulesInstallFormat.claudeModular:
        final file = File(targetPath);
        if (!file.existsSync()) return false;
        return file.readAsStringSync().contains(_beginMarker);
      case RulesInstallFormat.directory:
        final dir = Directory(targetPath);
        if (!dir.existsSync()) return false;
        return dir.listSync(recursive: true).any((e) {
          return e is File && p.basename(e.path).startsWith('somnio-');
        });
    }
  }

  /// Resolves the install path for [rule] based on [scope].
  static String resolveTargetPath(
    AgentRule rule,
    RulesInstallScope scope, {
    String? projectDir,
  }) {
    if (scope == RulesInstallScope.global) {
      return rule.resolvedGlobalPath(PlatformUtils.homeDirectory);
    }
    final base = projectDir ?? Directory.current.path;
    return p.join(base, rule.projectPath);
  }
}

/// Whether to install rules globally or in the current project.
enum RulesInstallScope { global, project }
