import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:somnio/src/agents/agent_config.dart';
import 'package:somnio/src/agents/agent_registry.dart';
import 'package:somnio/src/commands/skills_command.dart';
import 'package:somnio/src/content/skill_registry.dart';
import 'package:somnio/src/installers/agent_installer.dart';
import 'package:somnio/src/installers/skill_manifest.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

final _amazonq = AgentRegistry.findById('amazonq')!;
final _amp = AgentRegistry.findById('amp')!;
final _copilot = AgentRegistry.findById('copilot')!;
final _windsurf = AgentRegistry.findById('windsurf')!;

/// Registered skill names, so the manifests map back to the registry.
final _auditA = SkillRegistry.skills[0].name;
final _auditB = SkillRegistry.skills[1].name;
final _workflow = SkillRegistry.workflowSkills[0].name;

/// Records [skill] in the manifest at [dir], as AgentInstaller does.
void _seed(String dir, String skill, {String kind = 'audit'}) {
  Directory(dir).createSync(recursive: true);
  SkillManifest.load(dir)
    ..record(
      skill: skill,
      kind: kind,
      paths: [ManifestPath(ManifestRoot.install, skill)],
    )
    ..save();
}

/// The skill names a discovered update unit would refresh, sorted.
List<String> _names(SkillsUpdateUnit unit) => [
      for (final bundle in unit.selection.audit) bundle.name,
      for (final skill in unit.selection.workflow) skill.name,
    ]..sort();

void main() {
  group('SkillsUpdateSummary', () {
    late _MockLogger logger;
    late List<String> lines;

    setUp(() {
      logger = _MockLogger();
      lines = [];
      when(() => logger.info(any())).thenAnswer((invocation) {
        lines.add(invocation.positionalArguments.first as String);
      });
    });

    test('lists unique names sorted across locations', () {
      final summary = SkillsUpdateSummary()
        ..addLocation(
          label: 'Claude Code (global)',
          updated: ['security-audit', 'git-commit-format'],
          failed: [],
        )
        ..addLocation(
          label: 'Cursor (project)',
          updated: ['git-commit-format', 'angular-health-audit'],
          failed: [],
        );

      summary.print(logger);

      expect(lines, [
        '',
        'Updated skills (3):',
        '  - angular-health-audit',
        '  - git-commit-format',
        '  - security-audit',
      ]);
    });

    test('lists failed skills with their location', () {
      final summary = SkillsUpdateSummary()
        ..addLocation(
          label: 'Claude Code (global)',
          updated: ['security-audit'],
          failed: ['dora-metrics'],
        );

      summary.print(logger);

      expect(lines, [
        '',
        'Updated skills (1):',
        '  - security-audit',
        '',
        'Failed skills:',
        '  - dora-metrics — Claude Code (global)',
      ]);
    });

    test('prints the failures even when nothing was updated', () {
      final summary = SkillsUpdateSummary()
        ..addLocation(
          label: 'Claude Code (global)',
          updated: [],
          failed: ['dora-metrics'],
        );

      summary.print(logger);

      expect(lines,
          ['', 'Failed skills:', '  - dora-metrics — Claude Code (global)']);
    });

    test('prints nothing when there is nothing to report', () {
      SkillsUpdateSummary().print(logger);

      expect(lines, isEmpty);
    });
  });

  group('somnio skills update (process)', () {
    late Directory home;
    late String workDir;

    setUp(() {
      home = Directory.systemTemp.createTempSync('skills_update_test_');
      workDir = p.join(home.path, 'project');
      Directory(workDir).createSync(recursive: true);
    });

    tearDown(() {
      // Restore write access so cleanup can delete locked fixtures.
      final locked = Directory(
        p.join(home.path, '.claude', 'skills', 'git-commit-format'),
      );
      if (locked.existsSync()) {
        Process.runSync('chmod', ['-R', 'u+w', locked.path]);
      }
      if (home.existsSync()) home.deleteSync(recursive: true);
    });

    void seedManifest(Map<String, String> skillKinds) {
      final dir = Directory(p.join(home.path, '.claude', 'skills'))
        ..createSync(recursive: true);
      File(p.join(dir.path, '.somnio-skills.json')).writeAsStringSync(
        jsonEncode({
          'version': 1,
          'skills': {
            for (final e in skillKinds.entries)
              e.key: {
                'kind': e.value,
                'paths': [
                  {'root': 'install', 'path': e.key},
                ],
              },
          },
        }),
      );
    }

    Future<ProcessResult> runSkills(
      List<String> args, {
      String? workingDirectory,
      String claudeConfigDir = '',
    }) =>
        Process.run(
          Platform.resolvedExecutable,
          [p.absolute('bin', 'somnio.dart'), 'skills', ...args],
          workingDirectory: workingDirectory ?? workDir,
          environment: {
            'HOME': home.path,
            'USERPROFILE': home.path,
            // Blank by default, so a caller's Claude config dir never
            // relocates the install out of the fake home.
            'CLAUDE_CONFIG_DIR': claudeConfigDir,
            // Keep pub reading the real cache instead of creating one under
            // the fake home.
            'PUB_CACHE': _pubCache,
          },
        );

    Future<ProcessResult> runUpdate(List<String> args) =>
        runSkills(['update', '--agent', 'claude', ...args]);

    test('prints the updated skill names after the progress lines', () async {
      seedManifest({
        'security-audit': 'audit',
        'git-commit-format': 'workflow',
      });

      final result = await runUpdate([]);

      expect(result.exitCode, 0);
      expect(
        result.stdout,
        contains(
          'Updated skills (2):\n  - git-commit-format\n  - security-audit',
        ),
      );
      expect(result.stdout, contains('2 skills updated'));
    });

    group('run from \$HOME with CLAUDE_CONFIG_DIR set', () {
      // The project scope then resolves to ~/.claude/skills, which belongs
      // to another Claude Code account.
      late String otherAccount;
      late String manifest;

      setUp(() {
        otherAccount = p.join(home.path, '.claude', 'skills');
        Directory(p.join(otherAccount, 'security-audit'))
            .createSync(recursive: true);
        seedManifest({'security-audit': 'audit'});
        manifest = File(p.join(otherAccount, '.somnio-skills.json'))
            .readAsStringSync();
      });

      void expectOtherAccountUntouched() {
        expect(
          Directory(p.join(otherAccount, 'security-audit')).listSync(),
          isEmpty,
        );
        expect(
          File(p.join(otherAccount, '.somnio-skills.json')).readAsStringSync(),
          manifest,
        );
      }

      test('skills update leaves ~/.claude alone', () async {
        final result = await runSkills(
          ['update', '--agent', 'claude'],
          workingDirectory: home.path,
          claudeConfigDir: p.join(home.path, '.claude-work'),
        );

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expectOtherAccountUntouched();
      });

      test('skills remove --project leaves ~/.claude alone', () async {
        final result = await runSkills(
          ['remove', '--project', '--agent', 'claude', '--force'],
          workingDirectory: home.path,
          claudeConfigDir: p.join(home.path, '.claude-work'),
        );

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expectOtherAccountUntouched();
      });
    });

    test('--verbose lists the updated names under the Location line', () async {
      seedManifest({'git-commit-format': 'workflow'});

      final result = await runUpdate(['--verbose']);

      expect(
        result.stdout,
        matches(RegExp(r'Location: .*\n    - git-commit-format\n')),
      );
    });

    test('omits per-location names without --verbose', () async {
      seedManifest({'git-commit-format': 'workflow'});

      final result = await runUpdate([]);

      expect(result.stdout, isNot(contains('    - git-commit-format')));
    });

    test('prints no summary when nothing is installed', () async {
      final result = await runUpdate([]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No somnio-installed skills found.'));
      expect(result.stdout, isNot(contains('Updated skills')));
    });

    test('prints no summary in --dry-run', () async {
      seedManifest({'git-commit-format': 'workflow'});

      final result = await runUpdate(['--dry-run']);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('Would refresh:'));
      expect(result.stdout, isNot(contains('Updated skills')));
    });

    test(
      'lists a failed skill with its location and exits non-zero',
      () async {
        seedManifest({'git-commit-format': 'workflow'});
        // A read-only skill directory makes the prune before the rewrite fail.
        final skillDir = Directory(
          p.join(home.path, '.claude', 'skills', 'git-commit-format'),
        )..createSync(recursive: true);
        File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('old');
        Process.runSync('chmod', ['-R', 'a-w', skillDir.path]);

        final result = await runUpdate([]);

        expect(result.exitCode, isNot(0));
        expect(
          result.stdout,
          contains(
              'Failed skills:\n  - git-commit-format — Claude Code (global)'),
        );
      },
      skip: Platform.isWindows || _isRoot()
          ? 'needs POSIX permissions and a non-root user'
          : false,
    );
  });

  late Directory home;
  late Directory project;

  setUp(() {
    home = Directory.systemTemp.createTempSync('skills_command_home_');
    project = Directory.systemTemp.createTempSync('skills_command_proj_');
  });

  tearDown(() {
    if (home.existsSync()) home.deleteSync(recursive: true);
    if (project.existsSync()) project.deleteSync(recursive: true);
  });

  /// Folders a project-scope lookup from the home directory would resolve
  /// to, none of which a global install creates.
  List<String> strayProjectFolders() => [
        p.join(home.path, '.agents', 'skills'),
        p.join(home.path, '.github', 'skills'),
        p.join(home.path, '.windsurf', 'skills'),
      ];

  group('discoverSkillsUpdateUnits', () {
    test('run from home refreshes each location once, as global', () {
      final amazonqLegacy = p.join(home.path, '.amazonq', 'prompts');
      final windsurfLegacy = p.join(home.path, '.windsurf', 'workflows');
      final copilotGlobal = p.join(home.path, '.copilot', 'skills');
      final ampGlobal = p.join(home.path, '.config', 'amp', 'skills');
      // Amp's legacy folder, global and project alike from home.
      final ampLegacy = p.join(home.path, '.amp', 'skills');
      final rooLegacy = p.join(home.path, '.roo', 'rules');
      final kiloLegacy = p.join(home.path, '.kilocode', 'rules');
      _seed(amazonqLegacy, _auditA);
      _seed(windsurfLegacy, _auditA);
      _seed(copilotGlobal, _auditA);
      _seed(ampLegacy, _auditA);
      _seed(rooLegacy, _auditA);
      _seed(kiloLegacy, _auditA);
      final warnings = <String>[];

      final units = discoverSkillsUpdateUnits(
        agents: AgentRegistry.installableAgents,
        home: home.path,
        projectRoot: home.path,
        onWarning: warnings.add,
      );

      // `<home>/.amazonq/prompts` is both Amazon Q's legacy global folder and
      // its project folder from home: refreshing it as a project install
      // would write the prompts back into the folder being migrated.
      expect(
        [for (final u in units) (u.agent.id, u.scope, u.location)],
        unorderedEquals([
          (
            'amazonq',
            InstallScope.global,
            p.join(home.path, '.aws', 'amazonq', 'prompts'),
          ),
          (
            'windsurf',
            InstallScope.global,
            p.join(home.path, '.codeium', 'windsurf', 'skills'),
          ),
          ('copilot', InstallScope.global, copilotGlobal),
          ('amp', InstallScope.global, ampGlobal),
          ('roo', InstallScope.global, p.join(home.path, '.roo', 'skills')),
          (
            'kilocode',
            InstallScope.global,
            p.join(home.path, '.kilocode', 'skills'),
          ),
        ]),
      );
      expect(warnings, isEmpty);
      for (final dir in strayProjectFolders()) {
        expect(Directory(dir).existsSync(), isFalse, reason: dir);
      }
    });

    test('warns about skills a release before the manifest left behind', () {
      final rule = File(p.join(home.path, '.roo', 'rules', 'security_audit.md'))
        ..createSync(recursive: true)
        ..writeAsStringSync('# Security Audit\n\n> Audits a project.\n');
      final warnings = <String>[];

      final units = discoverSkillsUpdateUnits(
        agents: [AgentRegistry.findById('roo')!],
        home: home.path,
        projectRoot: project.path,
        onWarning: warnings.add,
      );

      expect(units, isEmpty);
      expect(warnings, [
        allOf(contains(rule.parent.path), contains('security_audit.md')),
      ]);
    });

    test('merges the current and legacy manifests per agent and scope', () {
      final globalDir = p.join(home.path, '.codeium', 'windsurf', 'skills');
      final globalLegacy = p.join(home.path, '.windsurf', 'workflows');
      final projectDir = p.join(project.path, '.windsurf', 'skills');
      final projectLegacy = p.join(project.path, '.windsurf', 'workflows');
      _seed(globalLegacy, _auditA);
      _seed(globalLegacy, _auditB);
      _seed(globalDir, _auditB);
      _seed(globalDir, _workflow, kind: 'workflow');
      _seed(projectLegacy, _auditA);
      _seed(projectDir, _auditB);

      final units = discoverSkillsUpdateUnits(
        agents: [_windsurf],
        home: home.path,
        projectRoot: project.path,
      );

      expect(units, hasLength(2));
      final global = units.singleWhere((u) => u.scope == InstallScope.global);
      final local = units.singleWhere((u) => u.scope == InstallScope.project);
      expect(global.location, globalDir);
      expect(_names(global), [_auditA, _auditB, _workflow]..sort());
      expect(local.location, projectDir);
      expect(_names(local), [_auditA, _auditB]..sort());
    });

    test('warns about and skips a legacy entry no longer shipped', () {
      _seed(p.join(home.path, '.windsurf', 'workflows'), 'retired-skill');
      _seed(p.join(home.path, '.windsurf', 'workflows'), _auditA);
      final warnings = <String>[];

      final units = discoverSkillsUpdateUnits(
        agents: [_windsurf],
        home: home.path,
        projectRoot: project.path,
        onWarning: warnings.add,
      );

      expect(_names(units.single), [_auditA]);
      expect(warnings, [contains('retired-skill is no longer shipped')]);
    });

    test('warns about a global-only agent\'s legacy project folder', () {
      final legacyProject = p.join(project.path, '.amp', 'skills');
      _seed(legacyProject, _auditA);
      final warnings = <String>[];

      final units = discoverSkillsUpdateUnits(
        agents: [_amp],
        home: home.path,
        projectRoot: project.path,
        onWarning: warnings.add,
      );

      expect(units, isEmpty);
      expect(warnings, [contains(legacyProject)]);
    });

    test('warns about a legacy project folder linked to dotfiles', () {
      final dotfiles = p.join(project.path, 'dotfiles', 'amp');
      _seed(p.join(dotfiles, 'skills'), _auditA);
      Link(p.join(project.path, '.amp')).createSync(dotfiles);
      final warnings = <String>[];

      discoverSkillsUpdateUnits(
        agents: [_amp],
        home: home.path,
        projectRoot: project.path,
        onWarning: warnings.add,
      );

      expect(warnings, [contains(p.join(project.path, '.amp', 'skills'))]);
    });

    test(
        'does not warn about a legacy project folder linked to another '
        'agent\'s', () {
      _seed(p.join(project.path, '.claude', 'skills'), _auditA);
      Link(p.join(project.path, '.amp'))
          .createSync(p.join(project.path, '.claude'));
      final warnings = <String>[];

      discoverSkillsUpdateUnits(
        agents: [_amp],
        home: home.path,
        projectRoot: project.path,
        onWarning: warnings.add,
      );

      expect(warnings, isEmpty);
    });

    test(
        'does not warn about a legacy project folder linked to the agent\'s '
        'global one', () {
      // `<project>/.amp -> ~/.config/amp`: Amp reads those skills globally.
      final global = p.join(home.path, '.config', 'amp');
      _seed(p.join(global, 'skills'), _auditA);
      Link(p.join(project.path, '.amp')).createSync(global);
      final warnings = <String>[];

      discoverSkillsUpdateUnits(
        agents: [_amp],
        home: home.path,
        projectRoot: project.path,
        onWarning: warnings.add,
      );

      expect(warnings, isEmpty);
    });

    test(
        'does not warn about another agent\'s project folder linked to the '
        'legacy one', () {
      _seed(p.join(project.path, '.amp', 'skills'), _auditA);
      Link(p.join(project.path, '.claude'))
          .createSync(p.join(project.path, '.amp'));
      final warnings = <String>[];

      discoverSkillsUpdateUnits(
        agents: [_amp],
        home: home.path,
        projectRoot: project.path,
        onWarning: warnings.add,
      );

      expect(warnings, isEmpty);
    });

    group('legacy folder', () {
      late String claudeSkills;

      setUp(() {
        claudeSkills = p.join(home.path, '.claude', 'skills');
        _seed(claudeSkills, _auditA);
      });

      test('is migrated when it is a real folder', () {
        _seed(p.join(home.path, '.amp', 'skills'), _auditA);

        final units = discoverSkillsUpdateUnits(
          agents: [_amp],
          home: home.path,
          projectRoot: project.path,
        );

        expect(units.single.agent, _amp);
        expect(_names(units.single), [_auditA]);
      });

      test('is migrated when it is linked to dotfiles', () {
        // e.g. GNU stow: `~/.amp -> ~/dotfiles/amp` is still Amp's.
        final dotfiles = p.join(home.path, 'dotfiles', 'amp');
        _seed(p.join(dotfiles, 'skills'), _auditB);
        Link(p.join(home.path, '.amp')).createSync(dotfiles);

        final units = discoverSkillsUpdateUnits(
          agents: [_amp],
          home: home.path,
          projectRoot: project.path,
        );

        expect(units.single.agent, _amp);
        expect(_names(units.single), [_auditB]);
      });

      test('is skipped when it links to another agent\'s folder', () {
        Directory(p.join(home.path, '.amp')).createSync();
        Link(p.join(home.path, '.amp', 'skills')).createSync(claudeSkills);

        final units = discoverSkillsUpdateUnits(
          agents: [_amp],
          home: home.path,
          projectRoot: project.path,
        );

        expect(units, isEmpty);
      });

      test('is skipped when its parent links to another agent\'s', () {
        Link(p.join(home.path, '.amp'))
            .createSync(p.join(home.path, '.claude'));

        final units = discoverSkillsUpdateUnits(
          agents: [_amp],
          home: home.path,
          projectRoot: project.path,
        );

        expect(units, isEmpty);
      });

      test('is skipped when another agent\'s folder links to it', () {
        // `~/.claude -> ~/.amp`: `~/.amp/skills` is a real folder, but it
        // is Claude Code's install.
        final amp = p.join(home.path, '.amp');
        Directory(p.join(home.path, '.claude')).renameSync(amp);
        Link(p.join(home.path, '.claude')).createSync(amp);

        final units = discoverSkillsUpdateUnits(
          agents: [_amp],
          home: home.path,
          projectRoot: project.path,
        );

        expect(units, isEmpty);
      });

      test('is skipped when it links to the current folder', () {
        // `~/.amp -> ~/.config/amp`: the legacy folder is the current one,
        // whose skills must not be migrated onto themselves.
        final current = p.join(home.path, '.config', 'amp');
        _seed(p.join(current, 'skills'), _auditB);
        Link(p.join(home.path, '.amp')).createSync(current);

        expect(
          AgentInstaller.ownLegacyInstallDir(
            _amp,
            scope: InstallScope.global,
            home: home.path,
            projectRoot: project.path,
          ),
          isNull,
        );
        final units = discoverSkillsUpdateUnits(
          agents: [_amp],
          home: home.path,
          projectRoot: project.path,
        );
        expect(_names(units.single), [_auditB]);
      });
    });
  });

  group('ownLegacyInstallDir', () {
    final moved = [
      for (final agent in AgentRegistry.installableAgents)
        if (agent.legacyInstallPath != null) agent,
    ];

    test('accepts every registered legacy folder, run from home', () {
      expect(moved, isNotEmpty);
      for (final agent in moved) {
        expect(
          AgentInstaller.ownLegacyInstallDir(
            agent,
            scope: InstallScope.global,
            home: home.path,
            projectRoot: home.path,
          ),
          isNotNull,
          reason: agent.id,
        );
      }
    });

    test('accepts every registered legacy project folder but a current one',
        () {
      for (final agent in moved) {
        final legacy = AgentInstaller.ownLegacyInstallDir(
          agent,
          scope: InstallScope.project,
          home: home.path,
          projectRoot: project.path,
        );
        // Amazon Q's project prompts never moved: its legacy project folder
        // is its current one, which ownProjectInstallDirs keeps anyway.
        expect(
          legacy,
          agent == _amazonq ? isNull : isNotNull,
          reason: agent.id,
        );
      }
    });
  });

  group('discoverSkillsRemoveCandidates', () {
    test('--project finds the legacy folder of a global-only agent', () {
      final legacyProject = p.join(project.path, '.amp', 'skills');
      _seed(legacyProject, _auditA);
      _seed(p.join(home.path, '.config', 'amp', 'skills'), _auditB);

      final candidates = discoverSkillsRemoveCandidates(
        agents: [_amp],
        scopes: [InstallScope.project],
        home: home.path,
        projectRoot: project.path,
      );

      expect(
        [
          for (final c in candidates)
            (c.entry.skill, c.scope, c.manifest.directory),
        ],
        [(_auditA, InstallScope.project, legacyProject)],
      );
    });

    test('--global lists the current and legacy folders', () {
      final current = p.join(home.path, '.copilot', 'skills');
      final legacy = p.join(home.path, '.copilot', 'agents');
      _seed(current, _auditA);
      _seed(legacy, _auditB);

      final candidates = discoverSkillsRemoveCandidates(
        agents: [_copilot],
        scopes: [InstallScope.global],
        home: home.path,
        projectRoot: project.path,
      );

      expect(
        [for (final c in candidates) (c.entry.skill, c.manifest.directory)],
        unorderedEquals([(_auditA, current), (_auditB, legacy)]),
      );
    });

    test('run from home reads a shared folder once, as global', () {
      final amazonqLegacy = p.join(home.path, '.amazonq', 'prompts');
      final windsurfLegacy = p.join(home.path, '.windsurf', 'workflows');
      final rooLegacy = p.join(home.path, '.roo', 'rules');
      _seed(amazonqLegacy, _auditA);
      _seed(windsurfLegacy, _auditA);
      _seed(rooLegacy, _auditA);

      final candidates = discoverSkillsRemoveCandidates(
        agents: AgentRegistry.installableAgents,
        scopes: [InstallScope.global, InstallScope.project],
        home: home.path,
        projectRoot: home.path,
      );

      expect(
        [
          for (final c in candidates)
            (c.agent.id, c.scope, c.manifest.directory),
        ],
        unorderedEquals([
          ('amazonq', InstallScope.global, amazonqLegacy),
          ('windsurf', InstallScope.global, windsurfLegacy),
          ('roo', InstallScope.global, rooLegacy),
        ]),
      );
      for (final dir in strayProjectFolders()) {
        expect(Directory(dir).existsSync(), isFalse, reason: dir);
      }
    });

    test('run from home lists a dotfiles-linked folder once, as global', () {
      // Amazon Q's global legacy folder is its current project one: both
      // scopes agree on it however `~/.amazonq` is linked.
      final dotfiles = p.join(home.path, 'dotfiles', 'amazonq');
      _seed(p.join(dotfiles, 'prompts'), _auditA);
      Link(p.join(home.path, '.amazonq')).createSync(dotfiles);

      for (final scopes in [
        [InstallScope.global],
        [InstallScope.project],
        [InstallScope.global, InstallScope.project],
      ]) {
        expect(
          [
            for (final c in discoverSkillsRemoveCandidates(
              agents: [_amazonq],
              scopes: scopes,
              home: home.path,
              projectRoot: home.path,
            ))
              (c.entry.skill, c.scope),
          ],
          [(_auditA, scopes.first)],
          reason: '$scopes',
        );
      }
    });

    group('legacy folder', () {
      /// What remove would delete, as (skill, scope, manifest folder).
      List<(String, InstallScope, String)> discover(
        AgentConfig agent,
        InstallScope scope,
      ) =>
          [
            for (final c in discoverSkillsRemoveCandidates(
              agents: [agent],
              scopes: [scope],
              home: home.path,
              projectRoot: project.path,
            ))
              (c.entry.skill, c.scope, c.manifest.directory),
          ];

      group('--global', () {
        late String claudeSkills;

        setUp(() {
          claudeSkills = p.join(home.path, '.claude', 'skills');
          _seed(claudeSkills, _auditA);
        });

        test('is found when it is a real folder', () {
          final legacy = p.join(home.path, '.amp', 'skills');
          _seed(legacy, _auditB);

          expect(
            discover(_amp, InstallScope.global),
            [(_auditB, InstallScope.global, legacy)],
          );
        });

        test('is found when it is linked to dotfiles', () {
          final dotfiles = p.join(home.path, 'dotfiles', 'amp');
          _seed(p.join(dotfiles, 'skills'), _auditB);
          Link(p.join(home.path, '.amp')).createSync(dotfiles);

          expect(
            discover(_amp, InstallScope.global),
            [
              (
                _auditB,
                InstallScope.global,
                p.join(home.path, '.amp', 'skills')
              )
            ],
          );
        });

        test('is skipped when it links to another agent\'s folder', () {
          Directory(p.join(home.path, '.amp')).createSync();
          Link(p.join(home.path, '.amp', 'skills')).createSync(claudeSkills);

          expect(discover(_amp, InstallScope.global), isEmpty);
        });

        test('is skipped when its parent links to another agent\'s', () {
          Link(p.join(home.path, '.amp'))
              .createSync(p.join(home.path, '.claude'));

          expect(discover(_amp, InstallScope.global), isEmpty);
        });

        test('is skipped when another agent\'s folder links to it', () {
          final amp = p.join(home.path, '.amp');
          Directory(p.join(home.path, '.claude')).renameSync(amp);
          Link(p.join(home.path, '.claude')).createSync(amp);

          expect(discover(_amp, InstallScope.global), isEmpty);
        });

        test('is skipped when it holds another agent\'s folder', () {
          // Pruning a recorded skill folder there could reach Claude Code's.
          _seed(p.join(home.path, '.claude'), _auditB);
          Directory(p.join(home.path, '.amp')).createSync();
          Link(p.join(home.path, '.amp', 'skills'))
              .createSync(p.join(home.path, '.claude'));

          expect(discover(_amp, InstallScope.global), isEmpty);
        });

        test('is skipped when it lies inside another agent\'s folder', () {
          final nested = p.join(claudeSkills, 'nested');
          _seed(nested, _auditB);
          Directory(p.join(home.path, '.amp')).createSync();
          Link(p.join(home.path, '.amp', 'skills')).createSync(nested);

          expect(discover(_amp, InstallScope.global), isEmpty);
        });

        test('is skipped when it links to a relocated agent\'s folder', () {
          // CODEX_HOME moves Codex's skills; the legacy folder is them.
          final codexHome = p.join(home.path, 'codex-home');
          _seed(p.join(codexHome, 'skills'), _auditB);
          Link(p.join(home.path, '.amp')).createSync(codexHome);

          expect(
            discoverSkillsRemoveCandidates(
              agents: [_amp],
              scopes: [InstallScope.global],
              home: home.path,
              projectRoot: project.path,
              environment: {'CODEX_HOME': codexHome},
            ),
            isEmpty,
          );
        });

        test('is skipped when its rules folder is another agent\'s', () {
          // `~/.amp -> ~/.cursor`: `.amp/skills` is no agent's folder, but
          // Amp's old rules resolve into Cursor's `somnio_rules`.
          final cursor = p.join(home.path, '.cursor');
          Directory(p.join(cursor, 'somnio_rules', _auditB))
              .createSync(recursive: true);
          Directory(p.join(cursor, 'skills')).createSync(recursive: true);
          SkillManifest.load(p.join(cursor, 'skills'))
            ..record(
              skill: _auditB,
              kind: 'audit',
              paths: [ManifestPath(ManifestRoot.rules, _auditB)],
            )
            ..save();
          Link(p.join(home.path, '.amp')).createSync(cursor);

          expect(discover(_amp, InstallScope.global), isEmpty);
        });

        test('is found when run from a project inside it', () {
          // Every project folder lies inside the legacy one then.
          final legacy = p.join(home.path, '.amp', 'skills');
          _seed(legacy, _auditB);
          final inside = p.join(legacy, 'work');
          Directory(inside).createSync();

          expect(
            [
              for (final c in discoverSkillsRemoveCandidates(
                agents: [_amp],
                scopes: [InstallScope.global],
                home: home.path,
                projectRoot: inside,
              ))
                (c.entry.skill, c.manifest.directory),
            ],
            [(_auditB, legacy)],
          );
        });
      });

      group('--project', () {
        late String claudeSkills;

        setUp(() {
          claudeSkills = p.join(project.path, '.claude', 'skills');
          _seed(claudeSkills, _auditA);
        });

        test('is found when it is a real folder', () {
          final legacy = p.join(project.path, '.amp', 'skills');
          _seed(legacy, _auditB);

          expect(
            discover(_amp, InstallScope.project),
            [(_auditB, InstallScope.project, legacy)],
          );
        });

        test('is found when it is linked to dotfiles', () {
          final dotfiles = p.join(project.path, 'dotfiles', 'amp');
          _seed(p.join(dotfiles, 'skills'), _auditB);
          Link(p.join(project.path, '.amp')).createSync(dotfiles);

          expect(
            discover(_amp, InstallScope.project),
            [
              (
                _auditB,
                InstallScope.project,
                p.join(project.path, '.amp', 'skills'),
              ),
            ],
          );
        });

        test('is skipped when it links to another agent\'s folder', () {
          Directory(p.join(project.path, '.amp')).createSync();
          Link(p.join(project.path, '.amp', 'skills')).createSync(claudeSkills);

          expect(discover(_amp, InstallScope.project), isEmpty);
        });

        test('is skipped when its parent links to another agent\'s', () {
          Link(p.join(project.path, '.amp'))
              .createSync(p.join(project.path, '.claude'));

          expect(discover(_amp, InstallScope.project), isEmpty);
        });

        test('is skipped when another agent\'s folder links to it', () {
          final amp = p.join(project.path, '.amp');
          Directory(p.join(project.path, '.claude')).renameSync(amp);
          Link(p.join(project.path, '.claude')).createSync(amp);

          expect(discover(_amp, InstallScope.project), isEmpty);
        });

        test('is skipped when it links to the agent\'s own global folder', () {
          // `<project>/.amp -> ~/.config/amp`: these are Amp's global
          // skills, which `--project` must not delete.
          final global = p.join(home.path, '.config', 'amp');
          _seed(p.join(global, 'skills'), _auditB);
          Link(p.join(project.path, '.amp')).createSync(global);

          expect(discover(_amp, InstallScope.project), isEmpty);
        });

        test('is skipped when it links to another agent\'s global folder', () {
          final globalClaude = p.join(home.path, '.claude', 'skills');
          _seed(globalClaude, _auditB);
          Directory(p.join(project.path, '.amp')).createSync();
          Link(p.join(project.path, '.amp', 'skills')).createSync(globalClaude);

          expect(discover(_amp, InstallScope.project), isEmpty);
        });

        test('is skipped without hiding the current project folder', () {
          final current = p.join(project.path, '.windsurf', 'skills');
          _seed(current, _auditB);
          Link(p.join(project.path, '.windsurf', 'workflows'))
              .createSync(claudeSkills);

          expect(
            discover(_windsurf, InstallScope.project),
            [(_auditB, InstallScope.project, current)],
          );
        });

        test('keeps a current project folder that is also the legacy one', () {
          // Amazon Q's project prompts never moved: `.amazonq/prompts` is
          // both, so a symlinked `.amazonq` is still its own install.
          final elsewhere = p.join(project.path, 'elsewhere');
          _seed(p.join(elsewhere, 'prompts'), _auditB);
          Link(p.join(project.path, '.amazonq')).createSync(elsewhere);

          expect(
            discover(_amazonq, InstallScope.project),
            [
              (
                _auditB,
                InstallScope.project,
                p.join(project.path, '.amazonq', 'prompts'),
              ),
            ],
          );
        });
      });
    });
  });
}

final String _pubCache = Platform.environment['PUB_CACHE'] ??
    p.join(
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '',
      '.pub-cache',
    );

bool _isRoot() =>
    !Platform.isWindows &&
    (Process.runSync('id', ['-u']).stdout as String).trim() == '0';
