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
          artifactsDir: p.join(tempDir.path, 'reports', '.artifacts'),
          reportPath: p.join(tempDir.path, 'reports', 'audit.md'),
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
