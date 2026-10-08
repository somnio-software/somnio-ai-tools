import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/installers/skill_manifest.dart';
import 'package:test/test.dart';

/// Creates [path] with [contents], including any missing parent directories.
void _writeFile(String path, [String contents = 'x']) {
  Directory(p.dirname(path)).createSync(recursive: true);
  File(path).writeAsStringSync(contents);
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('skill_manifest_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('load', () {
    test('returns an empty manifest when no manifest file exists', () {
      final manifest = SkillManifest.load(tmp.path);

      expect(manifest.isEmpty, isTrue);
      expect(manifest.entries, isEmpty);
    });

    test('returns an empty manifest instead of throwing on corrupt JSON', () {
      _writeFile(
        p.join(tmp.path, SkillManifest.fileName),
        '{not valid json at all',
      );

      final manifest = SkillManifest.load(tmp.path);

      expect(
        manifest.isEmpty,
        isTrue,
        reason: 'a corrupt manifest must degrade to empty, never throw and '
            'never wedge install/update/remove',
      );
    });

    test('returns an empty manifest for an unknown format version', () {
      _writeFile(
        p.join(tmp.path, SkillManifest.fileName),
        '{"version": 999, "skills": {"foo": {"kind": "audit", "paths": []}}}',
      );

      final manifest = SkillManifest.load(tmp.path);

      expect(
        manifest.isEmpty,
        isTrue,
        reason: 'an unrecognized version must never be misinterpreted as '
            'the current schema',
      );
    });
  });

  group('record + save + load', () {
    test('round-trips skill name, kind, and both ManifestRoot paths', () {
      final manifest = SkillManifest.load(tmp.path);

      manifest.record(
        skill: 'flutter-health-audit',
        kind: 'audit',
        paths: const [
          ManifestPath(ManifestRoot.install, 'flutter-health-audit'),
          ManifestPath(ManifestRoot.rules, 'flutter-health-audit/rules.md'),
        ],
      );
      manifest.save();

      final reloaded = SkillManifest.load(tmp.path);
      final entry = reloaded.entryFor('flutter-health-audit');

      expect(entry, isNotNull);
      expect(entry!.skill, 'flutter-health-audit');
      expect(entry.kind, 'audit');
      expect(
        entry.paths,
        containsAll(const [
          ManifestPath(ManifestRoot.install, 'flutter-health-audit'),
          ManifestPath(ManifestRoot.rules, 'flutter-health-audit/rules.md'),
        ]),
      );
    });

    test('recording a skill already present replaces its paths', () {
      final manifest = SkillManifest.load(tmp.path);

      manifest.record(
        skill: 'security-audit',
        kind: 'audit',
        paths: const [ManifestPath(ManifestRoot.install, 'old-path')],
      );
      manifest.record(
        skill: 'security-audit',
        kind: 'audit',
        paths: const [ManifestPath(ManifestRoot.install, 'new-path')],
      );
      manifest.save();

      final reloaded = SkillManifest.load(tmp.path);
      final entry = reloaded.entryFor('security-audit');

      expect(
        entry!.paths,
        equals(const [ManifestPath(ManifestRoot.install, 'new-path')]),
        reason: 're-recording must replace, not append duplicate paths',
      );
    });

    test('save() is deterministic regardless of recording order', () {
      final manifestA = SkillManifest.load(p.join(tmp.path, 'a'));
      manifestA.record(
        skill: 'aaa-skill',
        kind: 'audit',
        paths: const [ManifestPath(ManifestRoot.install, 'aaa')],
      );
      manifestA.record(
        skill: 'zzz-skill',
        kind: 'workflow',
        paths: const [ManifestPath(ManifestRoot.rules, 'zzz')],
      );
      manifestA.save();

      final manifestB = SkillManifest.load(p.join(tmp.path, 'b'));
      manifestB.record(
        skill: 'zzz-skill',
        kind: 'workflow',
        paths: const [ManifestPath(ManifestRoot.rules, 'zzz')],
      );
      manifestB.record(
        skill: 'aaa-skill',
        kind: 'audit',
        paths: const [ManifestPath(ManifestRoot.install, 'aaa')],
      );
      manifestB.save();

      final contentsA = File(p.join(tmp.path, 'a', SkillManifest.fileName))
          .readAsStringSync();
      final contentsB = File(p.join(tmp.path, 'b', SkillManifest.fileName))
          .readAsStringSync();

      expect(
        contentsA,
        contentsB,
        reason: 'insertion order must not affect the serialized bytes so '
            'reinstalling the same skills never produces a spurious diff',
      );
    });
  });

  group('removeEntry', () {
    test('drops only the named skill and returns its entry', () {
      final manifest = SkillManifest.load(tmp.path);
      manifest.record(
        skill: 'skill-a',
        kind: 'audit',
        paths: const [ManifestPath(ManifestRoot.install, 'a')],
      );
      manifest.record(
        skill: 'skill-b',
        kind: 'audit',
        paths: const [ManifestPath(ManifestRoot.install, 'b')],
      );

      final removed = manifest.removeEntry('skill-a');

      expect(removed, isNotNull);
      expect(removed!.skill, 'skill-a');
      expect(manifest.entryFor('skill-a'), isNull);
      expect(
        manifest.entryFor('skill-b'),
        isNotNull,
        reason: 'removing one skill must not touch the others',
      );
    });

    test('removing an absent skill returns null', () {
      final manifest = SkillManifest.load(tmp.path);

      expect(manifest.removeEntry('never-installed'), isNull);
    });
  });

  group('save', () {
    test('deletes the manifest file once the last entry is removed', () {
      final manifest = SkillManifest.load(tmp.path);
      manifest.record(
        skill: 'only-skill',
        kind: 'audit',
        paths: const [ManifestPath(ManifestRoot.install, 'only')],
      );
      manifest.save();
      final file = File(p.join(tmp.path, SkillManifest.fileName));
      expect(file.existsSync(), isTrue);

      manifest.removeEntry('only-skill');
      manifest.save();

      expect(
        file.existsSync(),
        isFalse,
        reason: 'an emptied manifest must leave no litter in the agent '
            'skill directory',
      );
    });
  });
}
