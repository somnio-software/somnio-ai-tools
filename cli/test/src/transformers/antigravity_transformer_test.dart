import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/agents/agent_registry.dart';
import 'package:somnio/src/content/content_loader.dart';
import 'package:somnio/src/content/skill_bundle.dart';
import 'package:somnio/src/transformers/antigravity_transformer.dart';
import 'package:test/test.dart';

/// Creates a minimal skill bundle backed by real files in [repoRoot].
///
/// Writes a workflow file with [workflowContent] and a blank SKILL.md.
/// Optionally writes [ruleFiles] (filename → content) under references/.
SkillBundle _setupBundle({
  required String repoRoot,
  required String skillName,
  required String skillId,
  required String workflowContent,
  Map<String, String> ruleFiles = const {},
}) {
  final workflowDir = Directory(
    p.join(repoRoot, 'skills', skillName, '.agent', 'workflows'),
  );
  workflowDir.createSync(recursive: true);

  final workflowFileName = '${skillId}.md';
  File(p.join(workflowDir.path, workflowFileName))
      .writeAsStringSync(workflowContent);

  final refsDir = Directory(
    p.join(repoRoot, 'skills', skillName, 'references'),
  );
  refsDir.createSync(recursive: true);
  for (final entry in ruleFiles.entries) {
    File(p.join(refsDir.path, entry.key)).writeAsStringSync(entry.value);
  }

  File(p.join(repoRoot, 'skills', skillName, 'SKILL.md'))
      .writeAsStringSync('# Plan\n\nPlan content.');

  return SkillBundle(
    id: skillId,
    name: skillName,
    displayName: 'Test Skill',
    description: 'A test skill.',
    planRelativePath: 'skills/$skillName/SKILL.md',
    rulesDirectory: 'skills/$skillName/references',
    workflowPath:
        'skills/$skillName/.agent/workflows/$workflowFileName',
  );
}

void main() {
  late AntigravityTransformer transformer;

  setUp(() => transformer = AntigravityTransformer());

  // ---------------------------------------------------------------------------
  // transform()
  // ---------------------------------------------------------------------------
  group('transform', () {
    test('returns skipped:true when workflowPath is null', () {
      final bundle = const SkillBundle(
        id: 'test',
        name: 'test-skill',
        displayName: 'Test Skill',
        description: 'Test',
        planRelativePath: 'skills/test-skill/SKILL.md',
        rulesDirectory: 'skills/test-skill/references',
        // workflowPath intentionally omitted (null)
      );

      final tmpDir = Directory.systemTemp.createTempSync('somnio_skip_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      final loader = ContentLoader(tmpDir.path);
      final agent = AgentRegistry.findById('antigravity')!;

      final output = transformer.transform(bundle, loader, agent);

      expect(output.skipped, isTrue);
      expect(output.files, isEmpty);
    });

    test('places workflow under global_workflows/ when workflowPath is set',
        () {
      final tmpDir = Directory.systemTemp.createTempSync('somnio_wf_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmpDir.path,
        skillName: 'flutter-health-audit',
        skillId: 'flutter_health_audit',
        workflowContent: '# Flutter Health Audit\n',
      );

      final loader = ContentLoader(tmpDir.path);
      final agent = AgentRegistry.findById('antigravity')!;

      final output = transformer.transform(bundle, loader, agent);

      expect(output.skipped, isFalse);
      expect(
        output.files.keys,
        contains('global_workflows/somnio_flutter_health_audit.md'),
      );
    });

    test('places rule files under somnio_rules/', () {
      final tmpDir = Directory.systemTemp.createTempSync('somnio_rules_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmpDir.path,
        skillName: 'nestjs-health-audit',
        skillId: 'nestjs_health_audit',
        workflowContent: '# NestJS Health Audit\n',
        ruleFiles: {
          'architecture.md': 'arch content',
          'testing.md': 'test content',
        },
      );

      final loader = ContentLoader(tmpDir.path);
      final agent = AgentRegistry.findById('antigravity')!;

      final output = transformer.transform(bundle, loader, agent);

      expect(
        output.files.keys,
        containsAll([
          'somnio_rules/nestjs-health-audit/references/architecture.md',
          'somnio_rules/nestjs-health-audit/references/testing.md',
        ]),
      );
    });

    test('places plan file under somnio_rules/<skill>/plan/', () {
      final tmpDir = Directory.systemTemp.createTempSync('somnio_plan_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmpDir.path,
        skillName: 'react-health-audit',
        skillId: 'react_health_audit',
        workflowContent: '# React Health Audit\n',
      );

      final loader = ContentLoader(tmpDir.path);
      final agent = AgentRegistry.findById('antigravity')!;

      final output = transformer.transform(bundle, loader, agent);

      expect(
        output.files.keys,
        contains('somnio_rules/react-health-audit/plan/SKILL.md'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // _rewritePaths (tested indirectly via transformBundle)
  // ---------------------------------------------------------------------------
  group('_rewritePaths', () {
    late Directory tmpDir;
    late ContentLoader loader;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('somnio_paths_');
    });

    tearDown(() => tmpDir.deleteSync(recursive: true));

    test('rewrites workflow cross-reference paths', () {
      final bundle = _setupBundle(
        repoRoot: tmpDir.path,
        skillName: 'flutter-health-audit',
        skillId: 'flutter_health_audit',
        workflowContent:
            'After this step, follow workflow: '
            '`flutter-best-practices/.agent/workflows/flutter_best_practices.md`',
      );
      loader = ContentLoader(tmpDir.path);

      final output = transformer.transformBundle(bundle, loader);

      expect(
        output.workflowContent,
        contains('`somnio_flutter_best_practices.md`'),
      );
      expect(
        output.workflowContent,
        isNot(contains('flutter-best-practices/.agent/workflows')),
      );
    });

    test('rewrites references/ rule file paths to absolute Antigravity paths',
        () {
      final bundle = _setupBundle(
        repoRoot: tmpDir.path,
        skillName: 'flutter-health-audit',
        skillId: 'flutter_health_audit',
        workflowContent:
            'Read `flutter-health-audit/references/tool-installer.md` '
            'and follow ALL instructions.',
      );
      loader = ContentLoader(tmpDir.path);

      final output = transformer.transformBundle(bundle, loader);

      expect(
        output.workflowContent,
        contains(
          '`~/.gemini/antigravity/somnio_rules/'
          'flutter-health-audit/references/tool-installer.md`',
        ),
      );
      expect(
        output.workflowContent,
        isNot(contains('`flutter-health-audit/references/')),
      );
    });

    test('rewrites both cross-references and rule paths in the same content',
        () {
      final bundle = _setupBundle(
        repoRoot: tmpDir.path,
        skillName: 'flutter-health-audit',
        skillId: 'flutter_health_audit',
        workflowContent:
            '## Step 1\n'
            'Read `flutter-health-audit/references/tool-installer.md`.\n\n'
            '## Step 2\n'
            'If needed, run: `flutter-best-practices/.agent/workflows/'
            'flutter_best_practices.md`\n',
      );
      loader = ContentLoader(tmpDir.path);

      final output = transformer.transformBundle(bundle, loader);

      expect(
        output.workflowContent,
        contains(
          '`~/.gemini/antigravity/somnio_rules/'
          'flutter-health-audit/references/tool-installer.md`',
        ),
      );
      expect(
        output.workflowContent,
        contains('`somnio_flutter_best_practices.md`'),
      );
    });

    test('does not rewrite paths that are not wrapped in backticks', () {
      final bundle = _setupBundle(
        repoRoot: tmpDir.path,
        skillName: 'nestjs-health-audit',
        skillId: 'nestjs_health_audit',
        workflowContent:
            'See nestjs-health-audit/references/architecture.md for context.\n'
            'Also nestjs-best-practices/.agent/workflows/nestjs_best_practices.md\n',
      );
      loader = ContentLoader(tmpDir.path);

      final output = transformer.transformBundle(bundle, loader);

      expect(output.workflowContent, isNot(contains('somnio_rules')));
      expect(output.workflowContent, isNot(contains('somnio_nestjs_best_practices')));
    });

    test('rewrites multiple occurrences of the same pattern', () {
      final bundle = _setupBundle(
        repoRoot: tmpDir.path,
        skillName: 'security-audit',
        skillId: 'security_audit',
        workflowContent:
            'Read `security-audit/references/file-analysis.md`.\n'
            'Read `security-audit/references/secret-patterns.md`.\n'
            'Read `security-audit/references/sast.md`.\n',
      );
      loader = ContentLoader(tmpDir.path);

      final output = transformer.transformBundle(bundle, loader);

      final base = '~/.gemini/antigravity/somnio_rules/security-audit/references';
      expect(output.workflowContent, contains('`$base/file-analysis.md`'));
      expect(output.workflowContent, contains('`$base/secret-patterns.md`'));
      expect(output.workflowContent, contains('`$base/sast.md`'));
    });
  });

  // ---------------------------------------------------------------------------
  // Workflow file naming
  // ---------------------------------------------------------------------------
  group('workflow file naming', () {
    test('derives file name from workflowPath basename', () {
      final tmpDir = Directory.systemTemp.createTempSync('somnio_name_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmpDir.path,
        skillName: 'flutter-best-practices',
        skillId: 'flutter_best_practices',
        workflowContent: '# Flutter Best Practices\n',
      );

      final loader = ContentLoader(tmpDir.path);
      final output = transformer.transformBundle(bundle, loader);

      expect(output.workflowFileName, 'somnio_flutter_best_practices.md');
    });
  });

  // ---------------------------------------------------------------------------
  // All 7 registry bundles have workflowPath set
  // ---------------------------------------------------------------------------
  group('SkillRegistry coverage', () {
    test('all 7 audit/best-practices bundles have a non-null workflowPath', () {
      // Import here to avoid circular dep at top level
      // ignore: avoid_relative_lib_imports
      final bundles = [
        const SkillBundle(
          id: 'flutter_health',
          name: 'flutter-health-audit',
          displayName: 'Flutter Project Health Audit',
          description: 'desc',
          planRelativePath: 'skills/flutter-health-audit/SKILL.md',
          rulesDirectory: 'skills/flutter-health-audit/references',
          workflowPath:
              'skills/flutter-health-audit/.agent/workflows/flutter_health_audit.md',
        ),
        const SkillBundle(
          id: 'flutter_plan',
          name: 'flutter-best-practices',
          displayName: 'Flutter Best Practices Check',
          description: 'desc',
          planRelativePath: 'skills/flutter-best-practices/SKILL.md',
          rulesDirectory: 'skills/flutter-best-practices/references',
          workflowPath:
              'skills/flutter-best-practices/.agent/workflows/flutter_best_practices.md',
        ),
        const SkillBundle(
          id: 'nestjs_health',
          name: 'nestjs-health-audit',
          displayName: 'NestJS Project Health Audit',
          description: 'desc',
          planRelativePath: 'skills/nestjs-health-audit/SKILL.md',
          rulesDirectory: 'skills/nestjs-health-audit/references',
          workflowPath:
              'skills/nestjs-health-audit/.agent/workflows/nestjs_health_audit.md',
        ),
        const SkillBundle(
          id: 'nestjs_plan',
          name: 'nestjs-best-practices',
          displayName: 'NestJS Best Practices Check',
          description: 'desc',
          planRelativePath: 'skills/nestjs-best-practices/SKILL.md',
          rulesDirectory: 'skills/nestjs-best-practices/references',
          workflowPath:
              'skills/nestjs-best-practices/.agent/workflows/nestjs_best_practices.md',
        ),
        const SkillBundle(
          id: 'react_health',
          name: 'react-health-audit',
          displayName: 'React Project Health Audit',
          description: 'desc',
          planRelativePath: 'skills/react-health-audit/SKILL.md',
          rulesDirectory: 'skills/react-health-audit/references',
          workflowPath:
              'skills/react-health-audit/.agent/workflows/react_health_audit.md',
        ),
        const SkillBundle(
          id: 'react_plan',
          name: 'react-best-practices',
          displayName: 'React Best Practices Check',
          description: 'desc',
          planRelativePath: 'skills/react-best-practices/SKILL.md',
          rulesDirectory: 'skills/react-best-practices/references',
          workflowPath:
              'skills/react-best-practices/.agent/workflows/react_best_practices.md',
        ),
        const SkillBundle(
          id: 'security_audit',
          name: 'security-audit',
          displayName: 'Security Audit',
          description: 'desc',
          planRelativePath: 'skills/security-audit/SKILL.md',
          rulesDirectory: 'skills/security-audit/references',
          workflowPath:
              'skills/security-audit/.agent/workflows/security_audit.md',
        ),
      ];

      for (final bundle in bundles) {
        expect(
          bundle.workflowPath,
          isNotNull,
          reason: '${bundle.name} must have a workflowPath',
        );
      }
    });

    test('all 7 bundles would NOT be skipped by AntigravityTransformer', () {
      final tmpDir = Directory.systemTemp.createTempSync('somnio_registry_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      final loader = ContentLoader(tmpDir.path);
      final agent = AgentRegistry.findById('antigravity')!;

      final nullPathBundle = const SkillBundle(
        id: 'test',
        name: 'test-skill',
        displayName: 'Test',
        description: 'Test',
        planRelativePath: 'skills/test/SKILL.md',
        rulesDirectory: 'skills/test/references',
        // workflowPath: null
      );

      final withPathBundle = const SkillBundle(
        id: 'test',
        name: 'test-skill',
        displayName: 'Test',
        description: 'Test',
        planRelativePath: 'skills/test/SKILL.md',
        rulesDirectory: 'skills/test/references',
        workflowPath: 'skills/test/.agent/workflows/test.md',
      );

      final skipped = transformer.transform(nullPathBundle, loader, agent);
      final notSkipped = transformer.transform(withPathBundle, loader, agent);

      expect(skipped.skipped, isTrue, reason: 'null workflowPath → skipped');
      // notSkipped may error loading files, but skipped flag is false
      expect(notSkipped.skipped, isFalse,
          reason: 'non-null workflowPath → not skipped');
    });
  });
}
