import 'package:somnio/src/agents/agent_registry.dart';
import 'package:somnio/src/agents/installed_skill_names.dart';
import 'package:somnio/src/content/skill_registry.dart';
import 'package:test/test.dart';

void main() {
  final claude = AgentRegistry.findById('claude')!; // skillDir
  final cursor = AgentRegistry.findById('cursor')!; // singleFile
  final gemini = AgentRegistry.findById('gemini')!; // markdown
  final antigravity = AgentRegistry.findById('antigravity')!; // workflow

  group('InstalledSkillNames.all', () {
    test('covers every registered skill and workflow skill', () {
      for (final bundle in SkillRegistry.skills) {
        expect(InstalledSkillNames.all, contains(bundle.name));
      }
      for (final skill in SkillRegistry.workflowSkills) {
        expect(InstalledSkillNames.all, contains(skill.name));
      }
    });

    test('includes the v1.x names', () {
      expect(InstalledSkillNames.all, containsAll(['somnio-fh', 'somnio-sa']));
    });
  });

  group('InstalledSkillNames.basenamesFor', () {
    test('skillDir uses the raw bundle name', () {
      expect(
        InstalledSkillNames.basenamesFor(claude),
        contains('flutter-health-audit'),
      );
    });

    test('singleFile appends .md to the bundle name', () {
      expect(
        InstalledSkillNames.basenamesFor(cursor),
        contains('flutter-health-audit.md'),
      );
    });

    test('markdown underscores the bundle name', () {
      expect(
        InstalledSkillNames.basenamesFor(gemini),
        contains('flutter_health_audit.md'),
      );
    });

    test('workflow is matched by prefix, not by name', () {
      expect(InstalledSkillNames.basenamesFor(antigravity), isEmpty);
    });
  });

  group('InstalledSkillNames.matches', () {
    test('matches the names the transformers really write', () {
      // These are unprefixed, so the old filePrefix check missed them.
      expect(InstalledSkillNames.matches(claude, 'flutter-health-audit'),
          isTrue);
      expect(InstalledSkillNames.matches(cursor, 'security-audit.md'), isTrue);
      expect(InstalledSkillNames.matches(gemini, 'flutter_health_audit.md'),
          isTrue);
      expect(InstalledSkillNames.matches(antigravity, 'somnio_flutter_ha.md'),
          isTrue);
    });

    test('matches skills added to the registry after the v1.x rename', () {
      expect(InstalledSkillNames.matches(claude, 'python-health-audit'),
          isTrue);
      expect(InstalledSkillNames.matches(gemini, 'python_best_practices.md'),
          isTrue);
    });

    test('still matches legacy prefixed installs', () {
      expect(InstalledSkillNames.matches(claude, 'somnio-fh'), isTrue);
      expect(InstalledSkillNames.matches(gemini, 'somnio_fh.md'), isTrue);
    });

    test('does not match unrelated user content', () {
      expect(InstalledSkillNames.matches(claude, 'my-own-skill'), isFalse);
      expect(InstalledSkillNames.matches(gemini, 'notes.md'), isFalse);
      expect(InstalledSkillNames.matches(cursor, 'flutter-health-audit'),
          isFalse);
    });
  });
}
