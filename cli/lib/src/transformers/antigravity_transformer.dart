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
  /// Transforms a skill bundle into Antigravity format.
  AntigravityOutput transformBundle(
    SkillBundle bundle,
    ContentLoader loader,
  ) {
    var workflowContent = loader.loadWorkflow(bundle) ?? '';
    final planContent = loader.loadPlan(bundle);

    // Rewrite paths in workflow content
    workflowContent = _rewritePaths(workflowContent);

    // Determine workflow file name
    final workflowFileName = _workflowFileName(bundle);

    // Collect all rule files to copy
    final ruleFiles = <String, String>{};

    // Determine the plan subdirectory name
    final planSubDir = bundle.planSubDir;

    // Copy YAML rule files
    final allFiles = loader.listAllRuleFiles(bundle);
    for (final relativePath in allFiles) {
      final absPath = loader.rulesFilePath(bundle, relativePath);
      final content = File(absPath).readAsStringSync();
      ruleFiles['$planSubDir/references/$relativePath'] = content;
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
    // Soft-skip bundles without workflow files
    if (bundle.workflowPath == null) {
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

  String _rewritePaths(String content) {
    // First: rewrite workflow cross-references (must be done before
    // the general path rewrite catches them)
    // Pattern: `<prefix>_best_practices_check/.agent/workflows/<name>.md`
    content = content.replaceAllMapped(
      RegExp(
        r'`((\w+)_best_practices_check)/\.agent/workflows/(\w+)\.md`',
      ),
      (match) {
        final workflowName = match.group(3)!;
        return '`somnio_$workflowName.md`';
      },
    );

    // Then: rewrite cursor_rules and plan paths like:
    //   `<prefix>_project_health_audit/cursor_rules/...`
    //   `<prefix>_best_practices_check/cursor_rules/...`
    // to:
    //   `~/.gemini/antigravity/somnio_rules/<prefix>_.../cursor_rules/...`
    // Absolute path because Antigravity resolves paths relative to the
    // workspace, not relative to the workflow file.
    final pathPattern = RegExp(
      r'`(\w+_(?:project_health_audit|best_practices_check|audit)/[^`]+)`',
    );
    content = content.replaceAllMapped(pathPattern, (match) {
      return '`~/.gemini/antigravity/somnio_rules/${match.group(1)}`';
    });

    return content;
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
