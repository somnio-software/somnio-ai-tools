import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:somnio/src/utils/scaffold_generator.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

/// The canonical scoring legend every best-practices template carries,
/// byte-identical (en dash U+2013, middle dot U+00B7).
const _scoringLegend =
    '> **Scoring:** Strong (85\u2013100) \u00b7 Fair (70\u201384) \u00b7 Weak (0\u201369)';

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
      expect(
        report,
        contains(
          '> **Test Coverage:** [X]% (lines) — full breakdown in the '
          'Testing section.',
        ),
      );
      expect(report, contains('**Code Coverage:**'));
      expect(report, contains('### Harness Coverage'));
      expect(report, contains('## Appendix: Scoring Methodology'));
      expect(report, isNot(contains('Quality Index')));
      expect(report, isNot(contains('| Security |')));

      // Exactly 15 numbered `## N.` section headings, numbered 1..15.
      final numberedHeadings = RegExp(r'^## (\d+)\. ', multiLine: true)
          .allMatches(report)
          .map((m) => int.parse(m.group(1)!))
          .toList();
      expect(numberedHeadings, hasLength(15));
      expect(numberedHeadings, List.generate(15, (i) => i + 1));
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

      // A freshly scaffolded best-practices template must already satisfy the
      // shared skeleton in docs/best-practices-template-canonical.md. The
      // drift test guards the six known skills by name, so it would never see
      // a seventh, scaffolded one — these assertions are what stop the
      // scaffolder from birthing a divergent skill.
      expect(report, contains('## 1. Executive Summary'));
      expect(report, contains('## 2. Score Breakdown'));
      expect(report, contains('| Section | Score | Label |'));
      expect(report, contains('**Weighted Overall**'));
      expect(report, contains('## 6. Prioritized Recommendations'));
      expect(report, contains('## 7. Evidence Index'));
      expect(report, contains('## Appendix: Scoring Methodology'));
      expect(report, contains('## Report Metadata'));
      expect(report, contains('| Skill | svelte-best-practices |'));
      expect(
        report,
        contains(_scoringLegend),
        reason: 'scaffolded template must carry the canonical scoring legend '
            '(en dash U+2013, middle dot U+00B7)',
      );

      // The retired heading forms and the old /10 scale must not come back.
      expect(report, isNot(contains('## Section ')));
      expect(report, isNot(contains('Prioritized Action Plan')));
      expect(
        report,
        isNot(contains(RegExp(r'/10(?!\d)'))),
        reason: 'scaffolded template must score on /100, never the old /10 scale',
      );

      // The placeholder appendix weights must themselves sum to 100, so a new
      // skill starts valid instead of starting broken.
      final weights = RegExp(r'^\| (?!\*\*Total)[^|]+ \| (\d+)% \|', multiLine: true)
          .allMatches(report)
          .map((m) => int.parse(m.group(1)!))
          .toList();
      expect(weights, isNotEmpty, reason: 'no appendix weight rows parsed');
      expect(
        weights.fold<int>(0, (a, b) => a + b),
        100,
        reason: 'scaffolded appendix weights must sum to 100, found $weights',
      );
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
