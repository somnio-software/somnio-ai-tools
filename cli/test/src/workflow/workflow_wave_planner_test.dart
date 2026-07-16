import 'package:somnio/src/workflow/workflow_context.dart';
import 'package:somnio/src/workflow/workflow_wave_planner.dart';
import 'package:test/test.dart';

void main() {
  const planner = WavePlanner();

  WorkflowStepEntry _entry({
    String file = 'step.md',
    List<int> needs = const [],
  }) =>
      WorkflowStepEntry(file: file, tag: 'research', needs: needs);

  group('WavePlanner', () {
    test('empty steps returns empty waves', () {
      final waves = planner.plan([]);
      expect(waves, isEmpty);
    });

    test('single step returns one wave', () {
      final waves = planner.plan([_entry(file: '01.md')]);
      expect(waves, hasLength(1));
      expect(waves[0].stepIndices, [0]);
    });

    test('all independent steps form a single wave', () {
      final waves = planner.plan([
        _entry(file: '01.md'),
        _entry(file: '02.md'),
        _entry(file: '03.md'),
        _entry(file: '04.md'),
      ]);
      expect(waves, hasLength(1));
      expect(waves[0].stepIndices, [0, 1, 2, 3]);
    });

    test('all sequential steps form N waves', () {
      final waves = planner.plan([
        _entry(file: '01.md'),
        _entry(file: '02.md', needs: [0]), // needs step 1 (0-based: 0)
        _entry(file: '03.md', needs: [1]), // needs step 2 (0-based: 1)
      ]);
      expect(waves, hasLength(3));
      expect(waves[0].stepIndices, [0]);
      expect(waves[1].stepIndices, [1]);
      expect(waves[2].stepIndices, [2]);
    });

    test('mixed dependencies create correct waves', () {
      // Step 0: independent
      // Step 1: needs 0
      // Step 2: independent
      // Step 3: independent
      // Step 4: independent
      // Step 5: needs all (0-4)
      final waves = planner.plan([
        _entry(file: '01.md'),
        _entry(file: '02.md', needs: [0]),
        _entry(file: '03.md'),
        _entry(file: '04.md'),
        _entry(file: '05.md'),
        _entry(file: '06.md', needs: [0, 1, 2, 3, 4]),
      ]);
      expect(waves, hasLength(3));
      expect(waves[0].stepIndices, [0, 2, 3, 4]);
      expect(waves[1].stepIndices, [1]);
      expect(waves[2].stepIndices, [5]);
    });

    test('needs: all creates correct dependency', () {
      // Step 0: independent
      // Step 1: independent
      // Step 2: independent
      // Step 3: needs all (0,1,2)
      final waves = planner.plan([
        _entry(file: '01.md'),
        _entry(file: '02.md'),
        _entry(file: '03.md'),
        _entry(file: '04.md', needs: [0, 1, 2]),
      ]);
      expect(waves, hasLength(2));
      expect(waves[0].stepIndices, [0, 1, 2]);
      expect(waves[1].stepIndices, [3]);
    });

    test('needs specific steps: [1, 3]', () {
      // Step 0: independent        → level 0
      // Step 1: independent        → level 0
      // Step 2: independent        → level 0
      // Step 3: needs [0, 2]       → level 1
      final waves = planner.plan([
        _entry(file: '01.md'),
        _entry(file: '02.md'),
        _entry(file: '03.md'),
        _entry(file: '04.md', needs: [0, 2]),
      ]);
      expect(waves, hasLength(2));
      expect(waves[0].stepIndices, [0, 1, 2]);
      expect(waves[1].stepIndices, [3]);
    });

    test('chain dependency creates sequential waves', () {
      // 0 → 1 → 2 → 3
      final waves = planner.plan([
        _entry(file: '01.md'),
        _entry(file: '02.md', needs: [0]),
        _entry(file: '03.md', needs: [1]),
        _entry(file: '04.md', needs: [2]),
      ]);
      expect(waves, hasLength(4));
      expect(waves[0].stepIndices, [0]);
      expect(waves[1].stepIndices, [1]);
      expect(waves[2].stepIndices, [2]);
      expect(waves[3].stepIndices, [3]);
    });

    test('diamond dependency pattern', () {
      // Step 0: independent        → level 0
      // Step 1: needs [0]          → level 1
      // Step 2: needs [0]          → level 1
      // Step 3: needs [1, 2]       → level 2
      final waves = planner.plan([
        _entry(file: '01.md'),
        _entry(file: '02.md', needs: [0]),
        _entry(file: '03.md', needs: [0]),
        _entry(file: '04.md', needs: [1, 2]),
      ]);
      expect(waves, hasLength(3));
      expect(waves[0].stepIndices, [0]);
      expect(waves[1].stepIndices, [1, 2]);
      expect(waves[2].stepIndices, [3]);
    });

    test('wave length returns correct count', () {
      final waves = planner.plan([
        _entry(file: '01.md'),
        _entry(file: '02.md'),
        _entry(file: '03.md'),
      ]);
      expect(waves[0].length, 3);
    });

    test('forward reference: dep declared after its dependent', () {
      // Step 0 needs step 3 (0-based 2), step 2 needs step 5 (0-based 4).
      // Wave assignment must not depend on declaration order.
      final waves = planner.plan([
        _entry(file: '01.md', needs: [2]),
        _entry(file: '02.md'),
        _entry(file: '03.md', needs: [4]),
        _entry(file: '04.md'),
        _entry(file: '05.md'),
      ]);
      expect(waves, hasLength(3));
      expect(waves[0].stepIndices, [1, 3, 4]);
      expect(waves[1].stepIndices, [2]);
      expect(waves[2].stepIndices, [0]);

      // Each dependency must land strictly before its dependent.
      int waveOf(int step) =>
          waves.indexWhere((w) => w.stepIndices.contains(step));
      expect(waveOf(2), lessThan(waveOf(0)));
      expect(waveOf(4), lessThan(waveOf(2)));
    });

    test('duplicate deps are tolerated', () {
      final waves = planner.plan([
        _entry(file: '01.md'),
        _entry(file: '02.md', needs: [0, 0, 0]),
      ]);
      expect(waves, hasLength(2));
      expect(waves[0].stepIndices, [0]);
      expect(waves[1].stepIndices, [1]);
    });

    test('two-step cycle throws', () {
      expect(
        () => planner.plan([
          _entry(file: '01.md', needs: [1]),
          _entry(file: '02.md', needs: [0]),
        ]),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('cycle'), contains('01.md'), contains('02.md')),
          ),
        ),
      );
    });

    test('longer cycle throws and reports only the stuck steps', () {
      expect(
        () => planner.plan([
          _entry(file: '01.md'),
          _entry(file: '02.md', needs: [3]),
          _entry(file: '03.md', needs: [1]),
          _entry(file: '04.md', needs: [2]),
        ]),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('cycle'),
              contains('02.md'),
              contains('03.md'),
              contains('04.md'),
              isNot(contains('01.md')),
            ),
          ),
        ),
      );
    });

    test('out-of-range dependency throws', () {
      expect(
        () => planner.plan([
          _entry(file: '01.md'),
          _entry(file: '02.md', needs: [7]),
        ]),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Step 2 (02.md)'),
              contains('needs: 8'), // reported 1-based
              contains('only has 2 steps'),
            ),
          ),
        ),
      );
    });

    test('negative dependency throws', () {
      expect(
        () => planner.plan([_entry(file: '01.md', needs: [-1])]),
        throwsA(isA<FormatException>()),
      );
    });

    test('self dependency throws', () {
      expect(
        () => planner.plan([
          _entry(file: '01.md'),
          _entry(file: '02.md', needs: [1]),
        ]),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Step 2 (02.md) depends on itself'),
          ),
        ),
      );
    });
  });
}
