import '../agents/agent_config.dart';
import '../content/content_loader.dart';
import '../content/skill_bundle.dart';
import 'claude_transformer.dart';
import 'cursor_transformer.dart';
import 'antigravity_transformer.dart';
import 'markdown_transformer.dart';

/// Output of a skill transformation.
///
/// Maps relative file paths to their content.
/// The installer writes these to the agent's install location.
class TransformOutput {
  const TransformOutput({required this.files, this.skipped = false});

  /// Map of relative path -> file content.
  ///
  /// For skillDir: `{name}/SKILL.md`, `{name}/references/rule.md`, etc.
  /// For singleFile: `somnio-fh.md`
  /// For workflow: `global_workflows/somnio_x.md`, `somnio_rules/x/...`
  /// For markdown: `somnio_fh.md`
  final Map<String, String> files;

  /// Whether this bundle was skipped (e.g., missing workflow).
  final bool skipped;
}

/// Base interface for transforming skill bundles into agent-specific formats.
abstract class Transformer {
  /// Transforms a skill bundle into files for the given agent.
  TransformOutput transform(
    SkillBundle bundle,
    ContentLoader loader,
    AgentConfig agent,
  );
}

/// Returns the appropriate transformer for the given install format.
Transformer transformerFor(InstallFormat format) => switch (format) {
  InstallFormat.skillDir => SkillDirTransformer(),
  InstallFormat.singleFile => SingleFileTransformer(),
  InstallFormat.workflow => WorkflowTransformer(),
  InstallFormat.markdown => MarkdownTransformer(),
};
