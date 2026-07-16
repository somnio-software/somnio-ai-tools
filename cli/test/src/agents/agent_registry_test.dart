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

    test('ideAgents only includes non-executable agents', () {
      final ide = AgentRegistry.ideAgents;
      expect(ide, isNotEmpty);
      for (final agent in ide) {
        expect(agent.canExecute, isFalse,
            reason: '${agent.id} should not be executable');
      }
      final ids = ide.map((a) => a.id).toSet();
      expect(ids, containsAll(['copilot', 'windsurf', 'roo']));
      expect(ids, isNot(contains('claude')));
    });

    test('executableAgents and ideAgents partition the full registry', () {
      expect(
        AgentRegistry.executableAgents.length + AgentRegistry.ideAgents.length,
        AgentRegistry.agents.length,
      );
    });

    test('all executable agents have a binary', () {
      for (final agent in AgentRegistry.executableAgents) {
        expect(agent.binary, isNotNull,
            reason: '${agent.id} should have a binary');
      }
    });

    test('executable non-skillDir agents declare an executionRulesPath', () {
      // Without it AgentInstaller writes no per-rule reference files and
      // `somnio run` fails on its first step — only skillDir agents get their
      // references/ directory from the install format itself.
      for (final agent in AgentRegistry.executableAgents) {
        if (agent.installFormat == InstallFormat.skillDir) continue;
        expect(agent.executionRulesPath, isNotNull,
            reason: '${agent.id} needs an executionRulesPath to be runnable');
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

  group('modelTiers', () {
    final expected = {
      'claude': {'cheap': 'haiku', 'mid': 'sonnet', 'frontier': 'opus'},
      'cursor': {
        'cheap': 'claude-4.5-haiku',
        'mid': 'claude-4.6-sonnet',
        'frontier': 'claude-4.6-opus',
      },
      'gemini': {
        'cheap': 'gemini-3-flash',
        'mid': 'gemini-2.5-pro',
        'frontier': 'gemini-3-pro',
      },
      'codex': {
        'cheap': 'gpt-5.1-codex-mini',
        'mid': 'gpt-5.2-codex',
        'frontier': 'gpt-5.3-codex',
      },
      'auggie': {
        'cheap': 'claude-haiku-4-5',
        'mid': 'claude-sonnet-4-5',
        'frontier': 'claude-opus-4-6',
      },
      'qwen': {
        'cheap': 'qwen3-coder-next',
        'mid': 'qwen3-coder-plus',
        'frontier': 'qwen3-5-plus',
      },
    };

    test('populated agents have the exact three-tier map', () {
      for (final entry in expected.entries) {
        final agent = AgentRegistry.findById(entry.key)!;
        expect(agent.modelTiers, entry.value, reason: entry.key);
      }
    });

    test('every tier model ID exists in the agent models list', () {
      for (final id in expected.keys) {
        final agent = AgentRegistry.findById(id)!;
        for (final model in agent.modelTiers.values) {
          expect(agent.models, contains(model),
              reason: '$id tier model $model must be in models');
        }
      }
    });

    test('resolveTier on populated agents returns mapped IDs', () {
      final claude = AgentRegistry.findById('claude')!;
      expect(claude.resolveTier('cheap'), 'haiku');
      expect(claude.resolveTier('frontier'), 'opus');
    });

    test('agents without a clean three-tier split have an empty map', () {
      for (final id in [
        'amp',
        'aider',
        'cline',
        'opencode',
        'codebuddy',
        'antigravity',
        'copilot',
        'windsurf',
        'roo',
        'kilocode',
        'amazonq',
      ]) {
        final agent = AgentRegistry.findById(id)!;
        expect(agent.modelTiers, isEmpty, reason: id);
      }
    });

    test('executable agents with no models resolve every tier to null', () {
      // No modelTiers, defaultModel, or fallbackModel to resolve against, so
      // the tier must not leak to the CLI as `--model cheap`.
      for (final id in ['amp', 'aider', 'cline', 'opencode', 'codebuddy']) {
        final agent = AgentRegistry.findById(id)!;
        for (final tier in ['cheap', 'mid', 'frontier']) {
          expect(agent.resolveTier(tier), isNull, reason: '$id $tier');
        }
      }
    });

    test('an unresolved tier emits no model flag', () {
      final amp = AgentRegistry.findById('amp')!;
      final args = amp.buildArgs('prompt', model: amp.resolveTier('cheap'));
      expect(args, isNot(contains(amp.modelFlag)));
      expect(args, isNot(contains('cheap')));
    });
  });
}
