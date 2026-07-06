---
name: optimize-claude-config
description: |
  Audits and optimizes a repository's Claude Code configuration so path-scoped
  rules load lazily and CLAUDE.md stays a lightweight always-loaded index.
  First maps the real project tree (domains, monorepo package roots, extensions,
  generated/frozen areas) so every path glob is derived from and validated
  against actual files — stale globs that match zero files and over-broad ones
  are caught. Three areas: (1) migrate .claude/rules/**/*.md frontmatter to the
  native lazy-load `paths:` YAML-array form (away from eager `globs:` or
  red-flagged CSV `paths:`) with accurate, tree-validated patterns; (2) slim CLAUDE.md files to an index + rule map and delete
  redundant @import-only shells; (3) audit/install the PreToolUse(Write) hook
  that works around the read-not-create caveat. Audits first, shows a report,
  asks for confirmation, then applies. Pass --audit-only to skip applying.
argument-hint: "[--audit-only] [path]"
allowed-tools: Bash Read Edit Write
---

# optimize-claude-config

Optimize the `.claude/` config of a repo so rules load *only when relevant* and
CLAUDE.md stays small. Default mode audits, reports, asks to confirm, then
applies. `--audit-only` stops after the report.

## Why this matters (canonical facts)

Verified empirically in Claude Code **2.1.145**:

- **`paths:` as a YAML array** lazy-loads a rule (it enters context only when a
  matching file is read) AND passes the IDE extension's schema validation. This
  is the target format.
- **CSV single-line `paths: a, b`** lazy-loads at runtime but the IDE flags it
  red (*"paths must be an array of glob patterns"*). Migrate to the array form.
  YAML-array support landed in CC 2.1.84.
- **`globs: "..."`** (Cursor's field) loads **eager at session start, ignoring
  scope**. This is the main thing to fix — convert to `paths:`.
- **`alwaysApply:`** is a Cursor field, ignored by Claude Code — harmless noise.
  Leave it; do not churn files just to remove it.
- A rule with **no `paths:` and no `globs:`** is effectively always-loaded. Flag
  it: either it genuinely belongs in CLAUDE.md, or it needs a `paths:` scope.
- **Read-not-create caveat (bug #23478):** path-scoped rules trigger on *read*,
  not *create*. Creating a brand-new file that matches a rule, without first
  reading a neighbor, does NOT load that rule. The hook in area 3 backstops this.
- **CLAUDE.md** should be a lightweight, always-loaded **index**: project
  overview + a rule map (pointers into `.claude/rules/*`) + a short "Critical
  Rules" digest — NOT full rule bodies inlined. Per-directory CLAUDE.md files
  that are pure `@import` shells are redundant once rules self-load via `paths:`.

## Step 0 — Parse arguments

- `--audit-only` present → report only, never edit or write.
- A trailing path arg → treat it as the repo root to scan; otherwise use the
  current working directory. Resolve `.claude/` under that root.
- If `<root>/.claude` does not exist, stop and tell the user there is nothing to
  optimize here.

## Step 1 — Discover

Collect, under `<root>`:

```bash
find .claude/rules -type f -name '*.md' 2>/dev/null
find . -name 'CLAUDE.md' -not -path '*/node_modules/*' 2>/dev/null
ls .claude/settings.json .claude/settings.local.json 2>/dev/null
ls .claude/hooks/inject-rules.py 2>/dev/null
```

Read each rule file's frontmatter, each CLAUDE.md, and the settings file(s).

## Step 1b — Analyze project structure (derive paths from reality)

Do NOT guess path globs or trust existing ones blindly. Build a factual map of
the repo first, then derive/validate every `paths:` against it.

Enumerate the real tree (tracked files only, so build output and deps are
excluded):

```bash
git ls-files 2>/dev/null || find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/build/*'
```

From that file list, compute:

1. **Top-level domains** — the first path segment of each file (e.g. `apps/`,
   `functions/`, `packages/`). These are the coarse areas rules will scope to.
2. **Monorepo package roots** — directories containing a manifest
   (`pubspec.yaml`, `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`).
   Nested packages (e.g. `apps/mobile/packages/*/`) change the right glob depth:
   prefer `apps/mobile/packages/*/lib/**/*.dart` over a flat `**/*.dart`.
3. **Extensions per domain** — which file types live where (e.g. `.dart` under
   `apps/`, `.ts` under `functions/`). This tells you the file-type tail of each
   glob (`**/*.dart` vs `**/*.ts`).
4. **Generated / vendored / frozen areas** — directories a rule should NOT match
   (`*.g.dart`, `*.freezed.dart`, `build/`, `node_modules/`, `lib/` build output,
   and anything the repo's CLAUDE.md marks frozen/deprecated). Exclude these from
   proposed globs.

Use a quick aggregation to see the shape, e.g.:

```bash
# extensions by top-level domain
git ls-files | awk -F/ '{d=$1; n=split($NF,a,"."); print d"  *."a[n]}' | sort | uniq -c | sort -rn | head -40
# package roots
git ls-files | grep -E '/(pubspec\.yaml|package\.json|Cargo\.toml|go\.mod|pyproject\.toml)$'
```

Hold this map; Step 2 uses it to validate and derive globs.

## Step 2 — Audit rules frontmatter

For every `.claude/rules/**/*.md`, classify its frontmatter:

| Finding | Condition | Proposed action |
|---|---|---|
| ✅ OK | `paths:` is a YAML array (one `- pattern` per line) | none |
| 🔴 eager `globs:` | has `globs:` (any form) | rename key to `paths:`, convert value to a YAML array (one item per line) |
| 🟡 CSV `paths:` | `paths:` value is inline / comma-separated on one line | reformat to a YAML array |
| 🟡 unscoped | no `paths:` and no `globs:` | derive a candidate scope from Step 1b and the rule's own domain, then propose it for the user to confirm. Do NOT auto-apply a scope. |
| 🟠 stale glob | a `paths:`/`globs:` pattern matches **zero** tracked files | flag it — the directory was renamed/removed, or the depth/extension is wrong. Propose the corrected pattern from the real tree. |
| 🟠 over-broad | a pattern matches generated/vendored/frozen files (Step 1b list) | tighten it (add the right package depth, or narrow the extension) so the rule only loads for hand-written source. |

**Validate every pattern against the real tree.** For each `paths:`/`globs:`
entry, check it actually matches files (reuse the glob→regex logic from the hook,
or `git ls-files | grep` with the glob translated). A pattern matching zero files
is the most common silent failure — the rule looks scoped but never loads.

**Deriving a glob (for unscoped or stale rules).** Use the Step 1b map:
- Identify the rule's domain from its `description:`/body (e.g. "Flutter
  client", "Cloud Functions", "TypeScript") and map it to the real top-level
  domain(s) and extension(s) you found.
- Respect monorepo package depth — emit `apps/mobile/packages/*/lib/**/*.dart`
  when packages exist, not a flat `**/*.dart`.
- Exclude generated/frozen areas; never scope a rule to `build/`,
  `node_modules/`, `*.g.dart`, or a deprecated/frozen dir.
- Present each derived glob with the **count of files it matches** so the user
  can sanity-check (e.g. `apps/mobile/lib/**/*.dart → 142 files`).

Conversion rules:
- When a pattern is already correct, preserve it verbatim — only change the key
  name and the YAML shape. Strip surrounding quotes the CSV form may have.
- Only rewrite a pattern's *value* when Step 1b proves it stale or over-broad,
  and show the before/after in the report.
- Keep `description:` and any `alwaysApply:` line unchanged.
- Idempotent: a file already in the ✅ state with patterns that match real files
  gets no edit.

Target shape:

```yaml
---
description: <unchanged>
alwaysApply: false        # only if it was already there
paths:
  - apps/mobile/lib/**/*.dart
  - functions/**/*.ts
---
```

## Step 3 — Audit CLAUDE.md slimming

For each `CLAUDE.md` found:

1. **Pure `@import` shell** — file body (after stripping blank lines/comments) is
   nothing but `@import`/`@path` lines → **redundant**, because rules now
   self-load via `paths:`. Propose deletion. Exception: keep it if a parent
   `CLAUDE.md` relies on importing it AND it carries unique prose.
2. **Bloated index** — a top-level CLAUDE.md that inlines full rule bodies that
   already exist under `.claude/rules/`. Propose replacing the duplicated section
   with a one-line pointer (`(→ .claude/rules/<area>/<file>.md)`), keeping only a
   short digest. Do NOT delete unique content — only de-duplicate what is
   verbatim-present in a rule file.
3. **Healthy index** — overview + rule map + short Critical Rules digest →
   leave it.

Be conservative: when unsure whether content is unique, flag it for the user
rather than deleting. Never delete a CLAUDE.md that has hand-written guidance not
covered by a rule.

## Step 4 — Audit the read-not-create hook

Check two things:

1. `.claude/settings.json` registers a `PreToolUse` hook with matcher `Write`
   pointing at `.claude/hooks/inject-rules.py`.
2. `.claude/hooks/inject-rules.py` exists.

If either is missing, propose installing it. The canonical files are embedded
below — **this skill is self-contained**. Always reproduce them verbatim from
the blocks in this document. NEVER copy `inject-rules.py` (or any config) from
another repository, a sibling project, or a path on the host machine — there is
no "reference repo". The skill must behave identically for anyone who runs it,
including a colleague who only has this skill file.

**`.claude/settings.json`** (merge into existing `hooks` block; don't clobber
other hooks):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/inject-rules.py\""
          }
        ]
      }
    ]
  }
}
```

**`.claude/hooks/inject-rules.py`** — when absent, `Write` this exact content
(copy the block below character-for-character; do not fetch it from elsewhere):

```python
#!/usr/bin/env python3
"""PreToolUse(Write) hook: inject path-scoped rules when creating a new file.

Works around the read-not-create caveat (#23478): `.claude/rules/*.md` files
with `paths:` frontmatter load on read, not on create. When Claude creates a
NEW file matching a rule's paths, this injects that rule's body as
additionalContext so it is in context before the file is written.

Fires only for: Write to a file that does NOT yet exist AND matches at least
one rule's `paths:` patterns. Otherwise it exits silently.
"""
import json
import sys
import os
import re
import glob


def glob_to_regex(pat):
    out, i = ['^'], 0
    while i < len(pat):
        if pat[i:i + 3] == '**/':
            out.append('(?:.*/)?')
            i += 3
        elif pat[i:i + 2] == '**':
            out.append('.*')
            i += 2
        elif pat[i] == '*':
            out.append('[^/]*')
            i += 1
        elif pat[i] == '?':
            out.append('[^/]')
            i += 1
        else:
            out.append(re.escape(pat[i]))
            i += 1
    out.append('$')
    return re.compile(''.join(out))


def parse_paths(frontmatter):
    paths, in_paths = [], False
    for line in frontmatter.splitlines():
        if re.match(r'^paths:\s*$', line):
            in_paths = True
            continue
        if in_paths:
            m = re.match(r'^\s*-\s*(.+?)\s*$', line)
            if m:
                paths.append(m.group(1))
            elif line.strip() and not line[0].isspace():
                in_paths = False
    return paths


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return

    proj = os.environ.get('CLAUDE_PROJECT_DIR') or data.get('cwd') or os.getcwd()
    file_path = (data.get('tool_input') or {}).get('file_path', '')
    if not file_path:
        return

    abs_fp = file_path if os.path.isabs(file_path) else os.path.join(proj, file_path)
    # Only the caveat case: a brand-new file.
    if os.path.exists(abs_fp):
        return

    rel = os.path.relpath(abs_fp, proj)
    chunks = []
    pattern = os.path.join(proj, '.claude', 'rules', '**', '*.md')
    for rule_file in glob.glob(pattern, recursive=True):
        try:
            txt = open(rule_file, encoding='utf-8').read()
        except Exception:
            continue
        if not txt.startswith('---'):
            continue
        end = txt.find('\n---', 3)
        if end == -1:
            continue
        frontmatter, body = txt[3:end], txt[end + 4:]
        if any(glob_to_regex(p).match(rel) for p in parse_paths(frontmatter)):
            chunks.append(body.strip())

    if not chunks:
        return

    context = (
        'The file you are about to create (`' + rel + '`) matches path-scoped '
        'rules that were NOT yet loaded into context (they load on read, not on '
        'create). Apply the following rule(s) to the content you write now:\n\n'
        + '\n\n---\n\n'.join(chunks)
    )
    print(json.dumps({
        'hookSpecificOutput': {
            'hookEventName': 'PreToolUse',
            'additionalContext': context,
        }
    }))


main()
```

If `inject-rules.py` exists but differs from the embedded canonical, report the
diff and ask before overwriting — the user may have customized it. When the user
confirms a sync, `Write` the embedded block above; do not pull the file from any
other location.

## Step 5 — Report

Print one consolidated table grouped by area (Rules / CLAUDE.md / Hook), each row
being `path · finding · proposed action`. For any glob that changes or is
derived, show before → after **with the file-match count** so the scope is
verifiable at a glance (e.g. `globs:"lib/**" → paths: apps/mobile/lib/**/*.dart
(142 files)`). End with a count summary, e.g. `3 rules to migrate · 1 stale glob
fixed · 1 CLAUDE.md to delete · hook already installed`.

If nothing needs changing, say so plainly and stop — the config is already
optimal.

## Step 6 — Confirm & apply

- If `--audit-only`: stop after the report.
- Otherwise ask the user to confirm (`y` to apply all, or let them deselect
  specific rows). Then:
  - Edit rule frontmatter with `Edit` (key rename + YAML-array reshape).
  - Delete redundant shells with `rm`; de-duplicate bloated CLAUDE.md with `Edit`.
  - Install the hook (`Write` the script, `Edit`/`Write` settings.json) only if
    that row was confirmed.
- Never touch `unscoped` rules or ambiguous CLAUDE.md content automatically —
  those are advisory flags for the user to resolve by hand.

## Step 7 — Verify

After applying, tell the user how to confirm lazy-loading works:
- Run `/memory` (or read a file matching a migrated rule's `paths:`) and look for
  the `⎿ Loaded …` InstructionsLoaded message — the rule should appear only when
  a matching file is in context, not at session start.
- The hook fires only on creating a *new* matching file; the additionalContext
  arrives after the first write, so the model self-corrects with a second write
  (create-then-fix). Net result: the new file ends up compliant.

Do not run `git commit` unless the user asks.
