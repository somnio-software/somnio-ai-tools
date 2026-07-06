# Changelog

All notable changes to the Somnio CLI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
