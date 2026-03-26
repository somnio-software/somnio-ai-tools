[Home](../README.md) > Installation

# Installation

Somnio skills can be installed through three methods. Choose the one that fits your workflow.

## Prerequisites

| Method | Requires |
|--------|----------|
| skills.sh | Node.js / npx |
| Claude Desktop App (Cowork) | Claude Desktop App |
| Somnio CLI | Dart SDK 3.0+ |

---

## Option 1: skills.sh (recommended)

Works with Claude Code, Cursor, Windsurf, Copilot, and [40+ other agents](https://agentskills.io).

```bash
npx skills add somnio-software/somnio-ai-tools
```

This installs all skills globally into each detected agent's skill directory (e.g., `~/.claude/skills/`, `~/.cursor/commands/`).

To update:

```bash
npx skills add somnio-software/somnio-ai-tools
```

To remove:

```bash
npx skills remove somnio-software/somnio-ai-tools
```

---

## Option 2: Claude Desktop App (Cowork plugin)

Install through the Claude Desktop App UI:

1. Open **Claude Desktop App**
2. Go to the **Cowork** tab
3. Click **Customize** → **Explore Plugins**
4. Select the **Personal** tab
5. Click the **+** (Add) button
6. Paste `somnio-software/somnio-ai-tools` in the modal and confirm
7. The marketplace loads — select which plugins to install

The marketplace manifest registers four plugin packages:

| Plugin | Description |
|--------|-------------|
| `somnio-development` | Project health audits, security scans, best practices validation |
| `somnio-marketing` | Content strategy, ASO audits, campaign analysis |
| `somnio-operations` | Story definition, backlog management, workflow automation |
| `somnio-engineering-management` | Performance reviews, career path evaluation |

See [Plugin System](plugins.md) for details on each plugin.

### Updating the Cowork plugin

1. Go to **Cowork** → **Customize** → **Explore Plugins** → **Personal**
2. Click the **three dots** (⋯) next to the plugin name
3. Click **Search for updates**
4. Uninstall and re-install the plugin to apply the update

---

## Option 3: Somnio CLI

The Dart CLI includes a multi-step audit runner that orchestrates analysis across fresh AI contexts. It also installs skills via skills.sh under the hood.

```bash
dart pub global activate -sgit https://github.com/somnio-software/somnio-ai-tools.git --git-path cli
```

Then run the setup wizard:

```bash
somnio setup
```

`somnio setup` detects installed AI CLIs, offers to install missing ones, then runs `npx skills add` to install all skills globally.

### Setup flags

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Skip all confirmation prompts |
| `--skip-cli` | | Skip CLI detection and installation |
| `--legacy` | | Use built-in installer instead of skills.sh |

See the [CLI Reference](cli.md) for full usage.

---

## Environment Variables

Some skills require environment variables to be configured before use:

| Skill | Variable | Required | Purpose |
|-------|----------|----------|---------|
| Clockify Tracker | `CLOCKIFY_API_KEY` | Yes | API key from Clockify (Profile → API) |
| Clockify Tracker | `CLOCKIFY_TZ_OFFSET` | No | Local UTC offset in whole hours (e.g. `-3` for Argentina) |

---

## Verifying Installation

```bash
somnio status
```

This shows installed skills across all detected agents.

## Updating

```bash
somnio update
```

Updates the CLI to the latest version and reinstalls all skills.

## Uninstalling

```bash
somnio uninstall
```

Removes all Somnio skills from all agents. Prompts for confirmation unless `--force` is passed.

---

**See also:** [CLI Reference](cli.md) | [Skills Catalog](skills.md) | [Plugin System](plugins.md)
