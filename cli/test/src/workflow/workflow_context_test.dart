import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/workflow/workflow_context.dart';
import 'package:test/test.dart';

void main() {
  group('loadFrom', () {
    test('returns null when the file does not exist', () {
      final tmp = Directory.systemTemp.createTempSync('somnio_ctx_load_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      expect(WorkflowContext.loadFrom(p.join(tmp.path, 'missing.md')), isNull);
    });

    test('parses a context.md file from disk', () {
      final tmp = Directory.systemTemp.createTempSync('somnio_ctx_load_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final file = File(p.join(tmp.path, 'context.md'))
        ..writeAsStringSync(
          '---\nname: cleanup\ndescription: d\nversion: 1\nsteps:\n'
          '  - file: 01-analyze.md\n---\n',
        );

      final ctx = WorkflowContext.loadFrom(file.path);

      expect(ctx, isNotNull);
      expect(ctx!.name, 'cleanup');
    });
  });

  group('WorkflowContext', () {
    group('parse', () {
      test('parses full context.md with all fields', () {
        const content = '''
---
name: dependency-cleanup
description: Analyze and clean up project dependencies
created: 2026-03-03T14:30:00Z
version: 1
steps:
  - file: 01-analyze-dependencies.md
    tag: research
    mandatory: false
  - file: 02-plan-updates.md
    tag: planning
    mandatory: false
    needs: [1]
  - file: 03-execute-updates.md
    tag: execution
    mandatory: true
    needs: [2]
  - file: 04-verify-build.md
    tag: execution
    mandatory: true
---

# dependency-cleanup

Some description text here.
''';

        final context = WorkflowContext.parse(content);

        expect(context.name, 'dependency-cleanup');
        expect(context.description, 'Analyze and clean up project dependencies');
        expect(context.version, 1);
        expect(context.created, DateTime.utc(2026, 3, 3, 14, 30));
        expect(context.steps, hasLength(4));

        expect(context.steps[0].file, '01-analyze-dependencies.md');
        expect(context.steps[0].tag, 'research');
        expect(context.steps[0].mandatory, isFalse);
        expect(context.steps[0].needs, isEmpty);

        expect(context.steps[1].file, '02-plan-updates.md');
        expect(context.steps[1].needs, [0]); // 1-based [1] → 0-based [0]

        expect(context.steps[2].file, '03-execute-updates.md');
        expect(context.steps[2].tag, 'execution');
        expect(context.steps[2].mandatory, isTrue);
        expect(context.steps[2].needs, [1]); // 1-based [2] → 0-based [1]

        expect(context.steps[3].needs, isEmpty);
      });

      test('parses minimal context.md', () {
        const content = '''
---
name: simple-task
description: A simple task
steps:
  - file: 01-do-it.md
    tag: execution
---
''';

        final context = WorkflowContext.parse(content);

        expect(context.name, 'simple-task');
        expect(context.version, 1);
        expect(context.created, isNull);
        expect(context.steps, hasLength(1));
      });

      test('defaults tag to execution when missing', () {
        const content = '''
---
name: test
description: test
steps:
  - file: 01-step.md
---
''';

        final context = WorkflowContext.parse(content);
        expect(context.steps[0].tag, 'execution');
      });

      test('defaults needs to empty list', () {
        const content = '''
---
name: test
description: test
steps:
  - file: 01-step.md
    tag: research
---
''';

        final context = WorkflowContext.parse(content);
        expect(context.steps[0].mandatory, isFalse);
        expect(context.steps[0].needs, isEmpty);
        expect(context.steps[0].hasDependencies, isFalse);
      });

      test('parses needs: all', () {
        const content = '''
---
name: test
description: test
steps:
  - file: 01-step.md
    tag: research
  - file: 02-step.md
    tag: research
  - file: 03-report.md
    tag: planning
    needs: all
---
''';

        final context = WorkflowContext.parse(content);
        expect(context.steps[2].needs, [0, 1]);
      });

      test('parses needs: previous', () {
        const content = '''
---
name: test
description: test
steps:
  - file: 01-step.md
    tag: research
  - file: 02-step.md
    tag: planning
    needs: previous
---
''';

        final context = WorkflowContext.parse(content);
        expect(context.steps[1].needs, [0]);
      });

      test('parses needs as single int', () {
        const content = '''
---
name: test
description: test
steps:
  - file: 01-step.md
    tag: research
  - file: 02-step.md
    tag: research
  - file: 03-step.md
    tag: planning
    needs: 1
---
''';

        final context = WorkflowContext.parse(content);
        expect(context.steps[2].needs, [0]); // 1-based 1 → 0-based 0
      });

      test('parses needs as list of ints', () {
        const content = '''
---
name: test
description: test
steps:
  - file: 01-step.md
    tag: research
  - file: 02-step.md
    tag: research
  - file: 03-step.md
    tag: research
  - file: 04-step.md
    tag: planning
    needs: [1, 3]
---
''';

        final context = WorkflowContext.parse(content);
        expect(context.steps[3].needs, [0, 2]); // 1-based [1,3] → 0-based [0,2]
      });

      test('backward compat: needs_previous: true', () {
        const content = '''
---
name: test
description: test
steps:
  - file: 01-step.md
    tag: research
  - file: 02-step.md
    tag: planning
    needs_previous: true
---
''';

        final context = WorkflowContext.parse(content);
        expect(context.steps[1].needs, [0]);
        expect(context.steps[1].needsPrevious, isTrue);
      });

      test('backward compat: needs_previous: false', () {
        const content = '''
---
name: test
description: test
steps:
  - file: 01-step.md
    tag: research
  - file: 02-step.md
    tag: planning
    needs_previous: false
---
''';

        final context = WorkflowContext.parse(content);
        expect(context.steps[1].needs, isEmpty);
      });

      test('needs field takes priority over needs_previous', () {
        const content = '''
---
name: test
description: test
steps:
  - file: 01-step.md
    tag: research
  - file: 02-step.md
    tag: research
  - file: 03-step.md
    tag: planning
    needs: [1]
    needs_previous: true
---
''';

        final context = WorkflowContext.parse(content);
        // needs field wins: [1] → 0-based [0], not [1] from needs_previous
        expect(context.steps[2].needs, [0]);
      });

      test('needs: previous on first step returns empty', () {
        const content = '''
---
name: test
description: test
steps:
  - file: 01-step.md
    tag: research
    needs: previous
---
''';

        final context = WorkflowContext.parse(content);
        expect(context.steps[0].needs, isEmpty);
      });

      test('needs: all on first step returns empty', () {
        const content = '''
---
name: test
description: test
steps:
  - file: 01-step.md
    tag: research
    needs: all
---
''';

        final context = WorkflowContext.parse(content);
        expect(context.steps[0].needs, isEmpty);
      });

      test('throws on missing frontmatter', () {
        const content = '# No frontmatter here';

        expect(
          () => WorkflowContext.parse(content),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on unclosed frontmatter', () {
        const content = '''
---
name: broken
''';

        expect(
          () => WorkflowContext.parse(content),
          throwsA(isA<FormatException>()),
        );
      });

      test('handles empty steps list', () {
        const content = '''
---
name: empty
description: no steps
steps: []
---
''';

        final context = WorkflowContext.parse(content);
        expect(context.steps, isEmpty);
      });
    });
  });

  group('WorkflowStepEntry', () {
    test('toYaml produces correct map with needs', () {
      const entry = WorkflowStepEntry(
        file: '01-analyze.md',
        tag: 'research',
        mandatory: true,
        needs: [0, 2], // 0-based
      );

      final yaml = entry.toYaml();

      expect(yaml['file'], '01-analyze.md');
      expect(yaml['tag'], 'research');
      expect(yaml['mandatory'], isTrue);
      expect(yaml['needs'], [1, 3]); // 1-based in output
    });

    test('toYaml omits needs when empty', () {
      const entry = WorkflowStepEntry(
        file: '01-analyze.md',
        tag: 'research',
      );

      final yaml = entry.toYaml();

      expect(yaml.containsKey('needs'), isFalse);
    });

    test('hasDependencies returns correct value', () {
      const independent = WorkflowStepEntry(
        file: '01.md',
        tag: 'research',
      );
      const dependent = WorkflowStepEntry(
        file: '02.md',
        tag: 'planning',
        needs: [0],
      );

      expect(independent.hasDependencies, isFalse);
      expect(dependent.hasDependencies, isTrue);
    });
  });
}
