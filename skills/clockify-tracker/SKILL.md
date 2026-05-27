---
name: clockify-tracker
description: >-
  Manages Clockify time tracking via the official Clockify REST API (v1): list workspaces and projects, create time entries with correct UTC timestamps. Use when the user wants to log time, track hours, record work in Clockify, or mentions Clockify or time entries.
---

# Clockify time tracking (REST API)

Integrate with Clockify using **HTTPS requests** to `https://api.clockify.me/api/v1`. Do not assume any local `clockify_tracker` binary exists.

## API key

Resolve the key using this priority order:

1. `CLOCKIFY_API_KEY` environment variable — check with `echo $CLOCKIFY_API_KEY`
2. `api_key` field in `~/.clockify-prefs.json` — read with `cat ~/.clockify-prefs.json 2>/dev/null`
3. Neither found → ask the user to paste their key (Clockify → Profile → API), then offer to save it:
   > "Save this key to ~/.clockify-prefs.json so you don't have to enter it again? (yes/no)"
   If yes, merge `"api_key": "<key>"` into the prefs file.

**Never echo or log the key value**. Use it only inside `curl -H "X-Api-Key: $KEY"` commands.

## Environment

| Variable | Purpose |
|----------|---------|
| `CLOCKIFY_TZ_OFFSET` | Local offset from UTC in **whole hours** (e.g. `-3` for Argentina). Fallback when `~/.clockify-prefs.json` has no timezone. |

## Authentication

Every request:

- Header: `X-Api-Key: <resolved key>`
- Header: `Content-Type: application/json` (for POST bodies)

## Endpoints (mirror of former CLI behavior)

### List workspaces

`GET /workspaces`

Returns a JSON array of workspaces; each item includes `id` and `name`.

### List projects in a workspace

`GET /workspaces/{workspaceId}/projects?page-size=5000`

Returns a JSON array of projects; each item includes `id` and `name`.

**Flow:** If the user might have multiple workspaces, call `GET /workspaces` first and let them pick (or use the only one). Then list projects for the chosen `workspaceId`.

## Create a time entry

`POST /workspaces/{workspaceId}/time-entries`

**JSON body** (fields aligned with the previous CLI):

| Field | Required | Notes |
|-------|----------|--------|
| `start` | Yes | ISO 8601 UTC string, e.g. `2025-03-25T12:00:00.000Z` |
| `description` | Yes | Work description |
| `billable` | No | Boolean, default `false` if omitted |
| `end` | No | ISO 8601 UTC; omit for open-ended entry |
| `projectId` | No | Clockify project id |

### Converting user-local `HH:mm` to UTC `start` / `end`

When the user gives **local** time as `HH:mm` (and optional `YYYY-MM-DD`, default **today** in their locale intent):

1. Parse date `D` (year, month, day) and time parts `hour`, `minute`.
2. Let `tzOffset` be the offset **in hours from UTC** for that local zone: `+5` for UTC+5, `-3` for UTC-3. Use `CLOCKIFY_TZ_OFFSET` if set (integer hours); otherwise infer from the user (e.g. Argentina → `-3`) or from context.
3. Build UTC instant:
   `utc_hour = hour - tzOffset`
   then normalize into a proper UTC `DateTime` on calendar day `D` (carry overflow across day boundaries as needed), and serialize with `Z` (ISO 8601 UTC).

**Examples:**

- Local `09:00` on `2025-03-10`, `tzOffset = -3` → UTC hour `9 - (-3) = 12` → `2025-03-10T12:00:00.000Z`.
- If the user already provides full ISO strings with `T` and timezone/`Z`, pass them through without this conversion.

### Multiple calendar days

For ranges ("March 2–6") or discrete lists ("March 23, 24, 25, 26 and 27"), create **one POST per day** with the same local times and the appropriate date for each `start` (and `end` if any). When no year is provided, assume the current calendar year.

## Operational flow

1. Confirm `CLOCKIFY_API_KEY` is available to the execution environment.
2. If workspace is unknown: `GET /workspaces`; resolve `workspaceId`.
3. If project is needed: `GET /workspaces/{workspaceId}/projects?page-size=5000`; resolve `projectId`.
4. Collect description, start (and optional end), date if needed, and timezone offset if not obvious.
5. Build JSON and `POST /workspaces/{workspaceId}/time-entries`.
6. Show the API JSON response or a clear error (status code + body).

## Errors

On non-success status, read the response body and adjust (invalid id, permissions, malformed body). Official reference: [Clockify API documentation](https://docs.clockify.me/).

---

## Log-based mode

Triggered when the user says **"use logs"**, **"from work logs"**, **"usa los logs"**, **"auto-fill from logs"**, or similar. The existing manual mode (explicit description/project/dates/times) is unchanged.

### Preferences file

Path: `~/.clockify-prefs.json`. Read with `cat ~/.clockify-prefs.json 2>/dev/null`; write by overwriting the file with merged JSON.

```json
{
  "api_key": "<clockify-api-key>",
  "timezone": { "name": "Buenos Aires, Argentina", "offset": -3 },
  "default_start": "09:00",
  "default_end": "17:00",
  "workspace_id": "<wid>",
  "repo_mappings": {
    "mini-meta-repo":  { "name": "Nubank",        "id": "<pid>" },
    "somnio-ai-tools": { "name": "Internal Tools", "id": "<pid>" }
  }
}
```

Always **merge** new keys into existing prefs — never replace the whole file.

### Step-by-step flow

**1. Load prefs** — read `~/.clockify-prefs.json`. Missing file means no saved state; proceed through first-run setup.

**2. First-run setup (no prefs file)** — before asking anything else, ask:
> "Let's set up your preferences. What repos/projects are you actively working on, and what's the Clockify project name for each?
> Example: mini-meta-repo → Nubank, somnio-ai-tools → Internal Tools"

Resolve named Clockify projects to IDs via `GET /workspaces/{wid}/projects` and save to prefs. This is the only time the full project landscape is declared — new repos encountered later get a single one-time question.

**3. Ask for timespan** — if not in the user's message:
> "Which days should I look at? (e.g. today, this week, May 22–26)"

**4. Read log files** — for each day in the timespan:
```bash
cat ~/.work-log/YYYY-MM-DD.md 2>/dev/null
```
Missing file → skip that day and tell the user. Parse every `## HH:MM - … (branch)` header to collect unique repo names across all selected days.

**5. Confirm time frame** — default 09:00–17:00 (8 h). Show saved pref if one exists. Only ask to change if no prefs exist or user explicitly mentions a different block.

**6. Timezone picker** — if a saved timezone exists, offer it as default:
> "Using Buenos Aires (UTC-3) — press Enter to keep, or pick a number / type your own:"

If no saved pref, print and wait for a number, a name, or a free-text entry:
```
1. Buenos Aires, Argentina  (UTC-3)
2. Montevideo, Uruguay      (UTC-3)
3. São Paulo, Brazil        (UTC-3)
4. Quito, Ecuador           (UTC-5)
5. Lima, Peru               (UTC-5)
6. Colombia                 (UTC-5)
7. Nicaragua                (UTC-6)
8. Other — type your city or UTC offset (e.g. "Madrid" or "UTC+1")
```

If the user types a city or region not on the list, infer the standard UTC offset from your knowledge (e.g. "Madrid" → UTC+1 in winter / UTC+2 in summer — use the current standard offset for today's date). Confirm with the user before saving:
> "Madrid is UTC+1 (standard time) — is that correct?"

**7. Parse and resolve repo names** — log headers use two formats:
- Worktree: `## HH:MM - mini-meta-repo/refactor-flutter_http (branch)` — root repo is the part **before** `/`
- Main checkout: `## HH:MM - somnio-ai-tools (main)` — whole name is the root repo

Split on `/` to extract the root repo name (for Clockify mapping) and the worktree name (for description context). Then:
- Root repo **in `repo_mappings`** → use silently.
- Root repo **not in `repo_mappings`** → ask once:
  > "I see entries from **mini-meta-repo** — which Clockify project is this?"

Batch all unknown-repo questions before creating any entries.

**8. Save prefs** — after all questions are answered, merge answers into `~/.clockify-prefs.json`.

**9. Handle multi-project days** — for each day, count distinct Clockify projects the day's repos map to:
- **Single project** → one entry for the full time block.
- **Multiple projects** → ask the user to split hours:
  > "On May 26 you worked on **Nubank** (mini-meta-repo) and **Internal Tools** (somnio-ai-tools). How do you want to split the 8 hours? (e.g. 7h Nubank / 1h Internal Tools)"

  Create one entry per project for that day with its own start/end times.

**10. Summarize logs per entry** — for each (day, Clockify-project) pair, collect the relevant log entries and generate a **2-sentence executive summary**:
- Sentence 1: main accomplishments — features, decisions, specific worktrees/branches worked on (name them)
- Sentence 2: key finding, outcome, or next step

The goal is enough context for a Finance reader to understand 8 h of work, without being a wall of text.

**11. Preview and confirm** — before posting anything, show each entry in full so the user can validate the description. Format as a numbered list, one entry per item:

```
Here's what I'll post to Clockify:

1. May 22 — Nubank — 09:00–17:00
   refactor-flutter_http: Completed Flutter HTTP migration by updating LogoutInterceptor
   to use IRouter and fixing the redirect_interceptor_test setup. Key finding: the
   interceptor correctly dispatches the logout deeplink on 403 responses.

2. May 26 — Nubank — 09:00–16:00
   refactor-flutter_http: Diagnosed the native catalyst HTTP bypass on both iOS and
   Android — authenticated calls go through URLSession/OkHttp, not Dart/Dio, making
   LogoutInterceptor.onError structurally unreachable. Proposed and planned Option A
   (synthetic DioException) as the only viable path to trigger the interceptor.

3. May 26 — Internal Tools — 16:00–17:00
   somnio-ai-tools: Planned and implemented the clockify-tracker log-based mode,
   including hook fix for root-repo logging and the repo-to-project mapping system.

Post these entries? (yes / edit / cancel)
```

Use a numbered list (not a table) so the full description is readable without truncation. If the user says "edit", ask which entry number they want to change and what the new description should be, then re-show the full preview before posting.

**12. Create entries** — one `POST /workspaces/{workspaceId}/time-entries` per row using the existing UTC conversion logic. Show each API response.

**13. Clean up log files** — after all entries are successfully posted, offer to delete the processed files.

Check `~/.clockify-prefs.json` for `"auto_cleanup": true`. If set, delete without asking and tell the user which files were removed. Otherwise ask:

> "Entries posted. Delete the processed log files?
> - ~/.work-log/2026-05-26.md
> - ~/.work-log/2026-05-27.md
> (yes / no / always — 'always' saves the preference and never asks again)"

- **yes** — delete those files with `rm`, confirm each one removed
- **no** — leave files as-is
- **always** — delete files, then merge `"auto_cleanup": true` into `~/.clockify-prefs.json`

Only delete files whose entries **all** posted successfully. If posting was partial, skip deletion for any day with a failed entry and tell the user which files were kept.
