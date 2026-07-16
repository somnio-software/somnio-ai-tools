/// Emits [text] as the body of a YAML `>-` folded block: whitespace
/// collapsed, wrapped at ~76 columns, every line indented two spaces.
///
/// Folding is what makes an authored description safe to re-emit. Interpolating
/// it as a plain scalar breaks on `: ` (read as a nested mapping key), and
/// interpolating it as a single indented line under `>-` breaks on an embedded
/// newline — which silently truncates the value at the first line. Collapsing
/// the whitespace first removes both hazards, so the emitted frontmatter parses
/// and round-trips regardless of how the description was authored.
String foldYamlBlock(String text) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final lines = <String>[];
  var current = StringBuffer();
  for (final w in words) {
    if (current.isNotEmpty && current.length + 1 + w.length > 74) {
      lines.add(current.toString());
      current = StringBuffer();
    }
    if (current.isNotEmpty) current.write(' ');
    current.write(w);
  }
  if (current.isNotEmpty) lines.add(current.toString());
  return lines.map((l) => '  $l\n').join();
}

/// Emits [text] as a single-line YAML scalar, quoting only when the plain form
/// would be misparsed.
///
/// This is [foldYamlBlock]'s counterpart for values that must stay on one line,
/// such as `allowed-tools`. The hazard is the same: a `: ` inside a plain
/// scalar is read as a nested mapping key, a trailing `:` or an ` #` starts a
/// comment, and a leading indicator character changes the node type. Whitespace
/// is collapsed first, so an embedded newline cannot terminate the value early.
///
/// Values carrying none of those — the ordinary `Bash, Read, Edit` form every
/// skill authors today — are emitted verbatim, so this cannot churn existing
/// installed output.
String yamlInlineScalar(String text) {
  final v = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  final needsQuote = v.isEmpty ||
      v.contains(': ') ||
      v.endsWith(':') ||
      v.contains(' #') ||
      RegExp('^[-?:,\\[\\]{}#&*!|>\'"%@`]').hasMatch(v);
  if (!needsQuote) return v;
  return "'${v.replaceAll("'", "''")}'";
}
