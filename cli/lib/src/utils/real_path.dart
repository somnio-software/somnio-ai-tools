import 'dart:io';

import 'package:path/path.dart' as p;

/// The real location of [path], for telling whether two paths are the same
/// directory (e.g. a project scope that is the user's home).
///
/// Symlinks are resolved when [path] exists; otherwise the deepest existing
/// ancestor is resolved and the rest appended, so a not-yet-created path
/// still compares equal to its twin.
String realPathOf(String path) {
  final normalized = p.normalize(p.absolute(path));
  var existing = normalized;
  final missing = <String>[];
  while (FileSystemEntity.typeSync(existing) == FileSystemEntityType.notFound) {
    final parent = p.dirname(existing);
    if (parent == existing) return normalized;
    missing.insert(0, p.basename(existing));
    existing = parent;
  }
  try {
    return p
        .joinAll([Directory(existing).resolveSymbolicLinksSync(), ...missing]);
  } on FileSystemException {
    return normalized;
  }
}

/// The location [path] ends up at once every symlink on the way is followed,
/// also one whose target does not exist yet, which [realPathOf] leaves as it
/// is. For telling who a folder will belong to once it is created.
///
/// A link cycle has no such location, so that path gives its [realPathOf].
String followedPathOf(String path) {
  const maxLinks = 40;
  final pending = p.split(p.absolute(path));
  var followed = pending.removeAt(0);
  var links = 0;
  while (pending.isNotEmpty) {
    final segment = pending.removeAt(0);
    if (segment == '.') continue;
    if (segment == '..') {
      followed = p.dirname(followed);
      continue;
    }
    final next = p.join(followed, segment);
    if (!FileSystemEntity.isLinkSync(next)) {
      followed = next;
      continue;
    }
    if (++links > maxLinks) return realPathOf(path);
    final target = p.split(Link(next).targetSync());
    if (p.isAbsolute(target.first)) followed = target.removeAt(0);
    pending.insertAll(0, target);
  }
  return realPathOf(followed);
}

/// Whether [target] lies strictly inside [root] without passing through a
/// symlinked directory on the way, so deleting it cannot reach outside
/// [root].
///
/// [root] itself may be a symlink (skills.sh links whole agent folders);
/// only the directories between it and [target] are checked.
bool isSafelyWithin(String root, String target) {
  final normalized = p.normalize(target);
  if (!p.isWithin(root, normalized)) return false;
  for (var dir = p.dirname(normalized);
      p.isWithin(root, dir);
      dir = p.dirname(dir)) {
    if (FileSystemEntity.isLinkSync(dir)) return false;
  }
  return true;
}
