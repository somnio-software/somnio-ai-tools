[Home](../README.md) > Installation

# Installation

Somnio skills can be installed through two methods. Choose the one that fits your workflow.

## Prerequisites

| Method | Requires |
|--------|----------|
| Somnio CLI | Dart SDK 3.0+ |
| Claude Desktop App (Cowork) | Claude Desktop App |

---

## Option 1: Somnio CLI (recommended)

The Dart CLI includes a multi-step audit runner that orchestrates analysis across fresh AI contexts. It installs skills with its own installer and records them in a `.somnio-skills.json` manifest so `somnio skills update` can keep them current.

```bash
dart pub global activate -sgit https://github.com/somnio-software/somnio-ai-tools.git --git-path cli
```

Then run the setup wizard:

```bash
somnio setup
```

`somnio setup` detects installed AI CLIs, offers to install missing ones, then installs all skills globally to every detected agent.

> **Previously installed Somnio skills with skills.sh?** `somnio setup`, `somnio install`, `somnio skills install` and `somnio skills update` find the Somnio skills skills.sh installed globally and offer to remove them from all agents (after showing what will go and which of them the command will not reinstall), so they do not linger as stale duplicates. Third-party skills.sh skills are not touched. To uninstall an old skills.sh install by hand instead, run `npx skills remove somnio-software/somnio-ai-tools`. Preview with `somnio skills update --dry-run --verbose`; details in the [CLI Reference](cli.md#cleanup-of-skillssh-installs).

### Setup flags

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Skip all confirmation prompts |
| `--skip-cli` | | Skip CLI detection and installation |
| `--verbose` | `-v` | Show detailed output, including every skills.sh path removed |

`--legacy` is deprecated: it is accepted but has no effect.

See the [CLI Reference](cli.md) for full usage.

> **Reports for the shared pipeline.** Reports must come from `somnio run`, or from an install kept current with `somnio skills update`. `somnio run` refuses to start when the installed skills are stale (see [Installed-skills version check](cli.md#installed-skills-version-check)). Do not rename or convert the files; see [Sharing reports](cli.md#sharing-reports).

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

## Environment Variables

Some skills require environment variables to be configured before use:

| Skill | Variable | Required | Purpose |
|-------|----------|----------|---------|
| Clockify Tracker | `CLOCKIFY_API_KEY` | Yes | API key from Clockify (Profile → API) |
| Clockify Tracker | `CLOCKIFY_TZ_OFFSET` | No | Local UTC offset in whole hours (e.g. `-3` for Argentina) |
| DORA Metrics | `GITHUB_TOKEN` | No — falls back to `gh auth token` | GitHub token with read access to the project's repos/orgs. Skip this if you already have `gh auth login` done locally. |

---

## Skill-Specific Runtime Requirements

Beyond an installed agent, a few skills need their own local runtime to actually execute:

| Skill | Requires | Notes |
|-------|----------|-------|
| DORA Metrics | Python 3, the `requests` package (`pip install requests`), and the [GitHub CLI](https://cli.github.com/) (`gh`) | `gh` is only needed for the `GITHUB_TOKEN` fallback above — a token in the environment works without it. |

---

## Verifying Installation

```bash
somnio status
```

This shows installed skills across all detected agents.

## Updating

```bash
somnio update         # Update the CLI binary
somnio skills update  # Refresh installed skills (global and project)
```

`somnio update` updates the CLI only. Skills have their own lifecycle — `somnio skills update` refreshes the ones you already have installed, checking both the global and project locations.

## Uninstalling

```bash
somnio uninstall
```

Removes the somnio CLI from your machine. It first asks whether to also delete the installed skills and rules — answer no to keep them. Pass `--skills` / `--no-skills` to answer up front, and `--force` to skip the confirmation.

To remove only the skills and keep the CLI, use `somnio skills remove` instead.

---

**See also:** [CLI Reference](cli.md) | [Skills Catalog](skills.md) | [Plugin System](plugins.md)
