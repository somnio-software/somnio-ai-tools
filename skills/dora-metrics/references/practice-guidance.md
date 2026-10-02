# Practice guidance — engineering practices that move these metrics

> This guide is a **practice catalog**, not a diagnosis of any repo's numbers.
> Every entry here names a general engineering practice and explains how it
> tends to affect Lead Time for Changes or Deployment Frequency **as this
> skill defines and measures them** — never how good or bad a specific run's
> numbers are. The catalog is fixed: the same entries render on every report,
> regardless of any repo's `deployment_frequency`, `lead_time_median_hours`,
> `issues`, or anything else measured. Nothing is selected, filtered,
> reordered, or omitted based on a run's numbers — this guide never says a
> repo *should* adopt a practice, never says a team is doing well or badly,
> and never ranks or compares projects or repos. Interpreting what a specific
> run's numbers mean about a team is a separate, deliberately later step,
> outside this skill's scope (Goodhart's Law).

This file is **machine-read**. Each entry is preceded by an anchor comment
`<!-- code: some_code -->`, immediately followed by a standalone bold title
line (e.g. `**Trunk-based development**`) — bold rather than a `##`/`###`
heading because the `##` level here is already taken by the two dimension
headings, unlike `references/troubleshooting.md`, which is free to give each
entry its own `##` — nested under one of two `##` dimension headings
("Lowering Lead Time for Changes" or "Raising Deployment Frequency"), and
holds three subsections: `### What`, `### Why it helps this metric` and
`### How to adopt it`. The script parses them
(`scripts/practice_guidance.py`) and attaches the whole, unfiltered catalog to
its JSON output under `practice_guidance` — one entry per anchor, every run,
each carrying the title as `title` (empty string if the bold line is missing)
— so the guidance travels with the report instead of being looked up by hand.
Editing the prose here changes what every future report says — that is the
point. Do not rename the subsection headings or the dimension headings, and do
not add or remove an anchor without also updating `PRACTICE_GUIDANCE_CODES` in
`scripts/dora_metrics.py`.

Measurement setup issues (a wrong branch, a missing token scope, a tagging gap
that makes a *number* wrong or missing) belong in
`references/troubleshooting.md`, not here. This file is scoped to practices
that change how the underlying engineering work happens — never to fixing
what the script can or cannot see.

---

## Lowering Lead Time for Changes

<!-- code: trunk_based_development -->
**Trunk-based development**

### What

Developers integrate small changes into the production branch (`main`, per
`repos[].prod_branch`) frequently — at least daily — instead of working for
days or weeks on a long-lived feature branch before merging.

### Why it helps this metric

This skill measures Lead Time from a PR's **first commit** to the timestamp of
the prod tag that follows its merge (`references/lead-time-for-changes.md`).
A long-lived branch pushes its first commit long before the PR that eventually
merges it, so everything committed early sits waiting — inflating the
first-commit-to-merge span that makes up most of the measured interval.
Trunk-based development keeps that span short by construction: work is broken
into changes small enough to merge within a day or two of their first commit,
so the clock this skill starts never has far to run before the PR merges.

### How to adopt it

- Cap how long a branch may live before merging or being closed (a day or two,
  not a sprint).
- Break large pieces of work into a sequence of small PRs that each merge on
  their own, rather than one branch that accumulates all of them.
- Pair trunk-based development with the tag/release automation described
  under `automate_release_tagging` below, so a merge does not then wait on a
  separate, manual step before it can be measured as delivered.

---

<!-- code: small_prs -->
**Keep pull requests small**

### What

Each PR covers one focused change, reviewable in minutes rather than hours,
instead of bundling several unrelated changes into one large PR.

### Why it helps this metric

The population this skill measures is merged PRs into the production branch,
and each one's lead time starts at its first commit
(`references/lead-time-for-changes.md`). A large PR typically accumulates
commits over a longer stretch before anyone opens a review, and then spends
longer in review and rework before merging — both stretches happen entirely
before the merge event, inside the window this skill measures. A small PR
compresses both: less work happens before the first commit is "done enough"
to open, and a small, focused diff is faster for a reviewer to approve.

### How to adopt it

- Scope a PR to one reviewable unit of change; split out unrelated
  refactors, dependency bumps, or follow-up work into their own PRs.
- Open a PR as a draft early and push commits incrementally, rather than
  developing an entire feature locally before the first push.
- Set a soft team norm for a maximum diff size, and treat a PR that exceeds it
  as a signal to split it rather than review it as-is.

---

<!-- code: automate_release_tagging -->
**Automate release tagging**

### What

The prod tag or GitHub Release that marks a deploy is created automatically
by the deploy pipeline, at the moment the deploy happens — not as a separate,
manually-remembered step afterward.

### Why it helps this metric

Lead time's end boundary is the prod tag/Release timestamp, not the moment
code was actually running in production
(`references/deployment-frequency.md`, "Prod deploy marker"). If tagging is a
manual chore that happens whenever someone gets around to it, PRs that merged
and deployed cleanly still show as having a long lead time, because the
marker this skill reads lags behind the real deploy. Automating the tag as
part of the pipeline closes that gap: the marker's timestamp tracks the
actual deploy instead of whenever a human remembered to cut it.

### How to adopt it

- Add a pipeline step that creates the Release or tag as the last action of a
  successful deploy job, using the deploy job's own timestamp.
- Generate the tag name to match the repo's configured `tag_pattern` in
  `config/projects.json` (default `^v\d+\.\d+\.\d+$`), so the automated
  marker is one this skill actually recognizes.
- If releases must stay a curated, human-authored event (release notes,
  changelog), keep that process, but tag on deploy separately per
  `decouple_deploy_from_release_event` below, and treat the curated Release
  as a downstream announcement rather than the deploy marker itself.

---

<!-- code: fast_ci_feedback -->
**Fast, reliable CI feedback**

### What

The test and build pipeline that gates a merge returns a result in minutes,
consistently, rather than tens of minutes or with frequent flaky failures
that need a re-run.

### Why it helps this metric

A PR's lead time clock starts at its first commit and does not stop until the
next prod tag, so the entire stretch a PR spends waiting on CI — including
any re-runs after a flaky failure — falls inside the measured interval. For
most PRs, the pre-merge wait (open, review, CI, fix, re-run) is the bulk of
that stretch. Shortening and stabilizing CI feedback shortens that wait
directly, without changing anything about how the work itself is done.

### How to adopt it

- Track CI run duration and flake rate as their own numbers, separate from
  this skill's output, and treat a rising trend as worth investigating.
- Parallelize the slowest test suites, or split a single monolithic CI job
  into independent jobs that run concurrently.
- Quarantine or fix consistently flaky tests rather than leaving them to
  force re-runs — a re-run adds its full duration again to the PR's wait.

---

<!-- code: feature_flags_over_long_branches -->
**Feature flags instead of long-lived branches**

### What

New functionality merges into `main` behind a flag that keeps it dark for
users, instead of being developed on a separate branch until it is
considered "finished."

### Why it helps this metric

This skill can only measure a PR once it merges into the production branch —
work sitting on an unmerged branch is invisible to it and contributes no
first commit, no merge, and no lead time entry at all. A long-lived branch
therefore does not show up as "slow"; it shows up as nothing, until it
finally merges as one large, old PR whose first commit is far in the past.
Feature flags let the same work land in `main` as a sequence of small,
regularly merged PRs — each one measurable on its own — instead of arriving
as a single delayed merge.

### How to adopt it

- Wrap incomplete or user-facing-risky code in a flag that defaults off, and
  merge behind it rather than branching for the duration of the feature.
- Merge each piece of the feature as its own PR against `main` as soon as it
  is reviewable, rather than waiting for the whole feature to be flag-ready.
- Remove the flag (and the dead code path) in its own small PR once the
  feature is fully rolled out, instead of leaving stale flags to accumulate.

---

## Raising Deployment Frequency

<!-- code: decouple_deploy_from_release_event -->
**Decouple the deploy from the release announcement**

### What

The production deploy of a change and the public "this is now available"
release announcement are treated as two different events, each with its own
marker if needed — rather than one manually-curated Release being the only
signal that anything shipped.

### Why it helps this metric

Deployment Frequency counts prod tags/Releases matching `tag_pattern` on the
production branch within the measurement window
(`references/deployment-frequency.md`). When the only tag created is a
curated, occasional "release," a repo that in fact deployed to production
several times still shows a low count, because most of those deploys created
no marker this skill can see. Tagging (or releasing) at the moment of each
actual deploy — independent of when marketing or product decides to announce
it — makes the marker this skill counts correspond to how often code actually
reached production.

### How to adopt it

- Add a lightweight tag matching `tag_pattern` at deploy time, even for
  deploys that are not separately "announced."
- If the team wants curated Release notes to stay meaningful, keep a
  separate, less frequent published-Release cadence, but ensure the
  `deploy_source` configured in `config/projects.json` for the repo (`"tag"`
  vs `"release"`) points at whichever marker is actually created every
  deploy.
- Confirm the two events are recognizably different in GitHub (e.g. a plain
  tag for every deploy, a published Release only for the ones worth
  announcing) so neither process has to bend to match the other.

---

<!-- code: automate_the_deploy_pipeline -->
**Automate the deploy pipeline end to end**

### What

A production deploy — build, ship, and the tag/Release that marks it — runs
as one automated pipeline triggered by a merge or a manual approval, with no
separate manual step required afterward to record that it happened.

### Why it helps this metric

Every deploy this skill can count depends on a marker (a Release or a tag
matching `tag_pattern`) existing on the production branch
(`references/deployment-frequency.md`). In a manual deploy process, creating
that marker is an extra step a person can skip under time pressure, so real
deploys go uncounted. Folding the marker into the deploy pipeline itself
removes that skip point. It also removes the largest cost of deploying
often — the operator time a manual process demands — which is a precondition
for deploying more frequently in the first place, not a way of gaming the
count.

### How to adopt it

- Build a single pipeline that runs build, tests, deploy, and tag/Release
  creation as one sequence, so none of them can happen without the others.
- Remove manual approval gates that exist only out of habit; keep the ones
  that reflect a real risk decision.
- Make the tag/Release step unconditional on success, so a deploy that
  completes always produces the marker `deploy_source` expects.

---

<!-- code: reduce_batch_size -->
**Reduce deploy batch size**

### What

Each deploy ships a smaller amount of change — ideally close to what a
single merged PR introduces — rather than accumulating many merged PRs into
one larger, periodic deploy.

### Why it helps this metric

Deployment Frequency's operational definition is literally the count of prod
tags/Releases in the 14-day window (`references/deployment-frequency.md`).
Shipping in smaller batches more often raises that count directly, because
each batch produces its own marker rather than several merged PRs sharing
one. Smaller batches are also individually easier to verify and roll back,
which is part of what makes deploying more often sustainable rather than
just more frequent tagging on top of an unchanged process.

### How to adopt it

- Move away from a fixed deploy schedule (e.g. once a week) toward deploying
  whenever a change is ready, if the pipeline and review process can support
  it.
- Avoid queuing multiple merged PRs to ship together "to be efficient" — each
  held-back PR is also held back from being measured.
- Pair this with `automate_the_deploy_pipeline` above: batch size tends to
  grow specifically because deploying is costly: fix that cost first, and
  smaller, more frequent batches become the easier default.
