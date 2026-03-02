import 'dart:io';

import 'package:path/path.dart' as p;

import '../content/content_loader.dart';
import '../content/skill_bundle.dart';
import '../transformers/cursor_transformer.dart';
import '../utils/platform_utils.dart';
import 'installer.dart';

/// Installs commands into Cursor's global commands directory.
///
/// Cursor commands are plain `.md` files triggered via `/command-name`
/// in chat. Each skill becomes a single command file.
///
/// Location: `~/.cursor/commands/`
///
/// Prefer using [AgentInstaller] with the Cursor [AgentConfig] instead.
/// This class is kept for backward compatibility.
class CursorInstaller extends Installer {
  CursorInstaller({required super.logger, required super.loader});

  final _transformer = CursorTransformer();

  @override
  Future<InstallResult> install({
    required List<SkillBundle> bundles,
    bool force = false,
  }) async {
    final targetDir = PlatformUtils.cursorGlobalCommandsDir;

    var commandCount = 0;

    // Check for existing files
    if (!force && Directory(targetDir).existsSync()) {
      final existing = Directory(targetDir)
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.md') &&
              p.basename(f.path).startsWith('somnio-'))
          .toList();

      if (existing.isNotEmpty) {
        final overwrite = logger.confirm(
          'Found ${existing.length} existing Somnio commands. Overwrite?',
        );
        if (!overwrite) {
          logger.info('Skipped Cursor installation.');
          return InstallResult(
            skillCount: 0,
            ruleCount: 0,
            targetDirectory: targetDir,
          );
        }
      }
    }

    final rulesBaseDir = PlatformUtils.cursorGlobalRulesDir;
    var ruleCount = 0;

    for (final bundle in bundles) {
      final progress = logger.progress(
        'Installing /${bundle.name} command',
      );

      try {
        final output = _transformer.transformBundle(bundle, loader);

        for (final entry in output.commandFiles.entries) {
          _writeFile(p.join(targetDir, entry.key), entry.value);
          commandCount++;
        }

        // Also install transformed .md rule files for Cursor CLI (`agent`)
        final planSubDir = bundle.planSubDir;
        final rulesDir = p.join(rulesBaseDir, planSubDir, 'cursor_rules');

        // Transform YAML rules into .md files (same as Claude)
        final rules = loader.loadRules(bundle);
        for (final rule in rules) {
          _writeFile(
            p.join(rulesDir, '${rule.fileName}.md'),
            _ruleToMarkdown(rule),
          );
          ruleCount++;
        }

        // Copy template files as-is
        final allFiles = loader.listAllRuleFiles(bundle);
        for (final relativePath in allFiles) {
          if (relativePath.startsWith('templates/')) {
            final absPath = loader.rulesFilePath(bundle, relativePath);
            final content = File(absPath).readAsStringSync();
            _writeFile(p.join(rulesDir, relativePath), content);
          }
        }

        progress.complete(
          'Installed /${bundle.name} command + $ruleCount rule files',
        );
      } catch (e) {
        progress.fail('Failed to install ${bundle.name}: $e');
      }
    }

    return InstallResult(
      skillCount: commandCount,
      ruleCount: ruleCount,
      targetDirectory: targetDir,
    );
  }

  @override
  bool isInstalled() {
    final dir = Directory(PlatformUtils.cursorGlobalCommandsDir);
    if (!dir.existsSync()) return false;

    return dir
        .listSync()
        .whereType<File>()
        .any((f) =>
            f.path.endsWith('.md') &&
            p.basename(f.path).startsWith('somnio-'));
  }

  @override
  int installedCount() {
    final dir = Directory(PlatformUtils.cursorGlobalCommandsDir);
    if (!dir.existsSync()) return 0;

    return dir
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.md') &&
            p.basename(f.path).startsWith('somnio-'))
        .length;
  }

  /// Converts a parsed YAML rule into a markdown file.
  String _ruleToMarkdown(ParsedRule rule) {
    final buffer = StringBuffer();
    buffer.writeln('# ${rule.name}');
    buffer.writeln();
    buffer.writeln('> ${rule.description}');
    buffer.writeln();
    buffer.writeln('**File pattern**: `${rule.match}`');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    buffer.write(rule.prompt);
    if (!rule.prompt.endsWith('\n')) {
      buffer.writeln();
    }
    return buffer.toString();
  }

  void _writeFile(String path, String content) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }
}
