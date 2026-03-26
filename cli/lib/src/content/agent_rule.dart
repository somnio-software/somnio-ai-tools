/// How the agent rule content is organized on disk.
enum RulesInstallFormat {
  /// Single file written with somnio block markers (e.g., CLAUDE.md).
  singleFile,

  /// Directory of rule files copied with somnio- prefix (e.g., .cursor/rules/).
  directory,
}

/// Describes an agent-specific coding-standards pack from [agent-rules/adapters/].
///
/// Each [AgentRule] maps one adapter (pre-generated from `agent-rules/rules/`)
/// to both a global install path and a project-level install path for a
/// specific AI agent.
class AgentRule {
  const AgentRule({
    required this.agentId,
    required this.displayName,
    required this.adapterPath,
    required this.projectPath,
    required this.format,
    this.globalPath,
  });

  /// Matching [AgentConfig.id] (e.g., 'claude', 'cursor').
  final String agentId;

  /// Human-readable name (e.g., 'Claude Code').
  final String displayName;

  /// Path to the adapter source, relative to the repo root.
  /// e.g., 'agent-rules/adapters/claude/CLAUDE.md'
  final String adapterPath;

  /// Install path for project-level install (relative to the cwd).
  /// e.g., './CLAUDE.md'
  final String projectPath;

  /// Install format — single file or directory of files.
  final RulesInstallFormat format;

  /// Install path for global install (supports `{home}` placeholder).
  /// Null if this agent has no well-known global config path.
  final String? globalPath;

  /// Whether this agent supports global installation.
  bool get supportsGlobal => globalPath != null;

  /// Resolves the global path by replacing `{home}`.
  String resolvedGlobalPath(String home) {
    if (globalPath == null) return '';
    return globalPath!.replaceAll('{home}', home);
  }
}
