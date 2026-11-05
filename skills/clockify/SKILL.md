---
name: clockify
description: Read Clockify hours and safely log retroactive entries using named accounts and intent receipts.
allowed-tools: ["Bash"]
---

# Clockify

The earlier log-based tracker workflow is not provided by this skill.

Use the installed `clockify-cli` binary. This skill requires the account-explicit v1 CLI; the binary is not currently distributed by Somnio. First run `clockify-cli auth list` and verify that it returns a JSON envelope with `ok`, `v: 1`, `data`, and `meta`. If the binary is unavailable or its output does not match, stop and ask the operator to obtain the expected CLI. Do not assume another similarly named binary is compatible. Always pass `--account NAME` on network commands. If the operator named the account, use it; otherwise ask which account. Never select an account or workspace from the server's defaults.

Never read credentials, environment keys, rc files or Keychain. Never call the REST API through curl. Only the operator enters keys through `clockify-cli auth login --account NAME --workspace WORKSPACE` using hidden input/stdin. No key arguments or credential environment variables exist.

Read projects with `clockify-cli projects list --account NAME`; read hours with `entries --account NAME --month YYYY-MM` (or `--from/--to`), optionally `--project` and `--detail`. Parse envelope `data` and `meta.timezone`. Running timers are separate and excluded from totals. Check `ok` and exit status.

For a retroactive write, first run `add --account NAME --project PROJECT --from YYYY-MM-DDTHH:MM --duration 2h --description TEXT --tz IANA`. `--to` is an alternative to duration; use a full end date for overnight work. Batch input is `--batch` with a JSON array of project/from/to-or-duration/description/billable fields. Limit ten entries and 31 days per batch.

Show the account, workspace, project, description, billable, timezone, offsets, UTC timestamps and `intent_sha256`. After the operator confirms that exact preview, repeat the same command with `--confirm-intent SHA --yes`. Any changed field needs a fresh preview and confirmation. Overlap checks run at write time across all projects; never add `--allow-overlap` without explicit operator instruction and a new preview.

On HTTP 429 stop and report `retry_after`. Never sleep/retry inside a loop. On `WRITE_OUTCOME_UNKNOWN` (exit 10), never replay a POST; repeat the dry-run to reconcile the durable pending record. A new exact entry ID proves landing. If still unresolved, show the evidence; only the operator may authorize `add --account NAME --resolve-unknown PENDING_INTENT --yes`. This acknowledges uncertainty and can risk a later duplicate due to eventual consistency; that invocation never posts.

`READ_ONLY` blocks mutations. Do not create projects, start/stop timers, query Linear, or change billing tooling: those commands/integrations are later phases. Never fall back silently to another project.
