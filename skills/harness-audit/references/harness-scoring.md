# Harness Scoring

> Apply the fixed 7-piece / 100-point rubric to the inventory evidence, compute
> the total harness score, and map it to a maturity band. Award points ONLY when
> the inventory provides concrete evidence that the criterion is met. This step
> computes numbers; it does not re-scan the repository.

---

Goal: Turn the inventory artifact into a defensible /100 harness score with a
per-piece breakdown and a maturity band.

INPUT:
- Read `reports/.artifacts/step_01_harness_inventory.md`. Every point awarded or
  withheld must trace back to evidence in that artifact. If the inventory is
  missing a piece's evidence, treat that piece as **Not found** and award 0 for
  it (never guess).

READ-ONLY DISCIPLINE:
- Do not modify the audited repository. If you must confirm a single ambiguous
  fact, use a read-only command (`grep`, `cat`, `wc`) — never a mutating one.

## THE RUBRIC (7 pieces, 100 points)

Each piece is all-or-nothing at the point value shown unless noted. Award the
full points only when the evidence proves the criterion; otherwise award 0 for
that piece.

### Piece 1 — CLAUDE.md exists — 10 pts

- **+10** if a `CLAUDE.md` is present at the repo root or under `.claude/`.
- **0** if no CLAUDE.md is found anywhere.

### Piece 2 — CLAUDE.md is real — +10 pts (only if Piece 1 scored)

- **+10** if the primary CLAUDE.md is **under 200 lines** AND contains **real
  build/test commands** (e.g. `npm run test`, `pytest`, `docker compose up`,
  `make lint`) AND documents **conventions** (branching, PR format, directory
  layout, layering rules, naming).
- **0** if it is 200 lines or longer, OR has no runnable commands, OR is just
  prose with no conventions. A bloated or command-free CLAUDE.md is context
  clutter, not a working harness piece.
- Piece 2 requires Piece 1; if Piece 1 is 0, Piece 2 is 0.

### Piece 3 — Rules — 10 pts

- **+10** if at least one `.claude/rules/*.md` has a `paths:` (or `globs:`)
  frontmatter scope that targets **stack-relevant files that actually exist**
  (e.g. `src/**/*.ts`, `apps/api/**`, `**/*.py`).
- **0** if `.claude/rules/` is absent, empty, or every rule is always-on with no
  path scope. Path scoping is what makes a rule load lazily and stay relevant;
  an unscoped rule does not satisfy this criterion.

### Piece 4 — Permissions — 15 pts

- **+15** if a **project** `.claude/settings.json` (checked into the repo, not
  only `settings.local.json`) contains a `permissions.deny` array that protects
  secrets — e.g. `Read(./.env)`, `Read(./.env.*)`, `Read(./secrets/**)`, or an
  equivalent credential-file deny.
- **0** if there is no project settings.json, no `deny` array, or the deny array
  does not cover secret/credential files. Allow-lists alone do not count — the
  criterion is specifically *denying* secret reads.

### Piece 5 — Commands / Skills — 15 pts

- **+15** if at least one invocable team procedure exists and encodes a real
  workflow — a `.claude/commands/*.md` or a `.claude/skills/*/SKILL.md` for
  deploy, review, release, ticket-to-PR, etc.
- **0** if there are no commands and no skills, or only empty stubs.

### Piece 6 — Hooks — 20 pts

- **+20** if a hook wired to **`PostToolUse`** or **`Stop`** in settings.json
  runs real automated validation — lint, format, typecheck, or tests (the hook
  `command` invokes something like `eslint`, `prettier`, `tsc`, `jest`,
  `pytest`, `vitest`, or a project script that does).
- **0** if there is no `hooks` block, hooks fire only on unrelated events, or the
  hook does no validation (e.g. only logs). `.husky/` git hooks are corroborating
  evidence but the primary criterion is the Claude Code hook; if the only
  validation is a `.husky/pre-push` that runs tests, award **+20** and note the
  mechanism in the evidence.

### Piece 7 — Agents — 10 pts

- **+10** if at least one custom agent under `.claude/agents/*.md` defines a real
  specialized role (reviewer, qa, tester, security, architect) with a
  `name:`/`description:`.
- **0** if `.claude/agents/` is absent or empty.

### Piece 8 — Autotest → PR — 10 pts

- **+10** if there is concrete evidence the agent can reach a **green PR on its
  own** — the full lifecycle is wired and enforced: tests run (locally and/or in
  CI), must be green, and a PR is opened/updated as part of the flow (e.g. CI
  runs tests on PRs AND a `ship`/`ticket-to-pr` procedure exists that closes the
  loop).
- **0** if the loop is not closed — tests exist but nothing enforces them on the
  PR, or there is no procedure that takes work to a PR automatically.

## SCORE COMPUTATION (execute before writing anything)

Step A — For each of the 8 rubric entries above, read the inventory evidence and
decide met / not-met. Record the awarded points and a one-line justification
citing the evidence path.

Step B — Compute the total:
```
total = p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8
```
(p2 is 0 unless p1 is 10.) The total is already on a 0–100 scale — do not
re-weight.

Step C — Map the total to a maturity band:
- **0–30 — No harness**: the model improvises; nothing is paved.
- **31–60 — Basic harness**: context exists (CLAUDE.md, rules) but enforcement
  does not (no deny permissions, no hooks, no gates).
- **61–85 — Solid harness**: context plus real enforcement; well supported with
  gaps.
- **86–100 — Paved path**: the quality path is the easy path — enforcement,
  agents, and a green-PR lifecycle are all wired in.

Step D — Classify each piece for the report table:
- **Present** (full points awarded)
- **Missing** (0 points; the piece is absent)
- **Weak** (0 points but the piece exists in a form that does not meet the
  criterion — e.g. CLAUDE.md over 200 lines, an unscoped rule, a hook that
  does not validate). Use "Weak" to distinguish "started but incomplete" from
  "never attempted" — this drives the action plan.

Step E — Identify the **top-3 highest-impact next steps**: rank the missing/weak
pieces by (points recoverable × enforcement value). Pieces that move the project
from context-only to enforced (Permissions, Hooks, Autotest→PR) generally
outrank additional context. Each next step must name the exact file to create or
edit and the concrete change.

REJECTION CRITERIA:
- If the inventory artifact is missing entirely, award 0 to every piece, set the
  band to "No harness", and note "Score: 0/100 — inventory artifact
  (step_01_harness_inventory.md) not found." Never fabricate evidence.

## ARTIFACT SAVE (mandatory)

Save the scoring result to: `reports/.artifacts/step_02_harness_scoring.md`
Run before finishing: `mkdir -p reports/.artifacts`

Output format:
- **Per-piece table**: piece name · criterion · status (Present/Weak/Missing) ·
  points awarded / max · one-line evidence justification.
- **Total Score**: `[total]/100`
- **Maturity Band**: name + one-sentence reading.
- **Top-3 Next Steps**: ranked, each naming the exact file and change and the
  points it recovers.
