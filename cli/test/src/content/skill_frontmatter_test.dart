import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/content/content_loader.dart';
import 'package:somnio/src/content/skill_registry.dart';
import 'package:test/test.dart';

/// Limits from the Agent Skills specification
/// (https://agentskills.io/specification). Codex rejects a skill over them, as
/// do claude.ai uploads and the Skills API; Claude Code only truncates its
/// skill listing at 1,536 characters.
const _maxNameLength = 64;
const _maxDescriptionLength = 1024;
const _maxCompatibilityLength = 500;

final _namePattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

/// Walks up from the test's working directory until it finds the repo root
/// (the directory that contains the top-level `skills/` folder).
String _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (Directory(p.join(dir.path, 'skills')).existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate repo root from ${Directory.current}');
    }
    dir = parent;
  }
}

/// Returns every Agent Skills spec violation in [frontmatter], the parsed
/// frontmatter of the skill that lives in the directory [dirName].
List<String> _violations(Map<String, String> frontmatter, String dirName) {
  final name = frontmatter['name'] ?? '';
  final description = frontmatter['description'] ?? '';
  final compatibility = frontmatter['compatibility'];
  return [
    if (name.isEmpty)
      'name is missing'
    else ...[
      if (name.length > _maxNameLength)
        'name is ${name.length} chars (max $_maxNameLength)',
      if (!_namePattern.hasMatch(name))
        'name "$name" must be lowercase letters, digits and single hyphens, '
            'not starting or ending with a hyphen',
      if (name != dirName)
        'name "$name" must match its directory name "$dirName"',
    ],
    if (description.isEmpty)
      'description is missing or empty'
    else if (description.length > _maxDescriptionLength)
      'description is ${description.length} chars '
          '(max $_maxDescriptionLength)',
    if (compatibility != null &&
        (compatibility.isEmpty ||
            compatibility.length > _maxCompatibilityLength))
      'compatibility is ${compatibility.length} chars '
          '(must be 1-$_maxCompatibilityLength)',
  ];
}

void main() {
  final root = _repoRoot();
  final loader = ContentLoader(root);
  final skillDirs = Directory(p.join(root, 'skills'))
      .listSync()
      .whereType<Directory>()
      .where((d) => File(p.join(d.path, 'SKILL.md')).existsSync())
      .map((d) => p.basename(d.path))
      .toList()
    ..sort();

  group('shipped skills frontmatter (Agent Skills spec)', () {
    test('discovers the shipped skills', () {
      expect(skillDirs, isNotEmpty);
    });

    for (final dirName in skillDirs) {
      test('$dirName/SKILL.md frontmatter is valid', () {
        final frontmatter = loader.loadPlanFrontmatter(
          p.join('skills', dirName, 'SKILL.md'),
        );

        expect(
          frontmatter,
          isNotEmpty,
          reason: '$dirName: frontmatter is missing or cannot be parsed',
        );
        expect(_violations(frontmatter, dirName), isEmpty, reason: dirName);
      });
    }

    test('every registered skill is in a scanned directory named after it', () {
      final registered = [
        ...SkillRegistry.skills.map((s) => (s.name, s.planRelativePath)),
        ...SkillRegistry.workflowSkills
            .map((s) => (s.name, s.planRelativePath)),
      ];
      for (final (name, path) in registered) {
        final dirName = p.basename(p.dirname(path));
        expect(skillDirs, contains(dirName), reason: '$path is not scanned');
        expect(name, dirName, reason: 'registry name differs from $path');
      }
    });
  });

  group('_violations', () {
    test('accepts a description of exactly the maximum length', () {
      final frontmatter = {
        'name': 'my-skill',
        'description': 'a' * _maxDescriptionLength,
      };
      expect(_violations(frontmatter, 'my-skill'), isEmpty);
    });

    test('rejects a description over the maximum length', () {
      final frontmatter = {
        'name': 'my-skill',
        'description': 'a' * (_maxDescriptionLength + 1),
      };
      expect(_violations(frontmatter, 'my-skill'), [
        contains('description is 1025 chars'),
      ]);
    });

    test('rejects a missing description and a missing name', () {
      expect(_violations(const {}, 'my-skill'), [
        'name is missing',
        'description is missing or empty',
      ]);
    });

    for (final name in ['My-Skill', '-skill', 'skill-', 'my--skill', 'a_b']) {
      test('rejects the malformed name "$name"', () {
        expect(_violations({'name': name, 'description': 'ok'}, name), [
          contains('lowercase letters'),
        ]);
      });
    }

    test('accepts a name of exactly the maximum length', () {
      final name = 'a' * _maxNameLength;
      expect(_violations({'name': name, 'description': 'ok'}, name), isEmpty);
    });

    test('rejects a name over the maximum length', () {
      final name = 'a' * (_maxNameLength + 1);
      expect(_violations({'name': name, 'description': 'ok'}, name), [
        contains('name is 65 chars'),
      ]);
    });

    test('rejects a name that differs from its directory', () {
      expect(_violations({'name': 'one', 'description': 'ok'}, 'two'), [
        contains('must match its directory name'),
      ]);
    });

    test('accepts a compatibility of exactly the maximum length', () {
      final frontmatter = {
        'name': 'my-skill',
        'description': 'ok',
        'compatibility': 'a' * _maxCompatibilityLength,
      };
      expect(_violations(frontmatter, 'my-skill'), isEmpty);
    });

    test('rejects an empty compatibility', () {
      final frontmatter = {
        'name': 'my-skill',
        'description': 'ok',
        'compatibility': '',
      };
      expect(_violations(frontmatter, 'my-skill'), [
        contains('compatibility is 0 chars'),
      ]);
    });

    test('rejects a compatibility over the maximum length', () {
      final frontmatter = {
        'name': 'my-skill',
        'description': 'ok',
        'compatibility': 'a' * (_maxCompatibilityLength + 1),
      };
      expect(_violations(frontmatter, 'my-skill'), [
        contains('compatibility is 501 chars'),
      ]);
    });
  });
}
