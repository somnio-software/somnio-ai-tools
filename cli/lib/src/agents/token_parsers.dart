import '../runner/step_executor.dart';

/// Function type for parsing token usage from CLI JSON output.
typedef TokenUsageParser = TokenUsage? Function(Map<String, dynamic> json);

/// Parses token usage from Claude Code's JSON output.
///
/// Expected structure:
/// ```json
/// {
///   "usage": {
///     "input_tokens": 1234,
///     "output_tokens": 567,
///     "cache_read_input_tokens": 890,
///     "cache_creation_input_tokens": 100
///   },
///   "total_cost_usd": 0.05
/// }
/// ```
TokenUsage? parseClaudeUsage(Map<String, dynamic> json) {
  final usage = json['usage'] as Map<String, dynamic>? ?? {};
  return TokenUsage(
    inputTokens: (usage['input_tokens'] as num?)?.toInt() ?? 0,
    outputTokens: (usage['output_tokens'] as num?)?.toInt() ?? 0,
    cacheReadTokens:
        (usage['cache_read_input_tokens'] as num?)?.toInt() ?? 0,
    cacheCreationTokens:
        (usage['cache_creation_input_tokens'] as num?)?.toInt() ?? 0,
    costUsd: (json['total_cost_usd'] as num?)?.toDouble(),
  );
}

/// Parses token usage from Gemini CLI's JSON output.
///
/// Expected structure:
/// ```json
/// {
///   "stats": {
///     "models": {
///       "gemini-2.5-flash": {
///         "tokens": { "prompt": 1234, "candidates": 567 }
///       }
///     }
///   }
/// }
/// ```
TokenUsage? parseGeminiUsage(Map<String, dynamic> json) {
  final stats = json['stats'] as Map<String, dynamic>? ?? {};
  final models = stats['models'] as Map<String, dynamic>? ?? {};

  var promptTokens = 0;
  var candidateTokens = 0;

  for (final model in models.values) {
    if (model is Map<String, dynamic>) {
      final tokens = model['tokens'] as Map<String, dynamic>? ?? {};
      promptTokens += (tokens['prompt'] as num?)?.toInt() ?? 0;
      candidateTokens += (tokens['candidates'] as num?)?.toInt() ?? 0;
    }
  }

  return TokenUsage(
    inputTokens: promptTokens,
    outputTokens: candidateTokens,
  );
}
