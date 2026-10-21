import '../utils/real_path.dart';
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

  /// Generic single markdown file per skill (Aider, Amazon Q; Roo Code and
  /// Kilo Code before 3.2.18).
  markdown,
}

/// Whether skills are installed globally or per-project.
///
/// [global] anchors the `{home}` placeholder in an agent's install-path
/// template at the user's home directory (e.g. `~/.claude/skills`).
/// [project] re-anchors that same placeholder at the current project root
/// instead (e.g. `<project>/.claude/skills`), so the install lives alongside
/// the codebase rather than in the user's global config.
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
    this.driveUploadApproveFlags = const [],
    this.modelFlag = '--model',
    this.models = const [],
    this.modelTiers = const {},
    this.defaultModel,
    this.fallbackModel,
    this.installFormat = InstallFormat.markdown,
    this.installScope = InstallScope.global,
    required this.installPath,
    this.projectInstallPath,
    this.globalOnly = false,
    this.ruleExtension = '.md',
    this.executionRulesPath,
    this.configHome,
    this.configHomeVariable,
    this.cleansDefaultConfigHome = true,
    this.legacyInstallFormat,
    this.legacyInstallPath,
    this.legacyExecutionRulesPath,
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

  /// Auto-approval flags for the Drive upload step of `somnio run --upload`,
  /// used instead of [autoApproveFlags] so that only that step can call the
  /// Google Drive MCP tools.
  ///
  /// Empty when the agent cannot upload reports from `somnio run`.
  final List<String> driveUploadApproveFlags;

  /// Whether `somnio run --upload` can upload reports with this agent.
  bool get supportsDriveUpload => driveUploadApproveFlags.isNotEmpty;

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

  /// Install path template for [InstallScope.project], when the agent's
  /// project layout is not [installPath] re-anchored at the project root
  /// (e.g. Copilot reads `~/.copilot/skills` but `<project>/.github/skills`).
  ///
  /// `{home}` stands for the project root. Null means [installPath].
  final String? projectInstallPath;

  /// Whether the agent has no per-project install location at all, so
  /// project-scope installs fall back to the global one.
  final bool globalOnly;

  /// File extension for rule files (e.g., '.md', '.yaml').
  final String ruleExtension;

  /// Separate path for execution rules (e.g., Cursor's somnio_rules/).
  /// Template with `{home}` and `{name}` placeholders.
  /// When null, rules are read from installPath.
  final String? executionRulesPath;

  /// The agent's global config directory as a template prefix of
  /// [installPath] (e.g. `{home}/.codex`), relocatable through
  /// [configHomeVariable].
  ///
  /// Both must be set for the override to apply.
  final String? configHome;

  /// Environment variable that relocates [configHome] for the global scope
  /// (e.g. `CODEX_HOME`, `CLAUDE_CONFIG_DIR`).
  ///
  /// When it is set and non-blank, every path template starting with
  /// [configHome] resolves under its value instead. Project-scope installs
  /// ignore it: they are anchored at the project root.
  final String? configHomeVariable;

  /// Whether remove / uninstall also clean the default [configHome] while
  /// [configHomeVariable] relocates it, where earlier releases installed
  /// regardless of the variable.
  ///
  /// False when the default directory may be another profile's live one:
  /// `~/.claude` is often a second Claude Code account next to the one
  /// `CLAUDE_CONFIG_DIR` selects, so its skills are left alone.
  final bool cleansDefaultConfigHome;

  /// The [InstallFormat] an earlier CLI release installed this agent's
  /// skills in, when that differs from [installFormat].
  ///
  /// Lets status / uninstall still recognize (and clean up) content in the
  /// old layout that no manifest records.
  final InstallFormat? legacyInstallFormat;

  /// Install path template an earlier CLI release wrote this agent's skills
  /// to, when that differs from [installPath] (e.g. Antigravity's
  /// `{home}/.gemini/antigravity`, which held `global_workflows/`).
  ///
  /// The `.somnio-skills.json` manifest there keeps recording what that
  /// release wrote, so install migrates those entries out of it and update,
  /// remove and uninstall still find them.
  final String? legacyInstallPath;

  /// Execution-rules directory an earlier CLI release wrote for this agent
  /// and this one no longer does.
  ///
  /// Manifest entries rooted at `ManifestRoot.rules` keep resolving against
  /// it, so update / remove / uninstall can delete the old copies instead of
  /// resolving them against [installPath] — where the agent's current skill
  /// directories live.
  final String? legacyExecutionRulesPath;

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
  /// [approveFlags] replaces [autoApproveFlags] for a single invocation, as
  /// the Drive upload step does with [driveUploadApproveFlags].
  List<String> buildArgs(
    String prompt, {
    String? model,
    List<String>? approveFlags,
  }) {
    final args = <String>[];
    final approve = approveFlags ?? autoApproveFlags;

    switch (promptStyle) {
      case PromptStyle.flag:
        if (promptFlag != null) {
          args.addAll([promptFlag!, prompt]);
        }
        args.addAll(approve);
        args.addAll(outputFlags);
        if (model != null) args.addAll([modelFlag, model]);

      case PromptStyle.subcommand:
        if (promptFlag != null) {
          args.add(promptFlag!);
        }
        args.addAll(approve);
        args.addAll(outputFlags);
        if (model != null) args.addAll([modelFlag, model]);
        args.add(prompt);

      case PromptStyle.positionalLast:
        args.addAll(approve);
        args.addAll(outputFlags);
        if (model != null) args.addAll([modelFlag, model]);
        args.add(prompt);
    }

    return args;
  }

  /// Resolves the install path by replacing `{home}` and `{name}`.
  ///
  /// [environment] supplies [configHomeVariable]; it defaults to empty so
  /// a caller that resolves against a non-real [home] (tests, dry runs)
  /// never picks up the user's real override by accident.
  String resolvedInstallPath({
    required String home,
    String? name,
    Map<String, String> environment = const {},
  }) =>
      _resolve(installPath, home: home, name: name, environment: environment);

  /// Resolves the execution rules path, falling back to
  /// [legacyExecutionRulesPath] and then to the install path.
  ///
  /// [legacyExecutionRulesPath] is never relocated: the releases that wrote
  /// it ignored [configHomeVariable].
  String resolvedExecutionRulesPath({
    required String home,
    String? name,
    Map<String, String> environment = const {},
  }) {
    final legacy = legacyExecutionRulesPath;
    if (executionRulesPath == null && legacy != null) {
      return _resolve(legacy, home: home, name: name, environment: const {});
    }
    return _resolve(
      executionRulesPath ?? installPath,
      home: home,
      name: name,
      environment: environment,
    );
  }

  /// Every directory a global install may live in: [resolvedInstallPath]
  /// first, then the default location when [configHomeVariable] relocates
  /// it, where releases before 3.2.12 installed regardless of the variable.
  /// The default location is only listed when [cleansDefaultConfigHome].
  List<String> resolvedGlobalInstallPaths({
    required String home,
    Map<String, String> environment = const {},
  }) {
    final current = resolvedInstallPath(home: home, environment: environment);
    final fallback = resolvedInstallPath(home: home);
    return [
      current,
      if (cleansDefaultConfigHome && fallback != current) fallback,
    ];
  }

  /// Real paths of the install directories remove, update and uninstall
  /// must leave alone: the default location while [configHomeVariable]
  /// relocates the global install and [cleansDefaultConfigHome] is false.
  ///
  /// Run from [home], the project scope resolves to that same directory, so
  /// callers skip it in every scope. Empty when the relocated directory is
  /// the default one under another name (a symlink).
  List<String> resolvedProtectedInstallPaths({
    required String home,
    Map<String, String> environment = const {},
  }) {
    if (cleansDefaultConfigHome) return const [];
    final current = realPathOf(
      resolvedInstallPath(home: home, environment: environment),
    );
    final fallback = realPathOf(resolvedInstallPath(home: home));
    return [if (fallback != current) fallback];
  }

  /// Resolves [configHome], relocated by [configHomeVariable] when
  /// [environment] sets it, or `null` when the agent declares none.
  String? resolvedConfigHome({
    required String home,
    Map<String, String> environment = const {},
  }) {
    final template = configHome;
    if (template == null) return null;
    return _resolve(template, home: home, environment: environment);
  }

  /// Every directory a project install may live in under [projectRoot]: the
  /// current project location when [supportsProjectScope], then
  /// [legacyInstallPath] re-anchored at [projectRoot] — even for an agent
  /// that has no project location anymore, so an old one stays removable.
  List<String> resolvedProjectInstallPaths({required String projectRoot}) => {
        if (supportsProjectScope)
          resolvedScopedInstallPath(
            scope: InstallScope.project,
            home: projectRoot,
            projectRoot: projectRoot,
          ),
        if (resolvedScopedLegacyInstallPath(
          scope: InstallScope.project,
          home: projectRoot,
          projectRoot: projectRoot,
        )
            case final legacy?)
          legacy,
      }.toList();

  /// Resolves [legacyInstallPath] for [scope], anchoring `{home}` like
  /// [resolvedScopedInstallPath]. Null when the agent never moved.
  ///
  /// Never relocated through [configHomeVariable]: the releases that wrote
  /// it ignored the variable.
  String? resolvedScopedLegacyInstallPath({
    required InstallScope scope,
    required String home,
    required String projectRoot,
  }) {
    final legacy = legacyInstallPath;
    if (legacy == null) return null;
    return _resolve(
      legacy,
      home: scope == InstallScope.global ? home : projectRoot,
      environment: const {},
    );
  }

  /// Substitutes the placeholders in [template], relocating a [configHome]
  /// prefix to [configHomeVariable]'s value when [environment] sets it.
  String _resolve(
    String template, {
    required String home,
    String? name,
    required Map<String, String> environment,
  }) {
    var path = template;
    final prefix = configHome;
    final variable = configHomeVariable;
    if (prefix != null && variable != null && path.startsWith(prefix)) {
      final override = environment[variable]?.trim();
      if (override != null && override.isNotEmpty) {
        path = override + path.substring(prefix.length);
      }
    }
    path = path.replaceAll('{home}', home);
    if (name != null) {
      path = path.replaceAll('{name}', name);
    }
    return path;
  }

  /// Whether this agent has a meaningful per-project install location.
  ///
  /// Project scope works by re-anchoring the `{home}` placeholder at the
  /// project root, so it only makes sense for agents whose install path (or
  /// [projectInstallPath]) is home-relative (`{home}/.claude/skills` ->
  /// `<project>/.claude/skills`) and that are not [globalOnly].
  bool get supportsProjectScope =>
      !globalOnly && (projectInstallPath ?? installPath).startsWith('{home}');

  /// Resolves the install path for [scope], anchoring at [home] for
  /// [InstallScope.global] and at [projectRoot] for [InstallScope.project]
  /// (through [projectInstallPath] when set).
  ///
  /// [environment] only applies to the global scope; see
  /// [configHomeVariable].
  String resolvedScopedInstallPath({
    required InstallScope scope,
    required String home,
    required String projectRoot,
    String? name,
    Map<String, String> environment = const {},
  }) {
    if (scope == InstallScope.global) {
      return resolvedInstallPath(
        home: home,
        name: name,
        environment: environment,
      );
    }
    return _resolve(
      projectInstallPath ?? installPath,
      home: projectRoot,
      name: name,
      environment: const {},
    );
  }

  /// Resolves the execution rules path for [scope], anchoring at [home] for
  /// [InstallScope.global] and at [projectRoot] for [InstallScope.project].
  String resolvedScopedExecutionRulesPath({
    required InstallScope scope,
    required String home,
    required String projectRoot,
    String? name,
    Map<String, String> environment = const {},
  }) {
    final global = scope == InstallScope.global;
    return resolvedExecutionRulesPath(
      home: global ? home : projectRoot,
      name: name,
      environment: global ? environment : const {},
    );
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
