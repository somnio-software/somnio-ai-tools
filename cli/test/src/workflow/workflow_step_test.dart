import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/workflow/workflow_step.dart';
import 'package:test/test.dart';

void main() {
  group('loadFrom', () {
    test('returns null when the file does not exist', () {
      final tmp = Directory.systemTemp.createTempSync('somnio_step_load_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      expect(WorkflowStep.loadFrom(p.join(tmp.path, 'missing.md')), isNull);
    });

    test('parses a step file from disk', () {
      final tmp = Directory.systemTemp.createTempSync('somnio_step_load_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final file = File(p.join(tmp.path, '01-step.md'))
        ..writeAsStringSync('---\nname: Analyze\nindex: 1\n---\n\n# Body\n');

      final step = WorkflowStep.loadFrom(file.path);

      expect(step, isNotNull);
      expect(step!.name, 'Analyze');
    });

    group('returns null instead of throwing when the file is malformed', () {
      final cases = {
        'no frontmatter': '# Just a body\n',
        'unclosed frontmatter': '---\nname: Analyze\n',
        'frontmatter is a list': '---\n- a\n- b\n---\n\n# Body\n',
        'frontmatter is a scalar': '---\njust a string\n---\n\n# Body\n',
        'index is a string': '---\nname: A\nindex: "one"\n---\n\n# Body\n',
        'invalid yaml': '---\nname: [unclosed\n---\n\n# Body\n',
      };

      cases.forEach((label, content) {
        test(label, () {
          final tmp = Directory.systemTemp.createTempSync('somnio_step_bad_');
          addTearDown(() => tmp.deleteSync(recursive: true));
          final file = File(p.join(tmp.path, '01-step.md'))
            ..writeAsStringSync(content);

          expect(WorkflowStep.loadFrom(file.path), isNull);
        });
      });
    });
  });

  group('WorkflowStep', () {
    group('parse', () {
      test('parses step with full frontmatter and body', () {
        const content = '''
---
name: Execute Updates
tag: execution
index: 3
mandatory: true
needs_previous: true
---

# Execute Updates

## Objective
Apply the update strategy from the previous step.

## Instructions
1. Read the update plan from: {previous_output}
2. Execute updates

## Output
Save your execution log to: {output_path}
''';

        final step = WorkflowStep.parse(content);

        expect(step.name, 'Execute Updates');
        expect(step.tag, 'execution');
        expect(step.index, 3);
        expect(step.mandatory, isTrue);
        expect(step.needsPrevious, isTrue);
        expect(step.body, contains('# Execute Updates'));
        expect(step.body, contains('{previous_output}'));
        expect(step.body, contains('{output_path}'));
      });

      test('parses minimal step', () {
        const content = '''
---
name: Simple Step
index: 1
---

Do something simple.
''';

        final step = WorkflowStep.parse(content);

        expect(step.name, 'Simple Step');
        expect(step.tag, 'execution');
        expect(step.index, 1);
        expect(step.mandatory, isFalse);
        expect(step.needsPrevious, isFalse);
      });

      test('throws on missing frontmatter', () {
        expect(
          () => WorkflowStep.parse('No frontmatter here'),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on unclosed frontmatter', () {
        expect(
          () => WorkflowStep.parse('---\nname: broken\n'),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('resolveBody', () {
      test('replaces all placeholders', () {
        const step = WorkflowStep(
          name: 'Test',
          tag: 'execution',
          index: 2,
          needsPrevious: true,
          body: 'Read from {previous_output}\n'
              'Save to {output_path}\n'
              'Outputs in {outputs_dir}\n'
              'Workflow at {workflow_dir}',
        );

        final resolved = step.resolveBody(
          workflowDir: '/project/.somnio/workflows/test',
          outputsDir: '/project/.somnio/workflows/test/outputs',
          outputPath: '/project/.somnio/workflows/test/outputs/02-test-output.md',
          previousOutputPath: '/project/.somnio/workflows/test/outputs/01-prev-output.md',
        );

        expect(resolved, contains('/project/.somnio/workflows/test/outputs/01-prev-output.md'));
        expect(resolved, contains('/project/.somnio/workflows/test/outputs/02-test-output.md'));
        expect(resolved, contains('/project/.somnio/workflows/test/outputs'));
        expect(resolved, contains('/project/.somnio/workflows/test'));
      });

      test('resolves {step_N_output} placeholders', () {
        const step = WorkflowStep(
          name: 'Report',
          tag: 'planning',
          index: 4,
          body: 'Read map from: {step_1_output}\n'
              'Read scan from: {step_2_output}\n'
              'Read config from: {step_3_output}\n'
              'Save to: {output_path}',
        );

        final resolved = step.resolveBody(
          workflowDir: '/wf',
          outputsDir: '/wf/outputs',
          outputPath: '/wf/outputs/04-report-output.md',
          stepOutputPaths: {
            1: '/wf/outputs/01-map-output.md',
            2: '/wf/outputs/02-scan-output.md',
            3: '/wf/outputs/03-config-output.md',
          },
        );

        expect(resolved, contains('/wf/outputs/01-map-output.md'));
        expect(resolved, contains('/wf/outputs/02-scan-output.md'));
        expect(resolved, contains('/wf/outputs/03-config-output.md'));
        expect(resolved, contains('/wf/outputs/04-report-output.md'));
      });

      test('leaves {step_N_output} unreplaced when path not available', () {
        const step = WorkflowStep(
          name: 'Test',
          tag: 'execution',
          index: 2,
          body: 'Read from: {step_5_output}',
        );

        final resolved = step.resolveBody(
          workflowDir: '/wf',
          outputsDir: '/wf/outputs',
          outputPath: '/wf/outputs/02-test-output.md',
          stepOutputPaths: {1: '/wf/outputs/01-output.md'},
        );

        expect(resolved, contains('{step_5_output}'));
      });

      test('leaves {step_N_output} unreplaced when stepOutputPaths is null', () {
        const step = WorkflowStep(
          name: 'Test',
          tag: 'execution',
          index: 2,
          body: 'Read from: {step_1_output}',
        );

        final resolved = step.resolveBody(
          workflowDir: '/wf',
          outputsDir: '/wf/outputs',
          outputPath: '/wf/outputs/02-test-output.md',
        );

        expect(resolved, contains('{step_1_output}'));
      });

      test('leaves {previous_output} unreplaced when no previous path', () {
        const step = WorkflowStep(
          name: 'Test',
          tag: 'execution',
          index: 1,
          body: 'Save to {output_path}, prev: {previous_output}',
        );

        final resolved = step.resolveBody(
          workflowDir: '/wf',
          outputsDir: '/wf/outputs',
          outputPath: '/wf/outputs/01-test-output.md',
        );

        expect(resolved, contains('{previous_output}'));
        expect(resolved, contains('/wf/outputs/01-test-output.md'));
      });
    });

    group('outputFileName', () {
      test('converts step filename to output filename', () {
        expect(
          WorkflowStep.outputFileName('01-analyze-dependencies.md'),
          '01-analyze-dependencies-output.md',
        );
      });

      test('handles single-word step name', () {
        expect(
          WorkflowStep.outputFileName('01-analyze.md'),
          '01-analyze-output.md',
        );
      });
    });
  });
}
