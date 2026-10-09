import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:somnio/src/commands/skills_command.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  group('SkillsUpdateSummary', () {
    late _MockLogger logger;
    late List<String> lines;

    setUp(() {
      logger = _MockLogger();
      lines = [];
      when(() => logger.info(any())).thenAnswer((invocation) {
        lines.add(invocation.positionalArguments.first as String);
      });
    });

    test('lists unique names sorted across locations', () {
      final summary = SkillsUpdateSummary()
        ..addLocation(
          label: 'Claude Code (global)',
          updated: ['security-audit', 'git-commit-format'],
          failed: [],
        )
        ..addLocation(
          label: 'Cursor (project)',
          updated: ['git-commit-format', 'angular-health-audit'],
          failed: [],
        );

      summary.print(logger);

      expect(lines, [
        '',
        'Updated skills (3):',
        '  - angular-health-audit',
        '  - git-commit-format',
        '  - security-audit',
      ]);
    });

    test('lists failed skills with their location', () {
      final summary = SkillsUpdateSummary()
        ..addLocation(
          label: 'Claude Code (global)',
          updated: ['security-audit'],
          failed: ['dora-metrics'],
        );

      summary.print(logger);

      expect(lines, [
        '',
        'Updated skills (1):',
        '  - security-audit',
        '',
        'Failed skills:',
        '  - dora-metrics — Claude Code (global)',
      ]);
    });

    test('prints the failures even when nothing was updated', () {
      final summary = SkillsUpdateSummary()
        ..addLocation(
          label: 'Claude Code (global)',
          updated: [],
          failed: ['dora-metrics'],
        );

      summary.print(logger);

      expect(lines,
          ['', 'Failed skills:', '  - dora-metrics — Claude Code (global)']);
    });

    test('prints nothing when there is nothing to report', () {
      SkillsUpdateSummary().print(logger);

      expect(lines, isEmpty);
    });
  });

  group('somnio skills update (process)', () {
    late Directory home;
    late String workDir;

    setUp(() {
      home = Directory.systemTemp.createTempSync('skills_update_test_');
      workDir = p.join(home.path, 'project');
      Directory(workDir).createSync(recursive: true);
    });

    tearDown(() {
      // Restore write access so cleanup can delete locked fixtures.
      final locked = Directory(
        p.join(home.path, '.claude', 'skills', 'git-commit-format'),
      );
      if (locked.existsSync()) {
        Process.runSync('chmod', ['-R', 'u+w', locked.path]);
      }
      if (home.existsSync()) home.deleteSync(recursive: true);
    });

    void seedManifest(Map<String, String> skillKinds) {
      final dir = Directory(p.join(home.path, '.claude', 'skills'))
        ..createSync(recursive: true);
      File(p.join(dir.path, '.somnio-skills.json')).writeAsStringSync(
        jsonEncode({
          'version': 1,
          'skills': {
            for (final e in skillKinds.entries)
              e.key: {
                'kind': e.value,
                'paths': [
                  {'root': 'install', 'path': e.key},
                ],
              },
          },
        }),
      );
    }

    Future<ProcessResult> runUpdate(List<String> args) => Process.run(
          Platform.resolvedExecutable,
          [
            p.absolute('bin', 'somnio.dart'),
            'skills',
            'update',
            '--agent',
            'claude',
            ...args,
          ],
          workingDirectory: workDir,
          environment: {
            'HOME': home.path,
            'USERPROFILE': home.path,
            // Keep pub reading the real cache instead of creating one under
            // the fake home.
            'PUB_CACHE': _pubCache,
          },
        );

    test('prints the updated skill names after the progress lines', () async {
      seedManifest({
        'security-audit': 'audit',
        'git-commit-format': 'workflow',
      });

      final result = await runUpdate([]);

      expect(result.exitCode, 0);
      expect(
        result.stdout,
        contains(
          'Updated skills (2):\n  - git-commit-format\n  - security-audit',
        ),
      );
      expect(result.stdout, contains('2 skills updated'));
    });

    test('--verbose lists the updated names under the Location line', () async {
      seedManifest({'git-commit-format': 'workflow'});

      final result = await runUpdate(['--verbose']);

      expect(
        result.stdout,
        matches(RegExp(r'Location: .*\n    - git-commit-format\n')),
      );
    });

    test('omits per-location names without --verbose', () async {
      seedManifest({'git-commit-format': 'workflow'});

      final result = await runUpdate([]);

      expect(result.stdout, isNot(contains('    - git-commit-format')));
    });

    test('prints no summary when nothing is installed', () async {
      final result = await runUpdate([]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No somnio-installed skills found.'));
      expect(result.stdout, isNot(contains('Updated skills')));
    });

    test('prints no summary in --dry-run', () async {
      seedManifest({'git-commit-format': 'workflow'});

      final result = await runUpdate(['--dry-run']);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('Would refresh:'));
      expect(result.stdout, isNot(contains('Updated skills')));
    });

    test(
      'lists a failed skill with its location and exits non-zero',
      () async {
        seedManifest({'git-commit-format': 'workflow'});
        // A read-only skill directory makes the prune before the rewrite fail.
        final skillDir = Directory(
          p.join(home.path, '.claude', 'skills', 'git-commit-format'),
        )..createSync(recursive: true);
        File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('old');
        Process.runSync('chmod', ['-R', 'a-w', skillDir.path]);

        final result = await runUpdate([]);

        expect(result.exitCode, isNot(0));
        expect(
          result.stdout,
          contains(
              'Failed skills:\n  - git-commit-format — Claude Code (global)'),
        );
      },
      skip: Platform.isWindows || _isRoot()
          ? 'needs POSIX permissions and a non-root user'
          : false,
    );
  });
}

final String _pubCache = Platform.environment['PUB_CACHE'] ??
    p.join(
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '',
      '.pub-cache',
    );

bool _isRoot() =>
    !Platform.isWindows &&
    (Process.runSync('id', ['-u']).stdout as String).trim() == '0';
