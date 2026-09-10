import 'package:somnio/src/utils/report_naming.dart';
import 'package:test/test.dart';

void main() {
  group('projectSlug', () {
    test('lowercases', () {
      expect(projectSlug('HoopisBackend'), 'hoopisbackend');
    });

    test('turns underscores into hyphens', () {
      expect(projectSlug('Hoopis_Backend'), 'hoopis-backend');
    });

    test('turns spaces into hyphens', () {
      expect(projectSlug('Example Project'), 'example-project');
    });

    test('turns dots and slashes into hyphens', () {
      expect(projectSlug('hoopis.backend'), 'hoopis-backend');
      expect(projectSlug('hoopis/backend'), 'hoopis-backend');
    });

    test('drops a scope marker from an npm package name', () {
      expect(projectSlug('@hoopis/backend'), 'hoopis-backend');
    });

    test('drops characters outside [a-z0-9-]', () {
      expect(projectSlug('hoopis (backend)!'), 'hoopis-backend');
      expect(projectSlug('café'), 'caf');
    });

    test('keeps digits', () {
      expect(projectSlug('hoopis-backend-2'), 'hoopis-backend-2');
    });

    test('collapses runs of separators into a single hyphen', () {
      expect(projectSlug('hoopis___backend'), 'hoopis-backend');
      expect(projectSlug('hoopis   backend'), 'hoopis-backend');
      expect(projectSlug('hoopis - backend'), 'hoopis-backend');
    });

    test('trims leading and trailing hyphens', () {
      expect(projectSlug('_hoopis-backend_'), 'hoopis-backend');
      expect(projectSlug('--hoopis--'), 'hoopis');
    });

    test('falls back when the input slugifies to nothing', () {
      expect(projectSlug(''), kFallbackProjectSlug);
      expect(projectSlug('---'), kFallbackProjectSlug);
      expect(projectSlug('!!!'), kFallbackProjectSlug);
      expect(projectSlug('   '), kFallbackProjectSlug);
    });

    test('is idempotent on an already-valid slug', () {
      expect(projectSlug('hoopis-backend'), 'hoopis-backend');
      expect(
        projectSlug(projectSlug('Hoopis_Backend')),
        projectSlug('Hoopis_Backend'),
      );
    });
  });

  group('isoDate', () {
    test('formats as YYYY-MM-DD', () {
      expect(isoDate(DateTime(2026, 9, 14)), '2026-09-14');
    });

    test('zero-pads month and day', () {
      expect(isoDate(DateTime(2026, 1, 2)), '2026-01-02');
    });

    test('ignores the time component', () {
      expect(isoDate(DateTime(2026, 9, 14, 23, 59, 59)), '2026-09-14');
    });
  });

  group('reportFileName', () {
    final date = DateTime(2026, 9, 14);

    test('builds the canonical name', () {
      expect(
        reportFileName(
          date: date,
          project: 'hoopis-backend',
          reportType: 'security-audit',
        ),
        '2026-09-14-hoopis-backend-security-audit.md',
      );
    });

    test('slugifies the project segment', () {
      expect(
        reportFileName(
          date: date,
          project: 'Hoopis_Backend',
          reportType: 'nestjs-health-audit',
        ),
        '2026-09-14-hoopis-backend-nestjs-health-audit.md',
      );
    });

    test('supports a json sidecar via extension', () {
      expect(
        reportFileName(
          date: date,
          project: 'hoopis-backend',
          reportType: 'harness-audit',
          extension: 'json',
        ),
        '2026-09-14-hoopis-backend-harness-audit.json',
      );
    });

    test('keeps the report type verbatim', () {
      // The report type comes from SkillBundle.name, which is already
      // kebab-case; it must not be re-slugified or truncated.
      for (final type in const [
        'flutter-best-practices',
        'angularjs-health-audit',
        'iso27001-audit',
        'dora-metrics',
      ]) {
        expect(
          reportFileName(date: date, project: 'p', reportType: type),
          '2026-09-14-p-$type.md',
        );
      }
    });

    test('is a single path segment', () {
      final name = reportFileName(
        date: date,
        project: 'a/b c_d',
        reportType: 'security-audit',
      );
      expect(name, isNot(contains('/')));
      expect(name, '2026-09-14-a-b-c-d-security-audit.md');
    });
  });
}
