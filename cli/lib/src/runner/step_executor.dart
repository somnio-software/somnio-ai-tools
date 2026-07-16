// coverage:ignore-file
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../version.dart';
import 'run_config.dart';

/// Signature for spawning an AI CLI process. Matches [Process.start].
typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
});

/// Default wall-clock deadline for a single AI CLI invocation.
///
/// AI audit steps legitimately take minutes, so the deadline is generous —
/// it only exists to break out of an agent that hangs forever.
const defaultStepTimeout = Duration(minutes: 30);

/// Grace period granted between SIGTERM and SIGKILL when killing a step.
const _killGracePeriod = Duration(seconds: 5);

/// Thrown when a spawned AI CLI process outlives its deadline and is killed.
class StepTimeoutException implements Exception {
  const StepTimeoutException({
    required this.executable,
    required this.timeout,
  });

  /// Binary that was spawned (e.g., 'claude').
  final String executable;

  /// Deadline that expired.
  final Duration timeout;

  String get message => 'Step timed out after ${timeout.inSeconds}s; '
      '$executable process killed';

  @override
  String toString() => message;
}

/// Runs [executable] to completion and returns its buffered output, killing
/// the process if it outlives [timeout].
///
/// Unlike [Process.run] the wait is bounded: a hung AI CLI would otherwise
/// block the whole audit forever. stdout/stderr are drained while the child
/// runs (a chatty child that fills the pipe buffer would deadlock otherwise),
/// and stdin is closed so the child cannot block on an interactive prompt.
///
/// Throws [StepTimeoutException] when the deadline expires.
Future<ProcessResult> runBoundedProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  Duration timeout = defaultStepTimeout,
  Duration killGracePeriod = _killGracePeriod,
  ProcessStarter processStarter = Process.start,
}) async {
  final process = await processStarter(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );

  unawaited(process.stdin.close().catchError((Object _) {}));

  final stdoutFuture = _drain(process.stdout);
  final stderrFuture = _drain(process.stderr);

  try {
    final exitCode = await process.exitCode.timeout(timeout);
    return ProcessResult(
      process.pid,
      exitCode,
      await stdoutFuture,
      await stderrFuture,
    );
  } on TimeoutException {
    process.kill();
    try {
      await process.exitCode.timeout(killGracePeriod);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    }
    throw StepTimeoutException(executable: executable, timeout: timeout);
  }
}

/// Collects a process output stream into a string as it is produced.
Future<String> _drain(Stream<List<int>> stream) =>
    stream.transform(systemEncoding.decoder).join().catchError(
          (Object _) => '',
        );

/// Token usage statistics from an AI CLI invocation.
class TokenUsage {
  const TokenUsage({
    required this.inputTokens,
    required this.outputTokens,
    this.cacheReadTokens = 0,
    this.cacheCreationTokens = 0,
    this.costUsd,
  });

  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;
  final double? costUsd;

  /// Total input tokens including cache.
  int get totalInputTokens =>
      inputTokens + cacheReadTokens + cacheCreationTokens;
}

/// Result of executing a single step.
class StepResult {
  const StepResult({
    required this.step,
    required this.success,
    required this.artifactPath,
    required this.durationSeconds,
    this.errorMessage,
    this.tokenUsage,
  });

  final ExecutionStep step;
  final bool success;
  final String artifactPath;
  final int durationSeconds;
  final String? errorMessage;
  final TokenUsage? tokenUsage;
}

/// Executes individual plan steps by invoking an AI CLI in a fresh context.
///
/// Each step spawns a separate process using [AgentConfig.buildArgs],
/// which ensures a fresh context window per step. The AI reads the
/// rule file and saves findings as an artifact on disk.
class StepExecutor {
  StepExecutor({
    required this.config,
    required this.logger,
    ProcessStarter? processStarter,
    this.stepTimeout = defaultStepTimeout,
  }) : _processStarter = processStarter ?? Process.start;

  final RunConfig config;
  final Logger logger;
  final ProcessStarter _processStarter;

  /// Wall-clock deadline for a single AI CLI invocation.
  ///
  /// A step that exceeds it is killed and reported as a failed [StepResult]
  /// instead of hanging the whole run.
  final Duration stepTimeout;

  /// Fallback model to use when the primary model hits quota limits.
  ///
  /// Set by the caller (RunCommand) based on the agent's cheapest model.
  String? fallbackModel;

  /// Resolves the effective per-step base model for [step].
  ///
  /// When the step carries a tier (`step.model`), it is resolved via the
  /// agent's [AgentConfig.resolveTier]; otherwise the run-level [RunConfig.model]
  /// is used. When the tier is not resolvable for this agent, the run-level
  /// model is used instead. The returned value becomes the model passed to the
  /// CLI for that step (before any quota fallback retry).
  String? _stepBaseModel(ExecutionStep step) {
    if (step.model != null) {
      return config.agentConfig.resolveTier(step.model!) ?? config.model;
    }
    return config.model;
  }

  /// Executes a single standard step.
  ///
  /// The AI CLI reads the rule file and saves findings as an artifact.
  Future<StepResult> execute(ExecutionStep step) async {
    final stopwatch = Stopwatch()..start();
    final artifactPath = _artifactPath(step);

    // Verify rule file exists before spawning process
    final ruleFile = _ruleFilePath(step.ruleName);
    if (!File(ruleFile).existsSync()) {
      stopwatch.stop();
      return StepResult(
        step: step,
        success: false,
        artifactPath: artifactPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        errorMessage: 'Rule file not found: $ruleFile',
      );
    }

    final prompt = _buildStepPrompt(step, ruleFile, artifactPath);
    final baseModel = _stepBaseModel(step);
    var effectiveModel = baseModel;

    try {
      var result = await _runProcess(
        prompt,
        modelOverride: baseModel,
        artifactPath: artifactPath,
      );

      // Fallback: retry with cheapest model on quota/capacity errors
      if (result.exitCode != 0 &&
          fallbackModel != null &&
          fallbackModel != baseModel &&
          _isQuotaError(result)) {
        logger.info(
          '  Quota exceeded for "$baseModel", '
          'retrying with "$fallbackModel"...',
        );
        effectiveModel = fallbackModel;
        result = await _runProcess(
          prompt,
          modelOverride: fallbackModel,
          artifactPath: artifactPath,
        );
      }

      stopwatch.stop();

      final artifactExists = File(artifactPath).existsSync();
      final usage = _parseTokenUsage(result.stdout as String);

      return StepResult(
        step: step,
        success: result.exitCode == 0 && artifactExists,
        artifactPath: artifactPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        tokenUsage: usage,
        errorMessage: result.exitCode != 0
            ? _describeProcessError(result, effectiveModel)
            : (!artifactExists
                ? 'Artifact not created: $artifactPath'
                : null),
      );
    } on StepTimeoutException catch (e) {
      stopwatch.stop();
      return StepResult(
        step: step,
        success: false,
        artifactPath: artifactPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        errorMessage: e.message,
      );
    } catch (e) {
      stopwatch.stop();
      return StepResult(
        step: step,
        success: false,
        artifactPath: artifactPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        errorMessage: 'Process error: $e',
      );
    }
  }

  /// Writes a pre-flight artifact directly to disk, skipping AI invocation.
  ///
  /// Used when the CLI pre-flight already completed this step's work
  /// (e.g., tool installation, version alignment, test coverage).
  Future<StepResult> writePreflightArtifact(
    ExecutionStep step,
    String content,
  ) async {
    final artifactPath = _artifactPath(step);
    try {
      File(artifactPath).writeAsStringSync(content);
      return StepResult(
        step: step,
        success: true,
        artifactPath: artifactPath,
        durationSeconds: 0,
      );
    } catch (e) {
      return StepResult(
        step: step,
        success: false,
        artifactPath: artifactPath,
        durationSeconds: 0,
        errorMessage: 'Failed to write pre-flight artifact: $e',
      );
    }
  }

  /// Executes the report generator step (special handling).
  ///
  /// This step reads all previous artifacts and the report template,
  /// then generates the final audit report.
  Future<StepResult> executeReportGenerator(ExecutionStep step) async {
    final stopwatch = Stopwatch()..start();
    final reportPath = config.reportPath;

    // Verify rule file exists
    final ruleFile = _ruleFilePath(step.ruleName);
    if (!File(ruleFile).existsSync()) {
      stopwatch.stop();
      return StepResult(
        step: step,
        success: false,
        artifactPath: reportPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        errorMessage: 'Rule file not found: $ruleFile',
      );
    }

    final prompt = _buildReportPrompt(step, ruleFile, reportPath);
    final baseModel = _stepBaseModel(step);
    var effectiveModel = baseModel;

    try {
      var result = await _runProcess(prompt, modelOverride: baseModel);

      // Fallback: retry with cheapest model on quota/capacity errors
      if (result.exitCode != 0 &&
          fallbackModel != null &&
          fallbackModel != baseModel &&
          _isQuotaError(result)) {
        logger.info(
          '  Quota exceeded for "$baseModel", '
          'retrying with "$fallbackModel"...',
        );
        effectiveModel = fallbackModel;
        result = await _runProcess(prompt, modelOverride: fallbackModel);
      }

      stopwatch.stop();

      final reportExists = File(reportPath).existsSync();
      final usage = _parseTokenUsage(result.stdout as String);

      return StepResult(
        step: step,
        success: result.exitCode == 0 && reportExists,
        artifactPath: reportPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        tokenUsage: usage,
        errorMessage: result.exitCode != 0
            ? _describeProcessError(result, effectiveModel)
            : (!reportExists
                ? 'Report not created: $reportPath'
                : null),
      );
    } on StepTimeoutException catch (e) {
      stopwatch.stop();
      return StepResult(
        step: step,
        success: false,
        artifactPath: reportPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        errorMessage: e.message,
      );
    } catch (e) {
      stopwatch.stop();
      return StepResult(
        step: step,
        success: false,
        artifactPath: reportPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        errorMessage: 'Process error: $e',
      );
    }
  }

  /// Executes the format enforcer on the generated report (post-processing).
  ///
  /// Reads the generated report, validates it against the format enforcer
  /// rules, fixes any issues, and writes the corrected report back.
  /// Returns success even if the enforcer rule is missing (soft dependency).
  Future<StepResult> executeFormatEnforcer(
    ExecutionStep step,
    String enforcerRuleName,
  ) async {
    final stopwatch = Stopwatch()..start();
    final reportPath = config.reportPath;

    // Verify enforcer rule file exists — skip gracefully if missing
    final ruleFile = _ruleFilePath(enforcerRuleName);
    if (!File(ruleFile).existsSync()) {
      stopwatch.stop();
      return StepResult(
        step: step,
        success: true,
        artifactPath: reportPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        errorMessage: 'Format enforcer not found: $ruleFile (skipped)',
      );
    }

    // Verify report exists before enforcing
    if (!File(reportPath).existsSync()) {
      stopwatch.stop();
      return StepResult(
        step: step,
        success: false,
        artifactPath: reportPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        errorMessage: 'Report not found for format enforcement: $reportPath',
      );
    }

    final prompt = _buildFormatEnforcerPrompt(ruleFile, reportPath);
    final baseModel = _stepBaseModel(step);
    var effectiveModel = baseModel;

    try {
      var result = await _runProcess(prompt, modelOverride: baseModel);

      // Fallback: retry with cheapest model on quota/capacity errors
      if (result.exitCode != 0 &&
          fallbackModel != null &&
          fallbackModel != baseModel &&
          _isQuotaError(result)) {
        logger.info(
          '  Quota exceeded for "$baseModel", '
          'retrying with "$fallbackModel"...',
        );
        effectiveModel = fallbackModel;
        result = await _runProcess(prompt, modelOverride: fallbackModel);
      }

      stopwatch.stop();

      final reportExists = File(reportPath).existsSync();
      final usage = _parseTokenUsage(result.stdout as String);

      return StepResult(
        step: step,
        success: result.exitCode == 0 && reportExists,
        artifactPath: reportPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        tokenUsage: usage,
        errorMessage: result.exitCode != 0
            ? _describeProcessError(result, effectiveModel)
            : null,
      );
    } on StepTimeoutException catch (e) {
      stopwatch.stop();
      return StepResult(
        step: step,
        success: false,
        artifactPath: reportPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        errorMessage: e.message,
      );
    } catch (e) {
      stopwatch.stop();
      return StepResult(
        step: step,
        success: false,
        artifactPath: reportPath,
        durationSeconds: stopwatch.elapsed.inSeconds,
        errorMessage: 'Process error: $e',
      );
    }
  }

  // --- Private helpers ---

  /// Produces a human-readable error message from a failed AI CLI process.
  ///
  /// [model] is the model the failed attempt actually ran with — a per-step
  /// tier or the quota fallback, not necessarily [RunConfig.model].
  String _describeProcessError(ProcessResult result, String? model) {
    final stderr = (result.stderr as String? ?? '').toLowerCase();
    final stdout = (result.stdout as String? ?? '').toLowerCase();
    final combined = '$stderr $stdout';
    final label = model != null
        ? '"$model"'
        : 'the ${config.agentConfig.displayName} default model';

    if (combined.contains('not_found') ||
        combined.contains('model not found') ||
        combined.contains('requested entity was not found')) {
      return 'Model $label not found. '
          'Verify the model name is correct or try a different model.';
    }

    if (combined.contains('capacity') ||
        combined.contains('resource_exhausted') ||
        combined.contains('rate_limit') ||
        combined.contains('429')) {
      return 'No capacity available for model $label. '
          'You may not have an active subscription or sufficient quota '
          'for this model. Try a different model.';
    }

    if (combined.contains('unauthenticated') ||
        combined.contains('permission_denied') ||
        combined.contains('401') ||
        combined.contains('403')) {
      return 'Authentication failed. '
          'Verify you are logged in to the '
          '${config.agentConfig.displayName} CLI.';
    }

    return 'Process exited with code ${result.exitCode}';
  }

  /// Returns `true` if the process failed due to quota or capacity limits.
  bool _isQuotaError(ProcessResult result) {
    final combined =
        '${(result.stderr as String? ?? '')} ${(result.stdout as String? ?? '')}'
            .toLowerCase();
    return combined.contains('capacity') ||
        combined.contains('resource_exhausted') ||
        combined.contains('rate_limit') ||
        combined.contains('not_found') ||
        combined.contains('requested entity was not found') ||
        combined.contains('429');
  }

  String _ruleFilePath(String ruleName) {
    final ext = config.agentConfig.ruleExtension;
    return p.join(config.ruleBasePath, '$ruleName$ext');
  }

  String _artifactPath(ExecutionStep step) {
    final paddedIndex = step.index.toString().padLeft(2, '0');
    return p.join(
      config.artifactsDir,
      'step_${paddedIndex}_${step.ruleName}.md',
    );
  }

  String _buildStepPrompt(
    ExecutionStep step,
    String ruleFile,
    String artifactPath,
  ) {
    final readInstruction =
        config.agentConfig.formatReadInstruction(ruleFile);

    return 'You are executing step ${step.index} of ${config.steps.length} '
        'in the ${config.displayName}.\n\n'
        '$readInstruction\n\n'
        'Save your complete findings to: $artifactPath\n'
        'Include: status, key findings, evidence (file paths and line numbers), '
        'and any scores.\n\n'
        'Create the directory if it does not exist:\n'
        'mkdir -p ${config.artifactsDir}\n\n'
        'IMPORTANT: You MUST write your findings to the artifact file above.';
  }

  String _buildReportPrompt(
    ExecutionStep step,
    String ruleFile,
    String reportPath,
  ) {
    final readInstruction =
        config.agentConfig.formatReadInstruction(ruleFile);

    final reportDir = p.dirname(reportPath);

    return 'You are generating the final audit report for the '
        '${config.displayName}.\n\n'
        'EXECUTION ORDER — follow these steps exactly:\n\n'
        'STEP 1: Read the rule file and template\n'
        '$readInstruction\n'
        'Read ${config.templatePath} for the report format template.\n\n'
        'STEP 2: Read ALL artifact files\n'
        'Read ALL files in ${config.artifactsDir}/ to gather findings '
        'from all previous analysis steps.\n\n'
        'STEP 3: Compute scores BEFORE writing anything\n'
        'The rule file contains MANDATORY scoring rubrics. You MUST:\n'
        '- Extract scoring data from each artifact file\n'
        '- Compute each of the 5 section scores using the rubrics\n'
        '- Compute the weighted Overall Score using the formula\n'
        '- Determine score labels (Strong/Fair/Weak/Critical) for each\n'
        '- Sort the 5 scored sections by score ascending (lowest first)\n'
        'A report without computed scores is INVALID and must not '
        'be produced.\n\n'
        'STEP 4: Write the report\n'
        'Generate the complete report following the template structure.\n'
        'Every scored section MUST include: Score, Score Breakdown '
        '(showing Base, deductions/additions, Final), Key Findings, '
        'Evidence, Risks, and Recommendations.\n\n'
        'STEP 5: Add report metadata footer\n'
        'The report MUST end with this exact metadata block:\n'
        '---\n'
        'Generated by: Somnio CLI v$packageVersion\n'
        'Skill: ${config.bundleName}\n'
        'Date: [today\'s date in YYYY-MM-DD format]\n'
        'Somnio AI Tools: '
        'https://github.com/somnio-software/somnio-ai-tools\n'
        '---\n\n'
        'Save the final report to: $reportPath\n'
        'Follow the formatting rules from the rule file and the template '
        'structure exactly.\n\n'
        'Create the directory if it does not exist:\n'
        'mkdir -p $reportDir\n\n'
        'IMPORTANT: You MUST write the complete report to the file above.';
  }

  String _buildFormatEnforcerPrompt(String ruleFile, String reportPath) {
    final readInstruction =
        config.agentConfig.formatReadInstruction(ruleFile);

    return 'You are validating and enforcing formatting on the '
        '${config.displayName} report.\n\n'
        'STEP 1: Read the rules and report\n'
        '$readInstruction\n'
        'Read ${config.templatePath} for the expected report structure.\n'
        'Read the generated report at: $reportPath\n\n'
        'STEP 2: Run ALL structural validation checks from the rule file\n'
        'The rule file contains specific checks that MUST pass. '
        'Validate each one against the report content.\n\n'
        'STEP 3: Run score validation\n'
        '- Verify all scored sections have "Score:" lines with '
        '[Score]/100 ([Label]) format\n'
        '- Verify score labels match score ranges '
        '(85-100=Strong, 70-84=Fair, 50-69=Weak, 0-49=Critical)\n'
        '- Verify scores are consistent across sections\n\n'
        'STEP 4: Fix formatting issues\n'
        '- Apply the FORMATTING RULES defined in the rule file you read '
        'in STEP 1\n'
        '- Ensure section headers and structure match the template exactly\n\n'
        'STEP 5: Write the validated report\n'
        'If ALL structural checks pass, write the corrected report to: '
        '$reportPath\n'
        'If checks FAIL, still write the report but prepend a '
        '"VALIDATION WARNINGS" section listing what failed.\n\n'
        'IMPORTANT: You MUST write the result to the file above.';
  }

  /// Spawns the AI CLI process for a step.
  ///
  /// When [artifactPath] is provided, it is exported as the
  /// `SOMNIO_ARTIFACT_FILE` environment variable so that shell scripts
  /// embedded in rule files can resolve the artifact path without relying
  /// on the model substituting it into the script. The parent environment
  /// is preserved (merged), not replaced.
  ///
  /// Throws [StepTimeoutException] if the process outlives [stepTimeout].
  Future<ProcessResult> _runProcess(
    String prompt, {
    String? modelOverride,
    String? artifactPath,
  }) {
    final model = modelOverride ?? config.model;
    final agent = config.agentConfig;
    final args = agent.buildArgs(prompt, model: model);
    return runBoundedProcess(
      agent.binary!,
      args,
      workingDirectory: Directory.current.path,
      environment: artifactPath == null
          ? null
          : {'SOMNIO_ARTIFACT_FILE': artifactPath},
      timeout: stepTimeout,
      processStarter: _processStarter,
    );
  }

  /// Parses token usage from the JSON stdout of an AI CLI invocation.
  ///
  /// Returns `null` if parsing fails or the agent doesn't expose token data.
  TokenUsage? _parseTokenUsage(String stdout) {
    final parser = config.agentConfig.tokenUsageParser;
    if (parser == null) return null;

    try {
      final json = jsonDecode(stdout) as Map<String, dynamic>;
      return parser(json);
    } catch (_) {
      return null;
    }
  }
}