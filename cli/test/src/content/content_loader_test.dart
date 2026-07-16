import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/content/content_loader.dart';
import 'package:somnio/src/content/skill_bundle.dart';
import 'package:test/test.dart';

/// Builds a minimal skill bundle backed by real files under [repoRoot].
SkillBundle _bundle({
  required String repoRoot,
  String skillName = 'demo-skill',
  String skillId = 'demo',
  String? planContent,
  Map<String, String> referenceFiles = const {},
  Map<String, String> assetFiles = const {},
  String? templateContent,
  String? workflowContent,
}) {
  final skillDir = Directory(p.join(repoRoot, 'skills', skillName));
  skillDir.createSync(recursive: true);

  if (planContent != null) {
    File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync(planContent);
  }

  final refsDir = Directory(p.join(skillDir.path, 'references'));
  refsDir.createSync(recursive: true);
  for (final entry in referenceFiles.entries) {
    File(p.join(refsDir.path, entry.key)).writeAsStringSync(entry.value);
  }

  if (assetFiles.isNotEmpty) {
    final assetsDir = Directory(p.join(refsDir.path, 'assets'));
    assetsDir.createSync(recursive: true);
    for (final entry in assetFiles.entries) {
      File(p.join(assetsDir.path, entry.key)).writeAsStringSync(entry.value);
    }
  }

  String? templatePath;
  if (templateContent != null) {
    final assetsDir = Directory(p.join(skillDir.path, 'assets'));
    assetsDir.createSync(recursive: true);
    File(p.join(assetsDir.path, 'report-template.md'))
        .writeAsStringSync(templateContent);
    templatePath = 'skills/$skillName/assets/report-template.md';
  }

  String? workflowPath;
  if (workflowContent != null) {
    final wfDir =
        Directory(p.join(skillDir.path, '.agent', 'workflows'));
    wfDir.createSync(recursive: true);
    File(p.join(wfDir.path, '$skillId.md')).writeAsStringSync(workflowContent);
    workflowPath = 'skills/$skillName/.agent/workflows/$skillId.md';
  }

  return SkillBundle(
    id: skillId,
    name: skillName,
    displayName: 'Demo Skill',
    description: 'A demo skill.',
    planRelativePath: 'skills/$skillName/SKILL.md',
    rulesDirectory: 'skills/$skillName/references',
    templatePath: templatePath,
    workflowPath: workflowPath,
  );
}

void main() {
  late Directory tmp;
  late ContentLoader loader;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('somnio_loader_');
    loader = ContentLoader(tmp.path);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  // ---------------------------------------------------------------------------
  // loadPlanFrontmatter
  // ---------------------------------------------------------------------------
  group('loadPlanFrontmatter', () {
    test('normalises a block-sequence value to the comma-separated form', () {
      _bundle(
        repoRoot: tmp.path,
        planContent: '---\n'
            'name: demo\n'
            'description: A demo\n'
            'allowed-tools:\n'
            '  - Bash\n'
            '  - Read\n'
            '  - AskUserQuestion\n'
            '---\n\n'
            '# Demo',
      );

      final fm = loader.loadPlanFrontmatter('skills/demo-skill/SKILL.md');

      // Keeping only String values would drop the list entirely and silently
      // fall back to the installer's generic default, costing the skill tools
      // its own plan calls.
      expect(fm['allowed-tools'], 'Bash, Read, AskUserQuestion');
    });

    test('reads the real ship skill, whose allowed-tools is a block sequence',
        () {
      // Anchored on the shipped file rather than a fixture: this is the skill
      // that regressed, and a fixture would not catch it drifting again.
      final repoRoot = p.dirname(Directory.current.path);
      final fm =
          ContentLoader(repoRoot).loadPlanFrontmatter('skills/ship/SKILL.md');

      expect(
        fm['allowed-tools'],
        contains('AskUserQuestion'),
        reason: "ship's plan calls AskUserQuestion, so it must be declared",
      );
    });

    test('keeps a plain string value unchanged', () {
      _bundle(
        repoRoot: tmp.path,
        planContent: '---\n'
            'name: demo\n'
            'allowed-tools: Bash, Read\n'
            '---\n\n'
            '# Demo',
      );

      expect(
        loader.loadPlanFrontmatter('skills/demo-skill/SKILL.md')['allowed-tools'],
        'Bash, Read',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // loadPlan
  // ---------------------------------------------------------------------------
  group('loadPlan', () {
    test('strips YAML frontmatter and UUID comment, then trims', () {
      final bundle = _bundle(
        repoRoot: tmp.path,
        planContent: '---\n'
            'name: demo\n'
            'description: A demo\n'
            '---\n'
            '<!-- 123e4567-e89b-12d3-a456-426614174000 -->\n'
            '# Demo Plan\n\nBody text.',
      );

      final plan = loader.loadPlan(bundle);

      expect(plan, startsWith('# Demo Plan'));
      expect(plan, contains('Body text.'));
      expect(plan, isNot(contains('name: demo')));
      expect(plan, isNot(contains('123e4567')));
      expect(plan, isNot(contains('---')));
    });

    test('returns content unchanged when no frontmatter or comment', () {
      final bundle = _bundle(
        repoRoot: tmp.path,
        planContent: '# Plain Plan\n\nNo frontmatter here.',
      );

      final plan = loader.loadPlan(bundle);

      expect(plan, '# Plain Plan\n\nNo frontmatter here.');
    });

    test('leaves content intact when frontmatter has no closing delimiter', () {
      final bundle = _bundle(
        repoRoot: tmp.path,
        planContent: '---\nname: demo\nstill frontmatter',
      );

      final plan = loader.loadPlan(bundle);

      // No closing `---` after index 3 -> content kept as-is (just trimmed).
      expect(plan, contains('name: demo'));
    });

    test('throws FileSystemException when the plan file is missing', () {
      final bundle = SkillBundle(
        id: 'missing',
        name: 'missing-skill',
        displayName: 'Missing',
        description: 'desc',
        planRelativePath: 'skills/missing-skill/SKILL.md',
        rulesDirectory: 'skills/missing-skill/references',
      );

      expect(() => loader.loadPlan(bundle), throwsA(isA<FileSystemException>()));
    });
  });

  // ---------------------------------------------------------------------------
  // loadRules
  // ---------------------------------------------------------------------------
  group('loadRules', () {
    test('parses and sorts md + yaml rules, skips assets subdir', () {
      final bundle = _bundle(
        repoRoot: tmp.path,
        planContent: '# Plan',
        referenceFiles: {
          'b-second.md': '# Second Rule\n'
              '\n'
              '> Second description\n'
              '\n'
              '**File pattern**: `lib/**`\n'
              '\n'
              '---\n'
              '\n'
              'Second prompt body.',
          'a-first.yaml': 'rules:\n'
              '  - name: First Rule\n'
              '    description: First description\n'
              '    match: "*.dart"\n'
              '    prompt: |\n'
              '      First prompt body.\n',
          'notes.txt': 'ignored extension',
        },
        assetFiles: {
          'logo.png': 'binary-ish',
        },
      );

      final rules = loader.loadRules(bundle);

      // Sorted by path: a-first.yaml before b-second.md.
      expect(rules, hasLength(2));
      expect(rules[0].name, 'First Rule');
      expect(rules[0].match, '*.dart');
      expect(rules[0].prompt, 'First prompt body.');
      expect(rules[0].fileName, 'a-first');
      expect(rules[1].name, 'Second Rule');
      expect(rules[1].description, 'Second description');
      expect(rules[1].match, 'lib/**');
      expect(rules[1].fileName, 'b-second');
    });

    test('drops a malformed yaml rule but keeps a valid one', () {
      final bundle = _bundle(
        repoRoot: tmp.path,
        planContent: '# Plan',
        referenceFiles: {
          'broken.yaml': 'this: is: not: valid: yaml: ::::\n',
          'good.md': '# Good\n\n> d\n\n---\n\nprompt',
        },
      );

      final rules = loader.loadRules(bundle);

      expect(rules, hasLength(1));
      expect(rules.single.name, 'Good');
    });

    test('throws FileSystemException when references dir is absent', () {
      final bundle = SkillBundle(
        id: 'norefs',
        name: 'norefs-skill',
        displayName: 'No Refs',
        description: 'desc',
        planRelativePath: 'skills/norefs-skill/SKILL.md',
        rulesDirectory: 'skills/norefs-skill/references',
      );

      expect(
        () => loader.loadRules(bundle),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // _parseMdReference (via loadRules) edge cases
  // ---------------------------------------------------------------------------
  group('_parseMdReference', () {
    test('returns null when no heading present', () {
      final bundle = _bundle(
        repoRoot: tmp.path,
        planContent: '# Plan',
        referenceFiles: {
          'no-heading.md': 'just text\n\n---\n\nprompt',
        },
      );

      expect(loader.loadRules(bundle), isEmpty);
    });

    test('returns null when there is no --- separator', () {
      final bundle = _bundle(
        repoRoot: tmp.path,
        planContent: '# Plan',
        referenceFiles: {
          'no-sep.md': '# Heading\n\n> desc\n\nbody without separator',
        },
      );

      expect(loader.loadRules(bundle), isEmpty);
    });

    test('defaults match to * when no file-pattern line present', () {
      final bundle = _bundle(
        repoRoot: tmp.path,
        planContent: '# Plan',
        referenceFiles: {
          'rule.md': '# Heading\n\n> desc\n\n---\n\nbody',
        },
      );

      final rules = loader.loadRules(bundle);
      expect(rules.single.match, '*');
      expect(rules.single.prompt, 'body');
    });
  });

  // ---------------------------------------------------------------------------
  // loadTemplate
  // ---------------------------------------------------------------------------
  group('loadTemplate', () {
    test('returns null when templatePath is null', () {
      final bundle = _bundle(repoRoot: tmp.path, planContent: '# Plan');
      expect(loader.loadTemplate(bundle), isNull);
    });

    test('returns null when template file is missing', () {
      final bundle = SkillBundle(
        id: 'demo',
        name: 'demo-skill',
        displayName: 'Demo',
        description: 'desc',
        planRelativePath: 'skills/demo-skill/SKILL.md',
        rulesDirectory: 'skills/demo-skill/references',
        templatePath: 'skills/demo-skill/assets/missing.md',
      );
      expect(loader.loadTemplate(bundle), isNull);
    });

    test('returns content when template file exists', () {
      final bundle = _bundle(
        repoRoot: tmp.path,
        planContent: '# Plan',
        templateContent: '# Report Template',
      );
      expect(loader.loadTemplate(bundle), '# Report Template');
    });
  });

  // ---------------------------------------------------------------------------
  // loadWorkflow
  // ---------------------------------------------------------------------------
  group('loadWorkflow', () {
    test('returns null when workflowPath is null', () {
      final bundle = _bundle(repoRoot: tmp.path, planContent: '# Plan');
      expect(loader.loadWorkflow(bundle), isNull);
    });

    test('returns null when workflow file is missing', () {
      final bundle = SkillBundle(
        id: 'demo',
        name: 'demo-skill',
        displayName: 'Demo',
        description: 'desc',
        planRelativePath: 'skills/demo-skill/SKILL.md',
        rulesDirectory: 'skills/demo-skill/references',
        workflowPath: 'skills/demo-skill/.agent/workflows/missing.md',
      );
      expect(loader.loadWorkflow(bundle), isNull);
    });

    test('returns content when workflow file exists', () {
      final bundle = _bundle(
        repoRoot: tmp.path,
        planContent: '# Plan',
        workflowContent: '# Workflow Body',
      );
      expect(loader.loadWorkflow(bundle), '# Workflow Body');
    });
  });

  // ---------------------------------------------------------------------------
  // listAllRuleFiles + rulesFilePath
  // ---------------------------------------------------------------------------
  group('listAllRuleFiles', () {
    test('lists files recursively (including assets) as relative, sorted', () {
      final bundle = _bundle(
        repoRoot: tmp.path,
        planContent: '# Plan',
        referenceFiles: {
          'b.md': 'b',
          'a.md': 'a',
        },
        assetFiles: {
          'img.png': 'x',
        },
      );

      final files = loader.listAllRuleFiles(bundle);

      expect(files, ['a.md', 'assets/img.png', 'b.md']);
    });

    test('returns empty list when references dir does not exist', () {
      final bundle = SkillBundle(
        id: 'demo',
        name: 'demo-skill',
        displayName: 'Demo',
        description: 'desc',
        planRelativePath: 'skills/demo-skill/SKILL.md',
        rulesDirectory: 'skills/absent/references',
      );
      expect(loader.listAllRuleFiles(bundle), isEmpty);
    });
  });

  group('rulesFilePath', () {
    test('joins repoRoot, rulesDirectory and relative path', () {
      final bundle = _bundle(repoRoot: tmp.path, planContent: '# Plan');
      final path = loader.rulesFilePath(bundle, 'assets/img.png');
      expect(
        path,
        p.join(tmp.path, 'skills/demo-skill/references', 'assets/img.png'),
      );
    });
  });

  group('loadAgentFiles', () {
    SkillBundle bundleWith({String? agentsDirectory}) => SkillBundle(
          id: 'demo',
          name: 'demo-skill',
          displayName: 'Demo Skill',
          description: 'A demo skill.',
          planRelativePath: 'skills/demo-skill/SKILL.md',
          rulesDirectory: 'skills/demo-skill/references',
          agentsDirectory: agentsDirectory,
        );

    test('returns empty map when agentsDirectory is null', () {
      expect(loader.loadAgentFiles(bundleWith()), isEmpty);
    });

    test('returns empty map when the directory is absent', () {
      expect(
        loader.loadAgentFiles(
          bundleWith(agentsDirectory: 'skills/demo-skill/agents'),
        ),
        isEmpty,
      );
    });

    test('loads top-level .md files sorted by name', () {
      final agentsDir = Directory(
        p.join(tmp.path, 'skills', 'demo-skill', 'agents'),
      )..createSync(recursive: true);
      File(p.join(agentsDir.path, 'orchestrator.md'))
          .writeAsStringSync('orch body');
      File(p.join(agentsDir.path, 'report-writer.md'))
          .writeAsStringSync('writer body');
      // Non-md file should be ignored.
      File(p.join(agentsDir.path, 'notes.txt')).writeAsStringSync('ignore');

      final result = loader.loadAgentFiles(
        bundleWith(agentsDirectory: 'skills/demo-skill/agents'),
      );

      expect(result.keys.toList(), ['orchestrator.md', 'report-writer.md']);
      expect(result['orchestrator.md'], 'orch body');
      expect(result['report-writer.md'], 'writer body');
    });
  });
}
