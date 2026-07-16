import 'token_parsers.dart';

/// How the CLI accepts prompt text.
enum PromptStyle {
  /// Prompt via a flag (e.g., `claude -p "prompt"`).
  flag,

  /// Prompt via a subcommand (e.g., `codex exec "prompt"`).
  subcommand,

  /// Prompt as the last positional argument (e.g., `agent ... "prompt"`).
  positionalLast,
}

/// How skill files are organized on disk.
enum InstallFormat {
  /// Directory with SKILL.md + references/ + assets/ (Claude Code).
  skillDir,

  /// Single self-contained .md file (Cursor).
  singleFile,

  /// Workflow file + separate somnio_rules/ directory (Antigravity).
  workflow,

  /// Generic single markdown file per skill (Copilot, Windsurf, etc.).
  markdown,
}

/// Whether skills are installed globally or per-project.
enum InstallScope { global, project }

/// Configuration for a single AI agent supported by somnio.
///
/// Each agent has identity, execution, and installation properties.
/// CLI agents (canExecute: true) can run audits via `somnio run`.
/// IDE-only agents (canExecute: false) only receive skill installations.
class AgentConfig {
  const AgentConfig({
    required this.id,
    required this.displayName,
    this.binary,
    this.canExecute = false,
    this.promptStyle = PromptStyle.flag,
    this.promptFlag,
    this.outputFlags = const [],
    this.autoApproveFlags = const [],
    this.modelFlag = '--model',
    this.models = const [],
    this.modelTiers = const {},
    this.defaultModel,
    this.fallbackModel,
    this.installFormat = InstallFormat.markdown,
    this.installScope = InstallScope.global,
    required this.installPath,
    this.ruleExtension = '.md',
    this.executionRulesPath,
    this.readInstructionTemplate,
    this.tokenUsageParser,
    this.filePrefix = 'somnio',
    this.installUrl,
    this.installInstructions,
    this.npmPackage,
    this.detectionBinaries = const [],
    this.detectionPaths = const [],
  });

  // ── Identity ──────────────────────────────────────────────────────

  /// Unique identifier (e.g., 'claude', 'codex', 'copilot').
  final String id;

  /// Human-readable name (e.g., 'Claude Code', 'GitHub Copilot').
  final String displayName;

  // ── Execution ─────────────────────────────────────────────────────

  /// Binary name on PATH (e.g., 'claude', 'codex', 'agent').
  /// Null for IDE-only agents.
  final String? binary;

  /// Whether this agent can execute audits via `somnio run`.
  final bool canExecute;

  /// How the prompt is passed to the CLI.
  final PromptStyle promptStyle;

  /// Flag used to pass prompt (e.g., '-p', '--message').
  /// Null for positionalLast style.
  final String? promptFlag;

  /// Flags for structured output (e.g., ['--output-format', 'json']).
  final List<String> outputFlags;

  /// Flags for auto-approval / non-interactive mode.
  final List<String> autoApproveFlags;

  /// Flag for specifying the model (default: '--model').
  final String modelFlag;

  /// Available models for this agent.
  final List<String> models;

  /// Maps portable capability tiers to concrete model IDs for this agent.
  ///
  /// Audit `agents/*.md` files declare a provider-neutral
  /// `model: cheap|mid|frontier` tier rather than a hard-coded model ID, so a
  /// single skill file works across every registered agent. This map resolves
  /// those tiers to the agent's real model IDs (each value MUST already appear
  /// in [models]). Only executable agents with three distinct tiers populate
  /// it; agents lacking a clean three-tier split leave it empty and fall back
  /// via [resolveTier].
  final Map<String, String> modelTiers;

  /// Default model (first in interactive selection).
  final String? defaultModel;

  /// Cheapest model, used as fallback on quota errors.
  final String? fallbackModel;

  // ── Installation ──────────────────────────────────────────────────

  /// How skill files are organized on disk.
  final InstallFormat installFormat;

  /// Whether skills are installed globally or per-project.
  final InstallScope installScope;

  /// Install path template. Supports `{home}` and `{name}` placeholders.
  /// e.g., `{home}/.claude/skills/{name}/`
  final String installPath;

  /// File extension for rule files (e.g., '.md', '.yaml').
  final String ruleExtension;

  /// Separate path for execution rules (e.g., Cursor's somnio_rules/).
  /// Template with `{home}` and `{name}` placeholders.
  /// When null, rules are read from installPath.
  final String? executionRulesPath;

  /// Template for read instructions in step prompts.
  /// Uses `{file}` placeholder. If null, defaults to
  /// 'Read and follow ALL instructions in {file}'.
  final String? readInstructionTemplate;

  /// Function to parse token usage from CLI JSON output.
  /// Returns null if the agent doesn't expose token data.
  final TokenUsageParser? tokenUsageParser;

  /// Prefix for installed files (default: 'somnio').
  ///
  /// Only workflow-format files are actually written with this prefix. The
  /// other formats install skills under their raw bundle name, so status /
  /// uninstall / update match names via `InstalledSkillNames` and use this
  /// prefix solely to keep cleaning up legacy v1.x installations.
  final String filePrefix;

  // ── Discovery ─────────────────────────────────────────────────────

  /// URL for installation instructions.
  final String? installUrl;

  /// Multi-line manual installation instructions.
  final String? installInstructions;

  /// npm package name for auto-installation.
  final String? npmPackage;

  /// Additional binary names to check during detection.
  /// (besides [binary]). E.g., Antigravity checks 'agy', 'antigravity'.
  final List<String> detectionBinaries;

  /// Additional filesystem paths to check during detection.
  final List<String> detectionPaths;

  // ── Computed ──────────────────────────────────────────────────────

  /// Human-readable label for what this agent's installed content is called.
  String get contentLabel => switch (installFormat) {
        InstallFormat.workflow => 'workflow',
        InstallFormat.singleFile => 'command',
        _ => 'skill',
      };

  // ── Methods ───────────────────────────────────────────────────────

  /// Builds the argument list for invoking this agent's CLI.
  ///
  /// The [prompt] is placed according to [promptStyle].
  /// If [model] is provided, it's added via [modelFlag].
  List<String> buildArgs(String prompt, {String? model}) {
    final args = <String>[];

    switch (promptStyle) {
      case PromptStyle.flag:
        if (promptFlag != null) {
          args.addAll([promptFlag!, prompt]);
        }
        args.addAll(autoApproveFlags);
        args.addAll(outputFlags);
        if (model != null) args.addAll([modelFlag, model]);

      case PromptStyle.subcommand:
        if (promptFlag != null) {
          args.add(promptFlag!);
        }
        args.addAll(autoApproveFlags);
        args.addAll(outputFlags);
        if (model != null) args.addAll([modelFlag, model]);
        args.add(prompt);

      case PromptStyle.positionalLast:
        args.addAll(autoApproveFlags);
        args.addAll(outputFlags);
        if (model != null) args.addAll([modelFlag, model]);
        args.add(prompt);
    }

    return args;
  }

  /// Resolves the install path by replacing `{home}` and `{name}`.
  String resolvedInstallPath({required String home, String? name}) {
    var path = installPath
        .replaceAll('{home}', home);
    if (name != null) {
      path = path.replaceAll('{name}', name);
    }
    return path;
  }

  /// Resolves the execution rules path, falling back to install path.
  String resolvedExecutionRulesPath({
    required String home,
    String? name,
  }) {
    final template = executionRulesPath ?? installPath;
    var path = template.replaceAll('{home}', home);
    if (name != null) {
      path = path.replaceAll('{name}', name);
    }
    return path;
  }

  /// The provider-neutral capability tiers audit skills may declare.
  static const _portableTiers = {'cheap', 'mid', 'frontier'};

  /// Resolves a portable capability [tier] to a concrete model ID.
  ///
  /// Resolution order:
  /// 1. If [modelTiers] contains [tier], return its mapped model ID.
  /// 2. Otherwise fall back to [defaultModel] if set.
  /// 3. Otherwise fall back to [fallbackModel] if set.
  /// 4. Otherwise return null for a portable tier, or pass [tier] through
  ///    unchanged when it is already a concrete model ID.
  ///
  /// Agents with a default/fallback model degrade gracefully to it. Agents
  /// with no models at all (e.g. amp) resolve to null so callers omit the
  /// model flag entirely rather than passing the literal tier name — which is
  /// not a valid model for any CLI.
  String? resolveTier(String tier) {
    final mapped = modelTiers[tier];
    if (mapped != null) return mapped;
    final fallback = defaultModel ?? fallbackModel;
    if (fallback != null) return fallback;
    return _portableTiers.contains(tier) ? null : tier;
  }

  /// Formats the read instruction for a rule file in step prompts.
  String formatReadInstruction(String filePath) {
    if (readInstructionTemplate != null) {
      return readInstructionTemplate!.replaceAll('{file}', filePath);
    }
    return 'Read and follow ALL instructions in $filePath';
  }
}
