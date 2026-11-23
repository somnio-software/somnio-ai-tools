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
| `_comment` | no | string | Free text for people; ignored. |

Any other field is an error, so a misspelt field is caught instead of silently ignored.

## Example

```json
{
  "_comment": "Read by the weekly-audit-triage and weekly-audit-fixer skills of somnio-ai-tools.",
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
  "ship_skill": "ship-flow"
}
```

## Adding a repository

1. Add `.claude/weekly-audit.json` to the repository, through its normal review, and merge it into
   the default branch.
2. Check it with `repo_config.py`.
3. Add the repository to the routine that runs the triage. Nothing in the skills changes.
