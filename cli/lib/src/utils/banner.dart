import 'dart:io' as io;
import 'dart:math';

import 'quotes.dart';

/// RGB color for gradient calculations.
class Rgb {
  const Rgb(this.r, this.g, this.b);
  final int r;
  final int g;
  final int b;
}

// ---------------------------------------------------------------------------
// Brand gradient stops: dark blue → medium blue → purple → light purple
// ---------------------------------------------------------------------------
const gradientStops = <Rgb>[
  Rgb(30, 58, 138), // #1e3a8a
  Rgb(37, 99, 235), // #2563eb
  Rgb(124, 58, 237), // #7c3aed
  Rgb(167, 139, 250), // #a78bfa
];

const _dimColor = Rgb(40, 40, 50);
const _quoteColor = Rgb(100, 130, 220);

// ---------------------------------------------------------------------------
// ASCII art — figlet "Somnio" + SOFTWARE subtitle
// ---------------------------------------------------------------------------
const _bannerArt = <String>[
  '  ____                        _',
  " / ___|  ___  _ __ ___  _ __ (_) ___",
  " \\___ \\ / _ \\| '_ ` _ \\| '_ \\| |/ _ \\",
  '  ___) | (_) | | | | | | | | | | (_) |',
  " |____/ \\___/|_| |_| |_|_| |_|_|\\___/",
];

// ---------------------------------------------------------------------------
// Gradient math
// ---------------------------------------------------------------------------

/// Linearly interpolate between two [Rgb] colors at position [t] ∈ [0, 1].
Rgb lerpRgb(Rgb a, Rgb b, double t) {
  return Rgb(
    (a.r + (b.r - a.r) * t).round().clamp(0, 255),
    (a.g + (b.g - a.g) * t).round().clamp(0, 255),
    (a.b + (b.b - a.b) * t).round().clamp(0, 255),
  );
}

/// Multi-stop gradient interpolation. [t] must be in [0.0, 1.0].
Rgb interpolateGradient(double t, List<Rgb> stops) {
  if (stops.length == 1) return stops.first;
  final segments = stops.length - 1;
  final scaled = (t.clamp(0.0, 1.0) * segments);
  final index = scaled.floor().clamp(0, segments - 1);
  final localT = scaled - index;
  return lerpRgb(stops[index], stops[min(index + 1, segments)], localT);
}

// ---------------------------------------------------------------------------
// ANSI escape helpers
// ---------------------------------------------------------------------------
String _fg(int r, int g, int b) => '\x1b[38;2;$r;$g;${b}m';
const _reset = '\x1b[0m';

// ---------------------------------------------------------------------------
// Frame renderer
// ---------------------------------------------------------------------------

/// Renders one animation frame. [wavefrontPos] is the column index of the
/// leading edge of the color wave. Characters behind it are fully colored;
/// characters in the falloff zone blend toward [_dimColor].
void _renderFrame({
  required io.IOSink out,
  required List<String> lines,
  required int maxWidth,
  required int wavefrontPos,
  int falloff = 8,
  double brightnessBoost = 0.0,
}) {
  for (final line in lines) {
    if (line.isEmpty) {
      out.writeln();
      continue;
    }
    final buf = StringBuffer();
    for (var col = 0; col < line.length; col++) {
      final char = line[col];
      if (char == ' ') {
        buf.write(' ');
        continue;
      }

      // Gradient position based on column
      final gradientT = maxWidth > 0 ? col / maxWidth : 0.0;
      var color = interpolateGradient(gradientT, gradientStops);

      // Wave reveal blending + shimmer pulse — leftover animation hooks that
      // the instant-render printBanner() never triggers (wavefrontPos is always
      // past the last column and brightnessBoost defaults to 0).
      // coverage:ignore-start
      final dist = col - wavefrontPos;
      if (dist > 0 && dist < falloff) {
        color = lerpRgb(color, _dimColor, dist / falloff);
      } else if (dist >= falloff) {
        color = _dimColor;
      }

      if (brightnessBoost > 0) {
        color = lerpRgb(color, const Rgb(255, 255, 255), brightnessBoost);
      }
      // coverage:ignore-end

      buf.write('${_fg(color.r, color.g, color.b)}$char');
    }
    buf.write(_reset);
    out.writeln(buf);
  }
}

// ---------------------------------------------------------------------------
// Static fallback (no color, no animation)
// ---------------------------------------------------------------------------
void _printStaticBanner(io.IOSink out, List<String> lines, SomnioQuote quote) {
  out.writeln();
  for (final line in lines) {
    out.writeln(line);
  }
  out.writeln();
  out.writeln('  "${quote.text}"');
  out.writeln('     \u2014 ${quote.author}');
  out.writeln();
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Displays the Somnio banner with a blue-to-purple gradient.
///
/// Falls back to plain text when the terminal does not support ANSI escapes
/// or when stdout is not a TTY (e.g. piped output, CI).
void printBanner({
  required String version,
  required SomnioQuote quote,
  io.Stdout? stdout,
}) {
  final out = stdout ?? io.stdout;

  // Build the full set of lines (art + subtitle with version)
  final lines = <String>[
    ..._bannerArt,
    '',
    '          S  O  F  T  W  A  R  E    v$version',
  ];

  final maxWidth = lines.fold<int>(0, (m, l) => max(m, l.length));

  // ── Terminal capability check ──────────────────────────────────────────
  final supportsAnsi = out.hasTerminal && out.supportsAnsiEscapes;
  if (!supportsAnsi) {
    _printStaticBanner(out, lines, quote);
    return;
  }

  // ── Render gradient banner instantly ───────────────────────────────────
  out.writeln();
  _renderFrame(
    out: out,
    lines: lines,
    maxWidth: maxWidth,
    wavefrontPos: maxWidth + 20, // fully revealed
  );

  // ── Quote (single color) ──────────────────────────────────────────────
  final qc = _fg(_quoteColor.r, _quoteColor.g, _quoteColor.b);
  out.writeln();
  out.writeln('  $qc"${quote.text}"$_reset');
  out.writeln('  $qc   \u2014 ${quote.author}$_reset');
  out.writeln();
}
