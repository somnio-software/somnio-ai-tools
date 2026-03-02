import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../agents/agent_registry.dart';
import '../content/content_loader.dart';
import '../content/skill_registry.dart';
import '../installers/agent_installer.dart';
import '../utils/agent_detector.dart';
import '../utils/cli_installer.dart';
import '../utils/package_resolver.dart';

/// Full guided setup wizard.
///
/// Walks the user through:
/// 1. CLI detection and installation
/// 2. Technology selection
/// 3. Skill installation to all detected agents
///
/// Designed for first-time users with zero prior setup knowledge.
class SetupCommand extends Command<int> {
  SetupCommand({required Logger logger}) : _logger = logger {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Skip prompts, install all CLIs and technologies.',
    );
  }

  final Logger _logger;

  @override
  String get name => 'setup';

  @override
  String get description =>
      'Full guided setup: install CLIs, detect agents, and install skills.';

  @override
  Future<int> run() async {
    final force = argResults!['force'] as bool;
    final cliInstaller = CliInstaller(logger: _logger);

    // ── Step 1: Detect CLIs ─────────────────────────────────────────
    _logger.info('');
    _logger.info(
      '${lightCyan.wrap('Step 1/4')}  Checking installed CLIs...',
    );
    _logger.info('');

    final cliChecks = await cliInstaller.detectAll();

    for (final check in cliChecks) {
      if (check.installed) {
        _logger.info(
          '  ${lightGreen.wrap('✓')} ${check.cli.displayName}'
          '  (${check.path})',
        );
      } else {
        _logger.info(
          '  ${lightRed.wrap('✗')} ${check.cli.displayName}'
          '  (not found)',
        );
      }
    }
    _logger.info('');

    // ── Step 2: Install missing CLIs ────────────────────────────────
    final missingClis = cliChecks.where((c) => !c.installed).toList();

    if (missingClis.isNotEmpty) {
      _logger.info(
        '${lightCyan.wrap('Step 2/4')}  Install missing CLIs',
      );
      _logger.info('');

      final hasNpm = await cliInstaller.isNpmAvailable();

      for (final missing in missingClis) {
        final cli = missing.cli;

        final shouldInstall = force ||
            _logger.confirm(
              'Install ${cli.displayName}?',
              defaultValue: true,
            );

        if (!shouldInstall) continue;

        if (cli.npmPackage != null && hasNpm) {
          final success = await cliInstaller.installViaNpm(cli);
          if (!success) {
            cliInstaller.showManualInstructions(cli);
          }
        } else {
          cliInstaller.showManualInstructions(cli);
          if (cli.npmPackage != null && !hasNpm) {
            _logger.warn(
              '  npm not found — install Node.js first for auto-install.',
            );
          }
        }
        _logger.info('');
      }
    } else {
      _logger.info(
        '${lightCyan.wrap('Step 2/4')}  Install missing CLIs',
      );
      _logger.success('  All CLIs already installed!');
      _logger.info('');
    }

    // ── Step 3: Select technologies ─────────────────────────────────
    _logger.info(
      '${lightCyan.wrap('Step 3/4')}  Select technologies',
    );
    _logger.info('');

    final allTechs = SkillRegistry.technologies;
    List<String> selectedTechs;

    if (force || allTechs.length <= 1) {
      selectedTechs = allTechs;
      if (!force) {
        _logger.info('  Auto-selected: ${allTechs.join(', ')}');
      }
    } else {
      final techChoice = _logger.chooseOne(
        'Which technologies do you want to install?',
        choices: ['All', ...allTechs],
        defaultValue: 'All',
      );
      selectedTechs = techChoice == 'All' ? allTechs : [techChoice];
    }

    if (selectedTechs.isEmpty) {
      _logger.info('No technologies selected.');
      return ExitCode.success.code;
    }

    _logger.info('');

    // ── Step 4: Detect agents & install skills ──────────────────────
    _logger.info(
      '${lightCyan.wrap('Step 4/4')}  Installing skills...',
    );
    _logger.info('');

    // Re-detect to pick up any CLIs installed in step 2
    final detectProgress = _logger.progress('Detecting agents');
    final detector = AgentDetector();
    final agents = await detector.detect();
    detectProgress.complete('Agent detection complete');

    _logger.info('');
    for (final entry in agents.entries) {
      final agentName = AgentDetector.displayName(entry.key);
      final info = entry.value;
      if (info.installed) {
        _logger.info(
          '  ${lightGreen.wrap('✓')} $agentName',
        );
      } else {
        _logger.info(
          '  ${lightRed.wrap('✗')} $agentName  (not found)',
        );
      }
    }
    _logger.info('');

    final installedAgents = agents.entries
        .where((e) => e.value.installed)
        .map((e) => e.key)
        .toList();

    if (installedAgents.isEmpty) {
      _logger.err('No AI agents detected.');
      _logger.info('');
      _logger.info('Install at least one agent to continue:');
      _logger.info('  Claude Code: https://claude.ai/download');
      _logger.info('  Cursor:      https://cursor.com');
      _logger.info('  Gemini CLI:  https://github.com/google-gemini/gemini-cli');
      return ExitCode.software.code;
    }

    // Resolve repo root
    final resolver = PackageResolver();
    final String repoRoot;
    try {
      repoRoot = await resolver.resolveRepoRoot();
    } catch (e) {
      _logger.err('$e');
      return ExitCode.software.code;
    }

    final loader = ContentLoader(repoRoot);
    final bundles = SkillRegistry.byTechnologies(selectedTechs);

    // Install to each detected agent
    var totalSkills = 0;
    var totalRules = 0;

    for (final agentType in installedAgents) {
      final agentId = switch (agentType) {
        AgentType.claude => 'claude',
        AgentType.cursor => 'cursor',
        AgentType.antigravity => 'gemini',
      };
      final agentConfig = AgentRegistry.findById(agentId);
      if (agentConfig == null) continue;

      _logger.info('  ${AgentDetector.displayName(agentType)}:');

      final installer = AgentInstaller(
        logger: _logger,
        loader: loader,
        agentConfig: agentConfig,
      );
      final result = await installer.install(
        bundles: bundles,
        force: force,
      );
      totalSkills += result.skillCount;
      totalRules += result.ruleCount;

      _logger.info('');
    }

    // ── Summary ─────────────────────────────────────────────────────
    final parts = <String>[];
    if (totalSkills > 0) parts.add('$totalSkills commands');
    if (totalRules > 0) parts.add('$totalRules rules');

    if (parts.isNotEmpty) {
      _logger.success('Setup complete! Installed ${parts.join(', ')}.');
    } else {
      _logger.success('Setup complete!');
    }
    _logger.info('');

    // Next steps
    _logger.info('Next steps:');
    final healthBundles = bundles.where((b) => b.id.endsWith('_health'));
    for (final b in healthBundles) {
      final code = b.name.replaceFirst('somnio-', '');
      _logger.info(
        '  Run audit:    somnio run $code  (${b.displayName})',
      );
    }
    _logger.info('  Check status: somnio status');
    _logger.info('  Update:       somnio update');

    return ExitCode.success.code;
  }
}
