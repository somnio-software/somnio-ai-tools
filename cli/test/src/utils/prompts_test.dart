import 'package:somnio/src/utils/prompts.dart';
import 'package:test/test.dart';

void main() {
  group('Prompts non-interactive fallback', () {
    // The test runner is not attached to a TTY, so isInteractive is false.
    // These tests assert the safe fallbacks taken in that case (also the
    // path exercised in CI / piped output).
    test('isInteractive is false under the test harness', () {
      expect(Prompts.isInteractive, isFalse);
    });

    test('selectOneOf returns the default value when non-interactive', () {
      final result = Prompts.selectOneOf(
        'pick',
        choices: ['a', 'b', 'c'],
        defaultValue: 'b',
      );
      expect(result, 'b');
    });

    test('selectOneOf returns the first choice when no default given', () {
      final result = Prompts.selectOneOf(
        'pick',
        choices: ['x', 'y'],
      );
      expect(result, 'x');
    });
  });
}
