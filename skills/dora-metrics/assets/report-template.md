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
  e.g.: "Saved to `reports/2026-07-06-example-frontend-dora-metrics.json`."
  There is one pair of files per repo, so list each one.
- Do NOT add columns, labels, or prose that interpret, rank, score, or compare
  the numbers. Nothing here should say whether a value is good or bad.
-->

Saved to `reports/2026-07-06-example-frontend-dora-metrics.json`.
