/// Matches the line `dart pub global activate` prints on success, e.g.
/// `Activated somnio 3.2.6 from Git repository "https://..."`.
///
/// Only the package name and version are matched, so the trailing source
/// description (`at path ...`, `from Git repository ...`) may vary.
final _activatedLine = RegExp(
  r'^Activated somnio (\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.+-]+)?)(?:\s|$)',
);

final _ansiEscape = RegExp('\x1B\\[[0-9;]*[A-Za-z]');

/// The `somnio` version reported by `dart pub global activate` in [stdout].
///
/// Tolerates ANSI color codes, CRLF line endings and surrounding output.
/// Returns `null` when no `Activated somnio <version>` line is present, so
/// callers never have to guess a version.
String? parseActivatedVersion(String stdout) {
  for (final rawLine in stdout.split('\n')) {
    final line = rawLine.replaceAll(_ansiEscape, '').trim();
    final match = _activatedLine.firstMatch(line);
    if (match != null) return match.group(1);
  }
  return null;
}

/// The success message shown after updating the CLI.
///
/// Names the installed version when [stdout] reports one, and falls back to
/// `CLI updated` otherwise.
String updateSuccessMessage(String stdout) {
  final version = parseActivatedVersion(stdout);
  return version == null ? 'CLI updated' : 'CLI updated to v$version';
}
