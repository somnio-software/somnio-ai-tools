# Harness Inventory

> Locate every AI-harness piece in the repository and capture concrete,
> read-only evidence (paths, line counts, frontmatter, key excerpts) for each of
> the 7 scored pieces. Do NOT judge quality or assign scores here — that is the
> scoring step's job. Framework-agnostic with runtime detection.

---

Goal: Produce a complete, evidence-backed inventory of the harness surface so
the scoring step can apply the rubric without re-reading the repository.

READ-ONLY DISCIPLINE (non-negotiable):
- This step MUST NOT modify, create, reformat, or delete any file in the audited
  repository. Use only read/search commands (`find`, `grep`, `cat`, `wc`, `ls`,
  `Read`, `Grep`, `Glob`).
- Do NOT run `git commit`, formatters, installers, or any mutating command.
- Your only writes are to `reports/.artifacts/` (your own artifact).

EFFICIENCY REQUIREMENTS:
- Target: <= 12 total tool calls for the entire inventory.
- Use batch `find` / `ls` commands instead of reading files one by one.
- Pipe large outputs through `| head -50`.
- Read frontmatter with `head -20` rather than whole files where possible.

## What to locate (the 7 scored pieces + lifecycle)

Detect each item below and record the evidence noted. Absence is a valid,
important finding — record "Not found" explicitly.

### 1. CLAUDE.md — existence (10 pts) and quality (+10 pts)

- Find all CLAUDE.md files:
  `find . -maxdepth 3 -iname 'CLAUDE.md' -not -path '*/node_modules/*' 2>/dev/null`
  (check repo root, `.claude/CLAUDE.md`, and nested per-package copies).
- For the primary CLAUDE.md (root or `.claude/`), capture:
  - Line count: `wc -l <path>` (the quality criterion requires < 200 lines).
  - Whether it contains **real build/test commands** — grep for command fences
    and verbs: `grep -nE '(npm|pnpm|yarn|make|docker|pytest|jest|go test|cargo|dart|flutter|nest|vite)' <path> | head -30`.
  - Whether it documents **conventions** (branching, PR format, layering,
    directory map, naming) — grep for headings like `## `, `branch`, `PR`,
    `convention`, `workflow`.
- Evidence to record: path, line count, 3-5 example command lines, whether
  conventions are present.

### 2. Rules — path-scoped (10 pts)

- List rule files: `ls -1 .claude/rules/*.md 2>/dev/null` (and `.cursor/rules/`).
- For each rule, read the YAML frontmatter (first ~15 lines) and detect a
  `paths:` or `globs:` key that scopes the rule to real stack paths:
  `head -15 .claude/rules/*.md`.
- A rule qualifies only if it has a `paths:`/`globs:` scope that targets
  stack-relevant files (e.g. `src/**/*.ts`, `**/*.py`, `apps/*/`). An
  always-on rule with no path scope does NOT satisfy this criterion.
- Evidence to record: rule filenames, the `paths:` value of at least one
  qualifying rule, and whether the glob targets files that actually exist.

### 3. Permissions — settings.json deny of secrets (15 pts)

- Locate settings: `ls -la .claude/settings.json .claude/settings.local.json 2>/dev/null`.
- Read the `permissions` block, specifically the `deny` array:
  `cat .claude/settings.json 2>/dev/null | head -80`.
- The criterion is met only when a **project** `settings.json` (not just
  `settings.local.json`) contains a `deny` entry protecting secrets — e.g.
  `Read(./.env)`, `Read(./.env.*)`, `Read(./secrets/**)`, or equivalent
  credential-file denies.
- Evidence to record: which settings file(s) exist, whether `permissions.deny`
  exists, and the exact deny entries covering secrets.

### 4. Commands / Skills — invocable team procedure (15 pts)

- List commands: `ls -1 .claude/commands/*.md 2>/dev/null`.
- List skills: `ls -1 .claude/skills/*/SKILL.md 2>/dev/null`.
- The criterion is met when at least one invocable procedure exists that encodes
  a real team workflow (deploy, review, release, ticket-to-PR, etc.), not an
  empty stub.
- Evidence to record: filenames/skill names found, and a one-line summary of
  what the most substantive one does (from its description/frontmatter).

### 5. Hooks — automated validation (20 pts)

- Read the `hooks` block of settings.json:
  `cat .claude/settings.json 2>/dev/null | head -120` and search for
  `"hooks"`, `"PostToolUse"`, `"Stop"`, `"PreToolUse"`.
- The criterion is met when a hook wired to **`PostToolUse`** or **`Stop`** runs
  real validation — lint, format, typecheck, or tests. Grep the hook `command`
  values for `lint|format|prettier|eslint|test|jest|pytest|tsc|typecheck|vitest`.
- Also check `.husky/` for git-hook-based validation as corroborating evidence:
  `ls -1 .husky/ 2>/dev/null`.
- Evidence to record: which event the hook fires on, and the exact validation
  command(s) it runs. A hook that only logs or does nothing does NOT qualify.

### 6. Agents — custom role (10 pts)

- List agents: `ls -1 .claude/agents/*.md 2>/dev/null`.
- Read frontmatter of each (`head -15 .claude/agents/*.md`) and confirm at least
  one defines a real specialized role (reviewer, qa, tester, security, architect)
  with a `name:`/`description:`.
- Evidence to record: agent filenames and the role each fills.

### 7. Autotest → PR lifecycle (10 pts)

- Determine whether the agent can reach a **green PR on its own**. Look for the
  full lifecycle being automatable and enforced:
  - CI that runs tests on PRs: `ls .github/workflows/*.yml 2>/dev/null` then
    `grep -nE '(test|lint|build|jest|pytest|vitest)' .github/workflows/*.yml | head -20`.
  - A skill/command that takes a ticket to a PR (e.g. a `ticket-to-pr` skill or
    a `ship`/`pr` command) — cross-reference the Commands/Skills inventory.
  - Test scripts present and runnable: `grep -nE '"(test|test:e2e|lint)"' package.json 2>/dev/null`.
- The criterion is met when there is concrete evidence that the harness closes
  the loop: run tests → get them green → open/update a PR, without a human
  hand-carrying each step.
- Evidence to record: CI workflow names and the gates they enforce, the
  ship/PR procedure if present, and whether tests gate the PR.

## MONOREPO DETECTION

- If `apps/`, `packages/`, or multiple `package.json`/`CLAUDE.md` files exist,
  inventory the harness at the root AND note per-package harness pieces.
- Record whether harness coverage is consistent across packages or concentrated
  at the root.

## ARTIFACT SAVE (mandatory)

Save the full inventory to: `reports/.artifacts/step_01_harness_inventory.md`
Run before finishing: `mkdir -p reports/.artifacts`

Output format (one block per piece):
- **Piece name**
- **Status**: Found / Not found / Partial
- **Evidence**: exact paths, line counts, frontmatter values, command excerpts
- **Notes**: anything the scoring step needs (e.g. "settings.json has hooks but
  no deny", "CLAUDE.md is 240 lines — over the 200 threshold")

End with a short **Harness Surface Summary**: which of the 7 pieces were located,
and the primary CLAUDE.md path + line count.
