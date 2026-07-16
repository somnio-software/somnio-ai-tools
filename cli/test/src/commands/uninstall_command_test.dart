import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/commands/uninstall_command.dart';
import 'package:test/test.dart';

/// Creates [path] with [contents], including any missing parent directories.
void _writeFile(String path, [String contents = 'x']) {
  Directory(p.dirname(path)).createSync(recursive: true);
  File(path).writeAsStringSync(contents);
}

void main() {
  group('removeAgentInstalls', () {
    late Directory home;

    setUp(() {
      home = Directory.systemTemp.createTempSync('uninstall_command_test_');
    });

    tearDown(() {
      if (home.existsSync()) home.deleteSync(recursive: true);
    });

    test('removes Cursor execution rules, not just its commands', () {
      _writeFile(p.join(home.path, '.cursor', 'commands', 'security-audit.md'));
      _writeFile(
        p.join(home.path, '.cursor', 'somnio_rules', 'flutter', 'rules.md'),
      );

      removeAgentInstalls(home: home.path);

      expect(
        Directory(p.join(home.path, '.cursor', 'somnio_rules')).existsSync(),
        isFalse,
        reason: '~/.cursor/somnio_rules must not survive an uninstall',
      );
      expect(
        File(p.join(home.path, '.cursor', 'commands', 'security-audit.md'))
            .existsSync(),
        isFalse,
      );
    });

    test('removes Claude skills that exist in the registry', () {
      // Registry skills absent from the old hardcoded _allSkillNames list.
      for (final name in const [
        'python-health-audit',
        'python-best-practices',
        'dart-model-from-json',
        'optimize-claude-config',
      ]) {
        _writeFile(p.join(home.path, '.claude', 'skills', name, 'SKILL.md'));
      }

      removeAgentInstalls(home: home.path);

      for (final name in const [
        'python-health-audit',
        'python-best-practices',
        'dart-model-from-json',
        'optimize-claude-config',
      ]) {
        expect(
          Directory(p.join(home.path, '.claude', 'skills', name)).existsSync(),
          isFalse,
          reason: '$name is in SkillRegistry and must be uninstalled',
        );
      }
    });

    test('removes legacy v1.x Claude skills including somnio-rh/somnio-rp', () {
      for (final name in const ['somnio-fh', 'somnio-rh', 'somnio-rp']) {
        _writeFile(p.join(home.path, '.claude', 'skills', name, 'SKILL.md'));
      }

      removeAgentInstalls(home: home.path);

      for (final name in const ['somnio-fh', 'somnio-rh', 'somnio-rp']) {
        expect(
          Directory(p.join(home.path, '.claude', 'skills', name)).existsSync(),
          isFalse,
          reason: '$name is a legacy name and must still be cleaned up',
        );
      }
    });

    test('removes Claude symlinks left by the skills.sh installer', () {
      final target = Directory(p.join(home.path, 'src', 'security-audit'))
        ..createSync(recursive: true);
      final skillsDir = Directory(p.join(home.path, '.claude', 'skills'))
        ..createSync(recursive: true);
      Link(p.join(skillsDir.path, 'security-audit')).createSync(target.path);

      removeAgentInstalls(home: home.path);

      expect(
        Link(p.join(skillsDir.path, 'security-audit')).existsSync(),
        isFalse,
      );
      expect(target.existsSync(), isTrue, reason: 'symlink target is not ours');
    });

    test('removes skills from the skills.sh canonical ~/.agents/skills', () {
      _writeFile(
        p.join(home.path, '.agents', 'skills', 'security-audit', 'SKILL.md'),
      );

      removeAgentInstalls(home: home.path);

      expect(
        Directory(p.join(home.path, '.agents', 'skills', 'security-audit'))
            .existsSync(),
        isFalse,
      );
    });

    test('removes Antigravity workflows nested under global_workflows/', () {
      _writeFile(
        p.join(home.path, '.gemini', 'antigravity', 'global_workflows',
            'somnio_flutter_health.md'),
      );
      _writeFile(
        p.join(home.path, '.gemini', 'antigravity', 'somnio_rules', 'r.md'),
      );

      removeAgentInstalls(home: home.path);

      expect(
        File(p.join(home.path, '.gemini', 'antigravity', 'global_workflows',
                'somnio_flutter_health.md'))
            .existsSync(),
        isFalse,
      );
      expect(
        Directory(p.join(home.path, '.gemini', 'antigravity', 'somnio_rules'))
            .existsSync(),
        isFalse,
      );
    });

    test('removes Gemini skills and its execution rules', () {
      _writeFile(
        p.join(home.path, '.gemini', 'skills', 'security_audit.md'),
      );
      _writeFile(p.join(home.path, '.gemini', 'somnio_rules', 'r.md'));

      removeAgentInstalls(home: home.path);

      expect(
        File(p.join(home.path, '.gemini', 'skills', 'security_audit.md'))
            .existsSync(),
        isFalse,
      );
      expect(
        Directory(p.join(home.path, '.gemini', 'somnio_rules')).existsSync(),
        isFalse,
      );
    });

    test('leaves files somnio did not install untouched', () {
      final userFiles = [
        p.join(home.path, '.claude', 'skills', 'my-own-skill', 'SKILL.md'),
        p.join(home.path, '.cursor', 'commands', 'my-command.md'),
        p.join(home.path, '.gemini', 'skills', 'my_notes.md'),
        p.join(home.path, '.agents', 'skills', 'unrelated', 'SKILL.md'),
      ];
      for (final f in userFiles) {
        _writeFile(f, 'user content');
      }

      removeAgentInstalls(home: home.path);

      for (final f in userFiles) {
        expect(
          File(f).existsSync(),
          isTrue,
          reason: 'uninstall must never delete user-authored $f',
        );
      }
    });

    test('reports whether anything was removed', () {
      expect(
        removeAgentInstalls(home: home.path),
        isFalse,
        reason: 'nothing installed under an empty home',
      );

      _writeFile(
        p.join(home.path, '.claude', 'skills', 'security-audit', 'SKILL.md'),
      );

      expect(removeAgentInstalls(home: home.path), isTrue);
    });
  });
}
