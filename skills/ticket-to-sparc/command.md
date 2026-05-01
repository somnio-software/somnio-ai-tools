---
name: ticket-to-sparc
description: Turn one or more tracker tickets (or an epic) into the right artifact — full ADR + SPARC bundle, SPARC bundle alone, or enhanced prompt — based on tier classification per goal.
---

You are the **Ticket → ADR → SPARC orchestrator**. Run the workflow defined in `skills/ticket-to-sparc/SKILL.md`.

Arguments to this command: zero, one, or many tracker tokens. Each token is either a ticket key (`MARK-123`), an epic key (auto-expand to children), or pasted ticket text. If no argument is given, prompt the user for input.

**Flags**:
- `--adr-only` — record the architectural decision but do NOT generate a SPARC bundle. Forces Tier 1, skips SPARC dispatch, ends after the ADR step. Use when locking the decision now and deferring the implementation spec.

## Run order (summary)

1. **Parse and resolve** the input tokens. For epic keys: if `~~project tracker` is connected, expand via the tracker's child-issue API (Jira: JQL `parent = "<EPIC>"`; Linear: parent issue query; etc.); otherwise ask the user to list the children explicitly. Confirm the expanded list with the user.
2. **Fetch** each resolved ticket: if `~~project tracker` is connected, call the tracker's native fetch (Jira: `getJiraIssue`; Linear: `issue` query; etc.); otherwise ask the user to paste each ticket's summary + description + acceptance criteria. Stop on any fetch failure.
3. **Group into goals**. One goal = one artifact set. Recommend grouping based on shared parent epic / theme. Wait for user confirmation. For each goal, get a kebab-case `goal_slug` and a `goal_title`.
4. **Classify tier per goal**:
   - Tier 1 (Full): architectural decision, new pattern, schema/contract change, security impact
   - Tier 2 (SPARC only): non-trivial but architectural decision is locked
   - Tier 3 (Enhanced prompt): single-ticket routine work — bug fix, small CRUD, config tweak. **Single-ticket goals only.**
   Print a goal × tier table with reasoning. Wait for user confirmation.
5. **Dispatch per goal**:
   - **`--adr-only` mode**: skip Step 4. Force Tier 1 for every goal. Invoke `enhanced-adr` skill → `docs/adr/ADR-NNN-<goal-slug>.md`. **STOP. Do not invoke `sparc-orchestration`.** Note "SPARC deferred" in the final summary.
   - **Tier 1**: invoke `enhanced-adr` skill → `docs/adr/ADR-NNN-<goal-slug>.md`. Then invoke `sparc-orchestration` skill with the new ADR ref → `docs/sparc/<goal-slug>/`.
   - **Tier 2**: detect existing ADR(s) from tracker links, or ask the user. Invoke `sparc-orchestration` with that ADR ref.
   - **Tier 3**: build a basic prompt from `summary + description + AC + parent-epic`. Pass through `prompt-enhancer`. Save to `docs/briefs/<ticket-id>-<slug>.md` with frontmatter `tracker_id: <KEY>`, `tracker_type: jira | linear | notion | other`, `tier: 3`, `created: YYYY-MM-DD`. The body must end with the "ASK ANY QUESTIONS YOU HAVE…" footer and contain no meta-text.
6. **Frontmatter**: every artifact carries `tracker_id: <KEY>` (or YAML list for multi-ticket goals) and `tracker_type:`.
7. **Idempotency**: before writing, check for existing artifacts at the target paths. Ask before overwriting; offer supersede / v2 alternatives.
8. **Stop**. Print a final summary table: `goal → tickets → tier → artifact paths`. Do NOT commit, push, or open a PR. The Tech Lead reviews.

## Hard rules

- **NEVER** commit, push, or open a PR.
- **NEVER** proceed with partial tracker data on fetch failure.
- **NEVER** assign Tier 3 to a multi-ticket goal — refuse with a one-line explanation.
- **NEVER** invent tracker fields. If something's missing, surface it.
- **ALWAYS** print the tier recommendation with reasoning before dispatch.
- **ALWAYS** end with the consolidated summary table.

ASK ANY QUESTIONS YOU HAVE IN ORDER TO BE MORE CLEAR ABOUT THE TASK, IF YOU DONT HAVE ANY, START NOW
