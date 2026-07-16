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
      // 13, not 12: state-management-analysis was added as step 10 to
      // produce evidence for the mandatory "State Management" report
      // section (mirrors react-health-audit's numbering).
      stepCount: 13,
      firstRule: 'tool-installer',
      lastRule: 'report-generator',
      mandatoryRules: ['version-alignment'],
    ),
    // 4, not 5: the numbered best-practices-format-enforcer step was removed.
    // The runner auto-applies the enforcer after the generator writes the
    // report (RunCommand._executeBundle keys it off formatEnforcerRuleFor),
    // so numbering it ran it twice — once against a report that did not yet
    // exist. Health audits already omit their enforcer for the same reason.
    'flutter-best-practices': _SkillExpectation(
      stepCount: 4,
      firstRule: 'testing-quality',
      lastRule: 'best-practices-generator',
      mandatoryRules: [],
    ),
    'nestjs-health-audit': _SkillExpectation(
      stepCount: 14,
      firstRule: 'tool-installer',
      lastRule: 'report-generator',
      mandatoryRules: ['version-alignment'],
    ),
    'nestjs-best-practices': _SkillExpectation(
      stepCount: 6,
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
    'python-health-audit': _SkillExpectation(
      stepCount: 14,
      firstRule: 'tool-installer',
      lastRule: 'report-generator',
      mandatoryRules: ['version-alignment'],
    ),
    'react-health-audit': _SkillExpectation(
      // 13, not 14: report-format-enforcer is no longer a numbered rule —
      // it is auto-applied by the runner's format-enforcer pass.
      stepCount: 13,
      firstRule: 'tool-installer',
      lastRule: 'report-generator',
      mandatoryRules: ['version-alignment'],
    ),
    'python-best-practices': _SkillExpectation(
      stepCount: 8,
      firstRule: 'typing',
      lastRule: 'best-practices-generator',
      mandatoryRules: [],
    ),
    'react-best-practices': _SkillExpectation(
      stepCount: 7,
      firstRule: 'testing-quality',
      lastRule: 'best-practices-generator',
      mandatoryRules: [],
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

      // The new AI Harness & Adoption step must resolve `model: mid` and
      // must not be null — this is the thing most likely to fail silently
      // if the rule line ever wraps and swallows the `{model: ...}` token
      // (see spec.md §7 / §10).
      if (_harnessAuditSkills.contains(skillName)) {
        final harnessStep = steps.firstWhere(
          (s) => s.ruleName == 'harness-analysis',
          orElse: () => throw StateError(
            '$skillName: expected "harness-analysis" step not found',
          ),
        );
        expect(
          harnessStep.model,
          isNotNull,
          reason: '$skillName: harness-analysis step must have a resolved '
              'model tier (got null — the {model: ...} token was likely '
              'swallowed by a wrapped line)',
        );
        expect(
          harnessStep.model,
          'mid',
          reason: '$skillName: harness-analysis step must resolve '
              'model: mid',
        );
        // Must remain immediately before the generator, per spec §7.
        expect(
          steps.last.ruleName,
          'report-generator',
          reason: '$skillName: report-generator must still be last',
        );
      }
    });
  }
}

/// Skills that ship the AI Harness & Adoption rubric (spec.md §4).
const _harnessAuditSkills = {
  'flutter-health-audit',
  'nestjs-health-audit',
  'python-health-audit',
  'react-health-audit',
};

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
