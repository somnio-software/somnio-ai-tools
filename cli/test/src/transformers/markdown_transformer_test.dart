import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/agents/agent_registry.dart';
import 'package:somnio/src/content/content_loader.dart';
import 'package:somnio/src/content/skill_bundle.dart';
import 'package:somnio/src/transformers/markdown_transformer.dart';
import 'package:test/test.dart';

/// Writes a skill bundle on disk under [repoRoot] and returns its [SkillBundle].
SkillBundle _setupBundle({
  required String repoRoot,
  required String name,
  required String displayName,
  required String planContent,
  Map<String, String> references = const {},
}) {
  final skillDir = Directory(p.join(repoRoot, 'skills', name));
  skillDir.createSync(recursive: true);
  File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync(planContent);

  final refsDir = Directory(p.join(skillDir.path, 'references'));
  refsDir.createSync(recursive: true);
  for (final entry in references.entries) {
    File(p.join(refsDir.path, entry.key)).writeAsStringSync(entry.value);
  }

  return SkillBundle(
    id: 'test_health',
    name: name,
    displayName: displayName,
    description: 'A test skill.',
    planRelativePath: 'skills/$name/SKILL.md',
    rulesDirectory: 'skills/$name/references',
  );
}

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
  late MarkdownTransformer transformer;

  setUp(() => transformer = MarkdownTransformer());

  group('transform', () {
    test('includes the Rule Reference section when rules exist', () {
      final tmp = Directory.systemTemp.createTempSync('md_withrules_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        name: 'copilot-audit',
        displayName: 'Copilot Audit',
        planContent: '# Plan\n\nRun the audit.',
        references: {
          'testing.md': _mdReference(
            name: 'Testing',
            description: 'Test rules',
            pattern: '**/*.ts',
            prompt: 'Cover everything.',
          ),
        },
      );

      final loader = ContentLoader(tmp.path);
      final agent = AgentRegistry.findById('copilot')!;

      final output = transformer.transform(bundle, loader, agent);

      final content = output.files['copilot_audit.md']!;
      expect(content, contains('# Copilot Audit'));
      expect(content, contains('> A test skill.'));
      expect(content, contains('Run the audit.'));
      expect(content, contains('# Rule Reference'));
      expect(content, contains('## Testing'));
      expect(content, contains('**File pattern**: `**/*.ts`'));
      expect(content, contains('Cover everything.'));
    });

    test('omits the Rule Reference section when there are no rules', () {
      final tmp = Directory.systemTemp.createTempSync('md_norules_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        name: 'copilot-empty',
        displayName: 'Copilot Empty',
        planContent: '# Plan\n\nNothing to embed.',
      );

      final loader = ContentLoader(tmp.path);
      final agent = AgentRegistry.findById('copilot')!;

      final output = transformer.transform(bundle, loader, agent);

      final content = output.files['copilot_empty.md']!;
      expect(content, contains('Nothing to embed.'));
      expect(content, isNot(contains('# Rule Reference')));
    });

    test('derives file name replacing - with _ in the bundle name', () {
      final tmp = Directory.systemTemp.createTempSync('md_filename_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        name: 'react-best-practices',
        displayName: 'React Best Practices',
        planContent: '# Plan\n\nbody',
      );

      final loader = ContentLoader(tmp.path);
      final agent = AgentRegistry.findById('copilot')!;

      final output = transformer.transform(bundle, loader, agent);

      expect(output.files.keys, contains('react_best_practices.md'));
      expect(output.files.keys.single, isNot(contains('-')));
    });
  });
}
