import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:somnio/src/utils/scaffold_generator.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  late Directory tmpDir;
  late MockLogger logger;
  late ScaffoldGenerator generator;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('somnio_scaffold_');
    logger = MockLogger();
    generator = ScaffoldGenerator(repoRoot: tmpDir.path, logger: logger);
  });

  tearDown(() => tmpDir.deleteSync(recursive: true));

  String _read(String relPath) =>
      File(p.join(tmpDir.path, relPath)).readAsStringSync();

  bool _exists(String relPath) =>
      File(p.join(tmpDir.path, relPath)).existsSync();

  group('generateHealthAudit', () {
    test('creates directories and template files', () async {
      await generator.generateHealthAudit(
        tech: 'svelte',
        displayName: 'Svelte Project Health Audit',
      );

      const base = 'skills/svelte-health-audit';
      expect(
        Directory(p.join(tmpDir.path, base, 'references')).existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(tmpDir.path, base, 'assets')).existsSync(),
        isTrue,
      );

      final plan = _read('$base/SKILL.md');
      expect(plan, contains('name: svelte-health-audit'));
      expect(plan, contains('Svelte Project Health Audit'));
      // titleCase applied
      expect(plan, contains('Svelte Project Health Auditor'));

      final ref = _read('$base/references/svelte_repository_inventory.md');
      expect(ref, contains('Svelte Repository Inventory'));

      final report = _read('$base/assets/report-template.md');
      expect(report, contains('Svelte Project Health Audit Report'));
      expect(report, contains('At-a-Glance Scorecard'));
    });
  });

  group('generateBestPractices', () {
    test('creates directories and template files', () async {
      await generator.generateBestPractices(
        tech: 'svelte',
        displayName: 'Svelte Best Practices Check',
      );

      const base = 'skills/svelte-best-practices';
      expect(
        Directory(p.join(tmpDir.path, base, 'references')).existsSync(),
        isTrue,
      );

      final plan = _read('$base/SKILL.md');
      expect(plan, contains('name: svelte-best-practices'));
      expect(plan, contains('Svelte Code Quality Auditor'));

      final report = _read('$base/assets/report-template.md');
      expect(report, contains('Svelte Best Practices Check Report'));
      expect(report, contains('Violations by Category'));
    });
  });

  group('generateReadme', () {
    test('creates README.md when not present', () async {
      await generator.generateReadme('svelte');

      expect(_exists('skills/README.md'), isTrue);
      final readme = _read('skills/README.md');
      expect(readme, contains('Svelte Project Analysis'));
      expect(readme, contains('/svelte-health-audit'));
    });

    test('does not overwrite an existing README.md', () async {
      final readmePath = p.join(tmpDir.path, 'skills', 'README.md');
      File(readmePath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('ORIGINAL CONTENT');

      await generator.generateReadme('svelte');

      expect(_read('skills/README.md'), 'ORIGINAL CONTENT');
    });
  });

  group('_createDir (via generate)', () {
    test('does not re-create an already existing directory', () async {
      // Pre-create references dir so _createDir hits the "exists" branch.
      Directory(
        p.join(tmpDir.path, 'skills', 'svelte-health-audit', 'references'),
      ).createSync(recursive: true);

      await generator.generateHealthAudit(
        tech: 'svelte',
        displayName: 'Svelte Project Health Audit',
      );

      // Still generates the files fine.
      expect(_exists('skills/svelte-health-audit/SKILL.md'), isTrue);
    });
  });

  group('_writeFile (via generate)', () {
    test('creates missing parent directories for files', () async {
      // README has no pre-existing parent skills/ dir → exercises parent
      // creation branch.
      expect(Directory(p.join(tmpDir.path, 'skills')).existsSync(), isFalse);

      await generator.generateReadme('svelte');

      expect(_exists('skills/README.md'), isTrue);
    });
  });
}
