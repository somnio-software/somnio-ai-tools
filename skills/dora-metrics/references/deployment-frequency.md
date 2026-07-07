# Spec — Deployment Frequency

> Status: **closed** (illustrative example: Example Project).
> Measurement contract for the fetching skill.

## Attribute
How often a project deploys to production.

## Prod deploy marker (Step 2)
**GitHub Release on a tag with semver format `vX.Y.Z`**, created on each repo's
production branch (`main`). The Release timestamp = the moment of the deploy.
A single convention across the three project types (mobile/web/backend).

## Operational definition
Number of **prod tags** (`vX.Y.Z` on `main`) per project, within a 14-day
window.

## Source
GitHub — tags / Releases of the project's repos (see `../config/proyectos.json`).

## Aggregation level
Per project. **In multi-repo, independent count per repo** (a simultaneous tag
in all of the project's repos is not required): each repo deploys in a decoupled
way, and the project's metric is the sum/series of prod tags from *any* of its
repos. A decision validated with a real multi-repo case (e.g. Example Project:
frontend and backend deploy at different times) — it applies as the general
convention unless a specific project justifies otherwise.

## Window
14 days (biweekly cadence).

## Calculation
`deployment_frequency = count(prod_tags in the window)` per project (summing
tags from all of the project's repos).

## Reporting
**Absolute count per 14-day window** (not normalized). Since the window is
fixed, an absolute count and a weekly rate are equivalent (dividing by 2 is an
interpretation step, not a fetching step) — the raw number is left as is, and
reading the trend is a later step, outside this skill.
*(Proposed as the default; let me know if you'd prefer the skill to deliver
deploys/week directly.)*

## Worked example — Example Project
- Repos: `example-org/example-frontend`, `example-partner-org/example-backend`.
- Prod branch: `main` in both.
- Count: independent per repo.
