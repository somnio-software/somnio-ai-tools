import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/utils/platform_utils.dart';
import 'package:test/test.dart';

void main() {
  group('PlatformUtils.discoverConfigDirs', () {
    late Directory tempHome;

    setUp(() {
      tempHome = Directory.systemTemp.createTempSync('somnio_platform_utils_');
    });

    tearDown(() {
      if (tempHome.existsSync()) tempHome.deleteSync(recursive: true);
    });

    test('returns every directory whose basename starts with the prefix', () {
      Directory(p.join(tempHome.path, '.claude')).createSync();
      Directory(p.join(tempHome.path, '.claude-work')).createSync();
      Directory(p.join(tempHome.path, '.claude-personal')).createSync();
      Directory(p.join(tempHome.path, '.cursor')).createSync(); // unrelated
      File(p.join(tempHome.path, '.clauderc')).createSync(); // file, not dir

      final dirs = PlatformUtils.discoverConfigDirs(
        prefix: '.claude',
        home: tempHome.path,
      );

      expect(dirs, hasLength(3));
      expect(
        dirs.map(p.basename).toList(),
        ['.claude', '.claude-personal', '.claude-work'],
        reason: 'results should be sorted for stability',
      );
    });

    test('returns the canonical fallback when nothing matches', () {
      // Empty home, nothing matches.
      final dirs = PlatformUtils.discoverConfigDirs(
        prefix: '.cursor',
        home: tempHome.path,
      );

      expect(dirs, [p.join(tempHome.path, '.cursor')]);
    });

    test('returns the canonical fallback when home does not exist', () {
      final missing = p.join(tempHome.path, 'does-not-exist');

      final dirs = PlatformUtils.discoverConfigDirs(
        prefix: '.gemini',
        home: missing,
      );

      expect(dirs, [p.join(missing, '.gemini')]);
    });

    test('ignores files and only returns directories', () {
      File(p.join(tempHome.path, '.claude.json')).createSync();
      Directory(p.join(tempHome.path, '.claude')).createSync();

      final dirs = PlatformUtils.discoverConfigDirs(
        prefix: '.claude',
        home: tempHome.path,
      );

      expect(dirs, [p.join(tempHome.path, '.claude')]);
    });

    test('different prefixes scan independently', () {
      Directory(p.join(tempHome.path, '.cursor-work')).createSync();
      Directory(p.join(tempHome.path, '.gemini-personal')).createSync();

      final cursor = PlatformUtils.discoverConfigDirs(
        prefix: '.cursor',
        home: tempHome.path,
      );
      final gemini = PlatformUtils.discoverConfigDirs(
        prefix: '.gemini',
        home: tempHome.path,
      );

      expect(cursor.map(p.basename), ['.cursor-work']);
      expect(gemini.map(p.basename), ['.gemini-personal']);
    });
  });
}
