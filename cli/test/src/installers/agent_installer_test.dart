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
        File(p.join(rulesPath, bundle.planSubDir, 'references',
                'architecture.md'))
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

      final result = await installer.install(bundles: [bad, _seedBundle(repoRoot)]);

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

    test('skillDir: copies assetDirectories verbatim alongside SKILL.md',
        () {
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
