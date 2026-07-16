import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// A parsed workflow step file with YAML frontmatter and prompt body.
class WorkflowStep {
  const WorkflowStep({
    required this.name,
    required this.tag,
    required this.index,
    required this.body,
    this.mandatory = false,
    this.needsPrevious = false,
  });

  /// Human-readable step name.
  final String name;

  /// Step tag: 'research', 'planning', or 'execution'.
  final String tag;

  /// 1-based step index.
  final int index;

  /// Whether this step must succeed to continue.
  final bool mandatory;

  /// Whether this step needs the previous step's output.
  final bool needsPrevious;

  /// The prompt body (markdown content after frontmatter).
  final String body;

  // ── Parsing ────────────────────────────────────────────────────────

  /// Parses a step file with YAML frontmatter + markdown body.
  factory WorkflowStep.parse(String content) {
    final trimmed = content.trimLeft();
    if (!trimmed.startsWith('---')) {
      throw const FormatException(
        'Step file must start with YAML frontmatter (---)',
      );
    }

    final endIndex = trimmed.indexOf('---', 3);
    if (endIndex == -1) {
      throw const FormatException(
        'Step file frontmatter must be closed with ---',
      );
    }

    final frontmatterStr = trimmed.substring(3, endIndex).trim();
    final yaml = loadYaml(frontmatterStr) as YamlMap;
    final body = trimmed.substring(endIndex + 3).trim();

    return WorkflowStep(
      name: yaml['name'] as String? ?? '',
      tag: yaml['tag'] as String? ?? 'execution',
      index: yaml['index'] as int? ?? 0,
      mandatory: yaml['mandatory'] as bool? ?? false,
      needsPrevious: yaml['needs_previous'] as bool? ?? false,
      body: body,
    );
  }

  /// Loads and parses a step file from disk.
  ///
  /// Returns null when the file is missing OR unparseable, so callers can
  /// treat both as "no usable step" instead of crashing on a bad file.
  /// TypeError is caught because the frontmatter casts throw an Error, not an
  /// Exception, when a field has an unexpected shape.
  static WorkflowStep? loadFrom(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      return WorkflowStep.parse(file.readAsStringSync());
    } on YamlException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  // ── Placeholder Resolution ─────────────────────────────────────────

  /// Regex matching `{step_N_output}` placeholders (1-based N).
  static final _stepOutputPattern = RegExp(r'\{step_(\d+)_output\}');

  /// Resolves placeholders in the step body.
  ///
  /// Supported placeholders:
  /// - `{output_path}` → path where this step should save output
  /// - `{previous_output}` → path to the previous step's output
  /// - `{outputs_dir}` → the outputs directory
  /// - `{workflow_dir}` → the workflow directory root
  /// - `{step_N_output}` → path to step N's output (1-based)
  String resolveBody({
    required String workflowDir,
    required String outputsDir,
    required String outputPath,
    String? previousOutputPath,
    Map<int, String>? stepOutputPaths,
  }) {
    var resolved = body
        .replaceAll('{output_path}', outputPath)
        .replaceAll('{outputs_dir}', outputsDir)
        .replaceAll('{workflow_dir}', workflowDir);

    if (previousOutputPath != null) {
      resolved = resolved.replaceAll('{previous_output}', previousOutputPath);
    }

    // Resolve {step_N_output} placeholders
    if (stepOutputPaths != null) {
      resolved = resolved.replaceAllMapped(_stepOutputPattern, (match) {
        final stepNum = int.parse(match.group(1)!); // 1-based
        final path = stepOutputPaths[stepNum];
        return path ?? match.group(0)!; // Leave unreplaced if not found
      });
    }

    return resolved;
  }

  /// Derives the output filename from a step file name.
  ///
  /// `01-analyze-dependencies.md` → `01-analyze-dependencies-output.md`
  static String outputFileName(String stepFileName) {
    final base = p.basenameWithoutExtension(stepFileName);
    return '$base-output.md';
  }
}
