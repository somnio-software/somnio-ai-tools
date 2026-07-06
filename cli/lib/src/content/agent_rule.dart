/// How the agent rule content is organized on disk.
enum RulesInstallFormat {
  /// Single file concatenated from per-stack fragments.
  /// Source layout: `<adapterPath>/<stack>/<adapterFileName ?? basename(projectPath)>`.
  /// Target layout: `<projectPath>` wrapped in somnio block markers.
  singleFile,

  /// Directory of rule files copied from per-stack subdirectories.
  /// Source layout: `<adapterPath>/<stack>/**.*`.
  /// Target layout: `<projectPath>/<stack>/**.*` (stack subfolder is preserved).
  directory,

  /// Claude's hybrid modular layout: minimal `CLAUDE.md` at project root plus
  /// a `.claude/rules/<stack>/` directory of per-rule files referenced via
  /// `@imports`.
  ///
  /// Source layout per stack:
  ///   `<adapterPath>/<stack>/CLAUDE.md`        (imports fragment)
  ///   `<adapterPath>/<stack>/rules/**.md`     (condensed rule files)
  ///
  /// Target layout:
  ///   `<projectPath>`                          (concatenated CLAUDE.md)
  ///   `<projectDir>/.claude/rules/<stack>/**.md`
  claudeModular,
}

/// Describes an agent-specific coding-standards pack from [agent-rules/adapters/].
///
/// Adapters are organized per stack (e.g. react, flutter, nestjs), so consumers
/// can install only the stacks they use via `somnio rules install --stacks`.
class AgentRule {
  const AgentRule({
    required this.agentId,
    required this.displayName,
    required this.adapterPath,
    required this.projectPath,
    required this.format,
    this.stacks = const <String>['flutter', 'nestjs', 'react'],
    this.globalPath,
    this.adapterFileName,
  });

  /// Matching `AgentConfig.id` (e.g., 'claude', 'cursor').
  final String agentId;

  /// Human-readable name (e.g., 'Claude Code').
  final String displayName;

  /// Base adapter source directory relative to the repo root.
  ///
  /// The installer expects per-stack subdirectories beneath this path — see
  /// [RulesInstallFormat] for the exact layout each format requires.
  final String adapterPath;

  /// Install path for project-level install (relative to the cwd).
  ///
  /// For [RulesInstallFormat.singleFile] this is the target file. For
  /// [RulesInstallFormat.directory] this is the target directory. For
  /// [RulesInstallFormat.claudeModular] this is the target `CLAUDE.md` —
  /// the rules subdirectory is derived from its parent.
  final String projectPath;

  /// Install format — single file, directory, or Claude's hybrid layout.
  final RulesInstallFormat format;

  /// Stacks available in the adapter (must match subdirectory names under
  /// [adapterPath]). Defaults to the three Somnio-supported stacks.
  final List<String> stacks;

  /// Install path for global install (supports `{home}` placeholder).
  ///
  /// Null when the agent has no well-known global config path or when global
  /// installs are intentionally unsupported (e.g. Claude, because rules
  /// should live next to the project they describe).
  final String? globalPath;

  /// Source fragment filename for [RulesInstallFormat.singleFile] adapters,
  /// when it differs from `basename(projectPath)`.
  ///
  /// Most single-file agents name their per-stack source fragment after the
  /// target file (e.g. Cursor's `.cursorrules`), so this stays null and the
  /// installer derives the name from [projectPath]. Codex is the exception:
  /// its condensed fragment is `system-prompt.md` but installs into `AGENTS.md`.
  final String? adapterFileName;

  /// Whether this agent supports global installation.
  bool get supportsGlobal => globalPath != null;

  /// Resolves the global path by replacing `{home}`.
  String resolvedGlobalPath(String home) {
    if (globalPath == null) return '';
    return globalPath!.replaceAll('{home}', home);
  }
}
