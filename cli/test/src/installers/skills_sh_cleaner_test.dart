import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/installers/skills_sh_cleaner.dart';
import 'package:somnio/src/utils/platform_utils.dart';
import 'package:test/test.dart';

const _somnioUrl = 'https://github.com/somnio-software/somnio-ai-tools.git';

/// A skills.sh lock entry for a skill installed from [source].
Map<String, Object?> _entry(
  String name, {
  String source = somnioSkillsShSource,
  String? sourceUrl = _somnioUrl,
}) =>
    {
      'source': source,
      'sourceType': 'github',
      if (sourceUrl != null) 'sourceUrl': sourceUrl,
      'skillPath': 'skills/$name/SKILL.md',
      'skillFolderHash': 'abc123',
      'installedAt': '2026-03-25T18:50:48.975Z',
      'updatedAt': '2026-07-31T20:49:50.193Z',
    };

/// Writes [lock] the way skills.sh does: 2-space JSON, no trailing newline.
void _writeLock(String path, Map<String, Object?> lock) {
  Directory(p.dirname(path)).createSync(recursive: true);
  File(path).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(lock),
  );
}

Map<String, Object?> _lockWith(Map<String, Object?> skills) => {
      'version': 3,
      'skills': skills,
      'dismissed': {'findSkillsPrompt': true},
      'lastSelectedAgents': ['claude-code', 'cursor'],
    };

/// Creates the canonical `~/.agents/skills/<name>` copy with a SKILL.md.
String _canonical(String home, String name) {
  final dir = p.join(home, '.agents', 'skills', name);
  Directory(dir).createSync(recursive: true);
  File(p.join(dir, 'SKILL.md')).writeAsStringSync('---\nname: $name\n---\n');
  return dir;
}

/// Creates a relative symlink `<home>/<agentDir>/<name>` pointing at the
/// canonical copy, exactly like `npx skills add -g`.
String _relativeLink(String home, String agentDir, String name) {
  final linkPath = p.join(home, agentDir, name);
  Directory(p.dirname(linkPath)).createSync(recursive: true);
  final target = p.relative(
    p.join(home, '.agents', 'skills', name),
    from: p.dirname(linkPath),
  );
  Link(linkPath).createSync(target);
  return linkPath;
}

/// Plans and applies in one go, as a user who confirms immediately would.
SkillsShCleanupResult _applyAll(SkillsShCleaner cleaner) =>
    cleaner.apply(cleaner.plan());

bool _exists(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false) !=
    FileSystemEntityType.notFound;

void main() {
  late Directory temp;
  late String home;
  late String lockPath;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('skills_sh_cleaner_test_');
    home = temp.path;
    lockPath = p.join(home, '.agents', '.skill-lock.json');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  SkillsShCleaner cleaner([Map<String, String> env = const {}]) =>
      SkillsShCleaner(homeDirectory: home, environment: env);

  group('skillsShSanitizeName', () {
    test('lowercases and collapses disallowed characters into dashes', () {
      expect(skillsShSanitizeName('My Skill!!Name'), 'my-skill-name');
    });

    test('keeps dots and underscores', () {
      expect(skillsShSanitizeName('a.b_c'), 'a.b_c');
    });

    test('trims leading and trailing dots and dashes', () {
      expect(skillsShSanitizeName('..-name-.'), 'name');
    });

    test('reduces a dot-only name to empty', () {
      expect(skillsShSanitizeName('..'), isEmpty);
    });
  });

  group('SkillsShCleaner', () {
    test('preserves modified retired Clockify skills and lock entries', () {
      _writeLock(lockPath,
          _lockWith({'clockify-tracker': _entry('clockify-tracker')}));
      final dir =
          Directory(p.join(home, '.agents', 'skills', 'clockify-tracker'))
            ..createSync(recursive: true);
      final custom = File(p.join(dir.path, 'custom.txt'))
        ..writeAsStringSync('custom');
      final before = File(lockPath).readAsStringSync();
      final c = cleaner();

      final plan = c.plan();
      final result = c.apply(plan);

      expect(plan.skills, isEmpty);
      expect(plan.warnings, contains(contains('clockify-tracker')));
      expect(result.removedSkills, isEmpty);
      expect(custom.readAsStringSync(), 'custom');
      expect(File(lockPath).readAsStringSync(), before);
    });

    test('defaults to the user home directory', () {
      expect(SkillsShCleaner().homeDirectory, PlatformUtils.homeDirectory);
    });

    group('lockPath', () {
      test('defaults to ~/.agents/.skill-lock.json', () {
        expect(cleaner().lockPath, lockPath);
      });

      test('uses XDG_STATE_HOME when set', () {
        final c = cleaner({'XDG_STATE_HOME': p.join(home, 'state')});

        expect(c.lockPath, p.join(home, 'state', 'skills', '.skill-lock.json'));
      });

      test('ignores a blank XDG_STATE_HOME', () {
        expect(cleaner({'XDG_STATE_HOME': '  '}).lockPath, lockPath);
      });
    });

    group('agentSkillDirectories', () {
      test('includes nested agent directories', () {
        final dirs = cleaner().agentSkillDirectories;

        expect(
          dirs,
          containsAll([
            p.join(home, '.pi', 'agent', 'skills'),
            p.join(home, '.config', 'goose', 'skills'),
            p.join(home, '.claude', 'skills'),
          ]),
        );
      });

      test('resolves every env override', () {
        final dirs = cleaner({
          'CLAUDE_CONFIG_DIR': '/c',
          'CODEX_HOME': '/x',
          'VIBE_HOME': '/v',
          'HERMES_HOME': '/h',
          'AUTOHAND_HOME': '/a',
          'GROK_HOME': '/g',
          'XDG_CONFIG_HOME': '/cfg',
        }).agentSkillDirectories;

        expect(
          dirs,
          containsAll([
            '/c/skills',
            '/x/skills',
            '/v/skills',
            '/h/skills',
            '/a/skills',
            '/g/skills',
            '/cfg/goose/skills',
          ]),
        );
      });

      test('keeps crush under ~/.config regardless of XDG_CONFIG_HOME', () {
        final dirs = cleaner({'XDG_CONFIG_HOME': '/cfg'}).agentSkillDirectories;

        expect(dirs, contains(p.join(home, '.config', 'crush', 'skills')));
      });

      test('contains no duplicates', () {
        final dirs = cleaner({
          'XDG_CONFIG_HOME': p.join(home, '.config'),
        }).agentSkillDirectories;

        expect(dirs.toSet().length, dirs.length);
      });
    });

    group('plan', () {
      test('is empty when the lock is missing', () {
        final plan = cleaner().plan();

        expect(plan.isEmpty, isTrue);
        expect(plan.warnings, isEmpty);
      });

      test('lists canonical copy and links of a Somnio skill', () {
        _writeLock(lockPath, _lockWith({'flutter-health-audit': _entry('x')}));
        final canonical = _canonical(home, 'flutter-health-audit');
        final links = [
          _relativeLink(home, '.claude/skills', 'flutter-health-audit'),
          _relativeLink(home, '.pi/agent/skills', 'flutter-health-audit'),
        ];

        final skill = cleaner().plan().skills.single;

        expect(
          (skill.name, skill.canonicalPath, skill.canonicalKind),
          ('flutter-health-audit', canonical, CanonicalKind.directory),
        );
        expect(skill.links, unorderedEquals(links));
      });

      test('has no side effects', () {
        _writeLock(lockPath, _lockWith({'ship': _entry('ship')}));
        final canonical = _canonical(home, 'ship');
        final link = _relativeLink(home, '.claude/skills', 'ship');
        final before = File(lockPath).readAsStringSync();

        cleaner().plan();

        expect(
          (
            File(lockPath).readAsStringSync(),
            _exists(canonical),
            _exists(link),
          ),
          (before, true, true),
        );
      });

      test('matches entries by sourceUrl when source differs in form', () {
        _writeLock(
          lockPath,
          _lockWith({
            'a': _entry('a', source: 'other', sourceUrl: _somnioUrl),
            'b': _entry(
              'b',
              source: 'other',
              sourceUrl: 'git@github.com:Somnio-Software/somnio-ai-tools.git',
            ),
            'c': _entry('c', source: 'SOMNIO-SOFTWARE/somnio-ai-tools'),
          }),
        );

        final names = cleaner().plan().skills.map((s) => s.name);

        expect(names, ['a', 'b', 'c']);
      });

      test('ignores third-party and malformed entries', () {
        _writeLock(
          lockPath,
          _lockWith({
            'vercel': _entry(
              'vercel',
              source: 'vercel-labs/agent-skills',
              sourceUrl: 'https://github.com/vercel-labs/agent-skills.git',
            ),
            'lookalike': _entry(
              'lookalike',
              source: 'x',
              sourceUrl: 'https://evilgithub.com/somnio-software/'
                  'somnio-ai-tools.git',
            ),
            'no-url': _entry('no-url', source: 'x', sourceUrl: null),
            'broken': 'not a map',
          }),
        );

        expect(cleaner().plan().isEmpty, isTrue);
      });

      test('skips an entry whose name sanitizes to nothing', () {
        _writeLock(lockPath, _lockWith({'..': _entry('..')}));

        final plan = cleaner().plan();

        expect(plan.isEmpty, isTrue);
        expect(plan.warnings.single, contains('unusable skill name'));
      });

      test('reports a canonical symlink, file and missing copy', () {
        _writeLock(
          lockPath,
          _lockWith({
            'linked': _entry('linked'),
            'file': _entry('file'),
            'gone': _entry('gone'),
          }),
        );
        final skillsDir = p.join(home, '.agents', 'skills');
        Directory(skillsDir).createSync(recursive: true);
        Link(p.join(skillsDir, 'linked')).createSync(temp.path);
        File(p.join(skillsDir, 'file')).writeAsStringSync('x');

        final kinds = cleaner().plan().skills.map((s) => s.canonicalKind);

        expect(kinds, [
          CanonicalKind.link,
          CanonicalKind.other,
          CanonicalKind.missing,
        ]);
      });

      test('uses the sanitized name for the canonical copy and links', () {
        _writeLock(lockPath, _lockWith({'My Skill': _entry('My Skill')}));
        _canonical(home, 'my-skill');
        final link = _relativeLink(home, '.claude/skills', 'my-skill');

        final skill = cleaner().plan().skills.single;

        expect(p.basename(skill.canonicalPath), 'my-skill');
        expect(skill.links, [link]);
      });

      for (final (label, content) in [
        ('invalid JSON', '{not json'),
        ('a non-object root', '[]'),
        ('an unsupported version', '{"version": 2, "skills": {}}'),
        ('a non-object skills map', '{"version": 3, "skills": []}'),
      ]) {
        test('warns and plans nothing for $label', () {
          Directory(p.dirname(lockPath)).createSync(recursive: true);
          File(lockPath).writeAsStringSync(content);

          final plan = cleaner().plan();

          expect(plan.isEmpty, isTrue);
          expect(plan.warnings.single, contains('Nothing was changed'));
        });
      }

      test(
        'warns when the lock cannot be read',
        () {
          _writeLock(lockPath, _lockWith({'fha': _entry('fha')}));
          Process.runSync('chmod', ['000', lockPath]);
          addTearDown(() => Process.runSync('chmod', ['644', lockPath]));

          final plan = cleaner().plan();

          expect(plan.warnings.single, contains('could not read'));
        },
        testOn: 'posix',
      );
    });

    group('apply', () {
      test('removes relative links in every agent dir, incl. nested ones', () {
        _writeLock(lockPath, _lockWith({'flutter-health-audit': _entry('x')}));
        _canonical(home, 'flutter-health-audit');
        final links = [
          for (final dir in [
            '.claude/skills',
            '.pi/agent/skills',
            '.config/goose/skills',
            '.codeium/windsurf/skills',
          ])
            _relativeLink(home, dir, 'flutter-health-audit'),
        ];

        final result = _applyAll(cleaner());

        expect(result.unlinkedLinks, unorderedEquals(links));
        expect(links.where(_exists), isEmpty);
      });

      test('deletes the canonical directory and the lock entry', () {
        _writeLock(lockPath, _lockWith({'flutter-health-audit': _entry('x')}));
        final canonical = _canonical(home, 'flutter-health-audit');

        final result = _applyAll(cleaner());
        final lock = jsonDecode(File(lockPath).readAsStringSync()) as Map;

        expect(result.removedSkills, ['flutter-health-audit']);
        expect(result.deletedCanonicals, [canonical]);
        expect(_exists(canonical), isFalse);
        expect(lock['skills'], isNot(contains('flutter-health-audit')));
      });

      test('leaves a third-party entry, its links and canonical untouched', () {
        _writeLock(
          lockPath,
          _lockWith({
            'somnio': _entry('somnio'),
            'vercel': _entry(
              'vercel',
              source: 'vercel-labs/agent-skills',
              sourceUrl: 'https://github.com/vercel-labs/agent-skills.git',
            ),
          }),
        );
        _canonical(home, 'somnio');
        final canonical = _canonical(home, 'vercel');
        final link = _relativeLink(home, '.claude/skills', 'vercel');

        _applyAll(cleaner());
        final lock = jsonDecode(File(lockPath).readAsStringSync()) as Map;

        expect(_exists(canonical), isTrue);
        expect(_exists(link), isTrue);
        expect((lock['skills'] as Map).keys, ['vercel']);
      });

      test('never deletes a real directory with the same name', () {
        _writeLock(lockPath, _lockWith({'harness-audit': _entry('x')}));
        _canonical(home, 'harness-audit');
        final real = p.join(home, '.claude', 'skills', 'harness-audit');
        Directory(real).createSync(recursive: true);
        File(p.join(real, 'SKILL.md')).writeAsStringSync('mine');

        _applyAll(cleaner());

        expect(File(p.join(real, 'SKILL.md')).readAsStringSync(), 'mine');
      });

      test('removes dangling links when the canonical copy is gone', () {
        _writeLock(lockPath, _lockWith({'ship': _entry('ship')}));
        final links = [
          _relativeLink(home, '.codeium/windsurf/skills', 'ship'),
          _relativeLink(home, '.pi/agent/skills', 'ship'),
        ];
        final realShip = p.join(home, '.claude', 'skills', 'ship');
        Directory(realShip).createSync(recursive: true);

        final result = _applyAll(cleaner());

        expect(links.where(_exists), isEmpty);
        expect(Directory(realShip).existsSync(), isTrue);
        expect(result.removedSkills, ['ship']);
      });

      test('removes stale entries no longer in the Somnio registry', () {
        _writeLock(
          lockPath,
          _lockWith({
            'handshake-acknowledgement': _entry('handshake-acknowledgement'),
            'story-definition': _entry('story-definition'),
          }),
        );
        _canonical(home, 'handshake-acknowledgement');
        _canonical(home, 'story-definition');

        final result = _applyAll(cleaner());

        expect(
          result.removedSkills,
          ['handshake-acknowledgement', 'story-definition'],
        );
      });

      test('leaves a same-named symlink that points elsewhere', () {
        _writeLock(lockPath, _lockWith({'flutter-health-audit': _entry('x')}));
        _canonical(home, 'flutter-health-audit');
        final elsewhere = Directory(p.join(home, 'my-skills', 'fha'))
          ..createSync(recursive: true);
        final link = p.join(home, '.claude', 'skills', 'flutter-health-audit');
        Directory(p.dirname(link)).createSync(recursive: true);
        Link(link).createSync(elsewhere.path);

        _applyAll(cleaner());

        expect(Link(link).targetSync(), elsewhere.path);
      });

      test('removes an absolute symlink to the canonical copy', () {
        _writeLock(lockPath, _lockWith({'fha': _entry('fha')}));
        final canonical = _canonical(home, 'fha');
        final link = p.join(home, '.cursor', 'skills', 'fha');
        Directory(p.dirname(link)).createSync(recursive: true);
        Link(link).createSync(canonical);

        _applyAll(cleaner());

        expect(_exists(link), isFalse);
      });

      test('unlinks a canonical symlink without following it', () {
        _writeLock(lockPath, _lockWith({'linked': _entry('linked')}));
        final source = Directory(p.join(home, 'src', 'linked'))
          ..createSync(recursive: true);
        File(p.join(source.path, 'SKILL.md')).writeAsStringSync('src');
        final canonical = p.join(home, '.agents', 'skills', 'linked');
        Directory(p.dirname(canonical)).createSync(recursive: true);
        Link(canonical).createSync(source.path);

        final result = _applyAll(cleaner());

        expect(result.deletedCanonicals, [canonical]);
        expect(File(p.join(source.path, 'SKILL.md')).existsSync(), isTrue);
      });

      test('leaves a canonical file in place with a warning', () {
        _writeLock(lockPath, _lockWith({'file': _entry('file')}));
        final canonical = p.join(home, '.agents', 'skills', 'file');
        Directory(p.dirname(canonical)).createSync(recursive: true);
        File(canonical).writeAsStringSync('x');

        final result = _applyAll(cleaner());

        expect(File(canonical).existsSync(), isTrue);
        expect(result.warnings.single, contains('not a directory'));
      });

      test('honors CLAUDE_CONFIG_DIR', () {
        _writeLock(lockPath, _lockWith({'fha': _entry('fha')}));
        _canonical(home, 'fha');
        final link = _relativeLink(home, 'custom-claude/skills', 'fha');

        _applyAll(
            cleaner({'CLAUDE_CONFIG_DIR': p.join(home, 'custom-claude')}));

        expect(_exists(link), isFalse);
      });

      test('reads and rewrites the lock under XDG_STATE_HOME', () {
        final stateLock = p.join(home, 'state', 'skills', '.skill-lock.json');
        _writeLock(stateLock, _lockWith({'fha': _entry('fha')}));
        _canonical(home, 'fha');

        _applyAll(cleaner({'XDG_STATE_HOME': p.join(home, 'state')}));
        final lock = jsonDecode(File(stateLock).readAsStringSync()) as Map;

        expect((lock['skills'] as Map), isEmpty);
      });

      test('preserves other keys, their order and the no-newline format', () {
        _writeLock(
          lockPath,
          {
            'version': 3,
            'skills': {
              'third-party': _entry(
                'third-party',
                source: 'acme/skills',
                sourceUrl: 'https://github.com/acme/skills.git',
              ),
              'fha': _entry('fha'),
              'another': _entry(
                'another',
                source: 'acme/skills',
                sourceUrl: 'https://github.com/acme/skills.git',
              ),
            },
            'dismissed': {'findSkillsPrompt': true},
            'lastSelectedAgents': ['claude-code'],
          },
        );
        _canonical(home, 'fha');
        final expected = const JsonEncoder.withIndent('  ').convert({
          'version': 3,
          'skills': {
            'third-party': _entry(
              'third-party',
              source: 'acme/skills',
              sourceUrl: 'https://github.com/acme/skills.git',
            ),
            'another': _entry(
              'another',
              source: 'acme/skills',
              sourceUrl: 'https://github.com/acme/skills.git',
            ),
          },
          'dismissed': {'findSkillsPrompt': true},
          'lastSelectedAgents': ['claude-code'],
        });

        _applyAll(cleaner());

        expect(File(lockPath).readAsStringSync(), expected);
      });

      test('keeps the lock file when its skills map becomes empty', () {
        _writeLock(lockPath, _lockWith({'fha': _entry('fha')}));

        _applyAll(cleaner());

        expect(File(lockPath).existsSync(), isTrue);
      });

      test('touches nothing when the lock is malformed', () {
        Directory(p.dirname(lockPath)).createSync(recursive: true);
        File(lockPath).writeAsStringSync('{"version": 3, "skills": ');
        final canonical = _canonical(home, 'flutter-health-audit');
        final link =
            _relativeLink(home, '.claude/skills', 'flutter-health-audit');

        final result = _applyAll(cleaner());

        expect(_exists(canonical), isTrue);
        expect(_exists(link), isTrue);
        expect(File(lockPath).readAsStringSync(), '{"version": 3, "skills": ');
        expect(result.warnings.single, contains('Skipped'));
      });

      test('returns an empty result when the lock is missing', () {
        final result = _applyAll(cleaner());

        expect(result.removedSkills, isEmpty);
        expect(result.warnings, isEmpty);
      });

      test('does not rewrite a lock that has no Somnio entries', () {
        final lock = _lockWith({
          'vercel': _entry(
            'vercel',
            source: 'vercel-labs/agent-skills',
            sourceUrl: 'https://github.com/vercel-labs/agent-skills.git',
          ),
        });
        _writeLock(lockPath, lock);
        final modified = File(lockPath).lastModifiedSync();

        _applyAll(cleaner());

        expect(File(lockPath).lastModifiedSync(), modified);
      });

      test(
        'collects a warning and keeps the lock entry when a removal fails',
        () {
          _writeLock(
            lockPath,
            _lockWith({'locked': _entry('locked'), 'fha': _entry('fha')}),
          );
          _canonical(home, 'fha');
          final canonical = _canonical(home, 'locked');
          final link = _relativeLink(home, '.claude/skills', 'locked');
          final linkDir = p.dirname(link);
          // Read-only directories make both the unlink and the recursive
          // delete fail.
          Process.runSync('chmod', ['555', linkDir]);
          Process.runSync('chmod', ['555', canonical]);
          addTearDown(() {
            Process.runSync('chmod', ['755', linkDir]);
            Process.runSync('chmod', ['755', canonical]);
          });

          final result = _applyAll(cleaner());
          final lock = jsonDecode(File(lockPath).readAsStringSync()) as Map;

          expect(result.warnings, hasLength(2));
          expect(result.removedSkills, ['fha']);
          expect((lock['skills'] as Map).keys, ['locked']);
        },
        testOn: 'posix',
      );

      test(
        'warns when the lock cannot be rewritten',
        () {
          _writeLock(lockPath, _lockWith({'fha': _entry('fha')}));
          final lockDir = p.dirname(lockPath);
          Process.runSync('chmod', ['555', lockDir]);
          addTearDown(() => Process.runSync('chmod', ['755', lockDir]));

          final result = _applyAll(cleaner());

          expect(result.removedSkills, ['fha']);
          expect(result.warnings.single, contains('Could not update'));
        },
        testOn: 'posix',
      );
    });
  });

  group('SkillsShCleaner safety', () {
    Map<String, Object?> lockSkills() =>
        (jsonDecode(File(lockPath).readAsStringSync()) as Map)['skills']
            as Map<String, Object?>;

    group('folder collisions', () {
      late String canonical;

      setUp(() {
        _writeLock(
          lockPath,
          _lockWith({
            'My Skill': _entry(
              'My Skill',
              source: 'evil/thirdparty',
              sourceUrl: 'https://github.com/evil/thirdparty.git',
            ),
            'my-skill': _entry('my-skill'),
          }),
        );
        canonical = _canonical(home, 'my-skill');
      });

      test('skips a Somnio entry whose folder a third-party entry shares', () {
        final plan = cleaner().plan();

        expect(plan.isEmpty, isTrue);
        expect(plan.warnings.single, contains('non-Somnio skill "My Skill"'));
      });

      test('keeps the shared canonical copy and both lock entries', () {
        _applyAll(cleaner());

        expect(Directory(canonical).existsSync(), isTrue);
        expect(lockSkills().keys, ['My Skill', 'my-skill']);
      });
    });

    group('Somnio keys sharing a folder', () {
      setUp(() {
        _writeLock(
          lockPath,
          _lockWith({'Foo': _entry('Foo'), 'foo': _entry('foo')}),
        );
        _canonical(home, 'foo');
        _relativeLink(home, '.claude/skills', 'foo');
      });

      test('are planned as one item with an alias', () {
        final skill = cleaner().plan().skills.single;

        expect(skill.lockKeys, ['Foo', 'foo']);
      });

      test('are removed together without warnings', () {
        final result = _applyAll(cleaner());

        expect(result.warnings, isEmpty);
        expect(lockSkills(), isEmpty);
      });
    });

    group('canonical SKILL.md check', () {
      late String canonical;
      late String link;

      setUp(() {
        _writeLock(lockPath, _lockWith({'fha': _entry('fha')}));
        canonical = _canonical(home, 'fha');
        link = _relativeLink(home, '.claude/skills', 'fha');
      });

      for (final (label, content, reason) in [
        ('names another skill', '---\nname: other\n---\n', 'different skill'),
        ('has no frontmatter', '# fha', 'no frontmatter name'),
        ('has invalid YAML', '---\nname: [\n---\n', 'no frontmatter name'),
      ]) {
        test('skips the skill when SKILL.md $label', () {
          File(p.join(canonical, 'SKILL.md')).writeAsStringSync(content);

          final plan = cleaner().plan();

          expect(plan.isEmpty, isTrue);
          expect(plan.warnings.single, contains(reason));
        });
      }

      test('keeps the canonical copy, its links and its lock entry', () {
        File(p.join(canonical, 'SKILL.md'))
            .writeAsStringSync('---\nname: other\n---\n');

        _applyAll(cleaner());

        expect(Directory(canonical).existsSync(), isTrue);
        expect(_exists(link), isTrue);
        expect(lockSkills().keys, ['fha']);
      });

      test('accepts a canonical directory without SKILL.md', () {
        File(p.join(canonical, 'SKILL.md')).deleteSync();

        expect(cleaner().plan().skills.single.name, 'fha');
      });

      test(
        'skips the skill when SKILL.md cannot be read',
        () {
          final skillFile = p.join(canonical, 'SKILL.md');
          Process.runSync('chmod', ['000', skillFile]);
          addTearDown(() => Process.runSync('chmod', ['644', skillFile]));

          final plan = cleaner().plan();

          expect(plan.warnings.single, contains('could not be read'));
        },
        testOn: 'posix',
      );
    });

    group('symlinked directories', () {
      test('removes a link inside a symlinked agent dir', () {
        _writeLock(lockPath, _lockWith({'fha': _entry('fha')}));
        _canonical(home, 'fha');
        final realSkills =
            Directory(p.join(home, 'dotfiles', 'claude', 'skills'))
              ..createSync(recursive: true);
        Link(p.join(home, '.claude'))
            .createSync(p.join(home, 'dotfiles', 'claude'));
        // skills.sh computes the target from the real parent path.
        Link(p.join(realSkills.path, 'fha'))
            .createSync('../../../.agents/skills/fha');

        final result = _applyAll(cleaner());

        expect(
            result.unlinkedLinks, [p.join(home, '.claude', 'skills', 'fha')]);
        expect(_exists(p.join(realSkills.path, 'fha')), isFalse);
      });

      test('lists a link once when two agent dirs are the same directory', () {
        _writeLock(lockPath, _lockWith({'fha': _entry('fha')}));
        _canonical(home, 'fha');
        _relativeLink(home, '.cursor/skills', 'fha');
        Link(p.join(home, '.claude')).createSync(p.join(home, '.cursor'));

        final skill = cleaner().plan().skills.single;

        expect(skill.links, hasLength(1));
      });

      test('removes the canonical copy at the real path of ~/.agents/skills',
          () {
        _writeLock(lockPath, _lockWith({'fha': _entry('fha')}));
        final store = Directory(p.join(home, 'store', 'skills', 'fha'))
          ..createSync(recursive: true);
        File(p.join(store.path, 'SKILL.md'))
            .writeAsStringSync('---\nname: fha\n---\n');
        Link(p.join(home, '.agents', 'skills'))
            .createSync(p.join(home, 'store', 'skills'));
        final link = p.join(home, '.claude', 'skills', 'fha');
        Directory(p.dirname(link)).createSync(recursive: true);
        Link(link).createSync(store.path);

        final result = _applyAll(cleaner());

        expect(store.existsSync(), isFalse);
        expect(result.unlinkedLinks, [link]);
      });

      test('rewrites a symlinked lock at its target, keeping the symlink', () {
        final realLock = p.join(home, 'dotfiles', 'skill-lock.json');
        _writeLock(realLock, _lockWith({'fha': _entry('fha')}));
        Directory(p.dirname(lockPath)).createSync(recursive: true);
        Link(lockPath).createSync(realLock);

        _applyAll(cleaner());

        expect(FileSystemEntity.isLinkSync(lockPath), isTrue);
        expect(lockSkills(), isEmpty);
      });
    });

    group('empty agent skill folders', () {
      late String claudeSkills;
      late String piSkills;

      setUp(() {
        _writeLock(lockPath, _lockWith({'fha': _entry('fha')}));
        _canonical(home, 'fha');
        claudeSkills = p.dirname(_relativeLink(home, '.claude/skills', 'fha'));
        piSkills = p.dirname(_relativeLink(home, '.pi/agent/skills', 'fha'));
        // Claude also holds a skill of the user's own.
        Directory(p.join(claudeSkills, 'mine')).createSync();
      });

      test('are planned only when they hold nothing but planned links', () {
        expect(cleaner().plan().emptiedDirectories, [piSkills]);
      });

      test('are removed once their links are gone', () {
        final result = _applyAll(cleaner());

        expect(result.removedDirectories, [piSkills]);
        expect(Directory(piSkills).existsSync(), isFalse);
      });

      test('keep their parent directories', () {
        _applyAll(cleaner());

        expect(Directory(p.join(home, '.pi', 'agent')).existsSync(), isTrue);
      });

      test('are kept when they still hold other entries', () {
        _applyAll(cleaner());

        expect(Directory(claudeSkills).existsSync(), isTrue);
      });

      test('are kept when something appeared after planning', () {
        final plan = cleaner().plan();
        File(p.join(piSkills, 'new.md')).writeAsStringSync('x');

        final result = cleaner().apply(plan);

        expect(result.removedDirectories, isEmpty);
      });

      test(
        'warn when an emptied folder cannot be removed',
        () {
          final pi = p.join(home, '.pi', 'agent');
          final plan = cleaner().plan();
          // Unlinking needs a writable folder; removing the folder needs a
          // writable parent.
          Process.runSync('chmod', ['555', pi]);
          addTearDown(() => Process.runSync('chmod', ['755', pi]));

          final result = cleaner().apply(plan);

          expect(result.warnings.single, contains('Could not remove empty'));
        },
        testOn: 'posix',
      );
    });

    group('apply re-checks the confirmed plan', () {
      late String canonical;
      late String link;

      setUp(() {
        _writeLock(lockPath, _lockWith({'fha': _entry('fha')}));
        canonical = _canonical(home, 'fha');
        link = _relativeLink(home, '.claude/skills', 'fha');
      });

      test('leaves a link retargeted after planning', () {
        final plan = cleaner().plan();
        Link(link).updateSync(temp.path);

        final result = cleaner().apply(plan);

        expect(Link(link).targetSync(), temp.path);
        expect(result.warnings.single, contains('no longer links'));
        expect(lockSkills().keys, ['fha']);
      });

      test('treats a link removed after planning as done', () {
        final plan = cleaner().plan();
        Link(link).deleteSync();

        final result = cleaner().apply(plan);

        expect(result.removedSkills, ['fha']);
        expect(result.warnings, isEmpty);
      });

      test('skips a skill whose canonical copy changed kind', () {
        final plan = cleaner().plan();
        Directory(canonical).deleteSync(recursive: true);
        File(canonical).writeAsStringSync('x');

        final result = cleaner().apply(plan);

        expect(result.warnings.single, contains('changed after'));
        expect(_exists(link), isTrue);
      });

      test('removes nothing outside the plan', () {
        final plan = cleaner().plan();
        _writeLock(
          lockPath,
          _lockWith({'fha': _entry('fha'), 'new': _entry('new')}),
        );
        final newCanonical = _canonical(home, 'new');

        cleaner().apply(plan);

        expect(Directory(newCanonical).existsSync(), isTrue);
        expect(lockSkills().keys, ['new']);
      });

      test('touches nothing when the lock became unreadable', () {
        final plan = cleaner().plan();
        File(lockPath).writeAsStringSync('{');

        final result = cleaner().apply(plan);

        expect(Directory(canonical).existsSync(), isTrue);
        expect(result.warnings.single, contains('Nothing was changed'));
      });

      test('keeps the lock entry of a canonical that is not a directory', () {
        Directory(canonical).deleteSync(recursive: true);
        File(canonical).writeAsStringSync('x');

        _applyAll(cleaner());

        expect(lockSkills().keys, ['fha']);
      });
    });
  });

  group('SkillsShCleanupPlan', () {
    group('describe', () {
      test('reports when there is nothing to clean up', () {
        const plan = SkillsShCleanupPlan(lockPath: '/lock');

        expect(plan.describe().single, contains('No Somnio skills'));
      });

      test('summarizes skills, link counts and canonical copies', () {
        const plan = SkillsShCleanupPlan(
          lockPath: '/h/.agents/.skill-lock.json',
          skills: [
            SkillsShSkillPlan(
              name: 'fha',
              canonicalPath: '/h/.agents/skills/fha',
              canonicalKind: CanonicalKind.directory,
              links: ['/h/.claude/skills/fha', '/h/.pi/agent/skills/fha'],
            ),
            SkillsShSkillPlan(
              name: 'ship',
              canonicalPath: '/h/.agents/skills/ship',
              canonicalKind: CanonicalKind.missing,
              links: ['/h/.kiro/skills/ship'],
            ),
          ],
        );

        expect(plan.describe(), [
          'Somnio skills installed by skills.sh '
              '(global, /h/.agents/.skill-lock.json):',
          '2 skills, 3 agent links, 1 canonical copy to remove.',
          '  fha',
          '    canonical: /h/.agents/skills/fha (directory, will be deleted)',
          '    links:     2',
          '  ship',
          '    canonical: /h/.agents/skills/ship (already missing)',
          '    links:     1',
        ]);
      });

      test('lists every link path when verbose', () {
        const plan = SkillsShCleanupPlan(
          lockPath: '/lock',
          skills: [
            SkillsShSkillPlan(
              name: 'linked',
              canonicalPath: '/c/linked',
              canonicalKind: CanonicalKind.link,
              links: ['/a/linked'],
            ),
            SkillsShSkillPlan(
              name: 'file',
              canonicalPath: '/c/file',
              canonicalKind: CanonicalKind.other,
              links: [],
            ),
          ],
        );

        expect(plan.describe(verbose: true), [
          'Somnio skills installed by skills.sh (global, /lock):',
          '2 skills, 1 agent link, 1 canonical copy to remove.',
          '  linked',
          '    canonical: /c/linked (symlink, will be unlinked)',
          '    links:     1',
          '      /a/linked',
          '  file',
          '    canonical: /c/file (not a directory, left untouched)',
          '    links:     0',
        ]);
      });

      test('lists emptied folders, with paths when verbose', () {
        const plan = SkillsShCleanupPlan(
          lockPath: '/lock',
          skills: [
            SkillsShSkillPlan(
              name: 'a',
              canonicalPath: '/c/a',
              canonicalKind: CanonicalKind.directory,
              links: ['/x/a'],
            ),
          ],
          emptiedDirectories: ['/x', '/y'],
        );

        expect(plan.describe(verbose: true).sublist(6), [
          '2 empty agent skill folders will be removed.',
          '      /x',
          '      /y',
        ]);
      });

      test('uses singular wording for one emptied folder', () {
        const plan = SkillsShCleanupPlan(
          lockPath: '/lock',
          skills: [
            SkillsShSkillPlan(
              name: 'a',
              canonicalPath: '/c/a',
              canonicalKind: CanonicalKind.directory,
              links: ['/x/a'],
            ),
          ],
          emptiedDirectories: ['/x'],
        );

        expect(plan.describe().last,
            '1 empty agent skill folder will be removed.');
      });

      test('names the other lock entries that share a folder', () {
        const plan = SkillsShCleanupPlan(
          lockPath: '/lock',
          skills: [
            SkillsShSkillPlan(
              name: 'Foo',
              aliases: ['foo'],
              canonicalPath: '/c/foo',
              canonicalKind: CanonicalKind.directory,
              links: [],
            ),
          ],
        );

        expect(plan.describe()[2], '  Foo (also lock entries: foo)');
      });

      test('uses singular wording for a single skill', () {
        const plan = SkillsShCleanupPlan(
          lockPath: '/lock',
          skills: [
            SkillsShSkillPlan(
              name: 'a',
              canonicalPath: '/c/a',
              canonicalKind: CanonicalKind.directory,
              links: ['/x/a', '/y/a'],
            ),
            SkillsShSkillPlan(
              name: 'b',
              canonicalPath: '/c/b',
              canonicalKind: CanonicalKind.directory,
              links: [],
            ),
          ],
        );

        expect(
          plan.describe()[1],
          '2 skills, 2 agent links, 2 canonical copies to remove.',
        );
      });
    });
  });
}
