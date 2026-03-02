import '../agents/agent_config.dart';
import '../content/content_loader.dart';
import '../content/skill_bundle.dart';
import '../content/skill_registry.dart';
import 'transformer.dart';

/// Result of transforming content for Claude Code.
class ClaudeSkillOutput {
  const ClaudeSkillOutput({
    required this.skillMd,
    required this.ruleFiles,
    this.templateContent,
    this.templateFileName,
  });

  /// The SKILL.md content with frontmatter and transformed plan.
  final String skillMd;

  /// Map of file name (e.g., 'flutter_tool_installer.md') to content.
  final Map<String, String> ruleFiles;

  /// Template file content, if available.
  final String? templateContent;

  /// Template file name (e.g., 'flutter_report_template.txt').
  final String? templateFileName;
}

/// Transforms plan.md + YAML rules into Claude Code skill format.
///
/// Claude Code skills are stored as directories containing:
/// - SKILL.md (orchestration plan with frontmatter)
/// - rules/ (individual rule files as markdown)
/// - templates/ (report templates, copied as-is)
class ClaudeTransformer implements Transformer {
  /// Transforms a skill bundle into Claude Code format.
  ClaudeSkillOutput transformBundle(SkillBundle bundle, ContentLoader loader) {
    final plan = loader.loadPlan(bundle);
    final rules = loader.loadRules(bundle);
    final template = loader.loadTemplate(bundle);

    // Generate SKILL.md
    final skillMd = _generateSkillMd(bundle, plan);

    // Generate rule markdown files
    final ruleFiles = <String, String>{};
    for (final rule in rules) {
      ruleFiles['${rule.fileName}.md'] = _ruleToMarkdown(rule);
    }

    // Determine template file name
    String? templateFileName;
    if (bundle.templatePath != null) {
      templateFileName = bundle.templatePath!.split('/').last;
    }

    return ClaudeSkillOutput(
      skillMd: skillMd,
      ruleFiles: ruleFiles,
      templateContent: template,
      templateFileName: templateFileName,
    );
  }

  String _generateSkillMd(SkillBundle bundle, String planContent) {
    final frontmatter = '---\n'
        'name: ${bundle.name}\n'
        'description: >-\n'
        '  ${bundle.description}\n'
        'allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch\n'
        'user-invocable: true\n'
        '---\n\n';

    var content = planContent;

    // Extract technology prefix for sibling skill resolution
    // e.g., 'flutter_health' -> 'flutter', 'nestjs_plan' -> 'nestjs'
    final techPrefix = bundle.techPrefix;

    // Transform @rule_name references to file references
    // Matches: `@rule_name` (with backticks)
    content = content.replaceAllMapped(
      RegExp(r'`@(\w+)`'),
      (match) {
        final ruleName = match.group(1)!;
        return 'Read and follow the instructions in '
            '`rules/$ruleName.md`';
      },
    );

    // Transform cross-skill plan references
    // Pattern: @<prefix>_best_practices_check/plan/best_practices.plan.md
    content = content.replaceAllMapped(
      RegExp(r'@(\w+)_best_practices_check/plan/best_practices\.plan\.md'),
      (match) {
        final prefix = match.group(1)!;
        final targetSkill = SkillRegistry.findById('${prefix}_plan');
        if (targetSkill != null) {
          return '`/${targetSkill.name}`';
        }
        return match.group(0)!;
      },
    );

    // Transform remaining @rule.yaml references in execution summaries
    // Pattern: `@rule_name.yaml`
    content = content.replaceAllMapped(
      RegExp(r'`@(\w+)\.yaml`'),
      (match) {
        final ruleName = match.group(1)!;
        return 'Read and follow the instructions in '
            '`rules/$ruleName.md`';
      },
    );

    // Transform bare @best_practices.plan.md references
    // Resolves to the sibling best practices skill for the same technology
    content = content.replaceAllMapped(
      RegExp(r'`@best_practices\.plan\.md`'),
      (match) {
        final targetSkill = SkillRegistry.findById('${techPrefix}_plan');
        return '`/${targetSkill?.name ?? bundle.name}`';
      },
    );

    // Transform workflow references for Antigravity cross-refs
    // Pattern: `<prefix>_best_practices_check/.agent/workflows/<name>.md`
    content = content.replaceAllMapped(
      RegExp(
        r'`(\w+)_best_practices_check/\.agent/workflows/\w+\.md`',
      ),
      (match) {
        final prefix = match.group(1)!;
        final targetSkill = SkillRegistry.findById('${prefix}_plan');
        return '`/${targetSkill?.name ?? bundle.name}`';
      },
    );

    // Transform plan step rule references
    // Pattern: `<prefix>_best_practices_check/cursor_rules/rule_name.yaml`
    content = content.replaceAllMapped(
      RegExp(
        r'`(\w+)_best_practices_check/cursor_rules/(\w+)\.yaml`',
      ),
      (match) {
        final prefix = match.group(1)!;
        final ruleName = match.group(2)!;
        final targetSkill = SkillRegistry.findById('${prefix}_plan');
        return '`rules/$ruleName.md` (from '
            '`/${targetSkill?.name ?? bundle.name}`)';
      },
    );

    return frontmatter + content;
  }

  @override
  TransformOutput transform(
    SkillBundle bundle,
    ContentLoader loader,
    AgentConfig agent,
  ) {
    final output = transformBundle(bundle, loader);
    final files = <String, String>{};

    // SKILL.md in skill directory
    files['${bundle.name}/SKILL.md'] = output.skillMd;

    // Rule files in rules/ subdirectory
    for (final entry in output.ruleFiles.entries) {
      files['${bundle.name}/rules/${entry.key}'] = entry.value;
    }

    // Template file
    if (output.templateContent != null && output.templateFileName != null) {
      files['${bundle.name}/templates/${output.templateFileName!}'] =
          output.templateContent!;
    }

    return TransformOutput(files: files);
  }

  // techPrefix is now a getter on SkillBundle — no local helper needed.

  /// Converts a parsed YAML rule into a markdown file.
  ///
  /// Shared by multiple transformers.
  static String ruleToMarkdown(ParsedRule rule) => _ruleToMarkdown(rule);

  static String _ruleToMarkdown(ParsedRule rule) {
    final buffer = StringBuffer();
    buffer.writeln('# ${rule.name}');
    buffer.writeln();
    buffer.writeln('> ${rule.description}');
    buffer.writeln();
    buffer.writeln('**File pattern**: `${rule.match}`');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    buffer.write(rule.prompt);
    if (!rule.prompt.endsWith('\n')) {
      buffer.writeln();
    }
    return buffer.toString();
  }
}

/// Alias for [ClaudeTransformer] used by the unified transformer interface.
typedef SkillDirTransformer = ClaudeTransformer;
