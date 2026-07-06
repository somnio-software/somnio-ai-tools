// coverage:ignore-file
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../agents/agent_config.dart';
import '../runner/agent_resolver.dart';
import '../utils/prompts.dart';
import '../workflow/workflow_config.dart';
import '../workflow/workflow_context.dart';
import '../workflow/workflow_locator.dart';
import '../workflow/workflow_planner.dart';
import '../workflow/workflow_progress.dart';
import '../workflow/workflow_runner.dart';

/// Parent command for workflow operations.
///
/// Usage: `somnio workflow <subcommand>`
class WorkflowCommand extends Command<int> {
  WorkflowCommand({required Logger logger}) : _logger = logger {
    addSubcommand(_WorkflowPlanCommand(logger: _logger));
    addSubcommand(_WorkflowRunCommand(logger: _logger));
    addSubcommand(_WorkflowConfigCommand(logger: _logger));
    addSubcommand(_WorkflowListCommand(logger: _logger));
  }

  final Logger _logger;

  @override
  String get name => 'workflow';

  @override
  String get description => 'Create, configure, and run custom workflows.';

  @override
  String get invocation => 'somnio workflow <subcommand>';
}

// ── Plan Subcommand ──────────────────────────────────────────────────

class _WorkflowPlanCommand extends Command<int> {
  _WorkflowPlanCommand({required Logger logger}) : _logger = logger;

  final Logger _logger;

  @override
  String get name => 'plan';

  @override
  String get description => 'Create a new workflow via AI-guided planning.';

  @override
  String get invocation => 'somnio workflow plan <name>';

  @override
  Future<int> run() async {
    final args = argResults!.rest;
    if (args.isEmpty) {
      _logger.err('Usage: somnio workflow plan <name>');
      return ExitCode.usage.code;
    }

    final workflowName = args.first;

    // Validate name
    if (!WorkflowLocator.isValidName(workflowName)) {
      _logger.err(
        'Invalid workflow name "$workflowName". '
        'Use kebab-case (e.g., "my-workflow").',
      );
      return ExitCode.usage.code;
    }

    final locator = WorkflowLocator();

    // Check if already exists
    if (locator.find(workflowName) != null) {
      _logger.err('Workflow "$workflowName" already exists.');
      return ExitCode.software.code;
    }

    // Ask scope
    final scope = Prompts.selectOneOf(
      'Where should this workflow be created?',
      choices: ['project', 'global'],
      defaultValue: 'project',
    );
    final workflowScope = scope == 'global'
        ? WorkflowScope.global
        : WorkflowScope.project;

    // Create directory
    final workflowDir = locator.createWorkflowDir(
      workflowName,
      scope: workflowScope,
    );

    // Resolve agent (prefer best model for planning)
    final resolver = AgentResolver();
    final agent = await resolver.resolve();
    if (agent == null) {
      _logger.err('No AI CLI found. Install Claude Code, Cursor, or Gemini.');
      return ExitCode.software.code;
    }

    // Ask for workflow description
    _logger.info('');
    final description = _logger.prompt(
      'What should this workflow do?',
    );

    _logger.info('');
    _logger.info('Creating workflow "$workflowName" using ${agent.displayName}...');
    _logger.info('');

    // Run planner
    final planner = WorkflowPlanner(
      agentConfig: agent,
      logger: _logger,
    );

    final success = await planner.plan(
      workflowName: workflowName,
      workflowDir: workflowDir,
      description: description,
    );

    if (!success) {
      _logger.err('Workflow planning failed.');
      // Clean up empty directory
      final dir = Directory(workflowDir);
      if (dir.existsSync() &&
          dir.listSync().isEmpty) {
        dir.deleteSync(recursive: true);
      }
      return ExitCode.software.code;
    }

    // Validate generated files
    final contextFile = File(p.join(workflowDir, 'context.md'));
    if (!contextFile.existsSync()) {
      _logger.err('Planner did not create context.md.');
      return ExitCode.software.code;
    }

    final context = WorkflowContext.loadFrom(contextFile.path);
    if (context == null) {
      _logger.err('Generated context.md is invalid.');
      return ExitCode.software.code;
    }

    // Verify step files exist
    var missingSteps = 0;
    for (final step in context.steps) {
      if (!File(p.join(workflowDir, step.file)).existsSync()) {
        _logger.warn('Step file missing: ${step.file}');
        missingSteps++;
      }
    }

    _logger.info('');
    _logger.success('Workflow "$workflowName" created with ${context.steps.length} steps.');
    if (missingSteps > 0) {
      _logger.warn('$missingSteps step file(s) were not created by the planner.');
    }
    _logger.info('');
    _logger.info('Next steps:');
    _logger.info('  1. Review files in: $workflowDir');
    _logger.info('  2. Configure models: somnio workflow config $workflowName');
    _logger.info('  3. Run workflow:     somnio workflow run $workflowName');

    return ExitCode.success.code;
  }
}

// ── Run Subcommand ───────────────────────────────────────────────────

class _WorkflowRunCommand extends Command<int> {
  _WorkflowRunCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'agent',
        abbr: 'a',
        help: 'AI CLI to use (auto-detected if omitted).',
      )
      ..addFlag(
        'restart',
        negatable: false,
        help: 'Restart from the beginning (ignore progress).',
      );
  }

  final Logger _logger;

  @override
  String get name => 'run';

  @override
  String get description => 'Execute a workflow step by step.';

  @override
  String get invocation => 'somnio workflow run <name>';

  @override
  Future<int> run() async {
    final args = argResults!.rest;
    if (args.isEmpty) {
      _logger.err('Usage: somnio workflow run <name>');
      return ExitCode.usage.code;
    }

    final workflowName = args.first;
    final restart = argResults!['restart'] as bool;

    // Locate workflow
    final locator = WorkflowLocator();
    final location = locator.find(workflowName);
    if (location == null) {
      _logger.err('Workflow "$workflowName" not found.');
      _logger.info('Available locations:');
      _logger.info('  Project: .somnio/workflows/$workflowName/');
      _logger.info('  Global:  ~/.somnio/workflows/$workflowName/');
      return ExitCode.software.code;
    }

    // Parse context
    final context = WorkflowContext.loadFrom(location.contextPath);
    if (context == null) {
      _logger.err('Invalid context.md in ${location.path}');
      return ExitCode.software.code;
    }

    // Resolve agent
    final resolver = AgentResolver();
    final preferredAgent = argResults!['agent'] as String?;
    AgentConfig? agent;
    if (preferredAgent != null) {
      final agentConfig =
          (await resolver.detectAll()).where((a) => a.id == preferredAgent);
      agent = agentConfig.isNotEmpty ? agentConfig.first : null;
    } else {
      agent = await resolver.resolve();
    }

    if (agent == null) {
      _logger.err(
        preferredAgent != null
            ? 'Agent "$preferredAgent" not found in PATH.'
            : 'No AI CLI found. Install Claude Code, Cursor, or Gemini.',
      );
      return ExitCode.software.code;
    }

    // Load config
    final configPath = location.configPath(agent.id);
    var config = WorkflowConfig.loadFrom(configPath);
    if (config == null) {
      _logger.warn('No config file for ${agent.displayName}.');
      _logger.info('Using default model mapping...');
      config = WorkflowConfig(
        ide: agent.id,
        byRole: WorkflowConfig.defaultRoleMapping,
      );
    }

    // Check for existing progress
    var startFromIndex = 0;
    if (!restart) {
      final existing = WorkflowProgress.loadFrom(location.progressPath);
      if (existing != null && !existing.isComplete) {
        final nextIndex = existing.nextPendingIndex;
        if (nextIndex > 0) {
          final choice = Prompts.selectOneOf(
            'Previous run found (${existing.completedCount}/${existing.steps.length} steps). Resume?',
            choices: ['resume', 'restart', 'cancel'],
            defaultValue: 'resume',
          );
          if (choice == 'cancel') return ExitCode.success.code;
          if (choice == 'resume') startFromIndex = nextIndex;
        }
      }
    }

    // Display run info
    _logger.info('');
    _logger.info('Workflow: ${context.name}');
    _logger.info('Agent:    ${agent.displayName}');
    _logger.info('Steps:    ${context.steps.length}');
    _logger.info('Scope:    ${location.scope.name}');
    if (startFromIndex > 0) {
      _logger.info('Resuming from step ${startFromIndex + 1}');
    }
    _logger.info('');

    // Run
    final runner = WorkflowRunner(
      location: location,
      context: context,
      config: config,
      agentConfig: agent,
      logger: _logger,
    );

    final result = await runner.run(startFromIndex: startFromIndex);

    // Summary
    _logger.info('');
    if (result.success) {
      final wallClock = result.wallClockSeconds;
      final compute = result.totalDurationSeconds;
      final timeLabel = wallClock != null && wallClock < compute
          ? '${wallClock}s (${compute}s compute)'
          : '${compute}s';
      _logger.success(
        'Workflow completed! '
        '${result.completedCount} steps in $timeLabel',
      );
    } else {
      _logger.err(
        'Workflow failed at step: ${result.failedStep}',
      );
      if (result.errorMessage != null) {
        _logger.err(result.errorMessage!);
      }
      _logger.info('Run "somnio workflow run $workflowName" to resume.');
    }

    _logger.info('Outputs: ${location.outputsDir}');

    return result.success ? ExitCode.success.code : ExitCode.software.code;
  }
}

// ── Config Subcommand ────────────────────────────────────────────────

class _WorkflowConfigCommand extends Command<int> {
  _WorkflowConfigCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'agent',
      abbr: 'a',
      help: 'AI CLI to configure for (auto-detected if omitted).',
    );
  }

  final Logger _logger;

  @override
  String get name => 'config';

  @override
  String get description =>
      'Configure model assignments for a workflow.';

  @override
  String get invocation => 'somnio workflow config <name>';

  @override
  Future<int> run() async {
    final args = argResults!.rest;
    if (args.isEmpty) {
      _logger.err('Usage: somnio workflow config <name>');
      return ExitCode.usage.code;
    }

    final workflowName = args.first;

    // Locate workflow
    final locator = WorkflowLocator();
    final location = locator.find(workflowName);
    if (location == null) {
      _logger.err('Workflow "$workflowName" not found.');
      return ExitCode.software.code;
    }

    // Parse context
    final context = WorkflowContext.loadFrom(location.contextPath);
    if (context == null) {
      _logger.err('Invalid context.md in ${location.path}');
      return ExitCode.software.code;
    }

    // Resolve agent
    final resolver = AgentResolver();
    final preferredAgent = argResults!['agent'] as String?;
    AgentConfig? agent;
    if (preferredAgent != null) {
      final agentConfig =
          (await resolver.detectAll()).where((a) => a.id == preferredAgent);
      agent = agentConfig.isNotEmpty ? agentConfig.first : null;
    } else {
      agent = await resolver.resolve();
    }

    if (agent == null) {
      _logger.err('No AI CLI found.');
      return ExitCode.software.code;
    }

    // Show steps
    _logger.info('');
    _logger.info('Workflow: ${context.name}');
    _logger.info('Agent:    ${agent.displayName}');
    _logger.info('');
    _logger.info('Steps:');
    for (var i = 0; i < context.steps.length; i++) {
      final step = context.steps[i];
      final mandatoryTag = step.mandatory ? ' [MANDATORY]' : '';
      _logger.info(
        '  ${i + 1}. ${step.file} (${step.tag})$mandatoryTag',
      );
    }
    _logger.info('');

    // Ask: use defaults or customize?
    final useDefaults = Prompts.selectOneOf(
      'Model mapping strategy:',
      choices: ['defaults', 'customize'],
      defaultValue: 'defaults',
    );

    Map<String, String> byRole;
    final byStep = <int, String>{};

    if (useDefaults == 'defaults') {
      byRole = Map.of(WorkflowConfig.defaultRoleMapping);
      _logger.info('Using defaults: research=haiku, planning=opus, execution=sonnet');
    } else {
      byRole = {};
      // Collect unique tags
      final tags = context.steps.map((s) => s.tag).toSet();
      for (final tag in tags) {
        if (agent.models.isNotEmpty) {
          final model = Prompts.selectOneOf(
            'Model for "$tag" steps:',
            choices: agent.models,
            defaultValue: agent.models.first,
          );
          byRole[tag] = model;
        } else {
          final model = _logger.prompt('Model for "$tag" steps:');
          byRole[tag] = model;
        }
      }

      // Per-step overrides?
      final wantOverrides = _logger.confirm(
        'Override model for specific steps?',
        defaultValue: false,
      );

      if (wantOverrides) {
        for (var i = 0; i < context.steps.length; i++) {
          final step = context.steps[i];
          final defaultModel = byRole[step.tag] ?? 'default';
          final override = _logger.confirm(
            'Override step ${i + 1} (${step.file}, currently $defaultModel)?',
            defaultValue: false,
          );
          if (override) {
            if (agent.models.isNotEmpty) {
              byStep[i + 1] = Prompts.selectOneOf(
                'Model for step ${i + 1}:',
                choices: agent.models,
              );
            } else {
              byStep[i + 1] = _logger.prompt('Model for step ${i + 1}:');
            }
          }
        }
      }
    }

    // Save config
    final configIdeName = switch (agent.id) {
      'claude' => 'claudecode',
      _ => agent.id,
    };

    final workflowConfig = WorkflowConfig(
      ide: configIdeName,
      byRole: byRole,
      byStep: byStep,
    );

    final configPath = location.configPath(agent.id);
    workflowConfig.saveTo(configPath);

    _logger.info('');
    _logger.success('Config saved to: $configPath');

    return ExitCode.success.code;
  }
}

// ── List Subcommand ──────────────────────────────────────────────────

class _WorkflowListCommand extends Command<int> {
  _WorkflowListCommand({required Logger logger}) : _logger = logger;

  final Logger _logger;

  @override
  String get name => 'list';

  @override
  String get description => 'List all available workflows.';

  @override
  String get invocation => 'somnio workflow list';

  @override
  Future<int> run() async {
    final locator = WorkflowLocator();
    final workflows = locator.listAll();

    if (workflows.isEmpty) {
      _logger.info('No workflows found.');
      _logger.info('');
      _logger.info('Create one with: somnio workflow plan <name>');
      return ExitCode.success.code;
    }

    _logger.info('');
    _logger.info('Workflows:');
    _logger.info('');

    for (final location in workflows) {
      final context = WorkflowContext.loadFrom(location.contextPath);
      final progress = WorkflowProgress.loadFrom(location.progressPath);

      final name = context?.name ?? location.name;
      final stepCount = context?.steps.length ?? 0;
      final scopeLabel = location.scope == WorkflowScope.project
          ? 'project'
          : 'global';

      String statusLabel;
      if (progress == null) {
        statusLabel = 'not run';
      } else if (progress.isComplete) {
        statusLabel = 'completed';
      } else {
        statusLabel =
            '${progress.completedCount}/${progress.steps.length} steps';
      }

      _logger.info(
        '  $name  ($stepCount steps, $scopeLabel, $statusLabel)',
      );
      if (context?.description != null && context!.description.isNotEmpty) {
        _logger.info('    ${context.description}');
      }
    }

    _logger.info('');
    return ExitCode.success.code;
  }
}