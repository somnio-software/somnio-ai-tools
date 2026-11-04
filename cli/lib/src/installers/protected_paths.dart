import 'dart:io';

import 'package:path/path.dart' as p;

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import '../utils/real_path.dart';

/// Real paths of the install folders no install, update, remove or uninstall
/// of [agent] may touch, whichever folder links to them: every agent's
/// protected default (`~/.claude/skills` while `CLAUDE_CONFIG_DIR` relocates
/// Claude Code, see `AgentConfig.resolvedProtectedInstallPaths`), except one
/// that gives way to [agent] as the owner of the real folder (see
/// [AgentConfig.yieldsLinkedDefaultToOwner]).
Set<String> protectedInstallPaths(
  AgentConfig agent, {
  required String home,
  Map<String, String> environment = const {},
}) {
  final current =
      agent.resolvedInstallPath(home: home, environment: environment);
  final ownFolder =
      _reachedThroughLink(current, home) ? null : realPathOf(current);
  return {
    for (final other in AgentRegistry.installableAgents)
      for (final path in other.resolvedProtectedInstallPaths(
        home: home,
        environment: environment,
      ))
        if (!other.yieldsLinkedDefaultToOwner || path != ownFolder) path,
  };
}

/// Real paths of the config folders that hold a protected install folder
/// (`~/.claude`), where more than skills lives. A config folder that gives way
/// (see [AgentConfig.yieldsLinkedDefaultToOwner]) and is itself a link is left
/// out: what lives at its real path is not that agent's.
Set<String> protectedConfigHomes({
  required String home,
  Map<String, String> environment = const {},
}) =>
    {
      for (final agent in AgentRegistry.installableAgents)
        if (agent
            .resolvedProtectedInstallPaths(home: home, environment: environment)
            .isNotEmpty)
          if (agent.resolvedConfigHome(home: home) case final configHome?)
            if (!agent.yieldsLinkedDefaultToOwner ||
                !_reachedThroughLink(configHome, home))
              realPathOf(configHome),
    };

/// Whether [path], or a folder between it and [home], is a symlink. Outside
/// [home] the walk goes up to the root, so a link above the folder (macOS's
/// `/tmp`) counts too.
bool _reachedThroughLink(String path, String home) {
  for (var dir = p.normalize(path);
      !p.equals(dir, home) && dir != p.dirname(dir);
      dir = p.dirname(dir)) {
    if (FileSystemEntity.isLinkSync(dir)) return true;
  }
  return false;
}

/// Whether the install folder [dir] is, holds or lies inside one of
/// [protected], through a symlink or not.
bool overlapsProtected(String dir, Set<String> protected) {
  final real = realPathOf(dir);
  return protected.any(
    (path) =>
        p.equals(real, path) ||
        p.isWithin(path, real) ||
        p.isWithin(real, path),
  );
}

/// Whether [path] is, or lies inside, one of [protected] config folders.
///
/// Looser than [overlapsProtected] on purpose: a folder that merely holds a
/// config folder (the home directory) is no reason to skip it.
bool insideProtected(String path, Set<String> protected) {
  final real = realPathOf(path);
  return protected
      .any((root) => p.equals(real, root) || p.isWithin(root, real));
}
