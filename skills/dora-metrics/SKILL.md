---
name: dora-metrics
description: >
  Fetches the DORA metrics Deployment Frequency and Lead Time for Changes, per
  project and per repo, from the provider's API (GitHub, GitLab, or Bitbucket
  — not local git). Use this skill whenever the user asks to run or update the
  DORA metrics, measure the deployment frequency or lead time of a project
  (e.g. "Example Project"), generate the biweekly metrics report, or asks how
  many deploys a project made or how long a change takes to reach production —
  regardless of which of the three providers the project's repos live on.
  Also trigger on phrases like: "run the DORA metrics", "metrics for
  Example Project", "deployment frequency for [project]", "lead time for
  [project]", "biweekly metrics report", "how many deploys did we do this
  sprint", "add a GitLab/Bitbucket project to the DORA metrics".
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
marker: a **Release with a semver tag `vX.Y.Z`** on each repo's production
branch (a plain tag where the provider has no Releases API), or — for repos
whose integration branch deploys itself on every merge and that publish
neither releases nor tags — **every PR/MR merged into that branch**
(`deploy_source: "merge"`). All data comes
from the repo's **provider API** — never a local git clone — because lead time
depends on the real first commit of each PR/MR, and that is only reliable when
read from the provider's PR/MR object (it stays correct even if the merge was a
squash; the git log of `main` does not guarantee it).

Each repo belongs to one of four supported providers, declared per repo in
`config/projects.json` (`provider`, default `"github"`):

| Provider | Repo identifier format | Deploy marker |
|---|---|---|
| `github` (default) | `org/repo` | GitHub Release, plain tag, or merge |
| `gitlab` | project path, e.g. `group/project` or `group/subgroup/project` | GitLab Release, plain tag, or merge |
| `bitbucket` | `workspace/repo_slug` | Plain tag or merge — Bitbucket Cloud has no Releases API |
| `azure` | `organization/project/repository` (Azure DevOps) | Plain tag or merge — Azure DevOps has no Releases API |

`deploy_source` per repo picks the marker: `"release"` (default on GitHub and
GitLab), `"tag"` (default on Bitbucket and Azure DevOps) or `"merge"`. With
`"merge"` every PR/MR merged into `prod_branch` inside the window is one
deploy, dated by its merge, and its lead time runs from its first commit to
that merge — the right marker for a branch that auto-deploys on every merge
(`develop`, `staging`) with no release or tag ceremony. It changes what the
number means: it is integration/CD cadence, not production releases, so say so
when reporting it.

A single project — and even a single run — can mix providers across repos: a
project's frontend can live on GitHub while its backend lives on GitLab, and
each is measured with its own credential. Bitbucket Server/Data Center,
Azure DevOps Server (on-prem) and GitHub Enterprise beyond `api_base`
overrides are out of scope — this talks to GitHub.com, GitLab.com (or a
self-hosted instance via `api_base`), Bitbucket Cloud and dev.azure.com.

Projects can be mono-repo or multi-repo. In multi-repo, each repo is measured
and reported **independently, never combined**: if a project deploys the
frontend and backend at different times — or on different providers —
merging them into a single number would hide the very signal that calibration
is meant to expose.

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
- Optionally, if saving the result is requested, a file in the folder given by
  `--out-dir`: **one per repo**, a Markdown report
  (`YYYY-MM-DD-<repo>-dora-metrics.md`) with the same
  summary — easy to open and read on its
  own.

  A repo is the unit that gets measured (never combined with its siblings), so
  it is also the unit that gets saved: a multi-repo project produces one
  file per repo, each holding only that repo's numbers. `<repo>` is the repo
  name slugified to kebab-case — `example-org/example-frontend` becomes
  `example-frontend` — and only falls back to the org-qualified
  `example-org-example-frontend` when two repos in the same run share a name.

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
- The repo(s) that make it up, one or several (multi-repo), and **which
  provider each one is on** (`github`, `gitlab`, `bitbucket` or `azure` —
  default `github`, but confirm rather than assume when the user doesn't say).
  The identifier format depends on the provider: `org/repo` for GitHub, a
  project path for GitLab, `workspace/repo_slug` for Bitbucket,
  `organization/project/repository` for Azure DevOps.
- Type of each repo (web / mobile / backend).
- Production branch of each repo (reasonable default: `main`, but
  confirm — do not assume).
- Optional: whether any repo uses plain tags instead of Releases
  (`deploy_source: "tag"`), counts every merge into `prod_branch` as a deploy
  (`deploy_source: "merge"` — for a branch that auto-deploys and has no
  release/tag ceremony), or a `tag_pattern` different from the global one.
  Default: inherits the global `tag_pattern`, and `deploy_source: "release"`
  for github/gitlab — **except Bitbucket and Azure DevOps, which have no
  Releases API and default to `deploy_source: "tag"` (`"release"` is rejected
  there; `"merge"` is fine).**
- Optional: `api_base` for a self-hosted GitHub Enterprise or GitLab instance,
  if the repo isn't on github.com / gitlab.com. Not supported for Bitbucket
  (Cloud only).
- Optional: a short note if there is anything non-obvious about the project
  (e.g. multi-repo across different orgs, deploys decoupled between repos,
  repos split across providers) — goes in a `"notes"` field on the project.
  Not needed if there is nothing particular to call out.

Show the resulting JSON before saving it and ask for confirmation (it is a file
shared by the whole team). Once saved, continue with Step 2 as usual.

### Step 2 — Show the confirmation table

Before calling the API, show a table with what is going to be measured. Unlike
a skill that generates a document (where the table is a mandatory gate before
creating something hard to undo), here it is informational: the skill only
reads data and builds a report, so you can go straight through unless something
stands out (a repo that shouldn't be there, an odd branch). Show it regardless,
so whoever runs it can see at a glance what is being measured. Include the
**Provider** column always — it costs nothing when every repo is GitHub, and is
the whole point when a project mixes providers:

| Project | Repo | Provider | Type | Prod branch | Window |
|---|---|---|---|---|---|
| Example Project | `example-org/example-frontend` | github | web, mobile | main | last 14 days |
| Example Project | `example-partner-org/example-backend` | github | backend | main | last 14 days |

If anything in the table doesn't match what the user expected, stop and ask
before running the script.

### Step 3 — Verify authentication

The script (`scripts/dora_metrics.py`) needs a credential for **every
provider** present in the confirmation table, each with read access to **all**
the orgs/groups/workspaces of that provider's repos in the project (e.g. if
GitHub is multi-org: `example-org` and `example-partner-org`). Precedence
order per provider, automatic:

| Provider | 1st | 2nd |
|---|---|---|
| `github` | `GITHUB_TOKEN` env var | `gh auth token` (logged-in GitHub CLI) |
| `gitlab` | `GITLAB_TOKEN` env var | `glab auth token` (logged-in GitLab CLI) |
| `bitbucket` | `BITBUCKET_TOKEN` env var (bearer) | `BITBUCKET_USERNAME` + `BITBUCKET_APP_PASSWORD` together (no CLI fallback) |
| `azure` | `AZURE_DEVOPS_PAT` env var (a PAT with *Code: Read*) | `az account get-access-token` for the Azure DevOps resource (logged-in Azure CLI) |

A run can mix providers: a repo whose provider has no resolvable credential is
reported as `measured: false` with a `no_credential` problem (same shape as any
other unmeasurable repo), **while every repo on a provider that does have a
credential still measures normally.** Only when *no* provider in the table has
a credential does the script skip measuring altogether and produce a single
report carrying that one problem — still exits with code 1, still produces
output (and saves it, if `--out-dir` was passed).

Report missing credentials like any other problem — do not ask the user to
paste a token in the chat if the flow is Cowork; in local Claude Code, suggest
`gh auth login` / `glab auth login` / `az login` if they haven't done it
(Bitbucket has no CLI login to suggest — point at the env vars instead).

### Step 4 — Run the script

```bash
pip install requests --break-system-packages   # if needed

python3 scripts/dora_metrics.py --project "Example Project" --out-dir reports
```

Available flags:
- `--config`: path to the config (default: `config/projects.json`).
- `--project`: exact project name (default: runs all projects in the config).
- `--out-dir`: if passed, in addition to printing to stdout it saves one
  file per repo there — `YYYY-MM-DD-<repo>-dora-metrics.md` (the same summary as a readable
  file). Note this selects **where** to save, while `--project` selects **what**
  to measure; the file name comes from the repo, not from the project.
- `--branch <branch>`: one-off override of `prod_branch` for this run
  (requires `--project`). Does not modify the config — use only for one-off
  tests against a branch different from the configured one.
- `--deploy-source {release,tag,merge}`: one-off override of `deploy_source`
  (requires `--project`). Does not modify the config.
- `--provider {github,gitlab,bitbucket,azure}`: one-off override of `provider`
  (requires `--project`). Does not modify the config — applies to every repo
  in that project, so it's only useful for a single-provider project.
- `--window-days N`: one-off override of the window in days. Does not modify
  the config.

Exit code 1 does not mean the run failed: it means something could not be
measured (`impact: blocked`), and the report was still produced — read it from
stdout (or the saved files) and report it to the user exactly as Step 5
describes, the same as any other problem. Do not treat a non-zero exit code
from Bash as a reason to discard the output or tell the user the run failed.
The only case that produces no report at all is a usage error — an unknown
`--project`, `--branch`/`--deploy-source`/`--provider` passed without
`--project`, an invalid `deploy_source` or `provider`, `deploy_source:
"release"` on a bitbucket or azure repo, an azure repo not written as
`organization/project/repository`, or `api_base` on a bitbucket repo — which
prints an error to stderr and exits 1 before anything is measured.

`config/projects.json` field reference (also documented in `README.md` for a
human opening the folder, but summarized here so this skill is self-contained
even if only `SKILL.md` itself made it into an install):

| Field | Level | Default if omitted | What it is |
|---|---|---|---|
| `tag_pattern` | global | — (required) | Regex the tag must match to count as a deploy. |
| `window_days` | global | — (required) | Measurement window in days. |
| `projects[].name` | project | — (required) | Name the project is looked up by (case-insensitive). |
| `projects[].notes` | project | none | Free text: rationale or clarifications specific to that project. |
| `repos[].repo` | repo | — (required) | Repo identifier, format depends on `provider`: `org/repo` (github), project path (gitlab), `workspace/repo_slug` (bitbucket). |
| `repos[].provider` | repo | `"github"` | `"github"`, `"gitlab"`, or `"bitbucket"`. |
| `repos[].type` | repo | `[]` | Informational list (web/mobile/backend), only used for display in the output. |
| `repos[].prod_branch` | repo | — (required) | Production branch of that repo. |
| `repos[].deploy_source` | repo | `"release"` (github/gitlab), `"tag"` (bitbucket) | `"release"` = Release with a semver tag (not available on Bitbucket). `"tag"` = plain tag with no Release, for projects that tag but don't publish Releases. |
| `repos[].tag_pattern` | repo | the global `tag_pattern` | Override if that specific repo uses a different tag format (e.g. with a build number). |
| `repos[].api_base` | repo | the provider's public API root | Self-hosted GitHub Enterprise or GitLab instance's API root. Not supported for bitbucket (Cloud only). |

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
- The script diagnoses the repo's setup while it measures: whether the
  credential can see the repo, whether `prod_branch` exists, whether there are
  deploy markers and whether they match `tag_pattern` or the configured
  `deploy_source`. Every problem found comes back in `issues` with its
  remediation steps already attached, read from `references/troubleshooting.md`.
  The `report-writer` renders each `message` **verbatim** with its steps
  beneath — problems (impact `blocked`/`partial`) and notes (impact `none`)
  under separate headings. It never looks anything up and never writes steps of
  its own: an issue with `guidance: null` is reported as having no guidance.
  These are process-gap signals this calibration stage is meant to expose, not
  noise to hide, and the steps stay strictly on the measurement-setup side —
  they never comment on whether a number is good or bad.
- A repo the script could not measure at all comes back with `measured: false`
  and no metric fields. Report it as such, with its problems — never omit the
  repo or substitute a zero.
- If the file was saved, say where it ended up (the `.md` for every repo), in addition to reporting the values.
- The result also carries a fixed, root-level `practice_guidance` catalog —
  engineering practices that move Lead Time for Changes or Deployment
  Frequency in general, never a judgment of this run's numbers
  (`references/practice-guidance.md` is the source of truth; the script
  attaches the whole catalog unfiltered, the same entries on every run). The
  `report-writer` renders it as a **mandatory "How to improve these
  metrics"** section, **once per report — never once per repo** — placed
  after the last project section, grouped by `dimension`, each entry
  verbatim from the JSON. This section appears even on a run where nothing
  could be measured, because it is not about this run's data. It never
  selects, filters, reorders, or omits an entry based on what was measured,
  and never adds practice advice of its own; if `practice_guidance` is
  missing or empty, it still renders the heading with an explicit line
  saying no guidance was available and naming
  `references/practice-guidance.md`, never inventing entries.

---

## Maintaining the config

`config/projects.json` is the **single source of truth** for the project →
repos mapping — there is no separate doc to keep in sync. New projects are
added via Step 1 of this workflow (a conversation with the user), or by editing
the JSON directly. The skill does not infer the mapping on its own: if it's
missing, it asks.

## Known limitations (pilot)

- A repo's first historical Release: excluded from the Lead Time calculation
  (there is no way to bound the PR/MR population before it).
- GitHub only: uses the Search API (lower rate limits than the regular REST
  API); with 1-2 projects it shouldn't be an issue, but scaling to more
  projects may require batching/caching. GitLab and Bitbucket don't have this
  particular asymmetry, but Bitbucket has its own cost below.
- Lead time will come out high on the first runs — expected during
  calibration, do not read it as performance until 3-4 clean windows.
- `deploy_source: "tag"`: if the tag/release is created 1-2 seconds after the
  merge (e.g. a pipeline that auto-tags), a PR/MR can end up excluded or
  misattributed to the next interval. See the detail in the docstring of
  `scripts/dora_metrics.py`. Irrelevant with real cadences (days/weeks).
- The setup diagnosis costs 2 extra REST calls per repo (repo + branch
  existence checks), plus 2 more only when a repo produced no deploy marker
  and the script needs evidence to explain why. These are cheap REST calls,
  not the rate-limited Search API (GitHub only).
- GitLab self-hosted: `merged_after`/`merged_before` filtering on the merge
  requests list requires GitLab >= 13.1; an older instance may need an
  upgrade for Lead Time to measure correctly.
- GitLab tags: the API exposes only the target commit's date, not a separate
  "tag creation" date (GitHub distinguishes an annotated tag's own tagging
  date from the commit's date; GitLab does not).
- Bitbucket: no Releases API at all — every Bitbucket repo measures via plain
  tags (`deploy_source` is forced to `"tag"`). Its pull request object also
  has no direct "merged at" timestamp; the script uses the merge commit's date
  when available, falling back to the PR's `updated_on` otherwise — a
  reasonable proxy, less exact than GitHub/GitLab. Measuring Lead Time also
  costs more API calls on Bitbucket than on GitHub/GitLab, since there is no
  server-side "merged between these dates" filter to push the window down to
  the provider.
- Bitbucket Server/Data Center and GitHub Enterprise are out of scope beyond
  the `api_base` override for GitHub Enterprise; Bitbucket is Cloud-only.
- E2E tests (`tests/e2e/`) currently cover the GitHub path only — GitLab and
  Bitbucket are covered by unit tests with mocked HTTP responses, not a live
  end-to-end run.

## Important notes

- This skill **only fetches and reports**. It never interprets, ranks, or
  compares people — mixing fetching with evaluation contaminates the data
  (Goodhart's Law).
- Multi-repo: each repo is measured and reported independently, never combined
  — including when the repos are on different providers.
- Single source: the repo's own provider API (GitHub, GitLab, or Bitbucket).
  Never read from the cloned repo's local `.git`.
- If the requested project isn't in `config/projects.json`, don't invent it —
  ask for the details and add it (Step 1), never assume repos, branches, or
  provider.
- A repo whose provider has no resolvable credential is reported as
  `measured: false` with a `no_credential` problem — it does not block the
  rest of the run when other repos are on a provider that does have one.
