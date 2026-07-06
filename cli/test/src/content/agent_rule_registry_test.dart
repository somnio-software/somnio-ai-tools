import 'package:somnio/src/content/agent_rule_registry.dart';
import 'package:test/test.dart';

void main() {
  group('findById', () {
    test('returns the matching rule pack', () {
      final rule = AgentRuleRegistry.findById('cursor');
      expect(rule, isNotNull);
      expect(rule!.agentId, 'cursor');
      expect(rule.displayName, 'Cursor');
    });

    test('returns null for an unknown agent id', () {
      expect(AgentRuleRegistry.findById('does-not-exist'), isNull);
    });
  });

  group('globalCapable', () {
    test('includes only rules with a global path', () {
      final ids =
          AgentRuleRegistry.globalCapable.map((r) => r.agentId).toList();
      // Cursor and Windsurf declare a {home} globalPath.
      expect(ids, containsAll(['cursor', 'windsurf']));
      // Claude/Copilot/Codex/Antigravity have no global path.
      expect(ids, isNot(contains('claude')));
      expect(ids, isNot(contains('copilot')));
      expect(
        AgentRuleRegistry.globalCapable.every((r) => r.supportsGlobal),
        isTrue,
      );
    });
  });

  group('stacks', () {
    test('exposes the canonical stack list', () {
      expect(
        AgentRuleRegistry.stacks,
        [
          'django',
          'fastapi',
          'flask',
          'flutter',
          'functions',
          'nestjs',
          'python',
          'react',
          'typescript',
        ],
      );
    });
  });
}
