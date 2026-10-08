import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/utils/real_path.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('real_path_test_');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('realPathOf', () {
    test('resolves a path reached through a symlink', () {
      final real = Directory(p.join(temp.path, 'real', 'skills'))
        ..createSync(recursive: true);
      Link(p.join(temp.path, 'alias')).createSync(p.join(temp.path, 'real'));

      expect(
        realPathOf(p.join(temp.path, 'alias', 'skills')),
        real.resolveSymbolicLinksSync(),
      );
    });

    test('treats the same missing path under twin parents as equal', () {
      Directory(p.join(temp.path, 'real')).createSync();
      Link(p.join(temp.path, 'alias')).createSync(p.join(temp.path, 'real'));

      expect(
        realPathOf(p.join(temp.path, 'alias', '.claude', 'skills')),
        realPathOf(p.join(temp.path, 'real', '.claude', 'skills')),
      );
    });

    test('normalizes dot segments', () {
      expect(
        realPathOf(p.join(temp.path, 'a', '..', 'b')),
        realPathOf(p.join(temp.path, 'b')),
      );
    });
  });
  group('isSafelyWithin', () {
    test('accepts a path strictly inside the root', () {
      expect(isSafelyWithin(temp.path, p.join(temp.path, 'a', 'b')), isTrue);
    });

    test('rejects the root itself', () {
      expect(isSafelyWithin(temp.path, temp.path), isFalse);
    });

    test('rejects a path that climbs out of the root', () {
      expect(
        isSafelyWithin(temp.path, p.join(temp.path, 'a', '..', '..', 'x')),
        isFalse,
      );
    });

    test('rejects a path through a symlinked directory', () {
      Directory(p.join(temp.path, 'outside')).createSync();
      final root = Directory(p.join(temp.path, 'root'))..createSync();
      Link(p.join(root.path, 'evil')).createSync(p.join(temp.path, 'outside'));

      expect(
          isSafelyWithin(root.path, p.join(root.path, 'evil', 'x')), isFalse);
    });

    test('accepts a target that is itself a symlink', () {
      final root = Directory(p.join(temp.path, 'root'))..createSync();
      Link(p.join(root.path, 'skill')).createSync(temp.path);

      expect(isSafelyWithin(root.path, p.join(root.path, 'skill')), isTrue);
    });

    test('accepts a root reached through a symlink', () {
      final real = Directory(p.join(temp.path, 'real'))..createSync();
      Link(p.join(temp.path, 'alias')).createSync(real.path);
      final root = p.join(temp.path, 'alias');

      expect(isSafelyWithin(root, p.join(root, 'skill')), isTrue);
    });
  });
}
