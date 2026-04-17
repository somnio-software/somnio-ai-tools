import 'agent_rule.dart';

/// Static registry of all agent-rules adapters available for installation.
///
/// Each entry maps a pre-generated adapter from `agent-rules/adapters/`
/// to the install paths for both global and project-level scopes.
///
/// Adding support for a new agent requires only a new [AgentRule] entry here.
class AgentRuleRegistry {
  AgentRuleRegistry._();

  /// Stacks exposed by every adapter — must match subfolder names under
  /// `agent-rules/rules/` and the per-stack subfolders the generator emits
  /// under `agent-rules/adapters/<agent>/`.
  static const List<String> stacks = ['flutter', 'nestjs', 'react'];

  /// All registered agent-rules packs.
  static const List<AgentRule> rules = [
    AgentRule(
      agentId: 'claude',
      displayName: 'Claude Code',
      adapterPath: 'agent-rules/adapters/claude',
      // No global install for Claude — rules are stack-scoped and should live
      // next to the project that uses them via @imports.
      projectPath: 'CLAUDE.md',
      format: RulesInstallFormat.claudeModular,
      stacks: stacks,
    ),
    AgentRule(
      agentId: 'cursor',
      displayName: 'Cursor',
      adapterPath: 'agent-rules/adapters/cursor/rules',
      globalPath: '{home}/.cursor/rules',
      projectPath: '.cursor/rules',
      format: RulesInstallFormat.directory,
      stacks: stacks,
    ),
    AgentRule(
      agentId: 'windsurf',
      displayName: 'Windsurf',
      adapterPath: 'agent-rules/adapters/windsurf',
      globalPath: '{home}/.windsurfrules',
      projectPath: '.windsurfrules',
      format: RulesInstallFormat.singleFile,
      stacks: stacks,
    ),
    AgentRule(
      agentId: 'copilot',
      displayName: 'GitHub Copilot',
      adapterPath: 'agent-rules/adapters/copilot',
      // No well-known global path for Copilot — project-level only.
      projectPath: '.github/copilot-instructions.md',
      format: RulesInstallFormat.singleFile,
      stacks: stacks,
    ),
    AgentRule(
      agentId: 'codex',
      displayName: 'OpenAI Codex',
      adapterPath: 'agent-rules/adapters/codex',
      // No well-known global path for Codex — project-level only.
      projectPath: 'AGENTS.md',
      format: RulesInstallFormat.singleFile,
      stacks: stacks,
    ),
    AgentRule(
      agentId: 'antigravity',
      displayName: 'Antigravity',
      adapterPath: 'agent-rules/adapters/antigravity/rules',
      // No well-known global path for Antigravity — project-level only.
      projectPath: 'rules',
      format: RulesInstallFormat.directory,
      stacks: stacks,
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
