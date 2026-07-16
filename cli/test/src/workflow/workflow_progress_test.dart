import 'dart:io';

import 'package:somnio/src/workflow/workflow_progress.dart';
import 'package:test/test.dart';

void main() {
  group('WorkflowProgress', () {
    group('fromJson', () {
      test('parses full progress JSON', () {
        final json = {
          'workflow': 'dependency-cleanup',
          'agent': 'claude',
          'started_at': '2026-03-03T14:35:00.000Z',
          'steps': [
            {
              'file': '01-analyze-dependencies.md',
              'status': 'completed',
              'model': 'haiku',
              'duration_s': 42,
            },
            {
              'file': '02-plan-updates.md',
              'status': 'completed',
              'model': 'opus',
              'duration_s': 68,
            },
            {
              'file': '03-execute-updates.md',
              'status': 'pending',
            },
            {
              'file': '04-verify-build.md',
              'status': 'pending',
            },
          ],
        };

        final progress = WorkflowProgress.fromJson(json);

        expect(progress.workflow, 'dependency-cleanup');
        expect(progress.agent, 'claude');
        expect(progress.steps, hasLength(4));
        expect(progress.steps[0].status, StepStatus.completed);
        expect(progress.steps[0].model, 'haiku');
        expect(progress.steps[0].durationSeconds, 42);
        expect(progress.steps[2].status, StepStatus.pending);
        expect(progress.steps[2].model, isNull);
      });

      test('handles empty steps', () {
        final json = {
          'workflow': 'test',
          'agent': 'claude',
          'started_at': '2026-01-01T00:00:00.000Z',
          'steps': [],
        };

        final progress = WorkflowProgress.fromJson(json);
        expect(progress.steps, isEmpty);
      });

      test('handles missing fields', () {
        final progress = WorkflowProgress.fromJson({});

        expect(progress.workflow, '');
        expect(progress.agent, '');
        expect(progress.steps, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes full progress', () {
        final progress = WorkflowProgress(
          workflow: 'test',
          agent: 'claude',
          startedAt: DateTime.utc(2026, 3, 3, 14, 35),
          steps: [
            StepProgress(
              file: '01-step.md',
              status: StepStatus.completed,
              model: 'haiku',
              durationSeconds: 30,
            ),
            StepProgress(file: '02-step.md'),
          ],
        );

        final json = progress.toJson();

        expect(json['workflow'], 'test');
        expect(json['agent'], 'claude');
        expect(json['started_at'], '2026-03-03T14:35:00.000Z');

        final steps = json['steps'] as List;
        expect(steps, hasLength(2));
        expect((steps[0] as Map)['status'], 'completed');
        expect((steps[0] as Map)['model'], 'haiku');
        expect((steps[0] as Map)['duration_s'], 30);
        expect((steps[1] as Map)['status'], 'pending');
        expect((steps[1] as Map).containsKey('model'), isFalse);
      });
    });

    group('computed properties', () {
      test('nextPendingIndex returns first non-completed step', () {
        final progress = WorkflowProgress(
          workflow: 'test',
          agent: 'claude',
          steps: [
            StepProgress(file: '01.md', status: StepStatus.completed),
            StepProgress(file: '02.md', status: StepStatus.completed),
            StepProgress(file: '03.md', status: StepStatus.pending),
            StepProgress(file: '04.md', status: StepStatus.pending),
          ],
        );

        expect(progress.nextPendingIndex, 2);
      });

      test('nextPendingIndex returns -1 when all complete', () {
        final progress = WorkflowProgress(
          workflow: 'test',
          agent: 'claude',
          steps: [
            StepProgress(file: '01.md', status: StepStatus.completed),
            StepProgress(file: '02.md', status: StepStatus.completed),
          ],
        );

        expect(progress.nextPendingIndex, -1);
      });

      test('isComplete returns true when all done', () {
        final progress = WorkflowProgress(
          workflow: 'test',
          agent: 'claude',
          steps: [
            StepProgress(file: '01.md', status: StepStatus.completed),
          ],
        );

        expect(progress.isComplete, isTrue);
      });

      test('isComplete returns false with pending steps', () {
        final progress = WorkflowProgress(
          workflow: 'test',
          agent: 'claude',
          steps: [
            StepProgress(file: '01.md', status: StepStatus.completed),
            StepProgress(file: '02.md', status: StepStatus.pending),
          ],
        );

        expect(progress.isComplete, isFalse);
      });

      test('completedCount is accurate', () {
        final progress = WorkflowProgress(
          workflow: 'test',
          agent: 'claude',
          steps: [
            StepProgress(file: '01.md', status: StepStatus.completed),
            StepProgress(file: '02.md', status: StepStatus.completed),
            StepProgress(file: '03.md', status: StepStatus.pending),
          ],
        );

        expect(progress.completedCount, 2);
      });

      test('totalDurationSeconds sums completed durations', () {
        final progress = WorkflowProgress(
          workflow: 'test',
          agent: 'claude',
          steps: [
            StepProgress(
              file: '01.md',
              status: StepStatus.completed,
              durationSeconds: 30,
            ),
            StepProgress(
              file: '02.md',
              status: StepStatus.completed,
              durationSeconds: 45,
            ),
            StepProgress(file: '03.md'),
          ],
        );

        expect(progress.totalDurationSeconds, 75);
      });
    });

    group('file I/O', () {
      late Directory tempDir;

      setUp(() {
        tempDir =
            Directory.systemTemp.createTempSync('workflow_progress_test_');
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      test('saveTo and loadFrom roundtrip', () {
        final progress = WorkflowProgress(
          workflow: 'test',
          agent: 'claude',
          startedAt: DateTime.utc(2026, 3, 3),
          steps: [
            StepProgress(
              file: '01-step.md',
              status: StepStatus.completed,
              model: 'haiku',
              durationSeconds: 42,
            ),
            StepProgress(file: '02-step.md'),
          ],
        );

        final path = '${tempDir.path}/progress.json';
        progress.saveTo(path);

        final loaded = WorkflowProgress.loadFrom(path);

        expect(loaded, isNotNull);
        expect(loaded!.workflow, 'test');
        expect(loaded.agent, 'claude');
        expect(loaded.steps, hasLength(2));
        expect(loaded.steps[0].status, StepStatus.completed);
        expect(loaded.steps[0].model, 'haiku');
        expect(loaded.steps[1].status, StepStatus.pending);
      });

      test('loadFrom returns null for missing file', () {
        expect(
          WorkflowProgress.loadFrom('${tempDir.path}/missing.json'),
          isNull,
        );
      });

      group('loadFrom returns null instead of throwing for malformed', () {
        final cases = {
          'not json': 'not json at all',
          'truncated json': '{"workflow": "test"',
          'top level is a list': '[1, 2, 3]',
          'top level is a scalar': '"test"',
          'steps is not a list': '{"steps": {"file": "01.md"}}',
          'step entry is not a map': '{"steps": ["01-step.md"]}',
          'step entry missing file key': '{"steps": [{"status": "completed"}]}',
          'duration is not an int':
              '{"steps": [{"file": "01.md", "duration_s": "42"}]}',
        };

        cases.forEach((label, content) {
          test(label, () {
            final path = '${tempDir.path}/progress.bad.json';
            File(path).writeAsStringSync(content);
            expect(WorkflowProgress.loadFrom(path), isNull);
          });
        });
      });
    });
  });

  group('StepStatus parsing', () {
    test('parses all status values', () {
      for (final status in StepStatus.values) {
        final json = {'file': 'test.md', 'status': status.name};
        final step = StepProgress.fromJson(json);
        expect(step.status, status);
      }
    });

    test('defaults unknown status to pending', () {
      final step = StepProgress.fromJson({
        'file': 'test.md',
        'status': 'unknown',
      });
      expect(step.status, StepStatus.pending);
    });
  });
}
