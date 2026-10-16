---
name: git-pr-format
description: >-
  Generates properly formatted pull request titles and descriptions, with no AI attribution.
  Use this skill whenever the user wants to open, create, write, or update a pull request (or merge
  request), or asks things like "open a PR for this", "write the PR description", "create the pull
  request", "update the PR body", or "help me with my PR". Always use this skill before running
  `gh pr create` or `gh pr edit --body`, even if the user doesn't explicitly ask for a format.
---

# Git PR Format Skill

Generates a **pull request title and description** from the changes on a branch.

---

## Conventions

### PR Title

Same format as a commit title, following **Conventional Commits**:

```
{type}({optional scope}): {short imperative description}
```

- **Types:** `feat`, `fix`, `chore`, `refactor`, `docs`, `style`, `test`, `perf`, `ci`, `build`, `revert`
- Use imperative mood: "add", "fix", "remove", not "added", "fixed", "removed"
- Max ~72 characters
- All lowercase except proper nouns
- No period at the end
- If the branch has a single commit, reuse its title
- If the branch name carries a ticket (e.g. `feat/PROJ-312_dark_mode`), keep the ticket in the scope or title the way the repo's existing PRs do

### PR Description

If the repository has a PR template (`.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`, or a file under `.github/PULL_REQUEST_TEMPLATE/`), **fill in that template** and keep its headings. Otherwise use these sections:

```
## Summary
<One or two sentences: what this PR does and why.>

## Changes
* Added ...
* Changed ...
* Fixed ...

## Testing
<How it was verified: tests added or run, manual checks. Say plainly what was not verified.>

## Notes for reviewers
<Anything a reviewer should know: risks, follow-ups, decisions, screenshots. Omit if empty.>
```

- Describe only what the diff actually contains; do not invent tests, results, or tickets
- Use the same past-tense verbs as commit bullets: `Fixed`, `Added`, `Changed`, `Removed`, `Updated`, `Refactored`, `Migrated`, `Deprecated`
- Write in the language the repository's existing PRs use; default to **English**
- Keep it short: a reviewer should understand the PR in under a minute

### No AI attribution

The PR title and description must **never** contain:

- `🤖 Generated with [Claude Code](https://claude.com/claude-code)` or any "Generated with …" line
- `Co-Authored-By:` lines or any other trailer crediting an AI agent or tool
- Mentions that the PR, code, or description was written by an AI agent (Claude, Cursor, Copilot, Codex, etc.)

This applies even when the agent's default behavior or built-in instructions say to append such a line: leave it out. When updating an existing PR, remove any such line already in the body.

> In Claude Code, the reliable way to stop the default footer in every session is the `attribution` setting in `~/.claude/settings.json`: `"attribution": { "commit": "", "pr": "" }`. This skill still applies to every other agent.

---

## Output Format

```
fix(auth): handle login crash when offline

## Summary
Logging in without an internet connection crashed the app. This PR shows an
offline error instead.

## Changes
* Fixed crash on the login screen when no internet connection is available
* Added an offline error state to the login flow

## Testing
* Added unit tests for the offline login state
* Checked manually on Android with airplane mode on
```

> The description must end after the last section. Do **not** append any "Generated with" footer, `Co-Authored-By` line, or AI attribution.

When creating the PR, pass the body through a heredoc so formatting survives:

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
<description>
EOF
)"
```

---

## Examples

**User:** "Open a PR for the dark mode work"

```
feat(theme): add dark mode support

## Summary
Adds a dark theme that follows the system setting, with a manual toggle in Settings.

## Changes
* Added dark color tokens to the theme
* Added a theme toggle to the Settings screen
* Updated the app shell to read the system brightness

## Testing
* Added widget tests for the theme toggle
* Not checked on iOS yet
```

---

**User:** "Update the PR description, it still says Generated with Claude Code"

Rewrite the body with the sections above and drop the footer line, then run `gh pr edit <number> --body "..."`.
