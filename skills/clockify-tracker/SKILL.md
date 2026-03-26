---
name: clockify-tracker
description: >-
  Manages Clockify time tracking via the official Clockify REST API (v1): list workspaces and projects, create time entries with correct UTC timestamps. Use when the user wants to log time, track hours, record work in Clockify, or mentions Clockify or time entries.
---

# Clockify time tracking (REST API)

Integrate with Clockify using **HTTPS requests** to `https://api.clockify.me/api/v1`. Do not assume any local `clockify_tracker` binary exists.

## Environment

| Variable | Required | Purpose |
|----------|----------|---------|
| `CLOCKIFY_API_KEY` | Yes | API key from Clockify (Profile → API) |
| `CLOCKIFY_TZ_OFFSET` | No | Local offset from UTC in **whole hours** (e.g. `-3` for Argentina). Use when the shell or runtime reports UTC but the user gives local `HH:mm`. |

## Authentication

Every request:

- Header: `X-Api-Key: <CLOCKIFY_API_KEY>`
- Header: `Content-Type: application/json` (for POST bodies)

Never paste the API key into chat; use the environment variable in the tool/shell you run.

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
