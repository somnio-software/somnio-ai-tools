// coverage:ignore-file
import 'dart:io' as io;

import 'package:interact_cli/interact_cli.dart';

import 'scrolling_picker.dart';

/// Centralized interactive prompt helpers.
///
/// Wraps [ScrollingPicker] so every command shares the same Somnio-branded
/// `interact_cli` theme and the same non-interactive fallback logic.
///
/// Menus redraw with *relative* cursor movement (`cursorUp` + `eraseLine` per
/// line), which is scroll-safe — unlike `mason_logger`'s absolute
/// save/restore approach that caused the "jumping / duplicated lines"
/// rendering bug. Relative movement only holds while the frame fits in the
/// window, so the picker scrolls a viewport instead of painting every option;
/// `interact_cli`'s own `Select` / `MultiSelect` paint the full list and
/// duplicated their first lines once it outgrew the terminal.
class Prompts {
  Prompts._();

  /// Whether the current process is attached to an interactive terminal.
  ///
  /// When false (CI, pipes, redirected I/O), callers must skip interactive
  /// menus and fall back to a sensible default instead of hanging on stdin.
  static bool get isInteractive =>
      io.stdin.hasTerminal && io.stdout.hasTerminal;

  /// Whether the terminal can render ANSI colors. Falls back to the plain
  /// ASCII theme otherwise.
  static bool get _supportsAnsi =>
      io.stdout.hasTerminal && io.stdout.supportsAnsiEscapes;

  /// The theme used by all interactive prompts.
  static Theme get theme => _supportsAnsi ? somnioTheme : Theme.basicTheme;

  /// Single-choice menu. Returns the selected index.
  ///
  /// Navigate with ↑/↓, confirm with enter.
  static int selectOne({
    required String prompt,
    required List<String> options,
    int initialIndex = 0,
  }) {
    return ScrollingPicker(
      theme: theme,
      prompt: prompt,
      options: options,
      multi: false,
      unicode: _supportsAnsi,
      initialIndex: initialIndex,
    ).interact().first;
  }

  /// Single-choice menu over a list of string [choices], returning the
  /// chosen value (drop-in replacement for `mason_logger`'s `chooseOne`).
  ///
  /// When [defaultValue] is given it becomes the initially highlighted
  /// option. Falls back to that default (or the first choice) when there is
  /// no interactive terminal.
  static String selectOneOf(
    String prompt, {
    required List<String> choices,
    String? defaultValue,
  }) {
    final fallback = defaultValue ?? choices.first;
    if (!isInteractive) return fallback;

    final initial = defaultValue != null && choices.contains(defaultValue)
        ? choices.indexOf(defaultValue)
        : 0;
    final index = selectOne(
      prompt: prompt,
      options: choices,
      initialIndex: initial,
    );
    return choices[index];
  }

  /// Multi-choice menu. Returns the list of selected indexes, ascending.
  ///
  /// Navigate with ↑/↓, toggle with space, toggle every option with `a`,
  /// confirm with enter. Lists taller than the window scroll instead of
  /// overflowing it.
  static List<int> selectMany({
    required String prompt,
    required List<String> options,
    List<bool>? defaults,
  }) {
    if (defaults != null && defaults.length != options.length) {
      throw ArgumentError(
        'Default selections have a different length of ${defaults.length} '
        'than options of ${options.length}',
      );
    }

    return ScrollingPicker(
      theme: theme,
      prompt: prompt,
      options: options,
      multi: true,
      unicode: _supportsAnsi,
      defaults: defaults,
    ).interact();
  }
}

// ---------------------------------------------------------------------------
// Somnio-branded theme
// ---------------------------------------------------------------------------

/// Brand gradient stops (matches the CLI banner): blue → purple → lilac.
const _brandBlue = [37, 99, 235]; // #2563eb
const _brandPurple = [124, 58, 237]; // #7c3aed
const _brandLilac = [167, 139, 250]; // #a78bfa
const _dim = [120, 120, 130];

String _fg(List<int> rgb, String text) =>
    '\x1b[38;2;${rgb[0]};${rgb[1]};${rgb[2]}m$text\x1b[0m';

String _bold(String text) => '\x1b[1m$text\x1b[0m';

/// Somnio-branded variant of [Theme.colorfulTheme] using the brand palette.
final somnioTheme = Theme.colorfulTheme.copyWith(
  activeItemPrefix: _bold(_fg(_brandLilac, '❯')),
  inactiveItemPrefix: ' ',
  activeItemStyle: (x) => _bold(_fg(_brandLilac, x)),
  inactiveItemStyle: (x) => x,
  checkedItemPrefix: _fg(_brandPurple, '◉'),
  uncheckedItemPrefix: _fg(_dim, '◯'),
  pickedItemPrefix: _fg(_brandLilac, '❯'),
  unpickedItemPrefix: ' ',
  messageStyle: (x) => _bold(x),
  hintStyle: (x) => _fg(_dim, '($x)'),
  successPrefix: _fg(_brandBlue, '✔'),
);
