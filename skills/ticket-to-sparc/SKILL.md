---
name: ticket-to-sparc
description: >-
  Tech-Lead workflow that turns one or many tracker tickets (or an epic) into
  the right artifact for the dev team. Auto-classifies tier per goal, then
  dispatches to enhanced-adr / sparc-orchestration / prompt-enhancer. Use when
  the user asks to spec out a ticket, expand an epic, or convert a backlog
  item into dev-ready deliverables.
argument-hint: "<ticket-key(s) or --adr-only flag>"
---

# Ticket → ADR → SPARC Workflow

You orchestrate Tech-Lead delivery: turn tracker ticket(s) into the right artifact — a full ADR + SPARC bundle, a SPARC bundle alone, or an enhanced prompt — and stop before committing so the Tech Lead can review.

## When this skill applies

- A user invokes `/ticket-to-sparc <ticket(s)>` from the slash command.
- A user asks "spec out MARK-123 for me" or similar tracker-grounded request.
- Tech Lead wants to convert a ticket / milestone / epic into dev-ready deliverables.

## When this skill does NOT apply

- Pure code edits with no spec request — just code, no orchestration needed.
- ADR or SPARC work without a tracker anchor — call `enhanced-adr` or `sparc-orchestration` directly.
- Prompt enhancement on free-form input — call `/enhance-prompt` directly.

## Inputs

Zero, one, or many tokens. Each token is either:
- A tracker issue key (e.g., `MARK-123`)
- A tracker epic key (will be auto-expanded to its children)
- Empty → prompt the user for input

If the user pastes ticket text instead of a key, accept that as the goal context directly and skip the fetch.

### Flags

- `--adr-only` — record the architectural decision but do NOT generate a SPARC bundle. Useful when locking the decision now and deferring the implementation spec, or when implementation is obvious enough that a 5-phase SPARC is overkill. Forces every goal to be treated as Tier 1 and stops dispatch after the ADR step.

## Goal — the unit of artifact production

A **goal** can be a single ticket (story or self-contained milestone) or a group of tickets that together cover one initiative. The skill works at the goal level, not the ticket level. One goal = one artifact set.

## Workflow

### Step 1 — Parse and resolve

- Tokenize the input.
- For each token: is it an issue key, an epic key, or free text?
- **Epic keys**:
  - **If `~~project tracker` is connected**: query the tracker's child-issue API to expand to children (Jira: JQL `parent = "EPIC-42"`; Linear: `parent { id: "EPIC-42" }`; etc.). Show the expanded list. Confirm with the user before proceeding.
  - **If no project tracker is connected**: ask the user to list the child ticket keys explicitly, or paste the ticket text for each child.
- **Free text** → treat as goal context directly (skip Step 2 for that token).

### Step 2 — Fetch

**If `~~project tracker` is connected:**
- For each resolved ticket key, call the connected tracker's native fetch (Jira: `getJiraIssue`; Linear: `issue` query; etc.).
- Pull: summary, description, acceptance criteria (custom field if applicable), parent epic, linked issues, status.
- If any fetch fails, **STOP** — do not run the workflow with partial data. Report which tickets failed and ask the user whether to proceed without them or abort.

**If no project tracker is connected:**
- Ask the user to paste each ticket's summary + description + acceptance criteria.
- Treat the pasted text as goal context directly.

### Step 3 — Group into goals

Decide how many goals are in scope:

| Input | Default grouping |
|---|---|
| 1 ticket | 1 goal (the ticket). No prompt. |
| 1 epic key | 1 goal (the epic). User can confirm or split. |
| N tickets, all share parent epic OR same theme keywords | Recommend **one goal**. Show recommendation + reasoning. |
| N tickets, disjoint parents and themes | Recommend **separate goals**. Show recommendation + reasoning. |

Always print the recommendation and wait for confirmation. The user can:
- Accept the recommendation
- Merge all tickets into one goal
- Split into custom groupings
- Provide goal name(s) / slug(s) explicitly

For each goal, the user provides (or you propose, then they confirm):
- A kebab-case `goal_slug` (e.g., `event-sourcing-audit-log`)
- A human-readable `goal_title`

### Step 4 — Classify tier per goal

If `--adr-only` was passed, **skip this step**. Force every goal to Tier 1 and proceed to dispatch (the SPARC step is skipped in Step 5).

Otherwise, apply the heuristic to the *combined* context of each goal's tickets:

| Tier | Trigger signals |
|---|---|
| **1 — Full** | "new", "introduce", "migrate to", "replace"; schema/contract changes; multiple bounded contexts; security/compliance impact |
| **2 — SPARC only** | "extend", "support", "add endpoint to existing"; clear pattern but non-trivial scope; references an existing ADR |
| **3 — Enhanced prompt** | Bug fix; small CRUD; config tweak; single-file change. **Single-ticket goals only.** |

Print a per-goal table:

```
Goal              | Tickets             | Recommended tier | Reasoning
event-sourcing… | MARK-201, MARK-202  | Tier 1           | Introduces new pattern; schema change
quick-css-fix   | MARK-301            | Tier 3           | Single-ticket bug fix; scoped change
```

Wait for confirmation. The user can override any row.

**Hard rule**: multi-ticket goals MAY NOT be Tier 3. If the user tries to set a multi-ticket goal to Tier 3, refuse with a one-line explanation (multi-ticket scope implies non-trivial work).

### Step 5 — Dispatch per goal

For each goal, run the matching pipeline:

#### Tier 1 — Full
1. Invoke the [`enhanced-adr`](../enhanced-adr/SKILL.md) skill with goal context. Output: `docs/adr/ADR-NNN-<goal-slug>.md`.
2. **If `--adr-only` was passed, STOP here.** Skip the SPARC step entirely. Note in the final summary table that the SPARC bundle was deferred.
3. Invoke the [`sparc-orchestration`](../sparc-orchestration/SKILL.md) skill with goal context + the new ADR reference. Output: `docs/sparc/<goal-slug>/{1-specification..5-completion}.md` + `README.md`.

#### Tier 2 — SPARC only
1. Detect pre-existing ADRs the goal should reference. Check tracker links (`Depends on`, `Blocks`, `Relates to`) for ADR references in commit history or descriptions. If none found, ask the user which ADR(s) to reference.
2. Invoke the [`sparc-orchestration`](../sparc-orchestration/SKILL.md) skill with goal context + ADR reference(s).

#### Tier 3 — Enhanced prompt
1. Build a basic prompt from the ticket: `summary + description + acceptance criteria + parent-epic context`.
2. Invoke the [`prompt-enhancer`](../prompt-enhancer/SKILL.md) skill with that basic prompt.
3. Save the resulting enhanced prompt to `docs/briefs/<ticket-id>-<slug>.md` with frontmatter:
   ```yaml
   ---
   tracker_id: <TICKET-KEY>
   tracker_type: jira | linear | notion | other
   tier: 3
   created: YYYY-MM-DD
   ---
   ```
4. The body is the enhanced prompt itself — no meta-commentary. The mandatory "ASK ANY QUESTIONS YOU HAVE…" footer must be present.

### Step 6 — Frontmatter & traceability

Every artifact carries tracker keys in YAML frontmatter:
- Single-ticket goal: `tracker_id: MARK-123`
- Multi-ticket goal: `tracker_id: [MARK-201, MARK-202, MARK-203]`
- Always include `tracker_type: jira | linear | notion | other` so artifacts stay self-describing.

The SPARC bundle's `README.md` indexes:
- All tracker tickets with links (use the connected tracker's URL convention — Jira: `https://<host>/browse/<KEY>`; Linear: `https://linear.app/<workspace>/issue/<KEY>`; etc. Confirm the host/workspace with the user on first run if unknown.)
- The parent ADR (if Tier 1 or Tier 2 with an ADR)
- All 5 phase files

### Step 7 — Idempotency

Before writing any file, check whether it already exists:
- ADR at the same path (e.g., goal slug already has an ADR) → ask before overwriting; offer "supersede" (write a new ADR-NNN+1 referencing the original) as the recommended option.
- SPARC bundle directory exists → ask before overwriting; offer to write into a `docs/sparc/<goal-slug>-v2/` instead.
- Brief at the same path → ask before overwriting.

### Step 8 — Final summary

After the run, print one consolidated table:

```
Goal               | Tickets             | Tier | Artifacts
event-sourcing-…  | MARK-201, MARK-202  | 1    | docs/adr/ADR-007-event-sourcing-…md
                  |                     |      | docs/sparc/event-sourcing-…/
quick-css-fix     | MARK-301            | 3    | docs/briefs/MARK-301-quick-css-fix.md
```

Then **STOP**. Do not commit. Do not push. The Tech Lead reviews and commits with the existing `docs(adr):` / `docs(spec):` prefix style.

## Rules

- **ALWAYS** confirm goal grouping when multiple tickets are passed.
- **ALWAYS** print the tier recommendation with reasoning before dispatching.
- **ALWAYS** stop on fetch failure — never proceed with partial tracker data.
- **NEVER** commit, push, or open a PR. The skill produces drafts; the Tech Lead is the gate.
- **NEVER** invent tracker data. If a field is missing, surface it; ask if needed.
- **NEVER** write a Tier-3 brief for a multi-ticket goal.
- **WHEN `--adr-only`**: skip tier classification, force Tier 1 for every goal, stop dispatch after the ADR step (no SPARC bundle, no briefs). The final summary table notes "SPARC deferred" for affected goals.

## Reference

- Slash command body: [`command.md`](./command.md)
- Sibling skills (called during dispatch):
  - [`../enhanced-adr/SKILL.md`](../enhanced-adr/SKILL.md)
  - [`../sparc-orchestration/SKILL.md`](../sparc-orchestration/SKILL.md)
  - [`../prompt-enhancer/SKILL.md`](../prompt-enhancer/SKILL.md)
