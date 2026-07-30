# AI Harness & Adoption Analysis

> Score the project's AI harness — CLAUDE.md, `.claude/rules/`, `settings.json` permissions and hooks, `.claude/agents/`, commands/skills, the pre-push git hook, the documented lifecycle, and whether any of it is actually committed — on a 100-point rubric that judges **quality, not just presence**.

---

Goal: Produce a 0-100 score for the "AI Harness & Adoption" section of
the health audit, plus a maturity band and a prioritised action list
stating exactly how many points each action recovers.

THE CORE PRINCIPLE — NON-NEGOTIABLE:
Every dimension splits into EXISTENCE points and QUALITY points. A
harness that EXISTS but is HOLLOW MUST score badly. Existence is the
cheap half and is worth 28 of the 100 points; the quality half is worth
72 and is what discriminates a paved path from a repo that pasted a
CLAUDE.md once and never touched it again. A repo with one of
everything and quality in nothing scores 28 — it cannot reach the
61-point "harness sólido" band on existence alone, and it is nowhere
near the team's 85-point target. That ceiling is the rubric's whole
point.

THE SECOND PRINCIPLE — EXISTENCE IS AN ON-DISK TEST:
"Exists" means the file is on disk and non-empty. It does NOT mean the
file is committed. Whether the harness is versioned is scored exactly
once, in dimension 10, which is worth 12 points and carries a section
cap (Section 6). Never zero a dimension because a file is untracked or
gitignored — open it and score what it contains. A harness that exists
but is not shared is a real and serious finding with a one-line fix; it
is not the same finding as no harness at all, and this rubric must
never report the two as the same number.

Concretely, and this is the calibration target for the whole file:
- A 600-line untouched `/init` CLAUDE.md scores 7/13, not 13/13.
- A PostToolUse hook whose command is `echo "checked"` scores 5/14,
  not 14/14.
- An agent declared without a `model:` key forfeits its 4 quality
  points rather than scoring full marks for existing.
- A `settings.json` with a blanket `Bash(*)` allow and no `deny` scores
  4/13, not 13/13.
- A complete, well-built harness that `.gitignore` excludes scores 0/12
  on dimension 10 and is capped at 60 overall — not the ~14 it would
  score if tracking gated every dimension's existence.

If a check cannot be decided from file contents, it does NOT pass.
Never award quality points on the assumption that a file "probably"
does the right thing — open it, or score 0 and say why.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire analysis
- Batch-read `.claude/**` in parallel reads of 3-5 files per tool call
- Use ONE `git ls-files .claude .githooks` instead of per-file stats,
  and ONE `git check-ignore -v --no-index` for every path at once — both fold into
  the CALL 1 / CALL 2 pair in Section 3
- Do NOT read harness files one at a time
- Pipe long output through `| head -50` (rule bodies, hook scripts,
  `git ls-files` on a large tree)
- Reference cached artifacts from previous steps when available
- If the whole `.claude/` tree is under ~10 small files, read it in
  ONE parallel batch and do not re-read anything

────────────────────────────────────────────────────────────────────
SECTION 1 — SCOPE: WHAT COUNTS AS "THE HARNESS"
────────────────────────────────────────────────────────────────────

The harness is the project-level configuration that LIVES IN THE REPO
and is meant to apply to every teammate. That boundary — repo versus
home directory — decides what you score.

Note the boundary is location, not git status. Whether the in-repo
harness is actually committed is a QUALITY question, priced at 12
points in dimension 10, not a scope question. Everything below is in
scope whether or not `git ls-files` knows about it.

IN SCOPE (all paths relative to the repo root):
- `CLAUDE.md` at the repo root, or `.claude/CLAUDE.md`
- `.claude/rules/*.md`
- `.claude/settings.json` (permissions, hooks)
- `.claude/agents/*.md`
- `.claude/commands/*.md`
- `.claude/skills/<name>/SKILL.md` and its supporting files
- The pre-push git hook, by any mechanism (Section 5)
- Lifecycle documentation in `CLAUDE.md`, `README.md`,
  `CONTRIBUTING.md`, or packaged as a command/skill
- `AGENTS.md` — count it as an equivalent of root `CLAUDE.md` for
  dimension 1 if the project uses that convention instead

OUT OF SCOPE — never award points for these:
- `~/.claude/**` (personal, does not travel with the repo). A great
  personal harness is invisible to the team; that is the whole point.
  This is about LOCATION, not tracking: a file outside the repo can
  never be committed, so it is not a dimension 10 finding — it simply
  does not exist as far as this audit is concerned.
- `.claude/settings.local.json` (personal, per-machine overrides). Its
  existence never satisfies dimension 3's existence points.
- `CLAUDE.local.md` (personal notes)
- CI workflows under `.github/` — those are scored by the CI/CD
  section of this audit, not here. The pre-push hook IS in scope; the
  CI pipeline that runs the same gate is not.

IN SCOPE, AND THIS IS THE POINT PEOPLE GET WRONG — untracked files.
A `.claude/settings.json` that exists on disk but is not committed IS
scored: dimensions 1-9 read it and judge it on its contents, exactly as
if it were tracked. Not being committed costs dimension 10's 12 points
and triggers the Section 6 cap — once, visibly, with a one-line fix
attached. It does not silently zero the file's own dimension. An
untracked harness is a real harness with a distribution problem; a
missing harness is a different finding, and the report must be able to
tell a reader which one they have.

────────────────────────────────────────────────────────────────────
SECTION 2 — STACK-SPECIFIC VALUES
⚠️  THE ONLY SECTION THAT DIFFERS BETWEEN THE FOUR HEALTH-AUDIT SKILLS.
    Everything outside this section is stack-agnostic and MUST stay
    byte-identical across flutter / nestjs / python / react.
    Swap the two values below and nothing else.
────────────────────────────────────────────────────────────────────

| Value | This skill's value |
|---|---|
| Expected gate command (the project's lint/analyze/test one-liner) | `grunt test` (JSHint + Karma; equivalently `gulp test` or `npm test`) |
| Expected rule `paths:` glob (the stack's source tree) | `scripts/**/*.js` (or the app's real JS source tree: `app/**/*.js`, `src/**/*.js`) |

HOW THESE TWO VALUES ARE USED ELSEWHERE IN THIS FILE:
- "the expected gate command (Section 2)" — dimensions 4 and 5. It is
  the reference for what a REAL gate looks like in this stack, and the
  text you put in the remediation actions.
- "the expected rule glob (Section 2)" — dimension 2. It is the
  reference for what "scoped to the stack" means in this stack.

IMPORTANT — these are references, not exact-match requirements:
- A project that runs the same checks through its own wrapper (for
  example `./scripts/check.sh`, a `Makefile` target, or an npm script)
  is EQUIVALENT and scores full marks. Open the wrapper and confirm it
  reaches lint/analyze/test; score what the wrapper actually runs, not
  whether the string matches Section 2.
- A rule glob that is narrower or differently-shaped but still targets
  the stack's real source tree (for example a per-layer or per-package
  glob) is EQUIVALENT and scores full marks. What fails is a glob that
  matches everything (`**/*`), matches nothing that exists in the repo,
  or is absent.
- Never report "the gate command does not match `grunt test`" as
  a finding. The finding is "the hook runs no gate", or nothing.

────────────────────────────────────────────────────────────────────
SECTION 3 — EVIDENCE GATHERING (THE ≤8 CALL PLAN)
────────────────────────────────────────────────────────────────────

Follow this order. It is built to answer every rubric check in ≤8
calls, and to make the git-tracking checks (which several dimensions
depend on) cost one call total.

CALL 1 — tracking in one shot:
```
git ls-files .claude .githooks CLAUDE.md AGENTS.md CLAUDE.local.md | head -50
```
`git ls-files` lists tracked files only. This call answers exactly one
question — what is COMMITTED — and it feeds exactly one dimension: 10.
It does NOT decide whether a harness piece exists; CALL 2 does that.
Keep the two ideas apart, because conflating them is the failure this
rubric was rewritten to prevent (Section 4.11).

CALL 2 — on-disk reality + ignore status + hook mechanisms + sizes:
```
ls -la .claude .claude/rules .claude/agents .claude/commands .claude/skills 2>/dev/null | head -50; \
wc -l CLAUDE.md .claude/rules/*.md 2>/dev/null | head -20; \
git check-ignore -v --no-index .claude .claude/settings.json .claude/agents .claude/rules CLAUDE.md 2>/dev/null; \
grep -n 'claude\|CLAUDE' .gitignore 2>/dev/null; \
git config --get core.hooksPath; \
ls -la .git/hooks/pre-push .githooks/pre-push .husky/pre-push lefthook.yml .pre-commit-config.yaml 2>/dev/null
```
This answers what EXISTS (every dimension's existence check), dimension
1's line count, dimension 2's rule sizes, dimension 10's ignore status,
and the whole of Section 5's detection table.

`git check-ignore -v --no-index` is the call that makes dimension 10
measurable. It prints `<gitignore-file>:<line>:<pattern>	<path>` for
each ignored path and nothing for the rest, so it names the exact line
to delete in the remediation. Three properties matter:
- It reports an ignore RULE MATCH, which is independent of tracking.
- `--no-index` IS LOAD-BEARING, not optional. Without it, `git
  check-ignore` deliberately stays silent for any path that is already
  tracked — which would hide the grandfathered case in 4.11 completely,
  the one case `git ls-files` also cannot see. `--no-index` makes the
  match report on the `.gitignore` pattern alone, tracked or not.
- It exits 1 when nothing matches. That is the healthy result, not an
  error, and it does not false-positive on a clean repo. `2>/dev/null`
  and the `;` chaining keep it from aborting the compound command.
Cross-read CALL 1 against CALL 2: files listed by `ls` but absent from
`git ls-files` are untracked. That distinction scores dimension 10 —
and, per Section 4, nothing else.

CALL 3-5 — batch-read the harness (3-5 files per call, parallel):
- `CLAUDE.md` + `.claude/settings.json` + every `.claude/rules/*.md`
- every `.claude/agents/*.md` (frontmatter is what matters — if there
  are many agents, `head -20` each via one Bash call instead)
- every `.claude/commands/*.md` + each `SKILL.md`
- the pre-push hook body + any hook script referenced from
  `settings.json`

CALL 6 — resolve hook and pre-push script bodies you have not read
yet. This is MANDATORY and is the single most important call in the
analysis: dimension 4's +7 and dimension 5's +3 cannot be scored from
`settings.json` alone. If a hook's command is `./scripts/check.sh`,
`settings.json` tells you nothing about whether that script is a real
gate or an `echo`. Read the script.

CALL 7 — lifecycle + enable-step documentation, one grep:
```
grep -rniE 'plan|autotest|review|pull request|pr |core\.hooksPath|lefthook install|husky' \
  README.md CONTRIBUTING.md CLAUDE.md .githooks/README.md docs/ 2>/dev/null | head -30
```

CALL 8 — the Write of the artifact.

If any call is unnecessary (no `.claude/` at all, no hooks to resolve),
skip it. Under-spending the budget is always correct; over-spending it
is not.

────────────────────────────────────────────────────────────────────
SECTION 4 — THE RUBRIC: 100 POINTS ACROSS 10 DIMENSIONS
────────────────────────────────────────────────────────────────────

4.1 OVERVIEW

| # | Dimension | Pts | Existence | Quality (the discriminating half) |
|---|---|---:|---|---|
| 1 | CLAUDE.md | 13 | exists on disk, non-empty (5) | <200 lines, real build/test commands, non-deducible conventions (+8). >400 lines, or generic untouched `/init` boilerplate → quality capped at 2 |
| 2 | Rules | 9 | ≥1 in `.claude/rules/` (3) | ≥1 with `paths:` frontmatter scoped to the stack (+4); dense, not duplicating CLAUDE.md (+2) |
| 3 | Permissions | 13 | project `settings.json` on disk (4) | `deny` of secrets — `.env*`, keystores, PII (+6); `allow` scoped, not blanket `Bash(*)` (+3) |
| 4 | Hooks | 14 | ≥1 hook configured (5) | PostToolUse/Stop runs a **real gate** (lint/test/analyze), not `echo`/no-op (+6); script in-repo + `timeout` set (+3) |
| 5 | Pre-push git hook | 11 | pre-push exists, any mechanism (4) | **versioned** in the repo, not only `.git/hooks/` (+4); runs a real gate + enable step documented (+3) |
| 6 | Agents | 11 | ≥1 custom agent (3) | **every agent declares `model:`** (+4); scoped `tools:` (+2); trigger-shaped `description:` (+2) |
| 7 | Commands / Skills | 9 | ≥1 invocable team procedure (4) | skill with progressive disclosure, or command with `argument-hint` (+5) |
| 8 | Advanced orchestration | 5 | — | graduated: subagent delegation, `isolation: worktree`, loops / scheduled automation |
| 9 | Lifecycle | 3 | — | documented plan→impl→autotest→review→PR procedure |
| 10 | **Harness versioning** | 12 | — | graduated: is the harness on disk actually COMMITTED, and does `.gitignore` exclude it (Section 4.11) |
| | **Total** | **100** | | |

Existence subtotal: 28 (5+3+4+5+4+3+4+0+0+0). Quality subtotal: 72
(8+6+9+9+7+8+5+5+3+12). A repo that has one of everything and quality
in none of it lands at exactly 28. Add a committed harness (dimension
10's full 12) and it reaches 40 — "harness básico — contexto sí,
enforcement no". That is the intended reading, not a bug in the rubric:
the band's own name describes precisely that repo.

⚠️ EXISTENCE IS AN ON-DISK TEST. THE WHOLE RUBRIC TURNS ON THIS.
Dimensions 1-8 ask ONLY: is the file on disk, and is it any good?
Whether it is committed is scored ONCE, in dimension 10, and nowhere
else. Never zero a dimension because a file is untracked or gitignored
— read the file and score what it contains.

The reason is diagnostic, not generous. When tracking gated every
existence check, a repo with a real CLAUDE.md, real hooks and real
agents that happened to gitignore `.claude/` scored the same ~14 as a
repo with no harness at all, and the action list told the team to
"create a CLAUDE.md" they had already written. One `.gitignore` line
cost up to 85 points, silently, through seven dimensions. It is now one
row worth 12 points, plus the Section 6 cap — visible, bounded, and
attached to the one-line fix that recovers it.

This does NOT soften the thesis that an uncommitted harness is not team
harness. Section 6 caps the section at 60 while nothing is tracked, so
such a repo can never be called "harness sólido". The rubric now says
"you built it, you just have not shared it" — which is true, and
actionable — instead of "you have nothing", which was false.

4.2 DIMENSION 1 — CLAUDE.md (13)

EXISTENCE (5): a `CLAUDE.md` at the repo root, or `.claude/CLAUDE.md`,
or `AGENTS.md`, exists on disk AND is non-empty.
- Untracked or gitignored → still 5, and score its quality normally.
  Tracking is dimension 10's job. Note the fact in Evidence.
- Personal `~/.claude/CLAUDE.md` → 0. It is outside the repo entirely
  (Section 1) — that is a different failure from "not committed".
- Empty or whitespace-only → 0.

QUALITY (+8), three independent tests:

| Test | Pts | Pass condition | Fail condition |
|---|---:|---|---|
| 1a Length | +3 | `wc -l` < 200 | ≥ 200 lines |
| 1b Real commands | +3 | Contains ≥1 verbatim, runnable build/test command, AND that command is verified to exist in the repo (an npm script in `package.json`, a target in `Makefile`, a script file on disk, or the stack's standard toolchain invocation) | No command at all; or commands that do not resolve to anything in this repo (invented, or copied from another project) |
| 1c Non-deducible conventions | +2 | Contains ≥2 statements a competent engineer could NOT deduce by reading the code | Only restates what the code says |

TEST 1c — HOW TO JUDGE "NON-DEDUCIBLE". This is the test most often
scored wrong. Ask: *could I derive this sentence by reading the source
tree for five minutes?* If yes, it is deducible and worth nothing.
- DEDUCIBLE (no credit): "This project uses <framework>." "The `src/`
  directory contains the source code." "Components live in
  `components/`." A directory tree. A list of dependencies.
- NON-DEDUCIBLE (credit): exact commands and their preconditions;
  prohibitions ("no new dependencies without human approval"); layer
  boundaries with a reason ("business logic goes in the service, never
  the controller"); the definition of done ("no logic change is
  finished without passing tests"); known traps; conventions with no
  trace in code yet ("user-visible strings in Spanish").

QUALITY CAP — apply BEFORE summing 1a/1b/1c. If either condition
below holds, quality is capped at 2 (so the dimension scores at most
7/13) regardless of the tests above:

CAP CONDITION A — bloat: `wc -l CLAUDE.md` > 400.
  Rationale: every line is paid in tokens in every session. A 600-line
  CLAUDE.md is the "basural" anti-pattern — the model's attention is
  proportional to how short and specific the file is.

CAP CONDITION B — untouched `/init` boilerplate. ALL THREE must hold:
  - the file is dominated (≳80% of non-empty lines) by content that is
    deducible from the code: directory listings, framework
    descriptions, restated dependency lists; AND
  - it contains ZERO commands that resolve to something in this repo
    (test 1b fails); AND
  - it contains ZERO prohibitions, conventions, or definition-of-done
    statements (test 1c fails).
  If all three hold, the file is a generated inventory, not a
  constitution. Cap at 2.
  Do NOT infer "boilerplate" from the mere presence of headings like
  "## Project Overview" or "## Development Commands" — a well-tended
  CLAUDE.md often keeps `/init`'s skeleton. Judge the CONTENT under
  the headings.

Note the cap is not redundant with the tests: a 500-line file that
does document real commands would otherwise score 5/8 on 1b+1c; the
cap drops it to 2. Bloat is a defect on its own.

4.3 DIMENSION 2 — RULES (9)

EXISTENCE (3): ≥1 non-empty `.md` file in `.claude/rules/` on disk.
Tracking is dimension 10's job — do not test it here.
`~/.claude/rules/` never counts (Section 1).

QUALITY (+4) — SCOPED `paths:`:
Award 4 if ≥1 rule has YAML frontmatter with a `paths:` key whose
glob(s) target the stack's real source tree — see "the expected rule
glob (Section 2)" and its EQUIVALENCE note.
Award 0 if:
- no rule has frontmatter at all. A rule without `paths:` loads on
  EVERY session — it is CLAUDE.md split across files, which is the
  exact cost problem `paths:` exists to solve. No points.
- the only globs are `**/*` or `*` (matches everything → same
  always-loaded cost, no scoping).
- the glob matches no file that exists in the repo (verify with Glob;
  a rule scoped to a directory the project does not have is dead
  weight and a real finding).

QUALITY (+2) — DENSE, NOT DUPLICATING CLAUDE.md:
Award 2 only if BOTH hold:
- every rule file is < 100 lines; AND
- no rule substantially restates CLAUDE.md. Test: take each rule's
  substantive instruction lines; if ≳30% of them state the same
  instruction as a line already in CLAUDE.md, the rule is duplication.
  Duplicated instruction = paid twice in tokens, and drifts the moment
  one copy is edited.
Award 0 if either fails. Do not award 1.

4.4 DIMENSION 3 — PERMISSIONS (13)

EXISTENCE (4): `.claude/settings.json` exists on disk and parses.
- On disk but untracked or gitignored → still 4, and score its `deny`
  and `allow` normally. Tracking is dimension 10's job; record the fact
  in Evidence and let dimension 10 charge for it once.
- `.claude/settings.local.json` alone → 0. This is NOT a tracking
  judgement and dimension 10 does not rescue it: `settings.local.json`
  is by design personal, per-machine config (Section 1). The project
  file is `settings.json`, and it does not exist. The two files mean
  different things — one laptop's preferences versus the team's policy.

QUALITY (+6) — `deny` OF SECRETS (graduated):
First, inventory what this repo actually has to protect. Look for
(Glob, one call, do not read them): `.env*`, `**/*.jks`, `**/*.keystore`,
`**/*.p12`, `**/*.pem`, `**/*.key`, service-account JSON, and any
committed data file plausibly holding PII or business-confidential
data. Then compare against `permissions.deny`.

| Condition | Pts |
|---|---:|
| `deny` covers EVERY sensitive artifact present in the repo, via `Read(...)` (and ideally `Edit(...)`) entries | 6 |
| `deny` covers env files but misses other sensitive artifacts that exist in this repo (keystores, PII dumps) | 3 |
| `permissions.deny` absent, empty, or denies only things this repo does not have | 0 |

Scoring notes:
- A repo with genuinely nothing sensitive still needs the baseline
  `Read(.env*)` / `Edit(.env*)` deny to score 6 — it is the guard
  against the secret that gets added next month.
- `.gitignore` is NOT a substitute and earns nothing here. Claude Code
  does not respect `.gitignore` for tool access; the file being
  gitignored is exactly why it is still on disk and readable.
- A warning in CLAUDE.md ("don't read the PII file") is NOT a
  substitute and earns nothing. That is persuasion; `deny` is physics.
  If you find the warning and no deny, that is a Key Finding worth
  stating: the project believes it is protected and is not.

QUALITY (+3) — `allow` SCOPED, NOT BLANKET (graduated):

| Condition | Pts |
|---|---:|
| Every `allow` entry is bounded to a specific command with narrowed arguments — `Bash(npm run test*)`, `Bash(./scripts/check.sh)` | 3 |
| Entries are tool-scoped wildcards — `Bash(npm *)`, `Bash(git *)` — bounded to a binary but not to a subcommand | 2 |
| No `allow` list, or an empty one | 1 |
| Any entry is a blanket wildcard: `Bash(*)`, `Bash(:*)`, or equivalent | 0 |

The blanket case scores 0 for the whole test even if other entries are
tight — one `Bash(*)` subsumes them all. The empty-allow case scores 1,
not 0: nothing dangerous was granted, but no paved path was built
either, so every command still stops for approval and the lifecycle
cannot run unattended.

4.5 DIMENSION 4 — HOOKS (14)

EXISTENCE (5): `.claude/settings.json` has a `hooks` key with ≥1 event
containing ≥1 matcher with a non-empty `command`. On-disk test — an
untracked `settings.json` still earns this; see dimension 10.

QUALITY (+6) — A REAL GATE, NOT AN `echo`. This is the single most
discriminating test in the rubric. It has two parts:

  4a — THE GATE IS INVOKED (+4). A `PostToolUse` hook (matcher
  covering `Edit`/`Write`/`MultiEdit`) or a `Stop` hook whose command,
  followed to its end, actually runs lint / test / analyze / format /
  typecheck.
  MANDATORY: if the command points at a script (`./scripts/check.sh`,
  `make check`, an npm script), READ THE SCRIPT — or the `Makefile`
  target, or the `package.json` script. `settings.json` cannot answer
  this question. Award 4 only when you have seen the gate invocation
  with your own eyes.
  Award 0 if:
  - the command is `echo ...`, `true`, `:`, a `printf`, a notification
    (`say`, `osascript`, a webhook ping), or a log append — it runs,
    it succeeds, it checks nothing;
  - the command only formats (`dart format`, `prettier --write`) with
    no lint/analyze/test — formatting is not a gate, it cannot fail
    meaningfully;
  - the referenced script does not exist on disk (a dangling hook is a
    no-op that also fails silently);
  - the hook exists only on events that cannot gate an edit —
    `SessionStart`, `UserPromptSubmit`, `Notification`, `PreToolUse` on
    a read-only tool;
  - the matcher matches no tool that writes code.

  4b — FAILURE ACTUALLY BLOCKS (+2). The gate's non-zero exit
  propagates to Claude Code. Award 2 only if the command/script exits
  non-zero on failure.
  Award 0 if the failure is swallowed: a trailing `|| true`, a final
  `exit 0`, a pipeline that ends in a command that always succeeds
  (`... | tee log`, `... ; echo done`) with no `set -o pipefail` and no
  exit-code check, or a script that captures the output and prints it
  without checking `$?`.
  THIS IS THE HOLLOW-HARNESS TEST. A hook that runs the full test suite
  and then exits 0 regardless is theatre: it burns time on every edit
  and enforces nothing. It scores 4, not 6, and the missing 2 points
  must appear in the action list with the exact line to change.

QUALITY (+3) — IN-REPO + BOUNDED:
- +2 — the hook's script lives INSIDE the repo and the command uses a
  repo-relative path. Award 0 for an absolute path outside the repo
  (`/Users/<name>/bin/check.sh`, `~/scripts/...`) — that hook works on
  exactly one machine and is not team harness. This is a path test, not
  a tracking test: a script at `scripts/check.sh` that is untracked
  still earns these 2 points, and dimension 10 charges for the tracking
  once. A fully inline command (no script file) scores 2 if short,
  self-contained, AND already credited under 4a (a real gate, not
  `echo`/`true`/a no-op) — it is carried by `settings.json` itself. A
  no-op/echo command earns 0 here regardless of being inline and short:
  an inline command that gates nothing is not "harness", it is noise.
  (This is why the `echo "checked"` calibration example above scores
  5/14 — existence 5, gate 0, in-repo 0 — not 7/14.)
- +1 — `timeout` is set on the hook entry. Award 0 if absent. Note the
  unit is SECONDS, not milliseconds; a `timeout` of `60` is 60s and is
  a reasonable value, not a bug. Do not flag a plausible timeout as
  wrong.

4.6 DIMENSION 5 — PRE-PUSH GIT HOOK (11)

EXISTENCE (4): a pre-push hook exists by ANY mechanism in Section 5's
detection table. Mechanism-agnostic — a working lefthook setup is worth
exactly as much as a `.githooks/` setup.

QUALITY (+4) — VERSIONED: award 4 for every mechanism in Section 5
except the bare `.git/hooks/pre-push` row. `.git/` is not committed and
not cloneable: that hook protects its author and nobody else, which is
why it forfeits these 4 points while still earning the existence 4.
This is the ONE versioning test that does NOT move to dimension 10, and
the exception is structural, not an inconsistency: `.git/hooks/` is not
merely uncommitted, it is UNCOMMITTABLE. No `git add` can fix it — the
remedy is to move the file to a different path. Dimension 10 scores the
`.claude/` harness, whose fix is a commit; this scores a location whose
fix is a move. Two different findings, two different actions.

QUALITY (+3):
- +2 — the hook body runs a real gate. Apply the SAME test as 4a: read
  the body; it must reach lint / test / analyze / coverage. A pre-push
  that only checks the branch name, prints a reminder, or runs
  `exit 0` earns 0 here.
- +1 — the one-time enable step is documented (README, CONTRIBUTING,
  CLAUDE.md, or `.githooks/README.md`) OR automated so no human step
  exists (a husky `prepare` script, `lefthook install` wired into
  postinstall). An undocumented, non-automated `core.hooksPath` setup
  is a hook that only the person who configured their local git ever
  runs — the file is in the repo and the enforcement is not.

4.7 DIMENSION 6 — AGENTS (11)

EXISTENCE (3): ≥1 `.md` in `.claude/agents/` on disk, with YAML
frontmatter carrying at least a `name`. Tracking is dimension 10's job.

QUALITY (+4) — EVERY AGENT DECLARES `model:` — ALL OR NOTHING:
This is the rubric's originating example and it is deliberately
unforgiving. Award 4 only if 100% of the agent files declare a `model:`
key in frontmatter. Otherwise award 0.
- Five agents, four with `model:` → **0 of 4**, not 3.2. Do not
  pro-rate. Do not round up. Do not award partial credit for "most".
- Rationale: an agent with no `model:` silently inherits the session's
  model. Every dispatch to it is a cost and quality decision nobody
  made. One undeclared agent is enough to make the fleet's routing
  unintentional, which is why the test is all-or-nothing.
- The action text MUST name the offending files, e.g. "`reviewer.md`
  and `qa.md` have no `model:` key" — naming them is what makes the
  +4 recoverable in one commit.

QUALITY (+2) — SCOPED `tools:`:
| Condition | Pts |
|---|---:|
| Every agent declares a `tools:` allowlist | 2 |
| Some agents declare it, others omit it | 1 |
| No agent declares it | 0 |
An agent with no `tools:` key inherits every tool the session has —
including write and execute tools a read-only reviewer has no business
holding. Note: an agent whose `tools:` lists literally everything is
not scoped; treat it as omitted.

QUALITY (+2) — TRIGGER-SHAPED `description:`:
A description is trigger-shaped when it states WHEN to use the agent
("Use this agent when …"), not merely what it is ("Code reviewer.").
The description is the only part always in context and is what the
model matches against to decide dispatch; a description that does not
describe a trigger produces an agent that never fires.
| Condition | Pts |
|---|---:|
| Every agent's description states a trigger condition (bonus signal: `<example>` blocks) | 2 |
| Some do | 1 |
| None do, or descriptions are one-word/absent | 0 |

4.8 DIMENSION 7 — COMMANDS / SKILLS (9)

EXISTENCE (4): ≥1 invocable team procedure on disk — a
`.claude/commands/*.md`, or a `.claude/skills/<name>/SKILL.md`.
Non-empty; the file body must be an actual procedure, not a stub.
Tracking is dimension 10's job.

QUALITY (+5), two tests:
- +3 — PROGRESSIVE DISCLOSURE or `argument-hint`. Award 3 if EITHER:
  * a skill practises progressive disclosure: `SKILL.md` has a
    frontmatter `description`, and the body delegates to ≥1 supporting
    file (reference, checklist, script) that is read only when needed —
    so the always-on context cost is one line, not the whole procedure;
    OR
  * a command declares `argument-hint` in frontmatter (it is
    parameterised and self-documenting at the call site).
  Award 0 for a single flat file with no frontmatter and no supporting
  files.
- +2 — THE PROCEDURE IS PROJECT-SPECIFIC AND EXECUTABLE. It names this
  project's real commands, paths, or gate (Section 2 or its
  equivalent). Award 0 for generic prose that would apply unchanged to
  any repo ("review the code carefully, follow best practices") — that
  is not a team procedure, it is a wish.

4.9 DIMENSION 8 — ADVANCED ORCHESTRATION (5)

No existence points — this dimension is entirely graduated. It covers
the topics beyond the codelab's own rubric: agents, subagents,
worktrees and loops. Award each independently and sum. The three are
not worth the same: they are ordered by leverage, and loops are worth
1 because they are the narrowest win of the three and the last thing a
team should reach for.

| Capability | Pts | Evidence that counts |
|---|---:|---|
| Subagent delegation | +2 | A command, skill, or agent that dispatches work to other agents: `Task` in an `allowed-tools`/`tools:` list, an orchestrator agent, an explicit dispatch table, or a documented wave/parallel plan |
| Worktree isolation | +2 | `isolation: worktree` declared on an agent or command, or a documented git-worktree workflow for running agents in parallel without stepping on the working tree |
| Loops / scheduled automation | +1 | A scheduled or recurring agent (cron/routine), a self-iterating loop command, or a chained automation driven by `SessionStart`/`Stop` hooks that goes beyond a single gate |

Scoring notes:
- Score DECLARED capability, not aspiration. Prose in CLAUDE.md saying
  "we should use worktrees" earns 0. A key in frontmatter earns 2.
- A repo at 0/5 here is normal and is NOT a Risk. Say so plainly:
  this dimension is headroom above a solid harness, and it is the last
  place to spend effort. Never let 0/5 here drive a Risk entry — the
  action list will naturally sort it last, which is correct.
- Do not double-count with dimension 7: a skill earns its dimension-7
  points for being an invocable procedure, and earns here only if it
  additionally delegates, isolates, or loops.

4.10 DIMENSION 9 — LIFECYCLE (3)

No existence points. This dimension is now only the documented
procedure; the versioning half moved out to dimension 10, where it is
measured properly and priced at 12.

QUALITY (3) — DOCUMENTED LIFECYCLE: the plan → implementation →
autotest → review → PR procedure is written down (CLAUDE.md, README,
CONTRIBUTING, docs/) or packaged as a command/skill that executes it.
| Condition | Pts |
|---|---:|
| All five stages documented or packaged | 3 |
| ≥3 of the five stages | 2 |
| Fewer than 3, or only a passing mention ("we use PRs") | 0 |

4.11 DIMENSION 10 — HARNESS VERSIONING (12)

This is the dimension that decides whether everything above is TEAM
harness or one laptop's private setup. It is the ONLY place tracking is
scored. Dimensions 1-8 have already scored the harness on its merits;
this one asks the separate question: does anyone else have it?

Evidence: CALL 1 (`git ls-files`) crossed with CALL 2 (`ls -la` and
`git check-ignore -v --no-index`). Scope: `.claude/**` plus the dimension-1 file
(`CLAUDE.md` / `AGENTS.md`). Exclude from the scope, always:
`.claude/settings.local.json` and `CLAUDE.local.md` — they are personal
by design (Section 1) and are SUPPOSED to be untracked. Their absence
from `git ls-files` is correct and must never cost a point here.

| Condition | Pts |
|---|---:|
| Every in-scope harness file on disk is tracked, AND `git check-ignore` reports nothing for `.claude` or the CLAUDE.md file | 12 |
| Every in-scope harness file is tracked, BUT `.gitignore` carries a pattern matching `.claude` — tracked files survive by grandfathering while every NEW harness file is silently ignored | 8 |
| Partial: some in-scope harness files tracked, others untracked or ignored | 5 |
| Harness exists on disk but NOTHING in scope is tracked — gitignored, or never `git add`ed | 0 |
| No harness on disk at all (nothing to version) | 0 |

THE GRANDFATHERED CASE (8) — this is the row that only exists because
of `git check-ignore`, and it is a real trap, not a technicality. Once
`.claude/` matches a `.gitignore` pattern, files ALREADY tracked keep
being tracked, so `git ls-files` looks perfectly healthy and the repo
scores as if versioned. But the next agent, rule or hook someone adds
is silently never staged: `git add .claude/agents/new.md` fails without
an error anyone reads, and `git status` never mentions it. The harness
quietly stops growing for the team while it keeps growing on one
laptop. Award 8, and make it a Key Finding with the exact
`<file>:<line>` that `git check-ignore -v --no-index` printed.

SCORING NOTES:
- 0 here is the loudest finding this rubric can produce short of an
  empty repo. Lead Key Findings with it, and state both halves of the
  truth plainly: the harness is real and was scored on its merits
  (quote the dimension 1-8 subtotal), AND nobody else has it, so the
  section is capped at 60 by Section 6 until one commit lands.
- The fix is genuinely one or two lines, which is what makes this the
  highest-leverage action in the report. Name them exactly:
  `.gitignore` line N (from `git check-ignore -v --no-index`), then
  `git add .claude CLAUDE.md`. If files were tracked and then ignored,
  the pattern is the only thing to remove.
- Do NOT charge for this twice. If dimension 10 scores 0 or 8, no other
  dimension may deduct anything for tracking. Read Section 4.1's
  warning again if you are tempted.
- `.claude/settings.local.json` as the ONLY thing on disk is not a
  harness at all: dimensions 1-8 score it 0 on their own terms, and
  this dimension scores 0 for "no harness on disk", not for tracking.

────────────────────────────────────────────────────────────────────
SECTION 5 — PRE-PUSH DETECTION (DIMENSION 5)
────────────────────────────────────────────────────────────────────

Accept ANY of the following, checked in this precedence order. Stop at
the first mechanism that matches and score that one; do not penalise a
project for using a mechanism other than the one you expected.

| Mechanism | Detection | Versioned? |
|---|---|---|
| `.githooks/pre-push` + `git config core.hooksPath` | file exists AND `git config --get core.hooksPath` resolves | yes → full points |
| `.husky/pre-push` | file exists | yes |
| `lefthook.yml` with a `pre-push:` block | key present | yes |
| `.pre-commit-config.yaml` with `stages: [push]` | key present | yes |
| `.git/hooks/pre-push` only | file exists, executable | **no** → loses the +4 "versioned" points |

Then judge quality (dimension 5's +3): does the hook body actually
invoke a gate (tests / lint / analyze / coverage), or is it a stub? Is
the one-time enable step documented (README or CLAUDE.md)?

Detection notes:
- `.githooks/pre-push` present but `core.hooksPath` NOT set: the hook
  is versioned and correct but nothing runs it. Score existence 5 and
  the versioned +4, but the enable-step +1 is 0 and this is a Key
  Finding — the repo looks protected and is not. The action is a
  one-liner: `git config core.hooksPath .githooks`.
- `lefthook.yml` / `.pre-commit-config.yaml`: confirm the `pre-push` /
  `stages: [push]` key specifically. A `pre-commit`-only config does
  not satisfy this dimension.
- Multiple mechanisms present: score the highest-precedence one that
  is actually wired up. Note the redundancy as a finding, not a
  penalty.

> Reference implementation for the report's remediation text: this
> repo's own `.githooks/pre-push` + `.githooks/README.md` (per-file 85%
> coverage gate, `COVERAGE_MIN` override, `--no-verify` escape hatch).

────────────────────────────────────────────────────────────────────
SECTION 6 — SCORE, LABEL AND MATURITY BAND
────────────────────────────────────────────────────────────────────

The rubric total IS the section score: both are 0-100, so no scaling
is needed. Sum the ten dimensions, apply the cap below, and report the
integer.

THE UNVERSIONED CAP — apply AFTER summing, BEFORE mapping the band and
the label:

  IF dimension 10 scored 0, the section score is min(sum, 60).

That is the exact ceiling of the "harness básico" band. The cap encodes
the rubric's thesis: a harness nobody else has cannot be called
"sólido", no matter how good it is on the one machine that has it. It
never applies at 5, 8 or 12 on dimension 10 — a partially-tracked
harness is a real, shared harness with gaps, and the gaps are already
priced.

Report the cap explicitly when it bites. State the uncapped sum, the
cap, and the reason, in one line inside the section body:

  "Score: 60/100 (capped — dimensions 1-9 sum to 74, but `.claude/` is
  excluded by `.gitignore:12`, so dimension 10 scores 0 and Section 6
  caps the section at 60 until the harness is committed.)"

Never silently emit the capped number. A reader who cannot see the 74
cannot see that one commit is worth 26 points, and that is the whole
finding.

MATURITY BANDS (from the codelab, Appendix A) — reported inside the
section body:

| Band | Meaning |
|---|---|
| 0–30 | sin harness — el modelo improvisa |
| 31–60 | harness básico — contexto sí, enforcement no |
| 61–85 | harness sólido |
| 86–100 | paved path — el camino de calidad es el camino fácil |

SECTION LABEL — reported in the audit's §2 scorecard row, using the
audit's existing scale so the table stays uniform:
- 85-100 = Strong
- 70-84 = Fair
- 0-69 = Weak

Both are reported. The label keeps the scorecard consistent with the
other eight sections; the maturity band is the language the team
actually uses, and 86 is the 30-day target ("paved path").

Do NOT apply subjective adjustments to the total. If a dimension feels
harsh, that is the rubric working — the adjustment belongs in the
action list, not the arithmetic. The Section 6 cap is not a subjective
adjustment: it is a stated rule with one trigger, and it is the only
adjustment permitted.

────────────────────────────────────────────────────────────────────
SECTION 7 — BUILDING THE ACTION LIST
────────────────────────────────────────────────────────────────────

This is the deliverable the team acts on, and it is what the
requirement asks for explicitly: what is covered, the score, and the
list of actions with an explanation of what to do to raise it.

RULES:
1. SORT BY POINTS RECOVERED, DESCENDING. Not by dimension order, not
   by ease. The team is aiming at 85; the list must tell them the
   shortest path there.
2. EVERY action opens with its delta in brackets: `[+14]`.
3. EVERY action ends with `→ dimension D, X/Y → Y/Y` — the dimension
   number, the current sub-score, and the sub-score after the fix.
4. The how-to must be CONCRETE and specific to THIS repo: the file to
   create or edit, the key to add, the command to run. A reader must be
   able to execute it without re-deriving anything.
   - Good: "Create `scripts/check.sh` running <the gate command from
     Section 2> and exit 2 on failure, then register it as a
     PostToolUse hook matching `Edit|Write` with `timeout: 60` in
     `.claude/settings.json`."
   - Bad: "Improve hook coverage."
5. One action per recoverable block of points. Do not bundle two
   dimensions into one action — it makes the delta unverifiable at
   re-measure time.
6. Partial recoveries get their own entry. If dimension 4 sits at
   9/14 because failure is swallowed, the action is `[+2] Propagate
   the gate's exit code` with the exact line to change — not a vague
   "strengthen the hook".
7. Only list actions that recover points. If a dimension is at full
   marks, it does not appear.
8. State the total at the end: current score, score if every action
   lands, and whether that clears 85.
9. WHEN THE SECTION 6 CAP IS ACTIVE (dimension 10 scored 0), the
   versioning action goes FIRST regardless of the sort, because until
   it lands, no other action can raise the reported score at all — the
   cap absorbs them. Give it the COMBINED delta it actually recovers:
   dimension 10's 12 points plus everything the cap was withholding.
   - Format: `[+26] Commit the harness.` … `→ dimension 10, 0/12 →
     12/12; lifts the Section 6 cap, 60 → 74.`
   - Then add one line under the list: "Every action below assumes the
     harness is committed first; while it is not, the section stays at
     60 no matter what else lands."
   - The remaining actions keep their own honest per-dimension deltas.
     Do NOT restate them net of the cap — the arithmetic must still
     reconcile against the uncapped sum, which is what rule 8 and the
     verification checklist check.

────────────────────────────────────────────────────────────────────
SECTION 8 — OUTPUT FORMAT
────────────────────────────────────────────────────────────────────

Write the artifact to the exact path your invoker gave you:

- Via `somnio run`: the step prompt names the path ("Save your
  complete findings to: ..."). Use it verbatim.
- Via in-session dispatch: use the path in this skill's Dispatch Table
  in SKILL.md.

Create the parent directory first. Never invent, shorten, or re-derive
the path.

The report section this artifact feeds is richer than the audit's
standard 5-subsection block. Produce exactly this shape so the
report-writer can lift it with minimal transformation:

```markdown
## 11. AI Harness & Adoption

**Description:** [one sentence]
**Score:** [N]/100 ([Label])          ← if the Section 6 cap bit, say so
                                        here: "60/100 (capped — see below)"
**Maturity:** [sin harness | harness básico | harness sólido | paved path]

### Coverage
| Dimension | Status | Points |
|---|---|---|
| CLAUDE.md | Present — 142 lines, build/test commands documented | 13/13 |
| Rules | 2 rules, 1 with `paths:` scoped to <the stack glob> | 9/9 |
| Permissions | settings.json present, no deny of secrets | 7/13 |
| Hooks | None configured | 0/14 |
| Pre-push git hook | Missing | 0/11 |
| Agents | 3 agents, 2 without `model:` | 7/11 |
| Commands / Skills | 1 command, no argument-hint, generic prose | 4/9 |
| Advanced orchestration | No subagent/worktree/loop usage found | 0/5 |
| Lifecycle | No documented plan→PR procedure | 0/3 |
| Harness versioning | `.claude/` fully tracked, not ignored | 12/12 |
| **Total** | | **52/100** |

### Key Findings
### Evidence                    ← real file paths only, never invented
### Risks

### Actions to Raise the Score
1. **[+14] Add an autotest hook.** Create `scripts/check.sh` running
   <the gate command from Section 2> and exit 2 on failure, then
   register it as a PostToolUse hook matching `Edit|Write` with
   `timeout: 60` in `.claude/settings.json`.
   → dimension 4, 0/14 → 14/14.
2. **[+11] Add a pre-push hook.** Create `.githooks/pre-push` running
   <the gate command from Section 2>, run
   `git config core.hooksPath .githooks`, and document the enable step
   in the README. → dimension 5, 0/11 → 11/11.
3. **[+6] Add deny rules for secrets.** Add `Read(.env*)` and
   `Edit(.env*)` to `permissions.deny` in `.claude/settings.json`.
   → dimension 3, 7/13 → 13/13.
4. **[+4] Declare `model:` on every agent.** `reviewer.md` and `qa.md`
   have no `model:` key. → dimension 6, 7/11 → 11/11.

### Counts & Metrics
```

⚠️ THE ACTION LIST ABOVE IS ABRIDGED — DO NOT COPY ITS LENGTH. It shows
four actions worth 14+11+6+4 = 35 points, but that example scores 52/100,
so 48 points are missing. A real artifact MUST also carry the three
actions the example omits: `[+5]` dimension 7 (4/9 → 9/9), `[+5]`
dimension 8 (0/5 → 5/5), and `[+3]` dimension 9 (0/3 → 3/3). 35 + 13 = 48
= 100 − 52, and only then does the list satisfy Section 7's completeness
rule. The example is shape guidance, not a coverage target.

Note that dimension 10 does not appear in this example's action list:
it is already at 12/12, and Section 7 rule 7 says a dimension at full
marks does not appear. Had it scored 0, it would be action #1 with the
combined delta (Section 7 rule 9) and every other action would sit
below the cap note.

The `Status` column must be a FACT, not a verdict: "3 agents, 2 without
`model:`" — a number and what is missing. Never "poor" or "needs work".

COUNTS & METRICS — report at least:
- CLAUDE.md: present/absent, line count
- Rules: count, how many with `paths:`
- Permissions: settings.json present yes/no, deny entries count, allow
  entries count, blanket wildcard present yes/no
- Hooks: count by event, real-gate yes/no, timeout set yes/no
- Pre-push: mechanism detected (or none), versioned yes/no
- Agents: count, how many declare `model:`, how many declare `tools:`
- Commands/Skills: counts
- Versioning: harness files on disk vs tracked (e.g. "9 on disk, 9
  tracked"), `.gitignore` match for `.claude` yes/no + the
  `<file>:<line>` if yes, cap applied yes/no
- Existence subtotal /28, Quality subtotal /72
- Total: N/100 (and the uncapped sum if the cap applied), band, points
  recoverable from the action list

────────────────────────────────────────────────────────────────────
SECTION 9 — EVIDENCE DISCIPLINE
────────────────────────────────────────────────────────────────────

NON-NEGOTIABLE — this audit is evidence-based:
- Every Evidence entry is a REAL file path you actually opened or
  listed, ideally with the line or key that supports the claim.
- NEVER invent a file path. If you did not see it, it does not go in
  Evidence. A plausible-looking path is worse than no path: it sends
  someone to a file that does not exist and it discredits the score.
- If a file could not be read, write "Unable to read: <path>" and score
  the dependent checks as failing. Do not guess at contents.
- Absence is evidence too, and must be recorded as a verified absence:
  "No `.claude/hooks` key in `.claude/settings.json`" — not "hooks may
  be missing".
- Quote the discriminating detail. For a hollow hook, quote the
  command. For a missing `model:`, name the agent files. The reader
  must be able to verify your judgement without re-running the audit.
- Distinguish "missing" from "untracked" everywhere. They are different
  findings with different one-line fixes, and under this rubric they
  are different SCORES: missing costs the dimension's existence points,
  untracked costs dimension 10 and nothing else. Writing "untracked"
  where you mean "missing" (or the reverse) is a scoring error, not a
  wording error.
- When dimension 10 is not at 12, quote `git check-ignore -v --no-index`'s exact
  output line, or state "not ignored; N of M harness files untracked"
  with the file names. "The harness is not committed" without the paths
  is not evidence.

────────────────────────────────────────────────────────────────────
SECTION 10 — EDGE CASES
────────────────────────────────────────────────────────────────────

- NO `.claude/` AND NO `CLAUDE.md`: score 0/100, band "sin harness".
  This is a valid, complete result — not an error and not a reason to
  go looking further afield. Produce the FULL action list anyway: this
  is the highest-value report the rubric can emit, because every one of
  the 100 points is recoverable and the team has never seen the map.
  Spend ≤3 tool calls getting here.
- HARNESS EXISTS BUT IS UNTRACKED OR GITIGNORED: score dimensions 1-9
  NORMALLY, entirely on what the files contain. Score dimension 10 at 0
  and apply the Section 6 cap. Lead Key Findings with it, and report
  both numbers — the uncapped sum and the capped score — because the
  gap between them IS the value of the one commit. This is the case the
  rubric was rewritten for: it used to collapse to ~14 and tell a team
  with a real harness to go build one.
  Do NOT let the cap tempt you into scoring dimensions 1-9 harshly to
  "make the number look right". The uncapped sum is a real measurement
  that the team will re-check after committing.
- TRACKED BUT `.gitignore` MATCHES `.claude`: the grandfathered case.
  `git ls-files` looks healthy; `git check-ignore -v --no-index` is the only thing
  that sees it. Dimension 10 scores 8, the cap does NOT apply, and it
  is a Key Finding: the harness is shared today and silently stops
  growing tomorrow. Quote the `<file>:<line>:<pattern>` and make the
  action "delete that line".
- HARNESS ON DISK, `.git` ABSENT ENTIRELY (not a git repo): dimension
  10 scores 0 and the cap applies, but the finding is different and the
  action is `git init`, not `git add`. Say which one it is. If
  `git ls-files` errors rather than returning empty, that is the tell —
  do not report it as "nothing is committed".
- MONOREPO: the harness is scored at the repo root, where Claude Code
  loads it. Nested `CLAUDE.md` files in packages are a bonus signal for
  dimension 1's quality (they are the "pro" shape), never a
  replacement for the root file. Nested rules under a package's
  `.claude/` are not loaded at the root — do not count them.
- `AGENTS.md` INSTEAD OF `CLAUDE.md`: score it as dimension 1's file.
  Both present → score the one with real content; note the duplication
  as a drift risk in Findings.
- HARNESS PIECES OUTSIDE `.claude/`: some projects keep hook scripts in
  `scripts/` or `tools/`. That is fine and expected — dimension 4 asks
  that the script live in-repo, not that it live under `.claude/`. Such
  a script is also outside dimension 10's scope (`.claude/**` plus the
  CLAUDE.md file): do not fail dimension 10 because `scripts/check.sh`
  is untracked. Say it in Evidence and let dimension 4 judge the path.
- THIS AUDIT'S OWN SKILL FILES: if the repo under audit is itself a
  repo of skills/agents (like this one), score only its OWN harness at
  the root — `.claude/`, `CLAUDE.md`, `.githooks/`. Do NOT score the
  `skills/**/agents/*.md` it ships as products; those are its output,
  not its harness. Getting this wrong inflates dimensions 6 and 8
  enormously.
- A HOOK THAT CALLS A MISSING SCRIPT: existence 5 (it is configured),
  gate 0 (it cannot run). Flag it loudly — it is a silent no-op that
  the team believes is protecting them, which is worse than no hook.
- MANY AGENTS (>10): do not read them in full. One Bash call with
  `head -20` per file, or a targeted grep for `model:` / `tools:` /
  `description:` across `.claude/agents/*.md`, answers every dimension
  6 check. Stay in budget.
- `.claude/` PRESENT BUT EMPTY (directory only, no files): treat as
  absent for every dimension, dimension 10 included — an empty
  directory is not an unversioned harness, it is no harness. Git cannot
  track a directory anyway. Do not award existence points for a
  directory, and do not apply the cap on its account.

────────────────────────────────────────────────────────────────────
MANDATORY OUTPUT VERIFICATION
────────────────────────────────────────────────────────────────────

Before writing the artifact, verify:
- [ ] All 10 dimensions have a score, including the ones that scored 0
- [ ] NO dimension other than 10 was reduced for a file being untracked
      or gitignored. Existence was judged on disk, every time
- [ ] Dimension 10 was scored from `git ls-files` CROSSED WITH
      `git check-ignore -v --no-index` — not from `git ls-files` alone, which
      cannot see the grandfathered case
- [ ] `settings.local.json` and `CLAUDE.local.md` were excluded from
      dimension 10's scope, not counted as untracked failures
- [ ] Every dimension's score is decomposed into existence + quality,
      and no quality points were awarded on assumption
- [ ] Dimension 1's cap was evaluated BEFORE summing its quality tests
- [ ] Dimension 4's gate verdict came from reading the SCRIPT BODY, not
      from `settings.json` alone
- [ ] Dimension 6's `model:` test was applied all-or-nothing, and any
      offending agent files are named
- [ ] Dimension 5 was checked against ALL FIVE mechanisms in Section 5,
      in precedence order
- [ ] The ten dimensions sum to the reported total; the total is an
      integer 0-100
- [ ] The Section 6 cap was applied if and only if dimension 10 scored
      0; if it applied, BOTH the uncapped sum and the capped score are
      reported, with the reason
- [ ] The maturity band matches the FINAL (capped) score per Section 6
- [ ] The Strong/Fair/Weak label matches the FINAL score per Section 6
- [ ] Every Evidence entry is a real path that was opened or listed
- [ ] The action list is sorted by points descending, every entry has a
      `[+N]` and a `→ dimension D, X/Y → Y/Y` — except that the
      versioning action goes first when the cap is active (rule 9)
- [ ] Every point gap in the Coverage table is accounted for by exactly
      one action (Σ deltas = 100 − UNCAPPED sum)
- [ ] The artifact was written to the exact path the invoker specified, and nowhere else
- [ ] Total tool calls ≤ 8
