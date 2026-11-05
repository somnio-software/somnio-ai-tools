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
/// [AgentConfig.yieldsSharedFolder]) and is itself reached through a link.
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
        if (!other.yieldsSharedFolder ||
            path != ownFolder ||
            !_reachedThroughLink(other.resolvedInstallPath(home: home), home))
          path,
  };
}

/// Real paths of the config folders that hold a protected install folder
/// (`~/.claude`), where more than skills lives. A config folder that gives way
/// (see [AgentConfig.yieldsSharedFolder]) and is itself a link is left
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
            if (!agent.yieldsSharedFolder ||
                !_reachedThroughLink(configHome, home))
              realPathOf(configHome),
    };

/// The other agent whose current folder, global or under [projectRoot], is
/// really [agent]'s current folder in [scope], when [agent] gives way on such a
/// folder (see [AgentConfig.yieldsSharedFolder]). A link whose target does not
/// exist yet counts, since the other agent's install creates that folder.
AgentConfig? sharedFolderOwner(
  AgentConfig agent, {
  required InstallScope scope,
  required String home,
  required String projectRoot,
  Map<String, String> environment = const {},
}) {
  if (!agent.yieldsSharedFolder) return null;
  final own = followedPathOf(
    agent.resolvedScopedInstallPath(
      scope: scope,
      home: home,
      projectRoot: projectRoot,
      environment: environment,
    ),
  );
  for (final other in AgentRegistry.installableAgents) {
    if (other.id == agent.id) continue;
    final scopes = [
      InstallScope.global,
      if (other.supportsProjectScope) InstallScope.project,
    ];
    for (final otherScope in scopes) {
      final folder = other.resolvedScopedInstallPath(
        scope: otherScope,
        home: home,
        projectRoot: projectRoot,
        environment: environment,
      );
      if (followedPathOf(folder) == own) return other;
    }
  }
  return null;
}

/// The line that reports [agent] leaving [folder] to its [owner] when
/// [skipped], or else working on it because the user asked for [agent].
String sharedFolderNotice(
  AgentConfig agent,
  AgentConfig owner,
  String folder, {
  required bool skipped,
}) {
  final shared = "$folder is really ${owner.displayName}'s folder "
      '(${followedPathOf(folder)})';
  return skipped
      ? '  ${agent.displayName}: skipped, $shared. Only --agent ${agent.id} '
          'acts on it.'
      : '  ${agent.displayName}: $shared, so this also changes what '
          '${owner.displayName} reads.';
}

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
