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

**Warnings** (`example-org/example-frontend`):

- `Release v1.4.0 has no known prior release — the PR population can't be bounded, it's excluded from the Lead Time.`
  - **What:** this is the earliest deploy the script can see in the repo's
    history for the configured marker, so its Lead Time has no prior deploy to
    bound the PR population against and is excluded. It still counts toward
    Deployment Frequency.
  - **How to check:** confirm it is the earliest Release/tag matching
    `tag_pattern` in the repo.
  - **Where to fix:** nothing to fix — structural, resolves after the next
    deploy. (From `references/troubleshooting.md`.)

> Warnings are process-gap signals this calibration stage is meant to expose,
> not noise to hide — shown verbatim from the script output, with
> measurement-setup guidance from `references/troubleshooting.md` beneath each.

---

<!--
Structure notes for the report-writer (not part of the rendered reply):

- One `## <project name>` section per project measured.
- One table row per repo. Always show BOTH metrics for every repo:
  Deployment Frequency (the count of deploys in the window) and the median
  Lead Time with its n (lead_time_median_hours + lead_time_n from the JSON).
- Header the row with the repo's `type` and `deploy_source` from the JSON.
- State the measurement window once (default 14 days).
- Add a "Warnings" sub-list under a repo ONLY when its `warnings` array is
  non-empty; copy each warning string verbatim. Omit the sub-list when empty.
- Under each warning, add the matching What / How to check / Where to fix
  guidance from `references/troubleshooting.md` (read that file, match by the
  warning text). It is additive to the verbatim text and covers only the
  measurement setup — never whether a number is good or bad.
- If the JSON was saved via --out-dir, mention the path below the report,
  e.g.: "Saved to `outputs/2026-07-06_dora.json`."
- Do NOT add columns, labels, or prose that interpret, rank, score, or compare
  the numbers. Nothing here should say whether a value is good or bad.
-->

Saved to `outputs/2026-07-06_dora.json`.
