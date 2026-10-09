# Troubleshooting — problems and how to fix them

> This guide is a **measurement-setup** aid, not a performance guide. Every
> entry here diagnoses **why a specific data point is missing or unmeasurable**
> (a wrong branch, a missing token scope, a tagging gap) and how to fix the
> **setup** so the next run measures correctly. Nothing here says whether a
> number is good or bad, or what a team should do differently — interpreting the
> numbers is a separate, deliberately later step, outside this skill's scope
> (Goodhart's Law).

This file is **machine-read**. Each entry is preceded by an anchor comment
`<!-- code: some_code -->` matching a code the script emits, and holds three
subsections: `### What`, `### How to check`, `### Where to fix`. The script
parses them (`scripts/troubleshooting.py`) and embeds them in its JSON output
and in the saved Markdown report, so the steps travel with the report instead of
being looked up by hand. Editing the prose here changes what every future report
says — that is the point. Do not rename the subsection headings and do not
remove an anchor without also removing the code from `ISSUE_CODES` in
`scripts/dora_metrics.py`; a test asserts the two stay in sync.

Every code below is shared across the three supported providers (GitHub,
GitLab, Bitbucket) — the same script path produces the same code regardless of
which repo it came from, so "How to check" / "Where to fix" are broken out per
provider only where the concrete steps differ.

Sections without an anchor are for human readers only and are ignored by the
parser.

---

<!-- code: no_credential -->
## No credential found for this repo's provider

### What

Before any measurement, the script needs a credential for the repo's
`provider` (`github`, `gitlab`, or `bitbucket`) and found none. If this is the
*only* provider in play for the run, nothing could be measured and the report
contains this problem and no numbers; if other providers in the same run do
have a credential, only the repos on this provider are affected — the rest of
the run measures normally.

### How to check

- **GitHub:** `gh auth status` (is the GitHub CLI logged in?) and
  `echo $GITHUB_TOKEN`.
- **GitLab:** `glab auth status` (is the GitLab CLI logged in?) and
  `echo $GITLAB_TOKEN`.
- **Bitbucket:** `echo $BITBUCKET_TOKEN`, or `echo $BITBUCKET_USERNAME` /
  `echo $BITBUCKET_APP_PASSWORD` (there is no CLI fallback for Bitbucket).

Whichever credential you use must have **read** access to every org/group/
workspace that owns one of the project's repos on that provider (a multi-org
project needs access to each one).

### Where to fix

- **GitHub** — Option 1: `export GITHUB_TOKEN=ghp_xxxx` with a token that has
  repo **read** scope for those orgs. Option 2: run `gh auth login` once — the
  script detects it automatically via `gh auth token`, nothing to export.
- **GitLab** — Option 1: `export GITLAB_TOKEN=glpat-xxxx` with a token that has
  `read_api` scope for those groups/projects. Option 2: run `glab auth login`
  once — the script detects it automatically via `glab auth token`.
- **Bitbucket** — Option 1: `export BITBUCKET_TOKEN=xxxx` with a workspace or
  repository access token. Option 2: `export BITBUCKET_USERNAME=...` and
  `export BITBUCKET_APP_PASSWORD=...` (an app password, not the account
  password) — both must be set together.

---

<!-- code: repo_unreachable -->
## The repo is unreachable with this credential

### What

The provider's "does this repo exist and can I see it" check returned 404 or
403, so the script cannot read anything about this repo and skipped it. The
other repos of the project were still measured. A 404 here does not
necessarily mean the repo is gone: all three providers return 404 rather than
403 for a private repo a credential cannot see.

### How to check

- Confirm the `repo` value in `config/projects.json` is current:
  - **GitHub:** `org/repo`.
  - **GitLab:** the project's full path (`group/project` or
    `group/subgroup/project`) — a renamed group or project keeps redirecting
    in the browser but the configured path may no longer be canonical.
  - **Bitbucket:** `workspace/repo_slug`.
- Open the repo on the provider's web UI with the same account that owns the
  credential. If you cannot see it there either, it is an access problem, not
  a config typo.
- For a multi-org/multi-group/multi-workspace project, check the credential
  covers **that specific one**. Access to one says nothing about another.

### Where to fix

- Wrong path: correct `repos[].repo` in `config/projects.json`.
- Missing access: re-issue the credential with read scope for that org/group/
  workspace, or have it grant the account access. For a GitHub fine-grained
  token, the org must also approve it.

---

<!-- code: token_unauthorized -->
## The credential was rejected (401)

### What

The provider's API returned 401 Unauthorized. The credential exists but is not
valid — expired, revoked, or malformed. Nothing could be read for this repo.

### How to check

- **GitHub:** `gh auth status`, or
  `curl -sI -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user`
  and check for `HTTP/2 200`.
- **GitLab:** `glab auth status`, or
  `curl -sI -H "PRIVATE-TOKEN: $GITLAB_TOKEN" https://gitlab.com/api/v4/user`.
- **Bitbucket:** `curl -sI -H "Authorization: Bearer $BITBUCKET_TOKEN" https://api.bitbucket.org/2.0/user`,
  or the equivalent with `-u "$BITBUCKET_USERNAME:$BITBUCKET_APP_PASSWORD"`.

### Where to fix

Issue a new credential and export it again, or re-run the provider's CLI login
(`gh auth login` / `glab auth login`). Classic GitHub tokens and GitLab
personal access tokens can expire silently; fine-grained tokens also expire
and lose access when their org approval is revoked. A Bitbucket app password
is revoked independently of the account password — check it wasn't deleted.

---

<!-- code: rate_limited -->
## Provider API rate limit reached

### What

The provider's API refused the request for being over its rate limit, so the
run stopped reading data for this repo. This is not a configuration problem —
it is a quota one. GitHub's Search API (used for merged PRs) has a much lower
limit than its REST API; GitLab signals this with a plain 429, and the script
also treats a Bitbucket 429 as a rate limit (Atlassian does not document one).

### How to check

- **GitHub:** `gh api rate_limit` and look at the `search` and `core` blocks:
  `remaining` and the `reset` timestamp.
- **GitLab:** the response headers on any API call include `RateLimit-Remaining`
  and `RateLimit-Reset`; `glab api rate_limit` surfaces them too on recent
  `glab` versions.
- **Bitbucket:** Atlassian documents hourly request limits and `X-RateLimit-*`
  headers (https://support.atlassian.com/bitbucket-cloud/docs/api-request-limits/),
  but does not document a 429 response or a `Retry-After` header. The script
  treats any 429 as a rate limit, without relying on a header: it stops
  reading that repo and reports this problem. Wait before re-running.

### Where to fix

- Re-run after the reset time the provider reports.
- Run fewer projects per invocation with `--project`, instead of the whole
  config at once.
- Make sure a credential is actually being used — unauthenticated requests have
  drastically lower limits on all three providers.

---

<!-- code: branch_not_found -->
## The configured production branch does not exist

### What

The provider's "does this branch exist" check returned 404: the branch named
in `repos[].prod_branch` is not in the repo. Deployment Frequency is unaffected
(it counts deploy markers, which do not depend on the branch), but Lead Time
cannot be computed, because the PR/MR population is defined as changes merged
into that branch.

### How to check

- **GitHub:** open the repo's branch list, or run
  `gh api repos/{owner}/{repo}/branches --jq '.[].name'`.
- **GitLab:** open the project's branch list, or run
  `glab api projects/{id}/repository/branches --jq '.[].name'`.
- **Bitbucket:** open the repo's branch list in the web UI, or
  `curl -s https://api.bitbucket.org/2.0/repositories/{workspace}/{repo_slug}/refs/branches`.

Compare with the `prod_branch` in `config/projects.json`. Common mismatches:
`master` vs `main`, or a repo that deploys from `production` / `release`.

### Where to fix

Correct `repos[].prod_branch` in `config/projects.json`. Confirm the change
before saving — the config is shared by the team. To test a branch without
touching the config, use `--branch <branch>` for a one-off run.

---

<!-- code: no_markers_at_all -->
## The repo has no deploy markers at all

### What

The repo has no marker of the configured kind: no published Releases when
`deploy_source` is `"release"` (GitHub/GitLab only), or no tags when it is
`"tag"`. With no marker there is nothing to count as a deploy, so Deployment
Frequency is 0 and Lead Time has nothing to measure against — regardless of
how much was actually deployed.

### How to check

- **GitHub:** the repo's Releases and Tags pages, or
  `gh api repos/{owner}/{repo}/releases --jq '.[].tag_name'` and
  `gh api repos/{owner}/{repo}/tags --jq '.[].name'`.
- **GitLab:** the project's Releases and Tags pages, or
  `glab api projects/{id}/releases --jq '.[].tag_name'` and
  `glab api projects/{id}/repository/tags --jq '.[].name'`.
- **Bitbucket:** the repo's Tags page (Bitbucket Cloud has no Releases API at
  all — `deploy_source` must be `"tag"`), or
  `curl -s https://api.bitbucket.org/2.0/repositories/{workspace}/{repo_slug}/refs/tags`.

### Where to fix

- The repo does use one of them but not the configured one (GitHub/GitLab
  only): set `repos[].deploy_source` in `config/projects.json` accordingly
  (`"release"` or `"tag"`). On Bitbucket, `deploy_source` must be `"tag"` —
  `"release"` is rejected before anything is measured.
- The repo marks no deploys at all: this is an instrumentation gap. Lead Time
  and Deployment Frequency are defined against a deploy marker, so until each
  production deploy creates a Release (or tag) this repo cannot be measured.
  Adding that step to the release process is a setup choice for the repo.

---

<!-- code: no_markers_matching_pattern -->
## The repo has markers, but none match `tag_pattern`

### What

Releases or tags exist, but none of their names match the `tag_pattern` regex,
so none was counted as a deploy. The report lists the actual names found — this
is almost always a naming mismatch, not an absence of deploys.

### How to check

Compare the names in the report's evidence with the `tag_pattern` in
`config/projects.json` (global, or the repo's own override). The default
`^v\d+\.\d+\.\d+$` matches `v1.4.0` and nothing else — not `1.4.0` (no `v`),
not `v1.4` (two components), not `v1.4.0-rc1` or `v1.4.0+build.22` (suffixes),
not `release-2026-07-01`.

### Where to fix

Set `repos[].tag_pattern` in `config/projects.json` to a regex matching that
repo's real naming, leaving the global pattern for the repos that follow it. The
pattern is matched with `re.match` (anchored at the start) on all three
providers; anchor the end with `$` if you want an exact match. Example for a
build-number suffix: `^v\d+\.\d+\.\d+\+\d+$`.

---

<!-- code: deploy_source_mismatch -->
## `deploy_source` points at the wrong kind of marker

### What

Nothing matched with the configured `deploy_source`, but markers matching
`tag_pattern` **do** exist of the other kind — the repo tags without publishing
Releases, or publishes Releases while `deploy_source` says `"tag"`. The script
looked in the right repo for the wrong thing. (Not applicable to Bitbucket,
which has only one marker kind — tags.)

### How to check

The report's evidence lists the matching names found on the other side. Confirm
on the provider's web UI that those are what the team treats as a production
deploy.

### Where to fix

Flip `repos[].deploy_source` in `config/projects.json` to the kind that exists
(`"release"` or `"tag"`) and re-run. To check before editing the shared config,
use the one-off `--deploy-source {release,tag}` flag.

---

<!-- code: matching_releases_all_draft -->
## The matching Releases are all drafts (or, on GitLab, upcoming)

### What

Releases whose tag matches `tag_pattern` exist, but every one of them is a
GitHub draft, or a GitLab Release whose `released_at` is still in the future
("upcoming"). Neither is counted as a deploy — a draft means the deploy was
not announced, and an upcoming release hasn't happened yet; counting either
would inflate Deployment Frequency with deploys that haven't really occurred.
(Not applicable to Bitbucket, which has no Releases API.)

### How to check

- **GitHub:** the repo's Releases page — drafts are labelled **Draft** and are
  only visible to users with write access.
  `gh api repos/{owner}/{repo}/releases --jq '.[] | select(.draft) | .tag_name'`
  lists them.
- **GitLab:** the project's Releases page — an upcoming release is labelled
  **Upcoming Release**. Compare each matching release's `released_at` against
  now.

### Where to fix

Publish the Releases that correspond to real deploys (GitHub), or wait for an
upcoming GitLab release's `released_at` to pass, or adjust the release process
so the final step publishes immediately rather than scheduling ahead. If the
team deliberately keeps drafts/upcoming releases and marks deploys with plain
tags instead, set `repos[].deploy_source` to `"tag"`.

---

<!-- code: no_markers_in_window -->
## No deploy markers inside the measurement window

### What

Deployment Frequency is 0 for a plain reason: the repo does have deploy markers
in its history, but none of them falls inside the measured window. The report
states how many exist and the date of the most recent one. This is a fact about
the window, not a setup problem.

### How to check

Nothing to check. If you expected a deploy inside the window and the marker for
it is missing, the relevant entries are `no_markers_matching_pattern` (the
marker exists under a different name) or the "Setup check: Deployment Frequency
count looks incomplete (tag/deploy discipline)" section in
`references/troubleshooting.md` (the deploy happened but produced no marker).

### Where to fix

Nothing to fix. Use `--window-days N` for a one-off run over a longer window if
you want to see the surrounding history.

---

<!-- code: first_marker_no_prior -->
## The earliest deploy has no prior marker to bound against

### What

This deploy is the first one the script can see in the repo's history for the
configured marker (`deploy_source`: Release or plain tag). Lead Time is measured
against the *previous* deploy, so with no prior marker there is no lower bound
for the PR/MR population — the script skips Lead Time for this deploy and says
so. The deploy still counts toward Deployment Frequency; only its Lead Time is
excluded.

### How to check

In the repo's Releases (or tags) page on the provider, confirm this is in fact
the earliest marker matching `tag_pattern`. If it is, this is structural and
expected.

### Where to fix

Nothing to fix — this is not a setup problem. It resolves on its own once a
second deploy exists to bound against. If instead you *expected* an earlier
deploy to exist and be recognized, that points at the `no_markers_matching_pattern`
entry in `references/troubleshooting.md`: an earlier tag/release that does not
match `tag_pattern` (check `config/projects.json` → `tag_pattern`, global or the
repo's override) would not be seen, which can make a later deploy look like "the
first".

---

<!-- code: no_prs_in_range -->
## No merged PRs/MRs found between two deploys

### What

Between this deploy and the previous one, the script found no PRs/MRs merged
into the configured production branch, so it has nothing from which to compute
Lead Time for this deploy. This is usually a **measurement-setup** mismatch
rather than a real absence of changes.

### How to check

- In `config/projects.json`, read the repo's `prod_branch` and compare it to
  the branch PRs/MRs actually merge into on the provider. If changes merge into
  `master`, `production`, `release`, etc. but `prod_branch` says `main` (or
  vice versa), the query looks at the wrong base and finds nothing.
- On the provider, open the merged PRs/MRs for the interval between the two
  deploy tags and check their **target/base** branch. If changes reached the
  branch via direct pushes or fast-forward merges **without a PR/MR**, the
  script cannot see them (Lead Time is defined only over merged PRs/MRs — see
  `references/lead-time-for-changes.md`).

### Where to fix

- Wrong branch: correct `repos[].prod_branch` in `config/projects.json` (or use
  `--branch <branch>` for a one-off check without editing the config). Confirm
  the change before saving — the config is shared by the team.
- Changes landing without a PR/MR: this is a process/instrumentation detail of
  the repo. Routing production changes through a PR/MR is what makes Lead Time
  measurable; that is a setup choice for the repo, not something this guide
  ranks or scores.

---

<!-- code: pr_first_commit_unfetchable -->
## A PR/MR's first commit could not be fetched

### What

The script found the merged PR/MR but could not read its commit list from the
provider's API, so it has no first-commit timestamp to start Lead Time from and
excludes that single PR/MR. The other PRs/MRs in the interval are unaffected.

### How to check

- Confirm the credential can read that repo's PR/MR commits: open the PR/MR on
  the provider with the same account and check its commit list is visible. A
  credential missing read scope (or org/group access, for a multi-org/group
  project) can return the PR/MR from the list but fail on the commit fetch.
- **Bitbucket:** check whether the PR's source branch or source fork was
  deleted. An empty commit list (branch deleted) or a 404 (fork deleted) is the
  expected cause, and common when PRs delete their source branch on merge.
- Open the PR/MR and check its commit history is present and not empty
  (unusual merge history — e.g. a PR whose commits were rewritten or whose head
  was force-removed — can leave no fetchable commits).

### Where to fix

- Credential scope/access: use a credential with **read** access to that repo
  and to **all** the orgs/groups/workspaces of the project's repos on that
  provider. See the `no_credential` entry in `references/troubleshooting.md`.
- Genuinely empty/unusual commit history: nothing to fix in config — this
  PR/MR is correctly excluded because its first commit is unrecoverable.

---

## Setup check: Deployment Frequency count looks incomplete (tag/deploy discipline)

> No anchor: this section is for a human who suspects the number is incomplete,
> not a problem the script can detect on its own.

**What.** Deployment Frequency counts deploy markers (Releases or tags matching
`tag_pattern`) in the window. If a production deploy happened but was **not**
tagged/released per the repo's `deploy_source`, the script has no marker to count
and that deploy is not reflected in the number. This is a measurement/
instrumentation gap, not a statement about the number itself.

**How to check.** If you suspect the count does not reflect every deploy, verify
that **each** production deploy in the window actually produced a marker matching
the repo's configured `deploy_source`:

- `deploy_source: "release"` (GitHub/GitLab only) — a published GitHub Release,
  or a GitLab Release whose `released_at` has passed, whose tag matches
  `tag_pattern`.
- `deploy_source: "tag"` — a git tag whose name matches `tag_pattern` (the
  only option on Bitbucket).

Cross-check the repo's Releases/tags list on the provider against the deploys
you know happened.

**Where to fix.**

- Marker missing for a real deploy: add the missing Release/tag in the repo, or
  align the repo's release process so every prod deploy creates the configured
  marker.
- Marker present but not matching: see the `no_markers_matching_pattern` entry
  in this file.

This is purely a check on whether every deploy is *instrumented*. It does not
comment on how often the repo deploys or whether that cadence is adequate — that
would be interpreting performance, which is out of scope.

---

## Known provider-specific precision gaps

> No anchor: background for a human reading a Lead Time number that looks off
> by a little, or that rests on fewer PRs than expected. Not a problem the
> script surfaces as an issue.

- **GitLab tags:** the script dates a tag by the tag's own `created_at` when the
  API returns one (set for annotated tags, null for lightweight ones) and falls
  back to the target commit's date otherwise. A lightweight GitLab tag created
  well after its commit will read as if it happened at commit time.
- **Bitbucket PR merge time:** Bitbucket Cloud's pull request object has no
  directly exposed "merged at" timestamp. The script uses the merge commit's
  own commit date when available, falling back to the PR's `updated_on`
  otherwise — a reasonable proxy, not as exact as GitHub's Search API or
  GitLab's `merged_after`/`merged_before` filters.
- **Bitbucket deleted source branch or fork:** Bitbucket returns an empty PR
  commit list once the PR's source branch is deleted, and a 404 when the source
  fork is deleted
  (https://api.bitbucket.org/swagger.json, `GET .../pullrequests/{id}/commits`).
  The script then excludes that PR from Lead Time (`pr_first_commit_unfetchable`).
  Teams that delete source branches on merge will see many exclusions, and
  possibly `no data in the window`.

None of these is something `config/projects.json` can fix — they are limits
of what each provider's API reports, documented here so a small discrepancy or
a set of excluded PRs isn't mistaken for a bug.
