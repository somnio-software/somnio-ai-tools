import 'dart:io';

import 'package:path/path.dart' as p;

import '../content/command_bundle.dart';

/// Result of a command installation attempt.
class CommandInstallResult {
  const CommandInstallResult({
    required this.name,
    required this.targetPath,
    required this.success,
    this.error,
  });

  final String name;
  final String targetPath;
  final bool success;
  final String? error;
}

/// Installs command bundles (from root `commands/*.md`) to an agent's
/// project-level commands directory.
///
/// Unlike [RulesInstaller], there is no per-agent transformer: the command
/// markdown format (YAML frontmatter + body) is valid as-is for both Claude
/// and Cursor, so the source file is copied byte-for-byte to
/// `<targetDir>/<bundle.name>.md`.
class CommandInstaller {
  CommandInstaller({required this.repoRoot});

  /// Absolute path to the repository root.
  final String repoRoot;

  /// Installs [bundle] into [targetDir].
  ///
  /// Reads the source file at `<repoRoot>/<bundle.sourceRelativePath>` and
  /// writes it as-is to `<targetDir>/<bundle.name>.md`, creating parent
  /// directories as needed.
  CommandInstallResult install(CommandBundle bundle, String targetDir) {
    final targetPath = p.join(targetDir, '${bundle.name}.md');
    try {
      final source = File(p.join(repoRoot, bundle.sourceRelativePath));
      if (!source.existsSync()) {
        throw Exception('Command file not found: ${source.path}');
      }

      final content = source.readAsStringSync();
      final targetFile = File(targetPath);
      targetFile.parent.createSync(recursive: true);
      targetFile.writeAsStringSync(content);

      return CommandInstallResult(
        name: bundle.name,
        targetPath: targetPath,
        success: true,
      );
    } catch (e) {
      return CommandInstallResult(
        name: bundle.name,
        targetPath: targetPath,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Checks whether [bundle] is currently installed at [targetDir].
  bool isInstalled(CommandBundle bundle, String targetDir) {
    return File(p.join(targetDir, '${bundle.name}.md')).existsSync();
  }

  /// Resolves the project-level commands directory for [agentId].
  ///
  /// Command installs are always project-scoped (never global) — the
  /// directory is resolved relative to [projectDir] or the current working
  /// directory.
  static String resolveTargetDir(String agentId, {String? projectDir}) {
    final base = projectDir ?? Directory.current.path;
    switch (agentId) {
      case 'claude':
        return p.join(base, '.claude', 'commands');
      case 'cursor':
        return p.join(base, '.cursor', 'commands');
      default:
        throw ArgumentError('Unsupported agent for commands install: $agentId');
    }
  }
}
