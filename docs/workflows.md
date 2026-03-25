[Home](../README.md) > Workflows

# Workflow Builder

Create and execute custom, repeatable multi-step AI workflows. Each step runs in a fresh AI context and can use a different model. Independent steps run concurrently in parallel waves.

## Quick Start

```
Create a workflow called "dependency-cleanup" that audits outdated packages, plans upgrades, and executes the migration.
```

Or via CLI:

```bash
somnio workflow plan dependency-cleanup
somnio workflow run dependency-cleanup
```

---

## Workflow Structure

A workflow is a directory at `.somnio/workflows/<name>/` (project-level) or `~/.somnio/workflows/<name>/` (global):

```
.somnio/workflows/<name>/
├── context.md              # Manifest with step list and metadata
├── 01-<step-name>.md       # Step 1 prompt
├── 02-<step-name>.md       # Step 2 prompt
├── ...
├── config.claudecode.json  # Model assignments (optional)
├── progress.json           # Execution state (auto-generated)
└── outputs/                # Step output files (auto-generated)
```

---

## Key Concepts

### Steps

Each step is a markdown file with a prompt that runs in a fresh AI subagent. Steps are numbered (`01-`, `02-`, ...) and listed in `context.md`.

### Tags

Steps are tagged by role, which maps to model assignments:

| Tag | Purpose | Default Model |
|-----|---------|---------------|
| `research` | Analysis, reading, scanning | `haiku` (fast/cheap) |
| `planning` | Strategy, decisions, prioritization | `opus` (best) |
| `execution` | Making changes, running commands | `sonnet` (balanced) |

### Dependencies

The `needs` field controls execution order:

| Value | Meaning |
|-------|---------|
| *(omitted)* | Independent — runs in earliest possible wave |
| `needs: [1, 3]` | Depends on steps 1 and 3 (1-based) |
| `needs: all` | Depends on ALL previous steps |
| `needs: previous` | Depends on just the preceding step |
| `needs: 1` | Depends on step 1 only |

### Parallel Waves

Steps are grouped into waves based on dependencies:

```
Step 1: no deps       → Wave 1  ─┐
Step 3: no deps       → Wave 1  ─┤ run concurrently
Step 4: no deps       → Wave 1  ─┘
Step 2: needs [1]     → Wave 2  ─┐
Step 5: needs [3, 4]  → Wave 2  ─┤ run concurrently
Step 6: needs all     → Wave 3  ── runs last
```

Minimize dependencies to maximize parallelism.

### Placeholders

Steps can reference outputs from earlier steps:

| Placeholder | Description |
|-------------|-------------|
| `{output_path}` | Path where the current step should write its output |
| `{step_N_output}` | Path to step N's output file |

---

## Creating a Workflow

### Via skill prompt

Ask your AI agent:

```
Create a workflow called "my-workflow" that does X, Y, and Z.
```

The skill will ask clarifying questions, then generate the workflow directory with all files.

### Via CLI

```bash
somnio workflow plan my-workflow
```

### Manual creation

1. Create the directory: `mkdir -p .somnio/workflows/my-workflow`
2. Create `context.md` with YAML frontmatter listing steps
3. Create numbered step files (`01-step-name.md`, etc.)
4. Optionally create `config.claudecode.json` for model assignments

---

## Running a Workflow

### Via skill prompt

```
Run the dependency-cleanup workflow.
```

### Via CLI

```bash
somnio workflow run dependency-cleanup
somnio workflow list                     # List available workflows
```

### Resuming

If a workflow is interrupted, `progress.json` tracks which steps completed. On the next run, you'll be asked whether to resume or restart.

---

## Configuration

### Model assignments

Create `config.claudecode.json` in the workflow directory:

```json
{
  "by_role": {
    "research": "haiku",
    "planning": "opus",
    "execution": "sonnet"
  },
  "by_step": {
    "3": "opus"
  }
}
```

- `by_role` maps tags to models
- `by_step` overrides specific steps (takes precedence)

If no config exists, defaults are used: research → haiku, planning → opus, execution → sonnet.

### Managing config via CLI

```bash
somnio workflow config
```

---

**See also:** [Skills Catalog](skills.md) | [CLI Reference](cli.md) | [Architecture](architecture.md)
