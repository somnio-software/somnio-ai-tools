// coverage:ignore-file
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import '../agents/installed_skill_names.dart';
import '../content/skill_registry.dart';
import '../installers/agent_installer.dart';
import '../installers/interactive_install.dart';
import '../utils/agent_detector.dart';
import '../utils/command_helpers.dart';
import '../utils/platform_utils.dart';
import '../utils/prompts.dart';

/// Updates the CLI and reinstalls all skills.
///
/// For v2.0.0+, this command cleans up ALL legacy skill installations
/// (both `somnio-*` short names and new descriptive names) and reinstalls
/// via skills.sh (`npx skills add`).
class UpdateCommand extends Command<int> {
  UpdateCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addFlag(
        'legacy',
        help: 'Use built-in installer instead of skills.sh.',
      )
      ..addFlag(
        'all-skills',
        help: 'Reinstall every skill without prompting for a selection.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Show detailed output for each step.',
        negatable: false,
      )
      ..addFlag(
        'post-update',
        help: 'Internal: run the clean + reinstall steps only.',
        negatable: false,
        hide: true,
      );
  }

  final Logger _logger;

  static const _repoUrl =
      'https://github.com/somnio-software/somnio-ai-tools';
  static const _skillsRepo = 'somnio-software/somnio-ai-tools';

  /// All skill directory names to clean up — every registered skill plus the
  /// v1.x names, derived from the registry so new skills are never missed.
  List<String> get _skillNames => InstalledSkillNames.all;

  /// Cursor command file names to clean up (old + new).
  Set<String> get _cursorFiles =>
      InstalledSkillNames.basenamesFor(AgentRegistry.findById('cursor')!);

  /// Gemini CLI skill file names to clean up (old + new).
  Set<String> get _geminiFiles =>
      InstalledSkillNames.basenamesFor(AgentRegistry.findById('gemini')!);

  @override
  String get name => 'update';

  @override
  String get description =>
      'Update CLI to latest version and reinstall all skills.';

  @override
  Future<int> run() async {
    final useLegacy = argResults!['legacy'] as bool;
    final allSkills = argResults!['all-skills'] as bool;
    final verbose = argResults!['verbose'] as bool;
    final isPostUpdate = argResults!['post-update'] as bool;

    // ── Step 1: Update CLI from git ───────────────────────────────
    if (!isPostUpdate) {
      final updateProgress = _logger.progress('Updating somnio CLI');
      try {
        final result = await Process.run('dart', [
          'pub',
          'global',
          'activate',
          '--source',
          'git',
          _repoUrl,
          '--git-path',
          'cli',
        ]);
        if (result.exitCode != 0) {
          updateProgress.fail('Failed to update CLI');
          _logger.err(result.stderr as String);
          _logger.info('');
          _logger.info(
            'You can update manually:\n'
            '  dart pub global activate --source git $_repoUrl --git-path cli',
          );
          return ExitCode.software.code;
        }
        updateProgress.complete('CLI updated');
      } catch (e) {
        updateProgress.fail('Failed to update CLI: $e');
        return ExitCode.software.code;
      }

      _logger.info('');

      // Steps 2-3 must run the version we just activated, not this process.
      return _runPostUpdate(
        useLegacy: useLegacy,
        allSkills: allSkills,
        verbose: verbose,
      );
    }

    // ── Step 2: Clean up ALL old installations ────────────────────
    final cleanProgress = _logger.progress('Cleaning old skill installations');
    final cleanedCount = _cleanAllAgents(verbose: verbose);
    if (cleanedCount > 0) {
      cleanProgress.complete('Cleaned $cleanedCount old items');
    } else {
      cleanProgress.complete('No old installations found');
    }
    _logger.info('');

    // ── Step 3: Reinstall ─────────────────────────────────────────
    // Interactive terminal → let the user pick which agents and skills to
    // reinstall (same wizard as `somnio install`). Non-interactive (CI,
    // pipes) → reinstall everything so automation never hangs. `--all-skills`
    // forces the install-everything path even in a terminal.
    if (Prompts.isInteractive && !allSkills) {
      return _reinstallInteractive();
    }

    if (useLegacy) {
      _logger.info(
        '${lightCyan.wrap('Installing')}  Using built-in installer...',
      );
      _logger.info('');
      return CommandHelpers.installToDetectedAgents(_logger);
    }

    return _installViaSkillsSh(verbose: verbose);
  }

  /// Re-runs the clean + reinstall steps from the just-activated CLI.
  ///
  /// `dart pub global activate` cannot hot-reload the running process, so the
  /// skill registry and cleanup lists compiled into it are the pre-update ones.
  /// Running the remainder in a child process is what makes a single
  /// `somnio update` pick up skills added by the fetched version. stdio is
  /// inherited so the interactive wizard still works, and `--post-update`
  /// stops the child from updating the CLI again.
  Future<int> _runPostUpdate({
    required bool useLegacy,
    required bool allSkills,
    required bool verbose,
  }) async {
    try {
      final process = await Process.start(
        'dart',
        [
          'pub',
          'global',
          'run',
          'somnio:somnio',
          'update',
          '--post-update',
          if (useLegacy) '--legacy',
          if (allSkills) '--all-skills',
          if (verbose) '--verbose',
        ],
        mode: ProcessStartMode.inheritStdio,
      );
      return process.exitCode;
    } catch (e) {
      _logger.err('Failed to run the updated CLI: $e');
      _logger.info('');
      _logger.info('Run "somnio install" to reinstall your skills.');
      return ExitCode.software.code;
    }
  }

  /// Reinstalls skills through the interactive wizard (agents + skills).
  Future<int> _reinstallInteractive() async {
    final flow = InteractiveInstall(_logger);

    final agents = await flow.promptForAgents();
    if (agents.isEmpty) {
      _logger.info('No agents selected.');
      return ExitCode.success.code;
    }

    final selection = flow.promptForSkills();
    if (selection.isEmpty) {
      _logger.info('No skills selected.');
      return ExitCode.success.code;
    }

    final content = await CommandHelpers.resolveContent();
    final code = await flow.installToAgents(agents, content.loader, selection);

    _logger.info('');
    if (code == ExitCode.success.code) {
      _logger.success('Update complete!');
    }
    _logger.info('');
    CommandHelpers.printNextSteps(_logger);

    return code;
  }

  /// Cleans up all Somnio skill files across all agents.
  ///
  /// Removes both v1.x (`somnio-*`) and v2.x (`flutter-health-audit`, etc.)
  /// naming conventions from Claude Code, Cursor, Antigravity, and the
  /// cross-agent registry (`~/.agents/skills/`).
  int _cleanAllAgents({bool verbose = false}) {
    var count = 0;
    count += _cleanClaude(verbose: verbose);
    count += _cleanCursor(verbose: verbose);
    count += _cleanGemini(verbose: verbose);
    count += _cleanAntigravity(verbose: verbose);
    count += _cleanAgentsRegistry(verbose: verbose);
    return count;
  }

  /// Removes Somnio skill directories from `~/.claude/skills/`.
  int _cleanClaude({bool verbose = false}) {
    final dir = Directory(PlatformUtils.claudeGlobalSkillsDir);
    if (!dir.existsSync()) return 0;

    var count = 0;
    for (final name in _skillNames) {
      final skillDir = Directory(p.join(dir.path, name));
      if (skillDir.existsSync()) {
        skillDir.deleteSync(recursive: true);
        if (verbose) _logger.info('  Removed Claude: $name');
        count++;
      }
      // Also remove symlinks (skills.sh creates these)
      final link = Link(p.join(dir.path, name));
      if (link.existsSync()) {
        link.deleteSync();
        if (verbose) _logger.info('  Removed Claude symlink: $name');
        count++;
      }
    }
    return count;
  }

  /// Removes Somnio command files from `~/.cursor/commands/`
  /// and rules from `~/.cursor/somnio_rules/`.
  int _cleanCursor({bool verbose = false}) {
    var count = 0;

    // Command files
    final commandsDir = Directory(PlatformUtils.cursorGlobalCommandsDir);
    if (commandsDir.existsSync()) {
      for (final name in _cursorFiles) {
        final file = File(p.join(commandsDir.path, name));
        if (file.existsSync()) {
          file.deleteSync();
          if (verbose) _logger.info('  Removed Cursor: $name');
          count++;
        }
      }
    }

    // Rules directory
    final rulesDir = Directory(PlatformUtils.cursorGlobalRulesDir);
    if (rulesDir.existsSync()) {
      rulesDir.deleteSync(recursive: true);
      if (verbose) _logger.info('  Removed Cursor: somnio_rules/');
      count++;
    }

    return count;
  }

  /// Removes Somnio skill markdown files from `~/.gemini/skills/` and the
  /// execution rules from `~/.gemini/somnio_rules/` (Gemini CLI agent).
  ///
  /// Deletes by known name rather than by `somnio_` prefix: the markdown
  /// transformer writes un-prefixed underscored bundle names
  /// (`flutter_health_audit.md`), so a prefix scan would only catch v1.x files.
  int _cleanGemini({bool verbose = false}) {
    final home = PlatformUtils.homeDirectory;
    var count = 0;

    final skillsDir = Directory(p.join(home, '.gemini', 'skills'));
    if (skillsDir.existsSync()) {
      for (final name in _geminiFiles) {
        final file = File(p.join(skillsDir.path, name));
        if (file.existsSync()) {
          file.deleteSync();
          if (verbose) _logger.info('  Removed Gemini: $name');
          count++;
        }
      }
    }

    // Execution rules written by AgentInstaller._installExecutionRules.
    final rulesDir = Directory(p.join(home, '.gemini', 'somnio_rules'));
    if (rulesDir.existsSync()) {
      rulesDir.deleteSync(recursive: true);
      if (verbose) _logger.info('  Removed Gemini: somnio_rules/');
      count++;
    }

    return count;
  }

  /// Removes Somnio workflows and rules from Antigravity/Gemini.
  int _cleanAntigravity({bool verbose = false}) {
    final baseDir = PlatformUtils.antigravityGlobalDir;
    var count = 0;

    // Workflow files
    final workflowsDir = Directory(p.join(baseDir, 'global_workflows'));
    if (workflowsDir.existsSync()) {
      for (final entity in workflowsDir.listSync()) {
        if (entity is File && p.basename(entity.path).startsWith('somnio_')) {
          entity.deleteSync();
          if (verbose) {
            _logger.info('  Removed Antigravity: ${p.basename(entity.path)}');
          }
          count++;
        }
      }
    }

    // Rules directory
    final rulesDir = Directory(p.join(baseDir, 'somnio_rules'));
    if (rulesDir.existsSync()) {
      rulesDir.deleteSync(recursive: true);
      if (verbose) _logger.info('  Removed Antigravity: somnio_rules/');
      count++;
    }

    return count;
  }

  /// Removes Somnio skills from the cross-agent registry (`~/.agents/skills/`).
  /// These are the canonical copies that skills.sh creates, with symlinks
  /// from `~/.claude/skills/` pointing to them.
  int _cleanAgentsRegistry({bool verbose = false}) {
    final home = PlatformUtils.homeDirectory;
    final agentsDir = Directory(p.join(home, '.agents', 'skills'));
    if (!agentsDir.existsSync()) return 0;

    var count = 0;
    for (final name in _skillNames) {
      final skillDir = Directory(p.join(agentsDir.path, name));
      if (skillDir.existsSync()) {
        skillDir.deleteSync(recursive: true);
        if (verbose) _logger.info('  Removed agents registry: $name');
        count++;
      }
    }
    return count;
  }

  /// Installs skills to agents that skills.sh does not cover.
  ///
  /// skills.sh only covers Claude and Cursor. Any agent with its own
  /// [AgentConfig.executionRulesPath] (or [InstallFormat.workflow], e.g.
  /// Antigravity) needs the built-in installer to get its execution rules
  /// written. Returns the total number of failed installs.
  Future<int> _installNonSkillsShAgents() async {
    final detector = AgentDetector();
    final agents = await detector.detect();

    final agentsToInstall = agents.entries
        .where(
          (e) =>
              e.value.installed &&
              (e.key.installFormat == InstallFormat.workflow ||
                  e.key.executionRulesPath != null),
        )
        .map((e) => e.key)
        .toList();

    if (agentsToInstall.isEmpty) return 0;

    final content = await CommandHelpers.resolveContent();
    var totalFailed = 0;

    for (final agentConfig in agentsToInstall) {
      final progress = _logger.progress(agentConfig.displayName);

      final installer = AgentInstaller(
        logger: _logger,
        loader: content.loader,
        agentConfig: agentConfig,
      );
      final result = await installer.install(bundles: content.bundles);
      final wf = installer.installWorkflowSkillsDetailed(
        SkillRegistry.workflowSkills,
      );
      totalFailed += result.failedCount + wf.failed;

      progress.complete(
        '${agentConfig.displayName}  '
        '${CommandHelpers.installSummary(result, agentConfig, extraCount: wf.installed)}',
      );
    }

    return totalFailed;
  }

  /// Installs skills via `npx skills add` (skills.sh).
  Future<int> _installViaSkillsSh({bool verbose = false}) async {
    final installProgress = _logger.progress('Reinstalling skills');

    // Check if npx is available
    try {
      final which = await Process.run('which', ['npx'], runInShell: true);
      if (which.exitCode != 0) {
        installProgress.fail('npx not found — falling back to built-in installer');
        _logger.info('');
        return CommandHelpers.installToDetectedAgents(_logger);
      }
    } catch (_) {
      installProgress.fail('npx not found — falling back to built-in installer');
      _logger.info('');
      return CommandHelpers.installToDetectedAgents(_logger);
    }

    final args = ['skills', 'add', _skillsRepo, '-g', '--all', '-y'];

    if (verbose) {
      installProgress.complete('Running: npx ${args.join(' ')}');
      _logger.info('');
    }

    final result = await Process.run(
      'npx',
      args,
      environment: Platform.environment,
      runInShell: true,
    );

    if (verbose) {
      final stdout = (result.stdout as String).trim();
      if (stdout.isNotEmpty) {
        final clean = stdout.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '');
        for (final line in clean.split('\n')) {
          if (line.trim().isNotEmpty) {
            _logger.info('  $line');
          }
        }
      }
    }

    if (result.exitCode != 0) {
      if (!verbose) installProgress.fail('skills.sh failed — falling back to built-in installer');
      _logger.info('');
      return CommandHelpers.installToDetectedAgents(_logger);
    }

    if (!verbose) installProgress.complete('Skills reinstalled');

    // skills.sh only covers Claude/Cursor. Install to the remaining agents
    // via the built-in installer.
    final failed = await _installNonSkillsShAgents();

    _logger.info('');
    if (failed > 0) {
      _logger.err('Update finished with $failed failed install(s).');
    } else {
      _logger.success('Update complete! Skills reinstalled via skills.sh.');
    }
    _logger.info('');
    CommandHelpers.printNextSteps(_logger);

    return failed > 0 ? ExitCode.software.code : ExitCode.success.code;
  }
}