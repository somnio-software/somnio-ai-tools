import 'dart:convert';
import 'dart:io' as io;

import 'package:somnio/src/utils/banner.dart';
import 'package:somnio/src/utils/quotes.dart';
import 'package:test/test.dart';

/// Captures lines written to stdout and controls terminal capability flags.
class _FakeStdout implements io.Stdout {
  _FakeStdout({required this.hasTerminal, required this.supportsAnsiEscapes});

  @override
  final bool hasTerminal;

  @override
  final bool supportsAnsiEscapes;

  final List<String> written = <String>[];

  String get output => written.join();

  @override
  void writeln([Object? obj = '']) => written.add('$obj\n');

  @override
  void write(Object? obj) => written.add('$obj');

  @override
  void writeAll(Iterable<dynamic> objects, [String sep = '']) =>
      written.add(objects.join(sep));

  @override
  void writeCharCode(int charCode) => written.add(String.fromCharCode(charCode));

  @override
  void add(List<int> data) => written.add(utf8.decode(data));

  @override
  Encoding encoding = utf8;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('lerpRgb', () {
    test('returns first color at t=0', () {
      final a = const Rgb(0, 0, 0);
      final b = const Rgb(255, 255, 255);
      final result = lerpRgb(a, b, 0.0);
      expect(result.r, 0);
      expect(result.g, 0);
      expect(result.b, 0);
    });

    test('returns second color at t=1', () {
      final a = const Rgb(0, 0, 0);
      final b = const Rgb(255, 255, 255);
      final result = lerpRgb(a, b, 1.0);
      expect(result.r, 255);
      expect(result.g, 255);
      expect(result.b, 255);
    });

    test('returns midpoint at t=0.5', () {
      final a = const Rgb(0, 100, 200);
      final b = const Rgb(100, 200, 0);
      final result = lerpRgb(a, b, 0.5);
      expect(result.r, 50);
      expect(result.g, 150);
      expect(result.b, 100);
    });

    test('clamps values to 0-255', () {
      final a = const Rgb(250, 250, 250);
      final b = const Rgb(260, 260, 260); // intentionally out of range
      final result = lerpRgb(a, b, 1.0);
      expect(result.r, 255);
      expect(result.g, 255);
      expect(result.b, 255);
    });
  });

  group('interpolateGradient', () {
    test('returns first stop at t=0', () {
      final result = interpolateGradient(0.0, gradientStops);
      expect(result.r, gradientStops.first.r);
      expect(result.g, gradientStops.first.g);
      expect(result.b, gradientStops.first.b);
    });

    test('returns last stop at t=1', () {
      final result = interpolateGradient(1.0, gradientStops);
      expect(result.r, gradientStops.last.r);
      expect(result.g, gradientStops.last.g);
      expect(result.b, gradientStops.last.b);
    });

    test('returns intermediate color at t=0.5', () {
      final result = interpolateGradient(0.5, gradientStops);
      // t=0.5 with 4 stops (3 segments) → scaled = 1.5
      // Between stops[1] (37,99,235) and stops[2] (124,58,237), localT=0.5
      expect(result.r, closeTo(80, 2));
      expect(result.g, closeTo(78, 2));
      expect(result.b, closeTo(236, 2));
    });

    test('clamps t below 0', () {
      final result = interpolateGradient(-1.0, gradientStops);
      expect(result.r, gradientStops.first.r);
      expect(result.g, gradientStops.first.g);
      expect(result.b, gradientStops.first.b);
    });

    test('clamps t above 1', () {
      final result = interpolateGradient(2.0, gradientStops);
      expect(result.r, gradientStops.last.r);
      expect(result.g, gradientStops.last.g);
      expect(result.b, gradientStops.last.b);
    });

    test('handles single stop', () {
      final single = [const Rgb(100, 100, 100)];
      final result = interpolateGradient(0.5, single);
      expect(result.r, 100);
      expect(result.g, 100);
      expect(result.b, 100);
    });
  });

  group('printBanner', () {
    const quote = SomnioQuote('test quote', 'test author');

    test('renders gradient (ANSI) banner when terminal supports ANSI', () {
      final fake = _FakeStdout(hasTerminal: true, supportsAnsiEscapes: true);

      printBanner(version: '1.2.3', quote: quote, stdout: fake);

      final out = fake.output;
      // ANSI foreground escape present
      expect(out, contains('\x1b[38;2;'));
      // Reset escape present
      expect(out, contains('\x1b[0m'));
      // Version appears in the subtitle line. In the gradient banner each
      // glyph is wrapped in ANSI escapes, so strip them before matching.
      final stripped = out.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
      expect(stripped, contains('v1.2.3'));
      // Quote text rendered (quote line is single-color, not per-glyph).
      expect(out, contains('test quote'));
      expect(out, contains('test author'));
    });

    test('falls back to static banner when no terminal', () {
      final fake = _FakeStdout(hasTerminal: false, supportsAnsiEscapes: true);

      printBanner(version: '9.9.9', quote: quote, stdout: fake);

      final out = fake.output;
      // No ANSI escapes in static fallback
      expect(out, isNot(contains('\x1b[38;2;')));
      expect(out, contains('v9.9.9'));
      expect(out, contains('"test quote"'));
      expect(out, contains('— test author'));
    });

    test('falls back to static banner when ANSI unsupported', () {
      final fake = _FakeStdout(hasTerminal: true, supportsAnsiEscapes: false);

      printBanner(version: '0.0.1', quote: quote, stdout: fake);

      final out = fake.output;
      expect(out, isNot(contains('\x1b[0m')));
      expect(out, contains('v0.0.1'));
    });

    test('defaults to io.stdout when no sink is provided', () {
      // Exercises the `stdout ?? io.stdout` fallback. Under `dart test` stdout
      // is not a TTY, so this takes the harmless static-banner path.
      expect(
        () => printBanner(version: '0.0.0', quote: quote),
        returnsNormally,
      );
    });
  });
}
