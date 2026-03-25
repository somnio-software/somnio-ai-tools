import 'dart:io';

import 'package:path/path.dart' as p;

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import '../utils/platform_utils.dart';

/// Resolves the AI CLI agent and verifies skill installation paths.
class AgentResolver {
  /// Auto-detects available AI CLI, preferring the registry order
  /// (Claude > Cursor > Gemini > ...).
  ///
  /// If [preferred] is provided, only checks for that specific agent.
  /// Returns the resolved [AgentConfig], or `null` if none found.
  Future<AgentConfig?> resolve({AgentConfig? preferred}) async {
    if (preferred != null) {
      if (preferred.binary == null) return null;
      final path = await PlatformUtils.whichBinary(preferred.binary!);
      if (path != null) return preferred;
      return null;
    }

    // Auto-detect: try each executable agent in registry order
    for (final agent in AgentRegistry.executableAgents) {
      if (agent.binary == null) continue;
      if (await PlatformUtils.whichBinary(agent.binary!) != null) {
        return agent;
      }
    }
    return null;
  }

  /// Returns the base path where rule files are installed for the given agent.
  ///
  /// - Claude: `~/.claude/skills/{bundleName}/references/`
  /// - Cursor: `~/.cursor/somnio_rules/{planSubDir}/references/`
  /// - Others (incl. Gemini): derived from [AgentConfig.resolvedExecutionRulesPath]
  String ruleBasePath(
    AgentConfig agent,
    String bundleName,
    String planSubDir,
  ) {
    final home = PlatformUtils.homeDirectory;

    // Agent-specific paths for the original three agents
    switch (agent.id) {
      case 'claude':
        return p.join(home, '.claude', 'skills', bundleName, 'references');
      case 'cursor':
        return p.join(home, '.cursor', 'somnio_rules', planSubDir,
            'references');
      default:
        // Agents with executionRulesPath use the same subdirectory layout
        // as Cursor: {rulesPath}/{planSubDir}/references/
        final basePath = agent.resolvedExecutionRulesPath(
          home: home,
          name: bundleName,
        );
        if (agent.executionRulesPath != null) {
          return p.join(basePath, planSubDir, 'references');
        }
        return basePath;
    }
  }

  /// Returns the template file path for the given agent and bundle.
  String templatePath(
    AgentConfig agent,
    String bundleName,
    String planSubDir,
    String templateFile,
  ) {
    final home = PlatformUtils.homeDirectory;

    switch (agent.id) {
      case 'claude':
        return p.join(home, '.claude', 'skills', bundleName, 'assets',
            templateFile);
      case 'cursor':
        return p.join(home, '.cursor', 'somnio_rules', planSubDir,
            'assets', templateFile);
      default:
        final basePath = agent.resolvedExecutionRulesPath(
          home: home,
          name: bundleName,
        );
        if (agent.executionRulesPath != null) {
          return p.join(basePath, planSubDir, 'assets',
              templateFile);
        }
        return p.join(basePath, 'assets', templateFile);
    }
  }

  /// Verifies that the rule files exist at the expected location.
  ///
  /// Returns `null` if OK, or an error message describing the issue.
  String? verifyInstallation(
    AgentConfig agent,
    String ruleBasePath,
    List<String> ruleNames,
  ) {
    final dir = Directory(ruleBasePath);
    if (!dir.existsSync()) {
      final installCmd = 'somnio install --agent ${agent.id}';
      return 'Skills not found at: $ruleBasePath\n'
          'Run "$installCmd" first to install skills for '
          '${agent.displayName}.';
    }

    // Check that the first rule file exists
    final ext = agent.ruleExtension;
    final firstRule = File(
      p.join(ruleBasePath, '${ruleNames.first}$ext'),
    );
    if (!firstRule.existsSync()) {
      return 'Rule file not found: ${firstRule.path}\n'
          'Skills may be outdated. Run "somnio update" to reinstall.';
    }

    return null;
  }

  /// Returns the file extension for rule files per agent.
  String ruleExtension(AgentConfig agent) => agent.ruleExtension;

  /// Returns all AI CLIs found in PATH.
  Future<List<AgentConfig>> detectAll() async {
    final available = <AgentConfig>[];
    for (final agent in AgentRegistry.executableAgents) {
      if (agent.binary == null) continue;
      if (await PlatformUtils.whichBinary(agent.binary!) != null) {
        available.add(agent);
      }
    }
    return available;
  }

  /// Returns a human-readable display name for the given agent.
  String agentDisplayName(AgentConfig agent) => agent.displayName;
}
