---
name: dora-metrics
description: >
  Fetches the DORA metrics Deployment Frequency and Lead Time for Changes, per
  project and per repo, from GitHub (API, not local git). Use this skill
  whenever the user asks to run or update the DORA metrics, measure the
  deployment frequency or lead time of a project (e.g. "Example Project"),
  generate the biweekly metrics report, or asks how many deploys a project made
  or how long a change takes to reach production.
  Also trigger on phrases like: "run the DORA metrics", "metrics for
  Example Project", "deployment frequency for [project]", "lead time for
  [project]", "biweekly metrics report", "how many deploys did we do this
  sprint".
allowed-tools: Read, Write, Edit, Bash, Agent
---

# DORA Metrics — Deployment Frequency & Lead Time for Changes

> This skill **only fetches and aggregates the data** — it does not interpret,
> rank, or compare people or projects against one another. That is a separate,
> later step, outside the scope of this skill.

## Context

Two DORA metrics are measured per project: **Deployment Frequency** (how often
we deploy to prod) and **Lead Time for Changes** (how long a change takes to
reach prod). This is the **calibration** stage: the goal is for the team to
have a consistent number they can act on themselves — not one used to evaluate
people. Fetching the data and interpreting it are deliberately separate steps:
the moment a metric is used to evaluate people, it stops being a good metric
(Goodhart's Law).

CI is uniform (GitHub Actions) but CD is heterogeneous (mobile/web/backend
deploy differently), so instead of measuring the actual CD we use a uniform
marker: a **GitHub Release with a semver tag `vX.Y.Z`** on each repo's
production branch. All data comes from the **GitHub API** — never a local git
clone — because lead time depends on the real first commit of each PR, and that
is only reliable when read from the GitHub PR object (it stays correct even if
the merge was a squash; the git log of `main` does not guarantee it).

Projects can be mono-repo or multi-repo. In multi-repo, each repo is measured
and reported **independently, never combined**: if a project deploys the
frontend and backend at different times, merging them into a single number
would hide the very signal that calibration is meant to expose.

Formal definitions of each metric (attribute, population, exact calculation):
`references/deployment-frequency.md` and `references/lead-time-for-changes.md`.

## Input

- **Project name** (e.g. "Example Project"). If the user does not specify one,
  run all projects in `config/projects.json`.
- Measurement window: fixed at 14 days by default (config `window_days`) — do
  not ask for it unless the user explicitly wants something else.

## Output

- Human-readable console summary, per project and per repo: deployment
  frequency, median lead time, and edge-case warnings.
- Optionally, if saving the result is requested, two files in the folder
  given by `--out-dir`: a portable JSON (`YYYY-MM-DD_dora.json`) and a
  Markdown report with the same summary (`YYYY-MM-DD_dora.md`) — easy to
  open and read on its own, without re-parsing the JSON.

---

## Workflow

### Step 1 — Identify the project(s)

Read `config/projects.json`. Look up the requested project by name
(case-insensitive).

**If the project is not in the config**: do not invent repos or assume a
mapping. Instead of stopping and sending the user off to edit a separate file,
ask them directly for the missing details and add them to
`config/projects.json` yourself:

- Project name.
- The GitHub repo(s) that make it up (`org/repo`), one or several (multi-repo).
- Type of each repo (web / mobile / backend).
- Production branch of each repo (reasonable default: `main`, but
  confirm — do not assume).
- Optional: whether any repo uses plain tags instead of GitHub Releases
  (`deploy_source: "tag"`), or a `tag_pattern` different from the global one.
  Default: inherits `deploy_source: "release"` and the global `tag_pattern` if
  nothing is specified.
- Optional: a short note if there is anything non-obvious about the project
  (e.g. multi-repo across different orgs, deploys decoupled between repos) —
  goes in a `"notes"` field on the project. Not needed if there is nothing
  particular to call out.

Show the resulting JSON before saving it and ask for confirmation (it is a file
shared by the whole team). Once saved, continue with Step 2 as usual.

### Step 2 — Show the confirmation table

Before calling the API, show a table with what is going to be measured. Unlike
a skill that generates a document (where the table is a mandatory gate before
creating something hard to undo), here it is informational: the skill only
reads data and builds a report, so you can go straight through unless something
stands out (a repo that shouldn't be there, an odd branch). Show it regardless,
so whoever runs it can see at a glance what is being measured:

| Project | Repo | Type | Prod branch | Window |
|---|---|---|---|---|
| Example Project | `example-org/example-frontend` | web, mobile | main | last 14 days |
| Example Project | `example-partner-org/example-backend` | backend | main | last 14 days |

If anything in the table doesn't match what the user expected, stop and ask
before running the script.

### Step 3 — Verify authentication

The script (`scripts/dora_metrics.py`) needs a GitHub credential with read
access to **all** the orgs of the project's repos (e.g. if it's multi-org:
`example-org` and `example-partner-org`). Precedence order, automatic:

1. `GITHUB_TOKEN` environment variable.
2. `gh auth token` — if the GitHub CLI is already logged in locally, there is
   nothing to ask for or paste.

If neither is available, the script will say so explicitly when it runs (it
does not fail silently). In that case, explain the two options to the user — do
not ask them to paste a token in the chat if the flow is Cowork; in local
Claude Code, suggest `gh auth login` if they haven't done it.

### Step 4 — Run the script

```bash
pip install requests --break-system-packages   # if needed

python3 scripts/dora_metrics.py --project "Example Project" --out-dir outputs
```

Available flags:
- `--config`: path to the config (default: `config/projects.json`).
- `--project`: exact project name (default: runs all projects in the config).
- `--out-dir`: if passed, in addition to printing to stdout it saves
  `YYYY-MM-DD_dora.json` (portable data) and `YYYY-MM-DD_dora.md` (the same
  summary as a readable file) there.
- `--branch <branch>`: one-off override of `prod_branch` for this run
  (requires `--project`). Does not modify the config — use only for one-off
  tests against a branch different from the configured one.
- `--deploy-source {release,tag}`: one-off override of `deploy_source`
  (requires `--project`). Does not modify the config.
- `--window-days N`: one-off override of the window in days. Does not modify
  the config.

`config/projects.json` field reference (also documented in `README.md` for a
human opening the folder, but summarized here so this skill is self-contained
even if only `SKILL.md` itself made it into an install):

| Field | Level | Default if omitted | What it is |
|---|---|---|---|
| `tag_pattern` | global | — (required) | Regex the tag must match to count as a deploy. |
| `window_days` | global | — (required) | Measurement window in days. |
| `projects[].name` | project | — (required) | Name the project is looked up by (case-insensitive). |
| `projects[].notes` | project | none | Free text: rationale or clarifications specific to that project. |
| `repos[].repo` | repo | — (required) | GitHub `org/repo`. |
| `repos[].type` | repo | `[]` | Informational list (web/mobile/backend), only used for display in the output. |
| `repos[].prod_branch` | repo | — (required) | Production branch of that repo. |
| `repos[].deploy_source` | repo | `"release"` | `"release"` = GitHub Release with a semver tag. `"tag"` = plain tag with no Release, for projects that tag but don't publish Releases. |
| `repos[].tag_pattern` | repo | the global `tag_pattern` | Override if that specific repo uses a different tag format (e.g. with a build number). |

### Step 5 — Report

Do not improvise the human-readable summary yourself. Dispatch the
`report-writer` subagent (via the Agent tool), passing it the JSON the script
printed to stdout (and the saved file paths, if `--out-dir` was used), and have
it render the reply following `assets/report-template.md`.

**Model to dispatch with (parametrizable):** by default dispatch the
`report-writer` with `model: sonnet`. If the user explicitly asks for something
faster or cheaper, use `model: haiku`. If they explicitly ask for something
more thorough, use `model: opus`. Do not switch models on your own — only in
response to an explicit request.

The `report-writer` formats numbers only; it never interprets, ranks, scores,
or compares projects, repos, or people. The rules it must follow (and that this
step guarantees) are:

- **Always reply in the chat with the two values directly** (Deployment
  Frequency and median Lead Time) for each repo, even if the JSON is also
  saved — never replace the reply with a bare "I saved the file, check it
  there".
- Show the numbers exactly as the script produced them — do not reinterpret or
  rank them, that is a later step, outside the scope of this skill.
- If there were `warnings` in the output (a release with no prior release, a PR
  with no recoverable commits, 0 PRs in the range), show them **verbatim**:
  they are a sign of process gaps, exactly what this calibration stage is meant
  to expose, not noise to hide. In addition to the verbatim text, the
  `report-writer` consults `references/troubleshooting.md` and, under each
  warning it renders, includes that reference's **What / How to check / Where to
  fix** guidance so whoever ran the skill can check or fix the measurement setup
  without asking the maintainers. This is additive — the raw warning still shows
  exactly as the script produced it — and the guidance stays strictly on the
  measurement-setup side (wrong branch, missing token scope, tagging setup); it
  never comments on whether a number is good or bad. The `report-writer` (the
  subagent rendering the final reply) is responsible for this lookup.
- If the files were saved, say where they ended up (both the `.json` and the
  `.md`), in addition to reporting the values.

---

## Maintaining the config

`config/projects.json` is the **single source of truth** for the project →
repos mapping — there is no separate doc to keep in sync. New projects are
added via Step 1 of this workflow (a conversation with the user), or by editing
the JSON directly. The skill does not infer the mapping on its own: if it's
missing, it asks.

## Known limitations (pilot)

- A repo's first historical Release: excluded from the Lead Time calculation
  (there is no way to bound the PR population before it).
- Uses GitHub's Search API (lower rate limits than the regular REST API); with
  1-2 projects it shouldn't be an issue, but scaling to more projects may
  require batching/caching.
- Lead time will come out high on the first runs — expected during
  calibration, do not read it as performance until 3-4 clean windows.
- `deploy_source: "tag"`: if the tag/release is created 1-2 seconds after the
  merge (e.g. a pipeline that auto-tags), a PR can end up excluded or
  misattributed to the next interval. See the detail in the docstring of
  `scripts/dora_metrics.py`. Irrelevant with real cadences (days/weeks).

## Important notes

- This skill **only fetches and reports**. It never interprets, ranks, or
  compares people — mixing fetching with evaluation contaminates the data
  (Goodhart's Law).
- Multi-repo: each repo is measured and reported independently, never combined.
- Single source: the GitHub API. Never read from the cloned repo's local
  `.git`.
- If the requested project isn't in `config/projects.json`, don't invent it —
  ask for the details and add it (Step 1), never assume repos or branches.
