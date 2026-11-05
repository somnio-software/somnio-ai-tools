import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;
  late String cli;

  setUp(() {
    project = Directory.systemTemp.createTempSync('somnio_commands_');
    cli = p.absolute('bin', 'somnio.dart');
  });
  tearDown(() => project.deleteSync(recursive: true));

  test('help points Clockify users to the skill installer', () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      [cli, 'commands', '--help'],
      workingDirectory: project.path,
    );
    expect(result.exitCode, 0);
    expect(
        result.stdout, contains('Install Clockify with somnio skills install'));
    expect(result.stdout, isNot(contains('clockify-tracker')));
  });

  test('returns failure when one requested agent install fails', () async {
    final conflict =
        Directory(p.join(project.path, '.cursor', 'commands', 'ship.md'))
          ..createSync(recursive: true);
    final result = await Process.run(
      Platform.resolvedExecutable,
      [cli, 'commands', 'install', '--all', '--commands', 'ship'],
      workingDirectory: project.path,
    );
    expect(result.exitCode, isNot(0));
    expect(
        File(p.join(project.path, '.claude', 'commands', 'ship.md'))
            .existsSync(),
        isTrue);
    expect(conflict.existsSync(), isTrue);
  });
}
