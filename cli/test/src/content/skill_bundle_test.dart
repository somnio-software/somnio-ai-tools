import 'package:somnio/src/content/skill_bundle.dart';
import 'package:test/test.dart';

void main() {
  SkillBundle build({
    required String id,
    String displayName = 'Flutter Project Health Audit',
    String planRelativePath = 'skills/flutter-health-audit/SKILL.md',
  }) {
    return SkillBundle(
      id: id,
      name: 'flutter-health-audit',
      displayName: displayName,
      description: 'desc',
      planRelativePath: planRelativePath,
      rulesDirectory: 'skills/flutter-health-audit/references',
    );
  }

  group('techPrefix', () {
    test('strips _health suffix', () {
      expect(build(id: 'flutter_health').techPrefix, 'flutter');
    });

    test('strips _plan suffix', () {
      expect(build(id: 'nestjs_plan').techPrefix, 'nestjs');
    });

    test('strips _audit suffix', () {
      expect(build(id: 'security_audit').techPrefix, 'security');
    });

    test('leaves id without a known suffix unchanged', () {
      expect(build(id: 'react').techPrefix, 'react');
    });
  });

  group('techDisplayName', () {
    test('returns the first word of displayName', () {
      expect(
        build(id: 'flutter_health', displayName: 'Flutter Project Health Audit')
            .techDisplayName,
        'Flutter',
      );
    });
  });

  group('planSubDir', () {
    test('returns the second path segment', () {
      expect(
        build(
          id: 'flutter_health',
          planRelativePath: 'skills/flutter-health-audit/SKILL.md',
        ).planSubDir,
        'flutter-health-audit',
      );
    });

    test('falls back to id when path has fewer than 2 segments', () {
      expect(
        build(id: 'fallback-id', planRelativePath: 'SKILL.md').planSubDir,
        'fallback-id',
      );
    });
  });
}
