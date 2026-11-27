import 'package:path/path.dart' as p;

import '../agents/agent_registry.dart';
import '../utils/real_path.dart';

/// Real paths of the install folders no install, update, remove or uninstall
/// may touch, whichever agent's folder links to them: every agent's
/// protected default (`~/.claude/skills` while `CLAUDE_CONFIG_DIR` relocates
/// Claude Code, see `AgentConfig.resolvedProtectedInstallPaths`).
Set<String> protectedInstallPaths({
  required String home,
  Map<String, String> environment = const {},
}) =>
    {
      for (final agent in AgentRegistry.installableAgents)
        ...agent.resolvedProtectedInstallPaths(
          home: home,
          environment: environment,
        ),
    };

/// Real paths of the config folders that hold a protected install folder
/// (`~/.claude`), where more than skills lives.
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
            realPathOf(configHome),
    };

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
