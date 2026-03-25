# Connectors

## How tool references work

Plugin files use `~~category` as a placeholder for whatever tool the user connects in that category. For example, `~~project tracker` might mean Jira, Linear, Asana, or any other project management tool with an MCP server.

Plugins are **tool-agnostic** — they describe workflows in terms of categories (project tracker, chat, etc.) rather than specific products. The `.mcp.json` pre-configures specific MCP servers, but any MCP server in that category works.

## Connectors for this plugin

| Category | Placeholder | Included servers | Other options |
|----------|-------------|-----------------|---------------|
| Project tracker | `~~project tracker` | Atlassian (Jira/Confluence), Linear | Asana, Monday, ClickUp |
| Chat | `~~chat` | Slack | Microsoft Teams |
| Knowledge base | `~~knowledge base` | Notion | Confluence, Guru |
| Calendar | `~~calendar` | Google Calendar | Microsoft 365 |
| Email | `~~email` | Gmail | Microsoft 365 |
