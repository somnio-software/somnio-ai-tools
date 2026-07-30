# Changelog

All notable changes to the Somnio CLI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.9.0] - 2026-07-30

### Added

- **AngularJS Health Audit** (`ajh` / `somnio-ajh`): new CLI audit bundle for legacy AngularJS 1.x (controllers/directives/services, `$http`/interceptors/`$rootScope`, digest-cycle hygiene, minification-safe DI, Karma/Jasmine/angular-mocks, Grunt/gulp), including an AI Harness & Adoption analysis step and framework/Bower EOL migration-risk analysis. Mirrors the `react-health-audit` structure. Registered in `skill_registry.dart`.

## [2.8.2] - 2026-07-22

### Added

- **`somnio commands install`**: New CLI subcommand to list and install root-level commands at folder scope (current working directory) into `.claude/commands/` and `.cursor/commands/` for Claude Code and Cursor. Mirrors the existing `somnio rules install` workflow. Backed by a new `CommandBundle` model, `CommandRegistry`, and `CommandInstaller`.

### Changed

- **`ship` command moved to installable command**: The `ship` skill is now an installable command (via `somnio commands install`) instead of an auto-triggering skill. No longer auto-activates on skill trigger detection.

## [2.8.1] - 2026-07-17

### Changed

- **AI Harness & Adoption rubric — versioning is now its own dimension, not an existence gate**: In all four health-audit skills (`flutter`, `react`, `nestjs`, `python`), a harness that was present on disk but excluded by `.gitignore` scored ~14/100 — indistinguishable from a repo with no harness at all — because `git ls-files` returned empty and zeroed the *existence* half of seven dimensions before any quality could be scored. The rubric now judges existence **on disk**: dimensions 1-9 are scored on what the files actually contain, whether or not they are committed. Whether the harness is versioned is scored once, in the new **dimension 10 — Harness versioning (12 pts)**, graduated 12 (fully tracked) / 8 (tracked but a `.gitignore` pattern will silently swallow every new harness file — the grandfathered trap) / 5 (partial) / 0 (nothing tracked). When dimension 10 scores 0, Section 6 caps the section at 60 ("harness básico"), so an uncommitted harness can never read as "sólido" but is no longer collapsed to the same score as no harness — and the one-line fix (`git add` / remove the `.gitignore` line) surfaces as the highest-leverage action. The remaining dimensions were rebalanced to keep the total at 100. Evidence gathering adds one `git check-ignore -v --no-index` call (the `--no-index` flag is load-bearing — without it git stays silent on already-tracked paths, hiding the grandfathered case), staying within the ≤8-call budget. Applied identically across the shared rubric, the `harness-analyzer` subagents, the `SKILL.md` step descriptions, and the report generators/enforcers/templates.

### Fixed

- **`nestjs-health-audit` rubric drift**: `references/harness-analysis.md` had diverged from the other three stacks outside its designated stack-specific section (the in-session dispatch instruction), violating the file's own byte-identical invariant. Realigned with flutter/react/python.

## [2.8.0] - 2026-07-17

### Added

- **DORA Metrics Skill**: New `dora-metrics` skill that fetches Deployment Frequency and Lead Time for Changes per project and per repo from the GitHub API (never local git), so lead time stays accurate across merge strategies including squash merges. Reads a project-to-repos mapping from `config/projects.json`, asks for missing projects instead of guessing, and reports both metrics with process-gap warnings. Read-only: never ranks, scores, or compares projects or people. Ships with a lightweight Report Writer subagent (`model: sonnet`, parametrizable to `haiku`/`opus` on explicit request) that formats the script's JSON output via a template without interpreting it, and a `references/troubleshooting.md` guide mapping each data/measurement warning to a WHAT/HOW/WHERE-TO-FIX diagnosis, scoped strictly to setup problems, never team performance. Registered in the CLI skill registry.
- **`WorkflowSkill.assetDirectories`**: Workflow skills can now declare extra directories (e.g. `scripts/`, `config/`, `agents/`, `assets/`) copied verbatim alongside their `SKILL.md` for Claude Code `skillDir` installs, so skills backed by real executable code — not just markdown instructions — install correctly via `somnio add`/`somnio install`. Used by the new `dora-metrics` skill.

## [2.7.1] - 2026-07-16

### Added

- **`somnio run --step-timeout` flag**: New CLI flag to configure the per-step timeout in minutes (e.g., `somnio run fh --step-timeout 45`). Accepts positive whole numbers; default is 30 minutes. Non-numeric, zero, negative, or decimal values are rejected with a usage error.
- **`somnio workflow run --step-timeout` flag**: Same timeout configuration for custom workflows (e.g., `somnio workflow run my-workflow --step-timeout 60`).
- **Workflow token/cost summary**: `somnio workflow run` now prints a token consumption and cost summary box at the end of the run, matching the summary shown in `somnio run` audits.
- **Markdown agent rule installs**: Eight markdown-format agents (Codex, Augment Code, Amp, Aider, Cline, OpenCode, CodeBuddy, Qwen) now have their execution rules installed automatically via the default `somnio setup` and `somnio update` paths, not just through interactive `somnio install`.
- **Rules uninstall fallback**: When uninstalling rules from a stack whose install manifest is missing (from installs predating this version), Somnio now falls back to deleting only the known adapter files derived from the upstream repo. If the repo cannot be located, the files are left in place and a warning is logged instead of being removed silently.
- **`flutter-health-audit` state management analysis step**: The audit scored a mandatory `State Management` section and an `Architecture` section with no step producing evidence for either. A new `references/state-management-analysis.md` rubric and `state-management-analyzer` subagent (`model: mid`) now detect the state management library and pattern, and `references/repository-inventory.md` gained folder-organization and architecture analysis. Wired into both execution paths — the CLI `Rule Execution Order` (now 13 rules) and the in-session orchestrator wave dispatch.
- **`allowed-tools` block sequences are honoured**: `ContentLoader.loadPlanFrontmatter` kept only string-valued frontmatter keys, so a skill authoring `allowed-tools` as a YAML block sequence (`skills/ship/SKILL.md`) had it dropped and silently fell back to the installer's generic default — costing `ship` the `AskUserQuestion` tool its own plan calls four times. List values are now normalised to the comma-separated form.

### Fixed

- **Exit codes on install failures**: `somnio setup` and `somnio update` now exit with code 1 (ExitCode.software) when any bundle or workflow-skill install fails, instead of always exiting with code 0 on success. Fixes CI/automation detection of silent failures.
- **`somnio run <tech>-best-practices` never wrote its report**: the runner dispatched the terminal step to `executeReportGenerator` only when the rule name matched `report-generator` exactly, but all four `_plan` bundles name it `best-practices-generator`. The step fell through to the generic branch, which never reads the template or writes `reportPath`, while `_cleanPreviousRun` had already deleted the previous report — so the run destroyed a good report, wrote no replacement and exited 0 reporting success. This is the same defect 2.7.0 fixed for the health audits, shipped a second time through a different rule name; dispatch now goes through `isReportGeneratorRule` / `formatEnforcerRuleFor` in `rule_names.dart`, with an integration test asserting the real parser output for every runnable bundle.
- **Audit step counters and time attribution**: the format-enforcer result was appended to the same list the counters read, printing impossible totals like `11/10 steps`, and failed or timed-out AI steps were billed as pre-flight time in the usage summary. Counters now read a dedicated step list, and every result is classified into exactly one bucket.
- **`somnio add` generated invalid or corrupted Dart**: the registry escaper handled apostrophes only, so a description containing `$` was emitted raw into a single-quoted Dart literal and interpolated. The `dart format` gate is syntax-only and passes such a file, so a compile-broken `skill_registry.dart` was written and reported as success. Backslashes, `$` and apostrophes are now escaped (backslash first) across every generated field, and `hasConflicts` escapes before comparing so detection cannot drift from generation.
- **`somnio add` wrote Windows path separators into the registry**: auto-detected paths were emitted with the host's separator, so a Windows run injected backslash paths into checked-in source consumed on every platform. Paths are now normalised to POSIX at detection.
- **`somnio add` registered duplicate ids**: two skill directories classifying to the same bundle type produced identical ids and names, and the second install silently overwrote the first. Ambiguous detections are now rejected with a usage error, and duplicates are detected within a batch as well as against the existing registry.
- **Workflow resume was skipped when the failed step was the first one**: the resume prompt was gated on the index of the first pending step, but under wave parallelism "step 1 failed while steps 2..N succeeded" is the normal failure shape and yields index 0 — read as "no previous run". Saved progress was discarded and every completed step re-executed, overwriting good outputs. Resume is now an explicit flag gated on completed work, and the runner reconciles progress by file name rather than by index.
- **A stale output file marked a workflow step that produced nothing as successful**: the executor proves a step ran by checking its output file exists, but never cleared it first, so a file left by an earlier run satisfied the check and fed stale content to every downstream `{step_N_output}` consumer. The output is now removed before the AI is spawned.
- **An unrecognized `needs` value was silently dropped**: anything outside the recognised forms collapsed to no dependency, so a step meant to run after others joined wave 1 and ran concurrently with them. Invalid values now fail the workflow with the offending step and value named.
- **A bad dependency graph exited 64 with CLI usage text**: `WavePlanner`'s `FormatException` escaped to the arg parser's handler, so a cyclic or out-of-range graph printed usage as if the command had been typed wrong. It is now caught and reported as a workflow error (exit 70), before progress is saved.
- **A workflow with zero steps reported success**: `somnio workflow plan` and `run` now fail fast instead of printing "Workflow completed!" and exiting 0.
- **An unparseable workflow config was reported as "No config file"**: a malformed config was indistinguishable from a missing one, misattributing the cause of a defaulted model mapping. The two cases are now distinct and a parse failure is an error.
- **AntigravityTransformer never installed a bundle's `agents/` directory**: six workflows' first instruction is to read `<skill>/agents/orchestrator.md`, but the transformer emitted only `references/`, the template and the plan — so every orchestrator entry point dangled. Agent files are now emitted and their paths rewritten to the installed location, in both the prefixed and bare (`agents/x.md`) forms the shipped workflows use.
- **AntigravityTransformer left the report template path unrewritten**: `assets/report-template.md` stayed relative in workflow content while `references/` paths were rewritten, so the generator step pointed at a path that does not exist under the install root.
- **Installers discarded the authored `SKILL.md` frontmatter**: both `ClaudeTransformer` and `AgentInstaller` rebuilt `description` from the registry's short display string, dropping the `Use when …` / `Triggers on: …` clauses that drive skill auto-activation. All 16 skills diverged. The authored description now wins, with the registry as fallback.
- **Emitted frontmatter broke on unusual authored values**: a description containing `: ` was parsed as a nested mapping key, and a literal (`|`) block's newlines truncated the value at its first line — the form `skills/optimize-claude-config/SKILL.md` authors. A new `yaml_frontmatter.dart` folds descriptions into a `>-` block and quotes single-line values such as `allowed-tools` only when the plain form would be misparsed, so existing output is unchanged.
- **`workflow-builder`'s `references/` was never installed**: its plan links to `references/plan.md` and `references/run.md`, which `WorkflowSkill` had no concept of. Workflow skills can now declare a references directory; `skillDir` installs them as siblings and the flat formats append them inline.
- **Work-log hook dropped entries from concurrent projects**: the Stop hook's 5-second debounce was keyed on a single global per-day log file, so a second project logging within 5 seconds of the first was silently discarded — while two turns of the *same* session 1 second apart both wrote, which is the case the debounce existed to prevent. It is now keyed per session, so it suppresses the case it must and permits the case it must not.
- **`optimize-claude-config`'s `allowed-tools` was a space-separated blob**: `Bash Read Edit Write` instead of the comma-separated form all ten sibling skills use. Under a comma-splitting parser this grants none of the four declared tools. The file ships verbatim through the marketplace plugin symlink, and — since installers now re-emit the authored value — through `somnio install` as well.

- **`somnio uninstall` left Cursor execution rules behind**: `~/.cursor/somnio_rules/` was never removed, because Cursor was excluded from the only cleanup path that deletes execution rules. It is now removed like every other agent's.
- **`somnio uninstall` left Claude skills behind**: cleanup iterated a hardcoded skill list that had drifted from `SkillRegistry`, so `python-health-audit`, `python-best-practices`, `dart-model-from-json`, `optimize-claude-config` and the legacy `somnio-rh` / `somnio-rp` were never removed from `~/.claude/skills/`. The list is now derived from the registry, so new skills are covered automatically.
- **`somnio uninstall` skipped `~/.agents/skills/`**: skills.sh's canonical location was only cleaned when `~/.claude/skills/` also existed, so it leaked whenever the symlinks were already gone. Both locations are now cleaned independently.

### Removed

- **`somnio install --force` flag**: Removed the `--force` flag from the `somnio install` command. The flag was documented but never implemented — `somnio install` always overwrote files regardless of the flag. Removing it removes a misleading flag but changes no actual behavior.

### Security

- **Shell command injection via `.nvmrc` in the NestJS pre-flight**: `_readNodeVersion` returned the file's contents with only `.trim()` applied and interpolated them straight into a `bash -c` script, so auditing an untrusted repo whose `.nvmrc` contained shell metacharacters executed them with the invoking user's privileges — before any AI step and before the user approved anything, while the pre-flight reported PASSED. Node version specifiers are now validated at read time against a strict allowlist (`18`, `v18.17.0`, `lts/*`, `lts/iron`, `node`, `stable`), rejecting anything else with a warning. Validating at the source covers every consumer of the value.

## [2.7.0] - 2026-07-14

### Added

- **AI Harness & Adoption audit section**: All four health audits (`flutter-health-audit`, `nestjs-health-audit`, `python-health-audit`, `react-health-audit`) now score a 9th dimension — `CLAUDE.md`, `.claude/rules/`, `settings.json` permissions and hooks, custom agents, commands/skills, the pre-push git hook, advanced orchestration, and lifecycle/versioning — via a new `harness-analyzer` subagent (`model: mid`) and shared `references/harness-analysis.md` rubric (100 points across 9 dimensions, existence + quality split). Weighted at 0.10, with the existing 8 sections rescaled to sum to 0.90.

### Fixed

- **Runner report-generator dispatch (Phase 0)**: `somnio run` compared `step.ruleName.endsWith('_report_generator')` against rule names that are always hyphenated (`report-generator`), so the comparison never matched — `executeReportGenerator()` and the follow-on format-enforcer pass were unreachable, and every audit silently skipped enforcement. Fixed to compare against the exact rule name via a new `kReportGeneratorRuleName` / `kReportFormatEnforcerRuleName` constant.
- **Runner pre-flight artifact lookup (Phase 0)**: pre-flight artifacts were written with an underscore-joined `<techPrefix>_<rule_name>` key but looked up by bare rule name, so `flutter`/`nestjs`/`security` pre-flight steps (tool install, version checks, etc.) never matched their cached artifact and were always re-executed through the AI instead of reusing the deterministic pre-flight result. Fixed via a new pure, tested `preflightKey()` helper in `cli/lib/src/runner/rule_names.dart`, used at all three lookup sites in `run_command.dart`.
- **Rubrics no longer hardcode invoker-specific artifact paths**: the shared `references/` rubrics of the four health audits hardcoded the in-session artifact path (e.g. `reports/.artifacts/flutter_health/step_07_harness_analysis.md`), contradicting the CLI runner's own path convention (`step_{plan-index}_{rule-with-hyphens}.md` per `_artifactPath()`) when run via `somnio run`. Rubrics now defer to the path the invoker names; report generators locate the coverage/harness artifacts by glob (`step_*_test?coverage.md`) instead of an exact filename.
- **`SOMNIO_ARTIFACT_FILE` exported to step processes**: `StepExecutor` now exports the step's artifact path as the `SOMNIO_ARTIFACT_FILE` environment variable when spawning the AI CLI, so bash scripts embedded in rule files (e.g. the Python coverage runner) resolve the CLI's artifact path deterministically instead of relying on the model substituting it. In-session dispatch leaves the variable unset and falls back to the Dispatch Table path.

## [2.6.0] - 2026-06-04

### Added

- **Python Health Audit Skill**: New `python-health-audit` skill (`somnio-ph` / `ph`) that performs a comprehensive Python Project Health Audit. Analyzes tech stack, architecture, API/interface design, data layer, testing, code quality, CI/CD, and documentation. Produces a Google Docs-ready report with section scores and weighted overall score.
- **Python Best Practices Skill**: New `python-best-practices` skill (`somnio-pp` / `pp`) that runs a micro-level Python code quality audit. Validates code against live GitHub standards for typing, code style, function design, data validation, error handling, module structure, and testing. Produces a detailed violations report with prioritized action plan.
- **Python agent rules stacks**: Added `django`, `fastapi`, `flask`, and `python` to the `AgentRuleRegistry.stacks` list, enabling `somnio rules install` to target Python and its major frameworks alongside the existing Flutter/NestJS/React stacks.
- **Multi-model subagent orchestration**: All nine audit skills now fan out into a per-skill orchestrator + tiered analysis subagents (`cheap`/`mid`) + a dedicated frontier-tier report-writer, concentrating premium inference on the single user-facing report.
- **Portable model-tier convention**: Added the provider-neutral `cheap`/`mid`/`frontier` model-tier convention for audit `agents/*.md`, backed by a `modelTiers` map and a `resolveTier(...)` helper on `AgentConfig` that resolves tiers to per-agent model IDs (populated for Claude, Cursor, Gemini, Codex, Augment, and Qwen).
- **Subagent bundling/install**: Each in-scope skill's `agents/` directory is now bundled (via `SkillBundle.agentsDirectory` + `ContentLoader.loadAgentFiles`) and, for the Claude skill-dir install format, written under `<skill>/agents/` with each subagent's `model: <tier>` frontmatter resolved to the target agent's concrete model ID at install time; non-skill-dir formats skip `agents/` (no native subagent-dispatch surface).

### Changed

- **Retiered audit subagents**: Audit skills are retiered so mechanical scanners run on the cheap tier while synthesis runs on the frontier tier, concentrating premium inference on the single user-facing report.
- **`somnio run` per-step tiers**: `somnio run` now captures an optional per-step model tier (`{model: cheap|mid|frontier}` on a Rule Execution Order step) and resolves it via each agent's `modelTiers` before executing that step, with graceful fallback to `defaultModel` for agents lacking distinct tiers; the existing `fallbackModel` quota-retry behavior is preserved.

## [2.5.0] - 2026-05-30

### Added

- **Interactive install wizard**: `somnio install` now lets you pick which agents and skills to install via an arrow-key + spacebar menu instead of installing everything. New `--all-skills` flag installs every skill without prompting, and `--skills <ids>` installs a specific comma-separated subset (skips the wizard). When there is no interactive terminal (CI, pipes) it falls back to installing all skills so automation never hangs.
- **`somnio update` skill selection**: After updating the CLI, `update` now opens the same agent/skill wizard instead of silently reinstalling everything. Non-interactive runs (CI, pipes) still reinstall all skills, and `--all-skills` forces that behavior in a terminal.
- **Dart Model from JSON Skill**: New standalone `dart-model-from-json` skill that generates Dart model classes from a JSON structure using `json_annotation` and `equatable` (`copyWith`, `fromJson`, `toJson`, Equatable props; handles nested objects and arrays). Registered in the CLI skill registry.
- **Optimize Claude Config Skill**: New standalone `optimize-claude-config` skill that audits and optimizes a repo's Claude Code configuration so path-scoped rules load lazily and `CLAUDE.md` stays a lightweight index. Maps the real project tree (`git ls-files`) to validate every glob, migrates rule frontmatter to the native lazy-load `paths:` form, flags stale/over-broad globs, slims redundant `CLAUDE.md` content, and installs the read-not-create `PreToolUse(Write)` hook. Idempotent and conservative; supports `--audit-only` and an optional path argument. Stack-agnostic (requires `git` + `python3`). Registered in the CLI skill registry.
- **Flutter Rules**: Added `code-patterns`, `layout`, and `ui-theming` rules under `agent-rules/rules/flutter/`.
- **Test coverage**: Added a comprehensive unit-test suite (~21 new/extended test files, 379 tests) covering transformers, agents, content loaders, installers, runner, workflow, and utils. Every non-excluded source file under `cli/lib/` now has **100% line coverage**.

### Changed

- **Coverage gate (`pre-push`)**: The hook now enforces the threshold **per file** instead of as an aggregate average, and runs `format_coverage --check-ignore` so files marked `// coverage:ignore-file` (entrypoints, command shells, interactive prompts, and process-spawning orchestrators) are excluded from the calculation. It lists every offending file when the gate fails.
- **Interactive menus**: Migrated all selection prompts (`install`, `add`, `workflow`) from `mason_logger` to `interact_cli` with a Somnio-branded theme. The new menus redraw with relative cursor movement, fixing the jumping / duplicated-line rendering glitches the previous prompts showed when the list reached the bottom of the terminal.
- **Agent Rules**: Refactored flutter, nestjs, and react rule content across stacks and regenerated all tool adapters (Claude, Cursor, Windsurf, Copilot, Codex, Antigravity).
- **Docs**: Updated `docs/agent-rules.md` and the Cursor/Antigravity adapter READMEs to reflect the current flutter rule set.
- **flutter-best-practices Skill**: Updated standards references to point at `code-patterns` instead of the removed `dart-model-from-json` rule.

### Removed

- **Flutter Rule**: Removed `agent-rules/rules/flutter/dart-model-from-json.md`; its functionality now lives in the `dart-model-from-json` skill.

## [2.4.0] - 2026-05-26

### Added

- **Work-Log Hook**: New `hooks/work-log-stop.sh` script (portable, version-controlled) that appends a Haiku-generated 2-3 sentence summary of each Claude Code session turn to `~/.work-log/YYYY-MM-DD.md`. Logs root repo + worktree name (`mini-meta-repo/refactor-flutter_http`) so entries map cleanly to Clockify projects.
- **CLI `somnio hooks`**: New command to opt-in install the work-log Stop hook — copies the script to `~/.claude/hooks/`, makes it executable, and merges the Stop hook entry into `~/.claude/settings.json`. Idempotent; supports `--force` and `--verbose`.
- **Clockify log-based mode**: `clockify-tracker` skill now supports a second mode triggered by "use logs" / "usa los logs". Reads `~/.work-log/` daily files, maps repos to Clockify projects via `~/.clockify-prefs.json` (persisted), handles multi-project days with user-defined hour splits, generates 2-sentence executive summaries per entry, and shows a full preview before posting.
- **Docs**: Added `docs/work-log-stop-hook.md` explaining the hook design, setup, and relation to Clockify.

### Changed

- **Work-Log Hook**: Hook now logs the root git repo name instead of the worktree directory name, and appends the worktree name as a suffix (`root/worktree`) for traceability. Uses `which claude` instead of a hardcoded binary path for portability.
- **`clockify-tracker` command**: Updated description to document both manual mode (unchanged) and the new log-based mode.

## [2.3.0] - 2026-05-12

### Added

- **Agent Rules**: Multi-tool adapter system with rule files for Claude, Codex, Copilot, and Windsurf across functions and TypeScript stacks
- **Agent Rules**: Canonical rule sources under `agent-rules/rules/` for functions architecture, functions testing, and TypeScript best practices
- **Ship Skill**: New `ship` skill for automated PR workflow
- **Skills**: Report templates (`report-template.md`) added to all audit and best-practices skills (Flutter, NestJS, React, Security)

### Changed

- **CLI**: Updated `add`, `rules`, and `run` commands, registries, transformer, and scaffold generator to support the new agent-rules adapter system
- **Skills**: Updated SKILL.md files and references for flutter-best-practices, flutter-health-audit, nestjs-best-practices, nestjs-health-audit, react-best-practices, react-health-audit, and security-audit

### Removed

- **Plugins**: Removed legacy plugins — `engineering-management`, `marketing`, and `operations`

## [2.2.0] - 2026-04-16

### Added

- **Agent Rules**: Per-stack rule installs — Claude modular layout support with separate files per stack (Flutter, NestJS, React) instead of a single merged `CLAUDE.md`
- **Agent Rules**: `somnio rules uninstall` now cleans up all installed rule files
- **Engineering Management**: 10 new external service connectors for the engineering management plugin

### Changed

- **Health Audits**: Improved installation logic with stricter execution discipline and parallelization for faster audit runs
- **Agent Rules**: Migrated code generation script from shell to Python; generated outputs are now gitignored

### Fixed

- **CLI**: Fixed Antigravity skill installation and registered missing skills
- **Flutter Health Audit**: Enforced per-section coverage breakdown in the Testing section of the report

## [2.1.1] - 2026-03-25

### Fixed

- **Rules Install**: Fixed agent detection not finding Cursor (via `/Applications/Cursor.app`) or Antigravity (via `agy`/`antigravity` binaries) — detection now checks all methods: binary, detectionBinaries, detectionPaths, and installPath fallback
- **Rules Install**: Fixed screen reprinting/flickering when navigating the agent selection with arrow keys — detection table no longer renders above the interactive picker
- **Rules Install**: Fixed Claude adapter (`CLAUDE.md`) not found on git-based installs — file was not tracked in git
- **CLI**: Fixed `version.dart` version constant out of sync with `pubspec.yaml` (was stuck at `2.0.0`)

## [2.1.0] - 2026-03-25

### Added

- **Agent Rules**: New `somnio rules` CLI command with `install` and `status` subcommands for multi-agent coding rules management
- **Agent Rules**: Coding standards for NestJS, Flutter, and React with adapters for Claude, Cursor, Windsurf, Copilot, Codex, and Antigravity
- **Clockify Tracker**: New `clockify-tracker` skill with Clockify REST API integration for time tracking
- **Clockify Tracker**: New `clockify-tracker` command to expose the skill via CLI

### Changed

- **Plugins**: Renamed `plugins/developer` to `plugins/development` across all references and documentation

### Fixed

- **CLI**: Fixed `plan_parser` command handling and improved argument resolution
- **CLI**: Added `plan_parser` unit and integration tests for better reliability

## [2.0.0] - 2026-03-25

### Added

- **Plugin Architecture**: Native Claude Code plugin support with `.claude-plugin/` structure and `plugin.json` manifests
- **Workflow System**: Custom workflow system for multi-step, multi-model AI task orchestration
- **Git Skills**: New git-related skills including `git-commit-format` and `git-branch-format`
- **Marketing Plugin**: New `somnio-marketing` plugin with content strategy, ASO audits, and campaign analysis skills
- **Operations Plugin**: New `somnio-operations` plugin for user stories, backlog management, and project workflows
- **Engineering Management Plugin**: New `somnio-engineering-management` plugin with performance reviews and HandShake acknowledgement generation
- **Report Metadata**: Metadata fields (model, timestamp, agent version) injected into health audit reports

### Changed

- **Architecture**: Complete refactor to Agent Skills plugin architecture — skills are now distributed as Claude Code plugins (breaking change)
- **CLI**: Migrated from `skills.sh` shell scripts to structured Dart-based plugin installer
- **Multi-Agent Registry**: Data-driven multi-agent registry supporting 17 agents across all audit types

## [1.0.9] - 2026-02-27

### Added

- **Health Audit Reports**: Code Coverage field in Testing section (below Score)
- **Flutter**: Overall coverage (lib + packages) for single app; per-app overall for monorepo (apps/)
- **NestJS**: Total project coverage aggregated from lcov.info and coverage-summary.json
- **CLI preflight**: Automatic Code Coverage computation and injection into test_coverage artifacts

### Changed

- **Flutter test coverage**: Mandatory Code Coverage output in COVERAGE OVERVIEW
- **NestJS test coverage**: Mandatory Code Coverage output with lcov/coverage-summary parsing
- **Report templates**: Testing section includes Code Coverage placeholder
- **Report generators**: Extract Code Coverage from test_coverage artifact for Testing section

## [1.0.8] - 2025-02-26

### Added

- **Security Audit**: New `security_dependency_age.yaml` rule to detect outdated and deprecated packages per ecosystem
- **Security Audit**: New `security_gitleaks.yaml` rule for git history secret scanning with install recommendation
- **Security Audit**: New `security_sast.yaml` rule for static application security testing
- **Security Audit**: New `security_trivy.yaml` rule for container and filesystem vulnerability scanning

### Changed

- **CLI `somnio run`**: Added Gemini model support (`gemini-3-flash-preview`, `gemini-3-pro-preview`, `gemini-3.1-pro-preview`)
- **Security Audit**: Enhanced `security_dependency_audit.yaml` with improved vulnerability detection
- **Security Audit**: Updated `security_file_analysis.yaml` with expanded sensitive file checks
- **Security Audit**: Refined `security_gemini_analysis.yaml` for Gemini CLI integration
- **Security Audit**: Improved `security_report_format_enforcer.yaml` and `security_report_generator.yaml`
- **Security Audit**: Expanded `security_secret_patterns.yaml` with additional secret detection patterns
- **Security Audit**: Updated `security_tool_installer.yaml` with new tool support (Trivy, Gitleaks)
- **Security Audit**: Updated `security.plan.md` and workflow with new modular execution steps
- **Flutter/NestJS**: Updated `best_practices.plan.md` in both plans

### Fixed

- **Health audit follow-up**: When user responds YES/Y after a health audit, Best Practices and Security Audit are now actually executed instead of only showing the command
- **Health audit follow-up**: Extended prompt to suggest both Best Practices Check and Security Audit (previously only suggested Security Audit)
- **Health audit follow-up**: Per-bundle artifacts and report paths to avoid overwriting when running sequential audits
- `.gitignore` updates for security audit artifacts

## [1.0.7] - Previous

- Add security audit plan and Gemini model updates (#30)
- Interactive CLI selection and model validation for somnio run (#29)
- Improved banner using company colors (#28)
- NestJS Antigravity Workflows (#27)
- Setup command for AI CLI install (#26)
- Cursor CLI Support (#25)
