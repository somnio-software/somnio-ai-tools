# Troubleshooting — warnings and setup errors

> This guide is a **measurement-setup** aid, not a performance guide. Every
> entry here diagnoses **why a specific data point is missing or unmeasurable**
> (a wrong branch, a missing token scope, a tagging gap) and how to fix the
> **setup** so the next run measures correctly. Nothing here says whether a
> number is good or bad, or what a team should do differently — interpreting the
> numbers is a separate, deliberately later step, outside this skill's scope
> (Goodhart's Law).

When the script emits a warning (`! ...` in the console) or the auth error, look
it up here and include the **What / How to check / Where to fix** guidance
alongside the raw text — do not replace the raw text, add to it.

Matching a raw warning to an entry: the entry headings use placeholders for the
parts that vary at runtime — `<Release|Tag>` (whichever `deploy_source` produced
it), `vX.Y.Z` (the actual tag), and `#N` (the actual PR number). A raw warning
matches the entry whose heading is identical once those placeholders are filled
in; match on the fixed wording (e.g. "has no known prior", "0 merged PRs found
in the range", "could not fetch the first commit"), not on the tag or number.

---

## Warning: "<Release|Tag> vX.Y.Z has no known prior <release|tag> — the PR population can't be bounded, it's excluded from the Lead Time."

**What.** This deploy is the first one the script can see in the repo's history
for the configured marker (`deploy_source`: Release or plain tag). Lead Time is
measured against the *previous* deploy, so with no prior marker there is no lower
bound for the PR population — the script skips Lead Time for this deploy and says
so. The deploy still counts toward Deployment Frequency; only its Lead Time is
excluded.

**How to check.** In the repo's GitHub Releases (or tags) page, confirm this is
in fact the earliest marker matching `tag_pattern`. If it is, this is structural
and expected.

**Where to fix.** Nothing to fix — this is not a setup problem. It resolves on
its own once a second deploy exists to bound against. If instead you *expected*
an earlier deploy to exist and be recognized, that points at a different entry:
an earlier tag/release that does not match `tag_pattern` (check
`config/projects.json` → `tag_pattern`, global or the repo's override) would not
be seen, which can make a later deploy look like "the first".

---

## Warning: "<Release|Tag> vX.Y.Z: 0 merged PRs found in the range — check the base branch/convention."

**What.** Between this deploy and the previous one, the script found no PRs
merged into the configured production branch, so it has nothing from which to
compute Lead Time for this deploy. This is usually a **measurement-setup**
mismatch rather than a real absence of changes.

**How to check.**

- In `config/projects.json`, read the repo's `prod_branch` and compare it to
  the branch PRs actually merge into on GitHub. If PRs merge into `master`,
  `production`, `release`, etc. but `prod_branch` says `main` (or vice versa),
  the query looks at the wrong base and finds nothing.
- On GitHub, open the repo's merged PRs for the interval between the two deploy
  tags and check their **base** branch. If changes reached the branch via direct
  pushes or fast-forward merges **without a PR**, the Search API cannot see them
  (Lead Time is defined only over merged PRs — see
  `references/lead-time-for-changes.md`).

**Where to fix.**

- Wrong branch: correct `repos[].prod_branch` in `config/projects.json` (or use
  `--branch <branch>` for a one-off check without editing the config). Confirm
  the change before saving — the config is shared by the team.
- Changes landing without PRs: this is a process/instrumentation detail of the
  repo. Routing production changes through PRs is what makes Lead Time
  measurable; that is a setup choice for the repo, not something this guide
  ranks or scores.

---

## Warning: "PR #N: could not fetch the first commit, it's excluded."

**What.** The script found the merged PR but could not read its commit list from
the GitHub API, so it has no first-commit timestamp to start Lead Time from and
excludes that single PR. The other PRs in the interval are unaffected.

**How to check.**

- Confirm the token can read that repo's PR commits: open the PR on GitHub with
  the same account and check `pulls/N/commits` is visible. A token missing repo
  read scope (or org access, for a multi-org project) can return the PR from
  Search but fail on the commit fetch.
- Open the PR on GitHub and check its commit history is present and not empty
  (unusual merge history — e.g. a PR whose commits were rewritten or whose head
  was force-removed — can leave no fetchable commits).

**Where to fix.**

- Token scope/access: use a `GITHUB_TOKEN` (or `gh auth login` session) with
  **read** access to that repo and to **all** the orgs of the project's repos.
  See the auth entry below.
- Genuinely empty/unusual commit history: nothing to fix in config — this PR is
  correctly excluded because its first commit is unrecoverable.

---

## Error: "no GitHub credential found."

**What.** Before any measurement, the script needs a GitHub credential and found
neither a `GITHUB_TOKEN` environment variable nor a logged-in `gh` CLI, so it
stops instead of failing silently. The script's own message already lists the
two options; this expands on them.

**How to check.** Run `gh auth status` to see whether the GitHub CLI is logged
in, and `echo $GITHUB_TOKEN` to see whether the env var is set in the shell you
run the script from. Whichever credential you use must have **read** access to
every org that owns one of the project's repos (a multi-org project needs access
to each org).

**Where to fix.**

- Option 1: `export GITHUB_TOKEN=ghp_xxxx` with a token that has repo **read**
  scope for those orgs.
- Option 2: run `gh auth login` once (if the GitHub CLI is installed) — the
  script detects it automatically via `gh auth token`, nothing to export.
- If a token exists but the run later fails with `401 Unauthorized` or a `404`
  on a repo, the credential is present but missing access to that repo/org —
  re-issue it with the right scopes rather than treating it as a "no credential"
  case.

---

## Setup check: Deployment Frequency count looks incomplete (tag/deploy discipline)

**What.** Deployment Frequency counts deploy markers (Releases or tags matching
`tag_pattern`) in the window. If a production deploy happened but was **not**
tagged/released per the repo's `deploy_source`, the script has no marker to count
and that deploy is not reflected in the number. This is a measurement/
instrumentation gap, not a statement about the number itself.

**How to check.** If you suspect the count does not reflect every deploy, verify
that **each** production deploy in the window actually produced a marker matching
the repo's configured `deploy_source`:

- `deploy_source: "release"` — a published (non-draft) GitHub Release whose tag
  matches `tag_pattern`.
- `deploy_source: "tag"` — a git tag whose name matches `tag_pattern`.

Cross-check the repo's Releases/tags list on GitHub against the deploys you know
happened.

**Where to fix.**

- Marker missing for a real deploy: add the missing Release/tag in the repo, or
  align the repo's release process so every prod deploy creates the configured
  marker.
- Marker present but not matching: check `repos[].deploy_source` and
  `tag_pattern` (repo override or global) in `config/projects.json` — a tag
  format the pattern doesn't match (e.g. a build-number suffix) won't be counted
  until the pattern or the tag naming lines up.

This is purely a check on whether every deploy is *instrumented*. It does not
comment on how often the repo deploys or whether that cadence is adequate — that
would be interpreting performance, which is out of scope.
