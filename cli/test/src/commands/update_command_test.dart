import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:somnio/src/commands/update_command.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

void main() {
  late _MockLogger logger;
  late _MockProgress progress;

  setUp(() {
    logger = _MockLogger();
    progress = _MockProgress();
    when(() => logger.progress(any())).thenReturn(progress);
  });

  Future<int?> runUpdate(String stdout, {int exitCode = 0}) {
    final runner = CommandRunner<int>('somnio', 'test')
      ..addCommand(
        UpdateCommand(
          logger: logger,
          processRunner: (executable, arguments) async =>
              ProcessResult(1, exitCode, stdout, 'boom'),
        ),
      );
    return runner.run(['update']);
  }

  test('names the installed version in the success line', () async {
    final code = await runUpdate(
      'Activated somnio 3.2.6 from Git repository "x".\n',
    );

    expect(code, ExitCode.success.code);
    verify(() => progress.complete('CLI updated to v3.2.6')).called(1);
  });

  test('falls back to CLI updated when the version is not parseable', () async {
    final code = await runUpdate('garbled');

    expect(code, ExitCode.success.code);
    verify(() => progress.complete('CLI updated')).called(1);
  });

  test('fails when the process exits non-zero', () async {
    final code = await runUpdate('', exitCode: 1);

    expect(code, ExitCode.software.code);
    verify(() => progress.fail('Failed to update CLI')).called(1);
  });
}
