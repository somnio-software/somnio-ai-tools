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
}
