import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../agents/agent_registry.dart';
import '../content/content_loader.dart';
import '../content/skill_registry.dart';
import '../installers/agent_installer.dart';
import '../utils/package_resolver.dart';

/// Installs skills into Claude Code.
///
/// Thin alias for `somnio install --agent claude`.
class ClaudeCommand extends Command<int> {
  ClaudeCommand({required Logger logger}) : _logger = logger {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Overwrite existing skills without prompting.',
    );
  }

  final Logger _logger;

  @override
  String get name => 'claude';

  @override
  String get description => 'Install skills into Claude Code.';

  @override
  Future<int> run() async {
    final force = argResults!['force'] as bool;

    final resolver = PackageResolver();
    final String repoRoot;
    try {
      repoRoot = await resolver.resolveRepoRoot();
    } catch (e) {
      _logger.err('$e');
      return ExitCode.software.code;
    }

    final loader = ContentLoader(repoRoot);
    final agent = AgentRegistry.findById('claude')!;
    final installer = AgentInstaller(
      logger: _logger,
      loader: loader,
      agentConfig: agent,
    );

    final result = await installer.install(
      bundles: SkillRegistry.skills,
      force: force,
    );

    if (result.skillCount > 0) {
      _logger.success(
        '\nInstalled ${result.skillCount} skills to Claude Code.',
      );
      _logger.info('Location: ${result.targetDirectory}');
      _logger.info('');
      _logger.info('Usage:');
      for (final skill in SkillRegistry.skills) {
        _logger.info('  /${skill.name}');
      }
    }

    return ExitCode.success.code;
  }
}
