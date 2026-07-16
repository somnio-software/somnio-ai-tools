import 'dart:convert';
import 'dart:io';

/// Status of a single step in the progress tracker.
enum StepStatus { pending, running, completed, failed }

/// Tracks the execution state of a single workflow step.
class StepProgress {
  StepProgress({
    required this.file,
    this.status = StepStatus.pending,
    this.model,
    this.durationSeconds,
  });

  /// Step filename.
  final String file;

  /// Current execution status.
  StepStatus status;

  /// Model used (set after execution).
  String? model;

  /// Duration in seconds (set after execution).
  int? durationSeconds;

  factory StepProgress.fromJson(Map<String, dynamic> json) {
    return StepProgress(
      file: json['file'] as String,
      status: _parseStatus(json['status'] as String? ?? 'pending'),
      model: json['model'] as String?,
      durationSeconds: json['duration_s'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'file': file,
      'status': status.name,
    };
    if (model != null) json['model'] = model;
    if (durationSeconds != null) json['duration_s'] = durationSeconds;
    return json;
  }

  static StepStatus _parseStatus(String s) => switch (s) {
        'running' => StepStatus.running,
        'completed' => StepStatus.completed,
        'failed' => StepStatus.failed,
        _ => StepStatus.pending,
      };
}

/// Tracks the overall execution state of a workflow run.
class WorkflowProgress {
  WorkflowProgress({
    required this.workflow,
    required this.agent,
    required this.steps,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now().toUtc();

  /// Workflow name.
  final String workflow;

  /// Agent ID used for execution.
  final String agent;

  /// When the run started.
  final DateTime startedAt;

  /// Step-level progress tracking.
  final List<StepProgress> steps;

  /// Returns the index of the first non-completed step, or -1 if all done.
  int get nextPendingIndex {
    for (var i = 0; i < steps.length; i++) {
      if (steps[i].status != StepStatus.completed) return i;
    }
    return -1;
  }

  /// Whether all steps have completed successfully.
  bool get isComplete =>
      steps.every((s) => s.status == StepStatus.completed);

  /// Number of completed steps.
  int get completedCount =>
      steps.where((s) => s.status == StepStatus.completed).length;

  /// Total duration of all completed steps in seconds.
  int get totalDurationSeconds => steps.fold(
        0,
        (sum, s) => sum + (s.durationSeconds ?? 0),
      );

  // ── Serialization ──────────────────────────────────────────────────

  factory WorkflowProgress.fromJson(Map<String, dynamic> json) {
    final stepsJson = json['steps'] as List<dynamic>? ?? [];
    return WorkflowProgress(
      workflow: json['workflow'] as String? ?? '',
      agent: json['agent'] as String? ?? '',
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? ''),
      steps: stepsJson
          .map((s) => StepProgress.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'workflow': workflow,
        'agent': agent,
        'started_at': startedAt.toIso8601String(),
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  // ── File I/O ───────────────────────────────────────────────────────

  /// Loads progress from a JSON file.
  ///
  /// Returns null when the file is missing OR unparseable, so callers can
  /// treat both as "no saved progress" instead of crashing on a bad file.
  /// TypeError is caught because the JSON casts throw an Error, not an
  /// Exception, when a field has an unexpected shape.
  static WorkflowProgress? loadFrom(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return WorkflowProgress.fromJson(json);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Saves progress to a JSON file.
  void saveTo(String path) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(toJson()));
  }
}
