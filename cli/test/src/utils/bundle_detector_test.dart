import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:somnio/src/utils/bundle_detector.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  late Directory tmpDir;
  late MockLogger logger;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('somnio_bundle_detector_');
    logger = MockLogger();
  });

  tearDown(() => tmpDir.deleteSync(recursive: true));

  /// Creates a skill bundle directory under `skills/<name>/`.
  String _bundleDir(String name) {
    final dir = Directory(p.join(tmpDir.path, 'skills', name));
    dir.createSync(recursive: true);
    return dir.path;
  }

  void _writeFile(String path, String content) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  BundleDetector _detector() =>
      BundleDetector(repoRoot: tmpDir.path, logger: logger);

  group('detectBundles', () {
    test('returns [] when skills/ directory is absent', () async {
      final results = await _detector().detectBundles('flutter');
      expect(results, isEmpty);
    });

    test('matches <tech>-* directories and classifies them', () async {
      // health audit bundle (registrable)
      final ha = _bundleDir('flutter-health-audit');
      _writeFile(p.join(ha, 'SKILL.md'), '# Plan\nbody');
      _writeFile(p.join(ha, 'references', 'inventory.md'), '# Heading\ntext');

      // best practices bundle
      final bp = _bundleDir('flutter-best-practices');
      _writeFile(p.join(bp, 'SKILL.md'), '# Plan\nbody');
      _writeFile(p.join(bp, 'references', 'rules.md'), '# Rules\ntext');

      // unrelated tech, should not appear
      _bundleDir('react-health-audit');

      // matches prefix but classifies to null (no audit/practices keyword)
      _bundleDir('flutter-misc');

      final results = await _detector().detectBundles('flutter');

      expect(results, hasLength(2));
      // sorted alphabetically: best-practices before health-audit
      expect(results[0].subdirectory, 'flutter-best-practices');
      expect(results[0].bundleType, 'best_practices');
      expect(results[1].subdirectory, 'flutter-health-audit');
      expect(results[1].bundleType, 'health_audit');
    });

    test('skips subdirectories that do not classify', () async {
      _bundleDir('flutter-misc');
      final results = await _detector().detectBundles('flutter');
      expect(results, isEmpty);
    });
  });

  group('_detectBundle (via detectBundles)', () {
    test('registrable bundle: SKILL.md + valid references + template',
        () async {
      final base = _bundleDir('nestjs-health-audit');
      _writeFile(p.join(base, 'SKILL.md'), '# Plan\nbody');
      _writeFile(p.join(base, 'references', 'a.md'), '# A\ntext');
      _writeFile(p.join(base, 'references', 'b.md'), '# B\ntext');
      _writeFile(p.join(base, 'assets', 'report-template.md'), '# Template');

      final results = await _detector().detectBundles('nestjs');
      final r = results.single;

      expect(r.planFile, 'skills/nestjs-health-audit/SKILL.md');
      expect(r.rulesDirectory, 'skills/nestjs-health-audit/references');
      expect(r.ruleCount, 2);
      expect(r.validRuleCount, 2);
      expect(r.templatePath, 'skills/nestjs-health-audit/assets/report-template.md');
      expect(r.errors, isEmpty);
      expect(r.isRegistrable, isTrue);
    });

    test('missing SKILL.md adds an error and is not registrable', () async {
      final base = _bundleDir('react-health-audit');
      _writeFile(p.join(base, 'references', 'a.md'), '# A\ntext');

      final results = await _detector().detectBundles('react');
      final r = results.single;

      expect(r.planFile, isNull);
      expect(r.errors, contains('No SKILL.md file found in bundle directory'));
      expect(r.isRegistrable, isFalse);
    });

    test('missing references/ directory adds an error', () async {
      final base = _bundleDir('react-best-practices');
      _writeFile(p.join(base, 'SKILL.md'), '# Plan');

      final results = await _detector().detectBundles('react');
      final r = results.single;

      expect(r.errors, contains('references/ directory not found'));
      expect(r.ruleCount, 0);
      expect(r.isRegistrable, isFalse);
    });

    test('empty references/ adds "no reference files" error', () async {
      final base = _bundleDir('react-best-practices');
      _writeFile(p.join(base, 'SKILL.md'), '# Plan');
      Directory(p.join(base, 'references')).createSync(recursive: true);

      final results = await _detector().detectBundles('react');
      final r = results.single;

      expect(r.ruleCount, 0);
      expect(r.errors, contains('No reference files found in references/'));
    });

    test('partially invalid references add a validation error', () async {
      final base = _bundleDir('react-health-audit');
      _writeFile(p.join(base, 'SKILL.md'), '# Plan');
      _writeFile(p.join(base, 'references', 'good.md'), '# Good\ntext');
      _writeFile(p.join(base, 'references', 'bad.md'), 'no heading here');

      final results = await _detector().detectBundles('react');
      final r = results.single;

      expect(r.ruleCount, 2);
      expect(r.validRuleCount, 1);
      expect(
        r.errors,
        contains('1/2 reference files failed validation'),
      );
      // logger.detail called for the invalid file
      verify(() => logger.detail(any(that: contains('Invalid reference'))))
          .called(1);
    });
  });

  group('_isValidReference (via detection)', () {
    Future<BundleDetectionResult> detectWith(
      String fileName,
      String content,
    ) async {
      final base = _bundleDir('flutter-health-audit');
      _writeFile(p.join(base, 'SKILL.md'), '# Plan');
      _writeFile(p.join(base, 'references', fileName), content);
      final results = await _detector().detectBundles('flutter');
      return results.single;
    }

    test('md with heading is valid', () async {
      final r = await detectWith('a.md', '# Title\nbody');
      expect(r.validRuleCount, 1);
    });

    test('md without heading is invalid', () async {
      final r = await detectWith('a.md', 'plain text no heading');
      expect(r.validRuleCount, 0);
    });

    test('empty file is invalid', () async {
      final r = await detectWith('a.md', '   \n  ');
      expect(r.validRuleCount, 0);
    });

    test('valid yaml rule format is valid', () async {
      const yaml = '''
rules:
  - name: Rule
    description: A rule
    match: "**/*.dart"
    prompt: Do the thing
''';
      final r = await detectWith('rules.yaml', yaml);
      expect(r.validRuleCount, 1);
    });

    test('yaml that is not a map is invalid', () async {
      final r = await detectWith('rules.yaml', '- just\n- a\n- list');
      expect(r.validRuleCount, 0);
    });

    test('yaml without rules key is invalid', () async {
      final r = await detectWith('rules.yaml', 'other: value');
      expect(r.validRuleCount, 0);
    });

    test('yaml with empty rules list is invalid', () async {
      final r = await detectWith('rules.yaml', 'rules: []');
      expect(r.validRuleCount, 0);
    });

    test('yaml rule missing a required field is invalid', () async {
      const yaml = '''
rules:
  - name: Rule
    description: A rule
    match: "**/*.dart"
''';
      final r = await detectWith('rules.yaml', yaml);
      expect(r.validRuleCount, 0);
    });

    test('yaml with non-map rule entry is invalid', () async {
      const yaml = '''
rules:
  - just a string
''';
      final r = await detectWith('rules.yaml', yaml);
      expect(r.validRuleCount, 0);
    });

    test('malformed yaml is caught and invalid', () async {
      final r = await detectWith('rules.yaml', 'key: : : bad');
      expect(r.validRuleCount, 0);
    });

    test('non md/yaml files are ignored entirely', () async {
      final base = _bundleDir('flutter-health-audit');
      _writeFile(p.join(base, 'SKILL.md'), '# Plan');
      _writeFile(p.join(base, 'references', 'note.txt'), 'ignored');
      _writeFile(p.join(base, 'references', 'a.md'), '# A\ntext');
      final results = await _detector().detectBundles('flutter');
      final r = results.single;
      expect(r.ruleCount, 1);
    });
  });

  group('_findTemplate (via detection)', () {
    test('no assets dir → templatePath null', () async {
      final base = _bundleDir('flutter-health-audit');
      _writeFile(p.join(base, 'SKILL.md'), '# Plan');
      _writeFile(p.join(base, 'references', 'a.md'), '# A\ntext');
      final r = (await _detector().detectBundles('flutter')).single;
      expect(r.templatePath, isNull);
    });

    test('assets dir with no md → templatePath null', () async {
      final base = _bundleDir('flutter-health-audit');
      _writeFile(p.join(base, 'SKILL.md'), '# Plan');
      _writeFile(p.join(base, 'references', 'a.md'), '# A\ntext');
      _writeFile(p.join(base, 'assets', 'image.png'), 'binary');
      final r = (await _detector().detectBundles('flutter')).single;
      expect(r.templatePath, isNull);
    });
  });

  group('printReport', () {
    test('prints registrable bundle with template', () async {
      final base = _bundleDir('flutter-health-audit');
      _writeFile(p.join(base, 'SKILL.md'), '# Plan');
      _writeFile(p.join(base, 'references', 'a.md'), '# A\ntext');
      _writeFile(p.join(base, 'assets', 'report-template.md'), '# T');

      final results = await _detector().detectBundles('flutter');
      _detector().printReport(results);

      verify(() => logger.info(any(that: contains('Health Audit'))))
          .called(1);
      verify(() => logger.info(any(that: contains('Ready to register'))))
          .called(1);
    });

    test('prints cannot-register bundle with errors and no template',
        () async {
      final base = _bundleDir('flutter-best-practices');
      // No SKILL.md, no references → not registrable.
      Directory(base).createSync(recursive: true);

      final results = await _detector().detectBundles('flutter');
      _detector().printReport(results);

      verify(() => logger.info(any(that: contains('Best Practices'))))
          .called(1);
      verify(() => logger.info(any(that: contains('Cannot register'))))
          .called(1);
    });

    test('shows partial valid label when some references invalid', () async {
      final base = _bundleDir('flutter-health-audit');
      _writeFile(p.join(base, 'SKILL.md'), '# Plan');
      _writeFile(p.join(base, 'references', 'good.md'), '# Good\ntext');
      _writeFile(p.join(base, 'references', 'bad.md'), 'no heading');

      final results = await _detector().detectBundles('flutter');
      _detector().printReport(results);

      verify(() => logger.info(any(that: contains('1/2 valid')))).called(1);
    });
  });

  group('isRegistrable', () {
    test('true when planFile present and validRuleCount > 0', () {
      const r = BundleDetectionResult(
        bundleType: 'health_audit',
        subdirectory: 'flutter-health-audit',
        planFile: 'skills/flutter-health-audit/SKILL.md',
        validRuleCount: 1,
      );
      expect(r.isRegistrable, isTrue);
    });

    test('false when planFile missing', () {
      const r = BundleDetectionResult(
        bundleType: 'health_audit',
        subdirectory: 'x',
        validRuleCount: 2,
      );
      expect(r.isRegistrable, isFalse);
    });

    test('false when no valid rules', () {
      const r = BundleDetectionResult(
        bundleType: 'health_audit',
        subdirectory: 'x',
        planFile: 'skills/x/SKILL.md',
      );
      expect(r.isRegistrable, isFalse);
    });
  });
}
