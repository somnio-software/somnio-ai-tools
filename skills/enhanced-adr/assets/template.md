# ADR Template — Enhanced WH(Y) Format

Copy this skeleton when authoring `docs/adr/ADR-NNN-<slug>.md`. Replace bracketed placeholders. Required sections are marked.

---

```markdown
---
tracker_id: [TICKET-KEY or list]                # omit if no tracker ticket
tracker_type: jira | linear | notion | other    # omit if no tracker ticket
status: Proposed
created: YYYY-MM-DD
---

# ADR-NNN: [Decision Title]

| Field | Value |
|-------|-------|
| **Decision ID** | ADR-NNN |
| **Initiative** | [Initiative or epic name] |
| **Proposed By** | [Team or person] |
| **Date** | YYYY-MM-DD |
| **Status** | Proposed |

---

## WH(Y) Decision Statement

**In the context of** [situation and constraints],
**facing** [the problem or challenge],
**we decided for** [the chosen approach],
**and neglected** [rejected alternatives and why],
**to achieve** [intended outcomes],
**accepting that** [trade-offs and consequences].

---

## Problem Statement

[Detailed context. What's the situation, what existing constraints apply, what's broken or insufficient about the current approach? Be specific — name systems, components, and stakeholders.]

---

## Opportunity

[What does this decision unlock? Why now? What value does it create — for users, for the team, for operations? Tie back to business or product goals where possible.]

---

## Options Considered

### Option 1: [Alternative name] (Selected)

**Pros:**
- […]
- […]

**Cons:**
- […]
- […]

### Option 2: [Alternative name] (Rejected)

**Pros:**
- […]

**Cons:**
- […]

**Reason for rejection:** [Specific reason — usually a constraint Option 1 satisfies and this one doesn't.]

### Option 3: [Alternative name] (Rejected)

[…]

---

## Governance

| Review Board | Date | Outcome | Action | Review Cadence | Next Review |
|--------------|------|---------|--------|----------------|-------------|
| [Architecture review / Tech leads / etc.] | YYYY-MM-DD | [Approved / Pending / etc.] | [Next step] | [Quarterly / per-release / none] | YYYY-MM-DD |

---

## Status History

| Status | Approver | Date |
|--------|----------|------|
| Proposed | [Name or team] | YYYY-MM-DD |

---

## Dependencies

| Relationship | ADR ID | Title | Notes |
|--------------|--------|-------|-------|
| Depends On | ADR-### | [Title] | [Why this depends on it] |
| Relates To | ADR-### | [Title] | [How they connect] |

Relationship vocabulary:
- **Depends On** — this decision requires the other
- **Relates To** — contextually connected
- **Supersedes** — this replaces a prior decision
- **Refines** — elaborates on a prior decision
- **Part Of** — component of a master ADR
- **Enables** — makes another decision possible

---

## References

| Reference ID | Title | Type | Location |
|--------------|-------|------|----------|
| [REF-1] | [Title] | [Spec / RFC / Doc / Issue] | [Path or URL] |

---

## Supporting Artefact

[Optional. Link to the SPARC spec that implements this decision once it exists: `docs/sparc/<slug>/`. Or link to RFC, design doc, prototype, benchmark — whatever justifies the decision.]

---

## Implementation Notes

[Optional. High-level guidance for whoever picks up the implementation. Don't duplicate the SPARC spec — keep this short. Useful for things like "this requires a feature flag during rollout" or "coordinate with the data team before phase 3".]
```

---

## Status values (full vocabulary)

| Status | Meaning |
|---|---|
| **Proposed** | Decision drafted, awaiting review |
| **Approved** | Governance approved; implementation may proceed |
| **Implemented** | Decision has been executed in code |
| **Superseded** | Replaced by a newer ADR (link the successor in Dependencies) |
| **Rejected** | Decision was not accepted |
| **Deprecated** | No longer recommended; kept for history |

## Authoring tips

- Lead with the WH(Y) statement. It's the elevator pitch for the decision and the part most readers will skim first.
- The "and neglected" clause is the most important part of WH(Y). It forces explicit comparison and prevents the ADR from reading like a fait accompli.
- Keep the ADR immutable once approved. If the decision changes, write a new ADR that supersedes this one — don't edit history.
- Keep implementation details out. Those belong in the SPARC spec at `docs/sparc/<slug>/`, which can evolve independently.
