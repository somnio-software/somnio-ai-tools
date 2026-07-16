// coverage:ignore-file
import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import '../agents/agent_config.dart';
import '../runner/step_executor.dart';
import 'workflow_step.dart';

/// Result of executing a single workflow step.
class WorkflowStepResult {
  const WorkflowStepResult({
    required this.stepFile,
    required this.success,
    required this.outputPath,
    required this.durationSeconds,
    this.model,
    this.errorMessage,
    this.tokenUsage,
  });

  final String stepFile;
  final bool success;
  final String outputPath;
  final int durationSeconds;
  final String? model;
  final String? errorMessage;
  final TokenUsage? tokenUsage;
}

/// Executes individual workflow steps by spawning AI CLI processes.
///
/// Similar to [StepExecutor] but adapted for user-created workflows:
/// - Steps are standalone markdown files (not rule references)
/// - Prompts use placeholder resolution (not rule file reading)
/// - Output goes to the workflow's outputs/ directory
class WorkflowStepExecutor {
  WorkflowStepExecutor({
    required this.agentConfig,
    required this.logger,
    this.stepTimeout = defaultStepTimeout,
  });

  final AgentConfig agentConfig;
  final Logger logger;

  /// Per-step deadline; a step that outlives it is killed and fails.
  final Duration stepTimeout;

  /// Executes a single workflow step.
  ///
  /// The step's body is sent as the prompt (after placeholder resolution).
  /// The AI saves its output to [outputPath].
  Future<WorkflowStepResult> execute({
    required WorkflowStep step,
    required String stepFile,
    required String resolvedBody,
    required String outputPath,
    String? model,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Ensure outputs directory exists
    final outputDir = File(outputPath).parent;
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Remove any output left by a previous run. The existence check after
    // _runProcess is what proves the AI produced output for *this* invocation;
    // a stale file from an earlier run would satisfy it silently and feed
    // outdated content to every downstream {step_N_output} consumer.
    final outputFile = File(outputPath);
    if (outputFile.existsSync()) {
      outputFile.deleteSync();
    }

    final prompt = _buildPrompt(
      step: step,
      resolvedBody: resolvedBody,
      outputPath: outputPath,
    );

    try {
      final result = await _runProcess(prompt, model: model);
      stopwatch.stop();

      final outputExists = File(outputPath).existsSync();
      final usage = _parseTokenUsage(result.stdout as String);

      return WorkflowStepResult(
        stepFile: stepFile,
        success: result.exitCode == 0 && outputExists,
        outputPath: outputPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        model: model,
        tokenUsage: usage,
        errorMessage: result.exitCode != 0
            ? _describeProcessError(result, model)
            : (!outputExists
                ? 'Output not created: $outputPath'
                : null),
      );
    } on StepTimeoutException catch (e) {
      stopwatch.stop();
      return WorkflowStepResult(
        stepFile: stepFile,
        success: false,
        outputPath: outputPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        model: model,
        errorMessage: e.message,
      );
    } catch (e) {
      stopwatch.stop();
      return WorkflowStepResult(
        stepFile: stepFile,
        success: false,
        outputPath: outputPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        model: model,
        errorMessage: 'Process error: $e',
      );
    }
  }

  // ── Private helpers ────────────────────────────────────────────────

  String _buildPrompt({
    required WorkflowStep step,
    required String resolvedBody,
    required String outputPath,
  }) {
    final outputDir = File(outputPath).parent.path;

    return 'You are executing step ${step.index}: "${step.name}".\n\n'
        '$resolvedBody\n\n'
        'IMPORTANT: You MUST save your output to: $outputPath\n'
        'Create the directory if it does not exist:\n'
        'mkdir -p $outputDir';
  }

  /// Spawns the AI CLI for one step, bounded by [stepTimeout].
  ///
  /// Shares [runBoundedProcess] with the audit runner: a hung workflow step
  /// would otherwise block the whole workflow forever.
  ///
  /// Throws [StepTimeoutException] if the process outlives [stepTimeout].
  Future<ProcessResult> _runProcess(String prompt, {String? model}) {
    return runBoundedProcess(
      agentConfig.binary!,
      agentConfig.buildArgs(prompt, model: model),
      workingDirectory: Directory.current.path,
      timeout: stepTimeout,
    );
  }

  String _describeProcessError(ProcessResult result, String? model) {
    final stderr = (result.stderr as String? ?? '').toLowerCase();
    final stdout = (result.stdout as String? ?? '').toLowerCase();
    final combined = '$stderr $stdout';

    if (combined.contains('not_found') ||
        combined.contains('model not found')) {
      return 'Model "${model ?? "default"}" not found. '
          'Verify the model name is correct.';
    }

    if (combined.contains('capacity') ||
        combined.contains('resource_exhausted') ||
        combined.contains('rate_limit') ||
        combined.contains('429')) {
      return 'No capacity available for model "${model ?? "default"}". '
          'Try a different model.';
    }

    if (combined.contains('unauthenticated') ||
        combined.contains('permission_denied') ||
        combined.contains('401') ||
        combined.contains('403')) {
      return 'Authentication failed. '
          'Verify you are logged in to ${agentConfig.displayName}.';
    }

    return 'Process exited with code ${result.exitCode}';
  }

  TokenUsage? _parseTokenUsage(String stdout) {
    final parser = agentConfig.tokenUsageParser;
    if (parser == null) return null;

    try {
      final json = jsonDecode(stdout) as Map<String, dynamic>;
      return parser(json);
    } catch (_) {
      return null;
    }
  }
}