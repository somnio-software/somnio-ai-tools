[Home](../README.md) > Architecture

# Architecture

## System Overview

```
User
 │
 ├─ AI Agent (Claude Code, Cursor, Gemini, ...)
 │   │
 │   └─ Skills (installed via skills.sh or plugin)
 │       ├─ Audit skills → multi-step analysis → reports
 │       ├─ Utility skills → Git formatting, etc.
 │       └─ Workflow skills → custom pipelines
 │
 └─ Somnio CLI (`somnio run`)
     │
     ├─ Pre-flight (direct execution, no AI)
     └─ Step execution (fresh AI CLI process per step)
         └─ Artifacts → Final report
```

Skills can be invoked in two ways:
1. **Inside an AI agent** — the agent reads the SKILL.md and follows its instructions
2. **Via the Somnio CLI** — `somnio run` orchestrates multi-step execution externally

---

## Distribution Channels

| Channel | Method | Scope |
|---------|--------|-------|
| **skills.sh** | `npx skills add somnio-software/somnio-ai-tools` | 40+ agents |
| **Claude Desktop App** | Cowork → Explore Plugins → Personal → add `somnio-software/somnio-ai-tools` | Claude Desktop App |
| **Somnio CLI** | `somnio setup` (uses skills.sh internally) | All detected CLIs |

All three channels install the same skills. The CLI additionally provides the multi-step audit runner.

---

## CLI Architecture

```
cli/lib/src/
├── agents/          # Agent registry and config models
├── commands/        # CLI command classes (one per command)
├── content/         # Skill registry and content loader
├── installers/      # File writers (agent-specific install paths)
├── runner/          # Audit execution engine
│   ├── agent_resolver.dart   # Auto-detect available AI CLIs
│   ├── plan_parser.dart      # Extract steps from SKILL.md
│   ├── preflight.dart        # Pre-flight steps (no AI needed)
│   └── step_executor.dart    # Spawn fresh AI CLI per step
├── transformers/    # Convert plans + rules per agent format
└── utils/           # Shared helpers
```

### Key Layers

**Skill Registry** (`content/skill_registry.dart`) — Static registry of all audit skill bundles. Each `SkillBundle` defines paths to its SKILL.md, references directory, and assets.

**Agent Registry** (`agents/agent_registry.dart`) — Data-driven definitions for all supported agents. Each `AgentConfig` declares binary, prompt style, install format, models, and token parser. Adding a new agent requires only a single entry here.

**Content Loader** (`content/content_loader.dart`) — Reads SKILL.md plans and reference markdown files from the filesystem. References are parsed into `ParsedRule` objects.

**Transformers** — Convert SKILL.md and references into agent-specific formats:

| Format | Agent | Output |
|--------|-------|--------|
| `skillDir` | Claude Code | Directory with SKILL.md + rule files |
| `singleFile` | Cursor | Single merged markdown file |
| `workflow` | Gemini/Antigravity | Workflow YAML format |
| `markdown` | Generic | Standard markdown |

**Installers** — Write transformed skills to agent-specific locations (`~/.claude/skills/`, `~/.cursor/commands/`, etc.).

**Runner** — Executes audits step-by-step, spawning a fresh AI CLI process per step via `AgentConfig.buildArgs()`.

---

## Skill Execution Model

### Inside an AI Agent

When a skill is triggered inside an agent (e.g., the user says "run a Flutter audit"):

1. Agent reads the installed SKILL.md
2. SKILL.md instructions guide the agent through each analysis step
3. For each step, the agent reads the corresponding reference file
4. Agent produces artifacts and a final report

### Via Somnio CLI (`somnio run`)

When running from the terminal:

1. **Parse arguments** — agent, model, validation flags
2. **Validate project type** — check for framework markers (e.g., `pubspec.yaml` for Flutter)
3. **Run pre-flight steps** — tool installation, version alignment, test execution (direct shell, no AI)
4. **Resolve AI agent** — auto-detect or use `--agent` flag (preference: Claude > Cursor > Gemini)
5. **Parse SKILL.md** — extract step order from "Rule Execution Order" section
6. **Execute each step** — spawn a fresh AI CLI process with the step prompt, save output to `./reports/.artifacts/`
7. **Generate report** — combine artifacts into final report at `./reports/`

Each step runs in a **fresh AI context** to avoid context window exhaustion on large audits. This is a deliberate design choice — 13-step audits would exceed context limits in a single session.

---

## Agent Registry Design

The agent registry is **data-driven**: each agent is a configuration object, not a separate code path.

```dart
AgentConfig(
  id: 'claude',
  displayName: 'Claude Code',
  binary: 'claude',
  canExecute: true,
  promptStyle: PromptStyle.flag,       // How to pass prompts
  installFormat: InstallFormat.skillDir, // How to write skill files
  models: [...],                        // Available models
  tokenParser: claudeTokenParser,       // Parse token usage from output
)
```

This means:
- Adding a new agent = one config entry
- No agent-specific branching in command logic
- Transformers and installers work from the config, not agent identity

---

## Key Design Decisions

**Fresh AI context per step** — Multi-step audits (13 steps for health audits) would overflow a single context window. Running each step in a fresh process ensures consistent quality and avoids degradation as context fills.

**Data-driven agent registry** — Instead of if/else chains for each agent, a single `AgentConfig` model captures all agent differences (binary name, prompt style, install format, models). This makes the codebase scale linearly as new agents are added.

**skills.sh integration** — Rather than maintaining 40+ agent installers internally, Somnio delegates to skills.sh for broad agent compatibility and focuses CLI effort on the audit runner.

**Markdown-based skills** — Skills are plain markdown files, not code. This makes them readable, editable, and portable across any agent that supports markdown-based skill systems.

---

**See also:** [CLI Reference](cli.md) | [Contributing](contributing.md) | [Plugin System](plugins.md)
