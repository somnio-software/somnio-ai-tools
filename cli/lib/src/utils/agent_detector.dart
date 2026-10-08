// coverage:ignore-file
import 'dart:io';

import 'package:path/path.dart' as p;

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import '../installers/skills_sh_cleaner.dart';
import 'platform_utils.dart';

/// Information about a detected agent.
class AgentInfo {
  const AgentInfo({required this.installed, this.path, this.version});

  final bool installed;
  final String? path;
  final String? version;

  @override
  String toString() => installed
      ? 'AgentInfo(installed, path: $path)'
      : 'AgentInfo(not installed)';
}

/// Detects which AI coding agents are installed on the system.
///
/// All detection is driven by [AgentRegistry] — adding a new agent there
/// automatically makes it discoverable here.
class AgentDetector {
  /// Creates a detector that resolves install folders under [homeDirectory]
  /// (default: the user's home) and looks binaries up with [whichBinary]
  /// (default: [PlatformUtils.whichBinary]).
  AgentDetector({
    String? homeDirectory,
    Future<String?> Function(String binary)? whichBinary,
  })  : _home = homeDirectory ?? PlatformUtils.homeDirectory,
        _which = whichBinary ?? PlatformUtils.whichBinary;

  final String _home;
  final Future<String?> Function(String binary) _which;

  /// Whether [path] is a directory holding something that shows the agent
  /// is really in use.
  ///
  /// Ignored: macOS `.DS_Store` metadata and symlinks into skills.sh's
  /// canonical `<home>/.agents/skills` — `npx skills add -g --all` creates
  /// those (and their folder) for agents the user may never have installed,
  /// and the cleanup removes them before installing.
  static bool hasContent(String path, {required String home}) {
    final dir = Directory(path);
    if (!dir.existsSync()) return false;
    try {
      return dir.listSync(followLinks: false).any(
            (entity) =>
                p.basename(entity.path) != '.DS_Store' &&
                !isSkillsShLink(entity.path, home: home),
          );
    } on FileSystemException {
      return false;
    }
  }

  /// Detects all agents that have a binary (CLI agents).
  Future<Map<AgentConfig, AgentInfo>> detect() async {
    final results = <AgentConfig, AgentInfo>{};
    for (final agent in AgentRegistry.agents) {
      results[agent] = await _detectAgent(agent);
    }
    return results;
  }

  /// Detects a single agent by checking its binary, detection binaries,
  /// and detection paths.
  Future<AgentInfo> _detectAgent(AgentConfig agent) async {
    // Check primary binary on PATH
    if (agent.binary != null) {
      final binPath = await _which(agent.binary!);
      if (binPath != null) {
        return AgentInfo(installed: true, path: binPath);
      }
    }

    // Check additional detection binaries
    for (final bin in agent.detectionBinaries) {
      final binPath = await _which(bin);
      if (binPath != null) {
        return AgentInfo(installed: true, path: binPath);
      }
    }

    // Check detection paths (app bundles, etc.)
    for (final detPath in agent.detectionPaths) {
      if (Directory(detPath).existsSync() || File(detPath).existsSync()) {
        return AgentInfo(installed: true, path: detPath);
      }
    }

    // Check for a populated install directory (installed but binary not in
    // PATH). An empty one does not count: skills.sh creates `<agent>/skills`
    // folders for agents the user may never have installed.
    if (agent.installScope == InstallScope.global) {
      final installDir = agent.resolvedInstallPath(home: _home);
      if (hasContent(installDir, home: _home)) {
        return AgentInfo(installed: true, path: installDir);
      }
    }

    return const AgentInfo(installed: false);
  }
}
