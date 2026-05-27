import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/commands/hooks_command.dart';
import 'package:test/test.dart';

void main() {
  group('mergeStopHookIntoSettings', () {
    late Directory tmpDir;
    late String settingsPath;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('hooks_command_test_');
      settingsPath = p.join(tmpDir.path, 'settings.json');
    });

    tearDown(() => tmpDir.deleteSync(recursive: true));

    test('creates settings.json from scratch and registers the Stop hook', () {
      final registered = mergeStopHookIntoSettings(
        settingsPath,
        HooksCommand.hookCommand,
      );

      expect(registered, isFalse);

      final contents = jsonDecode(File(settingsPath).readAsStringSync())
          as Map<String, dynamic>;
      final stopList = (contents['hooks']['Stop'] as List);
      expect(stopList, hasLength(1));
      final inner = (stopList.first['hooks'] as List).first as Map;
      expect(inner['command'], HooksCommand.hookCommand);
      expect(inner['type'], 'command');
    });

    test('is idempotent — second call returns true and does not duplicate', () {
      mergeStopHookIntoSettings(settingsPath, HooksCommand.hookCommand);
      final secondCall = mergeStopHookIntoSettings(
        settingsPath,
        HooksCommand.hookCommand,
      );

      expect(secondCall, isTrue);

      final contents = jsonDecode(File(settingsPath).readAsStringSync())
          as Map<String, dynamic>;
      final stopList = contents['hooks']['Stop'] as List;
      final matchingEntries = stopList.where((entry) {
        if (entry is! Map) return false;
        final innerHooks = entry['hooks'] as List?;
        return innerHooks?.any(
              (h) => h is Map && h['command'] == HooksCommand.hookCommand,
            ) ??
            false;
      }).toList();
      expect(matchingEntries, hasLength(1));
    });

    test('preserves existing top-level settings keys', () {
      File(settingsPath).writeAsStringSync(
        jsonEncode({
          'theme': 'dark',
          'model': 'sonnet',
          'hooks': {
            'PreToolUse': [
              {
                'matcher': 'Bash',
                'hooks': [
                  {'type': 'command', 'command': 'echo pre'},
                ],
              },
            ],
          },
        }),
      );

      mergeStopHookIntoSettings(settingsPath, HooksCommand.hookCommand);

      final contents = jsonDecode(File(settingsPath).readAsStringSync())
          as Map<String, dynamic>;
      expect(contents['theme'], 'dark');
      expect(contents['model'], 'sonnet');
      expect(contents['hooks']['PreToolUse'], isNotNull);
      expect(contents['hooks']['Stop'], isNotNull);
    });

    test('backs up malformed JSON and registers the hook in a fresh file', () {
      File(settingsPath).writeAsStringSync('{ this is not valid json }');

      final warnings = <String>[];
      mergeStopHookIntoSettings(
        settingsPath,
        HooksCommand.hookCommand,
        onWarn: warnings.add,
      );

      expect(File('$settingsPath.bak').existsSync(), isTrue);
      expect(warnings, isNotEmpty);

      final contents = jsonDecode(File(settingsPath).readAsStringSync())
          as Map<String, dynamic>;
      final stopList = contents['hooks']['Stop'] as List;
      expect(stopList, hasLength(1));
    });
  });

  group('HooksCommand.hookScript drift check', () {
    test('embedded hookScript matches hooks/work-log-stop.sh logic', () {
      // Running `dart test` from the cli/ package root; the .sh file sits one
      // level up in the monorepo root.
      final hookFile = File(
        p.normalize(
          p.join(Directory.current.path, '..', 'hooks', 'work-log-stop.sh'),
        ),
      );
      expect(
        hookFile.existsSync(),
        isTrue,
        reason:
            'hooks/work-log-stop.sh not found — run tests from the cli/ directory',
      );

      final fileScript = hookFile.readAsStringSync();
      expect(
        _logicLines(HooksCommand.hookScript),
        equals(_logicLines(fileScript)),
        reason:
            'HooksCommand.hookScript has drifted from hooks/work-log-stop.sh. '
            'Update the embedded constant to match the source file.',
      );
    });
  });
}

/// Returns the non-blank, non-comment lines of a shell script (shebang kept),
/// with trailing whitespace stripped. Used to compare logic while ignoring
/// comment-only differences between the source .sh file and the embedded
/// Dart constant.
List<String> _logicLines(String script) {
  return script
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) {
        if (l.isEmpty) return false;
        if (l.startsWith('#!/')) return true; // keep shebang
        if (l.trimLeft().startsWith('#')) return false; // drop comments
        return true;
      })
      .toList();
}
