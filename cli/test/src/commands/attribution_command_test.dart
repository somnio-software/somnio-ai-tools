import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:somnio/src/commands/attribution_command.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  late Directory tmpDir;
  late String settingsPath;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('attribution_command_test_');
    settingsPath = p.join(tmpDir.path, '.claude', 'settings.json');
  });

  tearDown(() => tmpDir.deleteSync(recursive: true));

  Map<String, dynamic> readSettings() =>
      jsonDecode(File(settingsPath).readAsStringSync()) as Map<String, dynamic>;

  void writeSettings(Object settings) {
    File(settingsPath)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(settings));
  }

  group('setClaudeAttribution off', () {
    test('creates settings.json with empty commit and PR attribution', () {
      final changed = setClaudeAttribution(settingsPath, enabled: false);

      expect(changed, isTrue);
      expect(readSettings()['attribution'], {'commit': '', 'pr': ''});
    });

    test('preserves existing settings keys', () {
      writeSettings({
        'env': {'FOO': 'bar'},
        'hooks': {'Stop': <Object>[]},
      });

      setClaudeAttribution(settingsPath, enabled: false);

      final settings = readSettings();
      expect(settings['env'], {'FOO': 'bar'});
      expect(settings['hooks'], {'Stop': <Object>[]});
      expect(settings['attribution'], {'commit': '', 'pr': ''});
    });

    test('replaces a custom attribution', () {
      writeSettings({
        'attribution': {'commit': 'Made with AI', 'pr': ''},
      });

      final changed = setClaudeAttribution(settingsPath, enabled: false);

      expect(changed, isTrue);
      expect(readSettings()['attribution'], {'commit': '', 'pr': ''});
    });

    test('is idempotent', () {
      setClaudeAttribution(settingsPath, enabled: false);
      final before = File(settingsPath).readAsStringSync();

      final changed = setClaudeAttribution(settingsPath, enabled: false);

      expect(changed, isFalse);
      expect(File(settingsPath).readAsStringSync(), before);
    });

    test('treats an empty settings file as empty settings', () {
      File(settingsPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('');

      setClaudeAttribution(settingsPath, enabled: false);

      expect(readSettings(), {
        'attribution': {'commit': '', 'pr': ''},
      });
    });

    test('throws and leaves a malformed settings file untouched', () {
      File(settingsPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('{ not json');

      expect(
        () => setClaudeAttribution(settingsPath, enabled: false),
        throwsFormatException,
      );
      expect(File(settingsPath).readAsStringSync(), '{ not json');
    });

    test('throws when settings.json is not a JSON object', () {
      writeSettings(<Object>[]);

      expect(
        () => setClaudeAttribution(settingsPath, enabled: false),
        throwsFormatException,
      );
      expect(File(settingsPath).readAsStringSync(), '[]');
    });
  });

  group('setClaudeAttribution on', () {
    test('removes the attribution key and keeps the rest', () {
      writeSettings({
        'tui': 'fullscreen',
        'attribution': {'commit': '', 'pr': ''},
      });

      final changed = setClaudeAttribution(settingsPath, enabled: true);

      expect(changed, isTrue);
      expect(readSettings(), {'tui': 'fullscreen'});
    });

    test('does nothing when attribution is already the default', () {
      final changed = setClaudeAttribution(settingsPath, enabled: true);

      expect(changed, isFalse);
      expect(File(settingsPath).existsSync(), isFalse);
    });
  });

  group('readClaudeAttribution', () {
    test('is enabled when settings.json does not exist', () {
      expect(
        readClaudeAttribution(settingsPath),
        ClaudeAttributionState.enabled,
      );
    });

    test('is disabled when commit and PR attribution are empty', () {
      writeSettings({
        'attribution': {'commit': '', 'pr': ''},
      });

      expect(
        readClaudeAttribution(settingsPath),
        ClaudeAttributionState.disabled,
      );
    });

    test('is custom when only one side is empty', () {
      writeSettings({
        'attribution': {'commit': '', 'pr': 'Made with AI'},
      });

      expect(
        readClaudeAttribution(settingsPath),
        ClaudeAttributionState.custom,
      );
    });
  });

  group('AttributionCommand', () {
    late _MockLogger logger;
    late CommandRunner<int> runner;

    setUp(() {
      logger = _MockLogger();
      runner = CommandRunner<int>('somnio', 'test')
        ..addCommand(
          AttributionCommand(logger: logger, settingsPath: () => settingsPath),
        );
    });

    test('off turns attribution off and reports the change', () async {
      final exitCode = await runner.run(['attribution', 'off']);

      expect(exitCode, ExitCode.success.code);
      expect(readSettings()['attribution'], {'commit': '', 'pr': ''});
      verify(() => logger.success('Claude Code attribution turned off.'))
          .called(1);
    });

    test('off reports when attribution is already off', () async {
      writeSettings({
        'attribution': {'commit': '', 'pr': ''},
      });

      final exitCode = await runner.run(['attribution', 'off']);

      expect(exitCode, ExitCode.success.code);
      verify(() => logger.info('Claude Code attribution is already off.'))
          .called(1);
      verifyNever(() => logger.success(any()));
    });

    test('on restores the default attribution', () async {
      writeSettings({
        'attribution': {'commit': '', 'pr': ''},
      });

      final exitCode = await runner.run(['attribution', 'on']);

      expect(exitCode, ExitCode.success.code);
      expect(readSettings(), isEmpty);
      verify(() => logger.success('Claude Code attribution turned on.'))
          .called(1);
    });

    test('off fails with a config error on malformed settings', () async {
      File(settingsPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('{ not json');

      final exitCode = await runner.run(['attribution', 'off']);

      expect(exitCode, ExitCode.config.code);
      expect(File(settingsPath).readAsStringSync(), '{ not json');
      verify(() => logger.err(any(that: contains('was not changed'))))
          .called(1);
    });

    test('status reports the default state', () async {
      final exitCode = await runner.run(['attribution', 'status']);

      expect(exitCode, ExitCode.success.code);
      verify(
        () => logger.info(any(that: contains('attribution is on (default)'))),
      ).called(1);
    });

    test('status reports the off state', () async {
      writeSettings({
        'attribution': {'commit': '', 'pr': ''},
      });

      await runner.run(['attribution', 'status']);

      verify(() => logger.info('Claude Code attribution is off.')).called(1);
    });

    test('status reports a custom attribution', () async {
      writeSettings({
        'attribution': {'commit': 'Made with AI', 'pr': ''},
      });

      await runner.run(['attribution', 'status']);

      verify(
        () => logger.info(any(that: contains('attribution is customized'))),
      ).called(1);
    });

    test('status fails with a config error on malformed settings', () async {
      File(settingsPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('{ not json');

      final exitCode = await runner.run(['attribution', 'status']);

      expect(exitCode, ExitCode.config.code);
      verify(() => logger.err(any(that: contains('Could not read')))).called(1);
    });
  });
}
