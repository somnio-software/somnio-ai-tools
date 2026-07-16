import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../content/skill_bundle.dart';

/// Programmatically inserts new [SkillBundle] entries into
/// `skill_registry.dart`.
///
/// Uses string-based insertion to append entries before the closing
/// `];` of the `skills` list.
class RegistryModifier {
  RegistryModifier({required this.repoRoot, required Logger logger})
      : _logger = logger;

  final String repoRoot;
  final Logger _logger;

  /// Path to the skill_registry.dart file.
  String get _registryPath => p.join(
        repoRoot,
        'cli',
        'lib',
        'src',
        'content',
        'skill_registry.dart',
      );

  /// Inserts new [SkillBundle] entries into `skill_registry.dart`.
  ///
  /// Throws [StateError] if the insertion point cannot be found.
  /// Rolls back to the original content if insertion produces
  /// invalid code.
  Future<void> addBundles(List<SkillBundle> bundles) async {
    final file = File(_registryPath);
    final original = file.readAsStringSync();

    // Anchor to the `skills` list declaration first: skill_registry.dart
    // also declares a `workflowSkills` list that closes with the same
    // `\n  ];` pattern, so a bare lastIndexOf would land in the wrong list.
    const skillsMarker = 'static const List<SkillBundle> skills = [';
    final markerIndex = original.indexOf(skillsMarker);
    if (markerIndex == -1) {
      throw StateError(
        'Cannot find the skills list declaration in skill_registry.dart.',
      );
    }
    final insertIndex = original.indexOf('\n  ];', markerIndex);
    if (insertIndex == -1) {
      throw StateError(
        'Cannot find the closing "];" of the skills list in '
        'skill_registry.dart.',
      );
    }

    // Generate Dart code for each bundle
    final codeLines = bundles.map(_generateBundleCode).join('\n');

    // Insert before the `];`
    final modified = original.substring(0, insertIndex) +
        '\n$codeLines' +
        original.substring(insertIndex);

    // Write modified file
    file.writeAsStringSync(modified);

    // Validate the result is syntactically valid Dart; roll back otherwise.
    final formatResult = await Process.run(
      'dart',
      ['format', '--output=none', _registryPath],
    );
    if (formatResult.exitCode != 0) {
      file.writeAsStringSync(original);
      throw StateError(
        'Generated skill_registry.dart is not valid Dart syntax; '
        'rolled back to the original content.\n${formatResult.stderr}',
      );
    }

    _logger.detail('  Updated: ${p.relative(_registryPath, from: repoRoot)}');
  }

  /// Checks if any of the given bundles conflict with existing
  /// entries in the registry file.
  bool hasConflicts(List<SkillBundle> bundles) {
    final file = File(_registryPath);
    final content = file.readAsStringSync();

    final seenIds = <String>{};
    final seenNames = <String>{};
    for (final bundle in bundles) {
      if (!seenIds.add(bundle.id)) {
        _logger.err("Duplicate bundle ID '${bundle.id}' in the same batch.");
        return true;
      }
      if (!seenNames.add(bundle.name)) {
        _logger.err(
          "Duplicate bundle name '${bundle.name}' in the same batch.",
        );
        return true;
      }
    }

    for (final bundle in bundles) {
      if (content.contains("id: '${_escapeSingle(bundle.id)}'")) {
        _logger.err("Bundle ID '${bundle.id}' already exists.");
        return true;
      }
      if (content.contains("name: '${_escapeSingle(bundle.name)}'")) {
        _logger.err("Bundle name '${bundle.name}' already exists.");
        return true;
      }
    }

    return false;
  }

  /// Generates the Dart source code for a single [SkillBundle]
  /// constructor call.
  String _generateBundleCode(SkillBundle bundle) {
    final buf = StringBuffer();
    buf.writeln('    SkillBundle(');
    buf.writeln("      id: '${_escapeSingle(bundle.id)}',");
    buf.writeln("      name: '${_escapeSingle(bundle.name)}',");

    // Aliases
    if (bundle.aliases.isNotEmpty) {
      final aliasLiterals =
          bundle.aliases.map((a) => "'${_escapeSingle(a)}'").join(', ');
      buf.writeln('      aliases: [$aliasLiterals],');
    }

    buf.writeln("      displayName: '${_escapeSingle(bundle.displayName)}',");

    // Description: use adjacent string literals to match existing style
    final descParts = _wrapDescription(bundle.description);
    if (descParts.length == 1) {
      buf.writeln("      description: '${_escapeSingle(descParts.first)}',");
    } else {
      buf.writeln('      description:');
      for (var i = 0; i < descParts.length; i++) {
        final trailing = i < descParts.length - 1 ? '' : ',';
        buf.writeln(
          "          '${_escapeSingle(descParts[i])}'$trailing",
        );
      }
    }

    buf.writeln('      planRelativePath:');
    buf.writeln("          '${_escapeSingle(bundle.planRelativePath)}',");
    buf.writeln('      rulesDirectory:');
    buf.writeln("          '${_escapeSingle(bundle.rulesDirectory)}',");

    if (bundle.workflowPath != null) {
      buf.writeln('      workflowPath:');
      buf.writeln("          '${_escapeSingle(bundle.workflowPath!)}',");
    }

    if (bundle.templatePath != null) {
      buf.writeln('      templatePath:');
      buf.writeln("          '${_escapeSingle(bundle.templatePath!)}',");
    }

    buf.write('    ),');
    return buf.toString();
  }

  /// Wraps a description string into ~60-char lines for adjacent
  /// string literals.
  List<String> _wrapDescription(String description) {
    const maxLen = 58; // leave room for quotes and indentation
    final words = description.split(' ');
    final lines = <String>[];
    var current = StringBuffer();

    for (final word in words) {
      if (current.isEmpty) {
        current.write(word);
      } else if (current.length + 1 + word.length <= maxLen) {
        current.write(' $word');
      } else {
        lines.add('${current.toString()} ');
        current = StringBuffer(word);
      }
    }

    if (current.isNotEmpty) {
      lines.add(current.toString());
    }

    return lines;
  }

  /// Escapes a string for embedding in a single-quoted Dart literal.
  /// Order matters: backslash first, otherwise the escape characters
  /// introduced below get double-escaped.
  String _escapeSingle(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll(r'$', r'\$')
      .replaceAll("'", r"\'");
}
