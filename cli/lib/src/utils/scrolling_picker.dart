// coverage:ignore-file
import 'dart:io' as io;

import 'package:dart_console/dart_console.dart';
import 'package:interact_cli/interact_cli.dart';

import 'scroll_window.dart';

/// A single- or multi-choice picker that never renders more lines than the
/// terminal window can hold.
///
/// `interact_cli`'s `Select` / `MultiSelect` paint every option on every
/// redraw and erase the previous frame with relative cursor moves. Once the
/// list is taller than the window, the lines that scrolled off the top can no
/// longer be erased, so each redraw stacks another copy of them in the
/// scrollback — with 23 skills in a 20-row window the first four entries were
/// repeated once per keypress. This picker scrolls a viewport instead, so a
/// frame always fits and is always fully erasable.
///
/// Styling comes from the same [Theme] as the rest of the CLI, so the output
/// is indistinguishable from the components it replaces.
class ScrollingPicker {
  ScrollingPicker({
    required this.theme,
    required this.prompt,
    required this.options,
    required this.multi,
    this.unicode = true,
    List<bool>? defaults,
    int initialIndex = 0,
  })  : assert(options.length > 0, "Options can't be empty"),
        _index = initialIndex.clamp(0, options.length - 1),
        _selected = <int>{
          if (defaults != null)
            for (var i = 0; i < defaults.length && i < options.length; i++)
              if (defaults[i]) i,
        };

  /// The theme used for prefixes and text styles.
  final Theme theme;

  /// The question shown above the list.
  final String prompt;

  /// The option labels, in registry order.
  final List<String> options;

  /// Whether several options can be checked (space) or exactly one picked.
  final bool multi;

  /// Whether the terminal can render the arrow glyphs used by the scroll hint.
  final bool unicode;

  final Console _console = Console();
  final Set<int> _selected;
  int _index;
  int _offset = 0;
  int _linesWritten = 0;

  /// Runs the picker and returns the chosen indexes, ascending.
  ///
  /// For a single-choice picker the result always holds exactly one index.
  List<int> interact() {
    _console.hideCursor();
    try {
      _render();
      while (true) {
        final key = _console.readKey();

        if (key.isControl) {
          switch (key.controlChar) {
            case ControlCharacter.arrowUp:
              _move(-1);
            case ControlCharacter.arrowDown:
              _move(1);
            case ControlCharacter.enter:
              return _finish();
            case ControlCharacter.ctrlC:
              _abort();
            default:
              break;
          }
          continue;
        }

        switch (key.char) {
          case ' ':
            if (multi) {
              _toggle(_index);
              _redraw();
            }
          case 'a':
          case 'A':
            if (multi) {
              _toggleAll();
              _redraw();
            }
          default:
            break;
        }
      }
    } finally {
      _console.showCursor();
    }
  }

  void _move(int delta) {
    _index = (_index + delta) % options.length;
    _redraw();
  }

  void _toggle(int i) {
    if (!_selected.remove(i)) _selected.add(i);
  }

  void _toggleAll() {
    if (_selected.length == options.length) {
      _selected.clear();
    } else {
      _selected.addAll(List.generate(options.length, (i) => i));
    }
  }

  List<int> _finish() {
    final result = multi ? (_selected.toList()..sort()) : <int>[_index];
    _wipe();
    _console.writeLine(_successLine(result));
    return result;
  }

  Never _abort() {
    _wipe();
    _console
      ..showCursor()
      ..resetColorAttributes();
    io.exit(1);
  }

  // ---------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------

  void _redraw() {
    _wipe();
    _render();
  }

  /// Erases exactly the lines written by the previous frame.
  ///
  /// Safe by construction: [_render] never writes more lines than the window
  /// holds, so the cursor never needs to climb past the top of the window.
  void _wipe() {
    for (var i = 0; i < _linesWritten; i++) {
      _console
        ..cursorUp()
        ..eraseLine();
    }
    _linesWritten = 0;
  }

  void _render() {
    final total = options.length;
    final visible = visibleRows(total: total, terminalLines: _windowHeight);
    _offset = scrollOffset(
      index: _index,
      previousOffset: _offset,
      visible: visible,
      total: total,
    );

    _writeln(_promptLine());
    for (var i = _offset; i < _offset + visible; i++) {
      _writeln(_optionLine(i));
    }
    _writeln(_statusLine(visible));
  }

  void _writeln(String line) {
    _linesWritten++;
    _console.writeLine(line);
  }

  /// The window height, or `null` when stdout is not a terminal.
  int? get _windowHeight =>
      io.stdout.hasTerminal ? io.stdout.terminalLines : null;

  String _promptLine() {
    final hint = multi
        ? 'up/down move, space toggle, a all, enter confirm'
        : 'up/down move, enter confirm';
    return '${theme.inputPrefix}${theme.messageStyle(prompt)}'
        '${theme.inputSuffix} ${theme.hintStyle(hint)}';
  }

  String _optionLine(int i) {
    final line = StringBuffer();

    if (theme.showActiveCursor) {
      line
        ..write(
          i == _index ? theme.activeItemPrefix : theme.inactiveItemPrefix,
        )
        ..write(' ');
    }

    if (multi) {
      line
        ..write(
          _selected.contains(i)
              ? theme.checkedItemPrefix
              : theme.uncheckedItemPrefix,
        )
        ..write(' ');
    }

    line.write(
      i == _index
          ? theme.activeItemStyle(options[i])
          : theme.inactiveItemStyle(options[i]),
    );
    return line.toString();
  }

  /// The scroll indicator plus, for a multi-select, the selected count.
  ///
  /// Always rendered so every frame is the same height, which keeps the wipe
  /// count stable across redraws.
  String _statusLine(int visible) {
    final up = unicode ? '↑' : '^';
    final down = unicode ? '↓' : 'v';

    final parts = <String>[];
    final above = _offset;
    final below = options.length - (_offset + visible);
    if (above > 0) parts.add('$up $above more');
    if (below > 0) parts.add('$down $below more');
    if (multi) parts.add('${_selected.length}/${options.length} selected');

    return parts.isEmpty ? '' : theme.hintStyle(parts.join('  '));
  }

  /// Mirrors `interact_cli`'s `promptSuccess`, including its double styling of
  /// the value, so the confirmed line is byte-identical to what the replaced
  /// components printed.
  String _successLine(List<int> result) {
    final value =
        result.map((i) => options[i]).map(theme.valueStyle).join(', ');
    return '${theme.successPrefix}${theme.messageStyle(prompt)}'
        '${theme.successSuffix}${theme.valueStyle(' $value ')}';
  }
}
