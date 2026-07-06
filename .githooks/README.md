# Git hooks

Versioned git hooks for this repo. They live here (instead of `.git/hooks`, which
is not tracked) so everyone shares the same checks.

## Enable

Run once per clone:

```bash
git config core.hooksPath .githooks
```

## Hooks

### `pre-push`

Runs the Somnio CLI test suite with coverage and **blocks the push if any
non-excluded file in `cli/lib` is below 85% line coverage** (enforced per file,
not as an aggregate average). When the gate fails it lists every offending file.

- Override the threshold for one push: `COVERAGE_MIN=90 git push`
- Bypass intentionally (e.g. docs-only change): `git push --no-verify`

It uses `dart test --coverage`, then `coverage:format_coverage --check-ignore`
to produce an lcov report (the `coverage` package is auto-activated on first
run), then walks each `SF:…end_of_record` block to compute per-file coverage.
Files marked `// coverage:ignore-file` (entrypoints, command shells, interactive
prompts, process-spawning orchestrators) are excluded from the report.
