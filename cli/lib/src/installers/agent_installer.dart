import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../agents/agent_config.dart';
import '../content/skill_bundle.dart';
import '../transformers/claude_transformer.dart';
import '../transformers/transformer.dart';
import '../utils/platform_utils.dart';
import 'installer.dart';

/// Generic installer that works for any [AgentConfig].
///
/// Selects the appropriate transformer via [transformerFor], resolves
/// install paths, and writes files to the agent's install location.
class AgentInstaller extends Installer {
  AgentInstaller({
    required super.logger,
    required super.loader,
    required this.agentConfig,
  });

  final AgentConfig agentConfig;

  String get _home => PlatformUtils.homeDirectory;

  /// Resolves the base install directory for this agent.
  String get _installDir {
    if (agentConfig.installScope == InstallScope.project) {
      // Project-scope agents install relative to cwd
      return agentConfig.installPath;
    }
    return agentConfig.resolvedInstallPath(home: _home);
  }

  @override
  Future<InstallResult> install({
    required List<SkillBundle> bundles,
    bool force = false,
  }) async {
    final baseDir = _installDir;
    final transformer = transformerFor(agentConfig.installFormat);

    var skillCount = 0;
    var ruleCount = 0;
    var skippedCount = 0;

    // Check for existing files upfront for global scope
    if (!force && agentConfig.installScope == InstallScope.global) {
      final existing = _findExistingFiles(baseDir);
      if (existing > 0) {
        final overwrite = logger.confirm(
          'Found $existing existing Somnio '
          '${existing == 1 ? 'file' : 'files'}. Overwrite?',
        );
        if (!overwrite) {
          logger.info('Skipped ${agentConfig.displayName} installation.');
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
        final output = transformer.transform(bundle, loader, agentConfig);

        if (output.skipped) {
          progress.cancel();
          logger.info(
            '  ${lightYellow.wrap('~')} ${bundle.displayName}: '
            '${agentConfig.displayName} support not yet available.',
          );
          logger.info(
            '    Contribute one at: '
            'https://github.com/somnio-software/technology-tools',
          );
          skippedCount++;
          continue;
        }

        // Write all files from the transform output
        for (final entry in output.files.entries) {
          _writeFile(p.join(baseDir, entry.key), entry.value);
          ruleCount++;
        }

        // For singleFile and skillDir formats that also need execution
        // rules (e.g., Cursor installs commands + separate .md rules)
        if (agentConfig.executionRulesPath != null &&
            agentConfig.installFormat != InstallFormat.workflow) {
          final rulesDir = agentConfig.resolvedExecutionRulesPath(
            home: _home,
          );
          _installExecutionRules(bundle, rulesDir);
        }

        skillCount++;
        progress.complete('Installed ${bundle.name}');
      } catch (e) {
        progress.fail('Failed to install ${bundle.name}: $e');
      }
    }

    return InstallResult(
      skillCount: skillCount,
      ruleCount: ruleCount,
      targetDirectory: baseDir,
      skippedCount: skippedCount,
    );
  }

  /// Installs transformed .md rule files for CLI execution (e.g., Cursor).
  void _installExecutionRules(SkillBundle bundle, String rulesBaseDir) {
    final planSubDir = bundle.planSubDir;
    final rulesDir = p.join(rulesBaseDir, planSubDir, 'cursor_rules');

    // Transform YAML rules into .md files
    final rules = loader.loadRules(bundle);
    for (final rule in rules) {
      _writeFile(
        p.join(rulesDir, '${rule.fileName}.md'),
        ClaudeTransformer.ruleToMarkdown(rule),
      );
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
  }

  @override
  bool isInstalled() {
    final dir = Directory(_installDir);
    if (!dir.existsSync()) return false;
    return _findExistingFiles(_installDir) > 0;
  }

  @override
  int installedCount() => _findExistingFiles(_installDir);

  /// Counts existing somnio files in the given directory.
  int _findExistingFiles(String baseDir) {
    final dir = Directory(baseDir);
    if (!dir.existsSync()) return 0;

    final prefix = agentConfig.filePrefix;
    var count = 0;

    for (final entity in dir.listSync()) {
      final name = p.basename(entity.path);
      if (name.startsWith(prefix)) count++;
    }

    return count;
  }

  void _writeFile(String path, String content) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }
}
