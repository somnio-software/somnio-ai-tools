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

  group('with Kimi Code on a folder that is really another agent\'s', () {
    Future<ProcessResult> setup({String path = ''}) => Process.run(
          Platform.resolvedExecutable,
          [p.absolute('bin', 'somnio.dart'), 'setup', '--skip-cli', '--force'],
          workingDirectory: home.path,
          includeParentEnvironment: false,
          environment: {
            'HOME': home.path,
            'USERPROFILE': home.path,
            // No agent binary is found, so only the folders select the agents.
            'PATH': path,
          },
        );

    /// The `model:` lines of Claude Code's copy of the security audit.
    Set<String> claudeModels() => {
          for (final file in Directory(
            p.join(home.path, '.claude', 'skills', 'security-audit', 'agents'),
          ).listSync().whereType<File>())
            for (final line in file.readAsLinesSync())
              if (line.startsWith('model:')) line,
        };

    for (final (label, link, target) in [
      (
        '~/.kimi-code/skills -> ~/.claude/skills',
        '.kimi-code/skills',
        '.claude/skills',
      ),
      (
        '~/.claude/skills -> ~/.kimi-code/skills',
        '.claude/skills',
        '.kimi-code/skills',
      ),
    ]) {
      test('leaves $label to Claude Code and reports it', () async {
        final real = p.join(home.path, target);
        File(p.join(real, 'mine', 'SKILL.md')).createSync(recursive: true);
        Link(p.join(home.path, link)).createSync(real, recursive: true);

        final result = await setup();

        expect(result.exitCode, 0, reason: '${result.stdout}');
        expect(
          claudeModels(),
          everyElement(isNot(contains(RegExp('cheap|mid|frontier')))),
        );
        expect(claudeModels(), isNotEmpty);
        expect(
          '${result.stdout}${result.stderr}',
          contains('Kimi Code: skipped,'),
        );
      }, timeout: const Timeout.factor(2));
    }

    test('leaves ~/.cursor/commands to Cursor', () async {
      final commands = p.join(home.path, '.cursor', 'commands');
      File(p.join(commands, 'mine.md')).createSync(recursive: true);
      Link(p.join(home.path, '.kimi-code', 'skills'))
          .createSync(commands, recursive: true);

      final result = await setup();

      expect(result.exitCode, 0, reason: '${result.stdout}');
      expect(
        Directory(p.join(commands, 'security-audit')).existsSync(),
        isFalse,
      );
      expect(
        '${result.stdout}${result.stderr}',
        contains("really Cursor's folder"),
      );
    }, timeout: const Timeout.factor(2));

    test('exits 0 with the report when Kimi Code was the only agent', () async {
      final claude = p.join(home.path, '.claude', 'skills');
      Directory(claude).createSync(recursive: true);
      Link(p.join(home.path, '.kimi-code', 'skills'))
          .createSync(claude, recursive: true);
      final stub = File(p.join(home.path, 'bin', 'kimi'))
        ..createSync(recursive: true)
        ..writeAsStringSync('#!/bin/sh\n');
      Process.runSync('chmod', ['+x', stub.path]);

      final result = await setup(path: '${stub.parent.path}:/usr/bin:/bin');

      expect(result.exitCode, 0, reason: '${result.stdout}');
      expect(
        '${result.stdout}${result.stderr}',
        contains('Kimi Code: skipped,'),
      );
      expect(Directory(claude).listSync(), isEmpty);
    });

    test('installs into ~/dotfiles/skills, which no other agent uses',
        () async {
      final dotfiles = p.join(home.path, 'dotfiles', 'skills');
      File(p.join(dotfiles, 'mine', 'SKILL.md')).createSync(recursive: true);
      Link(p.join(home.path, '.kimi-code', 'skills'))
          .createSync(dotfiles, recursive: true);

      final result = await setup();

      expect(result.exitCode, 0, reason: '${result.stdout}');
      expect(SkillManifest.load(dotfiles).skillNames, isNotEmpty);
      expect('${result.stdout}${result.stderr}', isNot(contains('is really')));
    }, timeout: const Timeout.factor(2));
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
