import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/installers/legacy_clockify_guard.dart';
import 'package:somnio/src/installers/skill_manifest.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late String root;
  late String home;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('clockify_guard_');
    root = p.join(tmp.path, 'install');
    home = p.join(tmp.path, 'home');
    Directory(root).createSync();
    Directory(home).createSync();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  void check() => LegacyClockifyGuard.check(
        installRoot: root,
        rulesRoot: p.join(tmp.path, 'rules'),
        home: home,
      );

  for (final name in [
    'clockify-tracker',
    'clockify-tracker.md',
    'clockify_tracker.md',
    'global_workflows/somnio_clockify_tracker.md',
  ]) {
    test('blocks and preserves legacy layout $name', () {
      final old = File(p.join(root, name));
      old.parent.createSync(recursive: true);
      old.writeAsStringSync('custom');
      expect(check, throwsStateError);
      expect(old.readAsStringSync(), 'custom');
    });
  }

  test('blocks a symlink without following or changing its target', () {
    final external = File(p.join(tmp.path, 'external'))
      ..writeAsStringSync('private');
    Link(p.join(root, 'clockify-tracker')).createSync(external.path);
    expect(check, throwsStateError);
    expect(external.readAsStringSync(), 'private');
  });

  test('allows an absent recorded legacy path', () {
    File(p.join(root, '.somnio-skills.json')).writeAsStringSync(jsonEncode({
      'version': 1,
      'skills': {
        'clockify-tracker': {
          'kind': 'workflow',
          'paths': [
            {'root': 'install', 'path': 'retired-location'}
          ]
        }
      }
    }));
    expect(check, returnsNormally);
  });

  test('blocks a present manifest-owned legacy path', () {
    File(p.join(root, 'retired-location')).writeAsStringSync('custom');
    File(p.join(root, '.somnio-skills.json')).writeAsStringSync(jsonEncode({
      'version': 1,
      'skills': {
        'clockify-tracker': {
          'kind': 'workflow',
          'paths': [
            {'root': 'install', 'path': 'retired-location'}
          ]
        }
      }
    }));
    expect(check, throwsStateError);
    expect(File(p.join(root, 'retired-location')).readAsStringSync(), 'custom');
  });

  test('blocks a differently cased retired path', () {
    final old = File(p.join(root, 'Clockify-Tracker.md'))
      ..writeAsStringSync('custom');
    expect(check, throwsStateError);
    expect(old.readAsStringSync(), 'custom');
  });

  test('rejects malformed unrelated manifest entries', () {
    File(p.join(root, '.somnio-skills.json')).writeAsStringSync(jsonEncode({
      'version': 1,
      'skills': {
        'other': {'kind': 'workflow', 'paths': 'invalid'}
      }
    }));
    expect(check, throwsStateError);
  });

  test('fails closed on an invalid manifest', () {
    File(p.join(root, '.somnio-skills.json')).writeAsStringSync('{invalid');
    expect(check, throwsStateError);
  });

  test('rejects a symlinked manifest without reading its target', () {
    final external = File(p.join(tmp.path, 'foreign.json'))
      ..writeAsStringSync('{}');
    Link(p.join(root, '.somnio-skills.json')).createSync(external.path);
    expect(check, throwsStateError);
    expect(external.readAsStringSync(), '{}');
  });

  test('rejects an unsafe path in a legacy manifest', () {
    File(p.join(root, '.somnio-skills.json')).writeAsStringSync(jsonEncode({
      'version': 1,
      'skills': {
        'clockify-tracker': {
          'kind': 'workflow',
          'paths': [
            {'root': 'install', 'path': '../outside'}
          ]
        }
      }
    }));
    expect(check, throwsStateError);
  });

  test('blocks a symlinked ancestor without following it', () {
    final outside = Directory(p.join(tmp.path, 'outside'))..createSync();
    Link(p.join(root, 'global_workflows')).createSync(outside.path);
    expect(check, throwsStateError);
    expect(outside.listSync(), isEmpty);
  });

  test('accepts an install root linked to a dotfiles directory', () {
    final alias = p.join(tmp.path, 'linked-install');
    Link(alias).createSync(root);
    expect(
      () => LegacyClockifyGuard.check(
        installRoot: alias,
        rulesRoot: p.join(tmp.path, 'rules'),
        home: home,
      ),
      returnsNormally,
    );
  });

  test('rejects a root linked to a protected configuration', () {
    final protected = Directory(p.join(tmp.path, 'protected'))..createSync();
    final alias = p.join(tmp.path, 'linked-protected');
    Link(alias).createSync(protected.path);
    final manifest = File(p.join(protected.path, '.somnio-skills.json'))
      ..writeAsStringSync('preserve');
    expect(
      () => LegacyClockifyGuard.verifyManifests(
        installRoot: alias,
        rulesRoot: p.join(tmp.path, 'rules'),
        protectedRoots: [protected.path],
      ),
      throwsStateError,
    );
    expect(manifest.readAsStringSync(), 'preserve');
  });

  test('blocks the shared legacy skills.sh copy', () {
    Directory(p.join(home, '.agents', 'skills', 'clockify-tracker'))
        .createSync(recursive: true);
    expect(check, throwsStateError);
  });

  test('checks the command directory when the project is home', () {
    final dir = LegacyClockifyGuard.projectCommandDir('claude', home, home);
    final legacy = File(p.join(dir!, 'clockify-tracker.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync('custom');
    expect(() => LegacyClockifyGuard.checkCommand(dir), throwsStateError);
    expect(legacy.readAsStringSync(), 'custom');
  });

  test('does not inspect commands in a protected config home', () {
    final protected = p.join(home, '.claude');
    expect(
      LegacyClockifyGuard.projectCommandDir('claude', home, home,
          protectedRoots: [protected]),
      isNull,
    );
  });

  test('preserves a flat skill with unexpected recorded paths', () {
    final entry = ManifestEntry(
      skill: 'clockify',
      kind: 'workflow',
      paths: [const ManifestPath(ManifestRoot.install, 'other.md')],
    );
    expect(
      () => LegacyClockifyGuard.currentFileIsIdentical(
          root, 'clockify.md', 'expected', entry),
      throwsStateError,
    );
  });

  test('preserves a symlink in a flat workflow path', () {
    final outside = Directory(p.join(tmp.path, 'outside'))..createSync();
    Link(p.join(root, 'global_workflows')).createSync(outside.path);
    expect(
      () => LegacyClockifyGuard.currentFileIsIdentical(
          root, 'global_workflows/somnio_clockify.md', 'expected', null),
      throwsStateError,
    );
    expect(outside.listSync(), isEmpty);
  });

  test('preserves an existing differently cased flat skill', () {
    final file = File(p.join(root, 'Clockify.md'))..writeAsStringSync('custom');
    expect(
      () => LegacyClockifyGuard.currentFileIsIdentical(
          root, 'clockify.md', 'expected', null),
      throwsStateError,
    );
    expect(file.readAsStringSync(), 'custom');
  });
}
