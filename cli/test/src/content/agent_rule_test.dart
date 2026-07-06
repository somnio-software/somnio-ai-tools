import 'package:somnio/src/content/agent_rule.dart';
import 'package:test/test.dart';

void main() {
  AgentRule build({String? globalPath}) {
    return AgentRule(
      agentId: 'cursor',
      displayName: 'Cursor',
      adapterPath: 'agent-rules/adapters/cursor/rules',
      projectPath: '.cursor/rules',
      format: RulesInstallFormat.directory,
      globalPath: globalPath,
    );
  }

  group('supportsGlobal', () {
    test('is true when globalPath is set', () {
      expect(build(globalPath: '{home}/.cursor/rules').supportsGlobal, isTrue);
    });

    test('is false when globalPath is null', () {
      expect(build().supportsGlobal, isFalse);
    });
  });

  group('resolvedGlobalPath', () {
    test('returns empty string when globalPath is null', () {
      expect(build().resolvedGlobalPath('/home/user'), '');
    });

    test('replaces {home} placeholder', () {
      expect(
        build(globalPath: '{home}/.cursor/rules')
            .resolvedGlobalPath('/home/user'),
        '/home/user/.cursor/rules',
      );
    });
  });
}
