import 'package:somnio/src/agents/agent_config.dart';
import 'package:somnio/src/agents/agent_registry.dart';
import 'package:test/test.dart';

void main() {
  group('AgentRegistry', () {
    test('agents list is not empty', () {
      expect(AgentRegistry.agents, isNotEmpty);
    });

    test('all agents have unique ids', () {
      final ids = AgentRegistry.agents.map((a) => a.id).toSet();
      expect(ids.length, AgentRegistry.agents.length);
    });

    test('findById returns correct agent', () {
      final claude = AgentRegistry.findById('claude');
      expect(claude, isNotNull);
      expect(claude!.displayName, 'Claude Code');
      expect(claude.binary, 'claude');
    });

    test('findById returns null for unknown id', () {
      expect(AgentRegistry.findById('nonexistent'), isNull);
    });

    test('executableAgents only includes canExecute: true agents', () {
      final executable = AgentRegistry.executableAgents;
      expect(executable, isNotEmpty);
      for (final agent in executable) {
        expect(agent.canExecute, isTrue,
            reason: '${agent.id} should be executable');
      }
    });

    test('executableAgents includes claude, cursor, gemini', () {
      final ids = AgentRegistry.executableAgents.map((a) => a.id).toSet();
      expect(ids, containsAll(['claude', 'cursor', 'gemini']));
    });

    test('executableAgents includes new CLI agents', () {
      final ids = AgentRegistry.executableAgents.map((a) => a.id).toSet();
      expect(ids, containsAll(['codex', 'aider', 'cline']));
    });

    test('IDE-only agents are not executable', () {
      for (final id in ['copilot', 'windsurf', 'roo', 'kilocode', 'amazonq']) {
        final agent = AgentRegistry.findById(id);
        expect(agent, isNotNull, reason: '$id should exist');
        expect(agent!.canExecute, isFalse,
            reason: '$id should not be executable');
      }
    });

    test('installableAgents returns all agents', () {
      expect(AgentRegistry.installableAgents.length,
          AgentRegistry.agents.length);
    });

    test('all executable agents have a binary', () {
      for (final agent in AgentRegistry.executableAgents) {
        expect(agent.binary, isNotNull,
            reason: '${agent.id} should have a binary');
      }
    });

    test('claude has correct configuration', () {
      final claude = AgentRegistry.findById('claude')!;
      expect(claude.promptStyle, PromptStyle.flag);
      expect(claude.promptFlag, '-p');
      expect(claude.installFormat, InstallFormat.skillDir);
      expect(claude.ruleExtension, '.md');
      expect(claude.tokenUsageParser, isNotNull);
      expect(claude.models, contains('haiku'));
    });

    test('cursor has correct configuration', () {
      final cursor = AgentRegistry.findById('cursor')!;
      expect(cursor.promptStyle, PromptStyle.positionalLast);
      expect(cursor.binary, 'agent');
      expect(cursor.installFormat, InstallFormat.singleFile);
      expect(cursor.executionRulesPath, isNotNull);
    });

    test('gemini has correct configuration', () {
      final gemini = AgentRegistry.findById('gemini')!;
      expect(gemini.promptStyle, PromptStyle.flag);
      expect(gemini.promptFlag, '-p');
      expect(gemini.installFormat, InstallFormat.markdown);
      expect(gemini.tokenUsageParser, isNotNull);
    });

    test('antigravity has correct configuration', () {
      final antigravity = AgentRegistry.findById('antigravity')!;
      expect(antigravity.canExecute, false);
      expect(antigravity.installFormat, InstallFormat.workflow);
      expect(antigravity.ruleExtension, '.yaml');
      expect(antigravity.readInstructionTemplate, isNotNull);
    });

    test('codex has correct configuration', () {
      final codex = AgentRegistry.findById('codex')!;
      expect(codex.promptStyle, PromptStyle.subcommand);
      expect(codex.promptFlag, 'exec');
      expect(codex.autoApproveFlags, ['--dangerously-bypass-approvals-and-sandbox']);
      expect(codex.outputFlags, ['--json']);
      expect(codex.models, contains('gpt-5.3-codex'));
    });

    test('all CLI agents with yolo-style auto-approve', () {
      // Agents that have auto-approve/yolo flags
      final expectations = {
        'claude': ['--allowedTools', 'Read,Bash,Glob,Grep,Write'],
        'cursor': ['--print', '--force'],
        'gemini': ['--yolo'],
        'codex': ['--dangerously-bypass-approvals-and-sandbox'],
        'auggie': ['--print'],
        'aider': ['--yes-always'],
        'cline': ['-y'],
        'codebuddy': ['--dangerously-skip-permissions'],
        'qwen': ['--yolo'],
      };
      for (final entry in expectations.entries) {
        final agent = AgentRegistry.findById(entry.key)!;
        expect(agent.autoApproveFlags, entry.value,
            reason: '${entry.key} autoApproveFlags');
      }
    });

    test('agents without auto-approve have empty flags', () {
      for (final id in ['amp', 'opencode']) {
        final agent = AgentRegistry.findById(id)!;
        expect(agent.autoApproveFlags, isEmpty,
            reason: '$id should have no autoApproveFlags');
      }
    });

    test('agents with output flags are correctly configured', () {
      final expectations = {
        'claude': ['--output-format', 'json'],
        'cursor': ['--output-format', 'json'],
        'gemini': ['-o', 'json'],
        'codex': ['--json'],
        'auggie': ['--output-format', 'json'],
        'amp': ['--stream-json'],
        'cline': ['--json'],
        'opencode': ['-f', 'json'],
        'codebuddy': ['--output-format', 'json'],
        'qwen': ['--output-format', 'json'],
      };
      for (final entry in expectations.entries) {
        final agent = AgentRegistry.findById(entry.key)!;
        expect(agent.outputFlags, entry.value,
            reason: '${entry.key} outputFlags');
      }
    });
  });
}
