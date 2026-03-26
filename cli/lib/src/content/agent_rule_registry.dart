import 'agent_rule.dart';

/// Static registry of all agent-rules adapters available for installation.
///
/// Each entry maps a pre-generated adapter from `agent-rules/adapters/`
/// to the install paths for both global and project-level scopes.
///
/// Adding support for a new agent requires only a new [AgentRule] entry here.
class AgentRuleRegistry {
  AgentRuleRegistry._();

  /// All registered agent-rules packs.
  static const List<AgentRule> rules = [
    AgentRule(
      agentId: 'claude',
      displayName: 'Claude Code',
      adapterPath: 'agent-rules/adapters/claude/CLAUDE.md',
      globalPath: '{home}/.claude/CLAUDE.md',
      projectPath: 'CLAUDE.md',
      format: RulesInstallFormat.singleFile,
    ),
    AgentRule(
      agentId: 'cursor',
      displayName: 'Cursor',
      adapterPath: 'agent-rules/adapters/cursor/rules',
      globalPath: '{home}/.cursor/rules',
      projectPath: '.cursor/rules',
      format: RulesInstallFormat.directory,
    ),
    AgentRule(
      agentId: 'windsurf',
      displayName: 'Windsurf',
      adapterPath: 'agent-rules/adapters/windsurf/.windsurfrules',
      globalPath: '{home}/.windsurfrules',
      projectPath: '.windsurfrules',
      format: RulesInstallFormat.singleFile,
    ),
    AgentRule(
      agentId: 'copilot',
      displayName: 'GitHub Copilot',
      adapterPath:
          'agent-rules/adapters/copilot/copilot-instructions.md',
      // No well-known global path for Copilot — project-level only.
      projectPath: '.github/copilot-instructions.md',
      format: RulesInstallFormat.singleFile,
    ),
    AgentRule(
      agentId: 'codex',
      displayName: 'OpenAI Codex',
      adapterPath: 'agent-rules/adapters/codex/system-prompt.md',
      // No well-known global path for Codex — project-level only.
      projectPath: 'AGENTS.md',
      format: RulesInstallFormat.singleFile,
    ),
    AgentRule(
      agentId: 'antigravity',
      displayName: 'Antigravity',
      adapterPath: 'agent-rules/adapters/antigravity/rules',
      // No well-known global path for Antigravity — project-level only.
      projectPath: 'rules',
      format: RulesInstallFormat.directory,
    ),
  ];

  /// Find a rule pack by agent ID.
  static AgentRule? findById(String agentId) {
    for (final rule in rules) {
      if (rule.agentId == agentId) return rule;
    }
    return null;
  }

  /// Returns only agents that support global installation.
  static List<AgentRule> get globalCapable =>
      rules.where((r) => r.supportsGlobal).toList();
}
