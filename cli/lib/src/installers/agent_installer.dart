import 'dart:io';

import 'package:path/path.dart' as p;

import '../agents/agent_config.dart';
import '../agents/installed_skill_names.dart';
import '../content/skill_bundle.dart';
import '../content/workflow_skill.dart';
import '../transformers/claude_transformer.dart';
import '../transformers/transformer.dart';
import '../utils/bundle_file_filter.dart';
import '../utils/platform_utils.dart';
import '../utils/yaml_frontmatter.dart';
import 'installer.dart';
import 'skill_manifest.dart';

/// Generic installer that works for any [AgentConfig].
///
/// Selects the appropriate transformer via [transformerFor], resolves
/// install paths, and writes files to the agent's install location.
class AgentInstaller extends Installer {
  AgentInstaller({
    required super.logger,
    required super.loader,
    required this.agentConfig,
    this.scope = InstallScope.global,
    String? projectRoot,
    this.recordManifest = true,
  }) : projectRoot = projectRoot ?? Directory.current.path;

  final AgentConfig agentConfig;

  /// Whether to install into the agent's global (home-anchored) location or
  /// a project-local one. Defaults to [InstallScope.global] so the four
  /// existing call sites (install/update/setup/status commands and
  /// interactive install) keep today's behavior unchanged.
  final InstallScope scope;

  /// Root directory [InstallScope.project] re-anchors `{home}` at. Defaults
  /// to the current working directory so callers that don't pass it get the
  /// natural "wherever the CLI was invoked" answer.
  final String projectRoot;

  /// Whether to write `.somnio-skills.json`. Always true in normal use; the
  /// escape hatch exists for callers that only probe paths.
  final bool recordManifest;

  String get _home => PlatformUtils.homeDirectory;

  /// Resolves the base install directory for this agent, honouring [scope].
  String get _installDir => agentConfig.resolvedScopedInstallPath(
        scope: scope,
        home: _home,
        projectRoot: projectRoot,
      );

  /// Resolves the execution-rules directory for this agent, honouring
  /// [scope] — a project install must keep its rules alongside the project,
  /// not leak them into the user's global home directory.
  String get _rulesDir => agentConfig.resolvedScopedExecutionRulesPath(
        scope: scope,
        home: _home,
        projectRoot: projectRoot,
      );

  @override
  Future<InstallResult> install({required List<SkillBundle> bundles}) async {
    final baseDir = _installDir;
    final transformer = transformerFor(agentConfig.installFormat);

    // Loaded once up front and saved once at the end: `remove`/`update` need
    // an exact record of what somnio wrote so they can delete precisely
    // those paths instead of guessing from name collisions against the
    // registry (a third-party skill dir that happens to share a name with
    // one of ours must never be touched).
    final manifest = SkillManifest.load(baseDir);

    var skillCount = 0;
    var ruleCount = 0;
    var skippedCount = 0;
    var failedCount = 0;
    final installedSkills = <String>[];
    final failedSkills = <String>[];

    for (final bundle in bundles) {
      try {
        final output = transformer.transform(bundle, loader, agentConfig);

        if (output.skipped) {
          skippedCount++;
          continue;
        }

        final paths = <ManifestPath>[];

        // Prune the bundle's own directory so files a content update renamed
        // or dropped don't survive a reinstall. Only `<baseDir>/<name>/` is
        // somnio-owned — baseDir itself also holds third-party skills.
        if (agentConfig.installFormat == InstallFormat.skillDir) {
          _prune(p.join(baseDir, bundle.name));
          paths.add(ManifestPath(ManifestRoot.install, bundle.name));
        }

        // Write all files from the transform output.
        for (final entry in output.files.entries) {
          _writeFile(baseDir, p.join(baseDir, entry.key), entry.value);
          ruleCount++;
          // Record every individual file for non-skillDir formats: some
          // (e.g. `global_workflows/`) are shared directories other skills
          // also write into, so the directory itself must never be recorded
          // as somnio-owned — only the specific files somnio wrote.
          if (agentConfig.installFormat != InstallFormat.skillDir) {
            paths.add(ManifestPath(ManifestRoot.install, entry.key));
          }
        }

        // For singleFile and skillDir formats that also need execution
        // rules (e.g., Cursor installs commands + separate .md rules)
        if (agentConfig.executionRulesPath != null &&
            agentConfig.installFormat != InstallFormat.workflow) {
          _installExecutionRules(bundle, _rulesDir);
          paths.add(ManifestPath(ManifestRoot.rules, bundle.planSubDir));
        }

        manifest.record(skill: bundle.name, kind: 'audit', paths: paths);

        skillCount++;
        installedSkills.add(bundle.name);
      } catch (e) {
        failedCount++;
        failedSkills.add(bundle.name);
        logger.err('  Failed to install ${bundle.name}: $e');
      }
    }

    if (recordManifest) manifest.save();

    return InstallResult(
      skillCount: skillCount,
      ruleCount: ruleCount,
      targetDirectory: baseDir,
      skippedCount: skippedCount,
      failedCount: failedCount,
      installedSkills: installedSkills,
      failedSkills: failedSkills,
    );
  }

  /// Installs transformed .md rule files for CLI execution (e.g., Cursor).
  void _installExecutionRules(SkillBundle bundle, String rulesBaseDir) {
    final bundleDir = p.join(rulesBaseDir, bundle.planSubDir);

    // Load everything before pruning so a read failure can't leave the user
    // with a wiped install.
    final rules = loader.loadRules(bundle);
    final template = loader.loadTemplate(bundle);

    // The whole per-bundle dir is somnio-owned, so prune it: rules a content
    // update renamed or dropped must not survive a reinstall.
    _prune(bundleDir);

    final rulesDir = p.join(bundleDir, 'references');
    for (final rule in rules) {
      _writeFile(
        rulesBaseDir,
        p.join(rulesDir, '${rule.fileName}.md'),
        ClaudeTransformer.ruleToMarkdown(rule),
      );
    }

    // The template goes in `<planSubDir>/assets/` — a sibling of references/,
    // mirroring the skills/ layout. This is exactly the path AgentResolver
    // computes and the runner's prompts tell the AI to read.
    if (template != null && bundle.templatePath != null) {
      _writeFile(
        rulesBaseDir,
        p.join(bundleDir, 'assets', p.basename(bundle.templatePath!)),
        template,
      );
    }
  }

  /// Installs workflow skills and returns how many were written.
  ///
  /// See [installWorkflowSkillsDetailed] when the failure count is needed too.
  int installWorkflowSkills(List<WorkflowSkill> skills) =>
      installWorkflowSkillsDetailed(skills).installed;

  /// Installs workflow skills (standalone markdown, no YAML rules).
  ///
  /// Produces format-appropriate output for each agent's [InstallFormat]:
  /// - skillDir: `{name}/SKILL.md` with frontmatter
  /// - singleFile: `{name}.md` command file
  /// - workflow: `global_workflows/somnio_{name}.md`
  /// - markdown: `{name_underscored}.md` with header
  WorkflowInstallCounts installWorkflowSkillsDetailed(
    List<WorkflowSkill> skills,
  ) {
    final baseDir = _installDir;
    var count = 0;
    var failed = 0;
    final installedNames = <String>[];
    final failedNames = <String>[];

    // Loaded fresh from disk (not carried over from `install()`) so this
    // method also works standalone; when the two run back-to-back on the
    // same instance/baseDir, `SkillManifest.load` re-reading here picks up
    // whatever `install()` already saved, so entries from both calls end up
    // in the file rather than one clobbering the other.
    final manifest = SkillManifest.load(baseDir);

    for (final skill in skills) {
      try {
        final planPath = p.join(loader.repoRoot, skill.planRelativePath);
        final planFile = File(planPath);
        if (!planFile.existsSync()) continue;

        var content = planFile.readAsStringSync();

        // Strip existing YAML frontmatter so agents that add their own
        // header don't produce duplicate frontmatter.
        if (content.startsWith('---')) {
          final endIndex = content.indexOf('---', 3);
          if (endIndex != -1) {
            content = content.substring(endIndex + 3).trimLeft();
          }
        }

        final format = agentConfig.installFormat;

        // Prefer the authored frontmatter's `description` / `allowed-tools`:
        // the description carries the "Use when …" / "Triggers on: …" clauses
        // that drive skill auto-activation, which the shorter registry display
        // string drops. Falls back to the registry when the file omits them.
        final planFrontmatter =
            loader.loadPlanFrontmatter(skill.planRelativePath);
        final description = planFrontmatter['description'] ?? skill.description;
        final allowedTools = planFrontmatter['allowed-tools'] ??
            'Read, Edit, Write, Grep, Glob, Bash, Agent';

        // Some workflow skills (e.g. workflow-builder) ship a references/
        // directory of markdown files their plan links to. skillDir can
        // install them as sibling files so the plan's relative links
        // resolve; the other formats are a single flat file, so the
        // references are appended inline instead.
        final refsPath = skill.referencesRelativePath;
        final refFiles = <String, String>{};
        if (refsPath != null) {
          final dir = Directory(p.join(loader.repoRoot, refsPath));
          if (dir.existsSync()) {
            for (final f in dir
                .listSync()
                .whereType<File>()
                .where((f) => p.extension(f.path) == '.md')) {
              refFiles[p.basename(f.path)] = f.readAsStringSync();
            }
          }
        }

        switch (format) {
          case InstallFormat.skillDir:
            // Claude Code: directory with SKILL.md + frontmatter
            final skillMd = '---\n'
                'name: ${skill.name}\n'
                'description: >-\n'
                '${foldYamlBlock(description)}'
                'allowed-tools: ${yamlInlineScalar(allowedTools)}\n'
                'user-invocable: true\n'
                '---\n\n'
                '$content';
            // Same as audit bundles: start from a clean, real directory.
            // Pruning unlinks a symlinked skill dir (e.g. one skills.sh put
            // there) instead of writing through it into the shared copy, and
            // drops files a content update renamed or removed.
            _prune(p.join(baseDir, skill.name));
            _writeFile(
              baseDir,
              p.join(baseDir, skill.name, 'SKILL.md'),
              skillMd,
            );
            _installAssetDirectories(skill, baseDir);
            for (final entry in refFiles.entries) {
              _writeFile(
                baseDir,
                p.join(baseDir, skill.name, 'references', entry.key),
                entry.value,
              );
            }
            // The whole directory is somnio-owned — covers SKILL.md,
            // references/, and any asset dirs written above.
            manifest.record(
              skill: skill.name,
              kind: 'workflow',
              paths: [ManifestPath(ManifestRoot.install, skill.name)],
            );

          case InstallFormat.singleFile:
            // Cursor: single .md command file
            _writeFile(
              baseDir,
              p.join(baseDir, '${skill.name}.md'),
              _withInlineReferences(content, refFiles),
            );
            manifest.record(
              skill: skill.name,
              kind: 'workflow',
              paths: [
                ManifestPath(ManifestRoot.install, '${skill.name}.md'),
              ],
            );

          case InstallFormat.workflow:
            // Antigravity: workflow file in global_workflows/
            // Folded block scalar (>-) so descriptions containing ": " are not
            // parsed as a nested mapping key. Matches the skillDir branch.
            final underscored = skill.name.replaceAll('-', '_');
            final wrapped = '---\n'
                'description: >-\n'
                '${foldYamlBlock(description)}'
                '---\n\n'
                '${_withInlineReferences(content, refFiles)}';
            final workflowPath =
                p.join('global_workflows', 'somnio_$underscored.md');
            _writeFile(baseDir, p.join(baseDir, workflowPath), wrapped);
            // Only the specific file is recorded, never the
            // `global_workflows/` directory itself — it's shared with other
            // skills' workflow files, so it must never be deleted wholesale.
            manifest.record(
              skill: skill.name,
              kind: 'workflow',
              paths: [ManifestPath(ManifestRoot.install, workflowPath)],
            );

          case InstallFormat.markdown:
            // Generic markdown: header + description + content.
            // Uses the authored `description` resolved above, like the two
            // branches before it. This format emits no frontmatter, so the
            // blockquote is prose rather than an auto-activation trigger, but
            // the registry string is a short display label — for the 7 shipped
            // workflow skills it drops between a third and four fifths of what
            // the author wrote.
            //
            // Quoted line by line rather than as `> $description`: a literal
            // `|` block (optimize-claude-config authors one) keeps its
            // newlines through the YAML loader, and a bare interpolation would
            // quote only the first line and spill the rest into body prose.
            final underscored = skill.name.replaceAll('-', '_');
            final quoted = description
                .trim()
                .split('\n')
                .map((l) => '> ${l.trim()}'.trimRight())
                .join('\n');
            final buffer = StringBuffer()
              ..writeln('# ${skill.displayName}')
              ..writeln()
              ..writeln(quoted)
              ..writeln()
              ..write(_withInlineReferences(content, refFiles));
            _writeFile(
              baseDir,
              p.join(baseDir, '$underscored.md'),
              buffer.toString(),
            );
            manifest.record(
              skill: skill.name,
              kind: 'workflow',
              paths: [
                ManifestPath(ManifestRoot.install, '$underscored.md'),
              ],
            );
        }

        count++;
        installedNames.add(skill.name);
      } catch (e) {
        failed++;
        failedNames.add(skill.name);
        logger.err('  Failed to install ${skill.name}: $e');
      }
    }

    if (recordManifest) manifest.save();

    return (
      installed: count,
      failed: failed,
      installedNames: installedNames,
      failedNames: failedNames,
    );
  }

  /// Appends [refFiles] inline under headings matching each `references/`
  /// link, for install formats that write a single flat file with no
  /// sibling directory to hold them.
  String _withInlineReferences(String content, Map<String, String> refFiles) {
    if (refFiles.isEmpty) return content;
    final buffer = StringBuffer(content);
    for (final entry in refFiles.entries) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('## references/${entry.key}')
        ..writeln()
        ..write(entry.value);
    }
    return buffer.toString();
  }

  /// Copies each of [skill]'s `assetDirectories` verbatim into the installed
  /// skill directory (e.g. `scripts/`, `config/`), preserving their relative
  /// layout under `<baseDir>/<skill.name>/<dirBaseName>/...`.
  ///
  /// Python bytecode caches (`__pycache__/`, `*.pyc`, `*.pyo`) are skipped.
  ///
  /// Silently skips directories that don't exist in the source repo — a
  /// skill can list a directory it hasn't populated yet without breaking
  /// install.
  void _installAssetDirectories(WorkflowSkill skill, String baseDir) {
    for (final relativeDir in skill.assetDirectories) {
      final sourceDir = Directory(p.join(loader.repoRoot, relativeDir));
      if (!sourceDir.existsSync()) continue;

      final dirName = p.basename(relativeDir);
      for (final entity in sourceDir.listSync(recursive: true)) {
        if (entity is! File) continue;
        final relativePath = p.relative(entity.path, from: sourceDir.path);
        if (isIgnoredBundleFile(relativePath)) continue;
        _writeFile(
          baseDir,
          p.join(baseDir, skill.name, dirName, relativePath),
          entity.readAsStringSync(),
        );
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
    // For workflow format, somnio files live in global_workflows/ subdirectory
    final searchDir = agentConfig.installFormat == InstallFormat.workflow
        ? p.join(baseDir, 'global_workflows')
        : baseDir;
    final dir = Directory(searchDir);
    if (!dir.existsSync()) return 0;

    var count = 0;

    for (final entity in dir.listSync()) {
      final name = p.basename(entity.path);
      if (InstalledSkillNames.matches(agentConfig, name)) count++;
    }

    return count;
  }

  /// Deletes a somnio-owned directory so a reinstall starts from a clean slate.
  ///
  /// A symlink at [path] is unlinked rather than followed — skills.sh installs
  /// some skill dirs as symlinks, and recursing into one would delete the
  /// user's source tree.
  void _prune(String path) {
    final link = Link(path);
    if (link.existsSync()) {
      link.deleteSync();
      return;
    }
    final dir = Directory(path);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  /// Writes [content] to [path], which must lie inside the install [root].
  ///
  /// Guards every write against landing outside somnio's own files: a
  /// symlink at [path] itself is unlinked (only the link) and replaced by a
  /// real file, and a symlinked directory between [root] and [path] makes
  /// the write fail rather than go through it into someone else's tree
  /// (e.g. the shared `~/.agents/skills` copy skills.sh links to). [root]
  /// itself may be a symlink — that is the user's own setup.
  void _writeFile(String root, String path, String content) {
    final relative = p.relative(path, from: root);
    if (p.isAbsolute(relative) || p.split(relative).first == '..') {
      throw ArgumentError.value(path, 'path', 'is outside $root');
    }
    final parts = p.split(relative);
    var current = root;
    for (final part in parts.take(parts.length - 1)) {
      current = p.join(current, part);
      if (FileSystemEntity.isLinkSync(current)) {
        throw FileSystemException(
          'Refusing to write through a symlinked directory',
          current,
        );
      }
    }
    if (FileSystemEntity.isLinkSync(path)) Link(path).deleteSync();

    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }
}
