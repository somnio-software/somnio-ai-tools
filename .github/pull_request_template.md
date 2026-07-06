<!--
  Thanks for contributing!

  Fill in every section. Do not delete a checklist item — check it,
  leave it unchecked, or mark it N/A with a one-line reason.
  Claims must be evidence-based: link to commits, command output, or
  screenshots rather than asserting "done".
-->

## Description

<!--- Describe your changes in detail: what changed and why. -->

## Type of Change

<!--- Put an `x` in all the boxes that apply: -->

- [ ] ✨ New feature (skill, agent rule, CLI command, plugin)
- [ ] 🛠️ Bug fix (non-breaking change which fixes an issue)
- [ ] ❌ Breaking change (changes existing CLI behavior, skill format, or registry contract)
- [ ] 🧹 Code refactor
- [ ] ✅ Build/CI configuration change
- [ ] 📝 Documentation only
- [ ] 🗑️ Chore

## Quality agreement

<!--- Put an `x` in EVERY box that applies. If a box does not apply, write "N/A — <reason>" next to it instead of leaving it blank. -->

### CLI changes (`cli/`)

- [ ] ✅ `dart analyze` passes with no new warnings/errors
- [ ] ✅ `dart test` passes locally
- [ ] 📊 Every touched file in `cli/lib` is at or above 85% line coverage (pre-push hook gate is **per-file**, not an average) — lowest file: __%
- [ ] 🔢 Version bumped in **both** `cli/pubspec.yaml` and `cli/lib/src/version.dart` (`packageVersion`), if this PR ships a user-facing CLI change
- [ ] 📓 `cli/CHANGELOG.md` has a new entry describing the change
- [ ] 🧩 New/changed agent support is a registry edit (`agent_registry.dart` / `skill_registry.dart`), not a new branching code path

### Skills / agent rules (`skills/`, `agent-rules/`)

- [ ] 📁 New skill follows the `SKILL.md` + `references/` + `assets/` bundle layout and is registered in `skill_registry.dart`
- [ ] 🎯 `SKILL.md` frontmatter `description` is specific enough to drive correct trigger detection
- [ ] 🚫 No invented/fabricated data, URLs, or claims in skill instructions — evidence-based only
- [ ] 🔁 If `agent-rules/rules/<stack>/*.md` changed, adapters were regenerated via `python3 scripts/generate.py` (never hand-edited under `adapters/`)
- [ ] 📚 `docs/architecture.md` (or other relevant doc under `docs/`) updated if this changes CLI architecture or extension points

### General

- [ ] 🧪 Manual verification performed (describe below) — not just type-checking/tests
- [ ] 📝 Commit messages follow Conventional Commits
- [ ] 🌿 Branch name follows `{type}/{description}`
- [ ] 🙅 No environment variables or secrets committed into source control

## Tests

<!-- What was tested and how. Required even for docs-only PRs if behavior is affected. -->
-

## Documentation

<!-- Docs/README/CHANGELOG updates, with links/paths. -->
-

## Design decisions

<!-- Non-obvious choices, trade-offs, alternatives considered, and why. -->
-

## Evidence

<!-- Command output, screenshots, logs, or links that prove the change works. -->
-
