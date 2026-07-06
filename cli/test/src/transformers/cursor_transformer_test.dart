import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/agents/agent_config.dart';
import 'package:somnio/src/agents/agent_registry.dart';
import 'package:somnio/src/content/content_loader.dart';
import 'package:somnio/src/content/skill_bundle.dart';
import 'package:somnio/src/transformers/antigravity_transformer.dart';
import 'package:somnio/src/transformers/claude_transformer.dart';
import 'package:somnio/src/transformers/cursor_transformer.dart';
import 'package:somnio/src/transformers/markdown_transformer.dart';
import 'package:somnio/src/transformers/transformer.dart';
import 'package:test/test.dart';

/// Writes a skill bundle on disk under [repoRoot] and returns its [SkillBundle].
SkillBundle _setupBundle({
  required String repoRoot,
  required String name,
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
    displayName: 'Test Skill',
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
  late CursorTransformer transformer;

  setUp(() => transformer = CursorTransformer());

  group('transformBundle / transform', () {
    test('embeds plan and each rule section into one command file', () {
      final tmp = Directory.systemTemp.createTempSync('cursor_full_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        name: 'cursor-audit',
        planContent: '# Plan\n\nDo the audit.',
        references: {
          'a-testing.md': _mdReference(
            name: 'Testing',
            description: 'Test rules',
            pattern: '**/*.dart',
            prompt: 'Cover everything.',
          ),
          'b-arch.md': _mdReference(
            name: 'Architecture',
            description: 'Arch rules',
            pattern: '*',
            prompt: 'Keep layers clean.',
          ),
        },
      );

      final loader = ContentLoader(tmp.path);
      final agent = AgentRegistry.findById('cursor')!;

      final output = transformer.transform(bundle, loader, agent);

      expect(output.skipped, isFalse);
      expect(output.files.keys, contains('cursor-audit.md'));

      final content = output.files['cursor-audit.md']!;
      expect(content, contains('Do the audit.'));
      expect(content, contains('# Rule Reference'));
      expect(content, contains('## Testing'));
      expect(content, contains('> Test rules'));
      expect(content, contains('**File pattern**: `**/*.dart`'));
      expect(content, contains('Cover everything.'));
      expect(content, contains('## Architecture'));
      expect(content, contains('Keep layers clean.'));
    });

    test('still emits a command file with the Rule Reference header when '
        'there are zero references', () {
      final tmp = Directory.systemTemp.createTempSync('cursor_norefs_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final bundle = _setupBundle(
        repoRoot: tmp.path,
        name: 'cursor-empty',
        planContent: '# Plan\n\nNo rules.',
      );

      final loader = ContentLoader(tmp.path);
      final agent = AgentRegistry.findById('cursor')!;

      final output = transformer.transform(bundle, loader, agent);

      final content = output.files['cursor-empty.md']!;
      expect(content, contains('No rules.'));
      expect(content, contains('# Rule Reference'));
      expect(content, isNot(contains('## ')));
    });
  });

  // ---------------------------------------------------------------------------
  // transformerFor factory — all 4 InstallFormat arms.
  // ---------------------------------------------------------------------------
  group('transformerFor factory', () {
    test('maps every InstallFormat to its concrete transformer type', () {
      expect(
        transformerFor(InstallFormat.skillDir),
        isA<ClaudeTransformer>(),
      );
      expect(
        transformerFor(InstallFormat.singleFile),
        isA<CursorTransformer>(),
      );
      expect(
        transformerFor(InstallFormat.workflow),
        isA<AntigravityTransformer>(),
      );
      expect(
        transformerFor(InstallFormat.markdown),
        isA<MarkdownTransformer>(),
      );
    });

    test('covers exactly the 4 known InstallFormat values', () {
      // Guards the factory if a new enum value is ever added without a
      // matching switch arm.
      expect(InstallFormat.values.length, 4);
      for (final format in InstallFormat.values) {
        expect(transformerFor(format), isA<Transformer>());
      }
    });
  });
}
