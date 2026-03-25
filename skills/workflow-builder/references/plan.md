# Workflow Planner

> Design and create a custom, repeatable workflow with multiple steps that can each use different AI models.

---

## What You'll Create

A workflow is a directory at `.somnio/workflows/<name>/` containing:
- `context.md` — manifest with step list, tags, dependencies, and metadata
- Step files (`01-<name>.md`, `02-<name>.md`, ...) — individual step prompts
- Config files — model assignments per IDE

## Instructions

### Step 1: Gather Requirements

If the workflow name was provided as an argument, use it. Otherwise ask the user:
1. What should this workflow accomplish?
2. What name should it have? (kebab-case, e.g., `dependency-cleanup`)
3. Should it be project-level (`.somnio/workflows/`) or global (`~/.somnio/workflows/`)?

### Step 2: Design Steps

Break the task into 3-8 steps. For each step determine:

- **Name**: descriptive, action-oriented
- **Tag**: one of:
  - `research` — analysis, reading, scanning (typically uses a fast/cheap model)
  - `planning` — strategy, decisions, prioritization (typically uses the best model)
  - `execution` — making changes, running commands (typically uses a balanced model)
- **Mandatory**: must succeed for the workflow to continue? (default: false)
- **Dependencies** (`needs`): which earlier steps must complete first?

### Step 2b: Plan Dependencies for Parallel Execution

Steps run in parallel waves. Minimize dependencies to maximize parallelism:

- Steps with **no `needs`** → wave 1 (run concurrently)
- Steps that depend on wave 1 steps → wave 2
- A final report step → `needs: all`

Values for `needs`:
- **Omitted** → independent, no dependencies
- **`needs: [1, 3]`** → depends on steps 1 and 3 (1-based)
- **`needs: all`** → depends on ALL previous steps
- **`needs: previous`** → depends on just the preceding step
- **`needs: 1`** → depends on step 1 only

### Step 3: Create Files

#### context.md

Create the manifest file with YAML frontmatter:

```markdown
---
name: <workflow-name>
description: <one-line description>
created: <ISO 8601 timestamp>
version: 1
steps:
  - file: 01-<step-name>.md
    tag: <research|planning|execution>
    mandatory: <true|false>
  - file: 02-<step-name>.md
    tag: <research|planning|execution>
    mandatory: <true|false>
    needs: [1]
  - file: 03-<step-name>.md
    tag: <research|planning|execution>
  - file: 04-<step-name>.md
    tag: <research|planning|execution>
    needs: all
---

# <workflow-name>

<Description of what this workflow does>

## Steps
1. **Step Name** (tag) - Brief description
2. ...
```

#### Step Files

Each step file uses YAML frontmatter + markdown body:

```markdown
---
name: <Step Name>
tag: <research|planning|execution>
index: <1-based>
mandatory: <true|false>
---

# <Step Name>

## Objective
<What this step should accomplish>

## Instructions
<Detailed instructions for the AI executing this step>

## Output
Save your output to: {output_path}

Include:
- <what to include>
```

### Step 4: Placeholders

Step prompts support these placeholders (resolved at runtime):

| Placeholder | Resolves to |
|---|---|
| `{output_path}` | Where this step saves its output |
| `{previous_output}` | Previous step's output path |
| `{step_N_output}` | Step N's output path (1-based, e.g., `{step_1_output}`) |
| `{outputs_dir}` | The outputs directory |
| `{workflow_dir}` | The workflow root directory |

Use `{step_N_output}` when a step needs output from specific earlier steps:

```markdown
Read codebase map from: {step_1_output}
Read secrets scan from: {step_2_output}
Read config review from: {step_3_output}
```

### Step 5: Validate

After creating all files, verify:
- [ ] `context.md` has valid YAML frontmatter
- [ ] All step files listed in context.md exist
- [ ] Step indices are sequential (1, 2, 3, ...)
- [ ] `needs` only references valid step numbers
- [ ] Dependencies form a valid DAG (no cycles)
- [ ] Independent steps have no `needs` (to maximize parallelism)
- [ ] Each step has clear instructions and uses `{output_path}`

## Rules

1. Only add `needs` when a step genuinely requires another step's output
2. Steps without `needs` run in the first parallel wave — maximize this
3. Research steps are typically independent (no `needs`)
4. A final report/summary step should use `needs: all`
5. Use `{step_N_output}` to reference specific dependency outputs
6. Use kebab-case for step filenames
7. Number files with zero-padded indices (01-, 02-, etc.)
8. Each step should be self-contained enough to run in a fresh AI context
9. Step prompts should be specific about what to analyze or do

## Next Steps

After creating the workflow, tell the user:
1. Review the generated files
2. Configure models: `somnio workflow config <name>`
3. Run the workflow: `/somnio:workflow-builder run <name>`
