---
description: Log or manage Clockify time via the Clockify API (project skill clockify-tracker).
allowed-tools: ["Bash"]
---

Follow the **clockify-tracker** Agent Skill (`skills/clockify-tracker/SKILL.md`): use the Clockify REST API with `CLOCKIFY_API_KEY`, resolve workspace/project IDs from the API, convert local times to UTC (e.g. Buenos Aires = UTC-3), and create one time entry per day when the user gives multiple dates.

Interpret the user's message for description, project name or ID, dates, duration or start/end times, and timezone. If they say "8 hours starting at 09:00", use end time 17:00 local unless they specify otherwise.
