import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/content/command_registry.dart';
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
  group('CommandRegistry.commands', () {
    test('includes the expected command names', () {
      final names = CommandRegistry.commands.map((c) => c.name).toList();
      expect(
        names,
        containsAll(['ship', 'audit', 'quick-check', 'clockify']),
      );
    });
  });

  group('CommandRegistry.findByName', () {
    test('resolves a command bundle by name', () {
      final bundle = CommandRegistry.findByName('ship');
      expect(bundle, isNotNull);
      expect(bundle!.id, 'ship');
      expect(bundle.displayName, 'Ship');
      expect(bundle.sourceRelativePath, 'commands/ship.md');
    });

    test('resolves audit, quick-check, and clockify', () {
      expect(CommandRegistry.findByName('audit')?.id, 'audit');
      expect(CommandRegistry.findByName('quick-check')?.id, 'quick-check');
      expect(
        CommandRegistry.findByName('clockify')?.id,
        'clockify',
      );
    });

    test('does not expose the retired Clockify command', () {
      expect(CommandRegistry.findByName('clockify-tracker'), isNull);
    });

    test('returns null for an unknown name', () {
      expect(CommandRegistry.findByName('does-not-exist'), isNull);
    });
  });

  group('registered command files exist on disk', () {
    final root = _repoRoot();

    test('every command bundle has its source file present', () {
      for (final bundle in CommandRegistry.commands) {
        final file = File(p.join(root, bundle.sourceRelativePath));
        expect(
          file.existsSync(),
          isTrue,
          reason: '${bundle.name}: missing ${bundle.sourceRelativePath}',
        );
      }
    });
  });
}
