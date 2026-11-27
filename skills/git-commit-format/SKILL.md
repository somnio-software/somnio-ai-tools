---
name: git-commit-format
description: >-
  Generates Conventional Commits messages (title + description). Use for
  "write a commit for these changes", "how should I commit this?".
---

# Git Commit Format Skill

Generates a **commit message** (title + description) from a description of changes.

---

## Conventions

### Commit Title

Follows **Conventional Commits** spec:

```
{type}({optional scope}): {short imperative description}
```

- **Types:** `feat`, `fix`, `chore`, `refactor`, `docs`, `style`, `test`, `perf`, `ci`, `build`, `revert`
- Use imperative mood: "add", "fix", "remove" — not "added", "fixed", "removed"
- Max ~72 characters
- All lowercase except proper nouns
- No period at the end
- Example: `feat(auth): add biometric login support`

### Commit Description

Bullet list using past tense action words:

```
* Fixed ...
* Added ...
* Changed ...
* Removed ...
```

- Only include bullets that apply to the actual changes
- Keep each bullet concise and specific
- Allowed verbs: `Fixed`, `Added`, `Changed`, `Removed`, `Updated`, `Refactored`, `Migrated`, `Deprecated`
- Always in **English**
- **Never** include `Co-Authored-By`, `Signed-off-by`, or any trailer attributing the commit to an AI agent or tool

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

If the changes span multiple concerns, suggest splitting into separate commits.

---

## Output Format

```
feat(flutter): upgrade Flutter SDK to v3.19

* Updated Flutter SDK version to 3.19
* Changed minimum iOS deployment target to 14.0
* Fixed deprecated API usages after upgrade
* Removed unused legacy plugins
```

> The commit message must end after the bullet list. Do **not** append any `Co-Authored-By`, `Signed-off-by`, or AI attribution trailers.

---

## Examples

**User:** "I upgraded Flutter and had to fix some deprecated APIs and update the iOS target"

```
feat(flutter): upgrade Flutter SDK to v3.19

* Updated Flutter SDK version to 3.19
* Changed minimum iOS deployment target to 14.0
* Fixed deprecated API usages after upgrade
```

---

**User:** "Fixed a crash on login when the user has no internet"

```
fix(auth): handle login crash when offline

* Fixed crash on login screen when no internet connection is available
* Added offline error state to login flow
```
