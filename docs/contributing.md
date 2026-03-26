[Home](../README.md) > [Contributing](../CONTRIBUTING.md) > CLI Development

> For a full overview of all contribution areas (agent rules, skills, agents, plugins), see the [root CONTRIBUTING.md](../CONTRIBUTING.md).

# CLI & Skills Development

## Getting Started

```bash
git clone https://github.com/somnio-software/somnio-ai-tools
cd somnio-ai-tools/cli

dart pub get                              # Install dependencies
dart analyze                              # Run static analysis
dart test                                 # Run all tests
dart test test/src/utils/banner_test.dart  # Run a single test file
dart run bin/somnio.dart                  # Run CLI locally
dart pub global activate --source path .  # Install local version globally
```

---

## Repository Layout

```
somnio-ai-tools/
├── cli/                         # Dart CLI application
│   ├── bin/somnio.dart          # Entry point
│   ├── lib/src/
│   │   ├── agents/              # Agent registry and config models
│   │   ├── commands/            # CLI command classes (one per command)
│   │   ├── content/             # Skill registry and content loader
│   │   ├── installers/          # Agent-specific file writers
│   │   ├── runner/              # Audit execution engine
│   │   ├── transformers/        # Plan + rules → agent format converters
│   │   └── utils/               # Shared helpers
│   ├── test/                    # Tests
│   └── pubspec.yaml             # Package metadata
├── skills/                      # Skill definitions (SKILL.md + references + assets)
│   ├── flutter-health-audit/
│   ├── flutter-best-practices/
│   ├── nestjs-health-audit/
│   ├── nestjs-best-practices/
│   ├── security-audit/
│   ├── workflow-builder/
│   ├── git-branch-format/
│   └── git-commit-format/
├── commands/                    # Slash command definitions
│   ├── audit.md                 # /somnio:audit
│   └── quick-check.md           # /somnio:quick-check
├── plugins/                     # Claude Desktop App (Cowork) plugin packages
│   ├── developer/               # Symlinks to shared skills + commands
│   ├── marketing/
│   ├── operations/              # Own skills + MCP connectors
│   └── engineering-management/
├── .claude-plugin/
│   └── marketplace.json         # Plugin marketplace manifest
├── docs/                        # Documentation
├── CLAUDE.md                    # AI agent instructions
├── LICENSE                      # MIT
└── README.md
```

---

## Adding a New Skill

### Using the scaffolding command

```bash
somnio add react
```

This runs in **wizard mode** when `skills/react-*` directories don't exist:
- Scaffolds `skills/react-health-audit/` and `skills/react-best-practices/`
- Generates SKILL.md templates with placeholder steps
- Creates the `references/` and `assets/` directories
- Registers new `SkillBundle` entries in the skill registry

If `skills/react-*` already exists, it runs in **auto-detect mode** — scans existing directories and registers valid bundles.

### Manual skill creation

1. Create the skill directory:

   ```bash
   mkdir -p skills/my-skill/{references,assets}
   ```

2. Create `skills/my-skill/SKILL.md` with frontmatter:

   ```markdown
   ---
   name: my-skill
   description: >-
     What this skill does and when to trigger it.
   allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent
   ---

   # My Skill - Execution Plan

   Instructions for the AI agent...

   ## Rule Execution Order

   1. Step one — `references/step-one.md`
   2. Step two — `references/step-two.md`
   ```

3. Create reference files in `references/`:

   ```markdown
   # Step Name

   > Description of what this analysis step does.

   **File pattern**: `*`

   ---

   Detailed AI prompt with analysis instructions...
   ```

4. Optionally add a report template in `assets/report-template.txt`.

5. Register in `cli/lib/src/content/skill_registry.dart`:

   ```dart
   static const mySkill = SkillBundle(
     id: 'my_skill',
     name: 'my-skill',
     aliases: ['ms', 'somnio-ms'],
     displayName: 'My Skill',
     description: 'What it does',
     planRelativePath: 'skills/my-skill/SKILL.md',
     rulesDirectory: 'skills/my-skill/references',
     templatePath: 'skills/my-skill/assets/report-template.txt',
   );
   ```

   Then add it to the `skills` list in the same file.

---

## Adding a New Plugin

See the [Plugin System](plugins.md#adding-a-new-plugin) guide for step-by-step instructions.

### Symlink structure

The developer plugin uses symlinks to share content with the root directories:

```
plugins/developer/
├── commands -> ../../commands    # Points to root commands/
└── skills -> ../../skills        # Points to root skills/
```

Use symlinks when your plugin should reflect the shared skills. Use local directories when the plugin has its own independent skills (like the operations plugin).

---

## Adding a New Agent

Adding support for a new AI agent requires a single `AgentConfig` entry in `cli/lib/src/agents/agent_registry.dart`:

```dart
static const _myAgent = AgentConfig(
  id: 'myagent',
  displayName: 'My Agent',
  binary: 'myagent',
  canExecute: true,
  promptStyle: PromptStyle.flag,
  installFormat: InstallFormat.skillDir,
  // ... model definitions, token parser, etc.
);
```

Add it to the `agents` list in the same class. No other files need to change.

---

## Running Tests

```bash
cd cli
dart test                                 # All tests
dart test test/src/utils/banner_test.dart  # Single test file
dart test --coverage                      # With coverage
```

---

## Linter Configuration

`cli/analysis_options.yaml` enforces:

- `prefer_relative_imports`
- `prefer_final_locals`
- `avoid_print: false`

Run `dart analyze` to check.

---

## Version Management

Version is stored in two files — keep them in sync:

- `cli/lib/src/version.dart`
- `cli/pubspec.yaml`

---

## Commit & Branch Conventions

This project includes skills for consistent Git conventions:

- **Branches:** `{type}/{TICKET}_{description}` — see [Git Branch Format](skills.md#git-branch-format)
- **Commits:** Conventional Commits — see [Git Commit Format](skills.md#git-commit-format)

---

## Pull Request Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Make your changes
4. Run `dart analyze` and `dart test` from `cli/`
5. Commit using Conventional Commits format
6. Push and open a pull request

---

**See also:** [Architecture](architecture.md) | [Plugin System](plugins.md) | [CLI Reference](cli.md)
