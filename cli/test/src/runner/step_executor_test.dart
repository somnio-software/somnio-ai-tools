import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:somnio/src/agents/agent_config.dart';
import 'package:somnio/src/runner/run_config.dart';
import 'package:somnio/src/runner/step_executor.dart';
import 'package:test/test.dart';

void main() {
  group('StepExecutor.execute', () {
    late Directory tempDir;
    late RunConfig config;

    const step = ExecutionStep(index: 4, ruleName: 'test-coverage');

    RunConfig buildConfig({
      String? model,
      Map<String, String> modelTiers = const {},
    }) =>
        RunConfig(
          bundleId: 'python_health',
          bundleName: 'python-health-audit',
          displayName: 'Python Project Health Audit',
          techPrefix: 'python',
          model: model,
          agentConfig: AgentConfig(
            id: 'fake-agent',
            displayName: 'Fake Agent',
            binary: 'fake-agent',
            canExecute: true,
            installPath: '/tmp/somnio-fake-agent',
            modelTiers: modelTiers,
          ),
          steps: const [step],
          ruleBasePath: p.join(tempDir.path, 'references'),
          templatePath: p.join(tempDir.path, 'template.md'),
          artifactsDir:
              p.join(tempDir.path, 'reports', '.artifacts', 'flutter-health-audit'),
          reportPath: p.join(
            tempDir.path,
            'reports',
            '2026-09-14-hoopis-app-flutter-health-audit.md',
          ),
        );

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('step_executor_test');
      final ruleBasePath = p.join(tempDir.path, 'references');
      Directory(ruleBasePath).createSync(recursive: true);
      File(p.join(ruleBasePath, 'test-coverage.md'))
          .writeAsStringSync('# rule');

      config = buildConfig();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
        'exports SOMNIO_ARTIFACT_FILE with the step artifact path '
        'to the spawned AI CLI process', () async {
      Map<String, String>? capturedEnvironment;

      final executor = StepExecutor(
        config: config,
        logger: Logger(level: Level.quiet),
        processStarter: (executable, args,
            {workingDirectory, environment}) async {
          capturedEnvironment = environment;
          return _FakeProcess();
        },
      );

      await executor.execute(step);

      final expectedArtifactPath =
          p.join(config.artifactsDir, 'step_04_test-coverage.md');
      expect(
        capturedEnvironment?['SOMNIO_ARTIFACT_FILE'],
        expectedArtifactPath,
      );
    });

    test(
        'kills the AI CLI and fails the step when it outlives the deadline '
        'instead of hanging the run', () async {
      final hung = _FakeProcess(hangs: true);

      final executor = StepExecutor(
        config: config,
        logger: Logger(level: Level.quiet),
        processStarter: (executable, args,
                {workingDirectory, environment}) async =>
            hung,
        stepTimeout: const Duration(milliseconds: 50),
      );

      final result = await executor.execute(step);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Step timed out'));
      expect(hung.killSignals, [ProcessSignal.sigterm]);
    });

    test(
        'error message names the model the step actually ran with, '
        'not the run-level model', () async {
      const tierStep = ExecutionStep(
        index: 4,
        ruleName: 'test-coverage',
        model: 'frontier',
      );

      final executor = StepExecutor(
        config: buildConfig(
          model: 'run-level-model',
          modelTiers: const {'frontier': 'fake-frontier'},
        ),
        logger: Logger(level: Level.quiet),
        processStarter: (executable, args,
                {workingDirectory, environment}) async =>
            _FakeProcess(exitCode: 1, stderr: 'NOT_FOUND: model missing'),
      );

      final result = await executor.execute(tierStep);

      expect(result.errorMessage, contains('"fake-frontier"'));
      expect(result.errorMessage, isNot(contains('run-level-model')));
    });

    test('error message names the fallback model when the retry also fails',
        () async {
      final executor = StepExecutor(
        config: buildConfig(model: 'primary-model'),
        logger: Logger(level: Level.quiet),
        processStarter: (executable, args,
                {workingDirectory, environment}) async =>
            _FakeProcess(exitCode: 1, stderr: 'RESOURCE_EXHAUSTED'),
      )..fallbackModel = 'cheap-model';

      final result = await executor.execute(step);

      expect(result.errorMessage, contains('"cheap-model"'));
      expect(result.errorMessage, isNot(contains('primary-model')));
    });

    test(
        'error message labels the agent default model instead of printing '
        '"null" when no model is selected', () async {
      final executor = StepExecutor(
        config: config,
        logger: Logger(level: Level.quiet),
        processStarter: (executable, args,
                {workingDirectory, environment}) async =>
            _FakeProcess(exitCode: 1, stderr: 'NOT_FOUND'),
      );

      final result = await executor.execute(step);

      expect(result.errorMessage, contains('the Fake Agent default model'));
      expect(result.errorMessage, isNot(contains('null')));
    });
  });

  group('runBoundedProcess', () {
    test('returns the buffered output of a process that exits', () async {
      final result = await runBoundedProcess(
        'fake-agent',
        const [],
        processStarter: (executable, args,
                {workingDirectory, environment}) async =>
            _FakeProcess(exitCode: 3, stdout: 'out', stderr: 'err'),
      );

      expect(result.exitCode, 3);
      expect(result.stdout, 'out');
      expect(result.stderr, 'err');
    });

    test('escalates to SIGKILL when the child ignores SIGTERM', () async {
      final stubborn = _FakeProcess(hangs: true, ignoresSigterm: true);

      await expectLater(
        runBoundedProcess(
          'fake-agent',
          const [],
          timeout: const Duration(milliseconds: 50),
          killGracePeriod: const Duration(milliseconds: 50),
          processStarter: (executable, args,
                  {workingDirectory, environment}) async =>
              stubborn,
        ),
        throwsA(isA<StepTimeoutException>()),
      );

      expect(
        stubborn.killSignals,
        [ProcessSignal.sigterm, ProcessSignal.sigkill],
      );
    });
  });

  group('report-generator and format-enforcer prompt content', () {
    // These two prompts are shared by all 16 skills that use
    // executeReportGenerator/executeFormatEnforcer (the six
    // *-best-practices, the six *-health-audit, plus harness-audit,
    // iso27001-audit, security-audit and soc2-audit). Each skill's FORMAT
    // (section order/count, per-section fields, score-label bands, trailing
    // block shape) differs and lives in that skill's own template and rule
    // file; the shared prompt must carry only PROCESS and point at those
    // files instead of restating format facts. These tests guard against
    // reintroducing any of those per-skill format facts into the shared
    // builders.
    late Directory tempDir;
    late RunConfig promptConfig;

    const reportStep = ExecutionStep(index: 6, ruleName: 'report-generator');
    const enforcerRuleName = 'format-enforcer';

    RunConfig buildPromptConfig() => RunConfig(
          bundleId: 'python_health',
          bundleName: 'python-health-audit',
          displayName: 'Python Project Health Audit',
          techPrefix: 'python',
          agentConfig: const AgentConfig(
            id: 'fake-agent',
            displayName: 'Fake Agent',
            binary: 'fake-agent',
            canExecute: true,
            // positionalLast guarantees the prompt text is always one of
            // the spawned process's arguments (unlike PromptStyle.flag with
            // no promptFlag, which drops the prompt from args entirely), so
            // the fake processStarter below can reliably capture it.
            promptStyle: PromptStyle.positionalLast,
            installPath: '/tmp/somnio-fake-agent',
          ),
          steps: const [reportStep],
          ruleBasePath: p.join(tempDir.path, 'references'),
          templatePath: p.join(tempDir.path, 'template.md'),
          artifactsDir: p.join(
            tempDir.path,
            'reports',
            '.artifacts',
            'python-health-audit',
          ),
          reportPath: p.join(
            tempDir.path,
            'reports',
            '2026-09-21-project-python-health-audit.md',
          ),
        );

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('step_executor_prompt_test');
      final ruleBasePath = p.join(tempDir.path, 'references');
      Directory(ruleBasePath).createSync(recursive: true);
      File(p.join(ruleBasePath, 'report-generator.md'))
          .writeAsStringSync('# report generator rule');
      File(p.join(ruleBasePath, 'format-enforcer.md'))
          .writeAsStringSync('# format enforcer rule');

      promptConfig = buildPromptConfig();

      // executeFormatEnforcer requires the report to already exist.
      Directory(p.dirname(promptConfig.reportPath))
          .createSync(recursive: true);
      File(promptConfig.reportPath).writeAsStringSync('# draft report');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    Future<String> captureReportPrompt() async {
      String? prompt;
      final executor = StepExecutor(
        config: promptConfig,
        logger: Logger(level: Level.quiet),
        processStarter: (executable, args,
            {workingDirectory, environment}) async {
          prompt = args.last;
          return _FakeProcess();
        },
      );
      final result = await executor.executeReportGenerator(reportStep);
      expect(result.success, isTrue, reason: 'prompt capture setup broken');
      return prompt!;
    }

    Future<String> captureEnforcerPrompt() async {
      String? prompt;
      final executor = StepExecutor(
        config: promptConfig,
        logger: Logger(level: Level.quiet),
        processStarter: (executable, args,
            {workingDirectory, environment}) async {
          prompt = args.last;
          return _FakeProcess();
        },
      );
      final result =
          await executor.executeFormatEnforcer(reportStep, enforcerRuleName);
      expect(result.success, isTrue, reason: 'prompt capture setup broken');
      return prompt!;
    }

    test(
        'report-generator prompt does not assert a score-label band scale',
        () async {
      final prompt = await captureReportPrompt();

      // reason: security-audit's own bands (Strong 85-100 / Fair 70-84 /
      // Weak 50-69 / Critical 0-49) previously leaked into this shared
      // prompt, which all 16 skills use — twelve of them use a 3-band
      // scale and harness-audit uses a differently named 4-band scale, so
      // a hardcoded 4-band scale here is wrong for fifteen of sixteen.
      expect(prompt, isNot(contains('85-100=Strong')));
      expect(prompt, isNot(contains('0-49=Critical')));
      expect(prompt, isNot(contains('Strong/Fair/Weak/Critical')));
      expect(
        RegExp(r'\d{1,3}-\d{1,3}\s*=\s*\w+').hasMatch(prompt),
        isFalse,
        reason: 'a reworded band reintroduction (different label names, '
            'same NN-NN=Word shape) should be caught too, not just the '
            'exact strings that shipped before',
      );
    });

    test(
        'report-generator prompt asserts no ordering policy of its own '
        'for sections', () async {
      final prompt = await captureReportPrompt();

      // reason: this prompt is shared by all 16 skills, and they disagree
      // on section ordering — three (security-audit, iso27001-audit,
      // soc2-audit) mandate their scored sections be sorted dynamically by
      // score ascending, while the other thirteen mandate a fixed section
      // order. The shared prompt must defer to each skill's own template
      // and rule file rather than asserting either policy itself: it must
      // not itself instruct sorting sections by score (that would scramble
      // the thirteen skills with a fixed order), and it must not forbid
      // reordering (that would contradict the three skills whose template
      // and rule file require score-ascending ordering).
      // Matched as case-insensitive patterns, not literal substrings: a
      // reworded reintroduction ("Do NOT reorder...", "Never re-order the
      // sections") is the same bug and must fail the same way.
      expect(
        RegExp(r'sort\s+(the\s+)?(scored\s+)?sections?', caseSensitive: false)
            .hasMatch(prompt),
        isFalse,
        reason: 'prompt must not itself impose an ordering on the sections — '
            'score-ascending sorting breaks the thirteen skills whose own '
            'template fixes the section order',
      );
      expect(
        RegExp(r"(do\s+not|don't|never)\s+re-?(order|sort)", caseSensitive: false)
            .hasMatch(prompt),
        isFalse,
        reason: 'prompt must not itself forbid reordering sections — that '
            'contradicts security-audit, iso27001-audit and soc2-audit, '
            'whose templates and rule files require their scored sections '
            'to be dynamically sorted by score ascending',
      );
      expect(
        RegExp(r'(exact|same)\s+(numbered\s+)?order\s+(shown|listed|defined)\s+in\s+the\s+template',
                caseSensitive: false)
            .hasMatch(prompt),
        isFalse,
        reason: 'prompt must not restate a fixed-order policy in other words '
            'either — the template is the sole source of section order, and '
            'for three skills that order is dynamic',
      );
    });

    test(
        'report-generator prompt does not embed a plain-text --- metadata '
        'block or say the report must end with one', () async {
      final prompt = await captureReportPrompt();

      // reason: "MUST end with this exact metadata block" plus a
      // plain-text --- delimited block left no sanctioned place for the
      // unnumbered "## Appendix: Scoring Methodology" section that 13 of
      // the 16 templates carry between the Evidence Index and Report
      // Metadata, and all 16 templates render Report Metadata as a
      // | Field | Value | table, never a --- delimited block. This exact
      // phrasing is what squeezed the appendix out of the generated
      // report.
      expect(prompt, isNot(contains('MUST end with')));
      expect(prompt, isNot(contains('Add report metadata footer')));
      expect(RegExp(r'\n---\n').hasMatch(prompt), isFalse);
    });

    test(
        'report-generator prompt does not enumerate a fixed set of '
        'per-section subsection names', () async {
      final prompt = await captureReportPrompt();

      // reason: health-audit sections carry Evidence/Risks/Counts &
      // Metrics while best-practices sections carry Violations instead
      // and have no Evidence or Risks subsection at all — one fixed
      // required field list is wrong for six of the sixteen skills
      // sharing this prompt.
      expect(prompt, isNot(contains('Every scored section MUST include')));
      expect(prompt, isNot(contains('Score Breakdown')));
      expect(prompt, isNot(contains('Evidence, Risks, and Recommendations')));
    });

    test('format-enforcer prompt does not assert a score-label band scale',
        () async {
      final prompt = await captureEnforcerPrompt();

      // reason: this literal is security-audit's own band scale; the
      // enforcer used to validate all 16 skills' reports against it, so
      // e.g. harness-audit's "No harness/Basic/Solid/Paved path" bands
      // (a different count and different names entirely) would fail
      // enforcement against a scale that is not theirs.
      expect(prompt, isNot(contains('85-100=Strong, 70-84=Fair')));
      expect(
        RegExp(r'\d{1,3}-\d{1,3}\s*=\s*\w+').hasMatch(prompt),
        isFalse,
        reason: 'a reworded reintroduction of a fixed band scale should '
            'be caught too, not just the exact string that shipped before',
      );
    });

    test(
        'report-generator prompt still points the model at the rule file, '
        'the template, the artifacts dir and the report path, and still '
        'requires the file to be written', () async {
      final prompt = await captureReportPrompt();

      // reason: a test that only forbids hardcoded format facts would
      // pass if someone deleted the prompt's process instructions
      // instead of fixing the format assertions — this pins down what
      // must survive the refactor.
      expect(prompt, contains('report-generator.md'));
      expect(prompt, contains(promptConfig.templatePath));
      expect(prompt, contains(promptConfig.artifactsDir));
      expect(prompt, contains(promptConfig.reportPath));
      expect(prompt, contains('MUST write the complete report'));
    });

    test(
        'format-enforcer prompt still points the model at the rule file '
        'and the template, and still requires the result to be written',
        () async {
      final prompt = await captureEnforcerPrompt();

      expect(prompt, contains('format-enforcer.md'));
      expect(prompt, contains(promptConfig.templatePath));
      expect(prompt, contains(promptConfig.reportPath));
      expect(prompt, contains('MUST write the result'));
    });
  });
}

/// A [Process] stand-in whose lifetime the test controls.
///
/// When [hangs] is true the process never exits on its own, mimicking a stuck
/// AI CLI; [kill] then terminates it unless [ignoresSigterm] is set, in which
/// case only SIGKILL does.
class _FakeProcess implements Process {
  _FakeProcess({
    int exitCode = 0,
    String stdout = '',
    String stderr = '',
    bool hangs = false,
    this.ignoresSigterm = false,
  })  : _stdout = stdout,
        _stderr = stderr {
    if (!hangs) _exitCompleter.complete(exitCode);
  }

  final bool ignoresSigterm;
  final String _stdout;
  final String _stderr;
  final _exitCompleter = Completer<int>();

  /// Signals delivered via [kill], in order.
  final killSignals = <ProcessSignal>[];

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode(_stdout));

  @override
  Stream<List<int>> get stderr => Stream.value(utf8.encode(_stderr));

  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);

  @override
  int get pid => 4242;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killSignals.add(signal);
    final terminates = !ignoresSigterm || signal == ProcessSignal.sigkill;
    if (terminates && !_exitCompleter.isCompleted) {
      _exitCompleter.complete(-signal.signalNumber);
    }
    return true;
  }
}
