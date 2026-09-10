import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/content/content_loader.dart';
import 'package:somnio/src/content/skill_registry.dart';
import 'package:somnio/src/runner/plan_parser.dart';
import 'package:somnio/src/runner/rule_names.dart';
import 'package:somnio/src/utils/report_naming.dart';
import 'package:test/test.dart';

/// `run_command.dart` carries `// coverage:ignore-file`, so the dispatch
/// logic that used to inline these comparisons has been extracted into
/// `rule_names.dart` — a pure, testable helper. These tests cover the exact
/// bugs that a hyphen/underscore mismatch previously caused:
///
/// - Bug A: the report-generator dispatch never fired because the check
///   compared against `_report_generator` while the parser produces the
///   hyphenated `report-generator`.
/// - Bug B: pre-flight artifacts (written as `${techPrefix}_tool_installer`)
///   were never found because the lookup used the bare, hyphenated rule
///   name (`tool-installer`) instead of the mapped artifact key.
void main() {
  group('report-generator dispatch', () {
    test('"report-generator" matches kReportGeneratorRuleName', () {
      const ruleName = 'report-generator';
      expect(ruleName == kReportGeneratorRuleName, isTrue);
    });

    test('legacy "_report_generator" style name does NOT match', () {
      const ruleName = 'flutter_report_generator';
      expect(ruleName == kReportGeneratorRuleName, isFalse);
      expect(ruleName.endsWith('_report_generator'), isTrue);
    });
  });

  group('report-format-enforcer chain', () {
    test('enforcer rule name constant resolves to report-format-enforcer', () {
      expect(kReportFormatEnforcerRuleName, 'report-format-enforcer');
    });
  });

  group('preflightKey', () {
    test('maps a flutter pre-flight rule name to its artifact key', () {
      expect(
        preflightKey('flutter', 'tool-installer'),
        'flutter_tool_installer',
      );
    });

    test('maps a nestjs pre-flight rule name to its artifact key', () {
      expect(
        preflightKey('nestjs', 'version-alignment'),
        'nestjs_version_alignment',
      );
    });

    test('rule names with no hyphens pass through unchanged', () {
      expect(
        preflightKey('flutter', 'testcoverage'),
        'flutter_testcoverage',
      );
    });
  });

  group('generator dispatch covers every runnable bundle', () {
    // Regression test for a bug that shipped twice: kReportGeneratorRuleName
    // only matched the health-audit bundles' `report-generator` step, so the
    // `*_plan` bundles' `best-practices-generator` terminal step silently
    // fell through to the regular `execute()` path and never wrote
    // `RunConfig.reportPath`. Asserting against the real PlanParser output
    // (not just the constants) is what would have caught it.
    test('every runnable bundle\'s terminal step dispatches to the generator',
        () {
      var repoRoot = p.dirname(Directory.current.path);
      if (!File(p.join(repoRoot, 'skills', 'flutter-health-audit', 'SKILL.md'))
          .existsSync()) {
        // Fallback: maybe tests run from repo root
        repoRoot = Directory.current.path;
      }
      final loader = ContentLoader(repoRoot);
      final parser = PlanParser();
      final runnable = SkillRegistry.skills.where(
        (b) =>
            b.id.endsWith('_health') ||
            b.id.endsWith('_plan') ||
            b.id.endsWith('_audit'),
      );
      for (final b in runnable) {
        final last = parser.parse(loader.loadPlan(b)).last.ruleName;
        expect(
          isReportGeneratorRule(last),
          isTrue,
          reason: '${b.id}: terminal step "$last" would skip '
              'executeReportGenerator and never write reportPath',
        );
        expect(formatEnforcerRuleFor(last), isNotNull, reason: b.id);
      }
    });
  });

  group('report file name covers every runnable bundle', () {
    // `_reportFileFromBundle` uses `SkillBundle.name` verbatim as the
    // report-type segment. That only holds while every runnable bundle's
    // `name` is kebab-case: a snake_case or capitalised `name` slipping into
    // the registry would silently produce a report file that breaks the
    // `YYYY-MM-DD-<project>-<type>.md` convention.
    final runnable = SkillRegistry.skills.where(
      (b) =>
          b.id.endsWith('_health') ||
          b.id.endsWith('_plan') ||
          b.id.endsWith('_audit'),
    );

    test('every runnable bundle name is a clean kebab-case report type', () {
      for (final b in runnable) {
        expect(
          b.name,
          matches(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$')),
          reason: '${b.id}: name "${b.name}" is not kebab-case, so the '
              'report file name would not match the convention',
        );
        // The name must survive slugification untouched, otherwise the
        // report-type segment and the skill name would drift apart.
        expect(projectSlug(b.name), b.name, reason: b.id);
      }
    });

    test('every runnable bundle yields a conventional report file name', () {
      final date = DateTime(2026, 9, 14);
      for (final b in runnable) {
        final name = reportFileName(
          date: date,
          project: 'Hoopis_Backend',
          reportType: b.name,
        );
        expect(name, '2026-09-14-hoopis-backend-${b.name}.md', reason: b.id);
        expect(name, isNot(contains('_')), reason: b.id);
      }
    });

    test('health and plan bundles no longer collide on one name', () {
      // The old naming derived from `techPrefix`, so `flutter_health` and
      // `flutter_plan` both reduced to `flutter` and were told apart only by
      // an `_audit`/`_best_practices` suffix. Using `name` keeps them
      // distinct by construction.
      final names = runnable.map((b) => b.name).toList();
      expect(names.toSet().length, names.length);
    });
  });
}
