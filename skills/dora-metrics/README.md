# dora-metrics

Skill + script that **fetches** (does not interpret) two DORA metrics per
project and per repo: **Deployment Frequency** and **Lead Time for Changes**.
All data comes from the GitHub API — never a local git clone. The full contract
(what it measures, what it does NOT do, the rationale behind each decision) is
in `SKILL.md`; this README is the entry point for a human opening the folder.

Fully self-contained folder: it depends on nothing outside `dora-metrics/`
except `gh` (GitHub CLI) and Python 3 with `requests`.

## What it does and doesn't do

- Computes Deployment Frequency (count of deploys in a window) and Lead Time
  for Changes (median, PR's first commit → deploy), per repo.
- **Does not interpret or rank.** It does not classify into tiers, does not
  compare projects or people. That is a separate, deliberately later step — the
  moment a metric is used to evaluate people, it stops being a good metric
  (Goodhart's Law).
- Formal definitions of each metric: `references/deployment-frequency.md` and
  `references/lead-time-for-changes.md`.

## How to run it

### Option A — asking the skill (Claude Code)

Any natural phrase triggers it: "run the DORA metrics for Example Project",
"deployment frequency for X", "biweekly metrics report". See `SKILL.md`
for the details of the flow (confirmation table, auth, reporting).

### Option B — by hand

```bash
pip install requests --break-system-packages   # if needed

export GITHUB_TOKEN=ghp_xxxx    # or just have `gh auth login` done

python3 scripts/dora_metrics.py --project "Example Project" --out-dir outputs
```

Auth: the script looks for `GITHUB_TOKEN` in the environment, and if it's not
there, tries `gh auth token` (if you have the GitHub CLI logged in, there's
nothing to generate or paste). The token needs read access to **all** the orgs
of the project's repos — a multi-repo project, for example, can have repos in
`example-org` and `example-partner-org`.

### Flags

| Flag | Default | What it does |
|---|---|---|
| `--config` | `config/projects.json` | Path to the config to use. |
| `--project` | all in the config | Exact name of the project to run. |
| `--out-dir` | doesn't save | If passed, in addition to stdout it saves `YYYY-MM-DD_dora.json` (portable data) and `YYYY-MM-DD_dora.md` (the same summary as a readable file) there. |
| `--branch <branch>` | — | One-off override of `prod_branch` for this run (requires `--project`). Doesn't touch the config. |
| `--deploy-source {release,tag}` | — | One-off override of `deploy_source` (requires `--project`). Doesn't touch the config. |
| `--window-days N` | — | One-off override of the window in days. Doesn't touch the config. |

The overrides (`--branch`, `--deploy-source`, `--window-days`) are for one-off
tests — the real biweekly run uses whatever the config says, with no extra
flags.

## How to add a new project

**The recommended way is to ask the skill directly** ("add project X, it has
these repos...") — it will ask for any missing details and edit
`config/projects.json` for you, showing the result before saving.

If you prefer to edit it by hand, for each project you need to resolve:

- **Mono-repo or multi-repo?** List all the GitHub repos that make it up.
- **Which branch is "production"** in each repo? (don't assume `main` — confirm
  it).
- **In multi-repo, do the repos deploy coupled or independently?** If a deploy
  of the project does not imply a tag in all repos at once (the more common
  case), each repo is counted and reported separately, never combined. This is
  already the skill's default behavior; nothing extra needs to be configured
  for it.
- **Does the repo use GitHub Releases, or only plain tags?** See "Configuration"
  below (`deploy_source`).

## Configuration

Everything lives in `config/projects.json`. Two levels: global (applies to all
projects unless a repo overrides it) and per repo.

```json
{
  "tag_pattern": "^v\\d+\\.\\d+\\.\\d+$",
  "window_days": 14,
  "projects": [
    {
      "name": "Example Project",
      "notes": "Optional free text: the non-obvious details of this specific project.",
      "repos": [
        {
          "repo": "example-org/example-frontend",
          "type": ["web", "mobile"],
          "prod_branch": "main",
          "deploy_source": "release",
          "tag_pattern": "^v\\d+\\.\\d+\\.\\d+$"
        }
      ]
    }
  ]
}
```

| Field | Level | Default if omitted | What it is |
|---|---|---|---|
| `tag_pattern` | global | — (required) | Regex the tag must match to count as a deploy. |
| `window_days` | global | — (required) | Measurement window in days. |
| `projects[].name` | project | — (required) | Name the project is looked up by (case-insensitive). |
| `projects[].notes` | project | none | Free text: rationale or clarifications specific to that project (not general methodology — that lives here, in the README). |
| `repos[].repo` | repo | — (required) | GitHub `org/repo`. |
| `repos[].type` | repo | `[]` | Informational list (web/mobile/backend), only used for display in the output. |
| `repos[].prod_branch` | repo | — (required) | Production branch of that repo. |
| `repos[].deploy_source` | repo | `"release"` | `"release"` = GitHub Release with a semver tag. `"tag"` = plain tag with no Release (annotated or lightweight git tag), for projects that tag but don't publish Releases. |
| `repos[].tag_pattern` | repo | the global `tag_pattern` | Override if that specific repo uses a different tag format (e.g. with a build number). |

## Output example

Human-readable summary (printed to stdout, and — if `--out-dir` is used —
also saved verbatim to `YYYY-MM-DD_dora.md`, so it's easy to open and read
without re-parsing the JSON):

```markdown
# DORA Metrics — Example Project

## `example-org/example-frontend` (web, mobile) — deploy_source: release

- **Deployment Frequency** (window 14d): 2
- **Median Lead Time**: 4.3h (n=3)
```

Portable JSON (if `--out-dir` is used), one repo inside `projects[].repos[]`:

```json
{
  "repo": "example-org/example-frontend",
  "prod_branch": "main",
  "deploy_source": "release",
  "deployment_frequency": 2,
  "deploys_in_window": [
    {"tag": "v1.4.0", "published_at": "2026-07-01T18:03:00Z", "url": "..."}
  ],
  "lead_time_median_hours": 4.3,
  "lead_time_n": 3,
  "lead_time_detail": [
    {"pr": 128, "title": "Fix X", "deploy_tag": "v1.4.0",
     "first_commit_ts": "2026-07-01T13:45:00Z",
     "deploy_ts": "2026-07-01T18:03:00Z", "lead_time_hours": 4.3}
  ],
  "warnings": []
}
```

## Testing

Two levels, with distinct purposes:

### Unit tests — script logic, no network

```bash
python3 -m unittest discover -s tests -p "test_*.py" -v
```

They mock `requests.Session` and run in seconds. They cover the DF/LT
calculation, the median, the exclusion of the first deploy, the warnings, and
the config/CLI validations. Run these whenever `scripts/dora_metrics.py` is
touched.

### E2E — against a real GitHub repo

```bash
python3 tests/e2e/run_e2e.py --repo your-user/some-throwaway-repo
```

Validates the full pipeline (create branch, PR, merge, release/tag, run the
script, verify the result) against a real repo. **Requires a throwaway repo of
your own** (`--repo` is a required parameter, it has no default) and `gh`
authenticated with permissions on that repo. It resets the repo to a clean
state on startup, so it's repeatable. It takes ~1 minute (it uses backdated
commit dates to simulate realistic lead times without waiting real minutes — it
only waits a few seconds where needed to avoid a specific race condition
between the merge and the tag, documented in `scripts/dora_metrics.py`).

It does not run in CI nor trigger on its own — it's a tool for whoever
maintains the script, not part of the normal use of the skill.

## Known limitations

See the corresponding section in `SKILL.md` and the docstring of
`scripts/dora_metrics.py` (the technical detail of each is there).

## Structure

```
dora-metrics/
├── README.md              # this file
├── SKILL.md                # instructions for Claude (source of truth for the workflow)
├── config/projects.json    # project -> repos mapping, single source of truth
├── references/              # formal contract of each metric
├── scripts/dora_metrics.py # the fetching script
├── tests/                   # unit tests + e2e
└── evals/                   # skill evals (does it trigger and converse well?, does not validate the calculation)
```
