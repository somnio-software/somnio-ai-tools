import 'package:somnio/src/utils/bundle_file_filter.dart';
import 'package:test/test.dart';

void main() {
  group('isIgnoredBundleFile', () {
    test('ignores .DS_Store at any depth', () {
      expect(isIgnoredBundleFile('.DS_Store'), isTrue);
      expect(isIgnoredBundleFile('assets/.DS_Store'), isTrue);
    });

    test('ignores python bytecode caches', () {
      expect(isIgnoredBundleFile('__pycache__/x.pyc'), isTrue);
      expect(isIgnoredBundleFile('scripts/a.pyo'), isTrue);
    });

    test('keeps normal files', () {
      expect(isIgnoredBundleFile('script.py'), isFalse);
      expect(isIgnoredBundleFile('notes.DS_Store.md'), isFalse);
    });
  });
}
