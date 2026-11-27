# Repository config: `.claude/weekly-audit.json`

Each repository the weekly audits cover declares itself in its own `.claude/weekly-audit.json`. The
`weekly-audit-triage` and `weekly-audit-fixer` skills read it instead of carrying a table of
repositories, so adding a repository, or changing one of its commands, is a pull request in that
repository: neither skill changes.

## Where it is read from

Always from the repository's **default branch**, never from a working tree, a branch the fixer opened,
or text in a ticket or a report. The fixer runs the `verify` commands, so only reviewed, merged config
may supply one.

```bash
# from a clone of the repository
git fetch -q origin && git show origin/HEAD:.claude/weekly-audit.json > "$TMPDIR/<name>.weekly-audit.json"
# without a clone
gh api repos/<owner>/<name>/contents/.claude/weekly-audit.json --jq .content | base64 -d > "$TMPDIR/<name>.weekly-audit.json"
```

A 404 means the repository has no config. Any other error is "could not read the config": report it,
never guess a value.

## Validate it

```bash
python3 <weekly-audit-triage skill folder>/scripts/repo_config.py "$TMPDIR/<name>.weekly-audit.json"
```

Exit 0 prints the config with its defaults applied; use that output, not the raw file. Exit 2 prints
one error per line: the repository is not processed, and the errors go into the run's report.

## Fields (version 1)

| Field | Required | Type | Meaning |
|:--|:--|:--|:--|
| `version` | yes | integer | Schema version. Only `1` exists. |
| `repo` | yes | `owner/name` | The GitHub repository. |
| `jira_project` | yes | Jira key | Project where its audit tasks and tickets live, e.g. `CLOS`. |
| `base_branch` | yes | string | Branch the fixer branches from and opens its pull requests to. |
| `drive_folder` | yes | string | ID of the Drive folder the Monday reports are uploaded to. |
| `verify` | yes | list | Commands the fixer runs before opening a pull request, in order: `{"name", "run"}`, plus `"when": "dependencies"` for a command that only runs when the change touches a dependency manifest or lockfile. At least one. |
| `report_name` | no | string | Repository name in the report file names, `YYYY-MM-DD-<report_name>-<type>.md`. Default: the `name` part of `repo`. |
| `apps` | no | list of paths | The repository's apps, for the "at most 2 apps" gate. Default `["."]`: the repository is one app. |
| `excluded_paths` | no | list of paths | Paths no automatic fix may touch, on top of the exclusions written in the skills. Default `[]`. A repository can add paths; it cannot remove the skills' own. |
| `ship_skill` | no | string | The repository's own procedure from branch to pull request (a skill name), when it has one. Default: none, and the fixer follows the repository's `CLAUDE.md`, `CONTRIBUTING` and CI. |
| `slack_channel` | with `audits` | string | Slack channel ID the Weekly checks routine posts its one message to, e.g. `C0C2GVB9RKR`. |
| `audits` | no | list | The audits the Weekly checks routine runs on `base_branch` (`skills/weekly-audit-checks`): `{"skill", "path", "report_name"}`. `skill` is one of the types the Tech Metrics spreadsheet reads (below); `path` is where it runs, default `"."`; `report_name` is the key of its report, default the config's. With `audits`, `report_name` and `slack_channel` are required. Two audits may not write the same report. Leave it out in a repository no routine audits. |
| `dora` | with `dora-metrics` | object | The DORA run, required exactly when `dora-metrics` is an audit: `window_days` (a positive integer, the run's window) and `prod_branch` are required; `type`, `deploy_source`, `tag_pattern` and `provider` are optional and mean what they mean in a repo entry of the `dora-metrics` skill's `config/projects.json`, which checks their values. It is the repository's only DORA config: the routine writes a `projects.json` from it. |
| `ai_tools_ref` | no | 40-hex SHA | The somnio-ai-tools commit the routines load their skills from: the Weekly checks routine and the routine that runs the fixer. A commit of `main`, lowercase and in full. Moving it is a pull request in this repository, after reading somnio-ai-tools' CHANGELOG between the two commits. Without it the routines load `main`, and their Slack messages say "unpinned". A commit that cannot be fetched stops the run; it never falls back to `main`. |
| `tools` | no | object | The scan tools the Weekly checks routine installs at the version CI uses, each mapped to the repository file that pins it: `{"gitleaks": ".github/workflows/ci.yml", "trivy": ".github/actions/setup-trivy/action.yml"}`. Keys: `gitleaks` and `trivy`. Paths are relative to the repository root, without `..`. The file sets exactly one `<TOOL>_VERSION:` and one `<TOOL>_SHA256:` value (`weekly-audit-checks/scripts/install_tools.py`). A listed tool runs only as that binary. |
| `services` | no | list | Services the health audits' tests need, which the Weekly checks routine starts before them: `{"name", "run", "env"}`. `name` is unique; `run` is a command run from the repository root, for at most 10 minutes; `env` (an object of strings, optional) is exported to the health audits and holds local test settings, never a secret. At least one. It is the only command of the config the Weekly checks routine runs. |
| `_comment` | no | string | Free text for people; ignored. |

Any other field is an error, so a misspelt field is caught instead of silently ignored. A config without
`audits`, `slack_channel`, `dora`, `ai_tools_ref`, `tools` and `services` prints exactly as before they
existed; none of these fields gets a default.

## Report checks

`scripts/report_check.py` checks each report before the Weekly checks routine uploads it, with the
validated config (the output above, saved to a file) and the run's date:

```bash
python3 <weekly-audit-triage skill folder>/scripts/report_check.py "$TMPDIR/config.json" <YYYY-MM-DD> <report>...
```

It prints `PASS <report>`, or `FAIL <report>: <reason>` once per reason, and exits 0 only when every
report passes. A report passes when:

1. it is a non-empty `.md` file;
2. its name is exactly `<date>-<key>-<type>.md`, with the run's date, an audit's `report_name` as the
   key, and that audit's `skill` as the type. Without `audits`, the key is the config's `report_name`
   and the type any accepted one;
3. for `dora-metrics`: one line is exactly `## <repo>`, no other `## ` line names the repository (the
   old `` ## `owner/name` (…) — deploy_source: … `` heading), and its `| Measurement window | N days |`
   row equals `dora.window_days`.

With `--previous DIR` (a folder with last runs' reports), it also compares each report's sections with
those of the newest report in `DIR` of the same key and type dated before the run:

```bash
python3 <weekly-audit-triage skill folder>/scripts/report_check.py --previous "$TMPDIR/previous" "$TMPDIR/config.json" <YYYY-MM-DD> <report>...
```

4. every `## ` heading of the previous report, compared as trimmed text without a leading `N.` (the
   security audit renumbers its sections by score), is in this one, or the report carries the exact
   note line the check prints under its `FAIL`, such as `> ⚠️ Sections missing since 2026-11-16:
   Supply Chain Integrity`. A noted report passes with a `WARN` line. New sections are fine. Headings
   inside code fences do not count. Without an earlier report, or with an empty one, it prints `NOTE
   <report>: no previous report` and the report passes.

With `--previous DIR --unchanged <repo sha> <ai_tools_ref>` and no reports, it prints for each
`*-health-audit` of `audits` either `SKIP <key>-<type>: no changes since <sha12> (report of <date>)` or
`RUN <key>-<type>: <reason>`, and exits 0. It skips only when the previous report's `> Run:` line holds
both SHAs and the report has no `> ⚠️` line. `main` as the ref (an unpinned run) always runs, and
`security-audit` and `dora-metrics` are never listed: they run every week.

The accepted types are a closed list, `ACCEPTED_TYPES` in `report_check.py`: `security-audit`,
`dora-metrics`, `nestjs-health-audit`, `react-health-audit` and `python-health-audit`. The spreadsheet
rejects `nextjs-health-audit`, `nextjs-security-audit`, `harness-audit`, `weekly-summary` and suffixes
such as `-api`, so a pattern such as `<tech>-health-audit` is not the rule. A new stack the spreadsheet
reads is one line there.

## Example

```json
{
  "_comment": "Read by the weekly-audit-checks, weekly-audit-triage and weekly-audit-fixer skills of somnio-ai-tools.",
  "version": 1,
  "repo": "somnio-products/closebook-finance-platform",
  "jira_project": "CLOS",
  "base_branch": "develop",
  "drive_folder": "12JvOdKLeA4QAXO9fjjuWRdfGcq9RvMYV",
  "report_name": "closebook-finance-platform",
  "apps": ["apps/api", "apps/web", "apps/mcp"],
  "excluded_paths": ["infra/", "deploy/", ".github/workflows/", "apps/api/prisma/", "apps/api/src/oauth/"],
  "verify": [
    {"name": "build", "run": "pnpm build"},
    {"name": "web-lint", "run": "pnpm --filter @closebook/web lint"},
    {"name": "unit-tests", "run": "pnpm test"},
    {"name": "dependency-audit", "run": "pnpm check:audit", "when": "dependencies"}
  ],
  "ship_skill": "ship-flow",
  "slack_channel": "C0C2GVB9RKR",
  "audits": [
    {"skill": "security-audit"},
    {"skill": "nestjs-health-audit", "path": "apps/api"},
    {"skill": "react-health-audit", "path": "apps/web"},
    {"skill": "dora-metrics"}
  ],
  "dora": {
    "window_days": 14,
    "type": ["web", "backend"],
    "prod_branch": "develop",
    "deploy_source": "release",
    "tag_pattern": "^prod-v\\d+\\.\\d+\\.\\d+$"
  },
  "ai_tools_ref": "<40-hex SHA of a somnio-ai-tools main commit>",
  "tools": {
    "gitleaks": ".github/workflows/ci.yml",
    "trivy": ".github/actions/setup-trivy/action.yml"
  }
}
```

A repository whose tests need a database adds, for example,
`"services": [{"name": "postgres", "run": "service postgresql start", "env": {"DATABASE_URL": "postgresql://postgres@localhost:5432/test"}}]`.

## Adding a repository

1. Add `.claude/weekly-audit.json` to the repository, through its normal review, and merge it into
   the default branch.
2. Check it with `repo_config.py`.
3. Add the repository to the routine that runs the triage. Nothing in the skills changes.
4. For its Monday reports, add `slack_channel`, `audits` and (with `dora-metrics`) `dora`, and give its
   Weekly checks routine the prompt in `skills/weekly-audit-checks/SKILL.md`.
5. To make those runs reproducible, add `ai_tools_ref`, `tools` for the scanners its CI pins, and the
   `services` its tests need.
