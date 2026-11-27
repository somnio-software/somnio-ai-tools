---
description: Log or manage Clockify time via the Clockify API (project skill clockify-tracker).
allowed-tools: ["Bash"]
---

Follow the **clockify-tracker** Agent Skill (`skills/clockify-tracker/SKILL.md`). It supports two modes:

**Manual mode** — user supplies description, project, dates, and times explicitly (e.g. "carga 8 horas en el proyecto Somnio con la descripción 'Technology' empezando a las 09:00 para los días 25–29 de mayo usando el timezone de Buenos Aires"). Resolve workspace/project IDs from the API, convert local times to UTC using the user's IANA time zone (so DST and half-hour zones come out right), and create one time entry per day.

**Log-based mode** — triggered when the user says "use logs", "from work logs", "usa los logs", "auto-fill from logs", or similar. Read daily work logs from `~/.work-log/`, resolve repo-to-project mappings (persisted in `~/.clockify-prefs.json`), generate executive summaries, and create Clockify entries after user confirmation. Full flow is in the skill file under `## Log-based mode`.

In both modes, show the skill's numbered preview (date, local start–end, project, description, duration, total) and wait for an explicit yes before any POST.

If they say "8 hours starting at 09:00", use end time 17:00 local unless they specify otherwise.
