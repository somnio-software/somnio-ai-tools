# Changelog

All notable changes to the Somnio CLI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
