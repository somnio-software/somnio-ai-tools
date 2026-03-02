import '../agents/agent_config.dart';
import '../content/content_loader.dart';
import '../content/skill_bundle.dart';
import 'transformer.dart';

/// Transforms plan.md + YAML rules into a generic single markdown file.
///
/// Used for agents that accept markdown files as instructions
/// (Copilot, Windsurf, Roo, Kilo, Amazon Q, and new CLI agents).
/// Similar to SingleFileTransformer but without Cursor-specific conventions.
class MarkdownTransformer implements Transformer {
  @override
  TransformOutput transform(
    SkillBundle bundle,
    ContentLoader loader,
    AgentConfig agent,
  ) {
    final plan = loader.loadPlan(bundle);
    final rules = loader.loadRules(bundle);

    final buffer = StringBuffer();

    // Header with skill metadata
    buffer.writeln('# ${bundle.displayName}');
    buffer.writeln();
    buffer.writeln('> ${bundle.description}');
    buffer.writeln();

    // Plan content
    buffer.writeln(plan.trimRight());
    buffer.writeln();

    // Embedded rules
    if (rules.isNotEmpty) {
      buffer.writeln('---');
      buffer.writeln();
      buffer.writeln('# Rule Reference');
      buffer.writeln();
      for (final rule in rules) {
        buffer.writeln('## ${rule.name}');
        buffer.writeln();
        buffer.writeln('> ${rule.description}');
        buffer.writeln();
        buffer.writeln('**File pattern**: `${rule.match}`');
        buffer.writeln();
        buffer.write(rule.prompt.trimRight());
        buffer.writeln();
        buffer.writeln();
      }
    }

    // File name: somnio_fh.md (using bundle name with - replaced by _)
    final fileName = '${bundle.name.replaceAll('-', '_')}.md';

    return TransformOutput(files: {fileName: buffer.toString()});
  }
}
