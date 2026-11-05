import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/platform_utils.dart';
import '../utils/yaml_frontmatter.dart';

/// The skills.sh `source` value of every skill installed from this repo.
const somnioSkillsShSource = 'somnio-software/somnio-ai-tools';

/// Matches a `sourceUrl` that points at this repo on GitHub, over HTTPS or
/// SSH, with or without a trailing `.git` or `/`.
final _somnioSourceUrl = RegExp(
  r'^(?:(?:https?|git|ssh)://)?(?:[^@/]+@)?(?:www\.)?github\.com[/:]'
  r'somnio-software/somnio-ai-tools(?:\.git)?/?$',
  caseSensitive: false,
);

/// Base directory an agent skills directory is resolved against.
enum _Root {
  /// The user's home directory.
  home,

  /// `$XDG_CONFIG_HOME`, or `~/.config`.
  configHome,

  /// `$CLAUDE_CONFIG_DIR`, or `~/.claude`.
  claudeConfig,

  /// `$CODEX_HOME`, or `~/.codex`.
  codexHome,

  /// `$VIBE_HOME`, or `~/.vibe`.
  vibeHome,

  /// `$HERMES_HOME`, or `~/.hermes`.
  hermesHome,

  /// `$AUTOHAND_HOME`, or `~/.autohand`.
  autohandHome,

  /// `$GROK_HOME`, or `~/.grok`.
  grokHome,
}

/// Global skill directories where skills.sh (`npx skills add -g`) links a
/// skill for non-universal agents, as `(root, relative path)` pairs.
///
/// Transcribed from the agent table in skills v1.5.20 `dist/cli.mjs`. The
/// trailing block is defensive: directories older skills.sh versions may have
/// linked into. Including extra directories is harmless because only a
/// symlink that resolves to the skill's canonical `~/.agents/skills/<name>`
/// copy is ever removed from them.
const _agentSkillDirectories = <(_Root, String)>[
  (_Root.home, '.aider-desk/skills'),
  (_Root.home, '.astrbot/data/skills'),
  (_Root.autohandHome, 'skills'),
  (_Root.home, '.augment/skills'),
  (_Root.home, '.bob/skills'),
  (_Root.claudeConfig, 'skills'),
  (_Root.home, '.openclaw/skills'),
  (_Root.home, '.clawdbot/skills'),
  (_Root.home, '.moltbot/skills'),
  (_Root.home, '.codeartsdoer/skills'),
  (_Root.home, '.codebuddy/skills'),
  (_Root.home, '.codemaker/skills'),
  (_Root.home, '.codestudio/skills'),
  (_Root.home, '.commandcode/skills'),
  (_Root.home, '.continue/skills'),
  (_Root.home, '.snowflake/cortex/skills'),
  // Hard-coded to ~/.config in skills.sh, independent of XDG_CONFIG_HOME.
  (_Root.home, '.config/crush/skills'),
  (_Root.configHome, 'devin/skills'),
  (_Root.home, '.factory/skills'),
  (_Root.home, '.forge/skills'),
  (_Root.configHome, 'goose/skills'),
  (_Root.grokHome, 'skills'),
  (_Root.hermesHome, 'skills'),
  (_Root.home, '.inferencesh/skills'),
  (_Root.home, '.jazz/skills'),
  (_Root.home, '.junie/skills'),
  (_Root.home, '.iflow/skills'),
  (_Root.home, '.kilocode/skills'),
  (_Root.home, '.config/kimchi/harness/skills'),
  (_Root.home, '.kiro/skills'),
  (_Root.home, '.kode/skills'),
  (_Root.home, '.lingma/skills'),
  (_Root.home, '.mcpjam/skills'),
  (_Root.vibeHome, 'skills'),
  (_Root.home, '.moxby/skills'),
  (_Root.home, '.mux/skills'),
  (_Root.home, '.openhands/skills'),
  (_Root.home, '.ona/skills'),
  (_Root.home, '.pi/agent/skills'),
  (_Root.home, '.qoder/skills'),
  (_Root.home, '.qoder-cn/skills'),
  (_Root.home, '.qwen/skills'),
  (_Root.home, '.reasonix/skills'),
  (_Root.home, '.rovodev/skills'),
  (_Root.home, '.roo/skills'),
  (_Root.home, '.tabnine/agent/skills'),
  (_Root.home, '.terramind/skills'),
  (_Root.home, '.tinycloud/skills'),
  (_Root.home, '.trae/skills'),
  (_Root.home, '.trae-cn/skills'),
  (_Root.home, '.codeium/windsurf/skills'),
  (_Root.home, '.zcode/skills'),
  (_Root.home, '.zencoder/skills'),
  (_Root.home, '.neovate/skills'),
  (_Root.home, '.pochi/skills'),
  (_Root.home, '.adal/skills'),
  // Defensive: not linked by v1.5.20, possibly by older versions.
  (_Root.home, '.cursor/skills'),
  (_Root.codexHome, 'skills'),
  (_Root.home, '.gemini/skills'),
  (_Root.home, '.copilot/skills'),
  (_Root.configHome, 'opencode/skills'),
  (_Root.configHome, 'agents/skills'),
  (_Root.home, '.gemini/antigravity/skills'),
  (_Root.home, '.gemini/antigravity-cli/skills'),
  (_Root.home, '.deepagents/agent/skills'),
  (_Root.home, '.firebender/skills'),
];

/// Converts a skill name to the directory name skills.sh installs it under.
///
/// Mirrors skills.sh's `sanitizeName`: lowercases, collapses every run of
/// characters outside `[a-z0-9._]` into `-`, and trims leading and trailing
/// `.` and `-`. The trim also guarantees the result is never `.` or `..`.
String skillsShSanitizeName(String name) => name
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9._]+'), '-')
    .replaceAll(RegExp(r'^[.\-]+|[.\-]+$'), '');

/// Whether [entry] is a symlink into skills.sh's canonical skills directory
/// `<home>/.agents/skills` — i.e. content skills.sh manages, not evidence
/// that the agent owning [entry]'s folder is installed.
///
/// Uses the same resolution as the cleanup: a relative target is resolved
/// against the link's folder both as written and at its real path, and
/// each result (also under its real parent) is compared with the canonical
/// directory as written and at its real path. Never follows the link.
bool isSkillsShLink(String entry, {required String home}) {
  if (!FileSystemEntity.isLinkSync(entry)) return false;
  final String target;
  try {
    target = Link(entry).targetSync();
  } on FileSystemException {
    return false;
  }
  final root = p.join(home, '.agents', 'skills');
  final realRoot = _realDirectoryOf(root);
  final roots = {p.normalize(root), if (realRoot != null) realRoot};
  bool inRoot(String path) =>
      roots.any((r) => p.equals(r, path) || p.isWithin(r, path));

  final parent = p.dirname(entry);
  final realParent = _realDirectoryOf(parent);
  final resolved = p.isAbsolute(target)
      ? [p.normalize(target)]
      : [
          for (final dir in {parent, if (realParent != null) realParent})
            p.normalize(p.join(dir, target)),
        ];
  for (final path in resolved) {
    if (inRoot(path)) return true;
    final realDir = _realDirectoryOf(p.dirname(path));
    if (realDir != null && inRoot(p.join(realDir, p.basename(path)))) {
      return true;
    }
  }
  return false;
}

/// The real path of the directory [path], or `null` if it can't be resolved.
String? _realDirectoryOf(String path) {
  try {
    return Directory(path).resolveSymbolicLinksSync();
  } on FileSystemException {
    return null;
  }
}

/// What sits at a skill's canonical `~/.agents/skills/<name>` path.
enum CanonicalKind {
  /// A real directory — deleted recursively.
  directory,

  /// A symlink — unlinked, never followed.
  link,

  /// Something else (a plain file) — left untouched, and the skill's lock
  /// entry is kept.
  other,

  /// Nothing — already gone; any agent links to it dangle.
  missing,
}

/// The cleanup planned for one Somnio skill folder recorded in the skills.sh
/// lock.
class SkillsShSkillPlan {
  /// Creates the plan for the lock entry [name] (plus any [aliases] that
  /// sanitize to the same folder).
  const SkillsShSkillPlan({
    required this.name,
    required this.canonicalPath,
    required this.canonicalKind,
    required this.links,
    this.aliases = const [],
  });

  /// The skill's key in the skills.sh lock.
  final String name;

  /// Other Somnio lock keys that sanitize to the same folder as [name]
  /// (e.g. `Foo` next to `foo`); they are cleaned up together.
  final List<String> aliases;

  /// The skill's canonical copy, `~/.agents/skills/<sanitized name>`.
  final String canonicalPath;

  /// What sat at [canonicalPath] when this plan was made.
  final CanonicalKind canonicalKind;

  /// Agent-folder symlinks that resolve to [canonicalPath].
  final List<String> links;

  /// Every lock key this plan removes once the cleanup succeeds.
  List<String> get lockKeys => [name, ...aliases];

  /// Whether applying this plan deletes something at [canonicalPath].
  bool get removesCanonical =>
      canonicalKind == CanonicalKind.directory ||
      canonicalKind == CanonicalKind.link;
}

/// The full skills.sh cleanup plan: everything [SkillsShCleaner.apply] would
/// remove, computed without touching the file system.
class SkillsShCleanupPlan {
  /// Creates a plan for the lock at [lockPath].
  const SkillsShCleanupPlan({
    required this.lockPath,
    this.skills = const [],
    this.warnings = const [],
    this.emptiedDirectories = const [],
  });

  /// The skills.sh global lock file this plan was read from.
  final String lockPath;

  /// One entry per Somnio skill folder recorded in the lock.
  final List<SkillsShSkillPlan> skills;

  /// Problems found while planning: an unreadable lock, or entries skipped
  /// because removing them would not be safe.
  final List<String> warnings;

  /// Agent skill folders that hold nothing but links this plan removes, so
  /// they will be empty afterwards and are removed too (skills.sh creates
  /// them for agents the user may not have; left empty, they would make
  /// those agents look installed).
  final List<String> emptiedDirectories;

  /// Whether there is nothing to clean up.
  bool get isEmpty => skills.isEmpty;

  /// The total number of agent-folder symlinks to remove.
  int get linkCount =>
      skills.fold(0, (count, skill) => count + skill.links.length);

  /// The number of canonical copies to remove.
  int get canonicalCount => skills.where((s) => s.removesCanonical).length;

  /// A human-readable description of this plan, one line per element.
  ///
  /// Lists each skill with its canonical copy and its link count. With
  /// [verbose], every link path is listed under its skill as well.
  List<String> describe({bool verbose = false}) {
    if (isEmpty) {
      return ['No Somnio skills installed by skills.sh were found.'];
    }
    final skillWord = skills.length == 1 ? 'skill' : 'skills';
    final linkWord = linkCount == 1 ? 'link' : 'links';
    final dirWord = canonicalCount == 1 ? 'copy' : 'copies';
    final lines = <String>[
      'Somnio skills installed by skills.sh (global, $lockPath):',
      '${skills.length} $skillWord, $linkCount agent $linkWord, '
          '$canonicalCount canonical $dirWord to remove.',
    ];
    for (final skill in skills) {
      final links = skill.links.length;
      final aliases = skill.aliases.isEmpty
          ? ''
          : ' (also lock entries: ${skill.aliases.join(', ')})';
      lines
        ..add('  ${skill.name}$aliases')
        ..add('    canonical: ${skill.canonicalPath} '
            '(${_describeCanonical(skill.canonicalKind)})')
        ..add('    links:     $links');
      if (verbose) {
        for (final link in skill.links) {
          lines.add('      $link');
        }
      }
    }
    if (emptiedDirectories.isNotEmpty) {
      final count = emptiedDirectories.length;
      lines.add(
        '$count empty agent skill ${count == 1 ? 'folder' : 'folders'} '
        'will be removed.',
      );
      if (verbose) {
        for (final dir in emptiedDirectories) {
          lines.add('      $dir');
        }
      }
    }
    return lines;
  }

  static String _describeCanonical(CanonicalKind kind) => switch (kind) {
        CanonicalKind.directory => 'directory, will be deleted',
        CanonicalKind.link => 'symlink, will be unlinked',
        CanonicalKind.other => 'not a directory, left untouched',
        CanonicalKind.missing => 'already missing',
      };
}

/// What [SkillsShCleaner.apply] actually removed.
class SkillsShCleanupResult {
  /// Creates a cleanup result.
  const SkillsShCleanupResult({
    this.removedSkills = const [],
    this.unlinkedLinks = const [],
    this.deletedCanonicals = const [],
    this.removedDirectories = const [],
    this.warnings = const [],
  });

  /// Lock keys of the skills that were fully cleaned and dropped from the
  /// lock.
  final List<String> removedSkills;

  /// Agent-folder symlinks that were removed.
  final List<String> unlinkedLinks;

  /// Canonical `~/.agents/skills/<name>` entries that were removed.
  final List<String> deletedCanonicals;

  /// Agent skill folders left empty by the unlinking, which were removed.
  final List<String> removedDirectories;

  /// Per-item failures and skips; every other item was still processed.
  final List<String> warnings;
}

/// Removes Somnio skills that skills.sh (`npx skills add -g`) installed.
///
/// Those installs are not recorded in Somnio's `.somnio-skills.json`
/// manifest, so `somnio skills update` never refreshes them: they go stale
/// and duplicate the Somnio-managed copies. Only lock entries whose source is
/// this repo are candidates; third-party skills are never touched. For each
/// candidate it removes the agent-folder symlinks that resolve to the
/// skill's canonical copy, then the canonical copy, then the lock entry.
///
/// Safety rules:
/// - Real directories in agent folders (copy-mode installs, other
///   installers, hand-written skills) are never deleted, and no link is ever
///   followed: only the [Link] itself is removed.
/// - A Somnio entry whose folder name collides with a non-Somnio lock entry,
///   or whose canonical `SKILL.md` names a different skill, is skipped
///   entirely and its lock entry kept.
/// - An unreadable or unrecognised lock touches nothing.
/// - [apply] only executes a confirmed [plan], re-checking every item first.
///
/// Global scope only. A project's `skills-lock.json` and `.agents/skills`
/// may be committed to git, so deleting them could destroy tracked files;
/// project-scope installs are deliberately left alone.
class SkillsShCleaner {
  /// Creates a cleaner rooted at [homeDirectory] (default: the user's home)
  /// that reads env overrides from [environment] (default: the process
  /// environment).
  SkillsShCleaner({String? homeDirectory, Map<String, String>? environment})
      : homeDirectory = homeDirectory ?? PlatformUtils.homeDirectory,
        _environment = environment ?? Platform.environment;

  /// The home directory every default path is resolved against.
  final String homeDirectory;

  final Map<String, String> _environment;

  /// The skills.sh global lock file.
  ///
  /// `$XDG_STATE_HOME/skills/.skill-lock.json` when `XDG_STATE_HOME` is set,
  /// otherwise `~/.agents/.skill-lock.json`.
  String get lockPath {
    final stateHome = _env('XDG_STATE_HOME');
    return stateHome != null
        ? p.join(stateHome, 'skills', '.skill-lock.json')
        : p.join(homeDirectory, '.agents', '.skill-lock.json');
  }

  /// The directory holding skills.sh's canonical skill copies.
  String get canonicalSkillsDirectory =>
      p.join(homeDirectory, '.agents', 'skills');

  /// Every agent skills directory searched for links, deduplicated.
  List<String> get agentSkillDirectories {
    final dirs = LinkedHashSet<String>();
    for (final (root, relative) in _agentSkillDirectories) {
      dirs.add(p.normalize(p.join(_resolveRoot(root), relative)));
    }
    return dirs.toList();
  }

  /// Computes what [apply] would remove, without side effects.
  SkillsShCleanupPlan plan() => _discover().plan;

  /// Executes the confirmed [plan] and rewrites the lock.
  ///
  /// Every item is re-checked against the current state first: a skill whose
  /// canonical copy changed kind, or that is no longer a safe candidate, is
  /// skipped, and a link is only removed if it still resolves to the
  /// canonical copy. Nothing outside [plan] is ever removed. A skill's lock
  /// entries are only dropped when all of its paths were removed, so a later
  /// run can retry the rest. Failures are collected as warnings and never
  /// stop the remaining items. An unreadable lock touches nothing.
  SkillsShCleanupResult apply(SkillsShCleanupPlan plan) {
    final current = _discover();
    final lockSkills = current.lockSkills;
    if (lockSkills == null) {
      return SkillsShCleanupResult(warnings: current.plan.warnings);
    }
    final currentByPath = {
      for (final skill in current.plan.skills) skill.canonicalPath: skill,
    };

    final warnings = <String>[];
    final removedSkills = <String>[];
    final unlinked = <String>[];
    final deletedCanonicals = <String>[];
    final touchedDirectories = LinkedHashSet<String>();

    for (final planned in plan.skills) {
      final now = currentByPath[planned.canonicalPath];
      if (now == null || now.canonicalKind != planned.canonicalKind) {
        warnings.add(
          'Skipped ${planned.name}: it changed after the cleanup was planned.',
        );
        continue;
      }

      var complete = true;
      final currentLinks = now.links.toSet();
      for (final link in planned.links) {
        if (!currentLinks.contains(link)) {
          // Already gone is fine; anything else no longer is ours to remove.
          if (_exists(link)) {
            complete = false;
            warnings.add(
              'Left $link in place: it no longer links to '
              '${planned.canonicalPath}.',
            );
          }
          continue;
        }
        try {
          Link(link).deleteSync();
          unlinked.add(link);
          touchedDirectories.add(p.dirname(link));
        } on FileSystemException catch (e) {
          complete = false;
          warnings.add('Could not remove link $link: ${e.message}');
        }
      }

      try {
        switch (planned.canonicalKind) {
          case CanonicalKind.directory:
            Directory(planned.canonicalPath).deleteSync(recursive: true);
            deletedCanonicals.add(planned.canonicalPath);
          case CanonicalKind.link:
            Link(planned.canonicalPath).deleteSync();
            deletedCanonicals.add(planned.canonicalPath);
          case CanonicalKind.other:
            complete = false;
            warnings.add(
              'Left ${planned.canonicalPath} in place: it is not a directory.',
            );
          case CanonicalKind.missing:
            break;
        }
      } on FileSystemException catch (e) {
        complete = false;
        warnings.add(
          'Could not remove ${planned.canonicalPath}: ${e.message}',
        );
      }

      if (complete) {
        final keys = now.lockKeys.toSet();
        for (final key in planned.lockKeys) {
          if (keys.contains(key)) lockSkills.remove(key);
        }
        removedSkills.add(planned.name);
      }
    }

    final removedDirectories = <String>[];
    for (final dir in touchedDirectories) {
      if (!_isEmptyAgentFolder(dir, const {})) continue;
      try {
        // Non-recursive: fails rather than delete anything that appeared.
        Directory(dir).deleteSync();
        removedDirectories.add(dir);
      } on FileSystemException catch (e) {
        warnings.add('Could not remove empty folder $dir: ${e.message}');
      }
    }

    if (removedSkills.isNotEmpty) {
      try {
        _writeLock(current.lock!);
      } on FileSystemException catch (e) {
        warnings.add('Could not update $lockPath: ${e.message}');
      }
    }

    return SkillsShCleanupResult(
      removedSkills: removedSkills,
      unlinkedLinks: unlinked,
      deletedCanonicals: deletedCanonicals,
      removedDirectories: removedDirectories,
      warnings: warnings,
    );
  }

  /// Whether [dir] is a real agent skill folder (never the canonical
  /// `~/.agents/skills` itself) that holds nothing besides [removing].
  bool _isEmptyAgentFolder(String dir, Set<String> removing) {
    if (p.equals(dir, canonicalSkillsDirectory)) return false;
    if (FileSystemEntity.typeSync(dir, followLinks: false) !=
        FileSystemEntityType.directory) {
      return false;
    }
    try {
      return Directory(dir)
          .listSync(followLinks: false)
          .every((entity) => removing.contains(entity.path));
    } on FileSystemException {
      return false;
    }
  }

  /// Reads the lock and builds the plan; shared by [plan] and [apply].
  _Discovery _discover() {
    final path = lockPath;
    final file = File(path);
    if (!file.existsSync()) {
      return _Discovery(SkillsShCleanupPlan(lockPath: path));
    }

    Map<String, dynamic> lock;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != 3 ||
          decoded['skills'] is! Map<String, dynamic>) {
        return _Discovery(_unreadable(path, 'unexpected format'));
      }
      lock = decoded;
    } on FileSystemException catch (e) {
      return _Discovery(_unreadable(path, e.message));
    } on FormatException catch (e) {
      return _Discovery(_unreadable(path, 'invalid JSON (${e.message})'));
    }

    final lockSkills = lock['skills'] as Map<String, dynamic>;
    final warnings = <String>[];

    // Folders a non-Somnio entry may own: deleting them could destroy
    // third-party content, so a colliding Somnio entry is left alone.
    final foreign = <String, String>{};
    for (final MapEntry(key: name, value: entry) in lockSkills.entries) {
      if (_isSomnioEntry(entry)) continue;
      foreign.putIfAbsent(skillsShSanitizeName(name), () => name);
    }

    // Somnio keys grouped by folder, so `Foo` and `foo` are one item.
    final byFolder = LinkedHashMap<String, List<String>>();
    for (final MapEntry(key: name, value: entry) in lockSkills.entries) {
      if (!_isSomnioEntry(entry)) continue;
      final folder = skillsShSanitizeName(name);
      if (folder == 'clockify-tracker' || folder == 'clockify_tracker') {
        warnings.add(
            'Preserved retired Clockify skill "$name"; inspect and remove it manually before installing the replacement.');
        continue;
      }
      if (folder.isEmpty) {
        warnings.add('Skipped lock entry "$name": unusable skill name.');
        continue;
      }
      final owner = foreign[folder];
      if (owner != null) {
        warnings.add(
          'Skipped "$name": its folder $folder is shared with the '
          'non-Somnio skill "$owner".',
        );
        continue;
      }
      byFolder.putIfAbsent(folder, () => []).add(name);
    }

    final linkDirs = agentSkillDirectories;
    final skills = <SkillsShSkillPlan>[];
    for (final MapEntry(key: folder, value: keys) in byFolder.entries) {
      final canonical = p.join(canonicalSkillsDirectory, folder);
      final kind = _canonicalKind(canonical);
      if (kind == CanonicalKind.directory) {
        final problem = _skillFileProblem(canonical, folder);
        if (problem != null) {
          warnings.add('Skipped "${keys.first}": $problem.');
          continue;
        }
      }
      skills.add(
        SkillsShSkillPlan(
          name: keys.first,
          aliases: keys.sublist(1),
          canonicalPath: canonical,
          canonicalKind: kind,
          links: _findLinks(linkDirs, folder, canonical),
        ),
      );
    }

    final removing = {for (final skill in skills) ...skill.links};
    final emptied = [
      for (final dir in LinkedHashSet.of(removing.map(p.dirname)))
        if (_isEmptyAgentFolder(dir, removing)) dir,
    ];

    return _Discovery(
      SkillsShCleanupPlan(
        lockPath: path,
        skills: skills,
        warnings: warnings,
        emptiedDirectories: emptied,
      ),
      lock: lock,
      lockSkills: lockSkills,
    );
  }

  SkillsShCleanupPlan _unreadable(String path, String reason) =>
      SkillsShCleanupPlan(
        lockPath: path,
        warnings: [
          'Skipped skills.sh cleanup: could not read $path ($reason). '
              'Nothing was changed.',
        ],
      );

  /// The links named [folder] in [dirs] that resolve to [canonical], each
  /// listed once even when two agent dirs are the same real directory.
  static List<String> _findLinks(
    List<String> dirs,
    String folder,
    String canonical,
  ) {
    final seen = <String>{};
    final links = <String>[];
    for (final dir in dirs) {
      final entry = p.join(dir, folder);
      if (!_linksTo(entry, canonical)) continue;
      final realKey = p.join(_realDirectoryOf(dir) ?? dir, folder);
      if (seen.add(realKey)) links.add(entry);
    }
    return links;
  }

  /// Whether a lock entry was installed from this repo.
  static bool _isSomnioEntry(Object? entry) {
    if (entry is! Map<String, dynamic>) return false;
    final source = entry['source'];
    if (source is String &&
        source.trim().toLowerCase() == somnioSkillsShSource) {
      return true;
    }
    final url = entry['sourceUrl'];
    return url is String && _somnioSourceUrl.hasMatch(url.trim());
  }

  /// Why the canonical directory at [dir] must not be deleted as the skill
  /// [folder], or `null` when it is safe.
  ///
  /// A directory without a `SKILL.md` is accepted. One with a `SKILL.md`
  /// must declare a frontmatter `name` that sanitizes to [folder].
  static String? _skillFileProblem(String dir, String folder) {
    final file = File(p.join(dir, 'SKILL.md'));
    if (!file.existsSync()) return null;
    final String content;
    try {
      content = file.readAsStringSync();
    } on FileSystemException catch (e) {
      return 'its SKILL.md could not be read (${e.message})';
    }
    final name = frontmatterName(content);
    if (name == null) return 'its SKILL.md has no frontmatter name';
    if (skillsShSanitizeName(name) != folder) {
      return 'its SKILL.md belongs to a different skill ("$name")';
    }
    return null;
  }

  /// Whether [entry] is a symlink whose target resolves to [canonical].
  ///
  /// A relative target is resolved against the link's directory both as
  /// written and at its real path (skills.sh computes the target from the
  /// real path, so this matters when an agent dir such as `~/.claude` is
  /// itself a symlink). Each resolution, and the same path under its real
  /// parent directory, is compared with [canonical] both as written and
  /// under the real path of its parent. Never follows the link itself, so
  /// dangling links match too.
  static bool _linksTo(String entry, String canonical) {
    if (!FileSystemEntity.isLinkSync(entry)) return false;
    final String target;
    try {
      target = Link(entry).targetSync();
    } on FileSystemException {
      return false;
    }

    final canonicalParent = _realDirectoryOf(p.dirname(canonical));
    final canonicals = {
      p.normalize(canonical),
      if (canonicalParent != null)
        p.join(canonicalParent, p.basename(canonical)),
    };
    final parent = p.dirname(entry);
    final realParent = _realDirectoryOf(parent);
    final resolved = p.isAbsolute(target)
        ? [p.normalize(target)]
        : [
            for (final dir in [parent, if (realParent != null) realParent])
              p.normalize(p.join(dir, target)),
          ];
    for (final path in resolved) {
      if (canonicals.contains(path)) return true;
      // Same entry reached through a symlinked parent directory.
      final realDir = _realDirectoryOf(p.dirname(path));
      if (realDir != null &&
          canonicals.contains(p.join(realDir, p.basename(path)))) {
        return true;
      }
    }
    return false;
  }

  static bool _exists(String path) =>
      FileSystemEntity.typeSync(path, followLinks: false) !=
      FileSystemEntityType.notFound;

  static CanonicalKind _canonicalKind(String path) =>
      switch (FileSystemEntity.typeSync(path, followLinks: false)) {
        FileSystemEntityType.directory => CanonicalKind.directory,
        FileSystemEntityType.link => CanonicalKind.link,
        FileSystemEntityType.notFound => CanonicalKind.missing,
        _ => CanonicalKind.other,
      };

  /// Writes [lock] back the way skills.sh does (`JSON.stringify(lock, null,
  /// 2)`, no trailing newline), via a temp file so a failed write never
  /// leaves a truncated lock behind.
  ///
  /// When the lock path is a symlink, the file it points to is replaced and
  /// the symlink is kept.
  void _writeLock(Map<String, dynamic> lock) {
    var path = lockPath;
    if (FileSystemEntity.isLinkSync(path)) {
      path = File(path).resolveSymbolicLinksSync();
    }
    final temp = File('$path.somnio-tmp');
    temp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(lock));
    temp.renameSync(path);
  }

  String _resolveRoot(_Root root) => switch (root) {
        _Root.home => homeDirectory,
        _Root.configHome =>
          _env('XDG_CONFIG_HOME') ?? p.join(homeDirectory, '.config'),
        _Root.claudeConfig =>
          _env('CLAUDE_CONFIG_DIR') ?? p.join(homeDirectory, '.claude'),
        _Root.codexHome =>
          _env('CODEX_HOME') ?? p.join(homeDirectory, '.codex'),
        _Root.vibeHome => _env('VIBE_HOME') ?? p.join(homeDirectory, '.vibe'),
        _Root.hermesHome =>
          _env('HERMES_HOME') ?? p.join(homeDirectory, '.hermes'),
        _Root.autohandHome =>
          _env('AUTOHAND_HOME') ?? p.join(homeDirectory, '.autohand'),
        _Root.grokHome => _env('GROK_HOME') ?? p.join(homeDirectory, '.grok'),
      };

  /// The trimmed value of the environment variable [name], or `null` when it
  /// is unset or blank.
  String? _env(String name) {
    final value = _environment[name]?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}

/// The parsed lock alongside the plan built from it, so [SkillsShCleaner.apply]
/// can edit the same map it re-checked against.
class _Discovery {
  _Discovery(this.plan, {this.lock, this.lockSkills});

  final SkillsShCleanupPlan plan;
  final Map<String, dynamic>? lock;
  final Map<String, dynamic>? lockSkills;
}
