import 'dart:io';

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
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
      final binPath = await PlatformUtils.whichBinary(agent.binary!);
      if (binPath != null) {
        return AgentInfo(installed: true, path: binPath);
      }
    }

    // Check additional detection binaries
    for (final bin in agent.detectionBinaries) {
      final binPath = await PlatformUtils.whichBinary(bin);
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

    // Check if the install directory exists (installed but binary not in PATH)
    if (agent.installScope == InstallScope.global) {
      final home = PlatformUtils.homeDirectory;
      final installDir = agent.resolvedInstallPath(home: home);
      if (Directory(installDir).existsSync()) {
        return AgentInfo(installed: true, path: installDir);
      }
    }

    return const AgentInfo(installed: false);
  }
}
