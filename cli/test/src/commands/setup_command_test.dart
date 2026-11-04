import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/installers/skill_manifest.dart';
import 'package:test/test.dart';

void main() {
  late Directory home;

  setUp(() {
    home = Directory.systemTemp.createTempSync('setup_command_test_');
  });

  tearDown(() {
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  test("keeps a hand-written Kimi Code folder with a skill's name", () async {
    const name = 'git-commit-format';
    final skills = p.join(home.path, '.kimi-code', 'skills');
    final own = File(p.join(skills, name, 'SKILL.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync('mine');
    final example = File(p.join(skills, name, 'examples', 'e.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync('mine');

    final result = await Process.run(
      Platform.resolvedExecutable,
      [p.absolute('bin', 'somnio.dart'), 'setup', '--skip-cli'],
      workingDirectory: home.path,
      includeParentEnvironment: false,
      environment: {
        'HOME': home.path,
        'USERPROFILE': home.path,
        // No agent binary is found, so only the folder above selects Kimi Code.
        'PATH': '',
      },
    );

    expect('${result.stdout}${result.stderr}', contains('kept'));
    expect(own.readAsStringSync(), 'mine');
    expect(example.existsSync(), isTrue);
    final manifest = SkillManifest.load(skills);
    expect(manifest.entryFor(name), isNull);
    expect(manifest.skillNames, isNotEmpty);
  });
}
