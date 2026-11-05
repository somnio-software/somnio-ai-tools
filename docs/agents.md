# Supported Agents

The Somnio CLI installs skills into 18 coding agents, and `somnio run` can drive 12 of them from the terminal. This page lists each agent, where its skills go and how they are laid out, and what happens to the folders earlier releases wrote to.

The source of truth is [`cli/lib/src/agents/agent_registry.dart`](../cli/lib/src/agents/agent_registry.dart), one `AgentConfig` entry per agent. When a folder or an id here differs from the registry, the registry wins.

**On this page:** [Install formats](#install-formats) · [Agents](#agents) · [Config home overrides](#config-home-overrides) · [Folders earlier releases used](#folders-earlier-releases-used) · [Adding an agent](#adding-an-agent)

---

## Install formats

Every agent has one install format (`AgentConfig.installFormat`). It decides what the CLI writes into the agent's folder.

| Format | What is written | Agents |
|--------|-----------------|--------|
| `skillDir` | One `<name>/` directory per skill: `SKILL.md` with its `references/`, `assets/` and `agents/` next to it | Claude Code, Gemini CLI, Antigravity, Codex CLI, Augment Code, Amp, Cline, OpenCode, CodeBuddy, Qwen CLI, Kimi Code, GitHub Copilot, Windsurf, Roo Code, Kilo Code |
| `singleFile` | One merged markdown file per skill (`<name>.md`) in the agent's commands folder, with its rules in `~/.cursor/somnio_rules` | Cursor |
| `markdown` | One standard markdown file per skill, opening with a `# <display name>` line and a `> ` description. Aider keeps its rules in `~/.aider/somnio_rules`; Amazon Q has no separate rules folder | Aider, Amazon Q |
| `workflow` | A workflow file plus a separate `somnio_rules/` directory | No agent. Antigravity used it before 3.2.15 and keeps it as its `legacyInstallFormat` |

---

## Agents

*Global folder* is where `--global` installs go, and *Project folder* is where `--project` installs go, relative to the project root. `somnio run` can drive an agent when the registry gives it a CLI binary (`canExecute`); the other agents only receive skills. See [`somnio skills`](cli.md#somnio-skills) for scopes and the `--agent <id>` flag.

| Agent | CLI id | Format | Global folder | Project folder | Config home variable | `somnio run` |
|-------|--------|--------|---------------|----------------|----------------------|--------------|
| Claude Code | `claude` | `skillDir` | `~/.claude/skills` | `.claude/skills` | `CLAUDE_CONFIG_DIR` | `claude` |
| Cursor | `cursor` | `singleFile` | `~/.cursor/commands` | `.cursor/commands` | | `agent` |
| Gemini CLI | `gemini` | `skillDir` | `~/.gemini/skills` | `.gemini/skills` | | `gemini` |
| Antigravity | `antigravity` | `skillDir` | `~/.gemini/config/skills` | `.gemini/config/skills` | | |
| Codex CLI | `codex` | `skillDir` | `~/.codex/skills` | `.codex/skills` | `CODEX_HOME` | `codex` |
| Augment Code | `auggie` | `skillDir` | `~/.augment/skills` | `.augment/skills` | | `auggie` |
| Amp | `amp` | `skillDir` | `~/.config/amp/skills` | global only | | `amp` |
| Aider | `aider` | `markdown` | `~/.aider/skills` | `.aider/skills` | | `aider` |
| Cline | `cline` | `skillDir` | `~/.cline/skills` | `.cline/skills` | | `cline` |
| OpenCode | `opencode` | `skillDir` | `~/.config/opencode/skills` | `.opencode/skills` | `XDG_CONFIG_HOME` | `opencode` |
| CodeBuddy | `codebuddy` | `skillDir` | `~/.codebuddy/skills` | `.codebuddy/skills` | | `codebuddy` |
| Qwen CLI | `qwen` | `skillDir` | `~/.qwen/skills` | `.qwen/skills` | | `qwen` |
| Kimi Code | `kimi` | `skillDir` | `~/.kimi-code/skills` | `.kimi-code/skills` | `KIMI_CODE_HOME` | `kimi` |
| GitHub Copilot | `copilot` | `skillDir` | `~/.copilot/skills` | `.github/skills` | | |
| Windsurf | `windsurf` | `skillDir` | `~/.codeium/windsurf/skills` | `.windsurf/skills` | | |
| Roo Code | `roo` | `skillDir` | `~/.roo/skills` | `.roo/skills` | | |
| Kilo Code | `kilocode` | `skillDir` | `~/.kilocode/skills` | `.kilocode/skills` | | |
| Amazon Q | `amazonq` | `markdown` | `~/.aws/amazonq/prompts` | `.amazonq/prompts` | | |

An empty `somnio run` cell means the agent has no CLI binary in the registry, so `somnio run` cannot use it. Amp is `globalOnly`: both project folders it reads (`.agents/skills`, `.claude/skills`) are shared with skills.sh and Claude Code, so a project install goes to the global folder. Kimi Code also reads the shared `~/.agents/skills` and `.agents/skills`; the CLI leaves those to skills.sh and installs into Kimi Code's own folders only. It reads project skills only at the git root, so run a project install from the repository root.

The registry records where the CLI installs. What an agent loads, and from where, is defined by the agent: check its own documentation before relying on a folder.

---

## Config home overrides

Four agents let an environment variable relocate their config directory, and the CLI follows it for the **global** scope:

| Agent | Variable | Global skills folder when set | Since |
|-------|----------|-------------------------------|-------|
| Claude Code | `CLAUDE_CONFIG_DIR` | `$CLAUDE_CONFIG_DIR/skills` | 3.2.14 |
| Codex CLI | `CODEX_HOME` | `$CODEX_HOME/skills` | 3.2.12 |
| OpenCode | `XDG_CONFIG_HOME` | `$XDG_CONFIG_HOME/opencode/skills` | 3.3.3 |
| Kimi Code | `KIMI_CODE_HOME` | `$KIMI_CODE_HOME/skills` | 3.3.5 |

A blank value is ignored; a relative value is used as typed, against the directory the CLI runs in, so set it to an absolute path. Project installs are anchored at the project root and ignore the variable. `update`, `remove`, `uninstall`, `status` and agent detection use the relocated folder, and so does `somnio run`; `somnio hooks` writes under `$CLAUDE_CONFIG_DIR` too.

Earlier releases installed to the default folder regardless of the variable. For Codex, `skills remove` and `uninstall --skills` also clean the default `~/.codex/skills` while `CODEX_HOME` points elsewhere, and for OpenCode the default `~/.config/opencode/skills` while `XDG_CONFIG_HOME` points elsewhere (no release before 3.3.3 wrote there; this covers an install made before the variable was set). For Claude Code they leave `~/.claude` alone (`cleansDefaultConfigHome: false` in the registry), because it is often another Claude Code account's live directory. They leave `~/.kimi-code/skills` alone the same way while `KIMI_CODE_HOME` points elsewhere: the variable exists to keep profiles apart, and no release ignored it there. That folder gets the protection described for `~/.claude/skills` below, with one difference: when `~/.kimi-code/skills` is itself a link (`~/.kimi-code/skills` → `~/.claude/skills`) to another agent's current folder, and that folder is reached through no link, that agent keeps working on it, because the folder is not Kimi Code's (`yieldsSharedFolder` in the registry). Kimi Code still leaves it alone. As an install folder, a real `~/.kimi-code/skills` stays protected from every other agent, also from one whose variable points there (`CODEX_HOME=~/.kimi-code`). The check covers install folders only and resolves `..` before links: a rules folder linked to it (`~/.cursor/somnio_rules` → `~/.kimi-code/skills`) or `CODEX_HOME=~/q/lnk/../.kimi-code` still reaches it, and a rules folder linked to `~/.claude/skills` reaches that one the same way.

The difference does not reach an owner whose folder sits behind a link of its own, or one that has moved away from the folder:

- With `~/.claude -> ~/dotfiles/claude` (or `~/.config -> ...` for OpenCode), the link above and `KIMI_CODE_HOME` set, Claude Code's install exits 70.
- With `~/.kimi-code/skills` → `~/.codex/skills`, `CODEX_HOME` and `KIMI_CODE_HOME` set, `skills remove` and `uninstall --skills` leave `~/.codex/skills` as it is, since that default is no longer Codex CLI's current folder.

### A Kimi Code folder that is really another agent's

While the real path of Kimi Code's current folder is another agent's current folder, in either link direction (`~/.kimi-code/skills` → `~/.claude/skills` or the reverse), a run over several agents leaves that folder to the other agent, so it does not end up with Kimi Code's copies of the skills. `setup`, `somnio install --all`, `skills install --all-agents`, an install picked for several agents, and `skills update` and `skills remove` without `--agent` skip Kimi Code and print a line naming the folder. `uninstall --skills` does the same silently, leaving the folder to the other agent's sweep and manifest. A link whose target does not exist yet counts, since the other agent's install creates that folder, and so does the other agent's project folder under the directory you run from: the result can depend on where you run the command.

`--agent kimi` is your own request, so it still works there and warns that it also changes what the other agent reads. On a link whose target does not exist yet it warns and then fails, since nothing creates the folder. Other agents do not get either behaviour (`yieldsSharedFolder`). A link to a folder that is no agent's current one (`~/.kimi-code/skills` → `~/dotfiles/skills`) installs as usual.

---

## Folders earlier releases used

Several agents were installed in a layout or folder the agent does not read as skills, or does not document (OpenCode). The registry keeps the old location in `legacyInstallFormat`, `legacyInstallPath` and `legacyExecutionRulesPath`, so the commands below can migrate or remove what an earlier release wrote. The release that changed each one is in [`cli/CHANGELOG.md`](../cli/CHANGELOG.md).

### Moved to a new folder

| Agent | Old location (layout) | New location | Release |
|-------|-----------------------|--------------|---------|
| Antigravity | `~/.gemini/antigravity/global_workflows/somnio_<name>.md` and `~/.gemini/antigravity/somnio_rules/` (`workflow`) | `~/.gemini/config/skills` | 3.2.15 |
| Windsurf | `~/.windsurf/workflows` (`markdown`) | `~/.codeium/windsurf/skills`, project `.windsurf/skills` | 3.2.17 |
| Amp | `~/.amp/skills` and `~/.amp/somnio_rules` (`markdown`) | `~/.config/amp/skills`, global only | 3.2.17 |
| GitHub Copilot | `~/.copilot/agents` (`markdown`) | `~/.copilot/skills`, project `.github/skills` | 3.2.17 |
| Amazon Q | `~/.amazonq/prompts` | `~/.aws/amazonq/prompts`; project prompts stay in `.amazonq/prompts` | 3.2.17 |
| Roo Code | `~/.roo/rules` (`markdown`) | `~/.roo/skills`, project `.roo/skills` | 3.3.2 |
| Kilo Code | `~/.kilocode/rules` (`markdown`) | `~/.kilocode/skills`, project `.kilocode/skills` | 3.3.2 |
| OpenCode | `~/.opencode/skills` (`skillDir`; `markdown` before 3.2.12) | `$XDG_CONFIG_HOME/opencode/skills` (default `~/.config/opencode/skills`); project installs stay in `.opencode/skills` | 3.3.3 |

The old folder is also checked in the project scope, anchored at the project root. Antigravity IDE workflows stopped working on 2026-10-19; Roo Code and Kilo Code add every file in their rules folders to the instructions of every request, which is why skills moved out of them.

### Same folder, new layout

Seven agents kept their skills folder in 3.2.12 (OpenCode left its in 3.3.3, see above), but releases before 3.2.12 wrote flat `<name>.md` files there, plus the references in a separate `somnio_rules/` directory. The agents load skills only as `<name>/SKILL.md` directories, so they now use `skillDir`.

| Agent | Old rules folder | Release |
|-------|------------------|---------|
| Gemini CLI | `~/.gemini/somnio_rules` | 3.2.12 |
| Codex CLI | `~/.codex/somnio_rules` | 3.2.12 |
| Augment Code | `~/.augment/somnio_rules` | 3.2.12 |
| Cline | `~/.cline/somnio_rules` | 3.2.12 |
| OpenCode | `~/.opencode/somnio_rules` | 3.2.12 |
| CodeBuddy | `~/.codebuddy/somnio_rules` | 3.2.12 |
| Qwen CLI | `~/.qwen/somnio_rules` | 3.2.12 |

### What the commands do with an old location

Every install since 2.10.0 records what it wrote in a `.somnio-skills.json` manifest at the root of the folder it installed into. The old folder keeps the manifest an earlier release wrote there, and the commands act on what it records.

| Command | Old location |
|---------|--------------|
| `somnio skills update` | Reinstalls the skills recorded in the old folder's manifest into the new folder, deletes the old files that manifest recorded and drops its entries; the manifest file goes once it is empty, and so does an old `somnio_rules/` once nothing is left in it. `somnio skills install` and `somnio setup` do the same for each skill they reinstall. |
| `somnio skills remove` | Deletes what the manifests of the new and the old folders record, in the scope you choose. Files the manifests do not record are never touched. |
| `somnio uninstall --skills` | Does the same for every recorded manifest, then sweeps by name, when it has **no** manifest, the old folder of an agent that moved (for Antigravity: `somnio_`-prefixed files in `global_workflows/` and the whole `somnio_rules/`), otherwise the agent's current folders, including any its config home variable relocates. Global scope only. The new folder is never swept by name: no release wrote there before the manifest existed. |

The name sweep keeps your skill folders, with one exception. Before 2.10.0 the CLI's installer wrote skill directories only for Claude Code (`hasPreManifestSkillDirs` in the registry): every other agent had flat files or was not supported yet, and the installer has recorded what it writes ever since. So the name sweep removes a directory only from Claude Code's default folder, `~/.claude/skills`, when its `SKILL.md` frontmatter `name` matches the folder. With no manifest beside it, a skill of yours there with a Somnio skill's name goes too, since an old install looks exactly like that, and so does one with the `somnio-` prefix, which the sweep matches although only the v1.x skills (`somnio-fh`, `somnio-sa` and the like) ever shipped under it.

Anywhere else a directory is kept, whatever its name and its `SKILL.md` say (`~/.gemini/skills/security-audit/`, `~/.codex/skills/somnio-team-style/`, `$CLAUDE_CONFIG_DIR/skills/security-audit/`), including the skill folders you keep beside the ones `skills update` moved. The sweep reports a kept directory with a Somnio skill's name, or with the agent's `somnio` prefix outside the `markdown` layout (in Cursor's folder, the prefix only; in Aider's and Amazon Q's, where only a flat file's name counts, a skill folder is kept silently), because a lost manifest, an interrupted first install or a skills.sh install in copy mode leaves the same thing: delete it by hand if Somnio wrote it.

In the current folders of Claude Code, Cursor, Gemini CLI, Codex CLI, Augment Code, Cline, CodeBuddy and Qwen CLI, a plain file named like a skill or with the `somnio` prefix is removed without further checks, so keep your own files there under other names. Claude Code only ever got directories, so there it takes the `somnio-` prefix or a skill's exact name with no extension: `security_audit.md` stays.

Kimi Code's own sweep removes nothing from its folders (`installsOnlyWithManifest` in the registry). No release wrote there without a manifest, and Kimi Code loads a flat `<name>.md` as a skill, so `uninstall --skills` removes only what a manifest records. In a folder with no manifest, a file, link or directory with a Somnio skill's name or the `somnio` prefix is kept and reported. In a folder with a manifest the sweep is skipped, so the same entry stays without a report, and anything else is left alone without a report in either case. A Somnio copy that a killed install or a lost manifest left unrecorded is kept too and warned about on every run. A `skills install` of the same version records it again, and `uninstall --skills` then removes it; a copy from another version has to be deleted by hand. The exception is a link between agents' folders (`~/.claude/skills` or `~/.qwen/skills` → `~/.kimi-code/skills`, or the reverse): with no manifest there, the other agent's sweep reaches the real folder and treats it as that agent's own. Qwen CLI's sweep deletes the plain files and links it matches and keeps folders. Claude Code's also deletes hand-written folders named like a Somnio skill or starting with `somnio-`, with their contents, when the `name` in their `SKILL.md` matches the folder. While `KIMI_CODE_HOME` is set, a folder linked into `~/.kimi-code/skills` is skipped instead.

A folder that is also a rules folder (`~/.roo/rules`, `~/.kilocode/rules`) can hold rules you wrote, so the name sweep has stricter rules for the `markdown` layout:

- A file or link is a candidate only if its name is a Somnio skill's name (written with underscores and `.md`, as the layout does). A bare `somnio` prefix does not count, so `somnio-team-conventions.md` stays.
- A file is deleted only if it opens with the header Somnio wrote for that skill: its display name as a `# ` title, then a `> ` description. A rule that shares a skill's name but has another title is kept and reported.
- A link is removed (only the link) when it resolves inside that folder; one pointing outside is kept.

**Skills from releases before 2.10.0.** Those releases wrote no manifest, so `skills update` has nothing to move. For an agent with an old folder in the `markdown` layout (Amp, GitHub Copilot, Windsurf, OpenCode, Roo Code, Kilo Code), `setup` and `skills install` (when they install that agent), and `skills update` (when the location has no manifest to refresh), list the files in an old folder without a manifest that match a skill's name and header and say they must be deleted by hand; nothing is deleted. `uninstall --skills` removes them by the rules above.

**Your skill in the new folder.** For an agent that moved its global folder to skill directories (Amp, GitHub Copilot, Roo Code, Kilo Code, OpenCode), `setup`, `skills install` and `skills update` write a skill into the new folder only if it has no directory of that name, or one its manifest records, or a skills.sh link, or one that holds only the start of the files the new copy would write (a copy killed part way, its last file possibly empty or cut off, which they finish). A directory of your own there is kept, with a warning, on every run, with or without an old manifest entry for the skill. If the old manifest records the skill, the old copy and the entry stay until you move yours, and the next run then moves the skill; otherwise the next run installs it. A file that cannot be read as text (a binary file, or a text file cut inside a multibyte character) and a subfolder that cannot be listed make the directory yours. Project installs are not affected. A move whose old copy could not be deleted keeps its manifest entry, so the next `skills update` finishes it.

Kimi Code has the same guard, though it never moved (`installsOnlyWithManifest` in the registry), and in every scope, since a project's `.kimi-code/skills` can be the global folder (run from `$HOME`, or with `KIMI_CODE_HOME` inside the project): a directory that no manifest records is kept, with a warning, on every run, and a copy killed part way is finished. Any other agent that never moved its folder has no such guard either: `setup` and `skills install` replace that directory in its folder, so rename it first.

**Folders that belong to another agent.** `skills update` and `skills remove` skip an old folder whose real path is, holds or lies inside another agent's current skills or rules folder, or the protected default `~/.claude/skills` while `CLAUDE_CONFIG_DIR` relocates Claude Code, or the agent's own global one, through a symlink either way (`~/.amp` → `~/.claude`, `~/.claude` → `~/.amp`, `~/.opencode/skills` → `~/.claude/skills`), because the manifest there records that agent's skills. Such a folder does not make the agent count as installed either. An old folder symlinked anywhere else (for example `~/.amazonq` → `~/dotfiles/amazonq` with GNU stow) is still migrated and removed. `uninstall --skills` reads every old folder regardless, since it removes every agent's installs, except one that is really the protected default `~/.claude/skills` while `CLAUDE_CONFIG_DIR` relocates Claude Code (`~/.opencode/skills` → `~/.claude/skills`), which it leaves alone; the same goes for any folder that holds or lies inside it, for every agent's current and old folders. `skills update`, `skills remove` and `skills install` apply the same rule to the agent's current folder: one that links into the protected `~/.claude/skills` is skipped, and `install` refuses to write there. `~/.kimi-code/skills` is covered the same way while `KIMI_CODE_HOME` relocates Kimi Code: with `~/.gemini/skills` or `~/.qwen/skills` linked to it, `skills install` refuses, `setup` exits 70, and `skills update`, `skills remove` and `uninstall --skills` skip the folder. If `~/.kimi-code/skills` is itself the link, the agent whose current folder it reaches is not affected, as long as that folder is no link either and lies in the home directory or under no symlink; another agent linked to the same place is refused, and so is a folder that only holds or lies inside it. `~/.claude/skills` does not give way like that: with `~/.claude/skills` → `~/.gemini/skills` and `CLAUDE_CONFIG_DIR` set, Gemini CLI's folder stays refused. The protection is for the skills folder; the rest of `~/.claude` (`commands`, `rules`, `agents`, `global_workflows`) is not covered when another agent's folder links to it. Amp skills an earlier release put in a project's `.amp/skills` are not refreshed: `skills update` warns, and `skills remove --project` deletes them.

---

## Adding an agent

A new agent is a single `AgentConfig` entry in `agent_registry.dart`, added to its `agents` list; no other file changes. The steps and an example are in [Contributing Agents](../CONTRIBUTING.md#contributing-agents), and [Architecture](architecture.md#key-layers) explains how the registry, transformers and installers use it. Then add the agent to the tables above.

---

**See also:** [CLI Reference](cli.md) | [Architecture](architecture.md) | [Installation](installation.md)
