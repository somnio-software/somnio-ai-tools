# Somnio Technology Tools

A centralized repository for Somnio Software's technology department containing all tools developed to accelerate project analysis, improve code quality, and optimize development processes.

## 🎯 Purpose

This repository's main objectives are:

- **Centralize tools**: Keep all analysis and development tools in one place
- **Accelerate analysis**: Provide automated tools to evaluate project health
- **Improve quality**: Establish consistent development standards and processes
- **Optimize processes**: Automate repetitive analysis and auditing tasks
- **Facilitate maintenance**: Create reusable and scalable tools

## ⚡ Getting Started

### 📦 Install the CLI

Before using any tools, install the Somnio CLI to easily install and manage AI agent skills:

```bash
dart pub global activate --source git https://github.com/somnio-software/technology-tools --git-path cli
```

### 🚀 Quick Start

For first-time users, run the guided setup wizard. It checks which AI CLIs you have installed, helps install missing ones, and lets you choose which technologies to set up:

```bash
somnio setup
```

Already have your CLIs installed? Use `init` to detect agents and install skills directly:

```bash
somnio init
```

### 🤖 Supported Agents

Somnio supports **11 CLI agents** for running audits and **5 IDE-only agents** for skill installation — all driven by a single agent registry.

**CLI agents** (for `somnio run`): Claude Code, Cursor, Gemini CLI, Codex, Augment Code, Amp, Aider, Cline, OpenCode, CodeBuddy, Qwen

**IDE-only agents** (for `somnio install`): GitHub Copilot, Windsurf, Roo Code, Kilo Code, Amazon Q

Install skills to any agent:

```bash
somnio install --agent claude      # Install to Claude Code
somnio install --agent copilot     # Install to GitHub Copilot
somnio install --agent windsurf    # Install to Windsurf
somnio install --all               # Install to all detected agents
```

### 📚 CLI Documentation

For detailed CLI usage, commands, and advanced options, see the [CLI README](cli/README.md).

**Available CLI Commands:**
- `somnio setup` - Full guided setup: install CLIs, select technologies, install skills
- `somnio init` - Auto-detect agents, select technologies, and install skills
- `somnio install` - Install skills to any supported agent
- `somnio run <code>` - Run a health or security audit step-by-step from the project terminal
- `somnio status` - Show CLI availability and installed skills status
- `somnio update` - Update CLI and reinstall skills
- `somnio uninstall` - Remove all installed skills
- `somnio add` - Add new technology skill bundles
- `somnio quote` (or `somnio q`) - Display a random Somnio team quote

Legacy aliases (`somnio claude`, `somnio cursor`, `somnio antigravity`) still work and map to `somnio install --agent <id>`.

### 🏃 Running Audits from the Terminal

Use `somnio run` from the target project's root to execute a health or security audit. The CLI handles setup steps (tool installation, version alignment, test coverage) directly via pre-flight, then delegates analysis steps to an AI CLI in fresh contexts.

```bash
# From a Flutter project root
somnio run fh

# From a NestJS project root
somnio run nh

# From any project root (framework-agnostic security audit)
somnio run sa
```

| Code | Audit |
|------|-------|
| `fh` | Flutter Project Health Audit |
| `nh` | NestJS Project Health Audit |
| `sa` | Security Audit (framework-agnostic) |

You can specify an agent and model explicitly, or let the CLI auto-detect and prompt interactively:

```bash
somnio run fh --agent claude --model opus
somnio run nh --agent gemini -m gemini-3-pro
somnio run fh --agent codex             # Use OpenAI Codex CLI
somnio run sa                           # Auto-detect agent, interactive model
```

After a health audit completes, the CLI will ask if you want to run a security audit as well.

Artifacts are saved to `./reports/.artifacts/` and the final report to `./reports/`. See the [CLI README](cli/README.md) for all flags (`--agent`, `--model`, `--skip-validation`, `--no-preflight`).

## 🛠️ Available Tools

This repository contains technology-specific auditing and analysis tools organized by technology stack:

### Flutter Plans
Comprehensive auditing and best practices validation tools for Flutter/Dart projects.

**Location**: `flutter-plans/`

**Documentation**: See `flutter-plans/README.md` for detailed information about available Flutter tools and usage instructions.

### NestJS Plans
Auditing system for NestJS backend and cloud functions projects.

**Location**: `nestjs-plans/`

**Documentation**: See `nestjs-plans/README.md` for current status and TODO items.

### NestJS Project Health Audit
Complete auditing system for NestJS/Node.js backend projects that includes:

- **Automated analysis**: 8 analysis categories with scoring (Tech Stack, Architecture, API Design, Data Layer, Testing, Code Quality, Documentation, CI/CD)
- **Monorepo support**: Handles single-app and monorepo structures (nx, turborepo, lerna, custom)
- **Standardized reports**: 15-section format ready for Google Docs
- **API design analysis**: REST/GraphQL validation, DTOs, OpenAPI/Swagger documentation
- **Test coverage**: Execution, aggregation, and 70% minimum threshold validation
- **ChatGPT integration**: Specialized prompt for generating executive summaries

**Location**: `nestjs-plans/nestjs_project_health_audit/`

**Documentation**: See `nestjs-plans/nestjs_project_health_audit/README.md` for detailed instructions.

### Security Audit
Standalone, framework-agnostic security audit that detects the project type at runtime and adapts checks accordingly. Can be run independently or after a health audit.

- **Framework-agnostic**: Auto-detects Flutter, NestJS, Node.js, Go, Rust, Python, or generic projects
- **Sensitive file analysis**: Scans for exposed credentials, API keys, keystores, and checks .gitignore coverage
- **Source code secret scanning**: Detects hardcoded secrets, tokens, passwords, and cloud credentials in source code
- **Dependency vulnerability audit**: Runs native package manager scans (`npm audit`, `pub outdated`, `pip audit`, `cargo audit`, etc.)
- **Gemini AI analysis (optional)**: Leverages Gemini CLI with the security extension for advanced vulnerability detection - works with API key or Google subscription
- **Severity-classified reports**: Findings categorized as HIGH, MEDIUM, LOW with a remediation priority matrix

**Location**: `security-plans/security_audit/`

**Documentation**: See `security-plans/README.md` for detailed information about available security tools and usage instructions.

**CLI command**: `somnio run sa`

**IDE skill**: `/somnio-sa`

## 📁 Repository Structure

```
technology-tools/
├── flutter-plans/                        # Flutter tools
│   ├── flutter_project_health_audit/    # Health audit system
│   ├── flutter_best_practices_check/     # Code quality checker
│   └── README.md
├── nestjs-plans/                        # NestJS tools
│   ├── nestjs_project_health_audit/    # Health audit system
│   ├── nestjs_best_practices_check/     # Code quality checker
│   └── README.md
├── security-plans/                      # Security tools
│   ├── security_audit/                  # Framework-agnostic security audit
│   │   ├── plan/                        # Execution plan
│   │   ├── cursor_rules/                # Analysis rules (YAML)
│   │   │   └── templates/               # Report template
│   │   ├── .agent/workflows/            # Antigravity workflow
│   │   └── env/                         # Environment variable template
│   └── README.md
├── cli/                                 # Somnio CLI tool
└── README.md                            # This file
```

Each tool directory contains:
- `cursor_rules/` - Analysis rules (YAML files)
- `plan/` - Execution plans
- `cursor_rules/templates/` - Report templates
- `.agent/workflows/` - Antigravity workflow definitions

## 🚀 Quick Start

### For Flutter projects

Navigate to the Flutter plans directory and follow the instructions in the Flutter README:

```bash
cd flutter-plans/
# See flutter-plans/README.md for detailed instructions
```

### For NestJS projects

Navigate to the NestJS plans directory and check the current status:

```bash
cd nestjs-plans/
# See nestjs-plans/README.md for current status and TODO items
```

### For NestJS Health Audit
```bash
# Navigate to the specific tool
cd nestjs-plans/nestjs_project_health_audit/

# Follow instructions in the specific README
# See nestjs-plans/nestjs_project_health_audit/README.md
```

### For Security Audits

Run the standalone security audit from any project root. It auto-detects the project type:

```bash
# Via CLI (from the target project root)
somnio run sa

# Via IDE skill
/somnio-sa
```

The security audit can also be triggered after completing a health audit - the CLI will prompt you automatically.

To use the optional Gemini AI analysis, either set `GEMINI_API_KEY` in your environment or sign in with `gemini auth login` (Google One AI Premium subscription).

### For new tools

1. Create new folder with descriptive name (e.g., `react/`, `nodejs/`)
2. Include complete documentation in README.md within the folder
3. Update this main README with the new tool category

## 🔧 Development

### Adding new tools

1. Create folder with descriptive name
2. Include complete documentation in README.md within the folder
3. Update this main README with the new tool category
4. Follow established documentation standards

### Documentation standards

- Complete README.md in each technology folder
- Clear usage instructions
- Practical examples
- Documented file structure
- Tool-specific details should be in the technology folder's README

### Code Quality Standards

All YAML rule files follow strict formatting standards:
- **Line Length**: Maximum 80 characters per line
- **Formatting**: Commands split using shell continuation (`\`)
- **Descriptions**: Use folded scalar format (`>`) for multi-line text
- **Readability**: Optimized for maintainability and consistency

## 📈 Roadmap

- [x] Flutter Project Health Audit
- [x] Flutter Best Practices Check
- [x] NestJS Project Health Audit (Backend)
- [x] Framework-Agnostic Security Audit
- [x] Multi-agent registry (16 agents supported)
- [ ] NestJS Project Health Audit (Cloud Functions)
- [ ] Tools for React/Next.js project analysis
- [ ] Deployment automation
- [ ] Performance and quality metrics

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-tool`
3. Commit changes: `git commit -m 'Add new tool'`
4. Push to branch: `git push origin feature/new-tool`
5. Open Pull Request

### Development guidelines

- Follow established folder structure
- Document each tool completely in its technology folder
- Include usage examples
- Maintain backward compatibility

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For questions, issues, or contributions:
- **Issues**: [GitHub Issues](https://github.com/somnio-software/technology-tools/issues)
- **Discussions**: [GitHub Discussions](https://github.com/somnio-software/technology-tools/discussions)
- **Pull Requests**: [GitHub Pull Requests](https://github.com/somnio-software/technology-tools/pulls)

## 🏢 About Somnio Software

This project is maintained by [Somnio Software](https://github.com/somnio-software), a company focused on delivering high-quality software solutions and development tools.

---

**Made with ❤️ by the Somnio Software team**
