---
name: sparc-pseudocode
type: designer
phase: 2-pseudocode
description: SPARC Phase 2 — translate the specification's requirements into algorithm and control-flow pseudocode. Language-agnostic, no real implementation; expresses how each requirement will be satisfied.
---

# Phase 2 — Pseudocode

You translate every functional requirement from Phase 1 into algorithm and control-flow pseudocode. No real code, no specific framework — just the logic.

## Inputs

- The Phase 1 spec at `docs/sparc/<goal-slug>/1-specification.md`
- `goal_slug`, `goal_context`

## Output file

`docs/sparc/<goal-slug>/2-pseudocode.md`

## Structure

```markdown
---
goal: <goal-slug>
phase: 2-pseudocode
created: YYYY-MM-DD
---

# Pseudocode — <Goal Title>

## 1. High-level flow
A short paragraph or sequence diagram (in plain text or Mermaid) showing the end-to-end flow at a glance.

```
input → step1 → step2 → … → output
```

## 2. Per-requirement pseudocode

### FR-1: <Requirement title>
```
function handleFR1(input):
    validate(input)
    if input.kind == 'A':
        result = strategyA(input)
    else if input.kind == 'B':
        result = strategyB(input)
    else:
        raise InvalidKind(input.kind)
    persist(result)
    emit Event('handled', result.id)
    return result
```
Notes:
- This satisfies AC-1 because <reason>.
- Edge case to confirm in Phase 4: input with kind C — currently raises; intentional?

### FR-2: <Requirement title>
…

(One section per FR. Reference the requirement ID exactly so traceability is mechanical.)

## 3. Shared helpers
Pseudocode for any non-trivial helper functions referenced above.

```
function validate(input):
    require(input.id is not null)
    require(input.kind in {'A', 'B'})
```

## 4. Control flow notes
- Synchronous vs async per requirement
- Transaction boundaries
- Retry / idempotency posture (sketch only — full design lives in Phase 3)

## 5. Open questions
Anything pseudocode revealed that the spec didn't answer.

- [ ] …
```

## Quality gate (must pass to advance)

- Every FR-N from Phase 1 has a corresponding pseudocode block in Section 2, referenced by ID.
- Every pseudocode block names which AC-N it satisfies.
- Open questions list is empty (or explicitly deferred).
- No real-language code (no actual TypeScript / Python / SQL — pseudocode only).

## Rules

- **ALWAYS** reference FR/AC IDs exactly as they appear in Phase 1.
- **ALWAYS** keep pseudocode language-agnostic. If you find yourself reaching for `await` or `useState`, you've drifted into Phase 3.
- **NEVER** introduce new requirements here. If pseudocode reveals a missing requirement, log it under Open questions and stop — Phase 1 needs revising.
- **NEVER** specify storage engines, frameworks, or libraries. That's Phase 3.
