import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../utils/command_helpers.dart';
import '../utils/platform_utils.dart';

/// Updates the CLI and reinstalls all skills.
///
/// For v2.0.0+, this command cleans up ALL legacy skill installations
/// (both `somnio-*` short names and new descriptive names) and reinstalls
/// via skills.sh (`npx skills add`).
class UpdateCommand extends Command<int> {
  UpdateCommand({required Logger logger}) : _logger = logger {
    argParser.addFlag(
      'legacy',
      help: 'Use built-in installer instead of skills.sh.',
    );
  }

  final Logger _logger;

  static const _repoUrl =
      'https://github.com/somnio-software/technology-tools';
  static const _skillsRepo = 'somnio-software/technology-tools';

  /// All skill directory names to clean up (old + new naming conventions).
  static const _skillNames = [
    // v1.x names (old)
    'somnio-fh',
    'somnio-fp',
    'somnio-nh',
    'somnio-np',
    'somnio-sa',
    'workflow-plan',
    'workflow-run',
    // v2.x names (new)
    'flutter-health-audit',
    'flutter-best-practices',
    'nestjs-health-audit',
    'nestjs-best-practices',
    'security-audit',
    'workflow-builder',
  ];

  /// Cursor command file names to clean up (old + new).
  static const _cursorFiles = [
    'somnio-fh.md',
    'somnio-fp.md',
    'somnio-nh.md',
    'somnio-np.md',
    'somnio-sa.md',
    'workflow-plan.md',
    'workflow-run.md',
    'flutter-health-audit.md',
    'flutter-best-practices.md',
    'nestjs-health-audit.md',
    'nestjs-best-practices.md',
    'security-audit.md',
    'workflow-builder.md',
  ];

  @override
  String get name => 'update';

  @override
  String get description =>
      'Update CLI to latest version and reinstall all skills.';

  @override
  Future<int> run() async {
    final useLegacy = argResults!['legacy'] as bool;

    // ── Step 1: Update CLI from git ───────────────────────────────
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

    // ── Step 2: Clean up ALL old installations ────────────────────
    _logger.info(
      '${lightCyan.wrap('Cleaning')}  Removing old skill installations...',
    );
    _logger.info('');

    final cleanedCount = _cleanAllAgents();

    if (cleanedCount > 0) {
      _logger.success('  Cleaned $cleanedCount old items.');
    } else {
      _logger.info('  No old installations found.');
    }
    _logger.info('');

    // ── Step 3: Reinstall via skills.sh or legacy ─────────────────
    if (useLegacy) {
      _logger.info(
        '${lightCyan.wrap('Installing')}  Using built-in installer...',
      );
      _logger.info('');
      return CommandHelpers.installToDetectedAgents(_logger);
    }

    return _installViaSkillsSh();
  }

  /// Cleans up all Somnio skill files across all agents.
  ///
  /// Removes both v1.x (`somnio-*`) and v2.x (`flutter-health-audit`, etc.)
  /// naming conventions from Claude Code, Cursor, Antigravity, and the
  /// cross-agent registry (`~/.agents/skills/`).
  int _cleanAllAgents() {
    var count = 0;
    count += _cleanClaude();
    count += _cleanCursor();
    count += _cleanAntigravity();
    count += _cleanAgentsRegistry();
    return count;
  }

  /// Removes Somnio skill directories from `~/.claude/skills/`.
  int _cleanClaude() {
    final dir = Directory(PlatformUtils.claudeGlobalSkillsDir);
    if (!dir.existsSync()) return 0;

    var count = 0;
    for (final name in _skillNames) {
      final skillDir = Directory(p.join(dir.path, name));
      if (skillDir.existsSync()) {
        skillDir.deleteSync(recursive: true);
        _logger.info('  Removed Claude: $name');
        count++;
      }
      // Also remove symlinks (skills.sh creates these)
      final link = Link(p.join(dir.path, name));
      if (link.existsSync()) {
        link.deleteSync();
        _logger.info('  Removed Claude symlink: $name');
        count++;
      }
    }
    return count;
  }

  /// Removes Somnio command files from `~/.cursor/commands/`
  /// and rules from `~/.cursor/somnio_rules/`.
  int _cleanCursor() {
    var count = 0;

    // Command files
    final commandsDir = Directory(PlatformUtils.cursorGlobalCommandsDir);
    if (commandsDir.existsSync()) {
      for (final name in _cursorFiles) {
        final file = File(p.join(commandsDir.path, name));
        if (file.existsSync()) {
          file.deleteSync();
          _logger.info('  Removed Cursor: $name');
          count++;
        }
      }
    }

    // Rules directory
    final rulesDir = Directory(PlatformUtils.cursorGlobalRulesDir);
    if (rulesDir.existsSync()) {
      rulesDir.deleteSync(recursive: true);
      _logger.info('  Removed Cursor: somnio_rules/');
      count++;
    }

    return count;
  }

  /// Removes Somnio workflows and rules from Antigravity/Gemini.
  int _cleanAntigravity() {
    final baseDir = PlatformUtils.antigravityGlobalDir;
    var count = 0;

    // Workflow files
    final workflowsDir = Directory(p.join(baseDir, 'global_workflows'));
    if (workflowsDir.existsSync()) {
      for (final entity in workflowsDir.listSync()) {
        if (entity is File && p.basename(entity.path).startsWith('somnio_')) {
          entity.deleteSync();
          _logger.info(
            '  Removed Antigravity: ${p.basename(entity.path)}',
          );
          count++;
        }
      }
    }

    // Rules directory
    final rulesDir = Directory(p.join(baseDir, 'somnio_rules'));
    if (rulesDir.existsSync()) {
      rulesDir.deleteSync(recursive: true);
      _logger.info('  Removed Antigravity: somnio_rules/');
      count++;
    }

    return count;
  }

  /// Removes Somnio skills from the cross-agent registry (`~/.agents/skills/`).
  /// These are the canonical copies that skills.sh creates, with symlinks
  /// from `~/.claude/skills/` pointing to them.
  int _cleanAgentsRegistry() {
    final home = PlatformUtils.homeDirectory;
    final agentsDir = Directory(p.join(home, '.agents', 'skills'));
    if (!agentsDir.existsSync()) return 0;

    var count = 0;
    for (final name in _skillNames) {
      final skillDir = Directory(p.join(agentsDir.path, name));
      if (skillDir.existsSync()) {
        skillDir.deleteSync(recursive: true);
        _logger.info('  Removed agents registry: $name');
        count++;
      }
    }
    return count;
  }

  /// Installs skills via `npx skills add` (skills.sh).
  Future<int> _installViaSkillsSh() async {
    _logger.info(
      '${lightCyan.wrap('Installing')}  Reinstalling skills via skills.sh...',
    );
    _logger.info('');

    // Check if npx is available
    try {
      final which = await Process.run('which', ['npx'], runInShell: true);
      if (which.exitCode != 0) {
        _logger.warn('npx not found. Falling back to built-in installer.');
        _logger.info('');
        return CommandHelpers.installToDetectedAgents(_logger);
      }
    } catch (_) {
      _logger.warn('npx not found. Falling back to built-in installer.');
      _logger.info('');
      return CommandHelpers.installToDetectedAgents(_logger);
    }

    final args = ['skills', 'add', _skillsRepo, '-g', '--all', '-y'];

    _logger.info('  Running: npx ${args.join(' ')}');
    _logger.info('');

    final result = await Process.run(
      'npx',
      args,
      environment: Platform.environment,
      runInShell: true,
    );

    final stdout = (result.stdout as String).trim();
    if (stdout.isNotEmpty) {
      final clean = stdout.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '');
      for (final line in clean.split('\n')) {
        if (line.trim().isNotEmpty) {
          _logger.info('  $line');
        }
      }
    }

    if (result.exitCode != 0) {
      _logger.warn('');
      _logger.warn('skills.sh failed. Falling back to built-in installer.');
      _logger.info('');
      return CommandHelpers.installToDetectedAgents(_logger);
    }

    _logger.info('');
    _logger.success('Update complete! Skills reinstalled via skills.sh.');
    _logger.info('');
    CommandHelpers.printNextSteps(_logger);

    return ExitCode.success.code;
  }
}
