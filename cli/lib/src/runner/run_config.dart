import '../agents/agent_config.dart';

/// Supported AI CLI agents for chunked execution.
///
/// Deprecated: use [AgentConfig] from the agent registry instead.
enum RunAgent { claude, cursor, gemini }

/// A single parsed execution step from the plan's "Rule Execution Order".
class ExecutionStep {
  const ExecutionStep({
    required this.index,
    required this.ruleName,
    this.isMandatory = false,
    this.annotation,
  });

  /// 1-based step number from the plan.
  final int index;

  /// Rule name without @ prefix (e.g., 'flutter_tool_installer').
  final String ruleName;

  /// Whether this step aborts execution on failure.
  final bool isMandatory;

  /// Optional annotation text (e.g., 'MANDATORY - stops if FVM global fails').
  final String? annotation;
}

/// Resolved configuration for a complete chunked audit run.
class RunConfig {
  const RunConfig({
    required this.bundleId,
    required this.bundleName,
    required this.displayName,
    required this.techPrefix,
    required this.agentConfig,
    required this.steps,
    required this.ruleBasePath,
    required this.templatePath,
    required this.artifactsDir,
    required this.reportPath,
    this.model,
  });

  /// Bundle identifier (e.g., 'flutter_health').
  final String bundleId;

  /// Skill name (e.g., 'somnio-fh').
  final String bundleName;

  /// Human-readable name (e.g., 'Flutter Project Health Audit').
  final String displayName;

  /// Technology prefix (e.g., 'flutter', 'nestjs').
  final String techPrefix;

  /// Agent configuration for the AI CLI to invoke.
  final AgentConfig agentConfig;

  /// Ordered list of execution steps.
  final List<ExecutionStep> steps;

  /// Base directory where rule files are installed.
  ///
  /// Claude: `~/.claude/skills/somnio-fh/rules/`
  /// Cursor: `~/.cursor/somnio_rules/{planSubDir}/cursor_rules/`
  /// Gemini: `~/.gemini/antigravity/somnio_rules/{planSubDir}/cursor_rules/`
  final String ruleBasePath;

  /// Path to the report template file.
  final String templatePath;

  /// Artifact output directory (e.g., `./reports/.artifacts/`).
  final String artifactsDir;

  /// Final report path (e.g., `./reports/flutter_audit.txt`).
  final String reportPath;

  /// Optional model override passed to the AI CLI via `--model`.
  ///
  /// When `null`, the underlying CLI uses its default model.
  final String? model;
}
