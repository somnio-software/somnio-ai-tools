import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:somnio/src/agents/agent_config.dart';
import 'package:somnio/src/agents/agent_registry.dart';
import 'package:somnio/src/agents/installed_skill_names.dart';
import 'package:somnio/src/content/content_loader.dart';
import 'package:somnio/src/content/skill_registry.dart';
import 'package:somnio/src/installers/agent_installer.dart';
import 'package:somnio/src/transformers/markdown_transformer.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

/// The repository root, whose `skills/` holds the shipped skill content.
String _repoRoot() {
  var dir = Directory.current;
  while (!Directory(p.join(dir.path, 'skills')).existsSync()) {
    if (dir.parent.path == dir.path) {
      throw StateError('Could not locate repo root from ${Directory.current}');
    }
    dir = dir.parent;
  }
  return dir.path;
}

void main() {
  final claude = AgentRegistry.findById('claude')!; // skillDir
  final cursor = AgentRegistry.findById('cursor')!; // singleFile
  final copilot = AgentRegistry.findById('copilot')!; // markdown
  final codex = AgentRegistry.findById('codex')!; // skillDir, legacy markdown
  // skillDir, legacy workflow
  final antigravity = AgentRegistry.findById('antigravity')!;
  const workflowAgent = AgentConfig(
    id: 'workflow-agent',
    displayName: 'Workflow Agent',
    installFormat: InstallFormat.workflow,
    installPath: '/tmp/workflow-agent',
    filePrefix: 'somnio_',
  );

  group('InstalledSkillNames.all', () {
    test('covers every registered skill and workflow skill', () {
      for (final bundle in SkillRegistry.skills) {
        expect(InstalledSkillNames.all, contains(bundle.name));
      }
      for (final skill in SkillRegistry.workflowSkills) {
        expect(InstalledSkillNames.all, contains(skill.name));
      }
    });

    test('includes the v1.x names', () {
      expect(InstalledSkillNames.all, containsAll(['somnio-fh', 'somnio-sa']));
    });
  });

  group('InstalledSkillNames.basenamesFor', () {
    test('skillDir uses the raw bundle name', () {
      expect(
        InstalledSkillNames.basenamesFor(claude),
        contains('flutter-health-audit'),
      );
    });

    test('singleFile appends .md to the bundle name', () {
      expect(
        InstalledSkillNames.basenamesFor(cursor),
        contains('flutter-health-audit.md'),
      );
    });

    test('markdown underscores the bundle name', () {
      expect(
        InstalledSkillNames.basenamesFor(copilot),
        contains('flutter_health_audit.md'),
      );
    });

    test('also covers the legacy install format', () {
      expect(
        InstalledSkillNames.basenamesFor(codex),
        containsAll(['flutter-health-audit', 'flutter_health_audit.md']),
      );
      expect(
        InstalledSkillNames.basenamesFor(claude),
        isNot(contains('flutter_health_audit.md')),
      );
    });

    test('workflow is matched by prefix, not by name', () {
      expect(InstalledSkillNames.basenamesFor(workflowAgent), isEmpty);
      expect(
        InstalledSkillNames.matches(workflowAgent, 'somnio_flutter_ha.md'),
        isTrue,
      );
    });

    test('a legacy workflow layout adds no names to the skill directories', () {
      expect(
        InstalledSkillNames.basenamesFor(antigravity),
        InstalledSkillNames.basenamesFor(claude),
      );
    });
  });

  group('InstalledSkillNames.matches', () {
    test('matches the names the transformers really write', () {
      // These are unprefixed, so the old filePrefix check missed them.
      expect(
          InstalledSkillNames.matches(claude, 'flutter-health-audit'), isTrue);
      expect(InstalledSkillNames.matches(cursor, 'security-audit.md'), isTrue);
      expect(InstalledSkillNames.matches(copilot, 'flutter_health_audit.md'),
          isTrue);
      expect(InstalledSkillNames.matches(antigravity, 'somnio_flutter_ha.md'),
          isTrue);
    });

    test('matches skills added to the registry after the v1.x rename', () {
      expect(
          InstalledSkillNames.matches(claude, 'python-health-audit'), isTrue);
      expect(InstalledSkillNames.matches(copilot, 'python_best_practices.md'),
          isTrue);
    });

    test('still matches legacy prefixed installs', () {
      expect(InstalledSkillNames.matches(claude, 'somnio-fh'), isTrue);
      expect(InstalledSkillNames.matches(copilot, 'somnio_fh.md'), isTrue);
    });

    test('does not match unrelated user content', () {
      expect(InstalledSkillNames.matches(claude, 'my-own-skill'), isFalse);
      expect(InstalledSkillNames.matches(copilot, 'notes.md'), isFalse);
      expect(
          InstalledSkillNames.matches(cursor, 'flutter-health-audit'), isFalse);
    });
  });

  group('InstalledSkillNames.hasMarkdownHeader', () {
    final loader = ContentLoader(_repoRoot());

    test('accepts what the markdown layout writes for every shipped skill', () {
      for (final bundle in SkillRegistry.skills) {
        final output = MarkdownTransformer().transform(bundle, loader, copilot);
        for (final MapEntry(key: name, value: content)
            in output.files.entries) {
          expect(
            InstalledSkillNames.hasMarkdownHeader(name, content),
            isTrue,
            reason: name,
          );
        }
      }
    });

    test('accepts what the markdown layout writes for every workflow skill',
        () {
      final dir = Directory.systemTemp.createTempSync('markdown_header_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      AgentInstaller(
        logger: _MockLogger(),
        loader: loader,
        agentConfig: AgentConfig(
          id: 'markdown-agent',
          displayName: 'Markdown Agent',
          installFormat: InstallFormat.markdown,
          installPath: dir.path,
        ),
        environment: const {},
      ).installWorkflowSkillsDetailed(SkillRegistry.workflowSkills);

      final files = dir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.md'))
          .toList();
      expect(files, hasLength(SkillRegistry.workflowSkills.length));
      for (final file in files) {
        final name = p.basename(file.path);
        expect(
          InstalledSkillNames.hasMarkdownHeader(name, file.readAsStringSync()),
          isTrue,
          reason: name,
        );
      }
    });

    test('accepts the header v1.x wrote under its old names', () {
      expect(
        InstalledSkillNames.hasMarkdownHeader(
          'somnio_fh.md',
          '# Flutter Project Health Audit\n\n> Audits a Flutter project.\n',
        ),
        isTrue,
      );
    });

    test("rejects a user's rule titled other than the skill it is named for",
        () {
      expect(
        InstalledSkillNames.hasMarkdownHeader(
          'react_best_practices.md',
          '# React rules\n\n> keep hooks pure\n',
        ),
        isFalse,
      );
    });

    test('rejects a file not named for a skill', () {
      expect(
        InstalledSkillNames.hasMarkdownHeader(
          'notes.md',
          '# Security Audit\n\n> Audits a project.\n',
        ),
        isFalse,
      );
    });
  });
}
