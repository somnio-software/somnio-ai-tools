import 'dart:io';

import 'package:path/path.dart' as p;

import '../agents/agent_config.dart';
import '../content/skill_bundle.dart';
import '../content/workflow_skill.dart';
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
  String get _installDir => agentConfig.resolvedInstallPath(home: _home);

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

    for (final bundle in bundles) {
      try {
        final output = transformer.transform(bundle, loader, agentConfig);

        if (output.skipped) {
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
      } catch (e) {
        logger.err('  Failed to install ${bundle.name}: $e');
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
    final rulesDir = p.join(rulesBaseDir, planSubDir, 'references');

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
      if (relativePath.startsWith('assets/')) {
        final absPath = loader.rulesFilePath(bundle, relativePath);
        final content = File(absPath).readAsStringSync();
        _writeFile(p.join(rulesDir, relativePath), content);
      }
    }
  }

  /// Installs workflow skills (standalone markdown, no YAML rules).
  ///
  /// Produces format-appropriate output for each agent's [InstallFormat]:
  /// - skillDir: `{name}/SKILL.md` with frontmatter
  /// - singleFile: `{name}.md` command file
  /// - workflow: `global_workflows/somnio_{name}.md`
  /// - markdown: `{name_underscored}.md` with header
  int installWorkflowSkills(List<WorkflowSkill> skills) {
    final baseDir = _installDir;
    var count = 0;

    for (final skill in skills) {
      try {
        final planPath = p.join(loader.repoRoot, skill.planRelativePath);
        final planFile = File(planPath);
        if (!planFile.existsSync()) continue;

        final content = planFile.readAsStringSync();
        final format = agentConfig.installFormat;

        switch (format) {
          case InstallFormat.skillDir:
            // Claude Code: directory with SKILL.md + frontmatter
            final skillMd = '---\n'
                'name: ${skill.name}\n'
                'description: >-\n'
                '  ${skill.description}\n'
                'allowed-tools: Read, Edit, Write, Grep, Glob, Bash, Agent\n'
                'user-invocable: true\n'
                '---\n\n'
                '$content';
            _writeFile(p.join(baseDir, skill.name, 'SKILL.md'), skillMd);

          case InstallFormat.singleFile:
            // Cursor: single .md command file
            _writeFile(p.join(baseDir, '${skill.name}.md'), content);

          case InstallFormat.workflow:
            // Antigravity: workflow file in global_workflows/
            final underscored = skill.name.replaceAll('-', '_');
            final wrapped = '---\n'
                'description: ${skill.description}\n'
                '---\n\n'
                '$content';
            _writeFile(
              p.join(baseDir, 'global_workflows', 'somnio_$underscored.md'),
              wrapped,
            );

          case InstallFormat.markdown:
            // Generic markdown: header + description + content
            final underscored = skill.name.replaceAll('-', '_');
            final buffer = StringBuffer()
              ..writeln('# ${skill.displayName}')
              ..writeln()
              ..writeln('> ${skill.description}')
              ..writeln()
              ..write(content);
            _writeFile(
              p.join(baseDir, '$underscored.md'),
              buffer.toString(),
            );
        }

        count++;
      } catch (e) {
        logger.err('  Failed to install ${skill.name}: $e');
      }
    }

    return count;
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
    // For workflow format, somnio files live in global_workflows/ subdirectory
    final searchDir = agentConfig.installFormat == InstallFormat.workflow
        ? p.join(baseDir, 'global_workflows')
        : baseDir;
    final dir = Directory(searchDir);
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
