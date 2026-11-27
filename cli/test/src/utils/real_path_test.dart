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
  group('followedPathOf', () {
    late String real;

    setUp(() {
      real = temp.resolveSymbolicLinksSync();
    });

    test('matches realPathOf where every link has a target', () {
      Directory(p.join(temp.path, 'real', 'skills'))
          .createSync(recursive: true);
      Link(p.join(temp.path, 'alias')).createSync(p.join(temp.path, 'real'));
      final path = p.join(temp.path, 'alias', 'skills');

      expect(followedPathOf(path), realPathOf(path));
    });

    test('matches realPathOf on a missing path with no link', () {
      final path = p.join(temp.path, 'missing', 'skills');

      expect(followedPathOf(path), realPathOf(path));
    });

    test('follows a link whose target does not exist', () {
      Link(p.join(temp.path, 'link')).createSync(p.join(temp.path, 'target'));

      expect(followedPathOf(p.join(temp.path, 'link')), p.join(real, 'target'));
    });

    test('follows a relative link from the folder it lives in', () {
      Directory(p.join(temp.path, 'a')).createSync();
      Link(p.join(temp.path, 'a', 'link')).createSync('../target');

      expect(
        followedPathOf(p.join(temp.path, 'a', 'link')),
        p.join(real, 'target'),
      );
    });

    test('follows a dangling link above the path', () {
      Link(p.join(temp.path, 'home')).createSync(p.join(temp.path, 'target'));

      expect(
        followedPathOf(p.join(temp.path, 'home', 'skills')),
        p.join(real, 'target', 'skills'),
      );
    });

    test('follows a chain of links to a missing target', () {
      Link(p.join(temp.path, 'one')).createSync(p.join(temp.path, 'two'));
      Link(p.join(temp.path, 'two')).createSync(p.join(temp.path, 'target'));

      expect(followedPathOf(p.join(temp.path, 'one')), p.join(real, 'target'));
    });

    test('takes .. in a target after the link before it', () {
      Directory(p.join(temp.path, 'far', 'away')).createSync(recursive: true);
      Link(p.join(temp.path, 'near')).createSync(p.join(temp.path, 'far/away'));
      Link(p.join(temp.path, 'link')).createSync('near/../target');

      expect(
        followedPathOf(p.join(temp.path, 'link')),
        p.join(real, 'far', 'target'),
      );
    });

    test('gives realPathOf for a link cycle', () {
      final one = p.join(temp.path, 'one');
      Link(one).createSync(p.join(temp.path, 'two'));
      Link(p.join(temp.path, 'two')).createSync(one);

      expect(followedPathOf(one), realPathOf(one));
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
