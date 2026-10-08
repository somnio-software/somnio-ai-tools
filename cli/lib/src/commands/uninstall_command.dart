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
import '../installers/skill_manifest.dart';
import '../installers/skills_sh_cleaner.dart';
import '../utils/package_resolver.dart';
import '../utils/platform_utils.dart';
import '../utils/prompts.dart';
import '../utils/yaml_frontmatter.dart';

/// Uninstalls the somnio CLI itself, optionally taking the installed skills
/// and rules with it.
///
/// Skills are dealt with *before* the CLI is deactivated: once the binary is
/// gone the user has no `somnio skills remove` left to clean them up with, so
/// the choice has to be offered up front rather than left as an exercise.
class UninstallCommand extends Command<int> {
  UninstallCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addFlag(
        'skills',
        help: 'Also remove installed skills and rules. Skips the prompt; '
            'use --no-skills to keep them.',
        defaultsTo: null,
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Skip confirmation prompts.',
      )
      ..addFlag(
        'yes',
        abbr: 'y',
        help: 'Same as --force.',
        negatable: false,
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

  /// `--verbose` output and warnings gathered while the removal spinner is
  /// running, printed once it has stopped so lines never interleave with it.
  final _verboseLines = <String>[];
  final _warnings = <String>[];

  @override
  String get name => 'uninstall';

  @override
  String get description =>
      'Remove the somnio CLI from this machine, asking first whether to '
      'also delete the installed skills and rules.\n'
      '\n'
      'Examples:\n'
      '  somnio uninstall                 # asks about skills, then confirms\n'
      '  somnio uninstall --skills --force\n'
      '  somnio uninstall --no-skills     # remove the CLI, keep the skills';

  @override
  Future<int> run() async {
    final force =
        (argResults!['force'] as bool) || (argResults!['yes'] as bool);
    _verbose = argResults!['verbose'] as bool;
    final skillsFlag = argResults!['skills'] as bool?;

    _logger.info('');
    _logger.warn('This will remove the somnio CLI from your machine.');
    _logger.info('');

    // Ask about skills first: this is the last moment the CLI exists to do
    // it. An explicit --skills/--no-skills wins; with no flag and no terminal
    // to ask on, keep them — deleting a user's content on a guess is worse
    // than leaving it behind, and `somnio skills remove` still exists until
    // the CLI is gone.
    final bool removeSkills;
    if (skillsFlag != null) {
      removeSkills = skillsFlag;
    } else if (Prompts.isInteractive) {
      removeSkills = _logger.confirm(
        'Also remove all installed skills and rules?',
        defaultValue: false,
      );
    } else {
      removeSkills = false;
    }

    if (!force) {
      _logger.info('');
      final confirmed = _logger.confirm(
        removeSkills
            ? 'Remove the somnio CLI and all installed skills?'
            : 'Remove the somnio CLI?',
        defaultValue: false,
      );
      if (!confirmed) {
        _logger.info('');
        _logger.info('Uninstall cancelled.');
        return ExitCode.success.code;
      }
    }
    _logger.info('');

    if (removeSkills) {
      final removeProgress = _logger.progress('Removing skills and rules');

      var removedAnything = removeAgentInstalls(
        home: PlatformUtils.homeDirectory,
        onRemoved: _verbose ? _verboseLines.add : null,
        onWarning: _warnings.add,
      );

      // Covers what the home-scoped sweep above cannot: project-scoped
      // installs, and the `.somnio-skills.json` files themselves.
      removedAnything |= removeManifestTrackedInstalls(
        home: PlatformUtils.homeDirectory,
        projectRoot: Directory.current.path,
        onRemoved: _verbose ? _verboseLines.add : null,
      );

      // Remove agent rules (installed via `somnio rules install`)
      removedAnything |= await _removeRules();

      if (removedAnything) {
        removeProgress.complete('Skills and rules removed');
      } else {
        removeProgress.complete('No skills or rules found');
      }
      _verboseLines.forEach(_logger.info);
      _warnings.forEach(_logger.warn);
    } else {
      _logger.info(
        'Keeping installed skills — remove them later by reinstalling the '
        'CLI and running "somnio skills remove".',
      );
    }

    _logger.info('');
    return _deactivateCli();
  }

  /// Runs `dart pub global deactivate somnio` to remove the CLI binary.
  ///
  /// Deactivating the currently-running package is safe: this process is
  /// already loaded, so it finishes normally — only the next invocation is
  /// gone.
  Future<int> _deactivateCli() async {
    final progress = _logger.progress('Removing the somnio CLI');
    try {
      final result = await Process.run(
        'dart',
        ['pub', 'global', 'deactivate', 'somnio'],
      );

      final stderr = (result.stderr as String).trim();

      // Not activated at all (e.g. installed some other way) is a no-op, not
      // a failure — the desired end state is already true.
      if (result.exitCode != 0 && stderr.contains('No active package')) {
        progress.complete('somnio CLI was not installed via pub global');
        return ExitCode.success.code;
      }

      if (result.exitCode != 0) {
        progress.fail('Failed to remove the CLI');
        if (stderr.isNotEmpty) _logger.err(stderr);
        _logger.info('');
        _logger.info(
          'You can remove it manually:\n'
          '  dart pub global deactivate somnio',
        );
        return ExitCode.software.code;
      }

      progress.complete('somnio CLI removed');
      _logger.info('');
      _logger.info('Thanks for using somnio.');
      return ExitCode.success.code;
    } catch (e) {
      progress.fail('Failed to remove the CLI: $e');
      _logger.info('');
      _logger.info(
        'You can remove it manually:\n'
        '  dart pub global deactivate somnio',
      );
      return ExitCode.software.code;
    }
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
        _verboseLines.add('  Removed ${rule.displayName} $stack rules');
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
        _verboseLines.add(
          '  Removed ${rule.displayName} rules: ${p.basename(filePath)}',
        );
      }
    } else {
      file.writeAsStringSync('$remaining\n');
      if (_verbose) {
        _verboseLines.add(
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
        _verboseLines.add(
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
/// lives directly under its registered `installPath` (by name, and only for
/// locations without a manifest); only Antigravity, which also writes into
/// `global_workflows/`, needs its own remover.
///
/// Somnio skills installed by skills.sh are removed first through
/// [SkillsShCleaner], so only lock-owned Somnio entries go and their agent
/// links and lock entries are cleaned consistently; [environment] supplies
/// its env overrides (default: the process environment).
///
/// Returns `true` if anything was removed. [onRemoved] receives one message per
/// removed entry, for `--verbose` output, and [onWarning] one per skills.sh
/// item that could not be removed. Exposed at the top level (not as a class
/// member) so it can be exercised directly in unit tests without spinning up
/// the full command.
bool removeAgentInstalls({
  required String home,
  Map<String, String>? environment,
  void Function(String message)? onRemoved,
  void Function(String message)? onWarning,
}) {
  final cleaner =
      SkillsShCleaner(homeDirectory: home, environment: environment);
  final skillsSh = cleaner.apply(cleaner.plan());
  final skillsShPaths = [
    ...skillsSh.unlinkedLinks,
    ...skillsSh.deletedCanonicals,
    ...skillsSh.removedDirectories,
  ];
  for (final path in skillsShPaths) {
    onRemoved?.call('  Removed skills.sh copy: $path');
  }
  skillsSh.warnings.forEach(onWarning ?? (_) {});
  var removed = skillsShPaths.isNotEmpty;

  for (final agent in AgentRegistry.installableAgents) {
    removed |= switch (agent.id) {
      // Workflows live one level down, in global_workflows/.
      'antigravity' => _removeAntigravityInstall(agent, home, onRemoved) |
          _removeGenericInstall(agent, home, onRemoved, onWarning),
      _ => _removeGenericInstall(agent, home, onRemoved, onWarning),
    };
  }

  return removed;
}

/// Removes every manifest-recorded install for all registered agents, across
/// both the global ([home]) and project ([projectRoot]) scopes, then the
/// `.somnio-skills.json` manifests themselves.
///
/// [removeAgentInstalls] only sweeps [home] and matches by name, so this is
/// what catches project-scoped installs (`./.claude/skills/...`) and clears
/// the manifest bookkeeping the name-based sweep leaves behind.
///
/// Returns `true` if anything was removed. [onRemoved] receives one message
/// per deleted path, for `--verbose` output. Top-level rather than a class
/// member for the same reason as [removeAgentInstalls]: so it can be tested
/// against a temp directory without spinning up the full command.
bool removeManifestTrackedInstalls({
  required String home,
  required String projectRoot,
  void Function(String message)? onRemoved,
}) {
  var removed = false;

  for (final agent in AgentRegistry.installableAgents) {
    final scopes = [
      InstallScope.global,
      if (agent.supportsProjectScope) InstallScope.project,
    ];

    for (final scope in scopes) {
      final installDir = agent.resolvedScopedInstallPath(
        scope: scope,
        home: home,
        projectRoot: projectRoot,
      );
      final manifest = SkillManifest.load(installDir);
      if (manifest.isEmpty) continue;

      for (final entry in manifest.entries.toList()) {
        for (final path in entry.paths) {
          final base = path.root == ManifestRoot.install
              ? installDir
              : agent.resolvedScopedExecutionRulesPath(
                  scope: scope,
                  home: home,
                  projectRoot: projectRoot,
                );
          final target = p.join(base, path.path);
          if (_deleteEntity(target)) {
            onRemoved?.call('  Removed: $target');
            removed = true;
          }
        }
        manifest.removeEntry(entry.skill);
      }

      // Now empty, so this deletes the manifest file itself.
      manifest.save();
      removed = true;
    }
  }

  return removed;
}

/// Deletes whatever is at [path], unlinking a symlink rather than following
/// it (skills.sh installs some skill dirs as symlinks; recursing through one
/// would delete the user's source tree). Returns whether anything was there.
bool _deleteEntity(String path) {
  final link = Link(path);
  if (link.existsSync()) {
    link.deleteSync();
    return true;
  }
  final dir = Directory(path);
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
    return true;
  }
  final file = File(path);
  if (file.existsSync()) {
    file.deleteSync();
    return true;
  }
  return false;
}

bool _removeAntigravityInstall(
  AgentConfig agent,
  String home,
  void Function(String)? onRemoved,
) {
  final baseDir = agent.resolvedInstallPath(home: home);
  var removed = false;

  // Remove workflow files — unless a manifest records exactly which ones
  // somnio wrote, in which case removeManifestTrackedInstalls handles them.
  final workflowsDir = Directory(p.join(baseDir, 'global_workflows'));
  if (!_hasManifest(baseDir) && workflowsDir.existsSync()) {
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

/// Removes somnio content from [agent]'s global install directory by name,
/// for installs that predate the `.somnio-skills.json` manifest, plus the
/// agent's somnio-owned execution rules.
///
/// A location that has a manifest is not swept by name at all:
/// [removeManifestTrackedInstalls] deletes exactly what it records, so a
/// third-party entry that merely shares a Somnio skill's name survives.
/// Without a manifest, an entry named like a Somnio skill is removed only
/// when it looks like a Somnio install (see [_legacyKeepReason]); anything
/// else is kept and reported to [onWarning]. Links are never followed.
bool _removeGenericInstall(
  AgentConfig agent,
  String home,
  void Function(String)? onRemoved,
  void Function(String)? onWarning,
) {
  final location = agent.resolvedInstallPath(home: home);
  final dir = Directory(location);

  var removed = false;
  if (dir.existsSync() && !_hasManifest(location)) {
    for (final entity in dir.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!InstalledSkillNames.matches(agent, name)) continue;

      final keepReason = _legacyKeepReason(entity, location, name);
      if (keepReason != null) {
        onWarning?.call('Kept ${entity.path}: $keepReason.');
        continue;
      }
      if (entity is Directory) {
        entity.deleteSync(recursive: true);
      } else {
        entity.deleteSync();
      }
      onRemoved?.call('  Removed ${agent.displayName}: $name');
      removed = true;
    }
  }

  removed |= _removeExecutionRulesFor(agent, home, onRemoved);
  return removed;
}

/// Whether [location] has a `.somnio-skills.json` manifest.
bool _hasManifest(String location) =>
    File(p.join(location, SkillManifest.fileName)).existsSync();

/// Why a pre-manifest entry named like the Somnio skill [name] must be kept,
/// or `null` when it looks like a Somnio install and may be removed.
///
/// - A symlink is removed (only the link) when it resolves inside
///   [location]; one pointing outside is not somnio's to touch.
/// - A directory must hold a `SKILL.md` whose frontmatter `name` is [name].
/// - A plain file is removed: the installer writes those under the exact
///   Somnio name and they carry no marker to check.
String? _legacyKeepReason(
  FileSystemEntity entity,
  String location,
  String name,
) {
  if (entity is Link) {
    final String target;
    try {
      target = entity.targetSync();
    } on FileSystemException catch (e) {
      return 'its link target could not be read (${e.message})';
    }
    final resolved = p.normalize(
      p.isAbsolute(target) ? target : p.join(location, target),
    );
    return p.isWithin(location, resolved)
        ? null
        : 'it is a symlink to $target, outside $location';
  }
  if (entity is Directory) {
    final skillFile = File(p.join(entity.path, 'SKILL.md'));
    if (!skillFile.existsSync()) {
      return 'it has no SKILL.md identifying it as the Somnio skill $name';
    }
    final String content;
    try {
      content = skillFile.readAsStringSync();
    } on FileSystemException catch (e) {
      return 'its SKILL.md could not be read (${e.message})';
    }
    return frontmatterName(content) == name
        ? null
        : 'its SKILL.md does not name the Somnio skill $name';
  }
  return null;
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
