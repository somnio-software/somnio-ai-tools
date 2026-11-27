// coverage:ignore-file
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import '../content/content_loader.dart';
import '../content/skill_bundle.dart';
import '../content/skill_registry.dart';
import '../content/workflow_skill.dart';
import '../installers/agent_installer.dart';
import '../installers/installer.dart';
import '../installers/protected_paths.dart';
import 'agent_detector.dart';
import 'package_resolver.dart';
import 'platform_utils.dart';

/// Shared helpers used across multiple CLI commands.
///
/// Consolidates logic that was duplicated in setup, init, install,
/// update, run, and add commands.
class CommandHelpers {
  CommandHelpers._();

  /// Formats an install result as a summary string.
  ///
  /// [extraCount] adds additional skills (e.g., workflow skills) to the total.
  /// Example output: `"7 skills"`, `"5 commands, 2 skipped"`.
  static String installSummary(
    InstallResult result,
    AgentConfig agent, {
    int extraCount = 0,
  }) {
    final total = result.skillCount + extraCount;
    final label = agent.contentLabel;
    final plural = total == 1 ? label : '${label}s';
    final parts = <String>['$total $plural'];
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
    logger.info('  Update:       somnio skills update');
  }

  /// Title-cases a string (first character uppercase).
  static String titleCase(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  /// The installed names of [audit] and [workflow] skills — what a skill's
  /// folder and lock entry are called once installed.
  static Set<String> skillNames(
    Iterable<SkillBundle> audit,
    Iterable<WorkflowSkill> workflow,
  ) =>
      {for (final s in audit) s.name, for (final s in workflow) s.name};

  /// Detects installed AI agents and prints one ✓/✗ line per agent.
  ///
  /// Returns the detected agents; when there are none, prints the
  /// no-agents error and returns an empty list.
  static Future<List<AgentConfig>> detectInstallTargets(Logger logger) async {
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

    if (detectedAgents.isEmpty) printNoAgentsError(logger);
    return detectedAgents;
  }

  /// The [agents] an install in [scope] may write for, reporting every agent
  /// whose folder is really another agent's (see [sharedFolderOwner]).
  ///
  /// Such an agent is left out, unless the user asked for it alone ([explicit]):
  /// then it stays, with a warning.
  static List<AgentConfig> withoutSharedFolders(
    Logger logger,
    List<AgentConfig> agents, {
    required bool explicit,
    InstallScope scope = InstallScope.global,
  }) {
    final home = PlatformUtils.homeDirectory;
    final projectRoot = Directory.current.path;
    final environment = PlatformUtils.environment;
    final targets = <AgentConfig>[];
    for (final agent in agents) {
      final owner = sharedFolderOwner(
        agent,
        scope: scope,
        home: home,
        projectRoot: projectRoot,
        environment: environment,
      );
      if (owner != null) {
        final folder = agent.resolvedScopedInstallPath(
          scope: scope,
          home: home,
          projectRoot: projectRoot,
          environment: environment,
        );
        logger.warn(
          sharedFolderNotice(agent, owner, folder, skipped: !explicit),
        );
        if (!explicit) continue;
      }
      targets.add(agent);
    }
    return targets;
  }

  /// Installs every registered skill to [agents] and prints a summary.
  ///
  /// Used by `setup` after [detectInstallTargets]. Every install is recorded
  /// in the agent's `.somnio-skills.json` manifest, so `somnio skills update`
  /// can refresh it. Returns the exit code.
  static Future<int> installAllSkills(
    Logger logger,
    List<AgentConfig> agents,
    ResolvedContent content,
  ) async {
    logger.info('');
    var totalSkills = 0;
    var totalFailed = 0;

    for (final agentConfig in agents) {
      final progress = logger.progress(agentConfig.displayName);

      final installer = AgentInstaller(
        logger: logger,
        loader: content.loader,
        agentConfig: agentConfig,
      );
      final result = await installer.install(bundles: content.bundles);
      final wf = installer.installWorkflowSkillsDetailed(
        SkillRegistry.workflowSkills,
      );
      totalSkills += result.skillCount + wf.installed;
      totalFailed += result.failedCount + wf.failed;

      progress.complete(
        '${agentConfig.displayName}  '
        '${installSummary(result, agentConfig, extraCount: wf.installed)}',
      );
    }

    logger.info('');
    if (totalFailed > 0) {
      logger.err(
        'Done with errors: $totalFailed failed, $totalSkills skills '
        'installed across ${agents.length} agents.',
      );
    } else {
      logger.success(
        'Done! Installed $totalSkills skills '
        'across ${agents.length} agents.',
      );
    }
    logger.info('');

    printNextSteps(logger);

    return totalFailed > 0 ? ExitCode.software.code : ExitCode.success.code;
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
