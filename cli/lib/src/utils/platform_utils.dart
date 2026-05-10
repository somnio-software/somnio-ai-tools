import 'dart:io';

import 'package:path/path.dart' as p;

/// Cross-platform utility helpers.
class PlatformUtils {
  /// Returns the user's home directory.
  static String get homeDirectory {
    if (Platform.isWindows) {
      return Platform.environment['USERPROFILE'] ?? '';
    }
    return Platform.environment['HOME'] ?? '';
  }

  /// Returns Claude Code's config directory, honoring `CLAUDE_CONFIG_DIR`
  /// when set and non-empty. Falls back to `~/.claude`.
  static String get claudeConfigDir {
    final envValue = Platform.environment['CLAUDE_CONFIG_DIR']?.trim();
    if (envValue != null && envValue.isNotEmpty) return envValue;
    return p.join(homeDirectory, '.claude');
  }

  /// Returns every directory under [home] (default: [homeDirectory]) whose
  /// basename starts with [prefix] (e.g. `.claude` matches `.claude`,
  /// `.claude-work`, `.claude-personal`; `.cursor` matches `.cursor`,
  /// `.cursor-work`).
  ///
  /// Falls back to `[<home>/<prefix>]` if no matches exist so a fresh install
  /// still has a target directory. The [home] parameter exists for tests; in
  /// production callers omit it.
  static List<String> discoverConfigDirs({
    required String prefix,
    String? home,
  }) {
    final base = home ?? homeDirectory;
    final fallback = [p.join(base, prefix)];
    final dir = Directory(base);
    if (!dir.existsSync()) return fallback;

    final matches = <String>[];
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (name.startsWith(prefix)) matches.add(entity.path);
    }

    if (matches.isEmpty) return fallback;
    matches.sort();
    return matches;
  }

  /// Returns the path to Claude Code's global skills directory.
  static String get claudeGlobalSkillsDir =>
      p.join(claudeConfigDir, 'skills');

  /// Returns the path to Cursor's global commands directory.
  static String get cursorGlobalCommandsDir =>
      p.join(homeDirectory, '.cursor', 'commands');

  /// Returns the path to the Cursor CLI's rules directory.
  static String get cursorGlobalRulesDir =>
      p.join(homeDirectory, '.cursor', 'somnio_rules');

  /// Returns the path to Antigravity's global directory.
  static String get antigravityGlobalDir =>
      p.join(homeDirectory, '.gemini', 'antigravity');

  /// Runs `which` (Unix) or `where` (Windows) to find a binary.
  static Future<String?> whichBinary(String binary) async {
    try {
      final cmd = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(cmd, [binary]);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim().split('\n').first;
      }
    } catch (_) {}
    return null;
  }
}
