import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/real_path.dart';
import 'skill_manifest.dart';

/// Checks Clockify installations without changing user files.
class LegacyClockifyGuard {
  const LegacyClockifyGuard._();

  /// Throws for any existing Clockify path or state that cannot be inspected.
  static void check({
    required String installRoot,
    required String rulesRoot,
    required String home,
    String? legacyInstallRoot,
    String? projectCommandDir,
    List<String> protectedRoots = const [],
  }) {
    final roots = [
      installRoot,
      if (legacyInstallRoot != null) legacyInstallRoot
    ];
    for (final root in roots) {
      for (final relative in const [
        'clockify-tracker',
        'clockify-tracker.md',
        'clockify_tracker.md',
        'global_workflows/somnio_clockify_tracker.md',
      ]) {
        _requireAbsent(root, relative, protectedRoots: protectedRoots);
      }
      final safeRoot = _safeDirectory(root, protectedRoots: protectedRoots);
      if (safeRoot != null)
        _checkManifest(safeRoot, rulesRoot, protectedRoots: protectedRoots);
    }
    _requireAbsent(p.join(home, '.agents', 'skills'), 'clockify-tracker',
        protectedRoots: protectedRoots);
    if (projectCommandDir != null) {
      checkCommand(projectCommandDir, protectedRoots: protectedRoots);
    }
  }

  /// The selected agent's command directory in the current project only.
  static String? projectCommandDir(
      String agent, String projectRoot, String home,
      {List<String> protectedRoots = const []}) {
    final commandDir = switch (agent) {
      'claude' => p.join(projectRoot, '.claude', 'commands'),
      'cursor' => p.join(projectRoot, '.cursor', 'commands'),
      _ => null,
    };
    if (commandDir == null) return null;
    final resolved = realPathOf(commandDir);
    if (protectedRoots.any((root) =>
        p.equals(realPathOf(root), resolved) ||
        p.isWithin(realPathOf(root), resolved))) return null;
    return commandDir;
  }

  /// Blocks old commands or symlinked project ancestors.
  static void checkCommand(String targetDir,
      {List<String> protectedRoots = const []}) {
    try {
      _rejectSymlinkAncestors(targetDir);
      _requireAbsent(targetDir, 'clockify-tracker.md',
          protectedRoots: protectedRoots);
    } catch (e) {
      throw StateError('$e Check other projects separately.');
    }
  }

  /// Returns true only for an identical current command; never overwrites it.
  static bool currentCommandIsIdentical(String root, String content) {
    final safeRoot = _safeDirectory(root);
    if (safeRoot == null) return false;
    final current = _findChild(safeRoot, 'clockify.md');
    if (current == null) return false;
    if (FileSystemEntity.typeSync(current.path, followLinks: false) !=
            FileSystemEntityType.file ||
        File(current.path).lengthSync() > 1024 * 1024 ||
        File(current.path).readAsStringSync() != content) {
      throw StateError(
          'Existing Clockify command at ${current.path} was preserved. Confirm ownership before moving or removing it; check other projects separately');
    }
    return true;
  }

  /// An existing skill is reusable only when recorded and byte-identical.
  static bool currentSkillIsIdentical(
      String root, String content, ManifestEntry? owned,
      {List<String> protectedRoots = const []}) {
    if (owned != null &&
        (owned.kind != 'workflow' ||
            owned.paths.length != 1 ||
            owned.paths.single.root != ManifestRoot.install ||
            owned.paths.single.path != 'clockify')) {
      throw StateError(
          'Unexpected Clockify manifest paths were preserved in $root. Confirm ownership before moving or removing them');
    }
    final safeRoot = _safeDirectory(root, protectedRoots: protectedRoots);
    if (safeRoot == null) return false;
    final current = _findChild(safeRoot, 'clockify');
    if (current == null) return false;
    if (p.basename(current.path) != 'clockify' ||
        FileSystemEntity.typeSync(current.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        owned == null ||
        owned.kind != 'workflow') {
      throw StateError(
          'Existing Clockify skill at ${current.path} was preserved. Confirm ownership before moving or removing it');
    }
    final files = Directory(current.path).listSync(followLinks: false);
    if (files.length != 1 ||
        p.basename(files.single.path) != 'SKILL.md' ||
        FileSystemEntity.typeSync(files.single.path, followLinks: false) !=
            FileSystemEntityType.file ||
        File(files.single.path).lengthSync() > 1024 * 1024 ||
        File(files.single.path).readAsStringSync() != content) {
      throw StateError(
          'Existing Clockify skill at ${current.path} was preserved. Confirm ownership before moving or removing it');
    }
    return true;
  }

  /// Validates complete manifests before the normal loader can rewrite them.
  static void verifyManifests({
    required String installRoot,
    required String rulesRoot,
    String? legacyInstallRoot,
    List<String> protectedRoots = const [],
  }) {
    for (final root in [
      installRoot,
      if (legacyInstallRoot != null) legacyInstallRoot
    ]) {
      final safeRoot = _safeDirectory(root, protectedRoots: protectedRoots);
      if (safeRoot != null) {
        _checkManifest(safeRoot, rulesRoot,
            checkRetired: false, protectedRoots: protectedRoots);
      }
    }
  }

  static void _checkManifest(String root, String rulesRoot,
      {bool checkRetired = true, List<String> protectedRoots = const []}) {
    final manifest = _findChild(root, SkillManifest.fileName);
    if (manifest == null) return;
    final path = manifest.path;
    if (FileSystemEntity.typeSync(path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('Cannot safely inspect $path');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(File(path).readAsStringSync());
    } catch (e) {
      throw StateError('Cannot safely inspect $path');
    }
    if (decoded is! Map ||
        decoded['version'] != SkillManifest.formatVersion ||
        decoded['skills'] is! Map) {
      throw StateError('Cannot safely inspect $path');
    }
    for (final item in (decoded['skills'] as Map).entries) {
      final entry = item.value;
      if (item.key is! String ||
          entry is! Map ||
          entry['kind'] is! String ||
          entry['paths'] is! List) {
        throw StateError('Cannot safely inspect $path');
      }
      final retired = (item.key as String).toLowerCase() == 'clockify-tracker';
      if (retired &&
          (entry['kind'] != 'workflow' || (entry['paths'] as List).isEmpty)) {
        throw StateError(
            'Cannot safely inspect retired Clockify entry in $path');
      }
      for (final raw in entry['paths'] as List) {
        if (raw is! Map ||
            raw['path'] is! String ||
            (raw['root'] != null &&
                raw['root'] != 'install' &&
                raw['root'] != 'rules')) {
          throw StateError('Cannot safely inspect $path');
        }
        final recorded = ManifestPath(
          raw['root'] == 'rules' ? ManifestRoot.rules : ManifestRoot.install,
          raw['path'] as String,
        );
        if (!recorded.isContained)
          throw StateError('Cannot safely inspect $path');
        if (retired && checkRetired) {
          _requireAbsent(recorded.root == ManifestRoot.rules ? rulesRoot : root,
              recorded.path,
              protectedRoots: protectedRoots);
        }
      }
    }
  }

  static void _rejectSymlinkAncestors(String path) {
    var current = p.normalize(p.absolute(path));
    while (true) {
      if (FileSystemEntity.typeSync(current, followLinks: false) ==
              FileSystemEntityType.link &&
          !(Platform.isMacOS && (current == '/var' || current == '/tmp'))) {
        throw StateError('Cannot safely inspect a symlinked command path');
      }
      final parent = p.dirname(current);
      if (parent == current) break;
      current = parent;
    }
  }

  static FileSystemEntity? _findChild(String parent, String name) {
    final matches = Directory(parent)
        .listSync(followLinks: false)
        .where(
          (entity) =>
              p.basename(entity.path).toLowerCase() == name.toLowerCase(),
        )
        .toList();
    if (matches.length > 1) throw StateError('Ambiguous path under $parent');
    return matches.isEmpty ? null : matches.single;
  }

  static String? _safeDirectory(String root,
      {List<String> protectedRoots = const []}) {
    final absolute = realPathOf(root);
    for (final protected in protectedRoots) {
      final blocked = realPathOf(protected);
      if (p.equals(absolute, blocked) ||
          p.isWithin(blocked, absolute) ||
          p.isWithin(absolute, blocked)) {
        throw StateError('Cannot inspect a protected configuration directory');
      }
    }
    var current = p.rootPrefix(absolute);
    final rootParts = p
        .split(absolute)
        .where((part) => part != current && part.isNotEmpty)
        .toList();
    for (final part in rootParts) {
      final child = _findChild(current, part);
      if (child == null) return null;
      final next = child.path;
      final type = FileSystemEntity.typeSync(next, followLinks: false);
      if (type == FileSystemEntityType.link &&
          Platform.isMacOS &&
          (next == '/var' || next == '/tmp')) {
        final resolved = Directory(next).resolveSymbolicLinksSync();
        if ((next == '/var' && resolved == '/private/var') ||
            (next == '/tmp' && resolved == '/private/tmp')) {
          current = resolved;
          continue;
        }
      }
      if (type != FileSystemEntityType.directory)
        throw StateError('Cannot safely inspect $next');
      current = next;
    }
    return current;
  }

  static void _requireAbsent(String root, String relative,
      {List<String> protectedRoots = const []}) {
    final safeRoot = _safeDirectory(root, protectedRoots: protectedRoots);
    if (safeRoot == null) return;
    var current = safeRoot;
    final parts = p.split(relative);
    for (var index = 0; index < parts.length; index++) {
      final child = _findChild(current, parts[index]);
      if (child == null) return;
      final next = child.path;
      if (index == parts.length - 1) {
        throw StateError(
            'Existing Clockify path $next was preserved. Confirm ownership before moving or removing it');
      }
      if (FileSystemEntity.typeSync(next, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw StateError('Cannot safely inspect $next');
      }
      current = next;
    }
  }
}
