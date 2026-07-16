import 'dart:io';

import 'package:yaml/yaml.dart';

/// A step entry from the context.md frontmatter.
class WorkflowStepEntry {
  const WorkflowStepEntry({
    required this.file,
    required this.tag,
    this.mandatory = false,
    this.needs = const [],
  });

  /// Step filename (e.g., '01-analyze-dependencies.md').
  final String file;

  /// Step tag: 'research', 'planning', or 'execution'.
  final String tag;

  /// Whether this step must succeed for the workflow to continue.
  final bool mandatory;

  /// 0-based indices of steps this step depends on.
  ///
  /// Empty list means the step is independent (no dependencies).
  final List<int> needs;

  /// Whether this step has any dependencies.
  bool get hasDependencies => needs.isNotEmpty;

  /// Backward-compat alias: true if this step depends on the previous step.
  bool get needsPrevious => needs.isNotEmpty;

  /// Parses a step entry from YAML frontmatter.
  ///
  /// [index] is the 0-based position of this step in the steps list,
  /// needed for resolving `needs: "all"` and `needs_previous: true`.
  factory WorkflowStepEntry.fromYaml(dynamic yaml, {required int index}) {
    final map = yaml as YamlMap;
    return WorkflowStepEntry(
      file: map['file'] as String,
      tag: map['tag'] as String? ?? 'execution',
      mandatory: map['mandatory'] as bool? ?? false,
      needs: _parseNeeds(map, index),
    );
  }

  Map<String, dynamic> toYaml() {
    final yaml = <String, dynamic>{
      'file': file,
      'tag': tag,
      'mandatory': mandatory,
    };
    if (needs.isNotEmpty) {
      // Store as 1-based for YAML output
      yaml['needs'] = needs.map((i) => i + 1).toList();
    }
    return yaml;
  }

  /// Parses the `needs` field from YAML, with backward compat for
  /// `needs_previous`.
  ///
  /// Returns a list of 0-based step indices.
  static List<int> _parseNeeds(YamlMap map, int index) {
    final needsValue = map['needs'];

    // New `needs` field takes priority
    if (needsValue != null) {
      if (needsValue is YamlList) {
        // needs: [1, 3] — 1-based in YAML, convert to 0-based
        return needsValue.map((v) => (v as int) - 1).toList();
      }
      // Defensive: YAML parsing always yields a YamlList (handled above), so a
      // plain List only reaches here if `needs` is injected programmatically.
      // coverage:ignore-start
      if (needsValue is List) {
        return (needsValue).map((v) => (v as int) - 1).toList();
      }
      // coverage:ignore-end
      if (needsValue is String) {
        if (needsValue == 'all') {
          // Depends on every step before this one
          return List.generate(index, (i) => i);
        }
        if (needsValue == 'previous') {
          return index > 0 ? [index - 1] : [];
        }
      }
      if (needsValue is int) {
        // Single int: needs: 1
        return [needsValue - 1];
      }
      // Unrecognized shape: fail loud rather than silently dropping the
      // dependency edge (which would place this step in the same wave as the
      // step it depends on).
      throw FormatException(
        'Step ${index + 1} (${map['file']}) has an invalid `needs` value: '
        '"$needsValue". Valid forms: a list ([1, 3]), a single int (1), '
        '"all", or "previous".',
      );
    }

    // Backward compat: needs_previous: true → depends on previous step
    final needsPreviousValue = map['needs_previous'] as bool? ?? false;
    if (needsPreviousValue && index > 0) {
      return [index - 1];
    }

    return const [];
  }
}

/// Parsed context.md manifest for a workflow.
///
/// Contains metadata (name, description, version) and the ordered step list.
class WorkflowContext {
  const WorkflowContext({
    required this.name,
    required this.description,
    required this.steps,
    this.created,
    this.version = 1,
  });

  /// Workflow name (kebab-case).
  final String name;

  /// Human-readable description.
  final String description;

  /// When the workflow was created.
  final DateTime? created;

  /// Schema version.
  final int version;

  /// Ordered list of step entries.
  final List<WorkflowStepEntry> steps;

  // ── Parsing ────────────────────────────────────────────────────────

  /// Parses a context.md file with YAML frontmatter.
  ///
  /// Expects the file to start with `---`, contain YAML, then `---`.
  factory WorkflowContext.parse(String content) {
    final frontmatter = _extractFrontmatter(content);
    if (frontmatter == null) {
      throw const FormatException(
        'context.md must start with YAML frontmatter (---)',
      );
    }

    final yaml = loadYaml(frontmatter) as YamlMap;

    final name = yaml['name'] as String? ?? '';
    final description = yaml['description'] as String? ?? '';
    final version = yaml['version'] as int? ?? 1;

    DateTime? created;
    if (yaml['created'] != null) {
      created = DateTime.tryParse(yaml['created'].toString());
    }

    final stepsYaml = yaml['steps'] as YamlList? ?? YamlList();
    final steps = <WorkflowStepEntry>[];
    for (var i = 0; i < stepsYaml.length; i++) {
      steps.add(WorkflowStepEntry.fromYaml(stepsYaml[i], index: i));
    }

    return WorkflowContext(
      name: name,
      description: description,
      created: created,
      version: version,
      steps: steps,
    );
  }

  /// Loads and parses a context.md file from disk.
  ///
  /// Returns null when the file is missing OR unparseable, so callers can
  /// treat both as "no usable context" instead of crashing on a bad file.
  /// TypeError is caught because the frontmatter casts throw an Error, not an
  /// Exception, when a field has an unexpected shape.
  static WorkflowContext? loadFrom(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      return WorkflowContext.parse(file.readAsStringSync());
    } on YamlException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  // ── Private ────────────────────────────────────────────────────────

  /// Extracts YAML frontmatter between `---` delimiters.
  static String? _extractFrontmatter(String content) {
    final trimmed = content.trimLeft();
    if (!trimmed.startsWith('---')) return null;

    final endIndex = trimmed.indexOf('---', 3);
    if (endIndex == -1) return null;

    return trimmed.substring(3, endIndex).trim();
  }
}
