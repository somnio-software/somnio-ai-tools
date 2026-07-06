// coverage:ignore-file
import 'package:mason_logger/mason_logger.dart';

import '../agents/agent_config.dart';
import 'workflow_config.dart';
import 'workflow_context.dart';
import 'workflow_locator.dart';
import 'workflow_progress.dart';
import 'workflow_step.dart';
import 'workflow_step_executor.dart';
import 'workflow_wave_planner.dart';

/// Result of executing a single step within a wave.
class _WaveStepResult {
  const _WaveStepResult({
    required this.stepIndex,
    required this.result,
  });

  /// 0-based step index.
  final int stepIndex;

  /// The execution result.
  final WorkflowStepResult result;
}

/// Orchestrates the execution of a workflow using wave-based parallelism.
///
/// Steps are grouped into concurrent waves based on their dependencies.
/// Within each wave, all steps run in parallel via [Future.wait].
/// Between waves, progress is saved and mandatory failures abort execution.
class WorkflowRunner {
  WorkflowRunner({
    required this.location,
    required this.context,
    required this.config,
    required this.agentConfig,
    required this.logger,
  });

  final WorkflowLocation location;
  final WorkflowContext context;
  final WorkflowConfig config;
  final AgentConfig agentConfig;
  final Logger logger;

  /// Runs all pending steps in the workflow using wave-based parallelism.
  ///
  /// If [startFromIndex] is provided, skips completed steps up to that index.
  /// Returns the overall success status.
  Future<WorkflowRunResult> run({int startFromIndex = 0}) async {
    final wallClock = Stopwatch()..start();

    final executor = WorkflowStepExecutor(
      agentConfig: agentConfig,
      logger: logger,
    );

    // Initialize or load progress
    final loaded = WorkflowProgress.loadFrom(location.progressPath);
    final progress = (loaded != null && startFromIndex != 0)
        ? loaded
        : WorkflowProgress(
            workflow: context.name,
            agent: agentConfig.id,
            steps: context.steps
                .map((s) => StepProgress(file: s.file))
                .toList(),
          );
    progress.saveTo(location.progressPath);

    // Plan waves
    const planner = WavePlanner();
    final waves = planner.plan(context.steps);
    final totalSteps = context.steps.length;
    final allResults = <WorkflowStepResult>[];

    // Track output paths for {step_N_output} placeholder resolution
    // Key: 1-based step number, Value: output path
    final stepOutputPaths = <int, String>{};

    // Pre-populate output paths for already-completed steps
    for (var i = 0; i < totalSteps; i++) {
      if (progress.steps[i].status == StepStatus.completed) {
        stepOutputPaths[i + 1] = location.outputPath(context.steps[i].file);
      }
    }

    for (var waveIdx = 0; waveIdx < waves.length; waveIdx++) {
      final wave = waves[waveIdx];

      // Filter out already-completed steps (for resume support)
      final pendingIndices = wave.stepIndices.where((i) {
        return progress.steps[i].status != StepStatus.completed;
      }).toList();

      if (pendingIndices.isEmpty) continue;

      // Log wave start
      final waveNum = waveIdx + 1;
      final totalWaves = waves.length;
      logger.info('');
      logger.info(
        'Wave $waveNum/$totalWaves (${pendingIndices.length} '
        '${pendingIndices.length == 1 ? "step" : "steps"})',
      );
      final waveProgress = logger.progress('Running wave $waveNum/$totalWaves');

      // Execute all steps in this wave concurrently
      final futures = <Future<_WaveStepResult>>[];
      for (final stepIdx in pendingIndices) {
        futures.add(
          _executeStep(
            executor: executor,
            stepIndex: stepIdx,
            totalSteps: totalSteps,
            progress: progress,
            stepOutputPaths: stepOutputPaths,
          ),
        );
      }

      final waveResults = await Future.wait(futures);

      // Process results
      waveProgress.complete('Wave $waveNum/$totalWaves completed');

      String? mandatoryFailure;
      String? failedStep;

      for (final wr in waveResults) {
        final stepIdx = wr.stepIndex;
        final result = wr.result;
        final stepEntry = context.steps[stepIdx];
        final stepNum = stepIdx + 1;
        final modelLabel = result.model != null ? ', ${result.model}' : '';

        allResults.add(result);

        if (result.success) {
          progress.steps[stepIdx].status = StepStatus.completed;
          progress.steps[stepIdx].durationSeconds = result.durationSeconds;
          stepOutputPaths[stepNum] = result.outputPath;
          logger.info(
            '  ${lightGreen.wrap('✓')} Step $stepNum/$totalSteps: '
            '${_stepName(stepIdx)}$modelLabel'
            ', ${result.durationSeconds}s)',
          );
        } else {
          progress.steps[stepIdx].status = StepStatus.failed;
          progress.steps[stepIdx].durationSeconds = result.durationSeconds;
          logger.info(
            '  ${red.wrap('✗')} Step $stepNum/$totalSteps: '
            '${_stepName(stepIdx)} - FAILED',
          );
          if (result.errorMessage != null) {
            logger.err('    ${result.errorMessage}');
          }

          if (stepEntry.mandatory) {
            mandatoryFailure = 'Mandatory step failed: ${stepEntry.file}'
                '${result.errorMessage != null ? " - ${result.errorMessage}" : ""}';
            failedStep = stepEntry.file;
          } else {
            logger.warn('    Non-mandatory step failed, continuing...');
          }
        }
      }

      // Save progress once per wave (no concurrent writes)
      progress.saveTo(location.progressPath);

      // Abort if a mandatory step failed
      if (mandatoryFailure != null) {
        wallClock.stop();
        return WorkflowRunResult(
          success: false,
          results: allResults,
          failedStep: failedStep,
          errorMessage: mandatoryFailure,
          wallClockSeconds: wallClock.elapsed.inSeconds,
        );
      }
    }

    wallClock.stop();
    return WorkflowRunResult(
      success: true,
      results: allResults,
      wallClockSeconds: wallClock.elapsed.inSeconds,
    );
  }

  /// Executes a single step and returns the result with its index.
  Future<_WaveStepResult> _executeStep({
    required WorkflowStepExecutor executor,
    required int stepIndex,
    required int totalSteps,
    required WorkflowProgress progress,
    required Map<int, String> stepOutputPaths,
  }) async {
    final stepEntry = context.steps[stepIndex];
    final stepNum = stepIndex + 1; // 1-based

    // Parse step file
    final stepPath = location.stepPath(stepEntry.file);
    final step = WorkflowStep.loadFrom(stepPath);
    if (step == null) {
      return _WaveStepResult(
        stepIndex: stepIndex,
        result: WorkflowStepResult(
          stepFile: stepEntry.file,
          success: false,
          outputPath: location.outputPath(stepEntry.file),
          durationSeconds: 0,
          errorMessage: 'Step file not found: $stepPath',
        ),
      );
    }

    // Resolve model
    final model = config.resolveModel(stepNum, stepEntry.tag) ??
        agentConfig.defaultModel;

    // Resolve placeholders
    final outputPath = location.outputPath(stepEntry.file);
    String? previousOutputPath;
    if (stepIndex > 0) {
      previousOutputPath = location.outputPath(
        context.steps[stepIndex - 1].file,
      );
    }

    final resolvedBody = step.resolveBody(
      workflowDir: location.path,
      outputsDir: location.outputsDir,
      outputPath: outputPath,
      previousOutputPath: previousOutputPath,
      stepOutputPaths: stepOutputPaths,
    );

    // Update progress to running
    progress.steps[stepIndex].status = StepStatus.running;
    progress.steps[stepIndex].model = model;

    // Execute
    final result = await executor.execute(
      step: step,
      stepFile: stepEntry.file,
      resolvedBody: resolvedBody,
      outputPath: outputPath,
      model: model,
    );

    return _WaveStepResult(
      stepIndex: stepIndex,
      result: result,
    );
  }

  /// Gets the step name from its file, or falls back to the filename.
  String _stepName(int stepIndex) {
    final stepPath = location.stepPath(context.steps[stepIndex].file);
    final step = WorkflowStep.loadFrom(stepPath);
    return step?.name ?? context.steps[stepIndex].file;
  }
}

/// Overall result of a workflow run.
class WorkflowRunResult {
  const WorkflowRunResult({
    required this.success,
    required this.results,
    this.failedStep,
    this.errorMessage,
    this.wallClockSeconds,
  });

  final bool success;
  final List<WorkflowStepResult> results;
  final String? failedStep;
  final String? errorMessage;

  /// Wall-clock time for the entire run (with parallelism).
  final int? wallClockSeconds;

  /// Total compute time (sum of all step durations).
  int get totalDurationSeconds =>
      results.fold(0, (sum, r) => sum + r.durationSeconds);

  int get completedCount => results.where((r) => r.success).length;
}