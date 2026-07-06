// coverage:ignore-file
/// A workflow skill bundle — a standalone markdown file for agent installation.
///
/// Unlike [SkillBundle] (audit bundles with YAML rules), workflow skills
/// are self-contained markdown files installed directly as skills/commands.
/// Installed to all agents in their format-appropriate shape.
class WorkflowSkill {
  const WorkflowSkill({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    required this.planRelativePath,
    this.assetDirectories = const [],
  });

  /// Internal identifier.
  final String id;

  /// Skill name used as slash command (e.g., 'workflow-builder').
  final String name;

  /// Human-readable name.
  final String displayName;

  /// Description for SKILL.md frontmatter.
  final String description;

  /// Path to the skill markdown file, relative to repo root.
  final String planRelativePath;

  /// Extra directories (relative to repo root) copied verbatim into the
  /// installed skill directory, preserving their relative layout.
  ///
  /// For skills backed by real executable code (e.g. `scripts/`, `config/`
  /// for a Python-based skill), this is how that code travels with the
  /// installed skill. Only honored for the Claude Code `skillDir` format —
  /// the only install target that installs a directory able to hold
  /// non-markdown files alongside a skill. Empty for skills that are pure
  /// markdown instructions.
  final List<String> assetDirectories;
}