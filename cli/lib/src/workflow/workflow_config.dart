import 'dart:convert';
import 'dart:io';

/// Model assignment configuration for a workflow.
///
/// Maps step tags (research/planning/execution) to model names,
/// with optional per-step overrides.
class WorkflowConfig {
  const WorkflowConfig({
    required this.ide,
    this.byRole = const {},
    this.byStep = const {},
  });

  /// IDE identifier (e.g., 'claudecode', 'cursor', 'gemini').
  final String ide;

  /// Model assignments by step tag.
  final Map<String, String> byRole;

  /// Model assignments by step index (overrides byRole).
  final Map<int, String> byStep;

  /// Resolves the model for a given step index and tag.
  ///
  /// Resolution order: by_step[index] → by_role[tag] → null (use default).
  String? resolveModel(int stepIndex, String tag) {
    if (byStep.containsKey(stepIndex)) return byStep[stepIndex];
    if (byRole.containsKey(tag)) return byRole[tag];
    return null;
  }

  /// Default role-to-model mapping.
  static const defaultRoleMapping = {
    'research': 'haiku',
    'planning': 'opus',
    'execution': 'sonnet',
  };

  // ── Serialization ──────────────────────────────────────────────────

  factory WorkflowConfig.fromJson(Map<String, dynamic> json) {
    final assignments =
        json['model_assignments'] as Map<String, dynamic>? ?? {};
    final byRoleRaw = assignments['by_role'] as Map<String, dynamic>? ?? {};
    final byStepRaw = assignments['by_step'] as Map<String, dynamic>? ?? {};

    return WorkflowConfig(
      ide: json['ide'] as String? ?? '',
      byRole: byRoleRaw.map((k, v) => MapEntry(k, v as String)),
      byStep: byStepRaw.map((k, v) => MapEntry(int.parse(k), v as String)),
    );
  }

  Map<String, dynamic> toJson() => {
        'ide': ide,
        'model_assignments': {
          'by_role': byRole,
          if (byStep.isNotEmpty)
            'by_step': byStep.map((k, v) => MapEntry(k.toString(), v)),
        },
      };

  // ── File I/O ───────────────────────────────────────────────────────

  /// Reads a config file from disk.
  ///
  /// Returns null when the file is missing OR unparseable, so callers can
  /// treat both as "no usable config" instead of crashing on a bad file.
  /// TypeError is caught because the JSON casts throw an Error, not an
  /// Exception, when a field has an unexpected shape.
  static WorkflowConfig? loadFrom(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return WorkflowConfig.fromJson(json);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Writes this config to disk as formatted JSON.
  void saveTo(String path) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(toJson()));
  }

  /// Returns the config filename for a given agent ID.
  static String configFileName(String agentId) {
    const mapping = {
      'claude': 'config.claudecode.json',
      'cursor': 'config.cursor.json',
      'gemini': 'config.gemini.json',
      'antigravity': 'config.gemini.json',
      'codex': 'config.codex.json',
    };
    return mapping[agentId] ?? 'config.$agentId.json';
  }
}
