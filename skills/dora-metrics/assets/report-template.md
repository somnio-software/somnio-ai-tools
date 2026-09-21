# DORA Metrics — Deployment Frequency & Lead Time for Changes

> These are **raw numbers only**. This report does not interpret, rank, score,
> or compare projects, repos, or people. Interpretation is a separate, later
> step, outside the scope of this skill.

**Measurement window:** last 14 days

---

## Example Project

| Repo | Type | Deploy source | Deployment Frequency (14d) | Median Lead Time |
|---|---|---|---|---|
| `example-org/example-frontend` | web, mobile | release | 2 | 4.3h (n=3) |
| `example-partner-org/example-backend` | backend | release | 1 | 11.7h (n=2) |

**Problems found and how to fix them** (`example-org/example-frontend`):

- `example-org/example-frontend: 3 published Releases found, none matching tag_pattern '^v\d+\.\d+\.\d+$' — no deploy marker was counted.`
  - **What:** Releases or tags exist, but none of their names match the
    `tag_pattern` regex, so none was counted as a deploy.
  - **How to check:** Compare the names in the evidence
    (`release-2026-07-01`, `release-2026-07-14`) with the `tag_pattern` in
    `config/projects.json`.
  - **Where to fix:** Set `repos[].tag_pattern` for that repo to a regex
    matching its real naming.

**Notes** (`example-partner-org/example-backend`):

- `example-partner-org/example-backend: 0 deploys in the window. 4 deploy marker(s) exist in history, the most recent on 2026-06-02T10:00:00Z.`
  - **What:** This is a fact about the window, not a setup problem.
  - **Where to fix:** Nothing to fix.

> Problems and notes come straight from the script's `issues`, message verbatim
> with the steps the script already attached from `references/troubleshooting.md`.
> Never add steps that are not in the JSON.

---

## How to improve these metrics

> The following is a fixed catalog of engineering practices — the same
> entries every run, not an assessment of the numbers above.

### Lowering Lead Time for Changes

**Trunk-based development**

#### What

Developers integrate small changes into the production branch (`main`, per
`repos[].prod_branch`) frequently — at least daily — instead of working for
days or weeks on a long-lived feature branch before merging.

#### Why it helps this metric

This skill measures Lead Time from a PR's first commit to the timestamp of
the prod tag that follows its merge. A long-lived branch pushes its first
commit long before the PR that eventually merges it, inflating the measured
interval. Trunk-based development keeps that span short by construction.

#### How to adopt it

- Cap how long a branch may live before merging or being closed.
- Break large pieces of work into a sequence of small PRs that each merge on
  their own.

*(…and so on for the remaining `lead_time` entries in `practice_guidance`.)*

### Raising Deployment Frequency

**Decouple the deploy from the release announcement**

#### What

The production deploy of a change and the public "this is now available"
release announcement are treated as two different events, each with its own
marker if needed.

#### Why it helps this metric

Deployment Frequency counts prod tags/Releases matching `tag_pattern` on the
production branch within the measurement window. When the only tag created is
a curated, occasional "release," several real deploys go uncounted.

#### How to adopt it

- Add a lightweight tag matching `tag_pattern` at deploy time, even for
  deploys that are not separately "announced."
- Keep a separate, less frequent published-Release cadence if curated notes
  still matter, but make sure `deploy_source` points at whichever marker is
  created on every deploy.

*(…and so on for the remaining `deployment_frequency` entries in
`practice_guidance`.)*

> This section is rendered **once per report, after every project section** —
> never once per repo. Every entry comes from the JSON's root-level
> `practice_guidance` list, verbatim, grouped by `dimension`. It is
> **mandatory**, including on a run where nothing could be measured: it is
> about engineering practice in general, never about this run's numbers. If
> `practice_guidance` is missing or empty, the heading still renders, with an
> explicit line saying no guidance was available and naming
> `references/practice-guidance.md` — never invented entries, never a
> silently dropped section.

---

<!--
Structure notes for the report-writer (not part of the rendered reply):

- One `## <project name>` section per project measured.
- One table row per repo. Always show BOTH metrics for every repo:
  Deployment Frequency (the count of deploys in the window) and the median
  Lead Time with its n (lead_time_median_hours + lead_time_n from the JSON).
- Header the row with the repo's `type` and `deploy_source` from the JSON.
- State the measurement window once (default 14 days).
- Add a "Problems found and how to fix them" sub-list under a repo when it has
  issues with impact blocked/partial, and a "Notes" sub-list for impact none.
  Copy each `message` verbatim and render its `guidance` beneath it. Do NOT look
  anything up — the guidance is already in the JSON. If `guidance` is null, say
  there is none.
- Root-level `issues` (no credential, etc.) render before any project section.
- A repo with `measured: false` has no metric fields: render its problems only.
- If the JSON was saved via --out-dir, mention the path below the report,
  e.g.: "Saved to `reports/2026-07-06-example-frontend-dora-metrics.md`."
  There is one file per repo, so list each one.
- Do NOT add columns, labels, or prose that interpret, rank, score, or compare
  the numbers. Nothing here should say whether a value is good or bad.
- MANDATORY: a "How to improve these metrics" section, once per report (never
  once per repo), placed after the last project section. Render the
  root-level `practice_guidance` list verbatim, grouped by `dimension`
  ("Lowering Lead Time for Changes" for `lead_time`, "Raising Deployment
  Frequency" for `deployment_frequency`). This section appears even on a run
  where nothing could be measured — it is not about this run's data. Never
  select, filter, reorder, shorten, or omit an entry based on the run's
  results, and never add practice advice that is not in the JSON. If
  `practice_guidance` is missing or empty, still render the heading, with an
  explicit line saying no guidance was available and naming
  `references/practice-guidance.md` — never invent entries, never silently
  drop the section.
-->

Saved to `reports/2026-07-06-example-frontend-dora-metrics.md`.
