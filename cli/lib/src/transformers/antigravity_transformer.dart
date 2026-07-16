import 'dart:io';

import 'package:path/path.dart' as p;

import '../agents/agent_config.dart';
import '../content/content_loader.dart';
import '../content/skill_bundle.dart';
import 'transformer.dart';

/// Result of transforming content for Antigravity.
class AntigravityOutput {
  const AntigravityOutput({
    required this.workflowContent,
    required this.workflowFileName,
    required this.ruleFiles,
    this.planContent,
    this.planRelativePath,
  });

  /// Transformed workflow content with rewritten paths.
  final String workflowContent;

  /// Target file name for the workflow (e.g., 'somnio_flutter_health_audit.md').
  final String workflowFileName;

  /// Map of relative path (under somnio_rules/) to file content.
  /// Includes YAML rules, templates, and plan files.
  final Map<String, String> ruleFiles;

  /// Plan file content.
  final String? planContent;

  /// Plan file relative path under somnio_rules/.
  final String? planRelativePath;
}

/// Transforms workflow files + rules into Antigravity format.
///
/// Antigravity stores workflows in `~/.gemini/antigravity/global_workflows/`
/// and supporting files in `~/.gemini/antigravity/somnio_rules/`. The
/// transformer copies files and rewrites paths in workflow content.
class AntigravityTransformer implements Transformer {
  /// How reference files spell the report template path in their prose.
  static const _templateRelativePath = 'assets/report-template.md';

  /// Transforms a skill bundle into Antigravity format.
  AntigravityOutput transformBundle(
    SkillBundle bundle,
    ContentLoader loader,
  ) {
    var workflowContent = loader.loadWorkflow(bundle) ?? '';
    final planContent = loader.loadPlan(bundle);

    // Determine the plan subdirectory name
    final planSubDir = bundle.planSubDir;

    // Rewrite paths in workflow content
    workflowContent = _rewritePaths(workflowContent, planSubDir);

    // Determine workflow file name
    final workflowFileName = _workflowFileName(bundle);

    // Collect all rule files to copy
    final ruleFiles = <String, String>{};

    // Copy YAML rule files
    final allFiles = loader.listAllRuleFiles(bundle);
    for (final relativePath in allFiles) {
      final absPath = loader.rulesFilePath(bundle, relativePath);
      var content = File(absPath).readAsStringSync();
      // Reference files are copied verbatim and still point at the bundle's
      // `assets/report-template.md`. Antigravity resolves paths against the
      // workspace, so rewrite it to the installed absolute location — the same
      // convention _rewritePaths uses for references/ paths.
      content = _rewriteTemplatePath(content, planSubDir);
      ruleFiles['$planSubDir/references/$relativePath'] = content;
    }

    // The report template lives in the bundle's `assets/`, a sibling of
    // references/, so listAllRuleFiles never sees it — load it explicitly.
    final template = loader.loadTemplate(bundle);
    if (template != null && bundle.templatePath != null) {
      ruleFiles['$planSubDir/assets/${p.basename(bundle.templatePath!)}'] =
          template;
    }

    // Subagent definitions live in the bundle's `agents/` directory, another
    // sibling of references/ that listAllRuleFiles never sees. The installed
    // workflow reads them by name, so they must ship too.
    final agentFiles = loader.loadAgentFiles(bundle);
    for (final entry in agentFiles.entries) {
      ruleFiles['$planSubDir/agents/${entry.key}'] = entry.value;
    }

    // Determine plan relative path under somnio_rules
    String? planRelPath;
    if (bundle.planRelativePath.isNotEmpty) {
      final planFileName = p.basename(bundle.planRelativePath);
      planRelPath = '$planSubDir/plan/$planFileName';
    }

    return AntigravityOutput(
      workflowContent: workflowContent,
      workflowFileName: workflowFileName,
      ruleFiles: ruleFiles,
      planContent: planContent,
      planRelativePath: planRelPath,
    );
  }

  @override
  TransformOutput transform(
    SkillBundle bundle,
    ContentLoader loader,
    AgentConfig agent,
  ) {
    // Soft-skip bundles whose workflow is unset OR missing on disk. Gating on
    // the loaded content (not just the path) keeps a bundle with a dangling
    // workflowPath from overwriting a good install with an empty file.
    if (loader.loadWorkflow(bundle) == null) {
      return const TransformOutput(files: {}, skipped: true);
    }

    final output = transformBundle(bundle, loader);
    final files = <String, String>{};

    // Workflow file goes under global_workflows/
    files['global_workflows/${output.workflowFileName}'] =
        output.workflowContent;

    // Rule files go under somnio_rules/
    for (final entry in output.ruleFiles.entries) {
      files['somnio_rules/${entry.key}'] = entry.value;
    }

    // Plan file
    if (output.planContent != null && output.planRelativePath != null) {
      files['somnio_rules/${output.planRelativePath!}'] = output.planContent!;
    }

    return TransformOutput(files: files);
  }

  String _rewritePaths(String content, String planSubDir) {
    // First: rewrite workflow cross-references (must be done before the
    // general path rewrite catches them).
    // Pattern: `<skill-name>/.agent/workflows/<workflow-name>.md`
    // → `somnio_<workflow-name>.md`
    content = content.replaceAllMapped(
      RegExp(r'`([a-z][a-z0-9-]*)\/\.agent\/workflows\/([a-z_]+)\.md`'),
      (match) => '`somnio_${match.group(2)}.md`',
    );

    // Then: rewrite agents/ subagent-definition paths.
    // Prefixed form: `<skill-name>/agents/<file>.md`
    content = content.replaceAllMapped(
      RegExp(r'`([a-z][a-z0-9-]*)\/agents\/([^`]+)`'),
      (m) =>
          '`~/.gemini/antigravity/somnio_rules/${m.group(1)}/agents/${m.group(2)}`',
    );
    // Bare form: `agents/<file>.md` — flutter-best-practices:14 and
    // python-health-audit:7 omit the skill prefix. Anchored on the opening
    // backtick so it cannot re-match a path the prefixed rule already
    // rewrote.
    content = content.replaceAllMapped(
      RegExp(r'`agents\/([^`]+)`'),
      (m) =>
          '`~/.gemini/antigravity/somnio_rules/$planSubDir/agents/${m.group(1)}`',
    );

    // Then: rewrite references/ rule file paths.
    // Pattern: `<skill-name>/references/<path>`
    // → `~/.gemini/antigravity/somnio_rules/<skill-name>/references/<path>`
    // Absolute path because Antigravity resolves paths relative to the
    // workspace, not relative to the workflow file.
    content = content.replaceAllMapped(
      RegExp(r'`([a-z][a-z0-9-]*)\/references\/([^`]+)`'),
      (match) =>
          '`~/.gemini/antigravity/somnio_rules/${match.group(1)}/references/${match.group(2)}`',
    );

    // Then: rewrite the report-template path (assets/report-template.md),
    // mirroring the rewrite applied to reference files copied verbatim in
    // transformBundle.
    content = _rewriteTemplatePath(content, planSubDir);

    return content;
  }

  /// Rewrites the bundle-relative report template path to its installed
  /// absolute location. Antigravity resolves paths against the workspace, so
  /// a bare `assets/report-template.md` would dangle.
  String _rewriteTemplatePath(String content, String planSubDir) {
    return content.replaceAll(
      _templateRelativePath,
      '~/.gemini/antigravity/somnio_rules/$planSubDir/$_templateRelativePath',
    );
  }

  String _workflowFileName(SkillBundle bundle) {
    // somnio_flutter_health_audit.md or somnio_flutter_best_practices.md
    if (bundle.workflowPath != null) {
      final originalName = p.basenameWithoutExtension(bundle.workflowPath!);
      return 'somnio_$originalName.md';
    }
    return 'somnio_${bundle.id}.md';
  }

  // planSubDir is now a getter on SkillBundle — no local helper needed.
}

/// Alias for [AntigravityTransformer] used by the unified transformer interface.
typedef WorkflowTransformer = AntigravityTransformer;
