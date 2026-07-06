import 'package:somnio/src/agents/agent_config.dart';
import 'package:test/test.dart';

void main() {
  group('AgentConfig.buildArgs', () {
    test('flag style places prompt after flag', () {
      const agent = AgentConfig(
        id: 'test',
        displayName: 'Test',
        promptStyle: PromptStyle.flag,
        promptFlag: '-p',
        installPath: '{home}/.test',
      );
      final args = agent.buildArgs('hello world');
      expect(args, ['-p', 'hello world']);
    });

    test('flag style includes autoApproveFlags and outputFlags', () {
      const agent = AgentConfig(
        id: 'claude',
        displayName: 'Claude',
        promptStyle: PromptStyle.flag,
        promptFlag: '-p',
        autoApproveFlags: ['--allowedTools', 'Read,Bash'],
        outputFlags: ['--output-format', 'json'],
        installPath: '{home}/.claude/skills',
      );
      final args = agent.buildArgs('prompt');
      expect(args, [
        '-p', 'prompt',
        '--allowedTools', 'Read,Bash',
        '--output-format', 'json',
      ]);
    });

    test('flag style includes model when provided', () {
      const agent = AgentConfig(
        id: 'test',
        displayName: 'Test',
        promptStyle: PromptStyle.flag,
        promptFlag: '-p',
        installPath: '{home}/.test',
      );
      final args = agent.buildArgs('prompt', model: 'haiku');
      expect(args, ['-p', 'prompt', '--model', 'haiku']);
    });

    test('subcommand style places prompt last after subcommand flag', () {
      const agent = AgentConfig(
        id: 'codex',
        displayName: 'Codex',
        promptStyle: PromptStyle.subcommand,
        promptFlag: 'exec',
        installPath: '{home}/.codex',
      );
      final args = agent.buildArgs('do something');
      expect(args, ['exec', 'do something']);
    });

    test('subcommand style with model', () {
      const agent = AgentConfig(
        id: 'codex',
        displayName: 'Codex',
        promptStyle: PromptStyle.subcommand,
        promptFlag: 'exec',
        installPath: '{home}/.codex',
      );
      final args = agent.buildArgs('prompt', model: 'o3');
      expect(args, ['exec', '--model', 'o3', 'prompt']);
    });

    test('subcommand style includes autoApproveFlags and outputFlags', () {
      const agent = AgentConfig(
        id: 'codex',
        displayName: 'Codex',
        promptStyle: PromptStyle.subcommand,
        promptFlag: 'exec',
        autoApproveFlags: ['--dangerously-bypass-approvals-and-sandbox'],
        outputFlags: ['--json'],
        installPath: '{home}/.codex',
      );
      final args = agent.buildArgs('prompt', model: 'o4-mini');
      expect(args, [
        'exec',
        '--dangerously-bypass-approvals-and-sandbox',
        '--json',
        '--model', 'o4-mini',
        'prompt',
      ]);
    });

    test('positionalLast places prompt at end', () {
      const agent = AgentConfig(
        id: 'cursor',
        displayName: 'Cursor',
        promptStyle: PromptStyle.positionalLast,
        autoApproveFlags: ['--print', '--force'],
        outputFlags: ['--output-format', 'json'],
        installPath: '{home}/.cursor',
      );
      final args = agent.buildArgs('my prompt');
      expect(args, [
        '--print', '--force',
        '--output-format', 'json',
        'my prompt',
      ]);
    });

    test('positionalLast with model', () {
      const agent = AgentConfig(
        id: 'cursor',
        displayName: 'Cursor',
        promptStyle: PromptStyle.positionalLast,
        autoApproveFlags: ['--print'],
        installPath: '{home}/.cursor',
      );
      final args = agent.buildArgs('prompt', model: 'auto');
      expect(args, ['--print', '--model', 'auto', 'prompt']);
    });

    test('flag style omits prompt when promptFlag is null', () {
      const agent = AgentConfig(
        id: 'noflag',
        displayName: 'No Flag',
        promptStyle: PromptStyle.flag,
        outputFlags: ['--json'],
        installPath: '{home}/.noflag',
      );
      final args = agent.buildArgs('ignored prompt', model: 'm');
      expect(args, ['--json', '--model', 'm']);
      expect(args, isNot(contains('ignored prompt')));
    });

    test('subcommand style omits subcommand flag when promptFlag is null', () {
      const agent = AgentConfig(
        id: 'sub',
        displayName: 'Sub',
        promptStyle: PromptStyle.subcommand,
        outputFlags: ['--json'],
        installPath: '{home}/.sub',
      );
      final args = agent.buildArgs('the prompt');
      expect(args, ['--json', 'the prompt']);
    });
  });

  group('AgentConfig.contentLabel', () {
    test('returns "workflow" for InstallFormat.workflow', () {
      const agent = AgentConfig(
        id: 'antigravity',
        displayName: 'Antigravity',
        installFormat: InstallFormat.workflow,
        installPath: '{home}/.gemini/antigravity',
      );
      expect(agent.contentLabel, 'workflow');
    });

    test('returns "command" for InstallFormat.singleFile', () {
      const agent = AgentConfig(
        id: 'cursor',
        displayName: 'Cursor',
        installFormat: InstallFormat.singleFile,
        installPath: '{home}/.cursor/commands',
      );
      expect(agent.contentLabel, 'command');
    });

    test('returns "skill" for other install formats', () {
      const skillDir = AgentConfig(
        id: 'claude',
        displayName: 'Claude',
        installFormat: InstallFormat.skillDir,
        installPath: '{home}/.claude/skills',
      );
      const markdown = AgentConfig(
        id: 'copilot',
        displayName: 'Copilot',
        installFormat: InstallFormat.markdown,
        installPath: '{home}/.copilot/agents',
      );
      expect(skillDir.contentLabel, 'skill');
      expect(markdown.contentLabel, 'skill');
    });
  });

  group('AgentConfig.resolvedExecutionRulesPath', () {
    test('falls back to installPath when executionRulesPath is null', () {
      const agent = AgentConfig(
        id: 'claude',
        displayName: 'Claude',
        installPath: '{home}/.claude/skills',
      );
      final path = agent.resolvedExecutionRulesPath(home: '/home/u');
      expect(path, '/home/u/.claude/skills');
    });

    test('uses executionRulesPath and substitutes {home}', () {
      const agent = AgentConfig(
        id: 'cursor',
        displayName: 'Cursor',
        installPath: '{home}/.cursor/commands',
        executionRulesPath: '{home}/.cursor/somnio_rules',
      );
      final path = agent.resolvedExecutionRulesPath(home: '/Users/u');
      expect(path, endsWith('/.cursor/somnio_rules'));
      expect(path, contains('/Users/u/'));
      expect(path, isNot(contains('{home}')));
    });

    test('substitutes {name} when provided', () {
      const agent = AgentConfig(
        id: 'cursor',
        displayName: 'Cursor',
        installPath: '{home}/.cursor/commands',
        executionRulesPath: '{home}/.cursor/somnio_rules/{name}',
      );
      final path = agent.resolvedExecutionRulesPath(
        home: '/Users/u',
        name: 'flutter-audit',
      );
      expect(path, endsWith('/somnio_rules/flutter-audit'));
      expect(path, isNot(contains('{name}')));
    });

    test('leaves {name} unsubstituted when name is null', () {
      const agent = AgentConfig(
        id: 'cursor',
        displayName: 'Cursor',
        installPath: '{home}/.cursor/commands',
        executionRulesPath: '{home}/.cursor/somnio_rules/{name}',
      );
      final path = agent.resolvedExecutionRulesPath(home: '/Users/u');
      expect(path, contains('{name}'));
    });

    test('claude buildArgs matches original implementation', () {
      const agent = AgentConfig(
        id: 'claude',
        displayName: 'Claude Code',
        promptStyle: PromptStyle.flag,
        promptFlag: '-p',
        autoApproveFlags: ['--allowedTools', 'Read,Bash,Glob,Grep,Write'],
        outputFlags: ['--output-format', 'json'],
        installPath: '{home}/.claude/skills',
      );
      final args = agent.buildArgs('test prompt', model: 'sonnet');
      expect(args, [
        '-p', 'test prompt',
        '--allowedTools', 'Read,Bash,Glob,Grep,Write',
        '--output-format', 'json',
        '--model', 'sonnet',
      ]);
    });

    test('gemini buildArgs matches original implementation', () {
      const agent = AgentConfig(
        id: 'gemini',
        displayName: 'Gemini',
        promptStyle: PromptStyle.flag,
        promptFlag: '-p',
        autoApproveFlags: ['--yolo'],
        outputFlags: ['-o', 'json'],
        installPath: '{home}/.gemini',
      );
      final args = agent.buildArgs('test prompt', model: 'gemini-2.5-flash');
      expect(args, [
        '-p', 'test prompt',
        '--yolo',
        '-o', 'json',
        '--model', 'gemini-2.5-flash',
      ]);
    });

    test('cursor buildArgs matches original implementation', () {
      const agent = AgentConfig(
        id: 'cursor',
        displayName: 'Cursor',
        promptStyle: PromptStyle.positionalLast,
        autoApproveFlags: ['--print', '--force'],
        outputFlags: ['--output-format', 'json'],
        installPath: '{home}/.cursor',
      );
      final args = agent.buildArgs('test prompt', model: 'auto');
      expect(args, [
        '--print', '--force',
        '--output-format', 'json',
        '--model', 'auto',
        'test prompt',
      ]);
    });
  });

  group('AgentConfig.resolvedInstallPath', () {
    test('replaces {home} placeholder', () {
      const agent = AgentConfig(
        id: 'test',
        displayName: 'Test',
        installPath: '{home}/.test/skills',
      );
      final path = agent.resolvedInstallPath(home: '/Users/user');
      expect(path, '/Users/user/.test/skills');
    });

    test('replaces {name} placeholder', () {
      const agent = AgentConfig(
        id: 'test',
        displayName: 'Test',
        installPath: '{home}/.test/{name}',
      );
      final path = agent.resolvedInstallPath(
        home: '/home/user',
        name: 'somnio-fh',
      );
      expect(path, '/home/user/.test/somnio-fh');
    });

    test('returns path as-is when no placeholders are present', () {
      const agent = AgentConfig(
        id: 'copilot',
        displayName: 'Copilot',
        installPath: '.github/agents',
      );
      final path = agent.resolvedInstallPath(home: '/Users/user');
      expect(path, '.github/agents');
    });
  });

  group('AgentConfig.formatReadInstruction', () {
    test('uses default template when readInstructionTemplate is null', () {
      const agent = AgentConfig(
        id: 'test',
        displayName: 'Test',
        installPath: '{home}/.test',
      );
      final instruction = agent.formatReadInstruction('/path/to/rule.md');
      expect(instruction,
          'Read and follow ALL instructions in /path/to/rule.md');
    });

    test('uses custom template when provided', () {
      const agent = AgentConfig(
        id: 'gemini',
        displayName: 'Gemini',
        readInstructionTemplate:
            'Read {file} and follow ALL instructions in the prompt field',
        installPath: '{home}/.gemini',
      );
      final instruction = agent.formatReadInstruction('/path/to/rule.yaml');
      expect(instruction,
          'Read /path/to/rule.yaml and follow ALL instructions in the prompt field');
    });
  });

  group('AgentConfig.configDirName / installSubpath', () {
    test('splits a typical {home}/<dir>/<sub> template', () {
      const agent = AgentConfig(
        id: 'claude',
        displayName: 'Claude',
        installPath: '{home}/.claude/skills',
      );
      expect(agent.configDirName, '.claude');
      expect(agent.installSubpath, 'skills');
    });

    test('handles a multi-segment subpath', () {
      const agent = AgentConfig(
        id: 'antigravity',
        displayName: 'Antigravity',
        installPath: '{home}/.gemini/antigravity/global_workflows',
      );
      expect(agent.configDirName, '.gemini');
      expect(agent.installSubpath, 'antigravity/global_workflows');
    });

    test('returns empty subpath when only the config dir is present', () {
      const agent = AgentConfig(
        id: 'test',
        displayName: 'Test',
        installPath: '{home}/.test',
      );
      expect(agent.configDirName, '.test');
      expect(agent.installSubpath, '');
    });
  });

  group('AgentConfig.resolveTier', () {
    const tiered = AgentConfig(
      id: 'tiered',
      displayName: 'Tiered',
      installPath: '{home}/.tiered',
      models: ['a', 'b', 'c'],
      modelTiers: {'cheap': 'a', 'mid': 'b', 'frontier': 'c'},
      defaultModel: 'b',
      fallbackModel: 'a',
    );

    test('returns mapped model when tier is present', () {
      expect(tiered.resolveTier('cheap'), 'a');
      expect(tiered.resolveTier('mid'), 'b');
      expect(tiered.resolveTier('frontier'), 'c');
    });

    test('falls back to defaultModel when tier is absent', () {
      expect(tiered.resolveTier('unknown'), 'b');
    });

    test('falls back to fallbackModel when no map and no defaultModel', () {
      const agent = AgentConfig(
        id: 'fallbackonly',
        displayName: 'Fallback Only',
        installPath: '{home}/.fb',
        fallbackModel: 'cheapo',
      );
      expect(agent.resolveTier('cheap'), 'cheapo');
    });

    test('passes the tier through when no map, default, or fallback', () {
      const agent = AgentConfig(
        id: 'bare',
        displayName: 'Bare',
        installPath: '{home}/.bare',
      );
      expect(agent.resolveTier('cheap'), 'cheap');
    });

    test('defaults to an empty modelTiers map', () {
      const agent = AgentConfig(
        id: 'empty',
        displayName: 'Empty',
        installPath: '{home}/.empty',
      );
      expect(agent.modelTiers, isEmpty);
    });
  });
}
