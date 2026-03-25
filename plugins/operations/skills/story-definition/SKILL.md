---
name: story-definition
description: >-
  Define well-structured user stories with acceptance criteria, sizing, and
  dependencies from project context. Use when breaking down features into
  implementable stories, refining a backlog, turning requirements or ideas
  into actionable tickets, preparing stories for sprint planning, or when
  someone says "create stories for this feature" or "break this down into
  tickets."
argument-hint: "<feature, epic, or requirement to break into stories>"
---

# Story Definition

Help teams define clear, implementable user stories from features, epics, requirements, or ideas. Pull project context from connected tools, apply structured frameworks, and create stories directly in the project tracker.

## Workflow

### Step 1 — Gather context

Understand what needs to be broken down before writing anything.

**If `~~project tracker` is connected:**

- Ask the user which project or board to work with
- Pull the current epics, labels, and team members to understand project structure
- Check existing backlog for related or duplicate stories
- Pull any linked requirements, specs, or parent epics for context
- Identify the project's existing conventions (label taxonomy, story point scale, naming patterns)

**If no project tracker is connected:**

- Ask the user to describe the feature, epic, or requirement
- Ask about the team context: who will implement, what tech stack, any constraints
- Ask about existing conventions they follow for story format

**Always ask:**

- What is the goal or outcome this work should achieve?
- Are there known constraints (timeline, dependencies, technical limitations)?
- What level of granularity do they need? (epic-level, sprint-ready, task-level)

### Step 2 — Analyze and decompose

Break down the input into logical, implementable units.

**Decomposition principles:**

1. **Vertical slicing** — Each story delivers a thin slice of end-to-end value, not a horizontal layer. A story should touch all layers needed (UI, API, DB) for one specific behavior.
2. **INVEST criteria** — Every story must be:
   - **I**ndependent — Can be built and delivered without waiting for other stories (minimize dependencies)
   - **N**egotiable — Details can be discussed; it is not a rigid specification
   - **V**aluable — Delivers clear value to a user, stakeholder, or the system
   - **E**stimable — The team can reasonably estimate the effort
   - **S**mall — Fits within a single sprint (if too big, split further)
   - **T**estable — Has clear conditions to verify it is done
3. **Dependency mapping** — Identify which stories block others and flag circular dependencies
4. **Risk-first ordering** — Surface high-risk or high-uncertainty stories early so they can be tackled first

**Splitting strategies when a story is too large:**

| Strategy | When to use | Example |
|----------|-------------|---------|
| By workflow step | Multi-step process | "User can add item to cart" vs "User can checkout" |
| By business rule | Complex validation | "Basic validation" vs "Edge-case handling" |
| By data variation | Multiple entity types | "Import CSV contacts" vs "Import CSV companies" |
| By interface | Multiple entry points | "Create via form" vs "Create via API" |
| By operation | Full CRUD | "View list" vs "Edit item" vs "Delete item" |
| By persona | Different user types | "Admin can configure" vs "Member can view" |
| Happy path / edge cases | Complex flows | "Successful payment" vs "Payment retry on failure" |

### Step 3 — Write stories

Use this format for each story. Adapt field names to match the project's conventions if they differ.

```
Title: [Action-oriented, concise — starts with a verb or "As a..."]

User story:
As a [specific persona/role],
I want to [concrete action],
so that [measurable outcome or business value].

Acceptance criteria:
- [ ] Given [context], when [action], then [expected result]
- [ ] Given [context], when [action], then [expected result]
- [ ] [Additional criteria using Given/When/Then or plain checkboxes]

Definition of done:
- [ ] Code implemented and passing CI
- [ ] Unit/integration tests covering acceptance criteria
- [ ] Code reviewed and approved
- [ ] [Project-specific DoD items from team conventions]

Technical notes:
- Implementation hints, API contracts, data model changes
- Links to relevant specs, designs, or documentation
- Known risks or open questions to resolve during implementation

Size: [T-shirt (XS/S/M/L/XL) or story points — match project convention]
Priority: [P0-Critical / P1-High / P2-Medium / P3-Low]
Labels: [Use existing project labels when available]
Dependencies: [List story titles or IDs this story depends on]
```

**Writing quality checklist — apply to every story:**

- Title is scannable in a board view (under 80 characters)
- "So that" clause has a real outcome, not a restatement of the action
- Acceptance criteria are testable — no ambiguous words like "should work well"
- Each acceptance criterion covers one behavior (split compound criteria)
- Technical notes exist for anything non-obvious to the implementer
- Size reflects actual complexity, not just code volume
- No hidden work — if the story requires migrations, config changes, or docs updates, they are explicit

### Step 4 — Validate and organize

Before presenting or creating stories, run a quality pass.

**Validation checks:**

1. **Coverage** — Does the full set of stories deliver the complete feature/epic? Identify gaps.
2. **Overlap** — Are any two stories doing the same work? Merge or clarify boundaries.
3. **Dependency graph** — Can the stories be ordered into a buildable sequence? Flag circular dependencies.
4. **Sprint fitness** — Is each story small enough for one sprint? Flag any that need further splitting.
5. **Testability** — Can QA verify every acceptance criterion without ambiguity?
6. **Backlog check** — If `~~project tracker` is connected, verify no existing stories already cover this work.

**Organize the output:**

- Group stories by epic or functional area
- Order by suggested implementation sequence (dependencies first, then priority)
- Clearly mark which stories are sprint-ready vs need further refinement
- Summarize the total scope: number of stories, estimated total effort, suggested sprint distribution

### Step 5 — Create in project tracker

**If `~~project tracker` is connected:**

- Confirm with the user before creating any tickets
- Show a summary table first:

| # | Title | Size | Priority | Dependencies |
|---|-------|------|----------|-------------|
| 1 | ... | S | P1 | — |
| 2 | ... | M | P1 | #1 |

- After user approval, create each story in the connected tool
- Apply labels, assignees, sprint, and parent epic as discussed
- Set up dependency links between stories where supported
- Report back with links to created tickets

**If no project tracker is connected:**

- Present the stories in the structured format above
- Offer to export as markdown or a formatted list the user can paste into their tool

### Step 6 — Notify team

**If `~~chat` is connected:**

- Ask if the user wants to notify the team about the new stories
- Draft a concise message summarizing what was created, how many stories, total estimated effort, and a link to the board/project
- Post only after user confirms

## Story sizing guide

Use the project's existing scale. If none exists, suggest one of these:

**T-shirt sizes (recommended for teams new to estimation):**

| Size | Typical scope | Examples |
|------|--------------|---------|
| XS | Config change, copy update, one-line fix | Toggle a feature flag, fix a typo |
| S | Single component, clear path | Add a form field, new API endpoint with known pattern |
| M | Multiple components, some unknowns | New CRUD feature, integration with documented API |
| L | Cross-cutting, needs design decisions | New auth flow, data migration with transformation |
| XL | Should probably be split further | Full feature redesign, new service |

**Fibonacci story points (for teams using velocity tracking):**

| Points | Relative effort |
|--------|----------------|
| 1 | Trivial — hours |
| 2 | Small — a day or less |
| 3 | Moderate — a couple of days |
| 5 | Significant — most of a week |
| 8 | Large — full week, consider splitting |
| 13 | Very large — must split |

## Priority framework

| Level | Label | Criteria | Action |
|-------|-------|----------|--------|
| P0 | Critical | Blocks release, security issue, data loss risk | Immediate — current sprint |
| P1 | High | Core to the feature/epic goal, high user impact | Next available sprint |
| P2 | Medium | Valuable improvement, not blocking | Backlog — schedule when capacity allows |
| P3 | Low | Nice-to-have, polish, minor enhancement | Backlog — revisit during planning |

## Anti-patterns to avoid

| Anti-pattern | Problem | Fix |
|-------------|---------|-----|
| "Implement feature X" | No user value stated, no acceptance criteria | Add persona, outcome, and testable criteria |
| Horizontal slicing | "Build the API" then "Build the UI" — no deliverable value until both done | Slice vertically — one behavior end-to-end |
| Giant stories | "As a user I want the whole checkout flow" — unestimable | Split by workflow step, operation, or business rule |
| Vague acceptance criteria | "It should work correctly" — untestable | Use Given/When/Then with specific inputs and outputs |
| Missing dependencies | Story fails because a prerequisite was not identified | Map dependencies explicitly during decomposition |
| Gold-plating | Story includes "nice-to-have" details mixed with core requirements | Separate must-have criteria from enhancements |
| Copy-paste personas | "As a user" for everything — loses context | Use specific roles: admin, member, guest, API consumer |
