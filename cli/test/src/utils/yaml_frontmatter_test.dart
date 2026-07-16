import 'package:somnio/src/utils/yaml_frontmatter.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Parses [frontmatter] the way a host agent's YAML reader would.
YamlMap _parse(String frontmatter) => loadYaml(frontmatter) as YamlMap;

void main() {
  group('foldYamlBlock', () {
    test('emits a >- body that round-trips a description containing ": "', () {
      const authored = 'Ship workflow: merge base branch. Use when asked to '
          '"ship" or "deploy".';
      final doc = _parse('description: >-\n${foldYamlBlock(authored)}');
      expect(doc['description'], authored);
    });

    test('does not truncate a multi-line authored description', () {
      const authored = 'First line of the description.\n'
          'Second line that a single indented interpolation would drop.\n'
          'Third line.';
      final doc = _parse('description: >-\n${foldYamlBlock(authored)}');
      expect(
        doc['description'],
        'First line of the description. Second line that a single indented '
        'interpolation would drop. Third line.',
      );
    });
  });

  group('yamlInlineScalar', () {
    test('leaves an ordinary tool list verbatim', () {
      // Pins the no-churn property: the common form must not gain quotes,
      // or every installed SKILL.md would be rewritten for no reason.
      expect(yamlInlineScalar('Bash, Read, Edit, Write'), 'Bash, Read, Edit, Write');
    });

    test('quotes a value containing ": " so it is not a nested mapping key', () {
      const authored = 'Bash(deploy: prod), Read';
      final emitted = yamlInlineScalar(authored);
      expect(emitted, "'Bash(deploy: prod), Read'");
      expect(_parse('allowed-tools: $emitted')['allowed-tools'], authored);
    });

    test('quotes a leading indicator character', () {
      final emitted = yamlInlineScalar('- Read');
      expect(_parse('allowed-tools: $emitted')['allowed-tools'], '- Read');
    });

    test('escapes an embedded apostrophe when quoting is required', () {
      const authored = "Bash(it's: fine), Read";
      final emitted = yamlInlineScalar(authored);
      expect(_parse('allowed-tools: $emitted')['allowed-tools'], authored);
    });

    test('collapses a newline rather than emitting an unterminated value', () {
      final emitted = yamlInlineScalar('Bash,\nRead');
      expect(_parse('allowed-tools: $emitted')['allowed-tools'], 'Bash, Read');
    });

    test('quotes a trailing colon and an inline comment marker', () {
      for (final authored in ['Read:', 'Read #1']) {
        final emitted = yamlInlineScalar(authored);
        expect(
          _parse('allowed-tools: $emitted')['allowed-tools'],
          authored,
          reason: 'authored value "$authored" must round-trip',
        );
      }
    });
  });
}
