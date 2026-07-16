import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/agents/agent_registry.dart';
import 'package:somnio/src/content/content_loader.dart';
import 'package:somnio/src/content/skill_bundle.dart';
import 'package:somnio/src/transformers/claude_transformer.dart';
import 'package:test/test.dart';

/// Writes a skill bundle on disk under [repoRoot] and returns its [SkillBundle].
///
/// Creates `skills/<name>/SKILL.md`, `references/*.md` (+ optional `*.yaml`),
/// and optionally an `assets/report-template.md` file when [withTemplate].
SkillBundle _setupBundle({
  required String repoRoot,
  required String id,
  required String name,
  required String planContent,
  Map<String, String> references = const {},
  bool withTemplate = false,
}) {
  final skillDir = Directory(p.join(repoRoot, 'skills', name));
  skillDir.createSync(recursive: true);

  File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync(planContent);

  final refsDir = Directory(p.join(skillDir.path, 'references'));
  refsDir.createSync(recursive: true);
  for (final entry in references.entries) {
    File(p.join(refsDir.path, entry.key)).writeAsStringSync(entry.value);
  }

  String? templatePath;
  if (withTemplate) {
    final assetsDir = Directory(p.join(skillDir.path, 'assets'));
    assetsDir.createSync(recursive: true);
    File(p.join(assetsDir.path, 'report-template.md'))
        .writeAsStringSync('# Report Template\n\nbody');
    templatePath = 'skills/$name/assets/report-template.md';
  }

  return SkillBundle(
    id: id,
    name: name,
    displayName: 'Test Skill',
    description: 'A test skill.',
    planRelativePath: 'skills/$name/SKILL.md',
    rulesDirectory: 'skills/$name/references',
    templatePath: templatePath,
  );
}

/// Builds a markdown reference file parseable by [ContentLoader.loadRules].
String _mdReference({
  required String name,
  required String description,
  required String pattern,
  required String prompt,
}) {
  return '# $name\n'
      '\n'
      '> $description\n'
      '\n'
      '**File pattern**: `$pattern`\n'
      '\n'
      '---\n'
      '\n'
      '$prompt';
}

void main() {
  late ClaudeTransformer transformer;

  setUp(() => transformer = ClaudeTransformer());

  // ---------------------------------------------------------------------------
  // _generateSkillMd — @... rewrite branches
  // ---------------------------------------------------------------------------
  group('transformBundle / _generateSkillMd', () {
    test('writes frontmatter with name and description', () {
      final tmp = Directory.systemTemp.createTempSync('claude_fm_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        id: 'flutter_health',
        name: 'flutter-health-audit',
        planContent: '# Plan\n\nNo special refs here.',
      );

      final output = transformer.transformBundle(bundle, ContentLoader(tmp.path));

      expect(output.skillMd, startsWith('---\n'));
      expect(output.skillMd, contains('name: flutter-health-audit'));
      expect(output.skillMd, contains('A test skill.'));
      expect(output.skillMd, contains('No special refs here.'));
    });

    test(
        'preserves the authored frontmatter description and allowed-tools, '
        'dropping neither the trigger clause nor extra tools', () {
      final tmp = Directory.systemTemp.createTempSync('claude_authored_fm_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        id: 'flutter_health',
        name: 'flutter-health-audit',
        planContent: '---\n'
            'name: flutter-health-audit\n'
            'description: >-\n'
            '  Audits a Flutter project health. Use when the user asks to\n'
            "  audit a Flutter project. Triggers on: 'run a health check'.\n"
            'allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent\n'
            '---\n\n'
            '# Plan\n\nbody',
      );

      final output = transformer.transformBundle(bundle, ContentLoader(tmp.path));

      expect(output.skillMd, contains('Triggers on'));
      expect(
        output.skillMd,
        contains(
          'allowed-tools: Read, Edit, Write, Grep, Glob, Bash, WebFetch, Agent',
        ),
      );
    });

    test('rewrites `@rule_name` backtick references to references/<rule>.md', () {
      final tmp = Directory.systemTemp.createTempSync('claude_rule_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        id: 'flutter_health',
        name: 'flutter-health-audit',
        planContent: 'Step 1: `@tool_installer` then continue.',
      );

      final output = transformer.transformBundle(bundle, ContentLoader(tmp.path));

      expect(
        output.skillMd,
        contains(
          'Read and follow the instructions in `references/tool_installer.md`',
        ),
      );
      expect(output.skillMd, isNot(contains('`@tool_installer`')));
    });

    test('rewrites @<prefix>_best_practices_check/plan/... when registry hits',
        () {
      final tmp = Directory.systemTemp.createTempSync('claude_planref_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        id: 'flutter_health',
        name: 'flutter-health-audit',
        planContent:
            'See @flutter_best_practices_check/plan/best_practices.plan.md',
      );

      final output = transformer.transformBundle(bundle, ContentLoader(tmp.path));

      // flutter_plan exists in the registry -> name flutter-best-practices.
      expect(output.skillMd, contains('`/flutter-best-practices`'));
    });

    test('leaves @<prefix>_best_practices_check/plan/... when registry misses',
        () {
      final tmp = Directory.systemTemp.createTempSync('claude_planmiss_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        id: 'unknown_health',
        name: 'unknown-health-audit',
        planContent:
            'See @nonexistent_best_practices_check/plan/best_practices.plan.md',
      );

      final output = transformer.transformBundle(bundle, ContentLoader(tmp.path));

      // No `nonexistent_plan` registry entry -> original text preserved.
      expect(
        output.skillMd,
        contains('@nonexistent_best_practices_check/plan/best_practices.plan.md'),
      );
    });

    test('rewrites `@rule.yaml` references to references/<rule>.md', () {
      final tmp = Directory.systemTemp.createTempSync('claude_yaml_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        id: 'flutter_health',
        name: 'flutter-health-audit',
        planContent: 'Apply `@architecture.yaml` rules.',
      );

      final output = transformer.transformBundle(bundle, ContentLoader(tmp.path));

      expect(
        output.skillMd,
        contains(
          'Read and follow the instructions in `references/architecture.md`',
        ),
      );
      expect(output.skillMd, isNot(contains('`@architecture.yaml`')));
    });

    test('rewrites `@best_practices.plan.md` to sibling plan skill (hit)', () {
      final tmp = Directory.systemTemp.createTempSync('claude_bp_hit_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        id: 'flutter_health', // techPrefix -> flutter -> flutter_plan exists
        name: 'flutter-health-audit',
        planContent: 'Then run `@best_practices.plan.md`.',
      );

      final output = transformer.transformBundle(bundle, ContentLoader(tmp.path));

      expect(output.skillMd, contains('`/flutter-best-practices`'));
    });

    test('rewrites `@best_practices.plan.md` to bundle name on miss', () {
      final tmp = Directory.systemTemp.createTempSync('claude_bp_miss_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        id: 'mystery_health', // techPrefix -> mystery -> mystery_plan missing
        name: 'mystery-health-audit',
        planContent: 'Then run `@best_practices.plan.md`.',
      );

      final output = transformer.transformBundle(bundle, ContentLoader(tmp.path));

      expect(output.skillMd, contains('`/mystery-health-audit`'));
    });

    test('rewrites workflow cross-ref `<prefix>_best_practices_check/.agent/...`',
        () {
      final tmp = Directory.systemTemp.createTempSync('claude_wf_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        id: 'flutter_health',
        name: 'flutter-health-audit',
        planContent:
            'Follow `flutter_best_practices_check/.agent/workflows/x.md` next.',
      );

      final output = transformer.transformBundle(bundle, ContentLoader(tmp.path));

      expect(output.skillMd, contains('`/flutter-best-practices`'));
    });

    test('rewrites cursor_rules step reference to references/<rule>.md', () {
      final tmp = Directory.systemTemp.createTempSync('claude_cursorrule_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        id: 'flutter_health',
        name: 'flutter-health-audit',
        planContent:
            'Use `flutter_best_practices_check/cursor_rules/testing.yaml`.',
      );

      final output = transformer.transformBundle(bundle, ContentLoader(tmp.path));

      expect(
        output.skillMd,
        contains('`references/testing.md` (from `/flutter-best-practices`)'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // ruleToMarkdown
  // ---------------------------------------------------------------------------
  group('ruleToMarkdown', () {
    test('renders heading, description, pattern and prompt', () {
      const rule = ParsedRule(
        name: 'Testing',
        description: 'Test coverage rules',
        match: '**/*.dart',
        prompt: 'Do the thing.',
        fileName: 'testing',
      );

      final md = ClaudeTransformer.ruleToMarkdown(rule);

      expect(md, contains('# Testing'));
      expect(md, contains('> Test coverage rules'));
      expect(md, contains('**File pattern**: `**/*.dart`'));
      expect(md, contains('Do the thing.'));
      // No prompt trailing newline -> writeln appended exactly one.
      expect(md, endsWith('Do the thing.\n'));
    });

    test('does not double the trailing newline when prompt already ends in \\n',
        () {
      const rule = ParsedRule(
        name: 'Arch',
        description: 'Architecture',
        match: '*',
        prompt: 'Layered.\n',
        fileName: 'arch',
      );

      final md = ClaudeTransformer.ruleToMarkdown(rule);

      expect(md, endsWith('Layered.\n'));
      expect(md, isNot(endsWith('Layered.\n\n')));
    });
  });

  // ---------------------------------------------------------------------------
  // transform — file layout
  // ---------------------------------------------------------------------------
  group('transform', () {
    test('lays out SKILL.md, references/ and assets/ when template present', () {
      final tmp = Directory.systemTemp.createTempSync('claude_layout_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        id: 'flutter_health',
        name: 'flutter-health-audit',
        planContent: '# Plan\n\nbody',
        references: {
          'testing.md': _mdReference(
            name: 'Testing',
            description: 'Test rules',
            pattern: '**/*.dart',
            prompt: 'Cover everything.',
          ),
        },
        withTemplate: true,
      );

      final loader = ContentLoader(tmp.path);
      final agent = AgentRegistry.findById('claude')!;

      final output = transformer.transform(bundle, loader, agent);

      expect(output.skipped, isFalse);
      expect(output.files.keys, contains('flutter-health-audit/SKILL.md'));
      expect(
        output.files.keys,
        contains('flutter-health-audit/references/testing.md'),
      );
      expect(
        output.files.keys,
        contains('flutter-health-audit/assets/report-template.md'),
      );
    });

    test('omits assets/ when bundle.templatePath is null', () {
      final tmp = Directory.systemTemp.createTempSync('claude_notpl_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        id: 'flutter_health',
        name: 'flutter-health-audit',
        planContent: '# Plan\n\nbody',
        references: {
          'testing.md': _mdReference(
            name: 'Testing',
            description: 'Test rules',
            pattern: '*',
            prompt: 'Cover.',
          ),
        },
      );

      final loader = ContentLoader(tmp.path);
      final agent = AgentRegistry.findById('claude')!;

      final output = transformer.transform(bundle, loader, agent);

      expect(
        output.files.keys.any((k) => k.contains('/assets/')),
        isFalse,
      );
    });
  });
}
