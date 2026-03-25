import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import '../content/content_loader.dart';
import '../content/skill_bundle.dart';
import '../content/skill_registry.dart';
import '../runner/agent_resolver.dart';
import '../runner/plan_parser.dart';
import '../runner/preflight.dart';
import '../runner/project_validator.dart';
import '../runner/run_config.dart';
import '../runner/step_executor.dart';
import '../utils/command_helpers.dart';

/// Executes a health audit or security audit step-by-step using an AI CLI.
///
/// Each rule runs in a fresh AI context, saving findings as artifacts.
/// Must be run from the target project's directory.
///
/// Available codes are derived dynamically from [SkillRegistry] — any
/// health or security audit bundle registered via `somnio add` is
/// automatically available without code changes.
///
/// Usage: `somnio run <code>`
class RunCommand extends Command<int> {
  RunCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'agent',
      abbr: 'a',
      help: 'AI CLI to use (auto-detected if not specified).',
      allowed: AgentRegistry.executableAgents.map((a) => a.id).toList(),
    );
    argParser.addOption(
      'model',
      abbr: 'm',
      help: 'Model to use (skips interactive selection).',
    );
    argParser.addFlag(
      'skip-validation',
      help: 'Skip project type validation.',
    );
    argParser.addFlag(
      'no-preflight',
      help: 'Skip CLI pre-flight (version setup, pub get, test coverage).',
    );
  }

  final Logger _logger;

  @override
  String get name => 'run';

  @override
  String get description =>
      'Execute a health or security audit from the project terminal.\n'
      '\n'
      'Run from the target project root (e.g., inside a Flutter or NestJS repo).\n'
      'The CLI handles setup steps (tool install, version alignment, tests)\n'
      'via pre-flight, then delegates analysis steps to an AI CLI.\n'
      '\n'
      'Artifacts are saved to ./reports/.artifacts/ and the final report\n'
      'to ./reports/{tech}_audit.txt.';

  @override
  String get invocation => 'somnio run <code>';

  /// Returns all runnable audit bundles from the registry.
  ///
  /// Runnable audits are identified by `id` ending with `_health`,
  /// `_plan`, or `_audit`.
  List<SkillBundle> get _runnableBundles =>
      SkillRegistry.skills
          .where((b) =>
              b.id.endsWith('_health') ||
              b.id.endsWith('_plan') ||
              b.id.endsWith('_audit'))
          .toList();

  /// Derives a display code from a bundle for listing.
  ///
  /// Shows the primary name and short alias if available.
  /// `flutter-health-audit` (fh)
  String _codeFromBundle(SkillBundle bundle) {
    final shortAlias = bundle.aliases.where(
      (a) => !a.startsWith('somnio-'),
    ).firstOrNull;
    if (shortAlias != null) return shortAlias;
    return bundle.name;
  }

  /// Derives the template file name from the bundle's template path.
  String _templateFileFromBundle(SkillBundle bundle) {
    if (bundle.templatePath == null) return '';
    return bundle.templatePath!.split('/').last;
  }

  /// Derives the report file name from the bundle.
  String _reportFileFromBundle(SkillBundle bundle) {
    if (bundle.id.endsWith('_plan')) {
      return '${bundle.techPrefix}_best_practices.txt';
    }
    return '${bundle.techPrefix}_audit.txt';
  }

  /// Derives the artifacts directory for a bundle.
  String _artifactsDirFromBundle(String cwd, SkillBundle bundle) =>
      p.join(cwd, 'reports', '.artifacts', bundle.id);

  /// Finds an audit bundle by name, alias, or short code.
  SkillBundle? _findBundleByCode(String code) {
    for (final bundle in _runnableBundles) {
      // Match by primary name
      if (bundle.name == code) return bundle;
      // Match by any alias (includes legacy somnio-fh and short fh)
      if (bundle.aliases.contains(code)) return bundle;
    }
    return null;
  }

  @override
  Future<int> run() async {
    final bundles = _runnableBundles;

    // 1. Parse and validate the short code
    final code = argResults!.rest.firstOrNull;
    final bundle = code != null ? _findBundleByCode(code) : null;

    if (code == null || bundle == null) {
      _logger.err(
        code == null
            ? 'Missing required argument: audit code.'
            : 'Unknown audit code: "$code".',
      );
      _logger.info('');
      _logger.info('Available audits:');
      for (final b in bundles) {
        final shortAlias = _codeFromBundle(b);
        _logger.info(
          '  ${b.name.padRight(26)} (${shortAlias.padRight(2)}) — ${b.displayName}',
        );
      }
      _logger.info('');
      _logger.info('Usage: somnio run <name-or-alias>');
      if (bundles.isNotEmpty) {
        _logger.info(
          'Example: somnio run ${bundles.first.name}',
        );
        _logger.info(
          '     or: somnio run ${_codeFromBundle(bundles.first)}',
        );
      }
      return ExitCode.usage.code;
    }

    final techPrefix = bundle.techPrefix;
    final cwd = Directory.current.path;

    // 2. Validate project type
    final skipValidation = argResults!['skip-validation'] as bool;
    if (!skipValidation) {
      final validator = ProjectValidator();
      final error = validator.validate(techPrefix, cwd);
      if (error != null) {
        _logger.err(error);
        return ExitCode.usage.code;
      }
      _logger.info(
        '${lightGreen.wrap('✓')} ${bundle.displayName.split(' ').first} '
        'project detected.',
      );
    }

    // 3. Run pre-flight checks
    final noPreflight = argResults!['no-preflight'] as bool;
    var preflightResult = PreflightResult();
    if (!noPreflight) {
      final preflight = PreflightRunner(logger: _logger);
      preflightResult = await preflight.run(techPrefix, cwd);
    }

    // 4. Resolve AI agent
    final agentFlag = argResults!['agent'] as String?;
    final agentResolver = AgentResolver();
    AgentConfig agent;

    if (agentFlag != null) {
      // Explicit --agent flag: validate it exists
      final preferredAgent = AgentRegistry.findById(agentFlag);
      if (preferredAgent == null || !preferredAgent.canExecute) {
        _logger.err('Unknown or non-executable agent: "$agentFlag".');
        return ExitCode.usage.code;
      }
      final resolved = await agentResolver.resolve(preferred: preferredAgent);
      if (resolved == null) {
        _logger.err(
          '${preferredAgent.displayName} CLI '
          '(${preferredAgent.binary ?? preferredAgent.id}) not found.',
        );
        CommandHelpers.printNoAgentsError(_logger);
        return ExitCode.software.code;
      }
      agent = resolved;
    } else {
      // No flag: detect all available, prompt if more than one
      final available = await agentResolver.detectAll();
      if (available.isEmpty) {
        CommandHelpers.printNoAgentsError(_logger);
        return ExitCode.software.code;
      }
      if (available.length == 1) {
        agent = available.first;
      } else {
        // Interactive selection
        _logger.info('');
        _logger.info('Available AI CLIs:');
        for (var i = 0; i < available.length; i++) {
          _logger.info('  ${i + 1}. ${available[i].displayName}');
        }
        final input = _logger.prompt(
          'Select CLI (1-${available.length})',
          defaultValue: '1',
        );
        final index = int.tryParse(input);
        if (index != null && index >= 1 && index <= available.length) {
          agent = available[index - 1];
        } else {
          agent = available.first;
          _logger.warn(
            'Invalid selection, using ${available.first.displayName}.',
          );
        }
      }
    }
    _logger.info(
      '${lightGreen.wrap('✓')} Using ${agent.displayName} CLI.',
    );

    // 4b. Resolve model
    final modelFlag = argResults!['model'] as String?;
    String? model;

    if (modelFlag != null) {
      if (agent.models.isNotEmpty && !agent.models.contains(modelFlag)) {
        _logger.err(
          'Model "$modelFlag" is not valid for ${agent.displayName} CLI.\n'
          'Valid models: ${agent.models.join(", ")}',
        );
        return ExitCode.usage.code;
      }
      model = modelFlag;
    } else if (agent.models.isNotEmpty) {
      final choices = agent.models;
      _logger.info('');
      _logger.info('Available ${agent.displayName} models:');
      for (var i = 0; i < choices.length; i++) {
        final tag = i == 0 ? ' (default)' : '';
        _logger.info('  ${i + 1}. ${choices[i]}$tag');
      }
      final input = _logger.prompt(
        'Select model (1-${choices.length})',
        defaultValue: '1',
      );
      final index = int.tryParse(input);
      if (index != null && index >= 1 && index <= choices.length) {
        model = choices[index - 1];
      } else {
        model = choices.first;
        _logger.warn('Invalid selection, using ${choices.first}.');
      }
    }
    if (model != null) {
      _logger.info('${lightGreen.wrap('✓')} Model: $model');
    }

    // 5. Resolve repo root
    final ResolvedContent resolvedContent;
    try {
      resolvedContent = await CommandHelpers.resolveContent();
    } catch (e) {
      _logger.err('$e');
      return ExitCode.software.code;
    }

    // 6. Execute the main bundle
    final result = await _executeBundle(
      bundle: bundle,
      agent: agent,
      model: model,
      cwd: cwd,
      repoRoot: resolvedContent.repoRoot,
      skipValidation: skipValidation,
      noPreflight: noPreflight,
      agentResolver: agentResolver,
      preflightResult: preflightResult,
    );
    final aborted = result.aborted;

    // 7. After a successful health audit, prompt for Best Practices and Security Audit
    if (!aborted && bundle.id.endsWith('_health')) {
      final bestPracticesBundle = SkillRegistry.findById('${techPrefix}_plan');
      final securityBundle = SkillRegistry.findById('security_audit');
      final followUpBundles = <SkillBundle>[];
      if (bestPracticesBundle != null) followUpBundles.add(bestPracticesBundle);
      if (securityBundle != null) followUpBundles.add(securityBundle);

      if (followUpBundles.isNotEmpty) {
        _logger.info('');
        _logger.info(
          'Would you like to run Best Practices Check and Security Audit? '
          '(somnio run ${followUpBundles.map(_codeFromBundle).join(", ")})',
        );
        final answer = _logger
            .prompt(
              'Run Best Practices and Security Audit? (y/n)',
              defaultValue: 'n',
            )
            .toLowerCase()
            .trim();
        if (answer == 'y' || answer == 'yes') {
          for (final followUp in followUpBundles) {
            _logger.info('');
            await _executeBundle(
              bundle: followUp,
              agent: agent,
              model: model,
              cwd: cwd,
              repoRoot: resolvedContent.repoRoot,
              skipValidation: true,
              noPreflight: noPreflight,
              agentResolver: agentResolver,
              preflightResult: null,
            );
          }
        }
      }
    }

    return aborted ? ExitCode.software.code : ExitCode.success.code;
  }

  /// Executes a single audit bundle.
  Future<_ExecuteBundleResult> _executeBundle({
    required SkillBundle bundle,
    required AgentConfig agent,
    required String? model,
    required String cwd,
    required String repoRoot,
    required bool skipValidation,
    required bool noPreflight,
    required AgentResolver agentResolver,
    PreflightResult? preflightResult,
  }) async {
    final techPrefix = bundle.techPrefix;

    // Validate project type
    if (!skipValidation) {
      final validator = ProjectValidator();
      final error = validator.validate(techPrefix, cwd);
      if (error != null) {
        _logger.err(error);
        return _ExecuteBundleResult(aborted: true);
      }
      _logger.info(
        '${lightGreen.wrap('✓')} ${bundle.displayName.split(' ').first} '
        'project detected.',
      );
    }

    // Run pre-flight if not provided
    var result = preflightResult ?? PreflightResult();
    if (preflightResult == null && !noPreflight) {
      final preflight = PreflightRunner(logger: _logger);
      result = await preflight.run(techPrefix, cwd);
    }
    final preflightResultForSteps = result;

    // Resolve rule paths and verify installation
    final planSubDir = bundle.planSubDir;
    final templateFile = _templateFileFromBundle(bundle);
    final reportFile = _reportFileFromBundle(bundle);

    final ruleBase = agentResolver.ruleBasePath(
      agent,
      bundle.name,
      planSubDir,
    );
    final templatePath = agentResolver.templatePath(
      agent,
      bundle.name,
      planSubDir,
      templateFile,
    );

    final loader = ContentLoader(repoRoot);
    final planContent = loader.loadPlan(bundle);

    final parser = PlanParser();
    final steps = parser.parse(planContent);
    if (steps.isEmpty) {
      _logger.err('No execution steps found in plan.');
      return _ExecuteBundleResult(aborted: true);
    }

    final preflightRuleNames = preflightResultForSteps.artifacts.keys.toSet();
    final ruleNames = steps
        .map((s) => s.ruleName)
        .where((name) => !preflightRuleNames.contains(name))
        .toList();
    if (ruleNames.isNotEmpty) {
      final verifyError = agentResolver.verifyInstallation(
        agent,
        ruleBase,
        ruleNames,
      );
      if (verifyError != null) {
        _logger.err(verifyError);
        return _ExecuteBundleResult(aborted: true);
      }
    }
    _logger.info('${lightGreen.wrap('✓')} Skills verified at: $ruleBase');

    final artifactsDir = _artifactsDirFromBundle(cwd, bundle);
    final reportPath = p.join(cwd, 'reports', reportFile);

    final config = RunConfig(
      bundleId: bundle.id,
      bundleName: bundle.name,
      displayName: bundle.displayName,
      techPrefix: techPrefix,
      agentConfig: agent,
      steps: steps,
      ruleBasePath: ruleBase,
      templatePath: templatePath,
      artifactsDir: artifactsDir,
      reportPath: reportPath,
      model: model,
    );

    _cleanPreviousRun(artifactsDir, reportPath);
    Directory(artifactsDir).createSync(recursive: true);

    final agentName = agent.displayName;
    final preflightCount = steps
        .where((s) => preflightResultForSteps.artifacts.containsKey(s.ruleName))
        .length;
    final aiCount = steps.length - preflightCount;
    _logger.info('');
    _logger.info(bundle.displayName);
    _logger.info('${'=' * bundle.displayName.length}');
    _logger.info(
      'Steps: ${steps.length} '
      '($preflightCount pre-flight, $aiCount AI) | '
      'Agent: $agentName ($model)',
    );
    _logger.info('Artifacts: $artifactsDir');
    _logger.info('Report: $reportPath');
    _logger.info('');

    final executor = StepExecutor(config: config, logger: _logger)
      ..fallbackModel = agent.fallbackModel;
    final results = <StepResult>[];
    var aborted = false;

    for (final step in steps) {
      final mandatory = step.isMandatory ? ' [MANDATORY]' : '';
      final progress = _logger.progress(
        'Step ${step.index}/${steps.length}: '
        '${step.ruleName}$mandatory',
      );

      StepResult stepResult;
      final preflightArtifact =
          preflightResultForSteps.artifacts[step.ruleName];

      if (preflightArtifact != null) {
        stepResult = await executor.writePreflightArtifact(
          step,
          preflightArtifact,
        );
      } else if (step.ruleName.endsWith('_report_generator')) {
        stepResult = await executor.executeReportGenerator(step);
      } else {
        stepResult = await executor.execute(step);
      }

      results.add(stepResult);

      if (stepResult.success) {
        if (preflightArtifact != null) {
          progress.complete(
            'Step ${step.index}/${steps.length}: ${step.ruleName} '
            '(pre-flight)',
          );
        } else {
          progress.complete(
            'Step ${step.index}/${steps.length}: ${step.ruleName}  '
            '${_formatStepStats(stepResult)}',
          );
        }

        if (step.ruleName.endsWith('_report_generator')) {
          final enforcerRuleName = step.ruleName.replaceFirst(
            '_report_generator',
            '_report_format_enforcer',
          );
          final enforcerProgress = _logger.progress(
            'Step ${step.index}/${steps.length}: format enforcement',
          );
          final enforcerResult = await executor.executeFormatEnforcer(
            step,
            enforcerRuleName,
          );
          results.add(enforcerResult);
          if (enforcerResult.success) {
            final hasWarning = enforcerResult.errorMessage != null;
            enforcerProgress.complete(
              'Step ${step.index}/${steps.length}: format enforcement  '
              '${hasWarning ? enforcerResult.errorMessage! : _formatStepStats(enforcerResult)}',
            );
          } else {
            enforcerProgress.fail(
              'Step ${step.index}/${steps.length}: '
              'format enforcement FAILED (continuing)',
            );
            if (enforcerResult.errorMessage != null) {
              _logger.warn(enforcerResult.errorMessage!);
            }
          }
        }
      } else {
        final stats = stepResult.tokenUsage != null
            ? '  ${_formatStepStats(stepResult)}  '
            : '';
        if (step.isMandatory) {
          progress.fail(
            'Step ${step.index}/${steps.length}: ${step.ruleName}'
            '${stats}FAILED (MANDATORY — aborting)',
          );
          if (stepResult.errorMessage != null) {
            _logger.err(stepResult.errorMessage!);
          }
          aborted = true;
          break;
        } else {
          progress.fail(
            'Step ${step.index}/${steps.length}: ${step.ruleName}'
            '${stats}FAILED (continuing)',
          );
          if (stepResult.errorMessage != null) {
            _logger.warn(stepResult.errorMessage!);
          }
        }
      }
    }

    _logger.info('');

    final succeeded = results.where((r) => r.success).length;
    final failed = results.where((r) => !r.success).length;
    final totalTime = results.fold<int>(
      0,
      (sum, r) => sum + r.durationSeconds,
    );
    final aiTime = results
        .where((r) => r.tokenUsage != null)
        .fold<int>(0, (sum, r) => sum + r.durationSeconds);
    final preflightTime = totalTime - aiTime;

    if (aborted) {
      _logger.err(
        'Audit ABORTED at mandatory step. '
        '$succeeded/${steps.length} steps completed.',
      );
    } else if (failed > 0) {
      _logger.warn(
        'Audit completed with warnings. '
        '$succeeded/${steps.length} steps succeeded, $failed failed.',
      );
    } else {
      _logger.success(
        'Audit completed successfully! '
        '$succeeded/${steps.length} steps in '
        '${_formatDuration(totalTime)}.',
      );
    }

    _printUsageSummary(results, totalTime, aiTime, preflightTime);

    if (!aborted && File(reportPath).existsSync()) {
      _logger.info('');
      _logger.info('Report saved to: $reportPath');
    }

    return _ExecuteBundleResult(aborted: aborted);
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes}m ${remaining}s';
  }

  String _formatTokens(int tokens) {
    if (tokens < 1000) return '$tokens';
    final k = tokens / 1000;
    return '${k.toStringAsFixed(1)}K';
  }

  String _formatStepStats(StepResult result) {
    final usage = result.tokenUsage;
    if (usage == null) return _formatDuration(result.durationSeconds);

    final it = _formatTokens(usage.totalInputTokens);
    final ot = _formatTokens(usage.outputTokens);
    final time = _formatDuration(result.durationSeconds);

    final buffer = StringBuffer('IT: $it  OT: $ot  Time: $time');
    if (usage.costUsd != null) {
      buffer.write('  Cost: \$${usage.costUsd!.toStringAsFixed(2)}');
    }
    return buffer.toString();
  }

  void _printUsageSummary(
    List<StepResult> results,
    int totalTime,
    int aiTime,
    int preflightTime,
  ) {
    final aiResults = results.where((r) => r.tokenUsage != null).toList();
    if (aiResults.isEmpty) return;

    var totalInput = 0;
    var totalOutput = 0;
    var totalCost = 0.0;
    var hasCost = false;

    for (final r in aiResults) {
      final u = r.tokenUsage!;
      totalInput += u.totalInputTokens;
      totalOutput += u.outputTokens;
      if (u.costUsd != null) {
        totalCost += u.costUsd!;
        hasCost = true;
      }
    }

    const divider = '────────────────────────────────────────────────────';
    _logger.info(divider);
    _logger.info(
      'Total tokens  ─  Input: ${_formatTokens(totalInput)}  '
      'Output: ${_formatTokens(totalOutput)}',
    );
    if (hasCost) {
      _logger.info(
        'Total cost    ─  \$${totalCost.toStringAsFixed(2)}',
      );
    }
    _logger.info(
      'Total time    ─  ${_formatDuration(totalTime)}  '
      '(AI: ${_formatDuration(aiTime)} | '
      'Pre-flight: ~${_formatDuration(preflightTime)})',
    );
    _logger.info(divider);
  }

  /// Removes previous run artifacts and report to prevent stale data.
  void _cleanPreviousRun(String artifactsDir, String reportPath) {
    final artifactsDirObj = Directory(artifactsDir);
    if (artifactsDirObj.existsSync()) {
      final files = artifactsDirObj
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();
      if (files.isNotEmpty) {
        _logger.info(
          '${lightGreen.wrap('✓')} Cleaned ${files.length} '
          'previous artifact(s).',
        );
        for (final file in files) {
          file.deleteSync();
        }
      }
    }

    final reportFile = File(reportPath);
    if (reportFile.existsSync()) {
      reportFile.deleteSync();
      _logger.info(
        '${lightGreen.wrap('✓')} Cleaned previous report.',
      );
    }
  }
}

/// Result of executing a single audit bundle.
class _ExecuteBundleResult {
  _ExecuteBundleResult({required this.aborted});
  final bool aborted;
}
