import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/commands/uninstall_command.dart';
import 'package:somnio/src/installers/skill_manifest.dart';
import 'package:test/test.dart';

/// Creates [path] with [contents], including any missing parent directories.
void _writeFile(String path, [String contents = 'x']) {
  Directory(p.dirname(path)).createSync(recursive: true);
  File(path).writeAsStringSync(contents);
}

/// The header Somnio's markdown layout writes above every skill.
const _markdownSkill = '# Security Audit\n\n> Audits a project.\n\nBody.\n';

/// Writes a Somnio-style `<dir>/SKILL.md` whose frontmatter names [name].
void _writeSkill(String dir, String name) {
  _writeFile(p.join(dir, name, 'SKILL.md'), '---\nname: $name\n---\n');
}

void main() {
  group('removeAgentInstalls', () {
    late Directory home;

    setUp(() {
      home = Directory.systemTemp.createTempSync('uninstall_command_test_');
    });

    tearDown(() {
      if (home.existsSync()) home.deleteSync(recursive: true);
    });

    test('removes Cursor execution rules, not just its commands', () {
      _writeFile(p.join(home.path, '.cursor', 'commands', 'security-audit.md'));
      _writeFile(
        p.join(home.path, '.cursor', 'somnio_rules', 'flutter', 'rules.md'),
      );

      removeAgentInstalls(home: home.path, environment: const {});

      expect(
        Directory(p.join(home.path, '.cursor', 'somnio_rules')).existsSync(),
        isFalse,
        reason: '~/.cursor/somnio_rules must not survive an uninstall',
      );
      expect(
        File(p.join(home.path, '.cursor', 'commands', 'security-audit.md'))
            .existsSync(),
        isFalse,
      );
    });

    test('removes Claude skills that exist in the registry', () {
      // Registry skills absent from the old hardcoded _allSkillNames list.
      for (final name in const [
        'python-health-audit',
        'python-best-practices',
        'dart-model-from-json',
        'optimize-claude-config',
      ]) {
        _writeSkill(p.join(home.path, '.claude', 'skills'), name);
      }

      removeAgentInstalls(home: home.path, environment: const {});

      for (final name in const [
        'python-health-audit',
        'python-best-practices',
        'dart-model-from-json',
        'optimize-claude-config',
      ]) {
        expect(
          Directory(p.join(home.path, '.claude', 'skills', name)).existsSync(),
          isFalse,
          reason: '$name is in SkillRegistry and must be uninstalled',
        );
      }
    });

    test('removes legacy v1.x Claude skills including somnio-rh/somnio-rp', () {
      for (final name in const ['somnio-fh', 'somnio-rh', 'somnio-rp']) {
        _writeSkill(p.join(home.path, '.claude', 'skills'), name);
      }

      removeAgentInstalls(home: home.path, environment: const {});

      for (final name in const ['somnio-fh', 'somnio-rh', 'somnio-rp']) {
        expect(
          Directory(p.join(home.path, '.claude', 'skills', name)).existsSync(),
          isFalse,
          reason: '$name is a legacy name and must still be cleaned up',
        );
      }
    });

    test('keeps a same-named symlink pointing outside the location', () {
      final target = Directory(p.join(home.path, 'src', 'security-audit'))
        ..createSync(recursive: true);
      final skillsDir = Directory(p.join(home.path, '.claude', 'skills'))
        ..createSync(recursive: true);
      final link = Link(p.join(skillsDir.path, 'security-audit'))
        ..createSync(target.path);
      final warnings = <String>[];

      removeAgentInstalls(
        home: home.path,
        environment: const {},
        onWarning: warnings.add,
      );

      expect(link.existsSync(), isTrue);
      expect(warnings, [contains('outside')]);
    });

    test('removes a same-named symlink resolving inside the location', () {
      final skillsDir = p.join(home.path, '.claude', 'skills');
      _writeSkill(skillsDir, 'old-copy');
      final link = Link(p.join(skillsDir, 'security-audit'))
        ..createSync('old-copy');

      removeAgentInstalls(home: home.path, environment: const {});

      expect(link.existsSync(), isFalse);
      expect(
        File(p.join(skillsDir, 'old-copy', 'SKILL.md')).existsSync(),
        isTrue,
        reason: 'only the link is removed, never its target',
      );
    });

    test('keeps a same-named directory that is not a Somnio install', () {
      final skillsDir = p.join(home.path, '.claude', 'skills');
      _writeFile(
        p.join(skillsDir, 'security-audit', 'SKILL.md'),
        '---\nname: my-security-audit\n---\n',
      );
      _writeFile(p.join(skillsDir, 'git-commit-format', 'notes.md'));
      final warnings = <String>[];

      removeAgentInstalls(
        home: home.path,
        environment: const {},
        onWarning: warnings.add,
      );

      expect(
        Directory(p.join(skillsDir, 'security-audit')).existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(skillsDir, 'git-commit-format')).existsSync(),
        isTrue,
      );
      expect(warnings, hasLength(2));
    });

    test('skips the name sweep where a manifest records the install', () {
      final skillsDir = p.join(home.path, '.claude', 'skills');
      _writeSkill(skillsDir, 'flutter-health-audit');
      _writeFile(p.join(skillsDir, '.somnio-skills.json'), '{}');

      removeAgentInstalls(home: home.path, environment: const {});

      expect(
        Directory(p.join(skillsDir, 'flutter-health-audit')).existsSync(),
        isTrue,
        reason: 'not in the manifest, so not ours',
      );
    });

    test('removes Somnio skills recorded in the skills.sh lock', () {
      _writeFile(
        p.join(home.path, '.agents', '.skill-lock.json'),
        jsonEncode({
          'version': 3,
          'skills': {
            'security-audit': {'source': 'somnio-software/somnio-ai-tools'},
          },
        }),
      );
      _writeFile(
        p.join(home.path, '.agents', 'skills', 'security-audit', 'SKILL.md'),
        '---\nname: security-audit\n---\n',
      );

      removeAgentInstalls(home: home.path, environment: const {});

      expect(
        Directory(p.join(home.path, '.agents', 'skills', 'security-audit'))
            .existsSync(),
        isFalse,
      );
    });

    test('keeps ~/.agents/skills copies the skills.sh lock does not own', () {
      final canonical =
          p.join(home.path, '.agents', 'skills', 'security-audit', 'SKILL.md');
      _writeFile(canonical);

      removeAgentInstalls(home: home.path, environment: const {});

      expect(File(canonical).existsSync(), isTrue);
    });

    test('reports skills.sh removals and warnings', () {
      _writeFile(
        p.join(home.path, '.agents', '.skill-lock.json'),
        jsonEncode({
          'version': 3,
          'skills': {
            'fha': {'source': 'somnio-software/somnio-ai-tools'},
            'odd': {'source': 'somnio-software/somnio-ai-tools'},
          },
        }),
      );
      _writeFile(
        p.join(home.path, '.agents', 'skills', 'fha', 'SKILL.md'),
        '---\nname: fha\n---\n',
      );
      _writeFile(p.join(home.path, '.agents', 'skills', 'odd'));
      final removed = <String>[];
      final warnings = <String>[];

      removeAgentInstalls(
        home: home.path,
        environment: const {},
        onRemoved: removed.add,
        onWarning: warnings.add,
      );

      expect(removed, contains(contains('Removed skills.sh copy')));
      expect(warnings, [contains('not a directory')]);
    });

    test('removes Antigravity workflows nested under global_workflows/', () {
      _writeFile(
        p.join(home.path, '.gemini', 'antigravity', 'global_workflows',
            'somnio_flutter_health.md'),
      );
      _writeFile(
        p.join(home.path, '.gemini', 'antigravity', 'somnio_rules', 'r.md'),
      );

      removeAgentInstalls(home: home.path, environment: const {});

      expect(
        File(p.join(home.path, '.gemini', 'antigravity', 'global_workflows',
                'somnio_flutter_health.md'))
            .existsSync(),
        isFalse,
      );
      expect(
        Directory(p.join(home.path, '.gemini', 'antigravity', 'somnio_rules'))
            .existsSync(),
        isFalse,
      );
    });

    test('keeps workflows somnio did not write in global_workflows/', () {
      final workflows =
          p.join(home.path, '.gemini', 'antigravity', 'global_workflows');
      _writeFile(p.join(workflows, 'somnio_flutter_health.md'));
      _writeFile(p.join(workflows, 'deploy.md'));

      removeAgentInstalls(home: home.path, environment: const {});

      expect(
        File(p.join(workflows, 'somnio_flutter_health.md')).existsSync(),
        isFalse,
      );
      expect(File(p.join(workflows, 'deploy.md')).existsSync(), isTrue);
    });

    test('does not sweep the folder a moved agent installs to now', () {
      // No release wrote there before the manifest existed, so anything
      // unrecorded there is the user's; recorded installs are removed by
      // removeManifestTrackedInstalls.
      final antigravity = p.join(home.path, '.gemini', 'config', 'skills');
      _writeSkill(antigravity, 'flutter-health-audit');
      final copilot = p.join(home.path, '.copilot', 'skills');
      _writeSkill(copilot, 'somnio-standup');
      final prompts = p.join(home.path, '.aws', 'amazonq', 'prompts');
      _writeFile(p.join(prompts, 'somnio-standup.md'), 'MINE');
      _writeFile(p.join(prompts, 'git_commit_format.md'), 'MINE');

      removeAgentInstalls(home: home.path, environment: const {});

      expect(
        Directory(p.join(antigravity, 'flutter-health-audit')).existsSync(),
        isTrue,
      );
      expect(Directory(p.join(copilot, 'somnio-standup')).existsSync(), isTrue);
      expect(File(p.join(prompts, 'somnio-standup.md')).existsSync(), isTrue);
      expect(
          File(p.join(prompts, 'git_commit_format.md')).existsSync(), isTrue);
    });

    test('removes pre-manifest Roo Code rules from its old rules folder', () {
      final rules = p.join(home.path, '.roo', 'rules');
      _writeFile(p.join(rules, 'security_audit.md'), _markdownSkill);

      removeAgentInstalls(home: home.path, environment: const {});

      expect(File(p.join(rules, 'security_audit.md')).existsSync(), isFalse);
    });

    test("keeps the user's own rules in Roo Code's old rules folder", () {
      final rules = p.join(home.path, '.roo', 'rules');
      _writeFile(p.join(rules, 'security_audit.md'), _markdownSkill);
      _writeFile(p.join(rules, 'team-conventions.md'));

      removeAgentInstalls(home: home.path, environment: const {});

      expect(File(p.join(rules, 'team-conventions.md')).existsSync(), isTrue);
    });

    test("keeps a user's rule with Somnio's prefix in Roo Code's rules folder",
        () {
      // Even with Somnio's header: only a skill's exact name is Somnio's.
      final rule = p.join(home.path, '.roo', 'rules', 'somnio-team.md');
      _writeFile(rule, _markdownSkill);

      removeAgentInstalls(home: home.path, environment: const {});

      expect(File(rule).existsSync(), isTrue);
    });

    test("keeps a user's rule titled other than the skill it is named for", () {
      final rule =
          p.join(home.path, '.roo', 'rules', 'react_best_practices.md');
      _writeFile(rule, '# React rules\n\n> keep hooks pure\n');

      removeAgentInstalls(home: home.path, environment: const {});

      expect(File(rule).existsSync(), isTrue);
    });

    test("keeps a user's link with Somnio's prefix in Roo Code's rules folder",
        () {
      final rules = p.join(home.path, '.roo', 'rules');
      _writeFile(p.join(rules, 'team', 'shared.md'));
      final link = Link(p.join(rules, 'somnio-shared.md'))
        ..createSync(p.join('team', 'shared.md'));

      removeAgentInstalls(home: home.path, environment: const {});

      expect(link.existsSync(), isTrue);
    });

    test("keeps a user's rule named like a skill without Somnio's header", () {
      final rule = p.join(home.path, '.kilocode', 'rules', 'security_audit.md');
      _writeFile(rule, '# Our audit\n\nCheck the changelog.\n');
      final warnings = <String>[];

      removeAgentInstalls(
        home: home.path,
        environment: const {},
        onWarning: warnings.add,
      );

      expect(File(rule).existsSync(), isTrue);
      expect(warnings, [contains(rule)]);
    });

    test('removes Gemini skills and its execution rules', () {
      _writeFile(
        p.join(home.path, '.gemini', 'skills', 'security_audit.md'),
      );
      _writeFile(p.join(home.path, '.gemini', 'somnio_rules', 'r.md'));

      removeAgentInstalls(home: home.path, environment: const {});

      expect(
        File(p.join(home.path, '.gemini', 'skills', 'security_audit.md'))
            .existsSync(),
        isFalse,
      );
      expect(
        Directory(p.join(home.path, '.gemini', 'somnio_rules')).existsSync(),
        isFalse,
      );
    });

    test('leaves files somnio did not install untouched', () {
      final userFiles = [
        p.join(home.path, '.claude', 'skills', 'my-own-skill', 'SKILL.md'),
        p.join(home.path, '.cursor', 'commands', 'my-command.md'),
        p.join(home.path, '.gemini', 'skills', 'my_notes.md'),
        p.join(home.path, '.agents', 'skills', 'unrelated', 'SKILL.md'),
      ];
      for (final f in userFiles) {
        _writeFile(f, 'user content');
      }

      removeAgentInstalls(home: home.path, environment: const {});

      for (final f in userFiles) {
        expect(
          File(f).existsSync(),
          isTrue,
          reason: 'uninstall must never delete user-authored $f',
        );
      }
    });

    test('reports whether anything was removed', () {
      expect(
        removeAgentInstalls(home: home.path, environment: const {}),
        isFalse,
        reason: 'nothing installed under an empty home',
      );

      _writeSkill(p.join(home.path, '.claude', 'skills'), 'security-audit');

      expect(
          removeAgentInstalls(home: home.path, environment: const {}), isTrue);
    });
    test('removes a pre-manifest Codex install in the pre-3.2.12 layout', () {
      final codexSkills = p.join(home.path, '.codex', 'skills');
      _writeFile(p.join(codexSkills, 'flutter_health_audit.md'));
      _writeFile(
        p.join(
          home.path,
          '.codex',
          'somnio_rules',
          'flutter-health-audit',
          'references',
          'rule.md',
        ),
      );
      _writeSkill(codexSkills, 'security-audit');

      removeAgentInstalls(home: home.path, environment: const {});

      expect(
        File(p.join(codexSkills, 'flutter_health_audit.md')).existsSync(),
        isFalse,
      );
      expect(
        Directory(p.join(home.path, '.codex', 'somnio_rules')).existsSync(),
        isFalse,
      );
      expect(
        Directory(p.join(codexSkills, 'security-audit')).existsSync(),
        isFalse,
      );
    });

    test('removes pre-manifest installs from folders agents never read', () {
      final legacy = {
        'windsurf': p.join(home.path, '.windsurf', 'workflows'),
        'amp': p.join(home.path, '.amp', 'skills'),
        'copilot': p.join(home.path, '.copilot', 'agents'),
        'amazonq': p.join(home.path, '.amazonq', 'prompts'),
      };
      for (final dir in legacy.values) {
        _writeFile(p.join(dir, 'security_audit.md'), _markdownSkill);
        _writeFile(p.join(dir, 'notes.md'), 'THEIRS');
      }
      final ampRules = p.join(home.path, '.amp', 'somnio_rules');
      _writeFile(p.join(ampRules, 'security-audit', 'references', 'r.md'));

      removeAgentInstalls(home: home.path, environment: const {});

      for (final MapEntry(key: id, value: dir) in legacy.entries) {
        expect(
          File(p.join(dir, 'security_audit.md')).existsSync(),
          isFalse,
          reason: id,
        );
        expect(File(p.join(dir, 'notes.md')).existsSync(), isTrue, reason: id);
      }
      expect(Directory(ampRules).existsSync(), isFalse);
    });
  });

  group('removeManifestTrackedInstalls', () {
    late Directory home;
    late Directory project;

    setUp(() {
      home = Directory.systemTemp.createTempSync('uninstall_manifest_home_');
      project = Directory.systemTemp.createTempSync('uninstall_manifest_proj_');
    });

    tearDown(() {
      if (home.existsSync()) home.deleteSync(recursive: true);
      if (project.existsSync()) project.deleteSync(recursive: true);
    });

    /// Installs a fake somnio skill for Claude under [root] and records it in
    /// that location's manifest, mirroring what AgentInstaller writes.
    void seedClaudeSkill(String root, String skill) {
      final dir = p.join(root, '.claude', 'skills');
      _writeFile(p.join(dir, skill, 'SKILL.md'));
      SkillManifest.load(dir)
        ..record(
          skill: skill,
          kind: 'audit',
          paths: [ManifestPath(ManifestRoot.install, skill)],
        )
        ..save();
    }

    group('with a manifest at the global location', () {
      late String skillsDir;

      setUp(() {
        seedClaudeSkill(home.path, 'security-audit');
        skillsDir = p.join(home.path, '.claude', 'skills');
        // Third-party skill sharing a Somnio skill's name, not in the manifest.
        _writeSkill(skillsDir, 'flutter-health-audit');

        removeAgentInstalls(home: home.path, environment: const {});
        removeManifestTrackedInstalls(
          home: home.path,
          projectRoot: project.path,
        );
      });

      test('keeps a same-named skill the manifest does not record', () {
        expect(
          Directory(p.join(skillsDir, 'flutter-health-audit')).existsSync(),
          isTrue,
        );
      });

      test('removes the skill the manifest records', () {
        expect(
          Directory(p.join(skillsDir, 'security-audit')).existsSync(),
          isFalse,
        );
      });
    });

    test('removes what a legacy folder behind a dotfiles link records', () {
      final dotfiles = p.join(project.path, 'dotfiles', 'amp');
      final skills = p.join(dotfiles, 'skills');
      final rules = p.join(dotfiles, 'somnio_rules');
      _writeFile(p.join(skills, 'security-audit.md'));
      _writeFile(p.join(rules, 'security-audit', 'references', 'r.md'));
      SkillManifest.load(skills)
        ..record(
          skill: 'security-audit',
          kind: 'audit',
          paths: const [
            ManifestPath(ManifestRoot.install, 'security-audit.md'),
            ManifestPath(ManifestRoot.rules, 'security-audit'),
          ],
        )
        ..save();
      Link(p.join(home.path, '.amp')).createSync(dotfiles);

      removeManifestTrackedInstalls(home: home.path, projectRoot: project.path);

      expect(File(p.join(skills, 'security-audit.md')).existsSync(), isFalse);
      expect(Directory(p.join(rules, 'security-audit')).existsSync(), isFalse);
      expect(
        File(p.join(skills, SkillManifest.fileName)).existsSync(),
        isFalse,
      );
    });

    group('a manifest shared through a link to another agent\'s folder', () {
      /// Records [skill] in the manifest at [skills] with an install and a
      /// rules entry, and writes the install file plus its rules folder in
      /// each of [rulesDirs].
      void seedShared(
        String skills,
        String skill, {
        required List<String> rulesDirs,
      }) {
        _writeFile(p.join(skills, 'somnio_$skill.md'));
        for (final rules in rulesDirs) {
          _writeFile(p.join(rules, skill, 'references', 'r.md'));
        }
        SkillManifest.load(skills)
          ..record(
            skill: skill,
            kind: 'audit',
            paths: [
              ManifestPath(ManifestRoot.install, 'somnio_$skill.md'),
              ManifestPath(ManifestRoot.rules, skill),
            ],
          )
          ..save();
      }

      /// Expects the install file, every rules folder and the manifest of
      /// [seedShared] gone.
      void expectSharedGone(
        String skills,
        String skill, {
        required List<String> rulesDirs,
      }) {
        expect(File(p.join(skills, 'somnio_$skill.md')).existsSync(), isFalse);
        for (final rules in rulesDirs) {
          expect(
            Directory(p.join(rules, skill)).existsSync(),
            isFalse,
            reason: rules,
          );
        }
        expect(
          File(p.join(skills, SkillManifest.fileName)).existsSync(),
          isFalse,
        );
      }

      test('clears the rules of both agents (.amp/skills -> .aider/skills)',
          () {
        // Amp comes first in the registry and reads Aider's manifest: its
        // rules entry may be Amp's or Aider's, so both folders are cleared.
        final skills = p.join(project.path, '.aider', 'skills');
        final rulesDirs = [
          p.join(project.path, '.aider', 'somnio_rules'),
          p.join(project.path, '.amp', 'somnio_rules'),
        ];
        seedShared(skills, 'security-audit', rulesDirs: rulesDirs);
        Link(p.join(project.path, '.amp', 'skills')).createSync(skills);

        removeManifestTrackedInstalls(
          home: home.path,
          projectRoot: project.path,
        );

        expectSharedGone(skills, 'security-audit', rulesDirs: rulesDirs);
      });

      test('clears the rules of both agents (~/.amp/skills -> ~/.aider/skills)',
          () {
        final skills = p.join(home.path, '.aider', 'skills');
        final rulesDirs = [
          p.join(home.path, '.aider', 'somnio_rules'),
          p.join(home.path, '.amp', 'somnio_rules'),
        ];
        seedShared(skills, 'security-audit', rulesDirs: rulesDirs);
        Link(p.join(home.path, '.amp', 'skills')).createSync(skills);

        removeManifestTrackedInstalls(
          home: home.path,
          projectRoot: project.path,
        );

        expectSharedGone(skills, 'security-audit', rulesDirs: rulesDirs);
      });

      test('clears a manifest no current folder holds (~/.amp -> ~/.cursor)',
          () {
        // Amp's old `skills` lands in no agent's install folder, while its
        // old rules folder is Cursor's: still Amp's manifest to read.
        final skills = p.join(home.path, '.cursor', 'skills');
        final rulesDirs = [p.join(home.path, '.cursor', 'somnio_rules')];
        seedShared(skills, 'security-audit', rulesDirs: rulesDirs);
        Link(p.join(home.path, '.amp'))
            .createSync(p.join(home.path, '.cursor'));

        removeManifestTrackedInstalls(
          home: home.path,
          projectRoot: project.path,
        );

        expectSharedGone(skills, 'security-audit', rulesDirs: rulesDirs);
      });

      test('clears a legacy folder holding another agent\'s', () {
        // `.windsurf/workflows -> .github` holds Copilot's `.github/skills`.
        final github = p.join(project.path, '.github');
        _writeFile(p.join(github, 'somnio_security_audit.md'));
        SkillManifest.load(github)
          ..record(
            skill: 'security-audit',
            kind: 'audit',
            paths: const [
              ManifestPath(ManifestRoot.install, 'somnio_security_audit.md'),
            ],
          )
          ..save();
        Directory(p.join(project.path, '.windsurf')).createSync();
        Link(p.join(project.path, '.windsurf', 'workflows')).createSync(github);

        removeManifestTrackedInstalls(
          home: home.path,
          projectRoot: project.path,
        );

        expect(
          File(p.join(github, 'somnio_security_audit.md')).existsSync(),
          isFalse,
        );
        expect(
          File(p.join(github, SkillManifest.fileName)).existsSync(),
          isFalse,
        );
      });

      test(
          'resolves rules entries in the agent\'s rules folder, never in an '
          'install folder (~/.amp/skills -> ~/.copilot/skills)', () {
        // Copilot has no rules folder: Amp's entry is only Amp's to resolve.
        final skills = p.join(home.path, '.copilot', 'skills');
        final rulesDirs = [p.join(home.path, '.amp', 'somnio_rules')];
        seedShared(skills, 'security-audit', rulesDirs: rulesDirs);
        _writeSkill(skills, 'security-audit');
        Link(p.join(home.path, '.amp', 'skills')).createSync(skills);

        removeManifestTrackedInstalls(
          home: home.path,
          projectRoot: project.path,
        );

        expectSharedGone(skills, 'security-audit', rulesDirs: rulesDirs);
        expect(
          File(p.join(skills, 'security-audit', 'SKILL.md')).existsSync(),
          isTrue,
        );
      });

      test(
          'keeps the unrecorded skills of a shared folder (~/.amp -> ~/.claude)',
          () {
        seedClaudeSkill(home.path, 'security-audit');
        final claudeSkills = p.join(home.path, '.claude', 'skills');
        _writeSkill(claudeSkills, 'flutter-health-audit');
        Link(p.join(home.path, '.amp'))
            .createSync(p.join(home.path, '.claude'));

        // In the command's order: the name sweep skips the folder, since it
        // has a manifest, then the manifests.
        removeAgentInstalls(home: home.path, environment: const {});
        removeManifestTrackedInstalls(
          home: home.path,
          projectRoot: project.path,
        );

        expect(
          Directory(p.join(claudeSkills, 'security-audit')).existsSync(),
          isFalse,
        );
        expect(
          File(p.join(claudeSkills, SkillManifest.fileName)).existsSync(),
          isFalse,
        );
        expect(
          Directory(p.join(claudeSkills, 'flutter-health-audit')).existsSync(),
          isTrue,
        );
      });
    });

    test('skips rules entries no agent with a rules folder could have written',
        () {
      // Agents without one (Copilot here) never recorded `rules` entries;
      // a hand-edited one must not resolve against the install folder.
      final skills = p.join(home.path, '.copilot', 'skills');
      _writeSkill(skills, 'security-audit');
      SkillManifest.load(skills)
        ..record(
          skill: 'security-audit',
          kind: 'audit',
          paths: const [ManifestPath(ManifestRoot.rules, 'security-audit')],
        )
        ..save();

      removeManifestTrackedInstalls(home: home.path, projectRoot: project.path);

      expect(
        File(p.join(skills, 'security-audit', 'SKILL.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(skills, SkillManifest.fileName)).existsSync(),
        isFalse,
      );
    });

    test('removes a project Amazon Q install from .amazonq/prompts', () {
      // Its current project folder and its legacy one at once.
      final prompts = p.join(project.path, '.amazonq', 'prompts');
      _writeFile(p.join(prompts, 'somnio_security_audit.md'));
      SkillManifest.load(prompts)
        ..record(
          skill: 'security-audit',
          kind: 'audit',
          paths: const [
            ManifestPath(ManifestRoot.install, 'somnio_security_audit.md'),
          ],
        )
        ..save();

      removeManifestTrackedInstalls(home: home.path, projectRoot: project.path);

      expect(
        File(p.join(prompts, 'somnio_security_audit.md')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(prompts, SkillManifest.fileName)).existsSync(),
        isFalse,
      );
    });

    group('a Codex manifest written before 3.2.12', () {
      late String codexSkills;
      late String legacyRules;

      setUp(() {
        codexSkills = p.join(home.path, '.codex', 'skills');
        legacyRules = p.join(home.path, '.codex', 'somnio_rules');
        _writeFile(p.join(codexSkills, 'flutter_health_audit.md'));
        _writeFile(
          p.join(legacyRules, 'flutter-health-audit', 'references', 'r.md'),
        );
        // Not recorded: must survive even though it shares the rules entry's
        // relative path under the install root.
        _writeSkill(codexSkills, 'flutter-health-audit');
        SkillManifest.load(codexSkills)
          ..record(
            skill: 'flutter-health-audit',
            kind: 'audit',
            paths: const [
              ManifestPath(ManifestRoot.install, 'flutter_health_audit.md'),
              ManifestPath(ManifestRoot.rules, 'flutter-health-audit'),
            ],
          )
          ..save();

        removeManifestTrackedInstalls(
          home: home.path,
          projectRoot: project.path,
        );
      });

      test('removes the recorded flat file', () {
        expect(
          File(p.join(codexSkills, 'flutter_health_audit.md')).existsSync(),
          isFalse,
        );
      });

      test('resolves rules entries against the legacy somnio_rules dir', () {
        expect(
          Directory(p.join(legacyRules, 'flutter-health-audit')).existsSync(),
          isFalse,
        );
        expect(
          File(p.join(codexSkills, 'flutter-health-audit', 'SKILL.md'))
              .existsSync(),
          isTrue,
        );
      });
    });

    group('an Antigravity manifest written before 3.2.15', () {
      late String legacyDir;

      /// Seeds the workflow layout releases before 3.2.15 wrote under [root], recorded in
      /// that location's manifest the way the installer recorded it.
      void seedWorkflowInstall(String root) {
        legacyDir = p.join(root, '.gemini', 'antigravity');
        const workflow = 'global_workflows/somnio_flutter_health.md';
        const rule = 'somnio_rules/flutter-health/references/r.md';
        _writeFile(p.join(legacyDir, workflow));
        _writeFile(p.join(legacyDir, rule));
        _writeFile(p.join(legacyDir, 'global_workflows', 'deploy.md'));
        SkillManifest.load(legacyDir)
          ..record(
            skill: 'flutter-health-audit',
            kind: 'audit',
            paths: const [
              ManifestPath(ManifestRoot.install, workflow),
              ManifestPath(ManifestRoot.install, rule),
            ],
          )
          ..save();
      }

      void expectRemoved() {
        expect(
          File(p.join(
            legacyDir,
            'global_workflows',
            'somnio_flutter_health.md',
          )).existsSync(),
          isFalse,
        );
        expect(
          File(p.join(
            legacyDir,
            'somnio_rules',
            'flutter-health',
            'references',
            'r.md',
          )).existsSync(),
          isFalse,
        );
        expect(
          File(p.join(legacyDir, SkillManifest.fileName)).existsSync(),
          isFalse,
        );
        expect(
          File(p.join(legacyDir, 'global_workflows', 'deploy.md')).existsSync(),
          isTrue,
          reason: 'a workflow the manifest does not record is not ours',
        );
      }

      test('removes the recorded files at the global legacy location', () {
        seedWorkflowInstall(home.path);

        final removed = removeManifestTrackedInstalls(
          home: home.path,
          projectRoot: project.path,
        );

        expect(removed, isTrue);
        expectRemoved();
      });

      test('removes the recorded files at the project legacy location', () {
        seedWorkflowInstall(project.path);

        removeManifestTrackedInstalls(
          home: home.path,
          projectRoot: project.path,
        );

        expectRemoved();
      });
    });

    test(
        'also cleans a pre-3.2.12 Codex install left at ~/.codex with CODEX_HOME set',
        () {
      final oldSkills = p.join(home.path, '.codex', 'skills');
      final oldRules = p.join(home.path, '.codex', 'somnio_rules');
      _writeFile(p.join(oldSkills, 'security_audit.md'));
      _writeFile(p.join(oldRules, 'security-audit', 'references', 'r.md'));
      SkillManifest.load(oldSkills)
        ..record(
          skill: 'security-audit',
          kind: 'audit',
          paths: const [
            ManifestPath(ManifestRoot.install, 'security_audit.md'),
            ManifestPath(ManifestRoot.rules, 'security-audit'),
          ],
        )
        ..save();

      removeManifestTrackedInstalls(
        home: home.path,
        projectRoot: project.path,
        environment: {'CODEX_HOME': p.join(home.path, 'custom-codex')},
      );

      expect(
          File(p.join(oldSkills, 'security_audit.md')).existsSync(), isFalse);
      expect(
          Directory(p.join(oldRules, 'security-audit')).existsSync(), isFalse);
      expect(
        File(p.join(oldSkills, SkillManifest.fileName)).existsSync(),
        isFalse,
      );
    });

    test('never deletes through a symlinked directory a manifest records', () {
      // A cloned repo could commit `.claude/skills/evil -> ../..` plus a
      // manifest entry `evil/src`; following it would delete <project>/src.
      final skills = p.join(project.path, '.claude', 'skills');
      final src = Directory(p.join(project.path, 'src'))
        ..createSync(recursive: true);
      Link(p.join(skills, 'evil')).createSync(project.path, recursive: true);
      SkillManifest.load(skills)
        ..record(
          skill: 'evil',
          kind: 'audit',
          paths: const [ManifestPath(ManifestRoot.install, 'evil/src')],
        )
        ..save();

      removeManifestTrackedInstalls(
        home: home.path,
        projectRoot: project.path,
      );

      expect(src.existsSync(), isTrue);
    });

    test('leaves ~/.claude alone with CLAUDE_CONFIG_DIR set', () {
      final configHome = p.join(home.path, '.claude-work');
      for (final skills in [
        p.join(configHome, 'skills'),
        p.join(home.path, '.claude', 'skills'),
      ]) {
        _writeSkill(skills, 'security-audit');
        SkillManifest.load(skills)
          ..record(
            skill: 'security-audit',
            kind: 'audit',
            paths: const [
              ManifestPath(ManifestRoot.install, 'security-audit'),
            ],
          )
          ..save();
      }

      removeManifestTrackedInstalls(
        home: home.path,
        projectRoot: project.path,
        environment: {'CLAUDE_CONFIG_DIR': configHome},
      );

      expect(
        Directory(p.join(configHome, 'skills', 'security-audit')).existsSync(),
        isFalse,
      );
      expect(
        Directory(p.join(home.path, '.claude', 'skills', 'security-audit'))
            .existsSync(),
        isTrue,
      );
    });

    test('leaves ~/.claude alone when run from \$HOME with CLAUDE_CONFIG_DIR',
        () {
      final otherAccount = p.join(home.path, '.claude', 'skills');
      _writeSkill(otherAccount, 'security-audit');
      SkillManifest.load(otherAccount)
        ..record(
          skill: 'security-audit',
          kind: 'audit',
          paths: const [ManifestPath(ManifestRoot.install, 'security-audit')],
        )
        ..save();

      removeManifestTrackedInstalls(
        home: home.path,
        projectRoot: home.path,
        environment: {'CLAUDE_CONFIG_DIR': p.join(home.path, '.claude-work')},
      );

      expect(
        Directory(p.join(otherAccount, 'security-audit')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(otherAccount, SkillManifest.fileName)).existsSync(),
        isTrue,
      );
    });

    test('finds the global Codex manifest under CODEX_HOME', () {
      final codexHome = p.join(home.path, 'custom-codex');
      final skills = p.join(codexHome, 'skills');
      _writeSkill(skills, 'security-audit');
      SkillManifest.load(skills)
        ..record(
          skill: 'security-audit',
          kind: 'audit',
          paths: const [ManifestPath(ManifestRoot.install, 'security-audit')],
        )
        ..save();

      final removed = removeManifestTrackedInstalls(
        home: home.path,
        projectRoot: project.path,
        environment: {'CODEX_HOME': codexHome},
      );

      expect(removed, isTrue);
      expect(Directory(p.join(skills, 'security-audit')).existsSync(), isFalse);
      expect(
          File(p.join(skills, SkillManifest.fileName)).existsSync(), isFalse);
    });

    test('removes a project-scoped install the home sweep cannot reach', () {
      seedClaudeSkill(project.path, 'security-audit');

      final removed = removeManifestTrackedInstalls(
        home: home.path,
        projectRoot: project.path,
      );

      expect(removed, isTrue);
      expect(
        Directory(
          p.join(project.path, '.claude', 'skills', 'security-audit'),
        ).existsSync(),
        isFalse,
        reason: 'project-scoped installs must be removed on uninstall',
      );
    });

    test('deletes the manifest file itself, leaving no bookkeeping behind', () {
      seedClaudeSkill(project.path, 'security-audit');
      final manifestPath = p.join(
        project.path,
        '.claude',
        'skills',
        SkillManifest.fileName,
      );
      expect(File(manifestPath).existsSync(), isTrue);

      removeManifestTrackedInstalls(
        home: home.path,
        projectRoot: project.path,
      );

      expect(File(manifestPath).existsSync(), isFalse);
    });

    test('never touches a skill absent from the manifest', () {
      seedClaudeSkill(project.path, 'security-audit');
      final mine = p.join(project.path, '.claude', 'skills', 'my-own-skill');
      _writeFile(p.join(mine, 'SKILL.md'), 'hand written');

      removeManifestTrackedInstalls(
        home: home.path,
        projectRoot: project.path,
      );

      expect(
        File(p.join(mine, 'SKILL.md')).readAsStringSync(),
        'hand written',
        reason: 'uninstall must only delete what the CLI recorded installing',
      );
    });

    test('clears both the global and the project scope in one pass', () {
      seedClaudeSkill(home.path, 'security-audit');
      seedClaudeSkill(project.path, 'flutter-health-audit');

      removeManifestTrackedInstalls(
        home: home.path,
        projectRoot: project.path,
      );

      expect(
        Directory(
          p.join(home.path, '.claude', 'skills', 'security-audit'),
        ).existsSync(),
        isFalse,
      );
      expect(
        Directory(
          p.join(project.path, '.claude', 'skills', 'flutter-health-audit'),
        ).existsSync(),
        isFalse,
      );
    });

    test('removes an Amp manifest left in ~/.amp before 3.2.17', () {
      final oldSkills = p.join(home.path, '.amp', 'skills');
      final oldRules = p.join(home.path, '.amp', 'somnio_rules');
      _writeFile(p.join(oldSkills, 'security_audit.md'));
      _writeFile(p.join(oldRules, 'security-audit', 'references', 'r.md'));
      SkillManifest.load(oldSkills)
        ..record(
          skill: 'security-audit',
          kind: 'audit',
          paths: const [
            ManifestPath(ManifestRoot.install, 'security_audit.md'),
            ManifestPath(ManifestRoot.rules, 'security-audit'),
          ],
        )
        ..save();

      final removed = removeManifestTrackedInstalls(
        home: home.path,
        projectRoot: project.path,
      );

      expect(removed, isTrue);
      expect(
        File(p.join(oldSkills, 'security_audit.md')).existsSync(),
        isFalse,
      );
      expect(
        Directory(p.join(oldRules, 'security-audit')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(oldSkills, SkillManifest.fileName)).existsSync(),
        isFalse,
      );
    });

    test('removes project installs from legacy folders', () {
      // Amp has no project location anymore; Windsurf and Copilot moved.
      for (final relative in [
        '.amp/skills',
        '.windsurf/workflows',
        '.copilot/agents',
      ]) {
        final dir = p.join(project.path, relative);
        _writeFile(p.join(dir, 'security_audit.md'));
        SkillManifest.load(dir)
          ..record(
            skill: 'security-audit',
            kind: 'audit',
            paths: const [
              ManifestPath(ManifestRoot.install, 'security_audit.md'),
            ],
          )
          ..save();
      }

      removeManifestTrackedInstalls(
        home: home.path,
        projectRoot: project.path,
      );

      for (final relative in [
        '.amp/skills',
        '.windsurf/workflows',
        '.copilot/agents',
      ]) {
        expect(
          File(p.join(project.path, relative, 'security_audit.md'))
              .existsSync(),
          isFalse,
          reason: relative,
        );
      }
    });

    test('returns false when nothing is recorded anywhere', () {
      expect(
        removeManifestTrackedInstalls(
          home: home.path,
          projectRoot: project.path,
        ),
        isFalse,
      );
    });
  });
}
