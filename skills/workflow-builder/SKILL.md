---
name: workflow-builder
description: >-
  This skill should be used when the user asks to "create a workflow",
  "run a workflow", "design a task pipeline", "execute a workflow",
  "resume a workflow", or "plan a multi-step automation". Creates and
  executes custom, repeatable workflows with multiple steps that can
  each use different AI models and run in parallel waves.
  Triggers on: 'create workflow', 'run workflow', 'execute workflow',
  'workflow plan', 'workflow run', 'resume workflow', 'multi-step
  workflow', 'task pipeline', 'automation'.
argument-hint: <plan|run> <workflow-name>
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent
---

# Workflow Builder

Create and execute custom, repeatable multi-step AI workflows. Each step
can use a different model, and independent steps run in parallel waves.

## Capabilities

This skill has two modes:

| Mode | When to use | Reference |
|------|-------------|-----------|
| **Plan** | User wants to create or design a new workflow | `references/plan.md` |
| **Run** | User wants to execute, resume, or re-run a workflow | `references/run.md` |

## Quick Start

- **Create**: "Create a workflow called dependency-cleanup"
- **Run**: "Run the dependency-cleanup workflow"
- **Resume**: "Resume the dependency-cleanup workflow"

## Routing

Determine the user's intent from their message or `$ARGUMENTS`:

1. If the user says "create", "plan", "design", or "new workflow"
   → Read and follow `references/plan.md`

2. If the user says "run", "execute", "start", or "resume"
   → Read and follow `references/run.md`

3. If `$ARGUMENTS` starts with `plan`
   → Read and follow `references/plan.md` with the remaining argument as workflow name

4. If `$ARGUMENTS` starts with `run`
   → Read and follow `references/run.md` with the remaining argument as workflow name

5. If unclear, ask the user:
   "Would you like to **create a new workflow** or **run an existing one**?"

## Workflow Structure

A workflow is a directory at `.somnio/workflows/<name>/` containing:

```
.somnio/workflows/<name>/
├── context.md              — Manifest with step list and metadata
├── 01-<step-name>.md       — Step 1 prompt
├── 02-<step-name>.md       — Step 2 prompt
├── ...
├── config.claudecode.json  — Model assignments (optional)
├── progress.json           — Execution state (auto-generated)
└── outputs/                — Step output files (auto-generated)
```

## Key Concepts

- **Steps** run in fresh AI contexts (separate subagents)
- **Tags** (`research`, `planning`, `execution`) map to model assignments
- **Dependencies** (`needs`) determine parallel wave grouping
- **Placeholders** (`{output_path}`, `{step_N_output}`) enable data flow between steps
- Independent steps with no `needs` run concurrently in the same wave
