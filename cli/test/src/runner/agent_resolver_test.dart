import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/agents/agent_config.dart';
import 'package:somnio/src/agents/agent_registry.dart';
import 'package:somnio/src/runner/agent_resolver.dart';
import 'package:somnio/src/utils/platform_utils.dart';
import 'package:test/test.dart';

void main() {
  late AgentResolver resolver;

  setUp(() => resolver = AgentResolver());

  final home = PlatformUtils.homeDirectory;
  final claude = AgentRegistry.findById('claude')!;
  final cursor = AgentRegistry.findById('cursor')!;
  final gemini = AgentRegistry.findById('gemini')!; // default + executionRulesPath
  final codex = AgentRegistry.findById('codex')!; // default, no executionRulesPath
  final antigravity = AgentRegistry.findById('antigravity')!; // binary == null

  // ---------------------------------------------------------------------------
  // ruleBasePath (4 branches)
  // ---------------------------------------------------------------------------
  group('ruleBasePath', () {
    test('claude → ~/.claude/skills/{bundle}/references', () {
      final path = resolver.ruleBasePath(claude, 'flutter-health', 'flutter');
      expect(
        path,
        p.join(home, '.claude', 'skills', 'flutter-health', 'references'),
      );
    });

    test('cursor → ~/.cursor/somnio_rules/{planSubDir}/references', () {
      final path = resolver.ruleBasePath(cursor, 'flutter-health', 'flutter');
      expect(
        path,
        p.join(home, '.cursor', 'somnio_rules', 'flutter', 'references'),
      );
    });

    test('default with executionRulesPath uses planSubDir layout', () {
      final path = resolver.ruleBasePath(gemini, 'flutter-health', 'flutter');
      expect(
        path,
        p.join(home, '.gemini', 'somnio_rules', 'flutter', 'references'),
      );
    });

    test('default without executionRulesPath returns resolved base path', () {
      final path = resolver.ruleBasePath(codex, 'flutter-health', 'flutter');
      final base = codex.resolvedExecutionRulesPath(
        home: home,
        name: 'flutter-health',
      );
      expect(path, base);
    });
  });

  // ---------------------------------------------------------------------------
  // templatePath (4 branches)
  // ---------------------------------------------------------------------------
  group('templatePath', () {
    test('claude → ~/.claude/skills/{bundle}/assets/{file}', () {
      final path =
          resolver.templatePath(claude, 'flutter-health', 'flutter', 't.md');
      expect(
        path,
        p.join(home, '.claude', 'skills', 'flutter-health', 'assets', 't.md'),
      );
    });

    test('cursor → ~/.cursor/somnio_rules/{planSubDir}/assets/{file}', () {
      final path =
          resolver.templatePath(cursor, 'flutter-health', 'flutter', 't.md');
      expect(
        path,
        p.join(home, '.cursor', 'somnio_rules', 'flutter', 'assets', 't.md'),
      );
    });

    test('default with executionRulesPath uses planSubDir layout', () {
      final path =
          resolver.templatePath(gemini, 'flutter-health', 'flutter', 't.md');
      expect(
        path,
        p.join(home, '.gemini', 'somnio_rules', 'flutter', 'assets', 't.md'),
      );
    });

    test('default without executionRulesPath uses base/assets/{file}', () {
      final path =
          resolver.templatePath(codex, 'flutter-health', 'flutter', 't.md');
      final base = codex.resolvedExecutionRulesPath(
        home: home,
        name: 'flutter-health',
      );
      expect(path, p.join(base, 'assets', 't.md'));
    });
  });

  // ---------------------------------------------------------------------------
  // verifyInstallation (ok / dir absent / rule absent)
  // ---------------------------------------------------------------------------
  group('verifyInstallation', () {
    test('returns error when base dir is absent', () {
      final tmpDir = Directory.systemTemp.createTempSync('somnio_vi_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      final missing = p.join(tmpDir.path, 'does-not-exist');

      final error =
          resolver.verifyInstallation(claude, missing, ['architecture']);
      expect(error, isNotNull);
      expect(error, contains('Skills not found at'));
      expect(error, contains('somnio install --agent claude'));
      expect(error, contains(claude.displayName));
    });

    test('returns error when first rule file is absent', () {
      final tmpDir = Directory.systemTemp.createTempSync('somnio_vi_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final error =
          resolver.verifyInstallation(claude, tmpDir.path, ['architecture']);
      expect(error, isNotNull);
      expect(error, contains('Rule file not found'));
      expect(error, contains('somnio update'));
    });

    test('returns null when dir and first rule file exist', () {
      final tmpDir = Directory.systemTemp.createTempSync('somnio_vi_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      File(p.join(tmpDir.path, 'architecture.md')).writeAsStringSync('x');

      final error =
          resolver.verifyInstallation(claude, tmpDir.path, ['architecture']);
      expect(error, isNull);
    });

    test('uses agent ruleExtension for the rule file check', () {
      final tmpDir = Directory.systemTemp.createTempSync('somnio_vi_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      // antigravity uses .yaml — a .md file should NOT satisfy it.
      File(p.join(tmpDir.path, 'architecture.md')).writeAsStringSync('x');

      final error = resolver
          .verifyInstallation(antigravity, tmpDir.path, ['architecture']);
      expect(error, isNotNull);
      expect(error, contains('architecture.yaml'));
    });
  });

  // ---------------------------------------------------------------------------
  // ruleExtension / agentDisplayName
  // ---------------------------------------------------------------------------
  group('passthrough getters', () {
    test('ruleExtension returns agent extension', () {
      expect(resolver.ruleExtension(claude), '.md');
      expect(resolver.ruleExtension(antigravity), '.yaml');
    });

    test('agentDisplayName returns agent display name', () {
      expect(resolver.agentDisplayName(claude), 'Claude Code');
      expect(resolver.agentDisplayName(cursor), 'Cursor');
    });
  });

  // ---------------------------------------------------------------------------
  // resolve early-return when binary == null
  // ---------------------------------------------------------------------------
  group('resolve', () {
    test('returns null when preferred agent has null binary', () async {
      final result = await resolver.resolve(preferred: antigravity);
      expect(result, isNull);
    });

    // A synthetic agent whose binary ('sh') is guaranteed to be on PATH on the
    // POSIX CI/dev machines this suite runs on — exercises the whichBinary
    // success branch of resolve().
    final shAgent = const AgentConfig(
      id: 'sh-agent',
      displayName: 'Shell',
      binary: 'sh',
      canExecute: true,
      installPath: '/tmp/somnio-sh-agent',
    );
    final missingAgent = const AgentConfig(
      id: 'missing-agent',
      displayName: 'Missing',
      binary: 'somnio-definitely-not-a-real-binary-xyz',
      canExecute: true,
      installPath: '/tmp/somnio-missing-agent',
    );

    test('returns the preferred agent when its binary is on PATH', () async {
      final result = await resolver.resolve(preferred: shAgent);
      expect(result, same(shAgent));
    }, testOn: 'posix');

    test('returns null when preferred binary is not on PATH', () async {
      final result = await resolver.resolve(preferred: missingAgent);
      expect(result, isNull);
    });

    test('auto-detect iterates executable agents and returns AgentConfig?',
        () async {
      // Result depends on what is installed; we only assert the branch runs
      // and yields a nullable AgentConfig (never throws).
      final result = await resolver.resolve();
      expect(result, anyOf(isNull, isA<AgentConfig>()));
    });
  });

  group('detectAll', () {
    test('returns a list of available agents without throwing', () async {
      final result = await resolver.detectAll();
      expect(result, isA<List<AgentConfig>>());
    });
  });
}
