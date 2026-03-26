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
/// Supports two install formats:
/// - [RulesInstallFormat.singleFile]: Writes content wrapped in somnio block
///   markers, making updates idempotent.
/// - [RulesInstallFormat.directory]: Copies all files from the adapter dir to
///   the target dir, prefixed with `somnio-`.
class RulesInstaller {
  RulesInstaller({required this.repoRoot});

  /// Absolute path to the repository root.
  final String repoRoot;

  static const _beginMarker =
      '<!-- BEGIN SOMNIO RULES — do not edit this block manually -->';
  static const _endMarker = '<!-- END SOMNIO RULES -->';

  /// Installs rules for [rule] at the given [targetPath].
  ///
  /// [targetPath] should already be resolved (no `{home}` placeholders).
  RulesInstallResult install(AgentRule rule, String targetPath) {
    try {
      switch (rule.format) {
        case RulesInstallFormat.singleFile:
          _installSingleFile(rule, targetPath);
        case RulesInstallFormat.directory:
          _installDirectory(rule, targetPath);
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

  /// Installs a single-file adapter, wrapping content in somnio block markers.
  ///
  /// Idempotent: if the file already contains a somnio block, it is replaced.
  void _installSingleFile(AgentRule rule, String targetPath) {
    final sourcePath = p.join(repoRoot, rule.adapterPath);
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      throw Exception('Adapter file not found: $sourcePath');
    }

    final adapterContent = sourceFile.readAsStringSync();
    final block = '$_beginMarker\n$adapterContent\n$_endMarker';

    final targetFile = File(targetPath);

    if (targetFile.existsSync()) {
      final existing = targetFile.readAsStringSync();
      final updated = _replaceOrAppendBlock(existing, block);
      targetFile.parent.createSync(recursive: true);
      targetFile.writeAsStringSync(updated);
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
      // Replace existing block (keep surrounding content)
      final before = content.substring(0, begin);
      final after = content.substring(end + _endMarker.length);
      return '$before$block$after';
    }

    // No existing block — append with a blank line separator
    final separator = content.endsWith('\n') ? '\n' : '\n\n';
    return '$content$separator$block\n';
  }

  /// Copies all files from the adapter directory to [targetDir], prefixed
  /// with `somnio-` to allow easy identification and uninstall.
  void _installDirectory(AgentRule rule, String targetDir) {
    final sourceDir = Directory(p.join(repoRoot, rule.adapterPath));
    if (!sourceDir.existsSync()) {
      throw Exception('Adapter directory not found: ${sourceDir.path}');
    }

    final target = Directory(targetDir);
    target.createSync(recursive: true);

    for (final entity in sourceDir.listSync(recursive: true)) {
      if (entity is! File) continue;

      // Compute path relative to sourceDir
      final relative = p.relative(entity.path, from: sourceDir.path);
      final parts = p.split(relative);

      // Prefix the leaf filename with 'somnio-'
      final fileName = parts.last;
      final prefixed = fileName.startsWith('somnio-')
          ? fileName
          : 'somnio-$fileName';
      parts[parts.length - 1] = prefixed;

      final destPath = p.joinAll([targetDir, ...parts]);
      final destFile = File(destPath);
      destFile.parent.createSync(recursive: true);
      destFile.writeAsStringSync(entity.readAsStringSync());
    }
  }

  /// Checks whether rules are currently installed at [targetPath].
  bool isInstalled(AgentRule rule, String targetPath) {
    switch (rule.format) {
      case RulesInstallFormat.singleFile:
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
