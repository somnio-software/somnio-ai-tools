# Contributing

Thank you for contributing to **somnio-ai-tools**! This guide covers all the ways you can contribute — from new coding-standard rules to new skills, agents, and plugins.

---

## Getting Started

```bash
git clone https://github.com/somnio-software/somnio-ai-tools
cd somnio-ai-tools/cli

dart pub get                              # Install dependencies
dart analyze                              # Run static analysis
dart test                                 # Run all tests
dart run bin/somnio.dart                  # Run CLI locally
dart pub global activate --source path .  # Install local version globally
```

---

## What You Can Contribute

| Area | What it is | Where to start |
|:-----|:-----------|:---------------|
| **Agent Rules** | Coding standards auto-applied by AI agents | [Agent Rules](#contributing-agent-rules) |
| **Skills** | Audit & task-execution bundles | [Skills](#contributing-skills) |
| **Agents** | Support for new AI coding assistants | [Agents](#contributing-agents) |
| **Plugins** | Claude Desktop App (Cowork) plugin packages | [Plugins](#contributing-plugins) |

---

## Contributing Agent Rules

Agent rules live in `agent-rules/rules/` and are compiled into agent-specific adapters via a code-generation script.

### Edit an existing rule

1. Edit the file in `agent-rules/rules/nestjs/` or `agent-rules/rules/flutter/`.
2. Regenerate all adapters:
   ```bash
   cd agent-rules
   npm run generate
   ```
3. Open a PR with a description of the change and why.

**Rule file format** (`agent-rules/rules/**/*.md`):

```markdown
---
description: "One-line description of what this rule enforces."
globs: **/*.service.ts
alwaysApply: false
---

# Rule Title

Brief explanation of what this rule enforces and why.

## Good example
\```typescript
// correct code
\```

## Bad example
\```typescript
// incorrect code
\```
```

Include at least one Good and one Bad example with code.

### Add a new rule

1. Create a `.md` file in `agent-rules/rules/nestjs/` or `agent-rules/rules/flutter/` using the format above.
2. Run `npm run generate` to verify all adapters are generated correctly.
3. Document the new rule in the table in `docs/agent-rules.md`.
4. Open a PR.

### Add support for a new agent adapter

1. **Add a renderer** in `agent-rules/scripts/generate.js`, following the existing renderer pattern. The function receives `groups`:

   ```js
   {
     nestjs: [{ filePath, meta, body, filename }, ...],
     flutter: [{ filePath, meta, body, filename }, ...]
   }
   ```

   Where `meta` = YAML frontmatter fields, `body` = markdown content, `filename` = file name without extension.

2. **Register the renderer** in `targets` inside `generate.js`.

3. **Add a script** in `agent-rules/package.json`:
   ```json
   "generate:my-agent": "node scripts/generate.js --only my-agent"
   ```

4. **Create `agent-rules/adapters/my-agent/README.md`** documenting:
   - What the agent does
   - How to set up the adapter (what to copy, where)
   - How to update (`npm run generate:my-agent`)

5. **Register in the CLI** — add an `AgentRule` entry to `cli/lib/src/content/agent_rule_registry.dart` so the adapter is installable via `somnio rules install`.

6. **Link in `docs/agent-rules.md`** — add a row to the supported-agents table.

---

## Contributing Skills

Skills are AI audit/task bundles composed of a `SKILL.md` plan and `references/` rule files.

### Using the scaffolding command

```bash
somnio add react
```

This scaffolds `skills/react-health-audit/` and `skills/react-best-practices/`, generates SKILL.md templates, creates the `references/` and `assets/` directories, and registers new `SkillBundle` entries in the skill registry.

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
   ...
   ```

3. Create reference files in `references/`.

4. Register in `cli/lib/src/content/skill_registry.dart`:
   ```dart
   SkillBundle(
     id: 'my_skill',
     name: 'my-skill',
     aliases: ['ms', 'somnio-ms'],
     displayName: 'My Skill',
     description: 'What it does',
     planRelativePath: 'skills/my-skill/SKILL.md',
     rulesDirectory: 'skills/my-skill/references',
   ),
   ```

For full details see [docs/contributing.md](docs/contributing.md).

---

## Contributing Agents

Adding support for a new AI agent (for skill installation and audit execution) requires a single `AgentConfig` entry in `cli/lib/src/agents/agent_registry.dart`:

```dart
static const _myAgent = AgentConfig(
  id: 'myagent',
  displayName: 'My Agent',
  binary: 'myagent',
  canExecute: true,
  promptStyle: PromptStyle.flag,
  installFormat: InstallFormat.skillDir,
  installPath: '{home}/.myagent/skills',
  // ... model definitions, token parser, etc.
);
```

Add it to the `agents` list in the same class. No other files need to change.

---

## Contributing Plugins

Plugins are Claude Desktop App (Cowork) packages. See the [Plugin System guide](docs/plugins.md) for step-by-step instructions on adding a new plugin.

---

## Running Tests

```bash
cd cli
dart test                                   # All tests
dart test test/src/utils/banner_test.dart   # Single test file
dart test --coverage                        # With coverage
```

---

## Commit & Branch Conventions

- **Branches:** `{type}/{TICKET}_{description}` — see [Git Branch Format](docs/skills.md#git-branch-format)
- **Commits:** Conventional Commits — see [Git Commit Format](docs/skills.md#git-commit-format)

---

## Pull Request Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Make your changes
4. Run `dart analyze` and `dart test` from `cli/`
5. Commit using Conventional Commits format
6. Push and open a pull request

---

**See also:** [CLI Reference](docs/cli.md) | [Architecture](docs/architecture.md) | [Plugin System](docs/plugins.md)
