import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:somnio/src/content/skill_bundle.dart';
import 'package:somnio/src/utils/registry_modifier.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  late Directory tmpDir;
  late MockLogger logger;
  late RegistryModifier modifier;

  /// Writes a fixture skill_registry.dart at the expected path under repoRoot.
  void _writeRegistry(String content) {
    final path = p.join(
      tmpDir.path,
      'cli',
      'lib',
      'src',
      'content',
      'skill_registry.dart',
    );
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  String _readRegistry() => File(
        p.join(
          tmpDir.path,
          'cli',
          'lib',
          'src',
          'content',
          'skill_registry.dart',
        ),
      ).readAsStringSync();

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('somnio_registry_mod_');
    logger = MockLogger();
    modifier = RegistryModifier(repoRoot: tmpDir.path, logger: logger);
  });

  tearDown(() => tmpDir.deleteSync(recursive: true));

  const fixtureRegistry = '''
class SkillRegistry {
  static const skills = <SkillBundle>[
    SkillBundle(
      id: 'flutter_health',
      name: 'flutter-health-audit',
      displayName: 'Flutter Project Health Audit',
      description: 'desc',
      planRelativePath: 'skills/flutter-health-audit/SKILL.md',
      rulesDirectory: 'skills/flutter-health-audit/references',
    ),
  ];
}
''';

  group('addBundles', () {
    test('inserts generated bundle code before the closing "];"', () async {
      _writeRegistry(fixtureRegistry);

      const bundle = SkillBundle(
        id: 'svelte_health',
        name: 'svelte-health-audit',
        displayName: 'Svelte Project Health Audit',
        description: 'A short description.',
        planRelativePath: 'skills/svelte-health-audit/SKILL.md',
        rulesDirectory: 'skills/svelte-health-audit/references',
      );

      await modifier.addBundles([bundle]);

      final out = _readRegistry();
      expect(out, contains("id: 'svelte_health'"));
      expect(out, contains("name: 'svelte-health-audit'"));
      // Inserted before closing bracket, original entry still present.
      expect(out, contains("id: 'flutter_health'"));
      final svelteIdx = out.indexOf("id: 'svelte_health'");
      final closingIdx = out.lastIndexOf('\n  ];');
      expect(svelteIdx, lessThan(closingIdx));
    });

    test('throws StateError when insertion point is missing', () async {
      _writeRegistry('const skills = <SkillBundle>[];');

      const bundle = SkillBundle(
        id: 'x',
        name: 'x-health-audit',
        displayName: 'X',
        description: 'd',
        planRelativePath: 'skills/x/SKILL.md',
        rulesDirectory: 'skills/x/references',
      );

      expect(
        () => modifier.addBundles([bundle]),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('hasConflicts', () {
    setUp(() => _writeRegistry(fixtureRegistry));

    test('returns true on id conflict', () {
      const bundle = SkillBundle(
        id: 'flutter_health',
        name: 'something-else',
        displayName: 'X',
        description: 'd',
        planRelativePath: 'skills/x/SKILL.md',
        rulesDirectory: 'skills/x/references',
      );
      expect(modifier.hasConflicts([bundle]), isTrue);
      verify(() => logger.err(any(that: contains('already exists')))).called(1);
    });

    test('returns true on name conflict', () {
      const bundle = SkillBundle(
        id: 'unique_id',
        name: 'flutter-health-audit',
        displayName: 'X',
        description: 'd',
        planRelativePath: 'skills/x/SKILL.md',
        rulesDirectory: 'skills/x/references',
      );
      expect(modifier.hasConflicts([bundle]), isTrue);
    });

    test('returns false when there is no conflict', () {
      const bundle = SkillBundle(
        id: 'brand_new',
        name: 'brand-new-audit',
        displayName: 'X',
        description: 'd',
        planRelativePath: 'skills/x/SKILL.md',
        rulesDirectory: 'skills/x/references',
      );
      expect(modifier.hasConflicts([bundle]), isFalse);
    });
  });

  group('_generateBundleCode (via addBundles)', () {
    test('emits aliases, workflowPath, templatePath and wrapped description',
        () async {
      _writeRegistry(fixtureRegistry);

      // Long description (> 58 chars) forces multi-line wrapping.
      const longDesc =
          'This is a deliberately long description that will need to be '
          'wrapped across multiple adjacent string literals for sure.';

      const bundle = SkillBundle(
        id: 'svelte_health',
        name: 'svelte-health-audit',
        aliases: ['sh', 'svelte-fh'],
        displayName: 'Svelte Project Health Audit',
        description: longDesc,
        planRelativePath: 'skills/svelte-health-audit/SKILL.md',
        rulesDirectory: 'skills/svelte-health-audit/references',
        workflowPath:
            'skills/svelte-health-audit/.agent/workflows/svelte_health.md',
        templatePath: 'skills/svelte-health-audit/assets/report-template.md',
      );

      await modifier.addBundles([bundle]);

      final out = _readRegistry();
      expect(out, contains("aliases: ['sh', 'svelte-fh'],"));
      expect(out, contains('workflowPath:'));
      expect(
        out,
        contains(
          "'skills/svelte-health-audit/.agent/workflows/svelte_health.md',",
        ),
      );
      expect(out, contains('templatePath:'));
      expect(
        out,
        contains("'skills/svelte-health-audit/assets/report-template.md',"),
      );
      // Multi-line description: bare "description:" header (no inline value).
      expect(out, contains('      description:\n'));
    });

    test('single-line description uses inline form', () async {
      _writeRegistry(fixtureRegistry);

      const bundle = SkillBundle(
        id: 'svelte_health',
        name: 'svelte-health-audit',
        displayName: 'Svelte Project Health Audit',
        description: 'Short desc.',
        planRelativePath: 'skills/svelte-health-audit/SKILL.md',
        rulesDirectory: 'skills/svelte-health-audit/references',
      );

      await modifier.addBundles([bundle]);

      final out = _readRegistry();
      expect(out, contains("description: 'Short desc.',"));
    });

    test('escapes single quotes in description', () async {
      _writeRegistry(fixtureRegistry);

      const bundle = SkillBundle(
        id: 'svelte_health',
        name: 'svelte-health-audit',
        displayName: 'Svelte Project Health Audit',
        description: "It's a test.",
        planRelativePath: 'skills/svelte-health-audit/SKILL.md',
        rulesDirectory: 'skills/svelte-health-audit/references',
      );

      await modifier.addBundles([bundle]);

      final out = _readRegistry();
      expect(out, contains(r"It\'s a test."));
    });

    test('omits workflowPath/templatePath/aliases when absent', () async {
      _writeRegistry(fixtureRegistry);

      const bundle = SkillBundle(
        id: 'svelte_health',
        name: 'svelte-health-audit',
        displayName: 'Svelte Project Health Audit',
        description: 'd',
        planRelativePath: 'skills/svelte-health-audit/SKILL.md',
        rulesDirectory: 'skills/svelte-health-audit/references',
      );

      await modifier.addBundles([bundle]);

      final out = _readRegistry();
      // The inserted block itself should not carry these keys.
      final insertedStart = out.indexOf("id: 'svelte_health'");
      final inserted = out.substring(insertedStart);
      expect(inserted, isNot(contains('aliases:')));
      expect(inserted, isNot(contains('workflowPath:')));
      expect(inserted, isNot(contains('templatePath:')));
    });
  });
}
