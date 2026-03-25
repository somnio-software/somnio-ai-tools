import 'package:somnio/src/runner/plan_parser.dart';
import 'package:test/test.dart';

void main() {
  late PlanParser parser;

  setUp(() {
    parser = PlanParser();
  });

  group('PlanParser', () {
    // ---------------------------------------------------------------
    // Real SKILL.md tests — one per runnable skill
    // ---------------------------------------------------------------

    test('flutter-health-audit (fh): verbose format, 11 steps', () {
      const plan = '''
**Rule Execution Order**:
1. Read and follow the instructions in `references/tool-installer.md`
2. Read and follow the instructions in `references/version-alignment.md` (MANDATORY - stops if FVM global
   fails)
3. Read and follow the instructions in `references/version-validator.md` (verification of FVM global setup)
4. Read and follow the instructions in `references/test-coverage.md` (coverage generation)
5. Read and follow the instructions in `references/repository-inventory.md`
6. Read and follow the instructions in `references/config-analysis.md`
7. Read and follow the instructions in `references/cicd-analysis.md`
8. Read and follow the instructions in `references/testing-analysis.md`
9. Read and follow the instructions in `references/code-quality.md`
10. Read and follow the instructions in `references/documentation-analysis.md`
11. Read and follow the instructions in `references/report-generator.md`

**Benefits of Modular Approach**:
''';

      final steps = parser.parse(plan);

      expect(steps, hasLength(11));
      expect(steps[0].ruleName, 'tool-installer');
      expect(steps[0].isMandatory, false);
      expect(steps[1].ruleName, 'version-alignment');
      expect(steps[1].isMandatory, true);
      expect(steps[2].ruleName, 'version-validator');
      expect(steps[3].ruleName, 'test-coverage');
      expect(steps[4].ruleName, 'repository-inventory');
      expect(steps[5].ruleName, 'config-analysis');
      expect(steps[6].ruleName, 'cicd-analysis');
      expect(steps[7].ruleName, 'testing-analysis');
      expect(steps[8].ruleName, 'code-quality');
      expect(steps[9].ruleName, 'documentation-analysis');
      expect(steps[10].ruleName, 'report-generator');
      expect(steps[10].index, 11);
    });

    test('flutter-best-practices (fp): verbose format, 5 steps', () {
      const plan = '''
**Rule Execution Order**:
1. Read and follow the instructions in `references/testing-quality.md`
2. Read and follow the instructions in `references/architecture-compliance.md`
3. Read and follow the instructions in `references/code-standards.md`
4. Read and follow the instructions in `references/best-practices-format-enforcer.md`
5. Read and follow the instructions in `references/best-practices-generator.md`

## Report Metadata (MANDATORY)
''';

      final steps = parser.parse(plan);

      expect(steps, hasLength(5));
      expect(steps[0].ruleName, 'testing-quality');
      expect(steps[1].ruleName, 'architecture-compliance');
      expect(steps[2].ruleName, 'code-standards');
      expect(steps[3].ruleName, 'best-practices-format-enforcer');
      expect(steps[4].ruleName, 'best-practices-generator');
    });

    test('nestjs-health-audit (nh): short format, 13 steps', () {
      const plan = '''
**Rule Execution Order**:
1. `references/tool-installer.md`
2. `references/version-alignment.md` (MANDATORY - stops if nvm fails)
3. `references/version-validator.md` (verification of nvm setup)
4. `references/test-coverage.md` (coverage generation)
5. `references/repository-inventory.md`
6. `references/config-analysis.md`
7. `references/cicd-analysis.md`
8. `references/testing-analysis.md`
9. `references/code-quality.md`
10. `references/api-design-analysis.md`
11. `references/data-layer-analysis.md`
12. `references/documentation-analysis.md`
13. `references/report-generator.md`

**Benefits of Modular Approach**:
''';

      final steps = parser.parse(plan);

      expect(steps, hasLength(13));
      expect(steps[0].ruleName, 'tool-installer');
      expect(steps[1].ruleName, 'version-alignment');
      expect(steps[1].isMandatory, true);
      expect(steps[9].ruleName, 'api-design-analysis');
      expect(steps[10].ruleName, 'data-layer-analysis');
      expect(steps[12].ruleName, 'report-generator');
      expect(steps[12].index, 13);
    });

    test('nestjs-best-practices (np): short format with double spaces, 7 steps',
        () {
      // NestJS best practices uses two spaces after the period (e.g., "1.  `ref...")
      const plan = '''
**Rule Execution Order**:
1.  `references/testing-quality.md`
2.  `references/architecture-compliance.md`
3.  `references/code-standards.md`
4.  `references/dto-validation.md`
5.  `references/error-handling.md`
6.  `references/best-practices-format-enforcer.md`
7.  `references/best-practices-generator.md`

## Standards References
''';

      final steps = parser.parse(plan);

      expect(steps, hasLength(7));
      expect(steps[0].ruleName, 'testing-quality');
      expect(steps[3].ruleName, 'dto-validation');
      expect(steps[4].ruleName, 'error-handling');
      expect(steps[5].ruleName, 'best-practices-format-enforcer');
      expect(steps[6].ruleName, 'best-practices-generator');
    });

    test('security-audit (sa): verbose format with annotations, 10 steps', () {
      const plan = '''
**Rule Execution Order**:
1. Read and follow the instructions in `references/tool-installer.md` (MANDATORY - tool detection)
2. Read and follow the instructions in `references/file-analysis.md`
3. Read and follow the instructions in `references/secret-patterns.md`
4. Read and follow the instructions in `references/gitleaks.md` (optional - skips if Gitleaks not installed)
5. Read and follow the instructions in `references/dependency-audit.md`
6. Read and follow the instructions in `references/dependency-age.md`
7. Read and follow the instructions in `references/trivy.md` (optional - skips if Trivy not installed)
8. Read and follow the instructions in `references/sast.md` (SAST OWASP patterns, LOW/MEDIUM findings)
9. Read and follow the instructions in `references/gemini-analysis.md` (optional - skips if Gemini unavailable)
10. Read and follow the instructions in `references/report-generator.md` (generates 13-section report with quantitative scoring)

**Post-Generation**: Read and follow...
''';

      final steps = parser.parse(plan);

      expect(steps, hasLength(10));
      expect(steps[0].ruleName, 'tool-installer');
      expect(steps[0].isMandatory, true);
      expect(steps[0].annotation, 'MANDATORY - tool detection');
      expect(steps[1].ruleName, 'file-analysis');
      expect(steps[2].ruleName, 'secret-patterns');
      expect(steps[3].ruleName, 'gitleaks');
      expect(steps[3].annotation, 'optional - skips if Gitleaks not installed');
      expect(steps[4].ruleName, 'dependency-audit');
      expect(steps[5].ruleName, 'dependency-age');
      expect(steps[6].ruleName, 'trivy');
      expect(steps[7].ruleName, 'sast');
      expect(steps[8].ruleName, 'gemini-analysis');
      expect(steps[9].ruleName, 'report-generator');
      expect(steps[9].index, 10);
    });

    // ---------------------------------------------------------------
    // Legacy format (backward compatibility)
    // ---------------------------------------------------------------

    test('legacy @format still works', () {
      const plan = '''
**Rule Execution Order**:
1. `@flutter_tool_installer`
2. `@flutter_version_alignment` (MANDATORY - stops if FVM global fails)
3. `@flutter_version_validator`
''';

      final steps = parser.parse(plan);

      expect(steps, hasLength(3));
      expect(steps[0].ruleName, 'flutter_tool_installer');
      expect(steps[1].ruleName, 'flutter_version_alignment');
      expect(steps[1].isMandatory, true);
      expect(steps[2].ruleName, 'flutter_version_validator');
    });

    // ---------------------------------------------------------------
    // Edge cases
    // ---------------------------------------------------------------

    test('returns empty list when no Rule Execution Order section', () {
      const plan = '''
# Some Plan

## Steps
1. Do something
''';

      expect(parser.parse(plan), isEmpty);
    });

    test('handles multiline annotations (line wraps to next line)', () {
      const plan = '''
**Rule Execution Order**:
1. Read and follow the instructions in `references/version-alignment.md` (MANDATORY - stops if FVM global
   fails)
2. Read and follow the instructions in `references/tool-installer.md`
''';

      final steps = parser.parse(plan);

      expect(steps, hasLength(2));
      expect(steps[0].ruleName, 'version-alignment');
      expect(steps[0].isMandatory, true);
      expect(steps[1].ruleName, 'tool-installer');
    });

    test('stops at blank line after steps', () {
      const plan = '''
**Rule Execution Order**:
1. `references/tool-installer.md`
2. `references/file-analysis.md`

This is not a step.
3. `references/should-not-parse.md`
''';

      final steps = parser.parse(plan);
      expect(steps, hasLength(2));
    });

    test('stops at new markdown section', () {
      const plan = '''
**Rule Execution Order**:
1. `references/tool-installer.md`
**Benefits of Modular Approach**:
''';

      final steps = parser.parse(plan);
      expect(steps, hasLength(1));
    });
  });
}
