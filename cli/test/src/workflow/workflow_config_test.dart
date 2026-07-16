import 'dart:io';

import 'package:somnio/src/workflow/workflow_config.dart';
import 'package:test/test.dart';

void main() {
  group('WorkflowConfig', () {
    group('fromJson', () {
      test('parses full config with by_role and by_step', () {
        final json = {
          'ide': 'claudecode',
          'model_assignments': {
            'by_role': {
              'research': 'haiku',
              'planning': 'opus',
              'execution': 'sonnet',
            },
            'by_step': {
              '3': 'opus',
              '4': 'haiku',
            },
          },
        };

        final config = WorkflowConfig.fromJson(json);

        expect(config.ide, 'claudecode');
        expect(config.byRole['research'], 'haiku');
        expect(config.byRole['planning'], 'opus');
        expect(config.byRole['execution'], 'sonnet');
        expect(config.byStep[3], 'opus');
        expect(config.byStep[4], 'haiku');
      });

      test('parses config with only by_role', () {
        final json = {
          'ide': 'cursor',
          'model_assignments': {
            'by_role': {'research': 'haiku'},
          },
        };

        final config = WorkflowConfig.fromJson(json);

        expect(config.ide, 'cursor');
        expect(config.byRole['research'], 'haiku');
        expect(config.byStep, isEmpty);
      });

      test('handles missing model_assignments', () {
        final json = {'ide': 'gemini'};

        final config = WorkflowConfig.fromJson(json);

        expect(config.ide, 'gemini');
        expect(config.byRole, isEmpty);
        expect(config.byStep, isEmpty);
      });

      test('handles empty JSON', () {
        final config = WorkflowConfig.fromJson({});

        expect(config.ide, '');
        expect(config.byRole, isEmpty);
        expect(config.byStep, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes full config', () {
        const config = WorkflowConfig(
          ide: 'claudecode',
          byRole: {'research': 'haiku', 'execution': 'sonnet'},
          byStep: {3: 'opus'},
        );

        final json = config.toJson();

        expect(json['ide'], 'claudecode');
        final assignments = json['model_assignments'] as Map;
        expect(assignments['by_role'], {'research': 'haiku', 'execution': 'sonnet'});
        expect(assignments['by_step'], {'3': 'opus'});
      });

      test('omits by_step when empty', () {
        const config = WorkflowConfig(
          ide: 'cursor',
          byRole: {'research': 'haiku'},
        );

        final json = config.toJson();
        final assignments = json['model_assignments'] as Map;

        expect(assignments.containsKey('by_step'), isFalse);
      });
    });

    group('resolveModel', () {
      test('by_step takes precedence over by_role', () {
        const config = WorkflowConfig(
          ide: 'claudecode',
          byRole: {'execution': 'sonnet'},
          byStep: {3: 'opus'},
        );

        expect(config.resolveModel(3, 'execution'), 'opus');
      });

      test('falls back to by_role when no by_step', () {
        const config = WorkflowConfig(
          ide: 'claudecode',
          byRole: {'execution': 'sonnet'},
        );

        expect(config.resolveModel(3, 'execution'), 'sonnet');
      });

      test('returns null when no mapping found', () {
        const config = WorkflowConfig(ide: 'claudecode');

        expect(config.resolveModel(1, 'research'), isNull);
      });
    });

    group('roundtrip', () {
      test('fromJson(toJson) preserves data', () {
        const original = WorkflowConfig(
          ide: 'claudecode',
          byRole: {'research': 'haiku', 'planning': 'opus', 'execution': 'sonnet'},
          byStep: {3: 'opus', 4: 'haiku'},
        );

        final roundtripped = WorkflowConfig.fromJson(original.toJson());

        expect(roundtripped.ide, original.ide);
        expect(roundtripped.byRole, original.byRole);
        expect(roundtripped.byStep, original.byStep);
      });
    });

    group('file I/O', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('workflow_config_test_');
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      test('saveTo and loadFrom roundtrip', () {
        const config = WorkflowConfig(
          ide: 'claudecode',
          byRole: {'research': 'haiku'},
          byStep: {2: 'opus'},
        );

        final path = '${tempDir.path}/config.claudecode.json';
        config.saveTo(path);

        final loaded = WorkflowConfig.loadFrom(path);

        expect(loaded, isNotNull);
        expect(loaded!.ide, 'claudecode');
        expect(loaded.byRole['research'], 'haiku');
        expect(loaded.byStep[2], 'opus');
      });

      test('loadFrom returns null for missing file', () {
        final loaded = WorkflowConfig.loadFrom('${tempDir.path}/missing.json');
        expect(loaded, isNull);
      });

      group('loadFrom returns null instead of throwing for malformed', () {
        final cases = {
          'not json': 'not json at all',
          'truncated json': '{"ide": "claudecode"',
          'top level is a list': '[1, 2, 3]',
          'top level is a scalar': '"claudecode"',
          'model_assignments is a string': '{"model_assignments": "nope"}',
          'by_role value is not a string':
              '{"model_assignments": {"by_role": {"research": 7}}}',
          'by_step key is not an int':
              '{"model_assignments": {"by_step": {"first": "opus"}}}',
        };

        cases.forEach((label, content) {
          test(label, () {
            final path = '${tempDir.path}/config.bad.json';
            File(path).writeAsStringSync(content);
            expect(WorkflowConfig.loadFrom(path), isNull);
          });
        });
      });

      test('saveTo creates parent directories', () {
        const config = WorkflowConfig(ide: 'test');
        final path = '${tempDir.path}/nested/dir/config.json';
        config.saveTo(path);

        expect(File(path).existsSync(), isTrue);
      });
    });

    group('configFileName', () {
      test('maps claude to config.claudecode.json', () {
        expect(WorkflowConfig.configFileName('claude'), 'config.claudecode.json');
      });

      test('maps cursor to config.cursor.json', () {
        expect(WorkflowConfig.configFileName('cursor'), 'config.cursor.json');
      });

      test('maps gemini to config.gemini.json', () {
        expect(WorkflowConfig.configFileName('gemini'), 'config.gemini.json');
      });

      test('maps antigravity to config.gemini.json', () {
        expect(WorkflowConfig.configFileName('antigravity'), 'config.gemini.json');
      });

      test('generates generic name for unknown agent', () {
        expect(WorkflowConfig.configFileName('aider'), 'config.aider.json');
      });
    });
  });
}
