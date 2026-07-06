import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/content/agent_rule.dart';
import 'package:somnio/src/installers/rules_installer.dart';
import 'package:test/test.dart';

const _beginMarker =
    '<!-- BEGIN SOMNIO RULES — do not edit this block manually -->';
const _endMarker = '<!-- END SOMNIO RULES -->';

/// Writes [content] to `<root>/<relativePath>`, creating parents.
void _writeFile(String root, String relativePath, String content) {
  final file = File(p.join(root, relativePath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

void main() {
  late Directory tmp;
  late String repoRoot;
  late RulesInstaller installer;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('somnio_rules_inst_');
    repoRoot = tmp.path;
    installer = RulesInstaller(repoRoot: repoRoot);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  // ---------------------------------------------------------------------------
  // install() — dispatch + try/catch
  // ---------------------------------------------------------------------------
  group('install', () {
    test('returns failure when stacks is empty', () {
      const rule = AgentRule(
        agentId: 'cursor',
        displayName: 'Cursor',
        adapterPath: 'adapters/cursor',
        projectPath: '.cursorrules',
        format: RulesInstallFormat.singleFile,
      );

      final result = installer.install(rule, p.join(tmp.path, '.cursorrules'),
          const <String>[]);

      expect(result.success, isFalse);
      expect(result.error, contains('No stacks selected'));
      expect(result.agentId, 'cursor');
      expect(result.displayName, 'Cursor');
    });

    test('returns failure (caught) when adapter file is missing', () {
      const rule = AgentRule(
        agentId: 'cursor',
        displayName: 'Cursor',
        adapterPath: 'adapters/cursor',
        projectPath: '.cursorrules',
        format: RulesInstallFormat.singleFile,
      );

      final result = installer.install(
        rule,
        p.join(tmp.path, '.cursorrules'),
        const ['flutter'],
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Adapter file not found'));
    });
  });

  // ---------------------------------------------------------------------------
  // _installSingleFile
  // ---------------------------------------------------------------------------
  group('singleFile format', () {
    const rule = AgentRule(
      agentId: 'cursor',
      displayName: 'Cursor',
      adapterPath: 'adapters/cursor',
      projectPath: '.cursorrules',
      format: RulesInstallFormat.singleFile,
    );

    test('concatenates per-stack fragments wrapped in markers', () {
      _writeFile(repoRoot, 'adapters/cursor/flutter/.cursorrules', 'FLUTTER\n');
      _writeFile(repoRoot, 'adapters/cursor/nestjs/.cursorrules', 'NESTJS\n');
      final target = p.join(tmp.path, 'out', '.cursorrules');

      final result =
          installer.install(rule, target, const ['flutter', 'nestjs']);

      expect(result.success, isTrue);
      final written = File(target).readAsStringSync();
      expect(written, contains(_beginMarker));
      expect(written, contains(_endMarker));
      expect(written, contains('FLUTTER'));
      expect(written, contains('NESTJS'));
    });

    test('throws (failure) when a stack adapter file is absent', () {
      _writeFile(repoRoot, 'adapters/cursor/flutter/.cursorrules', 'FLUTTER\n');
      final target = p.join(tmp.path, 'out', '.cursorrules');

      final result =
          installer.install(rule, target, const ['flutter', 'nestjs']);

      expect(result.success, isFalse);
      expect(result.error, contains('Adapter file not found'));
    });

    test('reads source fragment from adapterFileName when it differs from '
        'the target basename (Codex: system-prompt.md -> AGENTS.md)', () {
      const codexRule = AgentRule(
        agentId: 'codex',
        displayName: 'OpenAI Codex',
        adapterPath: 'adapters/codex',
        projectPath: 'AGENTS.md',
        adapterFileName: 'system-prompt.md',
        format: RulesInstallFormat.singleFile,
      );
      _writeFile(repoRoot, 'adapters/codex/flutter/system-prompt.md', 'FLUTTER\n');
      final target = p.join(tmp.path, 'out', 'AGENTS.md');

      final result = installer.install(codexRule, target, const ['flutter']);

      expect(result.success, isTrue);
      final written = File(target).readAsStringSync();
      expect(written, contains(_beginMarker));
      expect(written, contains('FLUTTER'));
    });
  });

  // ---------------------------------------------------------------------------
  // _installDirectory
  // ---------------------------------------------------------------------------
  group('directory format', () {
    const rule = AgentRule(
      agentId: 'windsurf',
      displayName: 'Windsurf',
      adapterPath: 'adapters/windsurf',
      projectPath: '.windsurf/rules',
      format: RulesInstallFormat.directory,
    );

    test('copies files into <stack>/ with somnio- prefix', () {
      _writeFile(repoRoot, 'adapters/windsurf/flutter/architecture.md', 'arch');
      _writeFile(
          repoRoot, 'adapters/windsurf/flutter/nested/testing.md', 'test');
      final target = p.join(tmp.path, '.windsurf', 'rules');

      final result = installer.install(rule, target, const ['flutter']);

      expect(result.success, isTrue);
      expect(
        File(p.join(target, 'flutter', 'somnio-architecture.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(target, 'flutter', 'nested', 'somnio-testing.md'))
            .existsSync(),
        isTrue,
      );
    });

    test('does not double-prefix files already starting with somnio-', () {
      _writeFile(
          repoRoot, 'adapters/windsurf/react/somnio-existing.md', 'content');
      final target = p.join(tmp.path, '.windsurf', 'rules');

      installer.install(rule, target, const ['react']);

      expect(
        File(p.join(target, 'react', 'somnio-existing.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(target, 'react', 'somnio-somnio-existing.md')).existsSync(),
        isFalse,
      );
    });

    test('clears previously installed somnio files but keeps user files', () {
      _writeFile(repoRoot, 'adapters/windsurf/flutter/new.md', 'new');
      final target = p.join(tmp.path, '.windsurf', 'rules');
      // Pre-existing files in the stack target dir.
      _writeFile(target, 'flutter/somnio-old.md', 'old');
      _writeFile(target, 'flutter/user-authored.md', 'keep');

      installer.install(rule, target, const ['flutter']);

      expect(File(p.join(target, 'flutter', 'somnio-old.md')).existsSync(),
          isFalse);
      expect(File(p.join(target, 'flutter', 'user-authored.md')).existsSync(),
          isTrue);
      expect(File(p.join(target, 'flutter', 'somnio-new.md')).existsSync(),
          isTrue);
    });

    test('throws (failure) when adapter directory is absent', () {
      final target = p.join(tmp.path, '.windsurf', 'rules');

      final result = installer.install(rule, target, const ['flutter']);

      expect(result.success, isFalse);
      expect(result.error, contains('Adapter directory not found'));
    });
  });

  // ---------------------------------------------------------------------------
  // _installClaudeModular
  // ---------------------------------------------------------------------------
  group('claudeModular format', () {
    const rule = AgentRule(
      agentId: 'claude',
      displayName: 'Claude Code',
      adapterPath: 'adapters/claude',
      projectPath: 'CLAUDE.md',
      format: RulesInstallFormat.claudeModular,
    );

    void seedStack(String stack) {
      _writeFile(repoRoot, 'adapters/claude/$stack/CLAUDE.md',
          '@import $stack rules');
      _writeFile(
          repoRoot, 'adapters/claude/$stack/rules/core.md', '$stack core');
    }

    test('writes CLAUDE.md block and .claude/rules/<stack>/ tree', () {
      seedStack('flutter');
      final projectDir = Directory(p.join(tmp.path, 'proj'))
        ..createSync(recursive: true);
      final target = p.join(projectDir.path, 'CLAUDE.md');

      final result = installer.install(rule, target, const ['flutter']);

      expect(result.success, isTrue);
      final claudeMd = File(target).readAsStringSync();
      expect(claudeMd, contains(_beginMarker));
      expect(claudeMd, contains('@import flutter rules'));
      expect(
        File(p.join(projectDir.path, '.claude', 'rules', 'flutter', 'core.md'))
            .existsSync(),
        isTrue,
      );
    });

    test('deletes an existing stack rules dir before re-copying', () {
      seedStack('react');
      final projectDir = Directory(p.join(tmp.path, 'proj'))
        ..createSync(recursive: true);
      final target = p.join(projectDir.path, 'CLAUDE.md');
      // Pre-existing stale file under .claude/rules/react/
      _writeFile(projectDir.path, '.claude/rules/react/stale.md', 'stale');

      installer.install(rule, target, const ['react']);

      expect(
        File(p.join(projectDir.path, '.claude', 'rules', 'react', 'stale.md'))
            .existsSync(),
        isFalse,
      );
      expect(
        File(p.join(projectDir.path, '.claude', 'rules', 'react', 'core.md'))
            .existsSync(),
        isTrue,
      );
    });

    test('throws (failure) when CLAUDE.md fragment is absent', () {
      final projectDir = Directory(p.join(tmp.path, 'proj'))
        ..createSync(recursive: true);
      final target = p.join(projectDir.path, 'CLAUDE.md');

      final result = installer.install(rule, target, const ['flutter']);

      expect(result.success, isFalse);
      expect(result.error, contains('Adapter fragment not found'));
    });

    test('throws (failure) when rules directory is absent', () {
      _writeFile(
          repoRoot, 'adapters/claude/flutter/CLAUDE.md', '@import flutter');
      // No rules/ subdir created.
      final projectDir = Directory(p.join(tmp.path, 'proj'))
        ..createSync(recursive: true);
      final target = p.join(projectDir.path, 'CLAUDE.md');

      final result = installer.install(rule, target, const ['flutter']);

      expect(result.success, isFalse);
      expect(result.error, contains('Rules directory not found'));
    });
  });

  // ---------------------------------------------------------------------------
  // _writeBlock / _replaceOrAppendBlock (via singleFile install)
  // ---------------------------------------------------------------------------
  group('block writing', () {
    const rule = AgentRule(
      agentId: 'cursor',
      displayName: 'Cursor',
      adapterPath: 'adapters/cursor',
      projectPath: '.cursorrules',
      format: RulesInstallFormat.singleFile,
    );

    setUp(() {
      _writeFile(repoRoot, 'adapters/cursor/flutter/.cursorrules', 'BODY\n');
    });

    test('creates a new file with trailing newline', () {
      final target = p.join(tmp.path, 'out', '.cursorrules');

      installer.install(rule, target, const ['flutter']);

      final content = File(target).readAsStringSync();
      expect(content.endsWith('\n'), isTrue);
      expect(content, contains('BODY'));
    });

    test('replaces existing somnio block in place, preserving surroundings',
        () {
      final target = p.join(tmp.path, 'out', '.cursorrules');
      File(target)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          'HEADER\n$_beginMarker\nOLD\n$_endMarker\nFOOTER\n',
        );

      installer.install(rule, target, const ['flutter']);

      final content = File(target).readAsStringSync();
      expect(content, contains('HEADER'));
      expect(content, contains('FOOTER'));
      expect(content, contains('BODY'));
      expect(content, isNot(contains('OLD')));
    });

    test('appends a block when none exists and file ends with newline', () {
      final target = p.join(tmp.path, 'out', '.cursorrules');
      File(target)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('EXISTING CONTENT\n');

      installer.install(rule, target, const ['flutter']);

      final content = File(target).readAsStringSync();
      expect(content, startsWith('EXISTING CONTENT'));
      expect(content, contains(_beginMarker));
      expect(content, contains('BODY'));
    });

    test('appends a block with extra separator when file lacks trailing newline',
        () {
      final target = p.join(tmp.path, 'out', '.cursorrules');
      File(target)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('NO TRAILING NEWLINE');

      installer.install(rule, target, const ['flutter']);

      final content = File(target).readAsStringSync();
      expect(content, contains('NO TRAILING NEWLINE\n\n$_beginMarker'));
    });
  });

  // ---------------------------------------------------------------------------
  // isInstalled
  // ---------------------------------------------------------------------------
  group('isInstalled', () {
    test('singleFile: true when file contains begin marker', () {
      const rule = AgentRule(
        agentId: 'cursor',
        displayName: 'Cursor',
        adapterPath: 'adapters/cursor',
        projectPath: '.cursorrules',
        format: RulesInstallFormat.singleFile,
      );
      final target = p.join(tmp.path, '.cursorrules');

      expect(installer.isInstalled(rule, target), isFalse);

      File(target).writeAsStringSync('$_beginMarker\nx\n$_endMarker\n');
      expect(installer.isInstalled(rule, target), isTrue);

      File(target).writeAsStringSync('no markers here');
      expect(installer.isInstalled(rule, target), isFalse);
    });

    test('claudeModular: true when CLAUDE.md contains begin marker', () {
      const rule = AgentRule(
        agentId: 'claude',
        displayName: 'Claude Code',
        adapterPath: 'adapters/claude',
        projectPath: 'CLAUDE.md',
        format: RulesInstallFormat.claudeModular,
      );
      final target = p.join(tmp.path, 'CLAUDE.md');

      expect(installer.isInstalled(rule, target), isFalse);
      File(target).writeAsStringSync('$_beginMarker\n$_endMarker');
      expect(installer.isInstalled(rule, target), isTrue);
    });

    test('directory: true when a somnio-prefixed file exists', () {
      const rule = AgentRule(
        agentId: 'windsurf',
        displayName: 'Windsurf',
        adapterPath: 'adapters/windsurf',
        projectPath: '.windsurf/rules',
        format: RulesInstallFormat.directory,
      );
      final target = p.join(tmp.path, '.windsurf', 'rules');

      expect(installer.isInstalled(rule, target), isFalse);

      Directory(target).createSync(recursive: true);
      _writeFile(target, 'flutter/other.md', 'x');
      expect(installer.isInstalled(rule, target), isFalse);

      _writeFile(target, 'flutter/somnio-rule.md', 'x');
      expect(installer.isInstalled(rule, target), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // resolveTargetPath
  // ---------------------------------------------------------------------------
  group('resolveTargetPath', () {
    const globalRule = AgentRule(
      agentId: 'cursor',
      displayName: 'Cursor',
      adapterPath: 'adapters/cursor',
      projectPath: '.cursorrules',
      format: RulesInstallFormat.singleFile,
      globalPath: '{home}/.config/cursor/rules',
    );

    test('global scope resolves {home} placeholder', () {
      final resolved = RulesInstaller.resolveTargetPath(
        globalRule,
        RulesInstallScope.global,
      );

      expect(resolved, endsWith('/.config/cursor/rules'));
      expect(resolved, isNot(contains('{home}')));
    });

    test('project scope joins projectDir with projectPath', () {
      final resolved = RulesInstaller.resolveTargetPath(
        globalRule,
        RulesInstallScope.project,
        projectDir: '/some/project',
      );

      expect(resolved, p.join('/some/project', '.cursorrules'));
    });

    test('project scope falls back to current directory', () {
      final resolved = RulesInstaller.resolveTargetPath(
        globalRule,
        RulesInstallScope.project,
      );

      expect(resolved, endsWith('.cursorrules'));
      expect(resolved, contains(Directory.current.path));
    });
  });
}
