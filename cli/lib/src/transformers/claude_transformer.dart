import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import '../content/content_loader.dart';
import '../content/skill_bundle.dart';
import '../content/skill_registry.dart';
import '../utils/yaml_frontmatter.dart';
import 'transformer.dart';

/// Result of transforming content for Claude Code.
class ClaudeSkillOutput {
  const ClaudeSkillOutput({
    required this.skillMd,
    required this.ruleFiles,
    this.templateContent,
    this.templateFileName,
    this.agentFiles = const {},
  });

  /// The SKILL.md content with frontmatter and transformed plan.
  final String skillMd;

  /// Map of file name (e.g., 'flutter_tool_installer.md') to content.
  final Map<String, String> ruleFiles;

  /// Template file content, if available.
  final String? templateContent;

  /// Template file name (e.g., 'flutter_report_template.md').
  final String? templateFileName;

  /// Subagent definition files (filename -> content) from the skill's
  /// `agents/` directory, with each file's `model: <tier>` frontmatter line
  /// already resolved to a concrete model ID for the target agent. Empty when
  /// the bundle has no `agents/` directory.
  final Map<String, String> agentFiles;
}

/// Transforms SKILL.md + references into Claude Code skill format.
///
/// Claude Code skills are stored as directories containing:
/// - SKILL.md (orchestration plan with frontmatter)
/// - references/ (individual reference files as markdown)
/// - assets/ (report templates, copied as-is)
class ClaudeTransformer implements Transformer {
  /// Transforms a skill bundle into Claude Code format.
  ///
  /// [agent] is the target agent used to resolve subagent `model:` tiers to
  /// concrete model IDs. Defaults to Claude Code, since the `agents/` directory
  /// is a Claude skill-dir feature.
  ClaudeSkillOutput transformBundle(
    SkillBundle bundle,
    ContentLoader loader, {
    AgentConfig? agent,
  }) {
    final plan = loader.loadPlan(bundle);
    final rules = loader.loadRules(bundle);
    final template = loader.loadTemplate(bundle);
    final targetAgent = agent ?? AgentRegistry.findById('claude')!;

    // Generate SKILL.md, preferring the authored frontmatter's `description`
    // / `allowed-tools` (which carry the auto-activation trigger phrases)
    // over the shorter registry display strings.
    final planFrontmatter = loader.loadPlanFrontmatter(bundle.planRelativePath);
    final skillMd = _generateSkillMd(bundle, plan, planFrontmatter);

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

    // Load subagent files and resolve their model tiers to concrete IDs.
    final agentFiles = <String, String>{};
    final rawAgents = loader.loadAgentFiles(bundle);
    for (final entry in rawAgents.entries) {
      agentFiles[entry.key] = _resolveAgentModelTiers(
        entry.value,
        targetAgent,
      );
    }

    return ClaudeSkillOutput(
      skillMd: skillMd,
      ruleFiles: ruleFiles,
      templateContent: template,
      templateFileName: templateFileName,
      agentFiles: agentFiles,
    );
  }

  /// Rewrites each `model: <cheap|mid|frontier>` frontmatter line in a subagent
  /// file to the concrete model ID resolved via [agent]'s `modelTiers`.
  ///
  /// Only the three known portable tiers are rewritten; any other `model:`
  /// value (already a concrete ID, `inherit`, etc.) is left unchanged, as is a
  /// tier the agent cannot resolve. The rest of the file is preserved
  /// byte-for-byte.
  static String _resolveAgentModelTiers(String content, AgentConfig agent) {
    const knownTiers = {'cheap', 'mid', 'frontier'};
    final modelLine = RegExp(r'^(\s*model:\s*)(\S+)(\s*)$', multiLine: true);
    return content.replaceAllMapped(modelLine, (m) {
      final tier = m.group(2)!;
      if (!knownTiers.contains(tier)) return m.group(0)!;
      final resolved = agent.resolveTier(tier);
      if (resolved == null) return m.group(0)!;
      return '${m.group(1)}$resolved${m.group(3)}';
    });
  }

  String _generateSkillMd(
    SkillBundle bundle,
    String planContent,
    Map<String, String> planFrontmatter,
  ) {
    // Prefer the authored description: it carries the "Use when …" /
    // "Triggers on: …" clauses that drive Claude's skill auto-activation.
    // The registry string is a short display label and drops them.
    final description = planFrontmatter['description'] ?? bundle.description;
    final allowedTools = planFrontmatter['allowed-tools'] ??
        'Read, Edit, Write, Grep, Glob, Bash, WebFetch';

    final frontmatter = '---\n'
        'name: ${bundle.name}\n'
        'description: >-\n'
        '${foldYamlBlock(description)}'
        'allowed-tools: ${yamlInlineScalar(allowedTools)}\n'
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
            '`references/$ruleName.md`';
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
            '`references/$ruleName.md`';
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
        return '`references/$ruleName.md` (from '
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
    final output = transformBundle(bundle, loader, agent: agent);
    final files = <String, String>{};

    // SKILL.md in skill directory
    files['${bundle.name}/SKILL.md'] = output.skillMd;

    // Reference files in references/ subdirectory
    for (final entry in output.ruleFiles.entries) {
      files['${bundle.name}/references/${entry.key}'] = entry.value;
    }

    // Template file in assets/ subdirectory
    if (output.templateContent != null && output.templateFileName != null) {
      files['${bundle.name}/assets/${output.templateFileName!}'] =
          output.templateContent!;
    }

    // Subagent files in agents/ subdirectory (Claude skill-dir only).
    // These are resolved+written by AgentInstaller for the skillDir format so
    // tier resolution can target the actual install agent; they are exposed on
    // ClaudeSkillOutput.agentFiles for transformBundle consumers/tests too.
    for (final entry in output.agentFiles.entries) {
      files['${bundle.name}/agents/${entry.key}'] = entry.value;
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
