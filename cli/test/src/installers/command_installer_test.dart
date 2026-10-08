import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/content/command_bundle.dart';
import 'package:somnio/src/content/command_registry.dart';
import 'package:somnio/src/installers/command_installer.dart';
import 'package:test/test.dart';

/// Walks up from the test's working directory until it finds the repo root
/// (the directory that contains the top-level `commands/` folder).
String _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (Directory(p.join(dir.path, 'commands')).existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate repo root from ${Directory.current}');
    }
    dir = parent;
  }
}

void main() {
  late Directory tmp;
  late String repoRoot;
  late CommandInstaller installer;

  setUpAll(() {
    repoRoot = _repoRoot();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('somnio_command_inst_');
    installer = CommandInstaller(repoRoot: repoRoot);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('resolveTargetDir', () {
    test('resolves the claude project commands directory', () {
      final dir =
          CommandInstaller.resolveTargetDir('claude', projectDir: tmp.path);
      expect(dir, p.join(tmp.path, '.claude', 'commands'));
    });

    test('resolves the cursor project commands directory', () {
      final dir =
          CommandInstaller.resolveTargetDir('cursor', projectDir: tmp.path);
      expect(dir, p.join(tmp.path, '.cursor', 'commands'));
    });

    test('throws for an unsupported agent', () {
      expect(
        () =>
            CommandInstaller.resolveTargetDir('unknown', projectDir: tmp.path),
        throwsArgumentError,
      );
    });
  });

  group('install', () {
    final bundle = CommandRegistry.findByName('ship')!;

    test('copies the ship command byte-for-byte into .claude/commands', () {
      final targetDir =
          CommandInstaller.resolveTargetDir('claude', projectDir: tmp.path);

      final result = installer.install(bundle, targetDir);

      expect(result.success, isTrue);
      final targetFile =
          File(p.join(tmp.path, '.claude', 'commands', 'ship.md'));
      expect(targetFile.existsSync(), isTrue);

      final sourceBytes =
          File(p.join(repoRoot, bundle.sourceRelativePath)).readAsBytesSync();
      final targetBytes = targetFile.readAsBytesSync();
      expect(targetBytes, equals(sourceBytes));
    });

    test('copies the ship command byte-for-byte into .cursor/commands', () {
      final targetDir =
          CommandInstaller.resolveTargetDir('cursor', projectDir: tmp.path);

      final result = installer.install(bundle, targetDir);

      expect(result.success, isTrue);
      final targetFile =
          File(p.join(tmp.path, '.cursor', 'commands', 'ship.md'));
      expect(targetFile.existsSync(), isTrue);

      final sourceBytes =
          File(p.join(repoRoot, bundle.sourceRelativePath)).readAsBytesSync();
      final targetBytes = targetFile.readAsBytesSync();
      expect(targetBytes, equals(sourceBytes));
    });

    test('every registered command installs byte-identically for both agents',
        () {
      for (final agentId in ['claude', 'cursor']) {
        final targetDir =
            CommandInstaller.resolveTargetDir(agentId, projectDir: tmp.path);

        for (final b in CommandRegistry.commands) {
          final result = installer.install(b, targetDir);
          expect(result.success, isTrue, reason: '$agentId/${b.name}');

          final sourceBytes =
              File(p.join(repoRoot, b.sourceRelativePath)).readAsBytesSync();
          final targetBytes =
              File(p.join(targetDir, '${b.name}.md')).readAsBytesSync();
          expect(targetBytes, equals(sourceBytes),
              reason: '$agentId/${b.name}');
        }
      }
    });

    test('fails gracefully when the source file is missing', () {
      const missingBundle = CommandBundle(
        id: 'missing',
        name: 'missing',
        displayName: 'Missing',
        description: 'Does not exist on disk.',
        sourceRelativePath: 'commands/does-not-exist.md',
      );
      final targetDir =
          CommandInstaller.resolveTargetDir('claude', projectDir: tmp.path);

      final result = installer.install(missingBundle, targetDir);

      expect(result.success, isFalse);
      expect(result.error, contains('Command file not found'));
    });
  });

  group('isInstalled', () {
    final bundle = CommandRegistry.findByName('ship')!;

    test('false before install, true after', () {
      final targetDir =
          CommandInstaller.resolveTargetDir('claude', projectDir: tmp.path);

      expect(installer.isInstalled(bundle, targetDir), isFalse);

      installer.install(bundle, targetDir);

      expect(installer.isInstalled(bundle, targetDir), isTrue);
    });
  });
}
