import 'dart:io';

import 'package:path/path.dart' as p;

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import '../utils/platform_utils.dart';

/// Resolves the AI CLI agent and verifies skill installation paths.
class AgentResolver {
  /// Creates a resolver that reads agent config-home overrides (e.g.
  /// `CODEX_HOME`) from [environment] (default: the process environment).
  AgentResolver({Map<String, String>? environment})
      : _environment = environment ?? PlatformUtils.environment;

  final Map<String, String> _environment;

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
  /// - skillDir agents (Claude, Codex, Gemini, ...):
  ///   `<installPath>/{bundleName}/references/`
  /// - agents with an executionRulesPath (Cursor, Amp, ...):
  ///   `<executionRulesPath>/{planSubDir}/references/`
  /// - others: [AgentConfig.resolvedExecutionRulesPath]
  String ruleBasePath(
    AgentConfig agent,
    String bundleName,
    String planSubDir,
  ) {
    final base = _bundleBasePath(agent, bundleName, planSubDir);
    final hasReferencesDir = agent.installFormat == InstallFormat.skillDir ||
        agent.executionRulesPath != null;
    return hasReferencesDir ? p.join(base, 'references') : base;
  }

  /// Returns the template file path for the given agent and bundle.
  String templatePath(
    AgentConfig agent,
    String bundleName,
    String planSubDir,
    String templateFile,
  ) =>
      p.join(
        _bundleBasePath(agent, bundleName, planSubDir),
        'assets',
        templateFile,
      );

  /// The directory holding a bundle's installed `references/` and `assets/`.
  String _bundleBasePath(
    AgentConfig agent,
    String bundleName,
    String planSubDir,
  ) {
    final home = PlatformUtils.homeDirectory;
    if (agent.installFormat == InstallFormat.skillDir) {
      return p.join(
        agent.resolvedInstallPath(home: home, environment: _environment),
        bundleName,
      );
    }
    final basePath = agent.resolvedExecutionRulesPath(
      home: home,
      name: bundleName,
      environment: _environment,
    );
    if (agent.executionRulesPath != null) {
      return p.join(basePath, planSubDir);
    }
    return basePath;
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
          'Skills may be outdated. Run "somnio skills update" to reinstall.';
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
