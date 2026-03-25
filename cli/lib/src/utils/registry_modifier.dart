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

    // Find the closing `];` of the skills list.
    // The pattern is `\n  ];` (2-space indented closing bracket).
    final insertIndex = original.lastIndexOf('\n  ];');
    if (insertIndex == -1) {
      throw StateError(
        'Cannot find insertion point in skill_registry.dart.\n'
        'Expected to find "  ];" closing the skills list.',
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

    _logger.detail('  Updated: ${p.relative(_registryPath, from: repoRoot)}');
  }

  /// Checks if any of the given bundles conflict with existing
  /// entries in the registry file.
  bool hasConflicts(List<SkillBundle> bundles) {
    final file = File(_registryPath);
    final content = file.readAsStringSync();

    for (final bundle in bundles) {
      if (content.contains("id: '${bundle.id}'")) {
        _logger.err("Bundle ID '${bundle.id}' already exists.");
        return true;
      }
      if (content.contains("name: '${bundle.name}'")) {
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
    buf.writeln("      id: '${bundle.id}',");
    buf.writeln("      name: '${bundle.name}',");

    // Aliases
    if (bundle.aliases.isNotEmpty) {
      final aliasLiterals =
          bundle.aliases.map((a) => "'$a'").join(', ');
      buf.writeln('      aliases: [$aliasLiterals],');
    }

    buf.writeln("      displayName: '${bundle.displayName}',");

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
    buf.writeln("          '${bundle.planRelativePath}',");
    buf.writeln('      rulesDirectory:');
    buf.writeln("          '${bundle.rulesDirectory}',");

    if (bundle.workflowPath != null) {
      buf.writeln('      workflowPath:');
      buf.writeln("          '${bundle.workflowPath}',");
    }

    if (bundle.templatePath != null) {
      buf.writeln('      templatePath:');
      buf.writeln("          '${bundle.templatePath}',");
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

  /// Escapes single quotes in a string for Dart string literals.
  String _escapeSingle(String s) => s.replaceAll("'", r"\'");
}
