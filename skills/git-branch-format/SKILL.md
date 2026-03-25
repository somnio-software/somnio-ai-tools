---
name: git-branch-format
description: >-
  Generates properly formatted Git branch names following project conventions.
  Use this skill whenever the user wants to name a branch, create a branch, or asks things like
  "what should I call this branch?", "what branch name should I use?", "help me with the branch name",
  or describes a feature/fix and needs a branch name. Always use this skill when the user needs a
  git branch name, even if they don't explicitly say "branch".
---

# Git Branch Format Skill

Generates a **branch name** from a description of changes.

---

## Convention

### With ticket number

```
{type}/{TICKET_NUMBER}_{short_description}
```

- `TICKET_NUMBER` is uppercase as provided by the user (e.g. `PROJ-548`)
- `short_description` is `snake_case`, brief (2–5 words)
- Example: `feat/TICKET-548_flutter_upgrade`

### Without ticket number

```
{type}/{short_description}
```

- `short_description` is `snake_case`, brief (2–5 words)
- Example: `feat/flutter_upgrade`

Never use placeholders like `NO-TICKET`. If there's no ticket, just omit that part entirely.

---

## Type Selection Guide

| Type | When to use |
|------|-------------|
| `feat` | New functionality |
| `fix` | Bug fix |
| `refactor` | Code change with no behavior change |
| `chore` | Config, deps, tooling, maintenance |
| `test` | Adding or updating tests |
| `docs` | Documentation only |
| `style` | Formatting, whitespace |
| `perf` | Performance improvement |
| `ci` | CI/CD changes |
| `build` | Build system changes |
| `revert` | Reverting a previous commit |

---

## Workflow

1. Read the user's description of changes.
2. Ask: *"Do you have a ticket number for this?"* — if the user doesn't provide one, proceed without it.
3. Infer the correct `type` from the nature of the changes.
4. Generate the branch name following the convention above.

---

## Examples

**User:** "I'm adding dark mode support" — Ticket: PROJ-312

```
feat/PROJ-312_dark_mode_support
```

---

**User:** "fixing a crash on the payment screen" — No ticket

```
fix/payment_screen_crash
```

---

**User:** "upgrading Flutter and fixing deprecated APIs" — Ticket: PROJ-548

```
feat/PROJ-548_flutter_upgrade
```
