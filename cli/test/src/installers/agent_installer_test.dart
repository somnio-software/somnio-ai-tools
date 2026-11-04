import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:somnio/src/agents/agent_config.dart';
import 'package:somnio/src/agents/agent_registry.dart';
import 'package:somnio/src/content/content_loader.dart';
import 'package:somnio/src/content/skill_bundle.dart';
import 'package:somnio/src/content/workflow_skill.dart';
import 'package:somnio/src/installers/agent_installer.dart';
import 'package:somnio/src/installers/skill_manifest.dart';
import 'package:somnio/src/utils/platform_utils.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

class MockLogger extends Mock implements Logger {}

/// Writes [content] to `<root>/<relativePath>`, creating parents.
void _writeFile(String root, String relativePath, String content) {
  final file = File(p.join(root, relativePath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// Seeds a SKILL.md + references/ tree under [repoRoot] and returns the bundle.
///
/// Mirrors the real `skills/<name>/` layout: `assets/` is a SIBLING of
/// `references/`, never nested inside it.
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
  // The report template, copied as-is.
  _writeFile(
    repoRoot,
    'skills/$name/assets/report-template.md',
    'TEMPLATE',
  );

  return SkillBundle(
    id: name.replaceAll('-', '_'),
    name: name,
    displayName: 'Test Skill',
    description: 'A test skill.',
    planRelativePath: 'skills/$name/SKILL.md',
    rulesDirectory: 'skills/$name/references',
    templatePath: 'skills/$name/assets/report-template.md',
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
    templatePath: base.templatePath,
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

    test('reports the names of the bundles it installed', () async {
      final bundle = _seedBundle(repoRoot);
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.markdown),
      );

      final result = await installer.install(bundles: [bundle]);

      expect(result.installedSkills, [bundle.name]);
      expect(result.failedSkills, isEmpty);
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

    test(
        'skips bundles when the transformer returns skipped (workflow, '
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
      // The template lands in <planSubDir>/assets/ — a sibling of references/,
      // which is the path AgentResolver hands to the runner's prompts.
      final template = File(p.join(
        rulesPath,
        bundle.planSubDir,
        'assets',
        'report-template.md',
      ));
      expect(template.existsSync(), isTrue);
      expect(template.readAsStringSync(), 'TEMPLATE');
    });

    test('does not install the template under references/', () async {
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

      await installer.install(bundles: [bundle]);

      expect(
        Directory(p.join(rulesPath, bundle.planSubDir, 'references', 'assets'))
            .existsSync(),
        isFalse,
      );
    });

    test('prunes stale execution rules left by a previous install', () async {
      final bundle = _seedBundle(repoRoot);
      final rulesPath = p.join(tmp.path, 'exec-rules');
      final stale = p.join(
        rulesPath,
        bundle.planSubDir,
        'references',
        'removed-upstream.md',
      );
      _writeFile(p.dirname(stale), p.basename(stale), 'OLD RULE');

      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(
          format: InstallFormat.singleFile,
          executionRulesPath: rulesPath,
        ),
      );

      await installer.install(bundles: [bundle]);

      expect(File(stale).existsSync(), isFalse);
      expect(
        File(p.join(
                rulesPath, bundle.planSubDir, 'references', 'architecture.md'))
            .existsSync(),
        isTrue,
      );
    });

    test('prunes a stale skillDir bundle directory but keeps sibling skills',
        () async {
      final bundle = _seedBundle(repoRoot);
      final baseDir = p.join(tmp.path, 'install');
      _writeFile(
        p.join(baseDir, bundle.name, 'references'),
        'removed-upstream.md',
        'OLD RULE',
      );
      // A third-party skill living next to ours must not be touched.
      _writeFile(p.join(baseDir, 'someone-elses-skill'), 'SKILL.md', 'THEIRS');

      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.skillDir),
      );

      await installer.install(bundles: [bundle]);

      expect(
        File(p.join(baseDir, bundle.name, 'references', 'removed-upstream.md'))
            .existsSync(),
        isFalse,
      );
      expect(
        File(p.join(baseDir, 'someone-elses-skill', 'SKILL.md')).existsSync(),
        isTrue,
      );
    });

    test('reports failedCount when a bundle throws', () async {
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

      final result =
          await installer.install(bundles: [bad, _seedBundle(repoRoot)]);

      expect(result.failedCount, 1);
      expect(result.skillCount, 1);
      // A skip is not a failure.
      expect(result.skippedCount, 0);
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
      expect(result.installedSkills, isEmpty);
      expect(result.failedSkills, ['missing']);
      verify(() => logger.err(any())).called(greaterThanOrEqualTo(1));
    });
  });

  // ---------------------------------------------------------------------------
  // installWorkflowSkills()
  // ---------------------------------------------------------------------------
  group('installWorkflowSkills', () {
    // The authored frontmatter is the source of truth for `description` and
    // `allowed-tools`: the description carries the trigger phrases that drive
    // skill auto-activation, which the shorter registry string drops.
    const authoredDescription =
        'Builds workflows. Use when the user asks to create a workflow.';

    WorkflowSkill seedWorkflow({
      String name = 'workflow-builder',
      bool withFrontmatter = true,
    }) {
      final body = withFrontmatter
          ? '---\ndescription: $authoredDescription\n'
              'allowed-tools: Read, Bash\n---\n\n# Workflow\n\nBody.'
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

    group('symlinked skill directory', () {
      late Directory shared;
      late String target;

      setUp(() {
        // skills.sh's shared copy, linked from the agent's skill folder.
        shared =
            Directory(p.join(tmp.path, 'agents', 'skills', 'workflow-builder'))
              ..createSync(recursive: true);
        File(p.join(shared.path, 'SKILL.md')).writeAsStringSync('shared');
        target = p.join(tmp.path, 'install', 'workflow-builder');
        Directory(p.dirname(target)).createSync(recursive: true);
        Link(target).createSync(shared.path);
      });

      test('leaves the link target untouched', () {
        final skill = seedWorkflow();
        final installer = AgentInstaller(
          logger: logger,
          loader: loader,
          agentConfig: agentFor(format: InstallFormat.skillDir),
        );

        installer.installWorkflowSkills([skill]);

        expect(
          File(p.join(shared.path, 'SKILL.md')).readAsStringSync(),
          'shared',
        );
      });

      test('replaces the link with a real directory', () {
        final skill = seedWorkflow();
        final installer = AgentInstaller(
          logger: logger,
          loader: loader,
          agentConfig: agentFor(format: InstallFormat.skillDir),
        );

        installer.installWorkflowSkills([skill]);

        expect(FileSystemEntity.isLinkSync(target), isFalse);
        expect(File(p.join(target, 'SKILL.md')).existsSync(), isTrue);
      });
    });

    test('drops files a previous install left in the skill directory', () {
      final skill = seedWorkflow();
      final stale = File(
        p.join(tmp.path, 'install', 'workflow-builder', 'references', 'old.md'),
      )..createSync(recursive: true);
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.skillDir),
      );

      installer.installWorkflowSkills([skill]);

      expect(stale.existsSync(), isFalse);
    });

    test('replaces a symlinked single-file install without following it', () {
      final skill = seedWorkflow();
      final outside = File(p.join(tmp.path, 'outside.md'))
        ..writeAsStringSync('outside');
      final linkPath = p.join(tmp.path, 'install', 'workflow-builder.md');
      Directory(p.dirname(linkPath)).createSync(recursive: true);
      Link(linkPath).createSync(outside.path);
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.singleFile),
      );

      installer.installWorkflowSkills([skill]);

      expect(outside.readAsStringSync(), 'outside');
      expect(FileSystemEntity.isLinkSync(linkPath), isFalse);
    });

    test('refuses to write through a symlinked directory', () {
      final skill = seedWorkflow();
      final outside = Directory(p.join(tmp.path, 'outside'))..createSync();
      final installDir = p.join(tmp.path, 'install');
      Directory(installDir).createSync(recursive: true);
      Link(p.join(installDir, 'global_workflows')).createSync(outside.path);
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.workflow),
      );

      final counts = installer.installWorkflowSkillsDetailed([skill]);

      expect(counts.failed, 1);
      expect(outside.listSync(), isEmpty);
    });

    test('logs an error and skips the skill when writing the file throws', () {
      final skill = seedWorkflow();
      // Make the install dir's parent a FILE so creating the output path throws.
      final blocker = File(p.join(tmp.path, 'blocker'))..writeAsStringSync('x');
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

    test('installWorkflowSkillsDetailed reports the failure count', () {
      final skill = seedWorkflow();
      final blocker = File(p.join(tmp.path, 'blocker2'))
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

      final counts = installer.installWorkflowSkillsDetailed([skill]);

      expect(counts.installed, 0);
      expect(counts.failed, 1);
      expect(counts.installedNames, isEmpty);
      expect(counts.failedNames, [skill.name]);
    });

    test('installWorkflowSkillsDetailed reports the installed names', () {
      final skill = seedWorkflow();
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.markdown),
      );

      final counts = installer.installWorkflowSkillsDetailed([skill]);

      expect(counts.installedNames, [skill.name]);
      expect(counts.failedNames, isEmpty);
    });

    test('a missing plan file is skipped, not counted as a failure', () {
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

      final counts = installer.installWorkflowSkillsDetailed([skill]);

      expect(counts.installed, 0);
      expect(counts.failed, 0);
    });

    test(
        'skillDir: authored description and allowed-tools win over the '
        'registry, and the body carries no duplicate frontmatter', () {
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
      // The trigger clause survives install — this is what activates the skill.
      expect(out, contains('Use when the user asks to create a workflow.'));
      expect(out, contains('allowed-tools: Read, Bash'));
      expect(out, isNot(contains('Builds workflows.\n')));
      // Exactly one frontmatter block: the body's copy was stripped.
      expect('---'.allMatches(out).length, 2);
    });

    test('markdown: blockquotes the authored description, not the registry one',
        () {
      final skill = seedWorkflow();
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.markdown),
      );

      installer.installWorkflowSkills([skill]);

      final out = File(
        p.join(tmp.path, 'install', 'workflow_builder.md'),
      ).readAsStringSync();
      // The branch used to emit `skill.description` while the two branches
      // above it used the authored value resolved in the same method.
      expect(out, contains('> $authoredDescription'));
      // Delimited on the newline: the registry string is a *prefix* of the
      // authored one, so an undelimited `contains` would fire either way.
      expect(out, isNot(contains('> Builds workflows.\n')));
    });

    test('markdown: quotes every line of a literal-block description', () {
      // A `|` block keeps its newlines through the YAML loader, so a bare
      // `> $description` would quote line 1 and spill the rest into body prose.
      _writeFile(
        repoRoot,
        'skills/multi-skill/SKILL.md',
        '---\n'
            'description: |\n'
            '  First line of the description.\n'
            '  Second line that must stay inside the blockquote.\n'
            '---\n\n'
            '# Body',
      );
      final skill = WorkflowSkill(
        id: 'multi_skill',
        name: 'multi-skill',
        displayName: 'Multi Skill',
        description: 'Registry blurb.',
        planRelativePath: 'skills/multi-skill/SKILL.md',
      );
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.markdown),
      );

      installer.installWorkflowSkills([skill]);

      final out = File(
        p.join(tmp.path, 'install', 'multi_skill.md'),
      ).readAsStringSync();
      expect(out, contains('> First line of the description.'));
      expect(
        out,
        contains('> Second line that must stay inside the blockquote.'),
        reason: 'a continuation line without "> " escapes the blockquote',
      );
    });

    test(
        'skillDir: falls back to the registry when the authored SKILL.md '
        'has no frontmatter', () {
      final skill = seedWorkflow(name: 'bare-skill', withFrontmatter: false);
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.skillDir),
      );

      installer.installWorkflowSkills([skill]);

      final out = File(
        p.join(tmp.path, 'install', 'bare-skill', 'SKILL.md'),
      ).readAsStringSync();
      expect(out, contains('Builds workflows.'));
      expect(
          out,
          contains('allowed-tools: Read, Edit, Write, Grep, Glob, '
              'Bash, Agent'));
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
      final text = out.readAsStringSync();
      expect(text, contains('description: >-'));
      // Authored wins: the trigger clause the registry string drops survives.
      expect(text, contains('Use when the user asks to create a workflow.'));
    });

    test(
        'workflow: a multi-line authored description is folded, not silently '
        'truncated at its first line', () {
      // A `|` literal block preserves newlines. Interpolated as a single
      // indented line under `>-`, everything after the first newline is
      // silently dropped; folding collapses it instead. optimize-claude-config
      // authors its description exactly this way.
      _writeFile(
        repoRoot,
        'skills/multi-skill/SKILL.md',
        '---\ndescription: |\n  First line of the description.\n'
            '  Second line that must not be lost.\n---\n\n# Workflow\n\nBody.',
      );
      const skill = WorkflowSkill(
        id: 'multi_skill',
        name: 'multi-skill',
        displayName: 'Multi Skill',
        description: 'Registry fallback.',
        planRelativePath: 'skills/multi-skill/SKILL.md',
      );
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.workflow),
      );

      installer.installWorkflowSkills([skill]);

      final text = File(p.join(
        tmp.path,
        'install',
        'global_workflows',
        'somnio_multi_skill.md',
      )).readAsStringSync();

      final frontmatter = text.substring(0, text.indexOf('\n---', 3));
      final parsed = loadYaml(frontmatter) as Map;
      expect(
        parsed['description'],
        'First line of the description. Second line that must not be lost.',
      );
    });

    test(
        'workflow: folded block scalar keeps a colon-bearing description '
        'valid YAML that round-trips byte-identically', () {
      const description = 'Does a thing: and another thing.';
      _writeFile(
        repoRoot,
        'skills/colon-skill/SKILL.md',
        '# Workflow\n\nBody.',
      );
      const skill = WorkflowSkill(
        id: 'colon_skill',
        name: 'colon-skill',
        displayName: 'Colon Skill',
        description: description,
        planRelativePath: 'skills/colon-skill/SKILL.md',
      );
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.workflow),
      );

      final count = installer.installWorkflowSkills([skill]);

      expect(count, 1);
      final text = File(p.join(
        tmp.path,
        'install',
        'global_workflows',
        'somnio_colon_skill.md',
      )).readAsStringSync();

      final fmEnd = text.indexOf('---', 3);
      final frontmatter = text.substring(0, fmEnd);
      expect(() => loadYaml(frontmatter), returnsNormally);
      final parsed = loadYaml(frontmatter) as Map;
      expect(parsed['description'], description);
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

    test('skillDir: skips __pycache__ and bytecode files in assetDirectories',
        () {
      final skill = seedWorkflow(name: 'dora-pyc');
      _writeFile(repoRoot, 'skills/dora-pyc/scripts/dora_metrics.py', 'ok\n');
      final pycDir = Directory(
        p.join(repoRoot, 'skills/dora-pyc/scripts/__pycache__'),
      )..createSync(recursive: true);
      // 0xFF / 0xFE are invalid UTF-8, like a real compiled .pyc.
      File(p.join(pycDir.path, 'x.cpython-314.pyc'))
          .writeAsBytesSync([0xFF, 0xFE, 0x00, 0x80]);
      File(p.join(repoRoot, 'skills/dora-pyc/scripts/stray.pyo'))
          .writeAsBytesSync([0xFF, 0xFE]);
      final withAssets = WorkflowSkill(
        id: skill.id,
        name: skill.name,
        displayName: skill.displayName,
        description: skill.description,
        planRelativePath: skill.planRelativePath,
        assetDirectories: ['skills/dora-pyc/scripts'],
      );
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.skillDir),
      );

      final count = installer.installWorkflowSkills([withAssets]);

      expect(count, 1);
      final scriptsDir = p.join(tmp.path, 'install', 'dora-pyc', 'scripts');
      expect(File(p.join(scriptsDir, 'dora_metrics.py')).readAsStringSync(),
          'ok\n');
      expect(
          Directory(p.join(scriptsDir, '__pycache__')).existsSync(), isFalse);
      final leaked = Directory(p.join(tmp.path, 'install'))
          .listSync(recursive: true)
          .map((e) => e.path)
          .where((e) =>
              e.contains('__pycache__') ||
              e.endsWith('.pyc') ||
              e.endsWith('.pyo'));
      expect(leaked, isEmpty);
    });

    test('skillDir: skips .DS_Store in assetDirectories', () {
      final skill = seedWorkflow(name: 'dora-ds');
      _writeFile(repoRoot, 'skills/dora-ds/scripts/dora_metrics.py', 'ok\n');
      File(p.join(repoRoot, 'skills/dora-ds/scripts/.DS_Store'))
          .writeAsBytesSync([0xFF, 0xFE, 0x00, 0x80]);
      final withAssets = WorkflowSkill(
        id: skill.id,
        name: skill.name,
        displayName: skill.displayName,
        description: skill.description,
        planRelativePath: skill.planRelativePath,
        assetDirectories: ['skills/dora-ds/scripts'],
      );
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.skillDir),
      );

      final count = installer.installWorkflowSkills([withAssets]);

      expect(count, 1);
      final scriptsDir = p.join(tmp.path, 'install', 'dora-ds', 'scripts');
      expect(File(p.join(scriptsDir, 'dora_metrics.py')).readAsStringSync(),
          'ok\n');
      expect(File(p.join(scriptsDir, '.DS_Store')).existsSync(), isFalse);
    });

    test('skillDir: copies assetDirectories verbatim alongside SKILL.md', () {
      final skill = seedWorkflow(name: 'dora-metrics');
      _writeFile(repoRoot, 'skills/dora-metrics/scripts/dora_metrics.py',
          'print("hi")\n');
      _writeFile(repoRoot, 'skills/dora-metrics/config/projects.json', '{}');
      final withAssets = WorkflowSkill(
        id: skill.id,
        name: skill.name,
        displayName: skill.displayName,
        description: skill.description,
        planRelativePath: skill.planRelativePath,
        assetDirectories: [
          'skills/dora-metrics/scripts',
          'skills/dora-metrics/config',
        ],
      );
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.skillDir),
      );

      final count = installer.installWorkflowSkills([withAssets]);

      expect(count, 1);
      final script = File(p.join(
        tmp.path,
        'install',
        'dora-metrics',
        'scripts',
        'dora_metrics.py',
      ));
      expect(script.existsSync(), isTrue);
      expect(script.readAsStringSync(), 'print("hi")\n');
      final config = File(p.join(
        tmp.path,
        'install',
        'dora-metrics',
        'config',
        'projects.json',
      ));
      expect(config.existsSync(), isTrue);
      expect(config.readAsStringSync(), '{}');
    });

    test('assetDirectories are ignored for non-skillDir formats', () {
      final skill = seedWorkflow(name: 'dora-metrics-2');
      _writeFile(repoRoot, 'skills/dora-metrics-2/scripts/dora_metrics.py',
          'print("hi")\n');
      final withAssets = WorkflowSkill(
        id: skill.id,
        name: skill.name,
        displayName: skill.displayName,
        description: skill.description,
        planRelativePath: skill.planRelativePath,
        assetDirectories: ['skills/dora-metrics-2/scripts'],
      );
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.singleFile),
      );

      final count = installer.installWorkflowSkills([withAssets]);

      expect(count, 1);
      final script = File(p.join(
        tmp.path,
        'install',
        'scripts',
        'dora_metrics.py',
      ));
      expect(script.existsSync(), isFalse);
    });

    test('missing assetDirectories are skipped without error', () {
      final skill = seedWorkflow(name: 'dora-metrics-3');
      final withAssets = WorkflowSkill(
        id: skill.id,
        name: skill.name,
        displayName: skill.displayName,
        description: skill.description,
        planRelativePath: skill.planRelativePath,
        assetDirectories: ['skills/dora-metrics-3/scripts'],
      );
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.skillDir),
      );

      final count = installer.installWorkflowSkills([withAssets]);

      expect(count, 1);
      final scriptDir = Directory(p.join(
        tmp.path,
        'install',
        'dora-metrics-3',
        'scripts',
      ));
      expect(scriptDir.existsSync(), isFalse);
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

    WorkflowSkill seedWorkflowWithReferences({
      String name = 'refs-skill',
    }) {
      _writeFile(
        repoRoot,
        'skills/$name/SKILL.md',
        '# Workflow\n\n'
            '  → Read and follow `references/plan.md`\n',
      );
      _writeFile(
        repoRoot,
        'skills/$name/references/plan.md',
        '# Plan\n\nPlan body.',
      );
      _writeFile(
        repoRoot,
        'skills/$name/references/run.md',
        '# Run\n\nRun body.',
      );
      return WorkflowSkill(
        id: name.replaceAll('-', '_'),
        name: name,
        displayName: 'Refs Skill',
        description: 'Has references.',
        planRelativePath: 'skills/$name/SKILL.md',
        referencesRelativePath: 'skills/$name/references',
      );
    }

    test('skillDir: also copies references/ as sibling files', () {
      final skill = seedWorkflowWithReferences();
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.skillDir),
      );

      final count = installer.installWorkflowSkills([skill]);

      expect(count, 1);
      expect(
        File(p.join(
          tmp.path,
          'install',
          skill.name,
          'references',
          'plan.md',
        )).readAsStringSync(),
        contains('Plan body.'),
      );
      expect(
        File(p.join(
          tmp.path,
          'install',
          skill.name,
          'references',
          'run.md',
        )).readAsStringSync(),
        contains('Run body.'),
      );
    });

    test(
        'markdown: inlines references/ content under a matching heading '
        'when there is no sibling directory to hold them', () {
      final skill = seedWorkflowWithReferences(name: 'refs-md-skill');
      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.markdown),
      );

      final count = installer.installWorkflowSkills([skill]);

      expect(count, 1);
      final out = File(
        p.join(tmp.path, 'install', 'refs_md_skill.md'),
      ).readAsStringSync();
      expect(out, contains('## references/plan.md'));
      expect(out, contains('Plan body.'));
      expect(out, contains('## references/run.md'));
      expect(out, contains('Run body.'));
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

    test('detects v2 installs named after the bundle, without any prefix', () {
      // Regression for the filePrefix detection bug: transformers write the
      // raw bundle name (flutter_health_audit.md), which never starts with
      // 'somnio', so a prefix-only match reported "nothing installed".
      final installDir = p.join(tmp.path, 'install');
      _writeFile(installDir, 'flutter_health_audit.md', 'a');
      _writeFile(installDir, 'react_health_audit.md', 'b');
      _writeFile(installDir, 'my_own_notes.md', 'c');

      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.markdown),
      );

      expect(installer.isInstalled(), isTrue);
      expect(installer.installedCount(), 2);
    });

    test('detects skillDir installs and ignores unrelated user dirs', () {
      final installDir = p.join(tmp.path, 'install');
      _writeFile(installDir, 'flutter-health-audit/SKILL.md', 'a');
      _writeFile(installDir, 'my-own-skill/SKILL.md', 'b');

      final installer = AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agentFor(format: InstallFormat.skillDir),
      );

      expect(installer.installedCount(), 1);
    });

    test('workflow format searches the global_workflows/ subdirectory', () {
      final installDir = p.join(tmp.path, 'install');
      // File directly in install dir should NOT be counted for workflow.
      _writeFile(installDir, 'somnio_top.md', 'x');
      _writeFile(p.join(installDir, 'global_workflows'), 'somnio_a.md', 'a');
      _writeFile(p.join(installDir, 'global_workflows'), 'somnio_b.md', 'b');

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
  // ---------------------------------------------------------------------------
  // Layout migration (markdown + somnio_rules -> skillDir)
  // ---------------------------------------------------------------------------
  group('layout migration', () {
    late String installDir;
    late String rulesDir;

    setUp(() {
      installDir = p.join(tmp.path, 'install');
      rulesDir = p.join(tmp.path, 'somnio_rules');
    });

    /// The layout CLI releases before 3.2.12 used for Codex and similar agents.
    AgentConfig legacyAgent() => AgentConfig(
          id: 'test-agent',
          displayName: 'Test Agent',
          installPath: installDir,
          executionRulesPath: rulesDir,
        );

    /// The same agent after its switch to skill directories.
    AgentConfig migratedAgent() => AgentConfig(
          id: 'test-agent',
          displayName: 'Test Agent',
          installFormat: InstallFormat.skillDir,
          installPath: installDir,
          legacyInstallFormat: InstallFormat.markdown,
          legacyExecutionRulesPath: rulesDir,
        );

    AgentInstaller installerFor(AgentConfig agent) => AgentInstaller(
          logger: logger,
          loader: loader,
          agentConfig: agent,
          environment: const {},
        );

    test('replaces the recorded flat file and rules with a skill directory',
        () async {
      final bundle = _seedBundle(repoRoot);
      await installerFor(legacyAgent()).install(bundles: [bundle]);
      expect(
          File(p.join(installDir, 'flutter_health.md')).existsSync(), isTrue);
      expect(
          Directory(p.join(rulesDir, bundle.planSubDir)).existsSync(), isTrue);

      await installerFor(migratedAgent()).install(bundles: [bundle]);

      expect(
          File(p.join(installDir, 'flutter_health.md')).existsSync(), isFalse);
      expect(
        File(p.join(installDir, bundle.name, 'SKILL.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(installDir, bundle.name, 'references', 'architecture.md'))
            .existsSync(),
        isTrue,
      );
      expect(Directory(rulesDir).existsSync(), isFalse,
          reason: 'the emptied legacy rules root is removed too');
      expect(
        SkillManifest.load(installDir).entryFor(bundle.name)!.paths,
        [ManifestPath(ManifestRoot.install, bundle.name)],
      );
    });

    test('keeps the legacy rules root while it still holds other content',
        () async {
      final bundle = _seedBundle(repoRoot);
      await installerFor(legacyAgent()).install(bundles: [bundle]);
      _writeFile(rulesDir, 'not-ours/rule.md', 'THEIRS');

      await installerFor(migratedAgent()).install(bundles: [bundle]);

      expect(
          Directory(p.join(rulesDir, bundle.planSubDir)).existsSync(), isFalse);
      expect(
          File(p.join(rulesDir, 'not-ours', 'rule.md')).existsSync(), isTrue);
    });

    test('never prunes through a symlinked directory', () async {
      final bundle = _seedBundle(repoRoot);
      final outside = Directory(p.join(tmp.path, 'outside'))..createSync();
      _writeFile(outside.path, 'sub/keep.md', 'THEIRS');
      Directory(rulesDir).createSync(recursive: true);
      Link(p.join(rulesDir, 'linked')).createSync(outside.path);
      SkillManifest.load(installDir)
        ..record(
          skill: bundle.name,
          kind: 'audit',
          paths: const [ManifestPath(ManifestRoot.rules, 'linked/sub')],
        )
        ..save();

      await installerFor(migratedAgent()).install(bundles: [bundle]);

      expect(File(p.join(outside.path, 'sub', 'keep.md')).existsSync(), isTrue);
    });

    test('leaves legacy files no manifest records untouched', () async {
      final bundle = _seedBundle(repoRoot);
      _writeFile(installDir, 'flutter_health.md', 'HAND WRITTEN');

      await installerFor(migratedAgent()).install(bundles: [bundle]);

      expect(
        File(p.join(installDir, 'flutter_health.md')).readAsStringSync(),
        'HAND WRITTEN',
      );
    });

    test('migrates workflow skills from flat files to skill directories', () {
      _writeFile(
        repoRoot,
        'skills/git-commit-format/SKILL.md',
        '---\ndescription: Writes commits.\n---\n\n# Commit\n',
      );
      const skill = WorkflowSkill(
        id: 'git_commit_format',
        name: 'git-commit-format',
        displayName: 'Git Commit Format',
        description: 'Writes commits.',
        planRelativePath: 'skills/git-commit-format/SKILL.md',
      );
      installerFor(legacyAgent()).installWorkflowSkills([skill]);
      expect(File(p.join(installDir, 'git_commit_format.md')).existsSync(),
          isTrue);

      installerFor(migratedAgent()).installWorkflowSkills([skill]);

      expect(File(p.join(installDir, 'git_commit_format.md')).existsSync(),
          isFalse);
      expect(
        File(p.join(installDir, 'git-commit-format', 'SKILL.md'))
            .readAsStringSync(),
        startsWith('---\nname: git-commit-format\n'),
      );
      expect(
        SkillManifest.load(installDir).entryFor('git-commit-format')!.paths,
        [const ManifestPath(ManifestRoot.install, 'git-commit-format')],
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Config-home override (e.g. CODEX_HOME)
  // ---------------------------------------------------------------------------
  group('config-home override', () {
    AgentConfig agent() => AgentConfig(
          id: 'test-agent',
          displayName: 'Test Agent',
          installFormat: InstallFormat.skillDir,
          installPath: p.join(tmp.path, 'default-home', 'skills'),
          configHome: p.join(tmp.path, 'default-home'),
          configHomeVariable: 'TEST_AGENT_HOME',
        );

    test('installs under the directory the variable names', () async {
      final bundle = _seedBundle(repoRoot);
      final custom = p.join(tmp.path, 'custom-home');

      final result = await AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agent(),
        environment: {'TEST_AGENT_HOME': custom},
      ).install(bundles: [bundle]);

      expect(result.targetDirectory, p.join(custom, 'skills'));
      expect(
        File(p.join(custom, 'skills', bundle.name, 'SKILL.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(custom, 'skills', SkillManifest.fileName)).existsSync(),
        isTrue,
      );
      expect(Directory(p.join(tmp.path, 'default-home')).existsSync(), isFalse);
    });

    test('falls back to the default directory when the variable is blank',
        () async {
      final bundle = _seedBundle(repoRoot);

      final result = await AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agent(),
        environment: const {'TEST_AGENT_HOME': '  '},
      ).install(bundles: [bundle]);

      expect(
          result.targetDirectory, p.join(tmp.path, 'default-home', 'skills'));
    });
  });

  // ---------------------------------------------------------------------------
  // Moved install root (Antigravity: workflows -> skill directories)
  // ---------------------------------------------------------------------------
  group('moved to a folder the agent reads', () {
    late String legacyDir;
    late String legacyRulesDir;
    late String installDir;

    setUp(() {
      legacyDir = p.join(tmp.path, 'old', 'skills');
      legacyRulesDir = p.join(tmp.path, 'old', 'somnio_rules');
      installDir = p.join(tmp.path, 'new', 'skills');
    });

    /// The layout CLI releases before 3.2.17 used for Amp.
    AgentConfig oldAgent() => AgentConfig(
          id: 'test-agent',
          displayName: 'Test Agent',
          installPath: legacyDir,
          executionRulesPath: legacyRulesDir,
        );

    /// The same agent after its move to a folder it reads.
    AgentConfig movedAgent() => AgentConfig(
          id: 'test-agent',
          displayName: 'Test Agent',
          installFormat: InstallFormat.skillDir,
          installPath: installDir,
          legacyInstallFormat: InstallFormat.markdown,
          legacyInstallPath: legacyDir,
          legacyExecutionRulesPath: legacyRulesDir,
        );

    AgentInstaller installerFor(AgentConfig agent) => AgentInstaller(
          logger: logger,
          loader: loader,
          agentConfig: agent,
          environment: const {},
        );

    test('moves a recorded skill from the legacy folder to the new one',
        () async {
      final bundle = _seedBundle(repoRoot);
      await installerFor(oldAgent()).install(bundles: [bundle]);
      expect(File(p.join(legacyDir, 'flutter_health.md')).existsSync(), isTrue);

      await installerFor(movedAgent()).install(bundles: [bundle]);

      expect(
        File(p.join(installDir, bundle.name, 'SKILL.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(legacyDir, 'flutter_health.md')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(legacyDir, SkillManifest.fileName)).existsSync(),
        isFalse,
        reason: 'the emptied legacy manifest is deleted',
      );
      expect(Directory(legacyRulesDir).existsSync(), isFalse);
      expect(SkillManifest.load(installDir).skillNames, [bundle.name]);
    });

    test('re-anchors the legacy folder at the project root for project scope',
        () async {
      final bundle = _seedBundle(repoRoot);
      final project = p.join(tmp.path, 'project');
      const agent = AgentConfig(
        id: 'test-agent',
        displayName: 'Test Agent',
        installFormat: InstallFormat.skillDir,
        installPath: '{home}/.agent/skills',
        projectInstallPath: '{home}/.github/skills',
        legacyInstallFormat: InstallFormat.markdown,
        legacyInstallPath: '{home}/.agent/old',
      );
      _writeFile(project, '.agent/old/flutter_health.md', 'OLD');
      SkillManifest.load(p.join(project, '.agent', 'old'))
        ..record(
          skill: bundle.name,
          kind: 'audit',
          paths: const [
            ManifestPath(ManifestRoot.install, 'flutter_health.md'),
          ],
        )
        ..save();

      await AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: agent,
        scope: InstallScope.project,
        projectRoot: project,
        environment: const {},
      ).install(bundles: [bundle]);

      expect(
        File(p.join(project, '.github', 'skills', bundle.name, 'SKILL.md'))
            .existsSync(),
        isTrue,
      );
      expect(
        File(p.join(project, '.agent', 'old', 'flutter_health.md'))
            .existsSync(),
        isFalse,
      );
    });

    test('moves Roo Code skills out of a project rules folder', () async {
      final bundle = _seedBundle(repoRoot);
      final project = p.join(tmp.path, 'project');
      final rules = p.join(project, '.roo', 'rules');
      _writeFile(rules, 'flutter_health.md', 'OLD');
      _writeFile(rules, 'team-conventions.md', 'Use tabs.');
      SkillManifest.load(rules)
        ..record(
          skill: bundle.name,
          kind: 'audit',
          paths: const [
            ManifestPath(ManifestRoot.install, 'flutter_health.md'),
          ],
        )
        ..save();

      await AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: AgentRegistry.findById('roo')!,
        scope: InstallScope.project,
        projectRoot: project,
        environment: const {},
      ).install(bundles: [bundle]);

      expect(
        File(p.join(project, '.roo', 'skills', bundle.name, 'SKILL.md'))
            .existsSync(),
        isTrue,
      );
      expect(
        Directory(rules).listSync().map((e) => p.basename(e.path)),
        ['team-conventions.md'],
      );
    });

    test('warns about skills a release before the manifest left behind',
        () async {
      _writeFile(
          legacyDir, 'security_audit.md', '# Security Audit\n\n> Audits.\n');
      _writeFile(legacyDir, 'notes.md', '# Notes\n\n> Mine.\n');

      await installerFor(movedAgent())
          .install(bundles: [_seedBundle(repoRoot)]);

      verify(
        () => logger.warn(
          any(
            that: allOf(
              contains(legacyDir),
              contains('security_audit.md'),
              isNot(contains('notes.md')),
            ),
          ),
        ),
      ).called(1);
    });

    test('does not warn about a legacy folder its manifest records', () async {
      _writeFile(
          legacyDir, 'security_audit.md', '# Security Audit\n\n> Audits.\n');
      SkillManifest.load(legacyDir)
        ..record(
          skill: 'security-audit',
          kind: 'audit',
          paths: const [
            ManifestPath(ManifestRoot.install, 'security_audit.md'),
          ],
        )
        ..save();

      await installerFor(movedAgent())
          .install(bundles: [_seedBundle(repoRoot)]);

      verifyNever(() => logger.warn(any()));
    });

    test('migrates through a legacy folder linked to dotfiles', () async {
      // e.g. GNU stow: the old folder lives in a dotfiles repo, but it is
      // still this agent's own install.
      final bundle = _seedBundle(repoRoot);
      await installerFor(oldAgent()).install(bundles: [bundle]);
      final dotfiles = p.join(tmp.path, 'dotfiles', 'skills');
      Directory(p.dirname(dotfiles)).createSync(recursive: true);
      Directory(legacyDir).renameSync(dotfiles);
      Link(legacyDir).createSync(dotfiles);

      await installerFor(movedAgent()).install(bundles: [bundle]);

      expect(
        File(p.join(installDir, bundle.name, 'SKILL.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(dotfiles, 'flutter_health.md')).existsSync(),
        isFalse,
      );
      expect(SkillManifest.load(dotfiles).isEmpty, isTrue);
    });

    group('does not migrate a legacy folder that is really', () {
      late SkillBundle bundle;
      late String project;
      late String claudeSkills;

      /// Amp's move, anchored at [project] by a project-scope install.
      const agent = AgentConfig(
        id: 'test-agent',
        displayName: 'Test Agent',
        installFormat: InstallFormat.skillDir,
        installPath: '{home}/.config/amp/skills',
        legacyInstallFormat: InstallFormat.markdown,
        legacyInstallPath: '{home}/.amp/skills',
      );

      Future<void> install() => AgentInstaller(
            logger: logger,
            loader: loader,
            agentConfig: agent,
            scope: InstallScope.project,
            projectRoot: project,
            environment: const {},
          ).install(bundles: [bundle]);

      String? ownLegacyDir() => AgentInstaller.ownLegacyInstallDir(
            agent,
            scope: InstallScope.project,
            home: tmp.path,
            projectRoot: project,
          );

      /// Seeds [dir] with a recorded skill, as another install would.
      void seedInstall(String dir, String content) {
        _writeFile(dir, 'flutter_health.md', content);
        SkillManifest.load(dir)
          ..record(
            skill: bundle.name,
            kind: 'audit',
            paths: const [
              ManifestPath(ManifestRoot.install, 'flutter_health.md'),
            ],
          )
          ..save();
      }

      setUp(() {
        bundle = _seedBundle(repoRoot);
        project = p.join(tmp.path, 'project');
        claudeSkills = p.join(project, '.claude', 'skills');
      });

      test('another agent\'s, through a symlinked parent', () async {
        // `.amp -> .claude`: `.amp/skills` is Claude Code's install.
        seedInstall(claudeSkills, 'CLAUDE');
        Link(p.join(project, '.amp')).createSync(p.join(project, '.claude'));

        await install();

        expect(
          File(p.join(claudeSkills, 'flutter_health.md')).readAsStringSync(),
          'CLAUDE',
        );
        expect(SkillManifest.load(claudeSkills).skillNames, [bundle.name]);
        expect(ownLegacyDir(), isNull);
      });

      test('another agent\'s, linked to it', () async {
        // `.claude -> .amp`: `.amp/skills` is a real folder, but it is
        // Claude Code's install.
        final ampSkills = p.join(project, '.amp', 'skills');
        seedInstall(ampSkills, 'CLAUDE');
        Link(p.join(project, '.claude')).createSync(p.join(project, '.amp'));

        await install();

        expect(
          File(p.join(ampSkills, 'flutter_health.md')).readAsStringSync(),
          'CLAUDE',
        );
        expect(SkillManifest.load(ampSkills).skillNames, [bundle.name]);
        expect(ownLegacyDir(), isNull);
      });

      test('the current one', () async {
        // `.amp -> .config/amp`: migrating would delete the fresh install.
        final current = p.join(project, '.config', 'amp');
        Directory(current).createSync(recursive: true);
        Link(p.join(project, '.amp')).createSync(current);

        await install();

        expect(
          File(p.join(current, 'skills', bundle.name, 'SKILL.md')).existsSync(),
          isTrue,
        );
        expect(
          SkillManifest.load(p.join(current, 'skills')).skillNames,
          [bundle.name],
        );
        expect(ownLegacyDir(), isNull);
      });
    });
  });

  group('moved install root', () {
    late String legacyDir;
    late String installDir;

    setUp(() {
      legacyDir = p.join(tmp.path, 'antigravity');
      installDir = p.join(tmp.path, 'config', 'skills');
    });

    /// The workflow layout CLI releases before 3.2.15 used for Antigravity.
    AgentConfig legacyAgent() => AgentConfig(
          id: 'test-agent',
          displayName: 'Test Agent',
          installFormat: InstallFormat.workflow,
          installPath: legacyDir,
          filePrefix: 'somnio_',
        );

    /// The same agent after its move to a skills folder.
    AgentConfig migratedAgent() => AgentConfig(
          id: 'test-agent',
          displayName: 'Test Agent',
          installFormat: InstallFormat.skillDir,
          installPath: installDir,
          legacyInstallFormat: InstallFormat.workflow,
          legacyInstallPath: legacyDir,
          legacyExecutionRulesPath: p.join(legacyDir, 'somnio_rules'),
          filePrefix: 'somnio_',
        );

    AgentInstaller installerFor(AgentConfig agent) => AgentInstaller(
          logger: logger,
          loader: loader,
          agentConfig: agent,
          environment: const {},
        );

    /// Seeds a bundle that also ships an Antigravity workflow file.
    SkillBundle seedWorkflowBundle({String name = 'flutter-health'}) {
      final base = _seedBundle(repoRoot, name: name);
      final id = name.replaceAll('-', '_');
      _writeFile(repoRoot, 'workflows/$id.md', '# $name workflow\n');
      return SkillBundle(
        id: base.id,
        name: base.name,
        displayName: base.displayName,
        description: base.description,
        planRelativePath: base.planRelativePath,
        rulesDirectory: base.rulesDirectory,
        templatePath: base.templatePath,
        workflowPath: 'workflows/$id.md',
      );
    }

    test('moves an audit bundle from the workflow layout to a skill dir',
        () async {
      final bundle = seedWorkflowBundle();
      await installerFor(legacyAgent()).install(bundles: [bundle]);
      final workflow = p.join(
        legacyDir,
        'global_workflows',
        'somnio_flutter_health.md',
      );
      expect(File(workflow).existsSync(), isTrue);
      expect(Directory(p.join(legacyDir, 'somnio_rules')).existsSync(), isTrue);

      final result =
          await installerFor(migratedAgent()).install(bundles: [bundle]);

      expect(result.targetDirectory, installDir);
      expect(
        File(p.join(installDir, bundle.name, 'SKILL.md')).existsSync(),
        isTrue,
      );
      expect(
        SkillManifest.load(installDir).entryFor(bundle.name)!.paths,
        [ManifestPath(ManifestRoot.install, bundle.name)],
      );
      expect(File(workflow).existsSync(), isFalse);
      expect(
        Directory(p.join(legacyDir, 'somnio_rules')).existsSync(),
        isFalse,
        reason: 'the per-file layout leaves only empty dirs, removed too',
      );
      expect(
        File(p.join(legacyDir, SkillManifest.fileName)).existsSync(),
        isFalse,
        reason: 'the emptied legacy manifest is deleted',
      );
    });

    test('leaves third-party workflows and the shared folder in place',
        () async {
      final bundle = seedWorkflowBundle();
      await installerFor(legacyAgent()).install(bundles: [bundle]);
      _writeFile(legacyDir, 'global_workflows/deploy.md', 'THEIRS');

      await installerFor(migratedAgent()).install(bundles: [bundle]);

      expect(
        File(p.join(legacyDir, 'global_workflows', 'deploy.md'))
            .readAsStringSync(),
        'THEIRS',
      );
    });

    test('keeps legacy entries for skills that were not reinstalled', () async {
      final kept = seedWorkflowBundle(name: 'nestjs-health');
      final moved = seedWorkflowBundle();
      await installerFor(legacyAgent()).install(bundles: [kept, moved]);

      await installerFor(migratedAgent()).install(bundles: [moved]);

      final legacy = SkillManifest.load(legacyDir);
      expect(legacy.skillNames, [kept.name]);
      for (final path in legacy.entryFor(kept.name)!.paths) {
        expect(
          File(p.join(legacyDir, path.path)).existsSync(),
          isTrue,
          reason: path.path,
        );
      }
      expect(
        Directory(p.join(legacyDir, 'somnio_rules', moved.planSubDir))
            .existsSync(),
        isFalse,
      );
    });

    test('moves workflow skills out of global_workflows', () {
      _writeFile(
        repoRoot,
        'skills/git-commit-format/SKILL.md',
        '---\ndescription: Writes commits.\n---\n\n# Commit\n',
      );
      const skill = WorkflowSkill(
        id: 'git_commit_format',
        name: 'git-commit-format',
        displayName: 'Git Commit Format',
        description: 'Writes commits.',
        planRelativePath: 'skills/git-commit-format/SKILL.md',
      );
      installerFor(legacyAgent()).installWorkflowSkills([skill]);
      final workflow = p.join(
        legacyDir,
        'global_workflows',
        'somnio_git_commit_format.md',
      );
      expect(File(workflow).existsSync(), isTrue);

      installerFor(migratedAgent()).installWorkflowSkills([skill]);

      expect(File(workflow).existsSync(), isFalse);
      expect(
        File(p.join(installDir, 'git-commit-format', 'SKILL.md'))
            .readAsStringSync(),
        startsWith('---\nname: git-commit-format\n'),
      );
      expect(SkillManifest.load(legacyDir).isEmpty, isTrue);
    });

    test('leaves legacy workflows no manifest records untouched', () async {
      final bundle = seedWorkflowBundle();
      _writeFile(
        legacyDir,
        'global_workflows/somnio_flutter_health.md',
        'PRE-MANIFEST',
      );

      await installerFor(migratedAgent()).install(bundles: [bundle]);

      expect(
        File(p.join(legacyDir, 'global_workflows', 'somnio_flutter_health.md'))
            .readAsStringSync(),
        'PRE-MANIFEST',
      );
    });

    test('never deletes through a symlinked legacy directory', () async {
      final bundle = seedWorkflowBundle();
      final outside = Directory(p.join(tmp.path, 'outside'))..createSync();
      _writeFile(outside.path, 'keep.md', 'THEIRS');
      Directory(legacyDir).createSync(recursive: true);
      Link(p.join(legacyDir, 'global_workflows')).createSync(outside.path);
      SkillManifest.load(legacyDir)
        ..record(
          skill: bundle.name,
          kind: 'audit',
          paths: const [
            ManifestPath(ManifestRoot.install, 'global_workflows/keep.md'),
          ],
        )
        ..save();

      await installerFor(migratedAgent()).install(bundles: [bundle]);

      expect(File(p.join(outside.path, 'keep.md')).existsSync(), isTrue);
    });

    test('does not migrate when the manifest is not recorded', () async {
      final bundle = seedWorkflowBundle();
      await installerFor(legacyAgent()).install(bundles: [bundle]);

      await AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: migratedAgent(),
        environment: const {},
        recordManifest: false,
      ).install(bundles: [bundle]);

      expect(SkillManifest.load(legacyDir).skillNames, [bundle.name]);
      expect(
        File(p.join(legacyDir, 'global_workflows', 'somnio_flutter_health.md'))
            .existsSync(),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Moved skill folder (OpenCode: ~/.opencode/skills -> ~/.config/opencode)
  // ---------------------------------------------------------------------------
  group('moved skill folder', () {
    late String legacyDir;
    late String legacyRulesDir;
    late String installDir;

    setUp(() {
      legacyDir = p.join(tmp.path, 'opencode', 'skills');
      legacyRulesDir = p.join(tmp.path, 'opencode', 'somnio_rules');
      installDir = p.join(tmp.path, 'config', 'opencode', 'skills');
    });

    /// The skill-directory layout releases 3.2.12 to 3.3.2 wrote to the
    /// old folder.
    AgentConfig oldFolderAgent() => AgentConfig(
          id: 'test-agent',
          displayName: 'Test Agent',
          installFormat: InstallFormat.skillDir,
          installPath: legacyDir,
          legacyInstallFormat: InstallFormat.markdown,
          legacyExecutionRulesPath: legacyRulesDir,
        );

    /// The flat-markdown layout releases before 3.2.12 wrote there.
    AgentConfig flatMarkdownAgent() => AgentConfig(
          id: 'test-agent',
          displayName: 'Test Agent',
          installFormat: InstallFormat.markdown,
          installPath: legacyDir,
          executionRulesPath: legacyRulesDir,
        );

    /// The same agent after its move to the new folder.
    AgentConfig movedAgent({String? legacyInstallPath}) => AgentConfig(
          id: 'test-agent',
          displayName: 'Test Agent',
          installFormat: InstallFormat.skillDir,
          installPath: installDir,
          legacyInstallFormat: InstallFormat.markdown,
          legacyInstallPath: legacyInstallPath ?? legacyDir,
          legacyExecutionRulesPath: legacyRulesDir,
        );

    /// The new folder with no old one to migrate from, which writes a full
    /// copy of a skill that no manifest records.
    AgentConfig newFolderOnlyAgent() => AgentConfig(
          id: 'test-agent',
          displayName: 'Test Agent',
          installFormat: InstallFormat.skillDir,
          installPath: installDir,
        );

    AgentInstaller installerFor(AgentConfig agent) => AgentInstaller(
          logger: logger,
          loader: loader,
          agentConfig: agent,
          environment: const {},
        );

    test('moves a skill directory from the old folder to the new one',
        () async {
      final bundle = _seedBundle(repoRoot);
      await installerFor(oldFolderAgent()).install(bundles: [bundle]);

      await installerFor(movedAgent()).install(bundles: [bundle]);

      expect(
        File(p.join(installDir, bundle.name, 'SKILL.md')).existsSync(),
        isTrue,
      );
      expect(Directory(p.join(legacyDir, bundle.name)).existsSync(), isFalse);
      expect(
        File(p.join(legacyDir, SkillManifest.fileName)).existsSync(),
        isFalse,
        reason: 'the emptied legacy manifest is deleted',
      );
    });

    test('moves a flat-markdown install and deletes its rules folder',
        () async {
      final bundle = _seedBundle(repoRoot);
      await installerFor(flatMarkdownAgent()).install(bundles: [bundle]);
      expect(Directory(legacyRulesDir).existsSync(), isTrue);

      await installerFor(movedAgent()).install(bundles: [bundle]);

      expect(
        File(p.join(installDir, bundle.name, 'SKILL.md')).existsSync(),
        isTrue,
      );
      expect(SkillManifest.load(legacyDir).isEmpty, isTrue);
      expect(Directory(legacyRulesDir).existsSync(), isFalse);
      expect(
        Directory(legacyDir).listSync(),
        isEmpty,
        reason: 'the recorded flat file is deleted too',
      );
    });

    test('leaves skills somnio did not install in the old folder', () async {
      final bundle = _seedBundle(repoRoot);
      await installerFor(oldFolderAgent()).install(bundles: [bundle]);
      _writeFile(legacyDir, 'my-skill/SKILL.md', 'THEIRS');

      await installerFor(movedAgent()).install(bundles: [bundle]);

      expect(
        File(p.join(legacyDir, 'my-skill', 'SKILL.md')).readAsStringSync(),
        'THEIRS',
      );
    });

    test("keeps the user's own skill of the same name in the new folder",
        () async {
      final bundle = _seedBundle(repoRoot);
      await installerFor(oldFolderAgent()).install(bundles: [bundle]);
      _writeFile(installDir, '${bundle.name}/SKILL.md', 'THEIRS');
      _writeFile(installDir, '${bundle.name}/references/mine.md', 'MINE');

      final result = await installerFor(movedAgent()).install(
        bundles: [bundle],
      );

      expect(result.skillCount, 0);
      expect(result.skippedCount, 1);
      expect(
        File(p.join(installDir, bundle.name, 'SKILL.md')).readAsStringSync(),
        'THEIRS',
      );
      expect(
        File(p.join(installDir, bundle.name, 'references', 'mine.md'))
            .readAsStringSync(),
        'MINE',
      );
      expect(SkillManifest.load(installDir).isEmpty, isTrue);
      expect(
        SkillManifest.load(legacyDir).skillNames,
        [bundle.name],
        reason: 'the legacy entry stays, so a later run can still move it',
      );
      expect(
        File(p.join(legacyDir, bundle.name, 'SKILL.md')).existsSync(),
        isTrue,
      );
      verify(() => logger.warn(any(that: contains('kept')))).called(1);

      // Once the user's copy is out of the way, the next run moves it.
      Directory(p.join(installDir, bundle.name)).deleteSync(recursive: true);
      final again = await installerFor(movedAgent()).install(
        bundles: [bundle],
      );
      expect(again.skillCount, 1);
      expect(Directory(p.join(legacyDir, bundle.name)).existsSync(), isFalse);
    });

    test('finishes a migration that was interrupted after the new copy',
        () async {
      final bundle = _seedBundle(repoRoot);
      await installerFor(oldFolderAgent()).install(bundles: [bundle]);
      // The run died with the new copy half written and the old one
      // deleted, before either manifest was saved.
      await AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: newFolderOnlyAgent(),
        environment: const {},
        recordManifest: false,
      ).install(bundles: [bundle]);
      Directory(p.join(installDir, bundle.name, 'references'))
          .deleteSync(recursive: true);
      Directory(p.join(legacyDir, bundle.name)).deleteSync(recursive: true);

      final result = await installerFor(movedAgent()).install(
        bundles: [bundle],
      );

      expect(result.skillCount, 1);
      expect(
        File(p.join(installDir, bundle.name, 'references', 'architecture.md'))
            .existsSync(),
        isTrue,
        reason: 'the missing file is written',
      );
      expect(SkillManifest.load(installDir).skillNames, [bundle.name]);
      expect(SkillManifest.load(legacyDir).isEmpty, isTrue);
    });

    test("keeps the user's own skill once the old copy is gone", () async {
      final bundle = _seedBundle(repoRoot);
      await installerFor(oldFolderAgent()).install(bundles: [bundle]);
      _writeFile(installDir, '${bundle.name}/SKILL.md', 'THEIRS');
      _writeFile(installDir, '${bundle.name}/extra.md', 'MINE');
      Directory(p.join(legacyDir, bundle.name)).deleteSync(recursive: true);

      final result = await installerFor(movedAgent()).install(
        bundles: [bundle],
      );

      expect(result.skillCount, 0);
      expect(result.skippedCount, 1);
      expect(
        File(p.join(installDir, bundle.name, 'SKILL.md')).readAsStringSync(),
        'THEIRS',
      );
      expect(
        File(p.join(installDir, bundle.name, 'extra.md')).readAsStringSync(),
        'MINE',
      );
      expect(SkillManifest.load(installDir).isEmpty, isTrue);
      expect(
        SkillManifest.load(legacyDir).skillNames,
        [bundle.name],
        reason: 'the entry stays while the folder is there',
      );
      verify(() => logger.warn(any(that: contains('kept')))).called(1);

      // Every run keeps it, not just the first.
      for (var i = 0; i < 2; i++) {
        final again = await installerFor(movedAgent()).install(
          bundles: [bundle],
        );
        expect(again.skillCount, 0);
      }
      expect(
        File(p.join(installDir, bundle.name, 'extra.md')).readAsStringSync(),
        'MINE',
      );
      expect(
        File(p.join(installDir, bundle.name, 'SKILL.md')).readAsStringSync(),
        'THEIRS',
      );

      // Once it is out of the way, the next run installs the skill.
      Directory(p.join(installDir, bundle.name)).deleteSync(recursive: true);
      final finished = await installerFor(movedAgent()).install(
        bundles: [bundle],
      );
      expect(finished.skillCount, 1);
      expect(SkillManifest.load(legacyDir).isEmpty, isTrue);
    });

    test('finishes a copy killed part way, with the old copy still there',
        () async {
      final bundle = _seedBundle(repoRoot);
      await installerFor(oldFolderAgent()).install(bundles: [bundle]);
      await AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: newFolderOnlyAgent(),
        environment: const {},
        recordManifest: false,
      ).install(bundles: [bundle]);
      // The kill left the last file empty and the references folder cut off.
      File(p.join(installDir, bundle.name, 'references', 'architecture.md'))
          .writeAsStringSync('');
      File(p.join(installDir, bundle.name, 'assets', 'report-template.md'))
          .deleteSync();

      final result = await installerFor(movedAgent()).install(
        bundles: [bundle],
      );

      expect(result.skillCount, 1);
      expect(result.skippedCount, 0);
      expect(
        File(p.join(installDir, bundle.name, 'references', 'architecture.md'))
            .readAsStringSync(),
        isNotEmpty,
      );
      expect(
        File(p.join(installDir, bundle.name, 'assets', 'report-template.md'))
            .existsSync(),
        isTrue,
      );
      expect(Directory(p.join(legacyDir, bundle.name)).existsSync(), isFalse);
      expect(SkillManifest.load(legacyDir).isEmpty, isTrue);
    });

    test('keeps a user folder with a binary file without failing', () async {
      final bundle = _seedBundle(repoRoot);
      await installerFor(oldFolderAgent()).install(bundles: [bundle]);
      Directory(p.join(installDir, bundle.name)).createSync(recursive: true);
      File(p.join(installDir, bundle.name, 'logo.png'))
          .writeAsBytesSync([0xff, 0xfe, 0x00, 0x80]);
      Directory(p.join(legacyDir, bundle.name)).deleteSync(recursive: true);

      final result = await installerFor(movedAgent()).install(
        bundles: [bundle],
      );

      expect(result.failedCount, 0);
      expect(result.skippedCount, 1);
      expect(
        File(p.join(installDir, bundle.name, 'logo.png')).existsSync(),
        isTrue,
      );
    });

    test("keeps a user's folder with the skill's own files plus an extra one",
        () async {
      final bundle = _seedBundle(repoRoot);
      await installerFor(oldFolderAgent()).install(bundles: [bundle]);
      await AgentInstaller(
        logger: logger,
        loader: loader,
        agentConfig: newFolderOnlyAgent(),
        environment: const {},
        recordManifest: false,
      ).install(bundles: [bundle]);
      _writeFile(installDir, '${bundle.name}/extra.md', 'MINE');
      Directory(p.join(legacyDir, bundle.name)).deleteSync(recursive: true);

      final result = await installerFor(movedAgent()).install(
        bundles: [bundle],
      );

      expect(result.skillCount, 0);
      expect(
        File(p.join(installDir, bundle.name, 'extra.md')).existsSync(),
        isTrue,
      );
    });

    group('a first-time install over a same-named folder', () {
      void seedTheirs(String name) {
        _writeFile(installDir, '$name/SKILL.md', 'THEIRS');
        _writeFile(installDir, '$name/extra.md', 'MINE');
      }

      void expectTheirs(String name) {
        expect(
          File(p.join(installDir, name, 'SKILL.md')).readAsStringSync(),
          'THEIRS',
        );
        expect(
          File(p.join(installDir, name, 'extra.md')).readAsStringSync(),
          'MINE',
        );
        expect(SkillManifest.load(installDir).isEmpty, isTrue);
      }

      test('A: keeps it with no legacy manifest at all', () async {
        final bundle = _seedBundle(repoRoot);
        seedTheirs(bundle.name);

        for (var i = 0; i < 2; i++) {
          final result = await installerFor(movedAgent()).install(
            bundles: [bundle],
          );
          expect(result.skillCount, 0);
          expect(result.skippedCount, 1);
          expect(result.failedCount, 0);
        }

        expectTheirs(bundle.name);
        verify(() => logger.warn(any(that: contains('kept')))).called(2);
      });

      test('B: keeps it once an uninstall cleared the legacy entry', () async {
        final bundle = _seedBundle(repoRoot);
        await installerFor(oldFolderAgent()).install(bundles: [bundle]);
        seedTheirs(bundle.name);
        await installerFor(movedAgent()).install(bundles: [bundle]);
        SkillManifest.load(legacyDir)
          ..removeEntry(bundle.name)
          ..save();

        final result = await installerFor(movedAgent()).install(
          bundles: [bundle],
        );

        expect(result.skillCount, 0);
        expectTheirs(bundle.name);
      });

      test('C: keeps it when the legacy manifest records another skill',
          () async {
        final other = _seedBundle(repoRoot, name: 'other-skill');
        final bundle = _seedBundle(repoRoot);
        await installerFor(oldFolderAgent()).install(bundles: [other]);
        seedTheirs(bundle.name);

        final result = await installerFor(movedAgent()).install(
          bundles: [bundle],
        );

        expect(result.skillCount, 0);
        expectTheirs(bundle.name);
        expect(SkillManifest.load(legacyDir).skillNames, [other.name]);
      });

      test('finishes a fresh install that was killed part way', () async {
        final bundle = _seedBundle(repoRoot);
        await AgentInstaller(
          logger: logger,
          loader: loader,
          agentConfig: newFolderOnlyAgent(),
          environment: const {},
          recordManifest: false,
        ).install(bundles: [bundle]);
        File(p.join(installDir, bundle.name, 'SKILL.md'))
            .writeAsStringSync('---\nname: flu');
        File(p.join(installDir, bundle.name, 'assets', 'report-template.md'))
            .deleteSync();

        final result = await installerFor(movedAgent()).install(
          bundles: [bundle],
        );

        expect(result.skillCount, 1);
        expect(SkillManifest.load(installDir).skillNames, [bundle.name]);
        expect(
          File(p.join(installDir, bundle.name, 'SKILL.md')).readAsStringSync(),
          contains('Plan body.'),
        );
      });

      test('keeps a folder with a subfolder that cannot be listed', () async {
        final bundle = _seedBundle(repoRoot);
        seedTheirs(bundle.name);
        _writeFile(installDir, '${bundle.name}/private/notes.md', 'MINE');
        final hidden = p.join(installDir, bundle.name, 'private');
        Process.runSync('chmod', ['000', hidden]);
        addTearDown(() => Process.runSync('chmod', ['755', hidden]));

        final result = await installerFor(movedAgent()).install(
          bundles: [bundle],
        );

        expect(result.failedCount, 0);
        expect(result.skippedCount, 1);
        expectTheirs(bundle.name);
      }, testOn: 'posix');

      group('workflow skills', () {
        WorkflowSkill seedWorkflow(String name) {
          _writeFile(repoRoot, 'skills/$name/SKILL.md', '# Workflow\n\nBody.');
          return WorkflowSkill(
            id: name.replaceAll('-', '_'),
            name: name,
            displayName: 'Workflow Builder',
            description: 'Builds workflows.',
            planRelativePath: 'skills/$name/SKILL.md',
          );
        }

        void expectKept(int installed, int failed, String name) {
          expect(installed, 0);
          expect(failed, 0);
          expectTheirs(name);
        }

        test('A: keeps it with no legacy manifest at all', () {
          final skill = seedWorkflow('workflow-builder');
          seedTheirs(skill.name);

          final counts =
              installerFor(movedAgent()).installWorkflowSkillsDetailed([skill]);

          expectKept(counts.installed, counts.failed, skill.name);
        });

        test('B: keeps it once an uninstall cleared the legacy entry', () {
          final skill = seedWorkflow('workflow-builder');
          installerFor(oldFolderAgent()).installWorkflowSkillsDetailed([skill]);
          seedTheirs(skill.name);
          installerFor(movedAgent()).installWorkflowSkillsDetailed([skill]);
          SkillManifest.load(legacyDir)
            ..removeEntry(skill.name)
            ..save();

          final counts =
              installerFor(movedAgent()).installWorkflowSkillsDetailed([skill]);

          expectKept(counts.installed, counts.failed, skill.name);
        });

        test('C: keeps it when the legacy manifest records another skill', () {
          final other = seedWorkflow('other-workflow');
          final skill = seedWorkflow('workflow-builder');
          installerFor(oldFolderAgent()).installWorkflowSkillsDetailed([other]);
          seedTheirs(skill.name);

          final counts =
              installerFor(movedAgent()).installWorkflowSkillsDetailed([skill]);

          expectKept(counts.installed, counts.failed, skill.name);
          expect(SkillManifest.load(legacyDir).skillNames, [other.name]);
        });
      });
    });

    test('finishes a move whose first run could not delete the old copy',
        () async {
      final bundle = _seedBundle(repoRoot);
      await installerFor(oldFolderAgent()).install(bundles: [bundle]);
      final undeletable = p.join(legacyDir, bundle.name, 'references');
      Process.runSync('chmod', ['555', undeletable]);
      addTearDown(() => Process.runSync('chmod', ['755', undeletable]));

      final first = await installerFor(movedAgent()).install(
        bundles: [bundle],
      );

      expect(first.failedCount, 1);
      expect(
        SkillManifest.load(legacyDir).skillNames,
        [bundle.name],
        reason: 'the entry stays while the old copy is not fully deleted',
      );

      Process.runSync('chmod', ['755', undeletable]);
      final second = await installerFor(movedAgent()).install(
        bundles: [bundle],
      );

      expect(second.skillCount, 1);
      expect(second.failedCount, 0);
      expect(Directory(p.join(legacyDir, bundle.name)).existsSync(), isFalse);
      expect(SkillManifest.load(legacyDir).isEmpty, isTrue);
      expect(SkillManifest.load(installDir).skillNames, [bundle.name]);
    }, testOn: 'posix');

    group('workflow skills', () {
      WorkflowSkill seedWorkflow() {
        _writeFile(
          repoRoot,
          'skills/workflow-builder/SKILL.md',
          '# Workflow\n\nBody.',
        );
        return const WorkflowSkill(
          id: 'workflow_builder',
          name: 'workflow-builder',
          displayName: 'Workflow Builder',
          description: 'Builds workflows.',
          planRelativePath: 'skills/workflow-builder/SKILL.md',
        );
      }

      test("keeps the user's own skill of the same name in the new folder",
          () async {
        final skill = seedWorkflow();
        installerFor(oldFolderAgent()).installWorkflowSkillsDetailed([skill]);
        _writeFile(installDir, '${skill.name}/SKILL.md', 'THEIRS');

        final counts =
            installerFor(movedAgent()).installWorkflowSkillsDetailed([skill]);

        expect(counts.installed, 0);
        expect(
          File(p.join(installDir, skill.name, 'SKILL.md')).readAsStringSync(),
          'THEIRS',
        );
        expect(SkillManifest.load(installDir).isEmpty, isTrue);
        expect(SkillManifest.load(legacyDir).skillNames, [skill.name]);
        expect(
          File(p.join(legacyDir, skill.name, 'SKILL.md')).existsSync(),
          isTrue,
        );
        verify(() => logger.warn(any(that: contains('kept')))).called(1);

        Directory(p.join(installDir, skill.name)).deleteSync(recursive: true);
        final again =
            installerFor(movedAgent()).installWorkflowSkillsDetailed([skill]);
        expect(again.installed, 1);
        expect(Directory(p.join(legacyDir, skill.name)).existsSync(), isFalse);
      });

      test("keeps the user's skill once the old copy is gone", () async {
        final skill = seedWorkflow();
        installerFor(oldFolderAgent()).installWorkflowSkillsDetailed([skill]);
        Directory(p.join(legacyDir, skill.name)).deleteSync(recursive: true);
        _writeFile(installDir, '${skill.name}/SKILL.md', 'THEIRS');

        final kept =
            installerFor(movedAgent()).installWorkflowSkillsDetailed([skill]);

        expect(kept.installed, 0);
        expect(
          File(p.join(installDir, skill.name, 'SKILL.md')).readAsStringSync(),
          'THEIRS',
        );
        expect(SkillManifest.load(legacyDir).skillNames, [skill.name]);

        final again =
            installerFor(movedAgent()).installWorkflowSkillsDetailed([skill]);
        expect(again.installed, 0);
        expect(
          File(p.join(installDir, skill.name, 'SKILL.md')).readAsStringSync(),
          'THEIRS',
        );
      });
    });

    test('replaces a skills.sh link in the new folder', () async {
      final bundle = _seedBundle(repoRoot);
      await installerFor(oldFolderAgent()).install(bundles: [bundle]);
      Directory(installDir).createSync(recursive: true);
      Link(p.join(installDir, bundle.name)).createSync(
        p.join(PlatformUtils.homeDirectory, '.agents', 'skills', bundle.name),
      );

      final result = await installerFor(movedAgent()).install(
        bundles: [bundle],
      );

      expect(result.skillCount, 1);
      expect(
        FileSystemEntity.isLinkSync(p.join(installDir, bundle.name)),
        isFalse,
      );
      expect(
        File(p.join(installDir, bundle.name, 'SKILL.md')).existsSync(),
        isTrue,
      );
    });

    test('keeps the install when the old folder links to the new one',
        () async {
      final bundle = _seedBundle(repoRoot);
      Directory(installDir).createSync(recursive: true);
      final linkedDir = p.join(tmp.path, 'linked', 'skills');
      Link(linkedDir).createSync(installDir, recursive: true);
      final agent = movedAgent(legacyInstallPath: linkedDir);
      await installerFor(agent).install(bundles: [bundle]);

      await installerFor(agent).install(bundles: [bundle]);

      expect(
        File(p.join(installDir, bundle.name, 'SKILL.md')).existsSync(),
        isTrue,
      );
      expect(SkillManifest.load(installDir).skillNames, [bundle.name]);
    });

    test('keeps a project install whose folder is also the legacy one',
        () async {
      final bundle = _seedBundle(repoRoot);
      final project = p.join(tmp.path, 'project');
      const agent = AgentConfig(
        id: 'test-agent',
        displayName: 'Test Agent',
        installFormat: InstallFormat.skillDir,
        installPath: '{home}/.config/opencode/skills',
        projectInstallPath: '{home}/.opencode/skills',
        legacyInstallFormat: InstallFormat.markdown,
        legacyInstallPath: '{home}/.opencode/skills',
        legacyExecutionRulesPath: '{home}/.opencode/somnio_rules',
      );
      AgentInstaller projectInstaller() => AgentInstaller(
            logger: logger,
            loader: loader,
            agentConfig: agent,
            scope: InstallScope.project,
            projectRoot: project,
            environment: const {},
          );
      await projectInstaller().install(bundles: [bundle]);

      final result = await projectInstaller().install(bundles: [bundle]);

      final projectSkills = p.join(project, '.opencode', 'skills');
      expect(result.targetDirectory, projectSkills);
      expect(
        File(p.join(projectSkills, bundle.name, 'SKILL.md')).existsSync(),
        isTrue,
      );
      expect(SkillManifest.load(projectSkills).skillNames, [bundle.name]);
    });
  });

  group('ownLegacyInstallDir for OpenCode', () {
    late String home;
    late String project;
    late AgentConfig opencode;

    setUp(() {
      home = p.join(tmp.path, 'home');
      project = p.join(tmp.path, 'project');
      Directory(project).createSync(recursive: true);
      opencode = AgentRegistry.findById('opencode')!;
    });

    /// Links OpenCode's legacy `~/.opencode/skills` to [target].
    void linkLegacyTo(String target) {
      Directory(target).createSync(recursive: true);
      Link(p.join(home, '.opencode', 'skills'))
          .createSync(target, recursive: true);
    }

    String? legacyDir([Map<String, String> environment = const {}]) =>
        AgentInstaller.ownLegacyInstallDir(
          opencode,
          scope: InstallScope.global,
          home: home,
          projectRoot: project,
          environment: environment,
        );

    test('is ~/.opencode/skills for a real folder of its own', () {
      Directory(p.join(home, '.opencode', 'skills'))
          .createSync(recursive: true);

      expect(legacyDir(), p.join(home, '.opencode', 'skills'));
    });

    test('is its own folder while CLAUDE_CONFIG_DIR relocates Claude Code', () {
      Directory(p.join(home, '.opencode', 'skills'))
          .createSync(recursive: true);

      expect(
        legacyDir({'CLAUDE_CONFIG_DIR': p.join(home, '.claude-work')}),
        p.join(home, '.opencode', 'skills'),
      );
    });

    test("is null for a folder linked to Claude Code's skills", () {
      linkLegacyTo(p.join(home, '.claude', 'skills'));

      expect(legacyDir(), isNull);
    });

    test("is null for a link to the default ~/.claude while it's relocated",
        () {
      linkLegacyTo(p.join(home, '.claude', 'skills'));

      expect(
        legacyDir({'CLAUDE_CONFIG_DIR': p.join(home, '.claude-work')}),
        isNull,
      );
    });

    test('is null for a folder linked to its own install folder', () {
      linkLegacyTo(p.join(home, '.config', 'opencode', 'skills'));

      expect(legacyDir(), isNull);
    });
  });
  group('preManifestLegacyWarning for OpenCode', () {
    late String home;
    late String project;
    late String legacy;
    late AgentConfig opencode;

    setUp(() {
      home = p.join(tmp.path, 'home');
      project = p.join(tmp.path, 'project');
      legacy = p.join(home, '.opencode', 'skills');
      Directory(project).createSync(recursive: true);
      opencode = AgentRegistry.findById('opencode')!;
    });

    String? warning({
      InstallScope scope = InstallScope.global,
      Map<String, String> environment = const {},
    }) =>
        AgentInstaller.preManifestLegacyWarning(
          opencode,
          scope: scope,
          home: home,
          projectRoot: project,
          environment: environment,
        );

    test('lists only files with a skill\'s exact name and header', () {
      _writeFile(
        legacy,
        'flutter_health_audit.md',
        '# Flutter Project Health Audit\n\n> Audits a Flutter project.\n',
      );
      _writeFile(legacy, 'security_audit.md', 'x');
      _writeFile(
        legacy,
        'somnio-team.md',
        '# Flutter Project Health Audit\n\n> Audits a Flutter project.\n',
      );
      _writeFile(legacy, 'notes.md', 'THEIRS');

      final text = warning();

      expect(text, contains('OpenCode: $legacy still holds 1 Somnio'));
      expect(text, endsWith('delete them by hand: flutter_health_audit.md.'));
    });

    test('is quiet when the folder holds no such file', () {
      _writeFile(legacy, 'security_audit.md', 'x');

      expect(warning(), isNull);
    });

    test('is quiet when a manifest records the folder', () {
      _writeFile(
        legacy,
        'flutter_health_audit.md',
        '# Flutter Project Health Audit\n\n> Audits a Flutter project.\n',
      );
      SkillManifest.load(legacy)
        ..record(
          skill: 'flutter-health-audit',
          kind: 'audit',
          paths: const [ManifestPath(ManifestRoot.install, 'x')],
        )
        ..save();

      expect(warning(), isNull);
    });

    test('is quiet for a folder linked to another agent\'s skills', () {
      final claudeSkills = p.join(home, '.claude', 'skills');
      _writeFile(
        claudeSkills,
        'flutter_health_audit.md',
        '# Flutter Project Health Audit\n\n> Audits a Flutter project.\n',
      );
      Link(legacy).createSync(claudeSkills, recursive: true);

      expect(warning(), isNull);
      expect(
        warning(
            environment: {'CLAUDE_CONFIG_DIR': p.join(home, '.claude-work')}),
        isNull,
      );
    });

    test('is quiet in the project scope, where the old folder is the new one',
        () {
      _writeFile(
        project,
        '.opencode/skills/flutter_health_audit.md',
        '# Flutter Project Health Audit\n\n> Audits a Flutter project.\n',
      );

      expect(warning(scope: InstallScope.project), isNull);
    });
  });
}
