// coverage:ignore-file
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import '../agents/agent_config.dart';

/// Plans a workflow by invoking an AI process with a meta-prompt.
///
/// The AI generates `context.md` and step files in the workflow directory
/// based on the user-provided description.
class WorkflowPlanner {
  WorkflowPlanner({
    required this.agentConfig,
    required this.logger,
  });

  final AgentConfig agentConfig;
  final Logger logger;

  /// Invokes the AI to create the workflow.
  ///
  /// The [description] tells the AI what the workflow should accomplish.
  /// Returns `true` if the planner executed successfully.
  Future<bool> plan({
    required String workflowName,
    required String workflowDir,
    required String description,
  }) async {
    final metaPrompt = _buildMetaPrompt(workflowName, workflowDir, description);

    // Use the best available model for planning
    final model = agentConfig.models.isNotEmpty
        ? agentConfig.models.last // Last model is typically the best
        : null;

    try {
      // Build args manually: skip outputFlags (no --output-format json)
      // so the user sees Claude's output in real time.
      final args = <String>[];
      if (agentConfig.promptFlag != null) {
        args.addAll([agentConfig.promptFlag!, metaPrompt]);
      }
      args.addAll(agentConfig.autoApproveFlags);
      if (model != null) {
        args.addAll([agentConfig.modelFlag, model]);
      }

      // Use Process.start with inherited stdio so the user sees progress.
      final process = await Process.start(
        agentConfig.binary!,
        args,
        workingDirectory: Directory.current.path,
        mode: ProcessStartMode.inheritStdio,
      );

      final exitCode = await process.exitCode;
      return exitCode == 0;
    } catch (e) {
      logger.err('Failed to launch ${agentConfig.displayName}: $e');
      return false;
    }
  }

  String _buildMetaPrompt(
    String workflowName,
    String workflowDir,
    String description,
  ) {
    return '''
You are a workflow planner. Your job is to create a structured workflow.

## User Request

The user wants a workflow called "$workflowName" that does the following:
$description

## Your Task

1. Break the request down into steps (3-8 steps typically)
2. For each step, determine:
   - A descriptive name
   - The appropriate tag: "research" (analysis/reading), "planning" (strategy/decisions), or "execution" (making changes)
   - Whether it's mandatory (must succeed to continue)
   - Its dependencies via the `needs` field (see below)
3. Write all files to: $workflowDir

## Dependencies (`needs` field)

Steps can declare dependencies on other steps. Independent steps run in parallel.

- **absent/omitted** → independent (no dependencies, can run in wave 1)
- **`needs: [1, 3]`** → depends on steps 1 and 3 (1-based)
- **`needs: all`** → depends on ALL previous steps
- **`needs: previous`** → depends on just the preceding step
- **Single int** `needs: 1` → depends on step 1 only

Steps with no dependencies form wave 1 and run concurrently. Steps whose
dependencies are all in wave 1 form wave 2, etc. Maximize parallelism by
only adding `needs` when a step genuinely requires another step's output.

## Output Files

### context.md
Write this file with YAML frontmatter:

```
---
name: $workflowName
description: <one-line description>
created: ${DateTime.now().toUtc().toIso8601String()}
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

# $workflowName

<Description of what this workflow does>

## Steps
1. **Step Name** (tag) - Brief description
...
```

### Step Files (01-<name>.md, 02-<name>.md, ...)
Each step file has YAML frontmatter + a prompt body:

```
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
- <what to include in the output>
```

## Placeholder Rules

Step prompts can use these placeholders (resolved at runtime):
- `{output_path}` - Where this step should save its output
- `{previous_output}` - Path to the previous step's output. ONLY use this in a step that declares `needs: previous`; otherwise the previous step may still be running in the same wave and the placeholder is left unresolved.
- `{step_N_output}` - Path to step N's output (1-based, e.g., `{step_1_output}`, `{step_3_output}`). ONLY use this in a step whose `needs` includes step N.
- `{outputs_dir}` - The outputs directory
- `{workflow_dir}` - The workflow root directory

Use `{step_N_output}` when a step depends on specific earlier steps (e.g., a report step
that consolidates findings from steps 1, 2, and 3). Independent steps that run in parallel
must not read another step's output — declare a `needs` edge first, or read nothing.

## Rules

1. Only add `needs` when a step genuinely requires another step's output
2. Steps without `needs` run in the first parallel wave — maximize this
3. Research steps are typically independent (no `needs`)
4. A final report/summary step should use `needs: all`
5. Use `{step_N_output}` to reference specific dependency outputs
6. Use kebab-case for step filenames
7. Number step files with zero-padded indices (01-, 02-, etc.)
8. Each step should be self-contained enough to run in a fresh AI context
9. Step prompts should be clear and specific about what to analyze/do

## Important

Write all files directly. Do not ask for confirmation — the user will review the files after creation.
Create the files in: $workflowDir
''';
  }
}