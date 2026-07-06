import 'package:somnio/src/agents/token_parsers.dart';
import 'package:test/test.dart';

void main() {
  group('parseClaudeUsage', () {
    test('parses a full usage payload', () {
      final usage = parseClaudeUsage({
        'usage': {
          'input_tokens': 1234,
          'output_tokens': 567,
          'cache_read_input_tokens': 890,
          'cache_creation_input_tokens': 100,
        },
        'total_cost_usd': 0.05,
      });

      expect(usage, isNotNull);
      expect(usage!.inputTokens, 1234);
      expect(usage.outputTokens, 567);
      expect(usage.cacheReadTokens, 890);
      expect(usage.cacheCreationTokens, 100);
      expect(usage.costUsd, 0.05);
    });

    test('coalesces missing usage map to zeros and null cost', () {
      final usage = parseClaudeUsage({});

      expect(usage, isNotNull);
      expect(usage!.inputTokens, 0);
      expect(usage.outputTokens, 0);
      expect(usage.cacheReadTokens, 0);
      expect(usage.cacheCreationTokens, 0);
      expect(usage.costUsd, isNull);
    });

    test('coalesces missing individual keys to zeros', () {
      final usage = parseClaudeUsage({
        'usage': {'input_tokens': 10},
      });

      expect(usage!.inputTokens, 10);
      expect(usage.outputTokens, 0);
      expect(usage.cacheReadTokens, 0);
      expect(usage.cacheCreationTokens, 0);
      expect(usage.costUsd, isNull);
    });

    test('handles numeric values supplied as doubles', () {
      final usage = parseClaudeUsage({
        'usage': {
          'input_tokens': 5.0,
          'output_tokens': 7.0,
        },
        'total_cost_usd': 1,
      });

      expect(usage!.inputTokens, 5);
      expect(usage.outputTokens, 7);
      expect(usage.costUsd, 1.0);
    });
  });

  group('parseGeminiUsage', () {
    test('sums prompt and candidate tokens across models', () {
      final usage = parseGeminiUsage({
        'stats': {
          'models': {
            'gemini-2.5-flash': {
              'tokens': {'prompt': 1000, 'candidates': 200},
            },
            'gemini-2.5-pro': {
              'tokens': {'prompt': 500, 'candidates': 50},
            },
          },
        },
      });

      expect(usage, isNotNull);
      expect(usage!.inputTokens, 1500);
      expect(usage.outputTokens, 250);
    });

    test('coalesces missing stats/models to zeros', () {
      final usage = parseGeminiUsage({});

      expect(usage, isNotNull);
      expect(usage!.inputTokens, 0);
      expect(usage.outputTokens, 0);
    });

    test('coalesces missing token keys within a model to zeros', () {
      final usage = parseGeminiUsage({
        'stats': {
          'models': {
            'gemini-3-flash': {'tokens': <String, dynamic>{}},
          },
        },
      });

      expect(usage!.inputTokens, 0);
      expect(usage.outputTokens, 0);
    });

    test('skips model entries that are not maps', () {
      final usage = parseGeminiUsage({
        'stats': {
          'models': {
            'broken': 'not-a-map',
            'gemini-3-flash': {
              'tokens': {'prompt': 42, 'candidates': 9},
            },
          },
        },
      });

      expect(usage!.inputTokens, 42);
      expect(usage.outputTokens, 9);
    });
  });

  group('TokenUsage.totalInputTokens', () {
    test('sums input, cache read, and cache creation tokens', () {
      final usage = parseClaudeUsage({
        'usage': {
          'input_tokens': 100,
          'cache_read_input_tokens': 20,
          'cache_creation_input_tokens': 5,
        },
      });

      expect(usage!.totalInputTokens, 125);
    });

    test('equals inputTokens when no cache tokens are present', () {
      final usage = parseGeminiUsage({
        'stats': {
          'models': {
            'gemini-3-flash': {
              'tokens': {'prompt': 80, 'candidates': 10},
            },
          },
        },
      });

      expect(usage!.totalInputTokens, 80);
    });
  });
}
