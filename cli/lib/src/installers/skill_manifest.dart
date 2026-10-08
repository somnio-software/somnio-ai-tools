import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Which of an agent's two install roots a recorded [ManifestPath] is
/// relative to.
///
/// Most agents write a skill's rules and its bundled files to the same
/// directory, but some (Cursor, Codex, Gemini) split them: the skill
/// file(s) go under the agent's normal install path while the execution
/// rules go under a separate `AgentConfig.executionRulesPath`. Recording
/// which root a path came from lets removal delete from the right place
/// without needing to re-derive it from agent config at uninstall time.
enum ManifestRoot {
  /// The agent's normal skill install directory.
  install,

  /// The agent's separate execution-rules directory
  /// (`AgentConfig.executionRulesPath`), when it has one.
  rules;

  /// Serializes to the on-disk string ('install' / 'rules').
  String toJson() => name;

  /// Parses the on-disk string, falling back to [install] for anything
  /// unrecognized so a future new root value (or a hand-edited manifest)
  /// never throws — it just degrades to the safer default.
  static ManifestRoot fromJson(String value) => switch (value) {
        'rules' => ManifestRoot.rules,
        _ => ManifestRoot.install,
      };
}

/// One path somnio wrote for a skill, relative to [root].
///
/// May point at a file or a directory; removal deletes whatever is at
/// [path] exactly, never touching siblings that weren't recorded.
class ManifestPath {
  const ManifestPath(this.root, this.path);

  /// Which install root [path] is relative to.
  final ManifestRoot root;

  /// Path relative to [root], using forward slashes on every platform so
  /// the manifest is portable and diffs cleanly across OSes.
  final String path;

  /// Reconstructs a [ManifestPath] from its JSON map.
  factory ManifestPath.fromJson(Map<String, dynamic> json) => ManifestPath(
        ManifestRoot.fromJson(json['root'] as String? ?? 'install'),
        json['path'] as String? ?? '',
      );

  /// Serializes to the on-disk map shape.
  Map<String, dynamic> toJson() => {
        'root': root.toJson(),
        'path': path,
      };

  /// Whether [path] names something strictly inside its root: non-empty,
  /// relative on every platform, and free of empty, `.` and `..` segments.
  ///
  /// The installer only ever records such paths. [SkillManifest.load] drops
  /// any other, so a hand-edited or committed manifest can never point
  /// install, update or removal at the root itself or outside it.
  bool get isContained {
    if (path.isEmpty || path.startsWith(RegExp(r'[/\\]|[A-Za-z]:'))) {
      return false;
    }
    return path.split(RegExp(r'[/\\]')).every(
        (segment) => segment.isNotEmpty && segment != '.' && segment != '..');
  }

  /// Orders paths by (root, path) so writing the manifest is deterministic
  /// and repeated installs produce a byte-identical file.
  int compareTo(ManifestPath other) {
    final rootCompare = root.name.compareTo(other.root.name);
    if (rootCompare != 0) return rootCompare;
    return path.compareTo(other.path);
  }

  @override
  bool operator ==(Object other) =>
      other is ManifestPath && other.root == root && other.path == path;

  @override
  int get hashCode => Object.hash(root, path);

  @override
  String toString() => '${root.name}:$path';
}

/// Everything somnio wrote for one skill in one (agent, scope) location.
class ManifestEntry {
  const ManifestEntry({
    required this.skill,
    required this.kind,
    required this.paths,
  });

  /// The skill's identifier, matching its registry entry.
  final String skill;

  /// What kind of installable produced [paths]: `'audit'` for a
  /// [SkillBundle], `'workflow'` for a [WorkflowSkill]. Kept as a plain
  /// string (rather than an enum tied to those types) so this file has no
  /// dependency on the content layer and can't create an import cycle.
  final String kind;

  /// Every file or directory somnio wrote for [skill], each relative to
  /// its own [ManifestPath.root].
  final List<ManifestPath> paths;

  /// Reconstructs a [ManifestEntry] from its JSON map.
  factory ManifestEntry.fromJson(String skill, Map<String, dynamic> json) {
    final pathsJson = json['paths'] as List<dynamic>? ?? [];
    return ManifestEntry(
      skill: skill,
      kind: json['kind'] as String? ?? '',
      paths: pathsJson
          .map((e) => ManifestPath.fromJson(e as Map<String, dynamic>))
          .where((path) => path.isContained)
          .toList(),
    );
  }

  /// Serializes to the on-disk map shape (excluding the [skill] key,
  /// which is the map key it's stored under, not a field of the value).
  Map<String, dynamic> toJson() {
    final sortedPaths = [...paths]..sort((a, b) => a.compareTo(b));
    return {
      'kind': kind,
      'paths': sortedPaths.map((p) => p.toJson()).toList(),
    };
  }
}

/// The record of what somnio installed for one agent at one scope
/// (global or project).
///
/// Lives as `.somnio-skills.json` at the root of an agent's resolved
/// install directory — e.g. `~/.claude/skills/.somnio-skills.json` for a
/// global Claude install, `<project>/.claude/skills/.somnio-skills.json`
/// for a project one. One manifest per (agent, scope) pair falls out of
/// that directory choice naturally, with no extra keying needed.
///
/// This is the source of truth that lets `somnio skills remove` and
/// `somnio skills update` distinguish CLI-installed skills from ones the
/// user authored by hand, instead of guessing from name collisions
/// against the registry.
class SkillManifest {
  SkillManifest._(this.directory, Map<String, ManifestEntry> entries)
      : _entries = entries;

  /// The manifest file's name, chosen to be dotfile-hidden and namespaced
  /// so it never collides with a user-authored skill directory.
  static const fileName = '.somnio-skills.json';

  /// On-disk schema version. Bump this if the shape of the JSON changes
  /// in a way older CLI versions can't read; [load] treats any other
  /// version as absent rather than misinterpreting it.
  static const formatVersion = 1;

  /// Loads the manifest rooted at [directory], or an empty one when the
  /// file is absent, unreadable, malformed JSON, has an unexpected shape,
  /// or declares a [formatVersion] this CLI doesn't understand.
  ///
  /// A corrupt manifest must never throw: install/update/remove all read
  /// this on every run, so a single bad file could otherwise wedge the
  /// CLI permanently for that agent/scope. Treating it as empty is always
  /// safe — worst case, `remove`/`update` see nothing installed and a
  /// later install rewrites the file cleanly.
  static SkillManifest load(String directory) {
    final file = File(p.join(directory, fileName));
    if (!file.existsSync()) {
      return SkillManifest._(directory, {});
    }
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        return SkillManifest._(directory, {});
      }
      if (decoded['version'] != formatVersion) {
        return SkillManifest._(directory, {});
      }
      final skillsJson = decoded['skills'];
      if (skillsJson is! Map<String, dynamic>) {
        return SkillManifest._(directory, {});
      }
      final entries = <String, ManifestEntry>{};
      for (final entry in skillsJson.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) continue;
        entries[entry.key] = ManifestEntry.fromJson(entry.key, value);
      }
      return SkillManifest._(directory, entries);
    } on FormatException {
      return SkillManifest._(directory, {});
    } on TypeError {
      // Thrown by the `as`/map casts above when a field has an unexpected
      // shape (e.g. `paths` present but not a list of maps).
      return SkillManifest._(directory, {});
    } on FileSystemException {
      return SkillManifest._(directory, {});
    }
  }

  /// The directory this manifest lives in — the agent's resolved install
  /// root for this scope.
  final String directory;

  final Map<String, ManifestEntry> _entries;

  /// Full path to the manifest file on disk.
  String get path => p.join(directory, fileName);

  /// All recorded entries, sorted by skill name so iteration order is
  /// deterministic regardless of insertion order.
  List<ManifestEntry> get entries {
    final sorted = _entries.values.toList()
      ..sort((a, b) => a.skill.compareTo(b.skill));
    return sorted;
  }

  /// Skill names currently recorded, sorted.
  List<String> get skillNames => entries.map((e) => e.skill).toList();

  /// Whether nothing is currently recorded.
  bool get isEmpty => _entries.isEmpty;

  /// The recorded entry for [skill], or null if somnio never installed it
  /// (or it was already removed) at this location.
  ManifestEntry? entryFor(String skill) => _entries[skill];

  /// Records (or replaces) the set of paths somnio wrote for [skill].
  ///
  /// A second call for the same skill fully replaces its previous entry
  /// rather than merging paths, so a re-install that drops a file also
  /// drops it from the manifest instead of leaking a stale reference.
  void record({
    required String skill,
    required String kind,
    required List<ManifestPath> paths,
  }) {
    _entries[skill] = ManifestEntry(skill: skill, kind: kind, paths: paths);
  }

  /// Drops [skill] from the manifest and returns the entry that was
  /// removed, or null if it wasn't recorded.
  ManifestEntry? removeEntry(String skill) => _entries.remove(skill);

  /// Persists the current entries to [path].
  ///
  /// Skills are sorted by name and each entry's paths by (root, path)
  /// before serializing, so re-installing the same skills byte-for-byte
  /// reproduces the same file — no spurious diffs from map iteration
  /// order. When no entries remain, the manifest file is deleted outright
  /// rather than written as `{"version": 1, "skills": {}}`, so an emptied
  /// install leaves no litter behind in the agent's skill directory.
  void save() {
    final file = File(path);
    if (_entries.isEmpty) {
      if (file.existsSync()) file.deleteSync();
      return;
    }

    final sortedNames = skillNames;
    final skillsJson = <String, dynamic>{
      for (final name in sortedNames) name: _entries[name]!.toJson(),
    };
    final json = {
      'version': formatVersion,
      'skills': skillsJson,
    };

    file.parent.createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync('${encoder.convert(json)}\n');
  }
}
