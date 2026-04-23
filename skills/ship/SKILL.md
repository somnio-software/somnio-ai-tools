---
name: ship
description: >-
  Ship workflow: merge base branch, run tests, review diff, bump VERSION,
  update CHANGELOG, commit, push, create PR. Use when asked to "ship",
  "deploy", "push to main", "create a PR", "merge and push", or "get it deployed".
  Proactively invoke this skill when the user says code is ready, asks about
  deploying, wants to push code up, or asks to create a PR.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
triggers:
  - ship it
  - create a pr
  - push to main
  - deploy this
---

# Ship: Fully Automated Ship Workflow

You are running the `/ship` workflow. This is a **non-interactive, fully automated** workflow.
Do NOT ask for confirmation at any step. The user said `/ship` which means DO IT.
Run straight through and output the PR URL at the end.

**Only stop for:**
- On the base branch (abort)
- Merge conflicts that can't be auto-resolved (stop, show conflicts)
- In-branch test failures (pre-existing failures are triaged, not auto-blocking)
- Pre-landing review finds ASK items that need user judgment
- MINOR or MAJOR version bump needed (ask — see Step 8)

**Never stop for:**
- Uncommitted changes (always include them)
- Version bump choice (auto-pick MICRO or PATCH — see Step 8)
- CHANGELOG content (auto-generate from diff)
- Commit message approval (auto-commit)

**Re-run behavior (idempotency):**
Re-running `/ship` means "run the whole checklist again." Every verification step
runs on every invocation. Only *actions* are idempotent:
- Step 8: If VERSION already bumped, skip the bump but still read the version
- Step 11: If already pushed, skip the push command
- Step 12: If PR exists, update the body instead of creating a new PR

---

## Step 0: Detect platform and base branch

First, detect the git hosting platform from the remote URL:

```bash
git remote get-url origin 2>/dev/null
```

- If the URL contains "github.com" → platform is **GitHub**
- Otherwise → **unknown** (use git-native commands only)

Determine which branch this PR targets, or the repo's default branch:

**If GitHub:**
1. `gh pr view --json baseRefName -q .baseRefName` — if succeeds, use it
2. `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` — if succeeds, use it

**Git-native fallback:**
1. `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'`
2. If that fails: `git rev-parse --verify origin/main 2>/dev/null` → use `main`
3. If that fails: `git rev-parse --verify origin/master 2>/dev/null` → use `master`

If all fail, fall back to `main`.

Print the detected base branch name. In every subsequent command, substitute the
detected branch name wherever the instructions say "the base branch" or `<base>`.

---

## Step 1: Pre-flight

1. Check the current branch. If on the base branch, **abort**: "You're on the base branch. Ship from a feature branch."

2. Run `git status` (never use `-uall`). Uncommitted changes are always included.

3. Run `git diff <base>...HEAD --stat` and `git log <base>..HEAD --oneline` to understand what's being shipped.

---

## Step 2: Merge the base branch (BEFORE tests)

Fetch and merge the base branch into the feature branch so tests run against the merged state:

```bash
git fetch origin <base> && git merge origin/<base> --no-edit
```

**If there are merge conflicts:** Try to auto-resolve if they are simple (VERSION, CHANGELOG ordering). If conflicts are complex or ambiguous, **STOP** and show them.

**If already up to date:** Continue silently.

---

## Step 3: Run tests (on merged code)

Run the project's test and build pipeline:

```bash
pnpm run build 2>&1 | tee /tmp/ship_build.txt
pnpm run lint 2>&1 | tee /tmp/ship_lint.txt
pnpm run test 2>&1 | tee /tmp/ship_tests.txt
```

After all complete, read the output files and check pass/fail.

**If any test fails:** Do NOT immediately stop. Apply the Test Failure Ownership Triage:

### Test Failure Ownership Triage

For each failing test:

1. **Get the files changed on this branch:**
   ```bash
   git diff origin/<base>...HEAD --name-only
   ```

2. **Classify the failure:**
   - **In-branch** if: the failing test file or the code it tests was modified on this branch, OR you can trace the failure to a change in the branch diff.
   - **Likely pre-existing** if: neither the test file nor the code it tests was modified on this branch, AND the failure is unrelated to any branch change.
   - **When ambiguous, default to in-branch.**

3. **Handle in-branch failures:** **STOP.** Show them and do not proceed.

4. **Handle pre-existing failures:** Use AskUserQuestion:
   > These test failures appear pre-existing (not caused by your branch changes):
   > [list each failure with file:line and brief error]
   >
   > A) Investigate and fix now
   > B) Skip — ship anyway

**If all pass:** Continue silently — note the counts briefly.

---

## Step 4: Test Coverage Audit

**Dispatch this step as a subagent** using the Agent tool. The subagent runs the
coverage audit in a fresh context window.

**Subagent prompt:** Pass the following instructions to the subagent, with `<base>` substituted:

> You are running a ship-workflow test coverage audit for a NestJS monorepo with 4-layer
> Clean Architecture (domain, application, infrastructure, api). Run `git diff <base>...HEAD`
> to see what changed. Do not commit or push — report only.
>
> 1. **Trace every codepath changed** in the diff. Read every changed file (full file, not just diff).
>    For each, trace data flow through every branch (if/else, switch, guard, early return, error path).
>
> 2. **Check each branch against existing tests.** For each function/method changed, search for
>    corresponding `.spec.ts` files. Score quality:
>    - ★★★ Tests behavior with edge cases AND error paths
>    - ★★  Tests correct behavior, happy path only
>    - ★   Smoke test / existence check / trivial assertion
>
> 3. **Output ASCII coverage diagram:**
>    ```
>    CODE PATH COVERAGE
>    ===========================
>    [+] src/application/units/commands/sync-unit.handler.ts
>        ├── [★★★ TESTED] Happy path — sync-unit.handler.spec.ts:42
>        ├── [GAP]         Error when unit not found — NO TEST
>        └── [GAP]         Partial update scenario — NO TEST
>    ```
>
> 4. **Generate tests for uncovered paths** (if test framework exists):
>    - Read 2-3 existing `.spec.ts` files to match conventions exactly
>    - Generate unit tests. Mock external dependencies (TypeORM repos, external APIs).
>    - Run each test. Passes → keep. Fails → fix once. Still fails → delete silently.
>
> After your analysis, output a single JSON object on the LAST LINE:
> `{"coverage_pct":N,"gaps":N,"diagram":"<markdown diagram>","tests_added":["path",...]}`

**Parent processing:**
1. Parse the LAST line as JSON.
2. Store for the PR body's `## Test Coverage` section.
3. Print: `Coverage: {coverage_pct}%, {gaps} gaps. {tests_added.length} tests added.`

**If the subagent fails:** Fall back to running the audit inline.

---

## Step 5: Pre-Landing Review

Review the diff for structural issues that tests don't catch.

1. Run `git diff origin/<base>` to get the full diff.

2. Apply this review checklist in two passes:

### Pass 1 (CRITICAL) — must fix before shipping:
- **SQL & Data Safety:** Raw SQL with string interpolation, missing transactions on multi-table writes, missing `WHERE` on UPDATE/DELETE, unvalidated user input in queries
- **Security:** Exposed secrets, missing gitignored files and directories properly, missing auth guards on endpoints, XSS via unsanitized output, CORS misconfiguration
- **Breaking Changes:** Removed/renamed public API endpoints, changed response shapes, removed required fields

### Pass 2 (INFORMATIONAL) — fix or note:
- **Architecture:** Layer boundary violations (framework imports in domain/), DTOs mixed with entities, missing barrel exports
- **Error Handling:** Inline string error messages (should use error enums), swallowed errors, missing Problem Details format
- **Performance:** N+1 queries, missing pagination, unbounded queries, missing indexes
- **Code Quality:** Dead code, orphan code, unused imports, duplicated logic, overly complex conditionals

### Confidence Calibration

Every finding MUST include a confidence score (1-10):

| Score | Meaning |
|-------|---------|
| 9-10 | Verified by reading specific code. Concrete bug demonstrated. |
| 7-8 | High confidence pattern match. Very likely correct. |
| 5-6 | Moderate. Could be a false positive. Show with caveat. |
| 3-4 | Low confidence. Suppress from main report. |
| 1-2 | Speculation. Only report if severity would be P0. |

**Finding format:**
`[SEVERITY] (confidence: N/10) file:line — description`

### Fix-First Flow

3. **Classify each finding as AUTO-FIX or ASK:**
   - AUTO-FIX: Dead code removal, unused imports, missing barrel exports, obvious formatting
   - ASK: Anything that changes behavior, security fixes, architectural decisions

4. **Auto-fix all AUTO-FIX items.** Output one line per fix:
   `[AUTO-FIXED] [file:line] Problem → what you did`

5. **If ASK items remain,** present them in ONE AskUserQuestion:
   - List each with severity, problem, recommended fix
   - Per-item options: A) Fix  B) Skip

6. **After all fixes:**
   - If ANY fixes were applied: commit fixed files (`git add <files> && git commit -m "fix: pre-landing review fixes"`), then **re-run tests** (Step 3).
   - If no fixes applied: continue to Step 8.

7. Output summary: `Pre-Landing Review: N issues — M auto-fixed, K asked (J fixed, L skipped)`

---

## Step 6: Scope Drift Detection

Check: did the branch build what was stated — nothing more, nothing less?

1. Read commit messages (`git log origin/<base>..HEAD --oneline`).
2. Identify the **stated intent** from the branch name and commits.
3. Run `git diff origin/<base>...HEAD --stat` and compare files changed against intent.

4. Detect:
   - **SCOPE CREEP:** Files changed that are unrelated to the stated intent
   - **MISSING REQUIREMENTS:** Expected work not present in the diff

5. Output:
   ```
   Scope Check: [CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING]
   Intent: <1-line summary>
   Delivered: <1-line summary>
   ```

6. This is **INFORMATIONAL** — does not block. Continue.

---

## Step 7: Plan Completion Audit

**Dispatch as a subagent.** Searches for an active plan file related to the current branch.

**Subagent prompt:**

> You are running a ship-workflow plan completion audit. The base branch is `<base>`.
>
> 1. Search for plan files: `find ~/.claude/plans ~/.gstack/projects -name "*.md" -mmin -1440 2>/dev/null | head -10`
> 2. If a plan references the current branch, read it and extract every actionable item.
> 3. Cross-reference each item against `git diff origin/<base>...HEAD`.
> 4. Classify: DONE, PARTIAL, NOT DONE, CHANGED.
>
> Output JSON on the LAST LINE:
> `{"total_items":N,"done":N,"changed":N,"deferred":N,"summary":"<markdown checklist>"}`

**Parent processing:**
- If `deferred > 0`: present deferred items via AskUserQuestion.
- Embed `summary` in PR body.
- If no plan file found: skip with "No plan file detected."

---

## Step 8: Version bump (auto-decide)

**Idempotency check:** Compare VERSION against the base branch.

```bash
BASE_VERSION=$(git show origin/<base>:VERSION 2>/dev/null || echo "0.0.0.0")
CURRENT_VERSION=$(cat VERSION 2>/dev/null || echo "0.0.0.0")
echo "BASE: $BASE_VERSION  HEAD: $CURRENT_VERSION"
if [ "$CURRENT_VERSION" != "$BASE_VERSION" ]; then echo "ALREADY_BUMPED"; fi
```

If `ALREADY_BUMPED`, skip the bump but read the current version. Otherwise:

1. Read `VERSION` (4-digit format: `MAJOR.MINOR.PATCH.MICRO`)

2. **Auto-decide the bump level:**
   - Count lines changed (`git diff origin/<base>...HEAD --stat | tail -1`)
   - **MICRO** (4th digit): < 50 lines changed, trivial tweaks, config
   - **PATCH** (3rd digit): 50+ lines, no feature signals
   - **MINOR** (2nd digit): **ASK** if feature signals detected (new routes, migrations, `feat/` branch)
   - **MAJOR** (1st digit): **ASK** — only for milestones or breaking changes

3. Compute and write the new version to `VERSION`.

---

## Step 9: CHANGELOG (auto-generate)

1. Read `CHANGELOG.md` header to know the format.

2. Enumerate every commit: `git log <base>..HEAD --oneline`

3. Read the full diff: `git diff <base>...HEAD`

4. Group commits by theme (features, fixes, cleanup, infra).

5. Write the CHANGELOG entry:
   - Sections: `### Added`, `### Changed`, `### Fixed`, `### Removed`
   - Format: `## [X.Y.Z.W] - YYYY-MM-DD`
   - Lead with what the user can now **do** that they couldn't before.

6. Cross-check: every commit must map to at least one bullet point.

---

## Step 10: Commit (bisectable chunks)

1. Analyze the diff and group changes into logical commits.

2. **Commit ordering** (earlier commits first):
   - Infrastructure: migrations, config changes
   - Domain & Application: entities, value objects, use cases, services (with tests)
   - Infrastructure implementations: repositories, TypeORM entities (with tests)
   - API layer: controllers, DTOs (with tests)
   - VERSION + CHANGELOG: always in the final commit

3. **Rules:**
   - A service and its test file go in the same commit
   - Each commit must be independently valid — no broken imports
   - If total diff is small (< 50 lines across < 4 files), a single commit is fine

4. Compose commit messages:
   - Invoke the `/git-commit-format` skill using the Skill tool.
   - **Never** include `Co-Authored-By` or any AI attribution trailer (per project convention)

---

## Step 11: Verification Gate

**IRON LAW: NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

Before pushing, re-verify if code changed during Steps 4-6:

1. **Re-run tests if ANY code changed** after Step 3's test run:
   ```bash
   pnpm run build && pnpm run lint && pnpm run test
   ```

2. **Rationalization prevention:**
   - "Should work now" → RUN IT.
   - "I already tested earlier" → Code changed since then. Test again.
   - "It's a trivial change" → Trivial changes break production.

**If tests fail here:** STOP. Do not push.

---

## Step 12: Push

**Idempotency check:**

```bash
BRANCH_NAME=$(git branch --show-current)
git fetch origin "$BRANCH_NAME" 2>/dev/null
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$BRANCH_NAME" 2>/dev/null || echo "none")
echo "LOCAL: $LOCAL  REMOTE: $REMOTE"
[ "$LOCAL" = "$REMOTE" ] && echo "ALREADY_PUSHED" || echo "PUSH_NEEDED"
```

If `ALREADY_PUSHED`, skip. Otherwise:

```bash
git push -u origin "$BRANCH_NAME"
```

---

## Step 13: Create PR

**Idempotency check:**

```bash
gh pr view --json url,number,state -q 'if .state == "OPEN" then "PR #\(.number): \(.url)" else "NO_PR" end' 2>/dev/null || echo "NO_PR"
```

If an open PR already exists: **update** the PR body using `gh pr edit --body "..."`.

If no PR exists: create one.

The PR body should contain:

```
## Summary
<Summarize ALL changes. Group commits into logical sections. Every commit
must appear in at least one section.>

## Test Coverage
<Coverage diagram from Step 4, or "All new code paths have test coverage.">

## Pre-Landing Review
<Findings from Step 5, or "No issues found.">

## Scope Drift
<From Step 6, or omit if CLEAN>

## Plan Completion
<From Step 7, or "No plan file detected.">

## Test plan
- [x] TypeScript compilation passes (strict mode)
- [x] ESLint passes
- [x] All Jest tests pass (N tests)
- [x] No regressions in affected modules
```

**Create the PR:**

```bash
gh pr create --base <base> --title "<type>(<scope>): <summary>" --body "$(cat <<'EOF'
<PR body from above>
EOF
)"
```

**Output the PR URL.**

---

## Important Rules

- **Never skip tests.** If tests fail, stop.
- **Never force push.** Use regular `git push` only.
- **Never ask for trivial confirmations** (e.g., "ready to push?", "create PR?").
- **Always use the 4-digit version format** from the VERSION file.
- **Date format in CHANGELOG:** `YYYY-MM-DD`
- **Split commits for bisectability** — each commit = one logical change.
- **Never push without fresh verification evidence.** If code changed after Step 3 tests, re-run before pushing.
- **Never include Co-Authored-By trailers** in commit messages (per project convention).
- **The goal is: user says `/ship`, next thing they see is the PR URL.**
