import 'agent_config.dart';
import 'token_parsers.dart';

/// Central registry of all AI agents supported by somnio.
///
/// Adding a new agent requires only a single [AgentConfig] entry here.
/// No other files need to change.
class AgentRegistry {
  AgentRegistry._();

  /// All registered agents.
  static const List<AgentConfig> agents = [
    // ── CLI agents (canExecute: true) ─────────────────────────────
    _claude,
    _cursor,
    _gemini,
    _antigravity,
    _codex,
    _auggie,
    _amp,
    _aider,
    _cline,
    _opencode,
    _codebuddy,
    _qwen,
    // ── IDE-only agents (canExecute: false) ────────────────────────
    _copilot,
    _windsurf,
    _roo,
    _kilocode,
    _amazonq,
  ];

  /// Agents that can execute audits via `somnio run`.
  static List<AgentConfig> get executableAgents =>
      agents.where((a) => a.canExecute).toList();

  /// Agents that support skill installation.
  static List<AgentConfig> get installableAgents => agents.toList();

  /// IDE-only agents (project-scope, no CLI binary).
  static List<AgentConfig> get ideAgents =>
      agents.where((a) => !a.canExecute).toList();

  /// Find an agent by its ID.
  static AgentConfig? findById(String id) {
    for (final agent in agents) {
      if (agent.id == id) return agent;
    }
    return null;
  }

  // ── CLI agent definitions ───────────────────────────────────────

  static const _claude = AgentConfig(
    id: 'claude',
    displayName: 'Claude Code',
    binary: 'claude',
    canExecute: true,
    promptStyle: PromptStyle.flag,
    promptFlag: '-p',
    autoApproveFlags: ['--allowedTools', 'Read,Bash,Glob,Grep,Write'],
    outputFlags: ['--output-format', 'json'],
    models: ['haiku', 'sonnet', 'opus'],
    defaultModel: 'haiku',
    fallbackModel: 'haiku',
    installFormat: InstallFormat.skillDir,
    installPath: '{home}/.claude/skills',
    ruleExtension: '.md',
    tokenUsageParser: parseClaudeUsage,
    filePrefix: 'somnio-',
    npmPackage: '@anthropic-ai/claude-code',
    installUrl: 'https://claude.ai/download',
  );

  static const _cursor = AgentConfig(
    id: 'cursor',
    displayName: 'Cursor',
    binary: 'agent',
    canExecute: true,
    promptStyle: PromptStyle.positionalLast,
    autoApproveFlags: ['--print', '--force'],
    outputFlags: ['--output-format', 'json'],
    models: [
      'auto',
      'claude-4.6-opus',
      'claude-4.6-opus-fast',
      'claude-4.6-sonnet',
      'claude-4.5-sonnet',
      'claude-4.5-opus',
      'claude-4.5-haiku',
      'claude-4-sonnet',
      'claude-4-sonnet-1m',
      'composer-1',
      'composer-1.5',
      'gpt-5.3-codex',
      'gpt-5.2-codex',
      'gpt-5.2',
      'gpt-5.1-codex-max',
      'gpt-5.1-codex-mini',
      'gpt-5.1-codex',
      'gpt-5',
      'gpt-5-fast',
      'gpt-5-mini',
      'gpt-5-codex',
      'gemini-3.1-pro',
      'gemini-3-pro',
      'gemini-3-flash',
      'gemini-2.5-flash',
      'grok-code',
      'kimi-k2.5',
    ],
    defaultModel: 'auto',
    fallbackModel: 'auto',
    installFormat: InstallFormat.singleFile,
    installPath: '{home}/.cursor/commands',
    executionRulesPath: '{home}/.cursor/somnio_rules',
    ruleExtension: '.md',
    filePrefix: 'somnio-',
    npmPackage: 'cursor-agent',
    installUrl: 'https://cursor.com/cli',
    detectionPaths: [
      '/Applications/Cursor.app',
    ],
  );

  static const _gemini = AgentConfig(
    id: 'gemini',
    displayName: 'Gemini CLI',
    binary: 'gemini',
    canExecute: true,
    promptStyle: PromptStyle.flag,
    promptFlag: '-p',
    autoApproveFlags: ['--yolo'],
    outputFlags: ['-o', 'json'],
    models: [
      'gemini-3-flash',
      'gemini-3.1-pro-preview',
      'gemini-3-pro',
      'gemini-3-flash-preview',
      'gemini-2.5-pro',
      'gemini-2.5-flash',
    ],
    defaultModel: 'gemini-3-flash',
    fallbackModel: 'gemini-2.5-flash',
    installFormat: InstallFormat.markdown,
    installPath: '{home}/.gemini/skills',
    tokenUsageParser: parseGeminiUsage,
    filePrefix: 'somnio_',
    npmPackage: '@google/gemini-cli',
    installUrl: 'https://github.com/google-gemini/gemini-cli',
  );

  static const _antigravity = AgentConfig(
    id: 'antigravity',
    displayName: 'Antigravity',
    installFormat: InstallFormat.workflow,
    installPath: '{home}/.gemini/antigravity/global_workflows',
    ruleExtension: '.yaml',
    readInstructionTemplate:
        'Read {file} and follow ALL instructions in the prompt field',
    filePrefix: 'somnio_',
    installUrl: 'https://github.com/google-gemini/gemini-cli',
    detectionBinaries: ['agy', 'antigravity'],
  );

  static const _codex = AgentConfig(
    id: 'codex',
    displayName: 'Codex CLI',
    binary: 'codex',
    canExecute: true,
    promptStyle: PromptStyle.subcommand,
    promptFlag: 'exec',
    autoApproveFlags: ['--dangerously-bypass-approvals-and-sandbox'],
    outputFlags: ['--json'],
    models: [
      'gpt-5.3-codex',
      'gpt-5.2-codex',
      'gpt-5.1-codex-max',
      'gpt-5.2',
      'gpt-5.1-codex-mini',
    ],
    defaultModel: 'gpt-5.3-codex',
    fallbackModel: 'gpt-5.1-codex-mini',
    installFormat: InstallFormat.markdown,
    installPath: '{home}/.codex/skills',
    filePrefix: 'somnio',
    npmPackage: '@openai/codex',
    installUrl: 'https://github.com/openai/codex',
  );

  static const _auggie = AgentConfig(
    id: 'auggie',
    displayName: 'Augment Code',
    binary: 'auggie',
    canExecute: true,
    promptStyle: PromptStyle.positionalLast,
    autoApproveFlags: ['--print'],
    outputFlags: ['--output-format', 'json'],
    models: [
      'claude-opus-4-6',
      'claude-sonnet-4-5',
      'claude-opus-4-5',
      'claude-haiku-4-5',
      'gpt-5.3',
      'gpt-5.2',
      'gpt-5.1',
    ],
    defaultModel: 'claude-sonnet-4-5',
    fallbackModel: 'claude-haiku-4-5',
    installFormat: InstallFormat.markdown,
    installPath: '{home}/.augment/skills',
    filePrefix: 'somnio',
    installUrl: 'https://www.augmentcode.com',
    installInstructions:
        '  Download from https://www.augmentcode.com/product/CLI\n'
        '  Or install the VS Code extension and enable CLI access',
  );

  static const _amp = AgentConfig(
    id: 'amp',
    displayName: 'Amp',
    binary: 'amp',
    canExecute: true,
    promptStyle: PromptStyle.flag,
    promptFlag: '-x',
    outputFlags: ['--stream-json'],
    installFormat: InstallFormat.markdown,
    installPath: '{home}/.amp/skills',
    filePrefix: 'somnio',
    npmPackage: 'amp',
    installUrl: 'https://ampcode.com',
  );

  static const _aider = AgentConfig(
    id: 'aider',
    displayName: 'Aider',
    binary: 'aider',
    canExecute: true,
    promptStyle: PromptStyle.flag,
    promptFlag: '--message',
    autoApproveFlags: ['--yes-always'],
    installFormat: InstallFormat.markdown,
    installPath: '{home}/.aider/skills',
    filePrefix: 'somnio',
    installUrl: 'https://aider.chat',
    installInstructions:
        '  pip install aider-chat\n'
        '  Or visit: https://aider.chat/docs/install.html',
  );

  static const _cline = AgentConfig(
    id: 'cline',
    displayName: 'Cline',
    binary: 'cline',
    canExecute: true,
    promptStyle: PromptStyle.positionalLast,
    autoApproveFlags: ['-y'],
    outputFlags: ['--json'],
    installFormat: InstallFormat.markdown,
    installPath: '{home}/.cline/skills',
    filePrefix: 'somnio',
    npmPackage: 'cline',
    installUrl: 'https://cline.bot',
  );

  static const _opencode = AgentConfig(
    id: 'opencode',
    displayName: 'OpenCode',
    binary: 'opencode',
    canExecute: true,
    promptStyle: PromptStyle.flag,
    promptFlag: '-p',
    outputFlags: ['-f', 'json'],
    installFormat: InstallFormat.markdown,
    installPath: '{home}/.opencode/skills',
    filePrefix: 'somnio',
    installUrl: 'https://opencode.ai',
    installInstructions:
        '  go install github.com/opencode-ai/opencode@latest\n'
        '  Or visit: https://opencode.ai',
  );

  static const _codebuddy = AgentConfig(
    id: 'codebuddy',
    displayName: 'CodeBuddy',
    binary: 'codebuddy',
    canExecute: true,
    promptStyle: PromptStyle.flag,
    promptFlag: '-p',
    autoApproveFlags: ['--dangerously-skip-permissions'],
    outputFlags: ['--output-format', 'json'],
    installFormat: InstallFormat.markdown,
    installPath: '{home}/.codebuddy/skills',
    filePrefix: 'somnio',
    installUrl: 'https://codebuddy.dev',
    installInstructions:
        '  Download from https://codebuddy.dev\n'
        '  Or: npm install -g @anthropic-ai/codebuddy (if available)',
  );

  static const _qwen = AgentConfig(
    id: 'qwen',
    displayName: 'Qwen CLI',
    binary: 'qwen',
    canExecute: true,
    promptStyle: PromptStyle.flag,
    promptFlag: '-p',
    autoApproveFlags: ['--yolo'],
    outputFlags: ['--output-format', 'json'],
    models: [
      'qwen3-coder-plus',
      'qwen3-coder-next',
      'qwen3-5-plus',
    ],
    defaultModel: 'qwen3-coder-plus',
    fallbackModel: 'qwen3-coder-next',
    installFormat: InstallFormat.markdown,
    installPath: '{home}/.qwen/skills',
    filePrefix: 'somnio',
    npmPackage: 'qwen-code',
    installUrl: 'https://qwen.ai',
  );

  // ── IDE-only agent definitions ──────────────────────────────────

  static const _copilot = AgentConfig(
    id: 'copilot',
    displayName: 'GitHub Copilot',
    installFormat: InstallFormat.markdown,
    installPath: '{home}/.copilot/agents',
    filePrefix: 'somnio',
    installUrl: 'https://github.com/features/copilot',
  );

  static const _windsurf = AgentConfig(
    id: 'windsurf',
    displayName: 'Windsurf',
    installFormat: InstallFormat.markdown,
    installPath: '{home}/.windsurf/workflows',
    filePrefix: 'somnio',
    installUrl: 'https://windsurf.com',
  );

  static const _roo = AgentConfig(
    id: 'roo',
    displayName: 'Roo Code',
    installFormat: InstallFormat.markdown,
    installPath: '{home}/.roo/rules',
    filePrefix: 'somnio',
    installUrl: 'https://roocode.com',
  );

  static const _kilocode = AgentConfig(
    id: 'kilocode',
    displayName: 'Kilo Code',
    installFormat: InstallFormat.markdown,
    installPath: '{home}/.kilocode/rules',
    filePrefix: 'somnio',
    installUrl: 'https://kilocode.ai',
  );

  static const _amazonq = AgentConfig(
    id: 'amazonq',
    displayName: 'Amazon Q',
    installFormat: InstallFormat.markdown,
    installPath: '{home}/.amazonq/prompts',
    filePrefix: 'somnio',
    installUrl: 'https://aws.amazon.com/q/developer/',
  );
}
