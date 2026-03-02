import 'dart:io';

import 'package:path/path.dart' as p;

import '../content/skill_bundle.dart';
import '../transformers/claude_transformer.dart';
import '../utils/platform_utils.dart';
import 'installer.dart';

/// Installs skills into Claude Code's global skill directory.
///
/// Location: `~/.claude/skills/<skill-name>/`
///
/// Prefer using [AgentInstaller] with the Claude [AgentConfig] instead.
/// This class is kept for backward compatibility.
class ClaudeInstaller extends Installer {
  ClaudeInstaller({required super.logger, required super.loader});

  final _transformer = ClaudeTransformer();

  @override
  Future<InstallResult> install({
    required List<SkillBundle> bundles,
    bool force = false,
  }) async {
    final baseDir = PlatformUtils.claudeGlobalSkillsDir;

    var skillCount = 0;
    var ruleCount = 0;

    // Check for existing skills upfront — ask once for all
    if (!force && Directory(baseDir).existsSync()) {
      final existing = Directory(baseDir)
          .listSync()
          .whereType<Directory>()
          .where((d) => p.basename(d.path).startsWith('somnio-'))
          .toList();

      if (existing.isNotEmpty) {
        final overwrite = logger.confirm(
          'Found ${existing.length} existing Somnio skills. Overwrite?',
        );
        if (!overwrite) {
          logger.info('Skipped Claude Code installation.');
          return InstallResult(
            skillCount: 0,
            ruleCount: 0,
            targetDirectory: baseDir,
          );
        }
      }
    }

    for (final bundle in bundles) {
      final progress = logger.progress(
        'Installing ${bundle.name}',
      );

      try {
        final output = _transformer.transformBundle(bundle, loader);

        // Create skill directory
        final skillDir = p.join(baseDir, bundle.name);

        // Write SKILL.md
        _writeFile(p.join(skillDir, 'SKILL.md'), output.skillMd);

        // Write rule files
        final rulesDir = p.join(skillDir, 'rules');
        for (final entry in output.ruleFiles.entries) {
          _writeFile(p.join(rulesDir, entry.key), entry.value);
          ruleCount++;
        }

        // Write template if available
        if (output.templateContent != null &&
            output.templateFileName != null) {
          _writeFile(
            p.join(skillDir, 'templates', output.templateFileName!),
            output.templateContent!,
          );
        }

        skillCount++;
        progress.complete('Installed /${bundle.name}');
      } catch (e) {
        progress.fail('Failed to install ${bundle.name}: $e');
      }
    }

    return InstallResult(
      skillCount: skillCount,
      ruleCount: ruleCount,
      targetDirectory: baseDir,
    );
  }

  @override
  bool isInstalled() {
    final dir = Directory(PlatformUtils.claudeGlobalSkillsDir);
    if (!dir.existsSync()) return false;

    return dir
        .listSync()
        .whereType<Directory>()
        .any((d) => p.basename(d.path).startsWith('somnio-'));
  }

  @override
  int installedCount() {
    final dir = Directory(PlatformUtils.claudeGlobalSkillsDir);
    if (!dir.existsSync()) return 0;

    return dir
        .listSync()
        .whereType<Directory>()
        .where((d) => p.basename(d.path).startsWith('somnio-'))
        .length;
  }

  void _writeFile(String path, String content) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }
}
