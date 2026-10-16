import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/content/skill_registry.dart';
import 'package:test/test.dart';

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

/// The audit bundles `somnio run` can execute, which all offer the upload.
final _auditBundles = SkillRegistry.skills.where(
  (b) =>
      b.id.endsWith('_health') ||
      b.id.endsWith('_plan') ||
      b.id.endsWith('_audit'),
);

void main() {
  final root = _repoRoot();
  final source = File(p.join(root, 'shared', 'references', 'drive-upload.md'));

  group('shared drive-upload reference', () {
    test('the source file exists', () {
      expect(source.existsSync(), isTrue);
    });

    test('covers every audit bundle', () {
      expect(_auditBundles, isNotEmpty);
    });

    for (final bundle in _auditBundles) {
      test('${bundle.name} ships an identical copy', () {
        final copy = File(
          p.join(root, 'skills', bundle.name, 'references', 'drive-upload.md'),
        );
        expect(
          copy.existsSync(),
          isTrue,
          reason: 'Copy shared/references/drive-upload.md to '
              'skills/${bundle.name}/references/drive-upload.md',
        );
        expect(
          copy.readAsStringSync(),
          source.readAsStringSync(),
          reason: 'skills/${bundle.name}/references/drive-upload.md drifted '
              'from shared/references/drive-upload.md; copy the source again',
        );
      });

      test('${bundle.name} SKILL.md points to the upload reference', () {
        final skill = File(p.join(root, 'skills', bundle.name, 'SKILL.md'))
            .readAsStringSync();
        expect(skill, contains('## Drive Upload (optional)'));
        expect(skill, contains('references/drive-upload.md'));
      });
    }
  });
}
