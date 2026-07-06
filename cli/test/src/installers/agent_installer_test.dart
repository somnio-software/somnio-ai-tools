import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:somnio/src/agents/agent_config.dart';
import 'package:somnio/src/content/content_loader.dart';
import 'package:somnio/src/content/skill_bundle.dart';
import 'package:somnio/src/content/workflow_skill.dart';
import 'package:somnio/src/installers/agent_installer.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

/// Writes [content] to `<root>/<relativePath>`, creating parents.
void _writeFile(String root, String relativePath, String content) {
  final file = File(p.join(root, relativePath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// Seeds a SKILL.md + references/ tree under [repoRoot] and returns the bundle.
SkillBundle _seedBundle(String repoRoot, {String name = 'flutter-health'}) {
  _writeFile(
    repoRoot,
    'skills/$name/SKILL.md',
    '---\nname: $name\n---\n\n# Plan\n\nPlan body.',
  );
  // A parseable markdown reference.
  _writeFile(
    repoRoot,
    'skills/$name/references/architecture.md',
    '# Architecture\n\n> Architecture rule\n\n'
        '**File pattern**: `*`\n\n---\n\nDo architecture things.\n',
  );
  // An asset that should be copied as-is.
  _writeFile(
    repoRoot,
    'skills/$name/references/assets/template.md',
    'TEMPLATE',
  );

  return SkillBundle(
    id: name.replaceAll('-', '_'),
    name: name,
    displayName: 'Test Skill',
    description: 'A test skill.',
    planRelativePath: 'skills/$name/SKILL.md',
    rulesDirectory: 'skills/$name/references',
  );
}

/// Seeds a bundle that also has an `agents/` directory with one subagent file.
SkillBundle _seedBundleWithAgents(
  String repoRoot, {
  String name = 'flutter-health',
}) {
  final base = _seedBundle(repoRoot, name: name);
  _writeFile(
    repoRoot,
    'skills/$name/agents/scanner.md',
    '---\nname: scanner\nmodel: cheap\n---\n\nScanner body.\n',
  );
  return SkillBundle(
    id: base.id,
    name: base.name,
    displayName: base.displayName,
    description: base.description,
    planRelativePath: base.planRelativePath,
    rulesDirectory: base.rulesDirectory,
    agentsDirectory: 'skills/$name/agents',
  );
}

void main() {
  late Directory tmp;
  late String repoRoot;
  late ContentLoader loader;
  late MockLogger logger;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('somnio_agent_inst_');
    repoRoot = tmp.path;
    loader = ContentLoader(repoRoot);
    logger = MockLogger();
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Builds a synthetic AgentConfig whose installPath is a literal temp path.
  AgentConfig agentFor({
    required InstallFormat format,
    String? executionRulesPath,
    String filePrefix = 'somnio',
    Map<String, String> modelTiers = const {},
  }) {
    return AgentConfig(
      id: 'test-agent',
      displayName: 'Test Agent',
      installFormat: format,
      installPath: p.join(tmp.path, 'install'),
      executionRulesPath: executionRulesPath,
      filePrefix: filePrefix,
      modelTiers: modelTiers,
    );
  }

  // ---------------------------------------------------------------------------
  // install()
  // ---------------------------------------------------------------------------
  group('install', () {
    test('markdown format writes files and reports counts', () async {
      final bundle = _seedBundle(repoRoot);
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.markdown),
      );

      final result = await installer.install(bundles: [bundle]);

      expect(result.skillCount, 1);
      expect(result.ruleCount, greaterThan(0));
      expect(result.skippedCount, 0);
      expect(result.targetDirectory, endsWith('install'));
    });

    test('skillDir format writes agents/ files with resolved tiers', () async {
      final bundle = _seedBundleWithAgents(repoRoot);
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(
          format: InstallFormat.skillDir,
          modelTiers: {'cheap': 'haiku', 'mid': 'sonnet', 'frontier': 'opus'},
        ),
      );

      await installer.install(bundles: [bundle]);

      final agentFile = File(p.join(
        tmp.path,
        'install',
        bundle.name,
        'agents',
        'scanner.md',
      ));
      expect(agentFile.existsSync(), isTrue);
      // Tier resolved against the target agent's modelTiers: cheap -> haiku.
      expect(agentFile.readAsStringSync(), contains('model: haiku'));
    });

    test('non-skillDir formats skip agents/ files', () async {
      final bundle = _seedBundleWithAgents(repoRoot);
      // markdown transformer does not emit agents/, and the installer also
      // guards against writing them for non-skillDir formats.
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.markdown),
      );

      await installer.install(bundles: [bundle]);

      final agentDir = Directory(p.join(
        tmp.path,
        'install',
        bundle.name,
        'agents',
      ));
      expect(agentDir.existsSync(), isFalse);
    });

    test('skips bundles when the transformer returns skipped (workflow, '
        'no workflowPath)', () async {
      // workflow transformer skips bundles without a workflowPath.
      final bundle = _seedBundle(repoRoot);
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.workflow),
      );

      final result = await installer.install(bundles: [bundle]);

      expect(result.skippedCount, 1);
      expect(result.skillCount, 0);
    });

    test('installs execution rules when executionRulesPath is set', () async {
      final bundle = _seedBundle(repoRoot);
      final rulesPath = p.join(tmp.path, 'exec-rules');
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(
          format: InstallFormat.singleFile,
          executionRulesPath: rulesPath,
        ),
      );

      final result = await installer.install(bundles: [bundle]);

      expect(result.skillCount, 1);
      // Execution rules written under <rulesPath>/<planSubDir>/references/
      final ruleMd = File(p.join(
        rulesPath,
        bundle.planSubDir,
        'references',
        'architecture.md',
      ));
      expect(ruleMd.existsSync(), isTrue);
      // Asset copied as-is.
      final asset = File(p.join(
        rulesPath,
        bundle.planSubDir,
        'references',
        'assets',
        'template.md',
      ));
      expect(asset.existsSync(), isTrue);
      expect(asset.readAsStringSync(), 'TEMPLATE');
    });

    test('logs an error and continues when a bundle fails to install',
        () async {
      // A bundle whose plan/rules files do not exist -> transform throws.
      const bad = SkillBundle(
        id: 'missing',
        name: 'missing',
        displayName: 'Missing',
        description: 'desc',
        planRelativePath: 'skills/missing/SKILL.md',
        rulesDirectory: 'skills/missing/references',
      );
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.markdown),
      );

      final result = await installer.install(bundles: [bad]);

      expect(result.skillCount, 0);
      verify(() => logger.err(any())).called(greaterThanOrEqualTo(1));
    });
  });

  // ---------------------------------------------------------------------------
  // installWorkflowSkills()
  // ---------------------------------------------------------------------------
  group('installWorkflowSkills', () {
    WorkflowSkill seedWorkflow({
      String name = 'workflow-builder',
      bool withFrontmatter = true,
    }) {
      final body = withFrontmatter
          ? '---\ndescription: old\n---\n\n# Workflow\n\nBody.'
          : '# Workflow\n\nBody.';
      _writeFile(repoRoot, 'skills/$name/SKILL.md', body);
      return WorkflowSkill(
        id: name.replaceAll('-', '_'),
        name: name,
        displayName: 'Workflow Builder',
        description: 'Builds workflows.',
        planRelativePath: 'skills/$name/SKILL.md',
      );
    }

    test('logs an error and skips the skill when writing the file throws', () {
      final skill = seedWorkflow();
      // Make the install dir's parent a FILE so creating the output path throws.
      final blocker = File(p.join(tmp.path, 'blocker'))
        ..writeAsStringSync('x');
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: AgentConfig(
          id: 'test-agent',
          displayName: 'Test Agent',
          installFormat: InstallFormat.skillDir,
          installPath: p.join(blocker.path, 'install'),
        ),
      );

      final count = installer.installWorkflowSkills([skill]);

      expect(count, 0);
      verify(() => logger.err(any())).called(1);
    });

    test('skillDir: writes <name>/SKILL.md with frontmatter, strips old', () {
      final skill = seedWorkflow();
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.skillDir),
      );

      final count = installer.installWorkflowSkills([skill]);

      expect(count, 1);
      final out = File(
        p.join(tmp.path, 'install', skill.name, 'SKILL.md'),
      ).readAsStringSync();
      expect(out, startsWith('---'));
      expect(out, contains('name: ${skill.name}'));
      expect(out, contains('# Workflow'));
      // Old frontmatter description should be stripped from the body.
      expect(out, isNot(contains('description: old')));
    });

    test('singleFile: writes <name>.md command file', () {
      final skill = seedWorkflow(name: 'cmd-skill');
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.singleFile),
      );

      final count = installer.installWorkflowSkills([skill]);

      expect(count, 1);
      expect(
        File(p.join(tmp.path, 'install', 'cmd-skill.md')).existsSync(),
        isTrue,
      );
    });

    test('workflow: writes global_workflows/somnio_<underscored>.md', () {
      final skill = seedWorkflow(name: 'wf-skill');
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.workflow),
      );

      final count = installer.installWorkflowSkills([skill]);

      expect(count, 1);
      final out = File(p.join(
        tmp.path,
        'install',
        'global_workflows',
        'somnio_wf_skill.md',
      ));
      expect(out.existsSync(), isTrue);
      expect(out.readAsStringSync(), contains('description: Builds workflows.'));
    });

    test('markdown: writes <underscored>.md with header + description', () {
      final skill = seedWorkflow(name: 'md-skill', withFrontmatter: false);
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.markdown),
      );

      final count = installer.installWorkflowSkills([skill]);

      expect(count, 1);
      final out =
          File(p.join(tmp.path, 'install', 'md_skill.md')).readAsStringSync();
      expect(out, contains('# Workflow Builder'));
      expect(out, contains('> Builds workflows.'));
      expect(out, contains('Body.'));
    });

    test('skips skills whose plan file is missing', () {
      const skill = WorkflowSkill(
        id: 'gone',
        name: 'gone',
        displayName: 'Gone',
        description: 'desc',
        planRelativePath: 'skills/gone/SKILL.md',
      );
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.markdown),
      );

      final count = installer.installWorkflowSkills([skill]);

      expect(count, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // isInstalled / installedCount / _findExistingFiles
  // ---------------------------------------------------------------------------
  group('isInstalled / installedCount', () {
    test('false / 0 when install dir does not exist', () {
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.markdown),
      );

      expect(installer.isInstalled(), isFalse);
      expect(installer.installedCount(), 0);
    });

    test('counts files matching the prefix in the install dir', () {
      final installDir = p.join(tmp.path, 'install');
      _writeFile(installDir, 'somnio_one.md', 'a');
      _writeFile(installDir, 'somnio_two.md', 'b');
      _writeFile(installDir, 'other.md', 'c');

      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.markdown),
      );

      expect(installer.isInstalled(), isTrue);
      expect(installer.installedCount(), 2);
    });

    test('workflow format searches the global_workflows/ subdirectory', () {
      final installDir = p.join(tmp.path, 'install');
      // File directly in install dir should NOT be counted for workflow.
      _writeFile(installDir, 'somnio_top.md', 'x');
      _writeFile(
          p.join(installDir, 'global_workflows'), 'somnio_a.md', 'a');
      _writeFile(
          p.join(installDir, 'global_workflows'), 'somnio_b.md', 'b');

      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.workflow),
      );

      expect(installer.isInstalled(), isTrue);
      expect(installer.installedCount(), 2);
    });

    test('respects a custom filePrefix', () {
      final installDir = p.join(tmp.path, 'install');
      _writeFile(installDir, 'custom_one.md', 'a');
      _writeFile(installDir, 'somnio_two.md', 'b');

      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(
          format: InstallFormat.markdown,
          filePrefix: 'custom_',
        ),
      );

      expect(installer.installedCount(), 1);
    });
  });
}
