import 'package:mason_logger/mason_logger.dart';

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import '../content/content_loader.dart';
import '../content/skill_bundle.dart';
import '../content/skill_registry.dart';
import '../installers/agent_installer.dart';
import '../installers/installer.dart';
import 'agent_detector.dart';
import 'package_resolver.dart';

/// Shared helpers used across multiple CLI commands.
///
/// Consolidates logic that was duplicated in setup, init, install,
/// update, run, and add commands.
class CommandHelpers {
  CommandHelpers._();

  /// Formats an install result as a summary string.
  ///
  /// Example output: `"5 skills"`, `"3 commands, 2 skipped"`.
  static String installSummary(InstallResult result, AgentConfig agent) {
    final label = agent.contentLabel;
    final plural = result.skillCount == 1 ? label : '${label}s';
    final parts = <String>['${result.skillCount} $plural'];
    if (result.skippedCount > 0) {
      parts.add('${result.skippedCount} skipped');
    }
    return parts.join(', ');
  }

  /// Resolves the repo root and returns a [ContentLoader] + skill bundles.
  ///
  /// Throws if the repo root cannot be resolved.
  static Future<ResolvedContent> resolveContent() async {
    final resolver = PackageResolver();
    final repoRoot = await resolver.resolveRepoRoot();
    final loader = ContentLoader(repoRoot);
    return ResolvedContent(
      repoRoot: repoRoot,
      loader: loader,
      bundles: SkillRegistry.skills,
    );
  }

  /// Prints an error message when no AI agents are detected.
  ///
  /// Install URLs are derived from [AgentRegistry] rather than hardcoded,
  /// ensuring consistency and automatic coverage of new agents.
  static void printNoAgentsError(Logger logger) {
    logger.info('');
    logger.err('No AI agents detected.');
    logger.info('');
    logger.info('Install one of the following:');
    for (final agent in AgentRegistry.executableAgents) {
      if (agent.installUrl == null && agent.npmPackage == null) continue;
      final install = agent.npmPackage != null
          ? 'npm install -g ${agent.npmPackage}'
          : agent.installUrl!;
      logger.info(
        '  ${agent.displayName.padRight(16)} $install',
      );
    }
  }

  /// Prints the standard "Next steps" footer after installation.
  static void printNextSteps(Logger logger) {
    logger.info('Next steps:');
    logger.info('  Run audit:    somnio run fh');
    logger.info('  Check status: somnio status');
    logger.info('  Update:       somnio update');
  }

  /// Title-cases a string (first character uppercase).
  static String titleCase(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  /// Detects agents, installs skills to all found, and prints a summary.
  ///
  /// Shared by `setup` (step 3) and `init`.
  /// Returns the exit code.
  static Future<int> installToDetectedAgents(Logger logger) async {
    final detectProgress = logger.progress('Detecting installed AI agents');
    final detector = AgentDetector();
    final agents = await detector.detect();
    detectProgress.complete('Agent detection complete');

    logger.info('');

    final detectedAgents = <AgentConfig>[];

    for (final entry in agents.entries) {
      final agent = entry.key;
      final info = entry.value;
      if (info.installed) {
        logger.info(
          '  ${lightGreen.wrap('✓')} ${agent.displayName} '
          '(${info.path ?? 'found'})',
        );
        detectedAgents.add(agent);
      } else if (agent.canExecute) {
        logger.info(
          '  ${lightRed.wrap('✗')} ${agent.displayName} (not found)',
        );
      }
    }

    if (detectedAgents.isEmpty) {
      printNoAgentsError(logger);
      return ExitCode.software.code;
    }

    final content = await resolveContent();

    logger.info('');
    var totalSkills = 0;

    for (final agentConfig in detectedAgents) {
      final progress = logger.progress(agentConfig.displayName);

      final installer = AgentInstaller(
        logger: logger,
        loader: content.loader,
        agentConfig: agentConfig,
      );
      final result = await installer.install(bundles: content.bundles);
      totalSkills += result.skillCount;

      progress.complete(
        '${agentConfig.displayName}  '
        '${installSummary(result, agentConfig)}',
      );
    }

    logger.info('');
    logger.success(
      'Done! Installed $totalSkills skills '
      'across ${detectedAgents.length} agents.',
    );
    logger.info('');

    printNextSteps(logger);

    return ExitCode.success.code;
  }
}

/// Resolved content from [CommandHelpers.resolveContent].
class ResolvedContent {
  const ResolvedContent({
    required this.repoRoot,
    required this.loader,
    required this.bundles,
  });

  final String repoRoot;
  final ContentLoader loader;
  final List<SkillBundle> bundles;
}
