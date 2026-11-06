---
name: clockify-tracker
description: >-
  Manages Clockify time tracking via the official Clockify REST API (v1): list workspaces and projects, create time entries with correct UTC timestamps. Use when the user wants to log time, track hours, record work in Clockify, or mentions Clockify or time entries.
---

# Clockify time tracking (REST API)

Integrate with Clockify using **HTTPS requests** to `https://api.clockify.me/api/v1`. Do not assume any local `clockify_tracker` binary exists.

## API key

The key lives in the user's environment or OS secret store, never in the chat and never in a file the skill writes.

**Rules for the agent**

- Never ask the user to paste the key into the chat, and never save a key typed or pasted into the chat. If the user pastes one anyway, do not use or store it; tell them to regenerate it (Clockify → Profile → API) and save the new one from their own terminal.
- Never print the key: no `echo`, no `curl -v`, no `set -x`, no `cat` of a file that may hold it. Check for a key only with `[ -n "$(clockify_key)" ]`.
- The user saves the key from their own terminal, in a window outside the chat (not through the `!` prefix, which logs output to the transcript).

### Lookup order

Use the first source that returns a non-empty value:

1. `CLOCKIFY_API_KEY` environment variable.
2. `CLOCKIFY_API_KEY_FILE` — path to a file containing just the key. Meant for vault-mounted or secrets-manager files, and for hosts with no secret store (headless Linux, containers). The skill reads it and never writes it; keep it `chmod 600`.
3. The OS secret store, service `clockify`, account = the login user (`$USER`):
   - **macOS** — `security find-generic-password -s clockify -a "$USER" -w`
   - **Linux** — `secret-tool lookup service clockify account "$USER"` (package `libsecret-tools`; needs a running Secret Service such as GNOME Keyring or KWallet)
   - **Windows** — Credential Manager, read through PowerShell. `cmdkey` can list entries but cannot print a secret, so use the `CredentialManager` module (`Install-Module CredentialManager`, Windows PowerShell 5.1), entry `clockify`: `(Get-StoredCredential -Target clockify).GetNetworkCredential().Password`

**Requirements.** A bash-compatible shell (macOS, Linux, WSL, or Git Bash on Windows, which Git for Windows provides), `curl` (built into Windows 10+ and Git for Windows), and Python 3.9+ for JSON and time zones (Windows: also `pip install tzdata`, which `zoneinfo` needs there). On Windows the key is read through `powershell.exe` (Windows PowerShell 5.1), so run the `Install-Module` / `New-StoredCredential` commands below in **Windows PowerShell**, not PowerShell 7, or the 5.1 reader will not see the module.

Define these helpers once per shell command (each Bash call starts fresh); every snippet in this file that calls `clockify_py`, `clockify_key`, `clockify_api` or `clockify_utc` needs them in the same command. They keep the key in a variable and out of the process list. `clockify_api` sends the key on curl's stdin, so the JSON body is passed as an argument (never `@-` or a heredoc), and `-q` stops a user's `~/.curlrc` (`verbose`, `trace`) from echoing the key header. Do not add `-v`/`--trace` or call `clockify_key` on its own:

```bash
# Runs Python 3.9+ with the given args (python3, python, or the Windows py launcher).
clockify_py() {
  if python3 -c 'import zoneinfo' 2>/dev/null; then python3 "$@"
  elif python -c 'import zoneinfo' 2>/dev/null; then python "$@"
  elif py -3 -c 'import zoneinfo' 2>/dev/null; then py -3 "$@"
  else echo "Python 3.9+ not found (Windows: install Python, then run: pip install tzdata)" >&2; return 1
  fi
}

clockify_key() {
  local k=${CLOCKIFY_API_KEY:-}
  [ -z "$k" ] && [ -n "${CLOCKIFY_API_KEY_FILE:-}" ] && k=$(tr -d '[:space:]' < "$CLOCKIFY_API_KEY_FILE" 2>/dev/null)
  if [ -z "$k" ]; then
    case "$(uname -s)" in
      Darwin) k=$(security find-generic-password -s clockify -a "${USER:-$(id -un)}" -w 2>/dev/null) ;;
      Linux) k=$(secret-tool lookup service clockify account "${USER:-$(id -un)}" 2>/dev/null) ;;
      MINGW*|MSYS*|CYGWIN*) k=$(powershell.exe -NoProfile -Command '(Get-StoredCredential -Target clockify).GetNetworkCredential().Password' 2>/dev/null | tr -d '\r') ;;
    esac
  fi
  printf '%s' "$k"
}

# Usage: clockify_api GET|POST <url> [json-body]
# Prints the response body, prints "HTTP <code>" on stderr, returns non-zero outside 2xx.
clockify_api() {
  local k resp code args=()
  k=$(clockify_key)
  [ -n "$k" ] || { echo "No Clockify API key found" >&2; return 1; }
  [ -n "$3" ] && args=(--data-binary "$3")
  resp=$(printf 'header = "X-Api-Key: %s"\n' "$k" | curl -q -sS --max-time 30 -K - -X "$1" -H 'Content-Type: application/json' "${args[@]}" -w '\n%{http_code}' "$2") || return 1
  code=${resp##*$'\n'}
  printf '%s\n' "${resp%$'\n'*}"
  echo "HTTP $code" >&2
  case $code in 2??) ;; *) return 1 ;; esac
}
```

### No key found

Stop and give the user the command for their OS to run **in their own terminal**; each one prompts for the key without echoing it. Then wait for them to say it is saved and look the key up again. On a host with no reachable secret store (WSL, headless Linux, containers, a sandboxed agent shell), point them to `CLOCKIFY_API_KEY_FILE` instead.

```bash
# macOS (-w with no value makes security prompt for the key; -U updates an existing item)
security add-generic-password -U -s clockify -a "$USER" -w

# Linux (secret-tool reads the key from the terminal)
secret-tool store --label='Clockify API key' service clockify account "$USER"
```

```powershell
# Windows PowerShell: type the key as the password in the prompt (the user name is ignored)
Install-Module CredentialManager -Scope CurrentUser   # once
New-StoredCredential -Target clockify -Credentials (Get-Credential -UserName clockify -Message 'Clockify API key') -Persist LocalMachine
```

### Migrating a plaintext key

Older versions of this skill kept the key as `api_key` in the prefs file and read it from shell rc files. The skill no longer reads either. If the prefs file still has an `api_key` field, the prefs reader (see Preferences file) reports it with the value hidden. Tell the user to:

1. Save the key with the command for their OS above (they can copy it from the prefs file in their own editor).
2. Say when it is saved. Verify with `clockify_api GET https://api.clockify.me/api/v1/user` (expect a user object, not an error).
3. Delete the `api_key` field. Offer to do it, and do it only on a yes:

```bash
clockify_py - "${CLOCKIFY_PREFS_PATH:-$HOME/.clockify-prefs.json}" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    prefs = json.load(f)
prefs.pop("api_key", None)
with open(path, "w", encoding="utf-8") as f:
    json.dump(prefs, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
```

If the prefs file was ever committed, synced or shared (dotfiles repo, cloud drive), tell the user to regenerate the key in Clockify as well.

An `export CLOCKIFY_API_KEY=...` line in a shell profile still works when the agent's shell inherits it (source 1); the skill just no longer greps rc files itself.

## Environment

| Variable | Purpose |
|----------|---------|
| `CLOCKIFY_API_KEY` | API key value directly in the live environment. |
| `CLOCKIFY_API_KEY_FILE` | Path to a file whose contents are the API key (e.g. `/run/secrets/clockify`). Useful with secrets managers or vault-mounted files. |
| `CLOCKIFY_PREFS_PATH` | Custom path for the prefs JSON file. Defaults to `~/.clockify-prefs.json` when unset. Resolve it with `${CLOCKIFY_PREFS_PATH:-$HOME/.clockify-prefs.json}` (a `~` inside `${…:-…}` is not expanded by the shell). |
| `CLOCKIFY_TZ_OFFSET` | **Legacy, read-only.** Whole-hour offset from UTC (e.g. `-3`). Used only when neither the request nor the prefs file gives an IANA zone, and it ignores DST. Prefer `timezone.zone` in the prefs file. |

## Authentication

Every request goes through `clockify_api` (see API key), which sends:

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

Build the body with `json.dumps`, so quotes, apostrophes and backslashes in a description cannot break it, and pass it to `clockify_api`:

```bash
START=2025-03-31T07:00:00.000Z END=2025-03-31T15:00:00.000Z PID=<projectId> WID=<workspaceId>
DESC_FILE=$(mktemp)
cat > "$DESC_FILE" <<'TXT'
Fixed the user's login redirect and removed the "legacy" auth path.
TXT
body=$(clockify_py -c '
import json, sys
start, end, desc_file, pid = sys.argv[1:5]
entry = {"start": start, "description": open(desc_file, encoding="utf-8").read().strip()}
if end: entry["end"] = end
if pid: entry["projectId"] = pid
print(json.dumps(entry))' "$START" "$END" "$DESC_FILE" "$PID")
rm -f "$DESC_FILE"
clockify_api POST "https://api.clockify.me/api/v1/workspaces/$WID/time-entries" "$body"
```

### Converting user-local `HH:mm` to UTC `start` / `end`

A fixed number of hours is not enough: zones with DST change their offset during the year, and some zones are not on the hour (India UTC+5:30, Newfoundland UTC-3:30). Convert with the IANA zone and the date of the entry, never with `hour - offset`.

**1. Resolve the IANA zone** (e.g. `America/Argentina/Buenos_Aires`, `Europe/Madrid`, `Asia/Kolkata`), first match wins:

1. A zone, city or offset the user names in this request wins over everything saved. Map a city to its IANA zone and confirm it ("Madrid → `Europe/Madrid`, correct?"). For a bare offset ("I'm in UTC+2 today"), ask for the zone before converting, since an offset cannot tell whether DST applies.
2. `timezone.zone` in the prefs file.
3. Legacy fixed offset, only when neither of the above exists: `timezone.offset` in prefs, then `CLOCKIFY_TZ_OFFSET`. Both are read-only (never written). Map offset `N` hours to the fixed zone `Etc/GMT` with the **sign flipped**: `-3` → `Etc/GMT+3`, `+5` → `Etc/GMT-5`. Warn the user that a fixed offset ignores DST and offer to pick a real zone and save it.
4. Otherwise ask for a city or IANA zone name.

**Relative dates.** Resolve "today", "this week" and a missing year in the chosen zone, never the host's clock, which can be a day or a year off near midnight or New Year for a user in another zone (`clockify_py -c 'import sys; from datetime import datetime; from zoneinfo import ZoneInfo; print(datetime.now(ZoneInfo(sys.argv[1])).strftime("%Y-%m-%d"))' "$ZONE"`). A range that crosses New Year ("Dec 30 – Jan 2") rolls the year forward.

**2. Convert** with this helper (needs the `clockify_py` helper; Python 3.9+ standard `zoneinfo`, and `pip install tzdata` on Windows). Each argument is `"YYYY-MM-DD HH:MM-HH:MM"` (start–end) or `"YYYY-MM-DD HH:MM"` (open-ended); the output is one line per argument: `start-UTC end-UTC minutes`. If the end is not after the start it falls on the next day. A bad zone name exits with an error.

```bash
clockify_utc() {
  clockify_py - "$@" <<'PY'
import sys
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

try:
    zone = ZoneInfo(sys.argv[1])
except ZoneInfoNotFoundError:
    sys.exit(f"Unknown time zone {sys.argv[1]!r} (Windows: run pip install tzdata)")
fmt = "%Y-%m-%dT%H:%M:%S.000Z"

def to_utc(day, hm):
    naive = datetime.strptime(f"{day} {hm}", "%Y-%m-%d %H:%M")
    first, second = naive.replace(tzinfo=zone), naive.replace(tzinfo=zone, fold=1)
    if first.utcoffset() != second.utcoffset():
        sys.exit(f"{day} {hm} is skipped or repeated by a DST change in {sys.argv[1]}; ask the user which instant they mean")
    return first.astimezone(timezone.utc)

for arg in sys.argv[2:]:
    day, span = arg.split()
    start_hm, _, end_hm = span.partition("-")
    start = to_utc(day, start_hm)
    if not end_hm:
        print(start.strftime(fmt), "-", "-")
        continue
    end = to_utc(day, end_hm)
    if end <= start:
        next_day = (datetime.strptime(day, "%Y-%m-%d") + timedelta(days=1)).strftime("%Y-%m-%d")
        end = to_utc(next_day, end_hm)
    print(start.strftime(fmt), end.strftime(fmt), int((end - start).total_seconds() // 60))
PY
}

clockify_utc Europe/Madrid "2025-03-28 09:00-17:00" "2025-03-31 09:00-17:00"
# 2025-03-28T08:00:00.000Z 2025-03-28T16:00:00.000Z 480
# 2025-03-31T07:00:00.000Z 2025-03-31T15:00:00.000Z 480
```

Use the `minutes` column for the duration in the preview; on a DST-change day it can differ from end minus start on the clock. A local time that does not exist or occurs twice (Madrid `02:30` on 2025-03-30 and 2025-10-26) makes the helper exit with an error: ask the user for a different time.

Only if no Python 3.9+ is available, `date` can convert one instant at a time. Both variants convert back and compare, which catches a skipped local time (the BSD one normalizes it, the GNU one rejects it). Neither can detect a time that occurs twice, and BSD and GNU pick different occurrences, so on the day a zone falls back (Madrid `2025-10-26`) install Python instead. Compute the duration from the two epoch values.

```bash
Z=Europe/Madrid T='2025-03-31 09:00'

# macOS / BSD
e=$(TZ=$Z date -j -f '%Y-%m-%d %H:%M:%S' "$T:00" +%s) && [ "$(TZ=$Z date -r "$e" '+%Y-%m-%d %H:%M')" = "$T" ] \
  && date -u -r "$e" +%Y-%m-%dT%H:%M:00.000Z || echo "skipped or invalid local time: $T"

# Linux / GNU
e=$(date -d "TZ=\"$Z\" $T" +%s) && [ "$(TZ=$Z date -d @"$e" '+%Y-%m-%d %H:%M')" = "$T" ] \
  && date -u -d @"$e" +%Y-%m-%dT%H:%M:00.000Z || echo "skipped or invalid local time: $T"
```

**Examples** (all verified with the helper above):

| Zone | Local | UTC `start` |
|------|-------|-------------|
| `America/Argentina/Buenos_Aires` (UTC-3, no DST) | `2025-03-10 09:00` | `2025-03-10T12:00:00.000Z` |
| `Europe/Madrid` (UTC+1 winter) | `2025-03-28 09:00` | `2025-03-28T08:00:00.000Z` |
| `Europe/Madrid` (UTC+2 after the 2025-03-30 change) | `2025-03-31 09:00` | `2025-03-31T07:00:00.000Z` |
| `Asia/Kolkata` (UTC+5:30) | `2025-03-10 09:00` | `2025-03-10T03:30:00.000Z` |
| `America/St_Johns` (UTC-2:30 in July) | `2025-07-10 09:00` | `2025-07-10T11:30:00.000Z` |

If the user already provides full ISO strings with `T` and a timezone/`Z`, pass them through without this conversion.

### Multiple calendar days

For ranges ("March 2–6") or discrete lists ("March 23, 24, 25, 26 and 27"), create **one POST per day** with the same local times and the appropriate date for each `start` (and `end` if any). When no year is provided, assume the current calendar year.

## Preview before every POST

Every `POST` to `/time-entries` is preceded by one preview, in every path: a single manual entry, a multi-day range, and log-based mode. Show every entry that will be created, then wait for the user's answer. Nothing is sent before an explicit **yes**.

Format: a numbered list (not a table, so the description is never truncated), one item per POST, each with the date, local start–end, project, description and duration, then a total and the question:

```
Here's what I'll post to Clockify (time zone: America/Argentina/Buenos_Aires):

1. 2025-05-22 — Nubank — 09:00–17:00 (8h)
   refactor-flutter_http: Completed Flutter HTTP migration by updating LogoutInterceptor
   to use IRouter and fixing the redirect_interceptor_test setup. Key finding: the
   interceptor correctly dispatches the logout deeplink on 403 responses.

2. 2025-05-26 — Nubank — 09:00–16:00 (7h)
   refactor-flutter_http: Diagnosed the native catalyst HTTP bypass on both iOS and
   Android — authenticated calls go through URLSession/OkHttp, not Dart/Dio, making
   LogoutInterceptor.onError structurally unreachable. Proposed and planned Option A
   (synthetic DioException) as the only viable path to trigger the interceptor.

3. 2025-05-26 — Internal Tools — 16:00–17:00 (1h)
   somnio-ai-tools: Planned and implemented the clockify-tracker log-based mode,
   including hook fix for root-repo logging and the repo-to-project mapping system.

Total: 3 entries, 16h

Post these entries? (yes / edit / cancel)
```

- Show the full date with the year and name the time zone the times are in, so a wrong zone or year is visible before anything is sent.
- Write the project by name, or "no project" when `projectId` is omitted. Show the full description.
- Open-ended entry (no `end`): show `09:00– (running)` and leave it out of the total.
- Only a clear yes posts. "edit": ask which entry number to change and what the new value is, then show the full preview again. "cancel", silence or anything ambiguous: do not post.
- The yes covers exactly the entries shown. If anything changes before sending (a time, a project, a description, a different set of days), show the preview again.

## Operational flow

1. Check that a key exists with `[ -n "$(clockify_key)" ]`. Never run `clockify_key` on its own (it prints the key), and never run `env` or `printenv`. If none is found, follow "No key found" and stop. Then read the prefs file with the reader (see Preferences file) for the saved time zone and the legacy `api_key` warning.
2. If workspace is unknown: `GET /workspaces`; resolve `workspaceId`.
3. If project is needed: `GET /workspaces/{workspaceId}/projects?page-size=5000`; resolve `projectId`.
4. Collect description, start (and optional end), date if needed, and the IANA time zone if not obvious.
5. Build the entries (one per day, one per project), converting local times to UTC with `clockify_utc`.
6. Show the preview and wait for an explicit yes (see "Preview before every POST"). No POST before it.
7. After the yes, `POST /workspaces/{workspaceId}/time-entries` once per previewed entry.
8. Show the API JSON response or a clear error (status code + body).

## Errors

On non-success status (`clockify_api` prints `HTTP <code>` and returns non-zero), read the response body and adjust (invalid id, permissions, malformed body). Never resend an entry that already posted, and never resend a corrected entry without showing it in a new preview first.

A POST whose outcome is unknown (a transport failure with no `HTTP <code>` line, or any 502/503/504) may still have created the entry. Never retry it automatically. List that day with `GET /workspaces/{workspaceId}/user/{userId}/time-entries?start=<ISO UTC>&end=<ISO UTC>&page-size=200&page=<n>` (the user id is `id` from `GET /user`; fetch pages until one comes back with fewer than 200 entries), show the user the entries it returns (Clockify returns instants like `...:00Z`, so compare them as instants, not strings, and look at `end`, project and description too), and resend only if the user confirms the entry is missing.

---

## Log-based mode

Triggered when the user says **"use logs"**, **"from work logs"**, **"usa los logs"**, **"auto-fill from logs"**, or similar. The existing manual mode (explicit description/project/dates/times) is unchanged.

### Preferences file

Path: `${CLOCKIFY_PREFS_PATH:-$HOME/.clockify-prefs.json}`. Always resolve this at runtime — check the env var first, then fall back to `~/.clockify-prefs.json` — and use that one path for every read, write and `auto_cleanup` check. The file holds no secrets. Never `cat` it (an old file may still contain a plaintext `api_key`); read it with this, which hides that field and warns:

```bash
clockify_py - "${CLOCKIFY_PREFS_PATH:-$HOME/.clockify-prefs.json}" <<'PY'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        prefs = json.load(f)
except FileNotFoundError:
    sys.exit(0)  # no file means first run
if "api_key" in prefs:
    del prefs["api_key"]
    print("legacy api_key found in prefs (value hidden): see Migrating a plaintext key", file=sys.stderr)
print(json.dumps(prefs, indent=2))
PY
```

Write with this merge helper, passing only the keys to set (single-quoted JSON; write an apostrophe inside a value as `'\''`). It reloads the whole file, so a legacy `api_key` the reader hid is kept until the user's migration step removes it, never dropped by an ordinary save. Top-level keys are replaced (pass the complete `timezone` object); `repo_mappings` is merged one level deep, so passing one new repo keeps the others. It builds the whole text before opening the file for writing, so an encoding error cannot leave a truncated prefs file:

```bash
clockify_py - "${CLOCKIFY_PREFS_PATH:-$HOME/.clockify-prefs.json}" '{"default_start": "09:00"}' <<'PY'
import json, sys
path, update = sys.argv[1], json.loads(sys.argv[2])
try:
    with open(path, encoding="utf-8") as f:
        prefs = json.load(f)
except FileNotFoundError:
    prefs = {}
for key, value in update.items():
    if key == "repo_mappings" and isinstance(prefs.get(key), dict):
        prefs[key].update(value)
    else:
        prefs[key] = value
text = json.dumps(prefs, indent=2, ensure_ascii=False) + "\n"
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PY
```

```json
{
  "timezone": { "name": "Buenos Aires, Argentina", "zone": "America/Argentina/Buenos_Aires" },
  "default_start": "09:00",
  "default_end": "17:00",
  "workspace_id": "<wid>",
  "repo_mappings": {
    "mini-meta-repo":  { "name": "Nubank",        "id": "<pid>" },
    "somnio-ai-tools": { "name": "Internal Tools", "id": "<pid>" }
  }
}
```

Always **merge** new keys into existing prefs — never replace the whole file. `timezone.zone` is an IANA zone name. Prefs written by older versions have `"timezone": { "name": ..., "offset": -3 }` instead; that is still read (see the legacy fallback in the conversion section) but never written. When the user confirms a zone, replace that `timezone` object with the `name` + `zone` form.

### Step-by-step flow

**1. Load prefs** — read the prefs file with the reader above. Missing file means no saved state; proceed through first-run setup.

**2. First-run setup (no prefs file)** — before asking anything else, ask:
> "Let's set up your preferences. What repos/projects are you actively working on, and what's the Clockify project name for each?
> Example: mini-meta-repo → Nubank, somnio-ai-tools → Internal Tools"

Resolve named Clockify projects to IDs via `GET /workspaces/{wid}/projects` and save them to prefs with the merge helper. This is the only time the full project landscape is declared — new repos encountered later get a single one-time question.

**3. Ask for timespan** — if not in the user's message:
> "Which days should I look at? (e.g. today, this week, May 22–26)"

**4. Read log files** — for each day in the timespan:
```bash
cat ~/.work-log/YYYY-MM-DD.md 2>/dev/null
```
Missing file → skip that day and tell the user. Parse every `## HH:MM - … (branch)` header to collect unique repo names across all selected days.

**5. Confirm time frame** — default 09:00–17:00 (8 h). Show saved pref if one exists. Only ask to change if no prefs exist or user explicitly mentions a different block.

**6. Timezone** — the zone is an IANA name, so DST and half-hour zones are handled. If a saved `timezone.zone` exists, offer it as default:
> "Using Buenos Aires (America/Argentina/Buenos_Aires) — press Enter to keep, or pick a number / type your own:"

If the prefs only have a legacy `offset`, say it is a fixed offset that ignores DST and ask for the real zone (the picker below) before converting.

If no saved pref, print and wait for a number, a name, or a free-text entry:
```
1. America/Argentina/Buenos_Aires  (Buenos Aires, Argentina)
2. America/Montevideo              (Montevideo, Uruguay)
3. America/Sao_Paulo               (São Paulo, Brazil)
4. America/Guayaquil               (Quito, Ecuador)
5. America/Lima                    (Lima, Peru)
6. America/Bogota                  (Colombia)
7. America/Managua                 (Nicaragua)
8. Other — type your city or an IANA zone (e.g. "Madrid", "Europe/Madrid", "Asia/Kolkata")
```

If the user types a city or region not on the list, map it to its IANA zone from your knowledge and confirm before saving, including the offsets so they can catch a wrong guess:
> "Madrid → Europe/Madrid (UTC+1 in winter, UTC+2 in summer) — is that correct?"

Check that the zone exists before saving: `clockify_py -c 'from zoneinfo import ZoneInfo; ZoneInfo("Europe/Madrid")'` (non-zero exit and `ZoneInfoNotFoundError` for a bad name). Then save `"timezone": { "name": "<label>", "zone": "<IANA zone>" }` with the merge helper (the complete object, so a legacy `offset` is dropped).

**7. Parse and resolve repo names** — log headers use two formats:
- Worktree: `## HH:MM - mini-meta-repo/refactor-flutter_http (branch)` — root repo is the part **before** `/`
- Main checkout: `## HH:MM - somnio-ai-tools (main)` — whole name is the root repo

Split on `/` to extract the root repo name (for Clockify mapping) and the worktree name (for description context). Then:
- Root repo **in `repo_mappings`** → use silently.
- Root repo **not in `repo_mappings`** → ask once:
  > "I see entries from **mini-meta-repo** — which Clockify project is this?"

Batch all unknown-repo questions before creating any entries.

**8. Save prefs** — after all questions are answered, merge answers into the prefs file with the merge helper.

**9. Handle multi-project days** — for each day, count distinct Clockify projects the day's repos map to:
- **Single project** → one entry for the full time block.
- **Multiple projects** → ask the user to split hours:
  > "On May 26 you worked on **Nubank** (mini-meta-repo) and **Internal Tools** (somnio-ai-tools). How do you want to split the 8 hours? (e.g. 7h Nubank / 1h Internal Tools)"

  Create one entry per project for that day with its own start/end times.

**10. Summarize logs per entry** — for each (day, Clockify-project) pair, collect the relevant log entries and generate a **2-sentence executive summary**:
- Sentence 1: main accomplishments — features, decisions, specific worktrees/branches worked on (name them)
- Sentence 2: key finding, outcome, or next step

The goal is enough context for a Finance reader to understand 8 h of work, without being a wall of text.

**11. Preview and confirm** — show the preview exactly as described in "Preview before every POST", with the 2-sentence summaries as descriptions, so the user can validate each one. Do not post until they answer yes.

**12. Create entries** — one `POST /workspaces/{workspaceId}/time-entries` per previewed row, with the `start` / `end` that `clockify_utc` produced and `clockify_api POST`. Show each API response.

**13. Clean up log files** — after all entries are successfully posted, offer to delete the processed files.

Check the prefs loaded in step 1 for `"auto_cleanup": true`. If set, delete without asking and tell the user which files were removed. Otherwise ask:

> "Entries posted. Delete the processed log files?
> - ~/.work-log/2026-05-26.md
> - ~/.work-log/2026-05-27.md
> (yes / no / always — 'always' saves the preference and never asks again)"

- **yes** — delete those files with `rm`, confirm each one removed
- **no** — leave files as-is
- **always** — delete files, then merge `"auto_cleanup": true` into the prefs file with the merge helper

Only delete files whose entries **all** posted successfully (`clockify_api` returned 2xx for each). If posting was partial, skip deletion for any day with a failed entry and tell the user which files were kept.
