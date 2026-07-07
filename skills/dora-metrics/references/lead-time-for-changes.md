# Spec — Lead Time for Changes

> Status: **closed** (illustrative example: Example Project).
> Measurement contract for the fetching skill.

## Attribute
How long a change takes from when it's committed until it reaches production.

## Operational definition
**Median** of (prod tag timestamp − **PR's first commit** timestamp), per PR
included in that deploy, aggregated **per project and per repo**, within a
14-day window.

- **Starting point: the PR's first commit** (not the merge commit). It measures
  the full cycle — development + wait for merge + wait for deploy — not just the
  post-merge stretch. Expected consequence: a higher number, especially in the
  first windows (see Known risk).

## Source
GitHub — commits, PRs, and tags / Releases of the project's repos
(see `../config/proyectos.json`).

## Aggregation level
**Per project and per repo** (not combined). Consistent with the Deployment
Frequency decision: in multi-repo with decoupled deploys (e.g. Example Project:
frontend and backend), a median is reported **per repo**, not a single median
mixing both — this prevents one repo's cycle from distorting the reading of the
other.

## Window
14 days (biweekly cadence).

## Population
PRs merged to `main` since the previous prod tag **of that same repo** (the
changes that went into that deploy).

**PRs with no subsequent tag** (merged but not yet deployed within the window):
they are **excluded** from this window's calculation. They enter the
calculation of the window where the deploy that includes them is actually
tagged. "Now" is not used as a proxy for the end.

## Calculation
For each included PR: `lead_time = prod_tag_ts − first_commit_ts`.
Metric per repo: **median** of those lead times (robust to outliers, not the
average). The project reports one median per repo that makes it up.

## Worked example — Example Project
- Repos: `example-org/example-frontend`, `example-partner-org/example-backend`.
- **2 medians** are reported (one per repo), not a combined one.
- PRs with no subsequent tag: excluded until the tag that includes them exists.

## Known risk
Inflated lead time in the first windows (deploys that batch old changes).
Do not read it as performance until 3-4 clean windows.
