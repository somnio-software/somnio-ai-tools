---
name: sparc-orchestration
description: Drive a feature through the 5-phase SPARC methodology — Specification, Pseudocode, Architecture, Refinement, Completion — producing a phase-structured spec bundle at docs/sparc/<goal-slug>/. Use this for non-trivial work that needs an explicit implementation plan: epic-level features, multi-component changes, or any goal where the dev team benefits from phase-by-phase deliverables. Self-contained: embeds the orchestrator, all 5 phase agents, and the docs publisher. Standalone or invoked by ticket-to-sparc Tier 1/2.
---

# SPARC Orchestration

You drive features through the SPARC 5-phase methodology and produce a phase-structured spec bundle that devs can implement against.

## When this skill applies

- A user asks to "spec out a feature", "plan this out", or "do a full SPARC for X".
- The `ticket-to-sparc` orchestrator routes a Tier-1 or Tier-2 goal to you.
- A non-trivial change needs explicit phase-by-phase deliverables before implementation begins.

## When this skill does NOT apply

- Routine work (single-file fix, config tweak). Use `prompt-enhancer` instead — five SPARC phases for a one-line change is paperwork bloat.
- An ADR needs to be drafted. Use `enhanced-adr` for that, then come back here for the spec.

## Inputs

- A **goal name** (kebab-case slug), e.g., `event-sourcing-audit-log`. If invoked from `ticket-to-sparc` the slug is provided; otherwise ask the user.
- **Goal context** — what's being built and why. Pull from the tracker ticket if available, otherwise ask the user.
- **ADR reference** (optional) — path or ID like `ADR-007`. The Architecture phase will reference it.
- **Tracker ticket keys** (optional) — included in the bundle README for traceability.

## Workflow

The orchestrator drives 5 sequential phases. Each phase has its own agent definition under [`agents/phases/`](./agents/phases/) and produces one output file. Quality gates run between phases — only proceed if the gate passes.

```
Specification → Pseudocode → Architecture → Refinement → Completion
   ↓ gate         ↓ gate        ↓ gate         ↓ gate        ↓
 1-spec.md     2-pseudo.md   3-arch.md     4-refine.md   5-done.md
```

Steps:

1. **Initialize the bundle directory** at `docs/sparc/<goal-slug>/`. Fail if it already exists unless the user confirms overwrite. Create `README.md` with frontmatter and a phase-status table (all "pending" initially).

2. **Run Phase 1 — Specification.** Delegate to [`agents/phases/1-specification.md`](./agents/phases/1-specification.md). Output: `docs/sparc/<goal-slug>/1-specification.md`. Quality gate: requirements + acceptance criteria + scope must be explicit and unambiguous. Update the README's phase-status table.

3. **Run Phase 2 — Pseudocode.** Delegate to [`agents/phases/2-pseudocode.md`](./agents/phases/2-pseudocode.md). Output: `2-pseudocode.md`. Quality gate: every requirement from Phase 1 has a corresponding pseudocode block.

4. **Run Phase 3 — Architecture.** Delegate to [`agents/phases/3-architecture.md`](./agents/phases/3-architecture.md). Output: `3-architecture.md`. **If an ADR reference was provided, this phase MUST cite it by exact filename.** Quality gate: components, data flow, integration points, and ADR linkage are all present.

5. **Run Phase 4 — Refinement.** Delegate to [`agents/phases/4-refinement.md`](./agents/phases/4-refinement.md). Output: `4-refinement.md`. Quality gate: edge cases, performance considerations, security considerations, and test strategy are all covered.

6. **Run Phase 5 — Completion.** Delegate to [`agents/phases/5-completion.md`](./agents/phases/5-completion.md). Output: `5-completion.md`. Quality gate: integration plan, definition of done, rollout/verification steps are all explicit.

7. **Finalize the README** index. Use the publisher agent at [`agents/docs-writer.md`](./agents/docs-writer.md) to produce a clean Markdown index linking all 5 phases, the ADR (if any), and the tracker tickets. Phase-status table updated to "complete" for each.

8. **Stop. Do not commit.** Print a summary of what was produced and the path to the bundle.

## Output layout

```
docs/sparc/<goal-slug>/
├── README.md            # index + phase status + tracker/ADR links
├── 1-specification.md
├── 2-pseudocode.md
├── 3-architecture.md
├── 4-refinement.md
└── 5-completion.md
```

## Output frontmatter

Every file in the bundle uses YAML frontmatter:

```yaml
---
tracker_id: <TICKET-KEY>                       # or [LIST] for multi-ticket goals; omit if no tracker
tracker_type: jira | linear | notion | other   # omit if no tracker
adr: ADR-NNN-<slug>                            # omit if Tier 2 with no new ADR
goal: <goal-slug>
phase: 1-specification                         # one of 1-specification..5-completion, README has no phase
created: YYYY-MM-DD
---
```

## Quality gate rules

- **NEVER** skip phases. The discipline is the value.
- **NEVER** advance to the next phase if the current quality gate fails. Print what's missing and stop.
- **NEVER** edit a previous phase mid-run. If a Phase 3 finding contradicts Phase 1, stop, surface the conflict, ask the user how to resolve.

## Reference

- Orchestrator details: [`agents/orchestrator.md`](./agents/orchestrator.md)
- Phase agents: [`agents/phases/1-specification.md`](./agents/phases/1-specification.md) … [`agents/phases/5-completion.md`](./agents/phases/5-completion.md)
- Publisher: [`agents/docs-writer.md`](./agents/docs-writer.md)

## Bundle layout

```
sparc-orchestration/
├── SKILL.md
└── agents/
    ├── orchestrator.md          # 5-phase driver with quality gates
    ├── docs-writer.md           # Markdown publisher for README index
    └── phases/
        ├── 1-specification.md
        ├── 2-pseudocode.md
        ├── 3-architecture.md
        ├── 4-refinement.md
        └── 5-completion.md
```
