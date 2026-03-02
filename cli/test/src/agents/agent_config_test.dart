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
}
