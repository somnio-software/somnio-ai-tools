import '../content/skill_registry.dart';
import 'agent_config.dart';

/// Registry-driven view of the file and directory names somnio actually
/// writes into an agent's install directory.
///
/// The transformers install skills under their raw bundle name — they never
/// prepend [AgentConfig.filePrefix] — so status / uninstall / update cannot
/// find installed content by prefix alone. This computes the real basenames
/// per [InstallFormat] from [SkillRegistry], and keeps the prefix match as a
/// fallback so legacy v1.x installations are still detected and cleaned up.
class InstalledSkillNames {
  const InstalledSkillNames._(); // coverage:ignore-line

  /// Skill names shipped by v1.x, before the descriptive-name rename.
  ///
  /// They are gone from [SkillRegistry] but may still sit on disk, so every
  /// cleanup path keeps deleting them.
  static const legacyNames = [
    'somnio-fh',
    'somnio-fp',
    'somnio-nh',
    'somnio-np',
    'somnio-rh',
    'somnio-rp',
    'somnio-sa',
    'workflow-plan',
    'workflow-run',
  ];

  /// Every skill name somnio may have installed: the current audit bundles
  /// and workflow skills, plus [legacyNames].
  static List<String> get all => [
        for (final bundle in SkillRegistry.skills) bundle.name,
        for (final skill in SkillRegistry.workflowSkills) skill.name,
        ...legacyNames,
      ];

  /// The basenames somnio writes into [agent]'s install directory.
  ///
  /// Mirrors the transformers: `{name}/` (skillDir), `{name}.md`
  /// (singleFile), `{name_underscored}.md` (markdown). Workflow files are
  /// named after the bundle's workflow path rather than its skill name, so
  /// they are matched by prefix instead — see [matches].
  static Set<String> basenamesFor(AgentConfig agent) {
    return switch (agent.installFormat) {
      InstallFormat.skillDir => all.toSet(),
      InstallFormat.singleFile => {for (final name in all) '$name.md'},
      InstallFormat.markdown => {
          for (final name in all) '${name.replaceAll('-', '_')}.md',
        },
      InstallFormat.workflow => const <String>{},
    };
  }

  /// Whether [basename] inside [agent]'s install directory is somnio content.
  static bool matches(AgentConfig agent, String basename) =>
      basenamesFor(agent).contains(basename) ||
      basename.startsWith(agent.filePrefix);
}
