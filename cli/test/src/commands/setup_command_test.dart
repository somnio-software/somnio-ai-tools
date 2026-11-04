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

  group('with KIMI_CODE_HOME set', () {
    Future<ProcessResult> setup() => Process.run(
          Platform.resolvedExecutable,
          [p.absolute('bin', 'somnio.dart'), 'setup', '--skip-cli', '--force'],
          workingDirectory: home.path,
          includeParentEnvironment: false,
          environment: {
            'HOME': home.path,
            'USERPROFILE': home.path,
            'KIMI_CODE_HOME': p.join(home.path, 'alt'),
            // No agent binary is found, so only the folders select the agents.
            'PATH': '',
          },
        );

    test("installs into Claude Code's real folder ~/.kimi-code/skills links to",
        () async {
      final claudeSkills = p.join(home.path, '.claude', 'skills');
      File(p.join(claudeSkills, 'mine', 'SKILL.md'))
          .createSync(recursive: true);
      Link(p.join(home.path, '.kimi-code', 'skills'))
          .createSync(claudeSkills, recursive: true);

      final result = await setup();

      expect(result.exitCode, 0, reason: '${result.stdout}');
      expect(SkillManifest.load(claudeSkills).skillNames, isNotEmpty);
    }, timeout: const Timeout.factor(2));

    test('fails on a Gemini CLI folder linked to ~/.kimi-code/skills',
        () async {
      final skills = p.join(home.path, '.kimi-code', 'skills');
      File(p.join(skills, 'mine', 'SKILL.md')).createSync(recursive: true);
      Link(p.join(home.path, '.gemini', 'skills'))
          .createSync(skills, recursive: true);

      final result = await setup();

      expect(result.exitCode, 70, reason: '${result.stdout}');
      expect(
        '${result.stdout}${result.stderr}',
        contains("is really a protected folder (another profile's config)"),
      );
      expect(SkillManifest.load(skills).isEmpty, isTrue);
    }, timeout: const Timeout.factor(2));
  });
}
