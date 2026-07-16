// coverage:ignore-file
import 'package:mason_logger/mason_logger.dart';

import '../runner/step_executor.dart' show TokenUsage;

/// Shared token/cost/duration formatting for the `run` and `workflow run`
/// commands, both of which execute a list of AI CLI steps and report an
/// aggregate token usage summary at the end.
class UsageSummary {
  UsageSummary._();

  /// Formats a token count for display, abbreviating thousands.
  ///
  /// Example: `1500` -> `'1.5K'`, `250` -> `'250'`.
  static String formatTokens(int tokens) {
    if (tokens < 1000) return '$tokens';
    final k = tokens / 1000;
    return '${k.toStringAsFixed(1)}K';
  }

  /// Formats a duration in seconds as e.g. `'45s'` or `'3m 12s'`.
  static String formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes}m ${remaining}s';
  }

  /// Prints an aggregate token/cost/time summary box to [logger].
  ///
  /// [tokenUsages] should already be filtered down to steps that actually
  /// invoked an AI CLI (steps without usage data, e.g. pre-flight steps,
  /// are not part of this list). Does nothing if [tokenUsages] is empty.
  ///
  /// [aiTime] and [preflightTime] are optional: when both are provided, the
  /// time line breaks total time down into AI vs. pre-flight; when omitted,
  /// only the total is printed.
  static void printUsageSummary(
    Logger logger,
    List<TokenUsage> tokenUsages, {
    required int totalTime,
    int? aiTime,
    int? preflightTime,
  }) {
    if (tokenUsages.isEmpty) return;

    var totalInput = 0;
    var totalOutput = 0;
    var totalCost = 0.0;
    var hasCost = false;

    for (final usage in tokenUsages) {
      totalInput += usage.totalInputTokens;
      totalOutput += usage.outputTokens;
      if (usage.costUsd != null) {
        totalCost += usage.costUsd!;
        hasCost = true;
      }
    }

    const divider = '────────────────────────────────────────────────────';
    logger.info(divider);
    logger.info(
      'Total tokens  ─  Input: ${formatTokens(totalInput)}  '
      'Output: ${formatTokens(totalOutput)}',
    );
    if (hasCost) {
      logger.info(
        'Total cost    ─  \$${totalCost.toStringAsFixed(2)}',
      );
    }
    if (aiTime != null && preflightTime != null) {
      logger.info(
        'Total time    ─  ${formatDuration(totalTime)}  '
        '(AI: ${formatDuration(aiTime)} | '
        'Pre-flight: ~${formatDuration(preflightTime)})',
      );
    } else {
      logger.info(
        'Total time    ─  ${formatDuration(totalTime)}',
      );
    }
    logger.info(divider);
  }
}
