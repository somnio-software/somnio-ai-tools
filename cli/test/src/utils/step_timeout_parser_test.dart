import 'package:somnio/src/runner/step_executor.dart' show defaultStepTimeout;
import 'package:somnio/src/utils/step_timeout_parser.dart';
import 'package:test/test.dart';

void main() {
  group('parseStepTimeoutMinutes', () {
    test('returns the default timeout when raw is null', () {
      expect(parseStepTimeoutMinutes(null), defaultStepTimeout);
    });

    test('parses a positive integer into minutes', () {
      expect(parseStepTimeoutMinutes('10'), const Duration(minutes: 10));
    });

    test('parses "1" into one minute', () {
      expect(parseStepTimeoutMinutes('1'), const Duration(minutes: 1));
    });

    test('throws for a non-numeric value', () {
      expect(
        () => parseStepTimeoutMinutes('abc'),
        throwsA(isA<StepTimeoutParseException>()),
      );
    });

    test('throws for zero', () {
      expect(
        () => parseStepTimeoutMinutes('0'),
        throwsA(isA<StepTimeoutParseException>()),
      );
    });

    test('throws for a negative value', () {
      expect(
        () => parseStepTimeoutMinutes('-5'),
        throwsA(isA<StepTimeoutParseException>()),
      );
    });

    test('throws for a decimal value', () {
      expect(
        () => parseStepTimeoutMinutes('1.5'),
        throwsA(isA<StepTimeoutParseException>()),
      );
    });

    test('throws for an empty string', () {
      expect(
        () => parseStepTimeoutMinutes(''),
        throwsA(isA<StepTimeoutParseException>()),
      );
    });

    test('exception message names the flag and the bad value', () {
      try {
        parseStepTimeoutMinutes('nope');
        fail('Expected a StepTimeoutParseException');
      } on StepTimeoutParseException catch (e) {
        expect(e.message, contains('--step-timeout'));
        expect(e.message, contains('nope'));
        expect(e.toString(), e.message);
      }
    });
  });
}
