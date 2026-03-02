import '../agents/agent_config.dart';
import '../content/content_loader.dart';
import '../content/skill_bundle.dart';
import 'transformer.dart';

/// Result of transforming content for Cursor.
class CursorOutput {
  const CursorOutput({required this.commandFiles});

  /// Map of file name (e.g., 'somnio-fh.md') to content.
  final Map<String, String> commandFiles;
}

/// Transforms plan.md + YAML rules into Cursor command format.
///
/// Cursor commands are plain `.md` files stored in `.cursor/commands/`.
/// Each skill becomes a single command file that includes the plan
/// content and all rule prompts inline, so the command is self-contained.
class CursorTransformer implements Transformer {
  /// Transforms a skill bundle into a Cursor command file.
  CursorOutput transformBundle(SkillBundle bundle, ContentLoader loader) {
    final plan = loader.loadPlan(bundle);
    final rules = loader.loadRules(bundle);
    final commandFiles = <String, String>{};

    // Build a single command .md file that embeds the plan + all rules
    final buffer = StringBuffer();

    // Plan content as the orchestration header
    buffer.writeln(plan.trimRight());
    buffer.writeln();

    // Append each rule as a section the agent can reference
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

    commandFiles['${bundle.name}.md'] = buffer.toString();

    return CursorOutput(commandFiles: commandFiles);
  }

  @override
  TransformOutput transform(
    SkillBundle bundle,
    ContentLoader loader,
    AgentConfig agent,
  ) {
    final output = transformBundle(bundle, loader);
    return TransformOutput(files: output.commandFiles);
  }
}

/// Alias for [CursorTransformer] used by the unified transformer interface.
typedef SingleFileTransformer = CursorTransformer;
