import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/content/content_loader.dart';
import 'package:somnio/src/content/skill_registry.dart';
import 'package:somnio/src/runner/plan_parser.dart';
import 'package:test/test.dart';

/// Integration tests that load real SKILL.md files from the repo
/// and verify PlanParser extracts the correct execution steps.
void main() {
  late PlanParser parser;
  late ContentLoader loader;
  late String repoRoot;

  setUpAll(() {
    // Resolve repo root (cli/ is the working directory during tests)
    repoRoot = p.dirname(Directory.current.path);
    if (!File(p.join(repoRoot, 'skills', 'flutter-health-audit', 'SKILL.md'))
        .existsSync()) {
      // Fallback: maybe tests run from repo root
      repoRoot = Directory.current.path;
    }
  });

  setUp(() {
    parser = PlanParser();
    loader = ContentLoader(repoRoot);
  });

  /// Expected step counts and first/last rule names per skill.
  final expectations = <String, _SkillExpectation>{
    'flutter-health-audit': _SkillExpectation(
      stepCount: 11,
      firstRule: 'tool-installer',
      lastRule: 'report-generator',
      mandatoryRules: ['version-alignment'],
    ),
    'flutter-best-practices': _SkillExpectation(
      stepCount: 5,
      firstRule: 'testing-quality',
      lastRule: 'best-practices-generator',
      mandatoryRules: [],
    ),
    'nestjs-health-audit': _SkillExpectation(
      stepCount: 13,
      firstRule: 'tool-installer',
      lastRule: 'report-generator',
      mandatoryRules: ['version-alignment'],
    ),
    'nestjs-best-practices': _SkillExpectation(
      stepCount: 7,
      firstRule: 'testing-quality',
      lastRule: 'best-practices-generator',
      mandatoryRules: [],
    ),
    'security-audit': _SkillExpectation(
      stepCount: 10,
      firstRule: 'tool-installer',
      lastRule: 'report-generator',
      mandatoryRules: ['tool-installer'],
    ),
  };

  for (final entry in expectations.entries) {
    final skillName = entry.key;
    final expected = entry.value;

    test('$skillName: parses ${expected.stepCount} steps from real SKILL.md',
        () {
      final bundle = SkillRegistry.findByName(skillName);
      expect(bundle, isNotNull, reason: 'Skill "$skillName" not in registry');

      final planContent = loader.loadPlan(bundle!);
      final steps = parser.parse(planContent);

      expect(
        steps.length,
        expected.stepCount,
        reason: '$skillName: expected ${expected.stepCount} steps, '
            'got ${steps.length}',
      );

      // First and last rule names
      expect(steps.first.ruleName, expected.firstRule);
      expect(steps.last.ruleName, expected.lastRule);

      // Step indices are sequential 1..N
      for (var i = 0; i < steps.length; i++) {
        expect(steps[i].index, i + 1);
      }

      // Mandatory flags
      for (final mandatoryName in expected.mandatoryRules) {
        final step = steps.firstWhere(
          (s) => s.ruleName == mandatoryName,
          orElse: () => throw StateError(
            '$skillName: expected mandatory rule "$mandatoryName" not found',
          ),
        );
        expect(
          step.isMandatory,
          true,
          reason: '$skillName: "$mandatoryName" should be MANDATORY',
        );
      }

      // All rule names are non-empty and contain only valid chars
      for (final step in steps) {
        expect(
          step.ruleName,
          matches(RegExp(r'^[\w-]+$')),
          reason: '$skillName step ${step.index}: '
              'invalid rule name "${step.ruleName}"',
        );
      }

      // Verify corresponding reference files exist
      final refsDir = p.join(repoRoot, bundle.rulesDirectory);
      for (final step in steps) {
        final refFile = File(p.join(refsDir, '${step.ruleName}.md'));
        expect(
          refFile.existsSync(),
          true,
          reason: '$skillName step ${step.index}: '
              'reference file not found: ${refFile.path}',
        );
      }
    });
  }
}

class _SkillExpectation {
  const _SkillExpectation({
    required this.stepCount,
    required this.firstRule,
    required this.lastRule,
    required this.mandatoryRules,
  });

  final int stepCount;
  final String firstRule;
  final String lastRule;
  final List<String> mandatoryRules;
}
