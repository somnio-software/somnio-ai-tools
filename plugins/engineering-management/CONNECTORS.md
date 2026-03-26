# Connectors

## How tool references work

Plugin files use `~~category` as a placeholder for whatever tool the user connects in that category. For example, `~~chat` might mean Slack or Microsoft Teams — any MCP server in that category works.

Plugins are **tool-agnostic** — they describe workflows in terms of categories (chat, email, etc.) rather than specific products. The `.mcp.json` pre-configures specific MCP servers, but any compatible MCP server in that category works.

## Connectors for this plugin

| Category | Placeholder | Included servers | Other options |
|----------|-------------|-----------------|---------------|
| Chat | `~~chat` | Slack | Microsoft Teams |
| Email | `~~email` | Gmail | Outlook (via Claude UI connector), Fastmail |
| Code repository | `~~code repo` | GitHub | GitLab, Bitbucket |
| Knowledge base | `~~knowledge base` | Notion | Confluence, Guru, Coda |
| Monitoring | `~~monitoring` | Datadog | New Relic, Grafana, PagerDuty |
| Calendar | `~~calendar` | Google Calendar | Outlook Calendar, Apple Calendar |
| Project tracker | `~~project tracker` | Atlassian (Jira/Confluence), ClickUp | Linear, Asana, Monday |
| Design | `~~design` | Figma | Sketch, Adobe XD, Zeplin |
| Data integration | `~~data integration` | Stitch by Google | Fivetran, Airbyte |

> **Note:** Outlook, MS365, and Zoom do not have public remote MCP server endpoints. Outlook/MS365 email and calendar are available as a Claude UI connector on Team/Enterprise plans. Zoom has no official MCP server at this time.

## Use cases for engineering management

| Connector | Example use cases |
|-----------|------------------|
| **Slack** | Post review summaries to channels, notify team leads of pending evaluations, gather async feedback |
| **Gmail** | Send review documents, schedule follow-ups, distribute acknowledgement PDFs |
| **GitHub** | Pull contribution stats (PRs, reviews, commits), assess code review activity, measure delivery velocity |
| **Notion** | Read/write career development docs, store evaluation templates, maintain team wikis |
| **Datadog** | Pull incident response metrics, on-call participation, system reliability ownership data |
| **Google Calendar** | Schedule 1:1s, check meeting load, plan review cycles |
| **Atlassian** | Pull sprint velocity, ticket completion rates, epic ownership from Jira; read confluence docs |
| **Figma** | Review design handoff activity, track design-to-dev collaboration, assess spec coverage |
| **ClickUp** | Pull task completion rates, sprint metrics, time tracking data, workload distribution |
| **Stitch** | Query consolidated engineering metrics from data warehouse, cross-source reporting |
