[Home](../README.md) > Plugin System

# Plugin System

Somnio is available as a plugin for the Claude Desktop App (Cowork). The plugin system organizes skills and commands into focused packages that can be installed through the app's marketplace.

## Marketplace Structure

The root manifest at `.claude-plugin/marketplace.json` registers four plugins under the `somnio-software` organization:

| Plugin | Directory | Description |
|--------|-----------|-------------|
| `somnio-development` | `plugins/developer/` | Project health audits, security scans, best practices validation |
| `somnio-marketing` | `plugins/marketing/` | Content strategy, ASO audits, campaign analysis |
| `somnio-operations` | `plugins/operations/` | Story definition, backlog management, workflow automation |
| `somnio-engineering-management` | `plugins/engineering-management/` | Performance reviews, career path evaluation |

### Installing

1. Open **Claude Desktop App** → **Cowork** tab → **Customize** → **Explore Plugins**
2. Go to **Personal**, click **+**, paste `somnio-software/somnio-ai-tools`
3. Select which plugins to install from the marketplace

### Updating

1. Go to **Cowork** → **Customize** → **Explore Plugins** → **Personal**
2. Click the **three dots** (⋯) next to the plugin name
3. Click **Search for updates**
4. Uninstall and re-install the plugin to apply the update

---

## Plugin Anatomy

Each plugin lives under `plugins/<name>/` and contains:

```
plugins/<name>/
├── .claude-plugin/
│   └── plugin.json        # Plugin manifest (name, version, description, keywords)
├── skills/                # Skill directories or symlinks
├── commands/              # Command definitions (markdown files)
└── .mcp.json              # MCP server connectors (optional)
```

### plugin.json

```json
{
  "name": "somnio-development",
  "version": "2.0.0",
  "description": "AI-powered project health audits...",
  "author": { "name": "Somnio Software" },
  "repository": "https://github.com/somnio-software/somnio-ai-tools",
  "license": "MIT",
  "keywords": ["flutter", "nestjs", "audit", "security"]
}
```

---

## Developer Plugin

The developer plugin uses **symlinks** to share the main skills and commands:

```
plugins/developer/
├── .claude-plugin/plugin.json
├── commands -> ../../commands        # symlink
└── skills -> ../../skills            # symlink
```

This means the developer plugin always reflects the current state of the root `skills/` and `commands/` directories. Changes to skills are immediately available through the plugin.

---

## Operations Plugin

The operations plugin has its own local skills and includes MCP server connectors for external tools:

```
plugins/operations/
├── .claude-plugin/plugin.json
├── .mcp.json                         # Pre-configured MCP servers
├── CONNECTORS.md                     # Connector documentation
├── commands/                         # Local command definitions
└── skills/                           # Local skills (e.g., story-definition)
```

### Connectors

Plugin files use `~~category` placeholders for tool-agnostic integration. The `.mcp.json` pre-configures specific MCP servers, but any server in that category works.

| Category | Placeholder | Included Servers | Other Options |
|----------|-------------|-----------------|---------------|
| Project tracker | `~~project tracker` | Atlassian (Jira/Confluence), Linear | Asana, Monday, ClickUp |
| Chat | `~~chat` | Slack | Microsoft Teams |
| Knowledge base | `~~knowledge base` | Notion | Confluence, Guru |
| Calendar | `~~calendar` | Google Calendar | Microsoft 365 |
| Email | `~~email` | Gmail | Microsoft 365 |

---

## Adding a New Plugin

1. Create a directory under `plugins/`:

   ```bash
   mkdir -p plugins/my-plugin/.claude-plugin
   ```

2. Create `plugins/my-plugin/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "somnio-my-plugin",
     "version": "1.0.0",
     "description": "Description of what this plugin does.",
     "author": { "name": "Somnio Software" },
     "repository": "https://github.com/somnio-software/somnio-ai-tools",
     "license": "MIT",
     "keywords": ["your", "keywords"]
   }
   ```

3. Add skills and/or commands — either as local directories or as symlinks to shared content:

   ```bash
   # Symlink to shared skills
   ln -s ../../skills plugins/my-plugin/skills

   # Or create local skills
   mkdir -p plugins/my-plugin/skills/my-skill
   ```

4. Register in `.claude-plugin/marketplace.json`:

   ```json
   {
     "name": "somnio-my-plugin",
     "source": "./plugins/my-plugin",
     "description": "Description for the marketplace."
   }
   ```

---

**See also:** [Installation](installation.md) | [Contributing](contributing.md) | [Architecture](architecture.md)
