import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/agents/agent_registry.dart';
import 'package:somnio/src/content/content_loader.dart';
import 'package:somnio/src/content/skill_bundle.dart';
import 'package:somnio/src/transformers/claude_transformer.dart';
import 'package:test/test.dart';

/// Seeds a minimal skill with an `agents/` directory and returns the bundle.
SkillBundle _seedSkill({
  required String repoRoot,
  required String name,
  required Map<String, String> agentFiles,
  bool withAgentsDir = true,
}) {
  final skillDir = Directory(p.join(repoRoot, 'skills', name))
    ..createSync(recursive: true);
  File(p.join(skillDir.path, 'SKILL.md'))
      .writeAsStringSync('---\nname: $name\n---\n\n# Plan\n\nbody');
  Directory(p.join(skillDir.path, 'references')).createSync(recursive: true);

  if (withAgentsDir) {
    final agentsDir = Directory(p.join(skillDir.path, 'agents'))
      ..createSync(recursive: true);
    for (final entry in agentFiles.entries) {
      File(p.join(agentsDir.path, entry.key)).writeAsStringSync(entry.value);
    }
  }

  return SkillBundle(
    id: name.replaceAll('-', '_'),
    name: name,
    displayName: 'Test Skill',
    description: 'A test skill.',
    planRelativePath: 'skills/$name/SKILL.md',
    rulesDirectory: 'skills/$name/references',
    agentsDirectory: withAgentsDir ? 'skills/$name/agents' : null,
  );
}

const _orchestrator = '---\n'
    'name: orchestrator\n'
    'description: routes\n'
    'model: mid\n'
    'tools: Read, Write\n'
    '---\n\n'
    'Orchestrator body with model: mid mentioned in prose.\n';

const _reportWriter = '---\n'
    'name: report-writer\n'
    'model: frontier\n'
    '---\n\n'
    'Writer body.\n';

const _scanner = '---\n'
    'name: scanner\n'
    'model: cheap\n'
    '---\n\n'
    'Scanner body.\n';

void main() {
  late Directory tmp;
  late ContentLoader loader;
  final claude = AgentRegistry.findById('claude')!;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('somnio_tx_agents_');
    loader = ContentLoader(tmp.path);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  group('transformBundle agent tier rewrite', () {
    test('rewrites cheap/mid/frontier to Claude model IDs', () {
      final bundle = _seedSkill(
        repoRoot: tmp.path,
        name: 'demo',
        agentFiles: {
          'orchestrator.md': _orchestrator,
          'report-writer.md': _reportWriter,
          'scanner.md': _scanner,
        },
      );

      final output =
          ClaudeTransformer().transformBundle(bundle, loader, agent: claude);

      expect(output.agentFiles['scanner.md'], contains('model: haiku'));
      expect(output.agentFiles['orchestrator.md'], contains('model: sonnet'));
      expect(output.agentFiles['report-writer.md'], contains('model: opus'));
      // Frontmatter tier line rewritten, prose mention untouched.
      expect(
        output.agentFiles['orchestrator.md'],
        contains('model: mid mentioned in prose'),
      );
      // Rest of file preserved.
      expect(output.agentFiles['scanner.md'], contains('Scanner body.'));
    });

    test('defaults to Claude when no agent is passed', () {
      final bundle = _seedSkill(
        repoRoot: tmp.path,
        name: 'demo',
        agentFiles: {'scanner.md': _scanner},
      );

      final output = ClaudeTransformer().transformBundle(bundle, loader);

      expect(output.agentFiles['scanner.md'], contains('model: haiku'));
    });

    test('resolves against a non-Claude agent', () {
      final bundle = _seedSkill(
        repoRoot: tmp.path,
        name: 'demo',
        agentFiles: {'scanner.md': _scanner},
      );
      final gemini = AgentRegistry.findById('gemini')!;

      final output =
          ClaudeTransformer().transformBundle(bundle, loader, agent: gemini);

      expect(output.agentFiles['scanner.md'], contains('model: gemini-3-flash'));
    });

    test('leaves unknown model values unchanged', () {
      final bundle = _seedSkill(
        repoRoot: tmp.path,
        name: 'demo',
        agentFiles: {
          'legacy.md': '---\nname: legacy\nmodel: inherit\n---\n\nbody\n',
        },
      );

      final output =
          ClaudeTransformer().transformBundle(bundle, loader, agent: claude);

      expect(output.agentFiles['legacy.md'], contains('model: inherit'));
    });

    test('empty agentFiles when bundle has no agents directory', () {
      final bundle = _seedSkill(
        repoRoot: tmp.path,
        name: 'demo',
        agentFiles: const {},
        withAgentsDir: false,
      );

      final output =
          ClaudeTransformer().transformBundle(bundle, loader, agent: claude);

      expect(output.agentFiles, isEmpty);
    });
  });

  group('transform emits agents/ files', () {
    test('skillDir transform output namespaces agents under agents/', () {
      final bundle = _seedSkill(
        repoRoot: tmp.path,
        name: 'demo',
        agentFiles: {'scanner.md': _scanner},
      );

      final out = ClaudeTransformer().transform(bundle, loader, claude);

      expect(out.files['demo/agents/scanner.md'], isNotNull);
      expect(out.files['demo/agents/scanner.md'], contains('model: haiku'));
    });
  });
}
