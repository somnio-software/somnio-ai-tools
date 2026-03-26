[Home](../README.md) > Agent Rules

# Agent Rules

Agent rules are coding standards for NestJS and Flutter that are automatically applied by your AI coding agent in every session. They are written once in `agent-rules/rules/` and compiled into agent-specific adapters for Claude Code, Cursor, Windsurf, Copilot, Codex, and Antigravity.

---

## How It Works

Rules live in `agent-rules/rules/` and are the single source of truth. Running the generation script produces all adapters:

```
agent-rules/
├── rules/            ← edit here
│   ├── nestjs/
│   └── flutter/
└── adapters/         ← never edit directly, auto-generated
    ├── antigravity/
    ├── claude/
    ├── codex/
    ├── copilot/
    ├── cursor/
    └── windsurf/
```

---

## Installation via CLI

Install rules for your agent — globally (applied to all projects) or locally (current project only):

```bash
somnio rules install                          # interactive: detect agents + choose scope
somnio rules install --agent claude --global  # Claude Code, global
somnio rules install --agent cursor --project # Cursor, current project
somnio rules install --all --global           # all detected agents, global
somnio rules status                           # check what is installed
```

### Install paths per agent

| Agent | Global | Project |
|:------|:-------|:--------|
| Claude Code | `~/.claude/CLAUDE.md` | `./CLAUDE.md` |
| Cursor | `~/.cursor/rules/` | `./.cursor/rules/` |
| Windsurf | `~/.windsurfrules` | `./.windsurfrules` |
| GitHub Copilot | — | `./.github/copilot-instructions.md` |
| OpenAI Codex | — | `./AGENTS.md` |
| Antigravity | — | `./rules/` |

> Global installs wrap the content in `<!-- BEGIN/END SOMNIO RULES -->` markers so updates are idempotent and existing file content is preserved.

---

## Available Rules

### NestJS

| Rule | Purpose |
|:-----|:--------|
| `dto-validation` | DTOs with class-validator, class-transformer, and Swagger |
| `service-patterns` | Service layer: RO-RO pattern, transactions, validation |
| `controller-patterns` | Controllers: guards, Swagger docs, response formatting |
| `repository-patterns` | Repository pattern: parameterized queries, soft deletes |
| `testing-unit` | Unit tests: mocking, structure, Arrange-Act-Assert |
| `testing-integration` | Integration tests: real database, isolation |
| `error-handling` | Exception filters, error enums, consistent responses |
| `module-structure` | Module organization, DI, barrel exports |
| `typescript` | TypeScript guidelines, naming conventions |

### Flutter

| Rule | Purpose |
|:-----|:--------|
| `architecture` | Layered architecture: Data, Repository, BLoC, Presentation |
| `best-practices` | General best practices: SOLID, state, navigation, theming |
| `bloc-test` | BLoC test structure and patterns |
| `testing` | Testing best practices: mocking, matchers, grouping |
| `dart-model-from-json` | JSON model generation with json_serializable and equatable |

---

## Editing Rules

```bash
# 1. Edit a rule
vim agent-rules/rules/nestjs/service-patterns.md

# 2. Regenerate all adapters
cd agent-rules && npm run generate

# Or regenerate a specific adapter
npm run generate:claude
npm run generate:cursor
npm run generate:copilot
npm run generate:windsurf
npm run generate:codex
npm run generate:antigravity
```

---

## Contributing

See the [Contributing Guide](../CONTRIBUTING.md#contributing-agent-rules) for instructions on editing rules, adding new rules, and adding support for new agents.
