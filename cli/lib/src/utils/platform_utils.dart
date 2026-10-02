// coverage:ignore-file
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

  /// Returns the path to Claude Code's global skills directory.
  static String get claudeGlobalSkillsDir =>
      p.join(homeDirectory, '.claude', 'skills');

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

  /// Resolves the real, native executable behind a Windows npm shim.
  ///
  /// npm installs global CLIs on Windows as `.cmd`/`.ps1` wrapper scripts
  /// that internally `cmd.exe`-parse and re-forward arguments. That
  /// re-tokenization is line-oriented, so a single argument containing
  /// literal newlines (e.g. a multi-paragraph prompt) gets silently
  /// truncated or corrupted — even when the wrapper is invoked directly
  /// via [Process.run] without a shell. The bundled native executable at
  /// `node_modules/<npmPackage>/bin/<binary>.exe` has no such wrapper and
  /// receives argv atomically, so resolving straight to it sidesteps the
  /// problem entirely.
  ///
  /// Returns `null` on non-Windows platforms, when [npmPackage] is
  /// unknown, when the shim can't be located on PATH, or when no matching
  /// bundled `.exe` exists next to it (falling back to the shim is then
  /// the caller's responsibility).
  static Future<String?> resolveWindowsNpmExecutable(
    String binary,
    String? npmPackage,
  ) async {
    if (!Platform.isWindows || npmPackage == null) return null;
    final shimPath = await whichBinary(binary);
    if (shimPath == null) return null;

    final shimDir = p.dirname(shimPath);
    final packageParts = npmPackage.split('/');
    final candidate = p.joinAll([
      shimDir,
      'node_modules',
      ...packageParts,
      'bin',
      '$binary.exe',
    ]);
    if (File(candidate).existsSync()) return candidate;
    return null;
  }
}