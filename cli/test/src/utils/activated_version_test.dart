import 'package:somnio/src/utils/activated_version.dart';
import 'package:test/test.dart';

void main() {
  group('parseActivatedVersion', () {
    test('parses a real-format git activation line', () {
      expect(
        parseActivatedVersion(
          'Activated somnio 3.2.6 from Git repository '
          '"https://github.com/somnio-software/somnio-ai-tools".\n',
        ),
        '3.2.6',
      );
    });

    test('parses the path-source format', () {
      expect(parseActivatedVersion('Activated somnio 1.0.0 at path "/x".'),
          '1.0.0');
    });

    test('tolerates ANSI color codes', () {
      expect(
        parseActivatedVersion(
          '\x1B[1mActivated\x1B[0m somnio 3.2.6 from Git repository "x".',
        ),
        '3.2.6',
      );
      expect(
        parseActivatedVersion('\x1B[32mActivated somnio 3.2.6\x1B[0m'),
        '3.2.6',
      );
    });

    test('finds the line among multiple lines with CRLF', () {
      const out = 'Resolving dependencies...\r\n'
          'Got dependencies!\r\n'
          'Installed executable somnio.\r\n'
          'Activated somnio 3.10.0-beta.1 from Git repository "x".\r\n';
      expect(parseActivatedVersion(out), '3.10.0-beta.1');
    });

    test('ignores other packages', () {
      expect(parseActivatedVersion('Activated mason_cli 0.1.2 at path "x".'),
          isNull);
      expect(parseActivatedVersion('Activated somnio_extra 1.2.3'), isNull);
    });

    test('returns null for empty or garbled output', () {
      expect(parseActivatedVersion(''), isNull);
      expect(parseActivatedVersion('Activated somnio'), isNull);
      expect(parseActivatedVersion('Activated somnio abc'), isNull);
      expect(parseActivatedVersion('\x00\xFFnoise'), isNull);
    });
  });

  group('updateSuccessMessage', () {
    test('names the version when parsed', () {
      expect(
        updateSuccessMessage('Activated somnio 3.2.6 from Git repository "x".'),
        'CLI updated to v3.2.6',
      );
    });

    test('falls back to CLI updated', () {
      expect(updateSuccessMessage('nothing useful'), 'CLI updated');
    });
  });
}
