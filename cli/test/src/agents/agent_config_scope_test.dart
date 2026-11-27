import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/agents/agent_config.dart';
import 'package:somnio/src/utils/real_path.dart';
import 'package:test/test.dart';

void main() {
  group('supportsProjectScope', () {
    test('is true for a home-anchored installPath', () {
      const agent = AgentConfig(
        id: 'claude',
        displayName: 'Claude Code',
        installPath: '{home}/.claude/skills/{name}',
      );

      expect(agent.supportsProjectScope, isTrue);
    });

    test('is false for an installPath that is not home-anchored', () {
      const agent = AgentConfig(
        id: 'weird-agent',
        displayName: 'Weird Agent',
        installPath: '/opt/weird-agent/skills/{name}',
      );

      expect(agent.supportsProjectScope, isFalse);
    });

    test('is false for a globalOnly agent', () {
      const agent = AgentConfig(
        id: 'amazonq',
        displayName: 'Amazon Q',
        installPath: '{home}/.aws/amazonq/prompts',
        globalOnly: true,
      );

      expect(agent.supportsProjectScope, isFalse);
    });

    test('follows a home-anchored projectInstallPath', () {
      const agent = AgentConfig(
        id: 'x',
        displayName: 'X',
        installPath: '/opt/x/skills',
        projectInstallPath: '{home}/.x/skills',
      );

      expect(agent.supportsProjectScope, isTrue);
    });
  });

  group('resolvedScopedInstallPath', () {
    const agent = AgentConfig(
      id: 'claude',
      displayName: 'Claude Code',
      installPath: '{home}/.claude/skills/{name}',
    );

    test('InstallScope.global anchors at home', () {
      final resolved = agent.resolvedScopedInstallPath(
        scope: InstallScope.global,
        home: '/Users/me',
        projectRoot: '/Users/me/projects/app',
        name: 'security-audit',
      );

      expect(resolved, '/Users/me/.claude/skills/security-audit');
    });

    test('InstallScope.project anchors at the project root', () {
      final resolved = agent.resolvedScopedInstallPath(
        scope: InstallScope.project,
        home: '/Users/me',
        projectRoot: '/Users/me/projects/app',
        name: 'security-audit',
      );

      expect(
        resolved,
        '/Users/me/projects/app/.claude/skills/security-audit',
      );
    });
  });

  group('resolvedScopedExecutionRulesPath', () {
    const agentWithRulesPath = AgentConfig(
      id: 'cursor',
      displayName: 'Cursor',
      installPath: '{home}/.cursor/commands/{name}',
      executionRulesPath: '{home}/.cursor/somnio_rules/{name}',
    );

    test('InstallScope.global anchors at home', () {
      final resolved = agentWithRulesPath.resolvedScopedExecutionRulesPath(
        scope: InstallScope.global,
        home: '/Users/me',
        projectRoot: '/Users/me/projects/app',
        name: 'flutter',
      );

      expect(resolved, '/Users/me/.cursor/somnio_rules/flutter');
    });

    test('InstallScope.project anchors at the project root', () {
      final resolved = agentWithRulesPath.resolvedScopedExecutionRulesPath(
        scope: InstallScope.project,
        home: '/Users/me',
        projectRoot: '/Users/me/projects/app',
        name: 'flutter',
      );

      expect(
        resolved,
        '/Users/me/projects/app/.cursor/somnio_rules/flutter',
      );
    });

    test('falls back to installPath when executionRulesPath is null', () {
      const agentWithoutRulesPath = AgentConfig(
        id: 'claude',
        displayName: 'Claude Code',
        installPath: '{home}/.claude/skills/{name}',
      );

      final global = agentWithoutRulesPath.resolvedScopedExecutionRulesPath(
        scope: InstallScope.global,
        home: '/Users/me',
        projectRoot: '/Users/me/projects/app',
        name: 'security-audit',
      );
      final project = agentWithoutRulesPath.resolvedScopedExecutionRulesPath(
        scope: InstallScope.project,
        home: '/Users/me',
        projectRoot: '/Users/me/projects/app',
        name: 'security-audit',
      );

      expect(
        global,
        '/Users/me/.claude/skills/security-audit',
        reason: 'with no executionRulesPath, rules must resolve from the '
            'same template as installPath',
      );
      expect(
        project,
        '/Users/me/projects/app/.claude/skills/security-audit',
      );
    });
  });
  group('resolvedScopedLegacyInstallPath', () {
    const moved = AgentConfig(
      id: 'antigravity',
      displayName: 'Antigravity',
      installPath: '{home}/.gemini/config/skills',
      legacyInstallPath: '{home}/.gemini/antigravity',
      configHome: '{home}/.gemini',
      configHomeVariable: 'TEST_GEMINI_HOME',
    );

    test('anchors at home for the global scope', () {
      expect(
        moved.resolvedScopedLegacyInstallPath(
          scope: InstallScope.global,
          home: '/Users/me',
          projectRoot: '/Users/me/app',
        ),
        '/Users/me/.gemini/antigravity',
      );
    });

    test('anchors at the project root for the project scope', () {
      expect(
        moved.resolvedScopedLegacyInstallPath(
          scope: InstallScope.project,
          home: '/Users/me',
          projectRoot: '/Users/me/app',
        ),
        '/Users/me/app/.gemini/antigravity',
      );
    });

    test('is never relocated by the config-home variable', () {
      expect(
        moved.resolvedInstallPath(
          home: '/Users/me',
          environment: const {'TEST_GEMINI_HOME': '/custom'},
        ),
        '/custom/config/skills',
      );
      expect(
        moved.resolvedScopedLegacyInstallPath(
          scope: InstallScope.global,
          home: '/Users/me',
          projectRoot: '/Users/me/app',
        ),
        '/Users/me/.gemini/antigravity',
      );
    });

    test('is null for an agent that never moved', () {
      const agent = AgentConfig(
        id: 'claude',
        displayName: 'Claude Code',
        installPath: '{home}/.claude/skills',
      );

      expect(
        agent.resolvedScopedLegacyInstallPath(
          scope: InstallScope.global,
          home: '/Users/me',
          projectRoot: '/Users/me/app',
        ),
        isNull,
      );
    });
  });

  group('config-home override', () {
    const agent = AgentConfig(
      id: 'codex',
      displayName: 'Codex CLI',
      installPath: '{home}/.codex/skills',
      configHome: '{home}/.codex',
      configHomeVariable: 'CODEX_HOME',
      legacyExecutionRulesPath: '{home}/.codex/somnio_rules',
    );
    const environment = {'CODEX_HOME': '/opt/codex'};

    test('relocates the global install path', () {
      final resolved = agent.resolvedScopedInstallPath(
        scope: InstallScope.global,
        home: '/Users/me',
        projectRoot: '/Users/me/projects/app',
        environment: environment,
      );

      expect(resolved, '/opt/codex/skills');
    });

    test('keeps the legacy rules path where older releases wrote it', () {
      final resolved = agent.resolvedScopedExecutionRulesPath(
        scope: InstallScope.global,
        home: '/Users/me',
        projectRoot: '/Users/me/projects/app',
        environment: environment,
      );

      expect(resolved, '/Users/me/.codex/somnio_rules');
    });

    test('lists the default install path after the relocated one', () {
      expect(
        agent.resolvedGlobalInstallPaths(
          home: '/Users/me',
          environment: environment,
        ),
        ['/opt/codex/skills', '/Users/me/.codex/skills'],
      );
      expect(
        agent.resolvedGlobalInstallPaths(home: '/Users/me'),
        ['/Users/me/.codex/skills'],
      );
    });

    test('leaves the default install path out when it may be in use', () {
      const shared = AgentConfig(
        id: 'claude',
        displayName: 'Claude Code',
        installPath: '{home}/.claude/skills',
        configHome: '{home}/.claude',
        configHomeVariable: 'CLAUDE_CONFIG_DIR',
        cleansDefaultConfigHome: false,
      );

      expect(
        shared.resolvedGlobalInstallPaths(
          home: '/Users/me',
          environment: const {'CLAUDE_CONFIG_DIR': '/Users/me/.claude-work'},
        ),
        ['/Users/me/.claude-work/skills'],
      );
    });

    group('resolvedProtectedInstallPaths', () {
      late Directory home;

      setUp(() => home = Directory.systemTemp.createTempSync('protected_'));
      tearDown(() => home.deleteSync(recursive: true));

      const shared = AgentConfig(
        id: 'claude',
        displayName: 'Claude Code',
        installPath: '{home}/.claude/skills',
        configHome: '{home}/.claude',
        configHomeVariable: 'CLAUDE_CONFIG_DIR',
        cleansDefaultConfigHome: false,
      );

      test('lists the default location while the variable relocates it', () {
        expect(
          shared.resolvedProtectedInstallPaths(
            home: home.path,
            environment: {
              'CLAUDE_CONFIG_DIR': p.join(home.path, '.claude-work'),
            },
          ),
          [realPathOf(p.join(home.path, '.claude', 'skills'))],
        );
      });

      test('is empty without the variable or with cleanup allowed', () {
        expect(shared.resolvedProtectedInstallPaths(home: home.path), isEmpty);
        expect(
          agent.resolvedProtectedInstallPaths(
            home: home.path,
            environment: environment,
          ),
          isEmpty,
        );
      });

      test('is empty when the variable links to the default location', () {
        Directory(p.join(home.path, '.claude')).createSync();
        Link(p.join(home.path, '.claude-link'))
            .createSync(p.join(home.path, '.claude'));

        expect(
          shared.resolvedProtectedInstallPaths(
            home: home.path,
            environment: {
              'CLAUDE_CONFIG_DIR': p.join(home.path, '.claude-link'),
            },
          ),
          isEmpty,
        );
      });
    });

    test('is ignored for the project scope', () {
      final resolved = agent.resolvedScopedInstallPath(
        scope: InstallScope.project,
        home: '/Users/me',
        projectRoot: '/Users/me/projects/app',
        environment: environment,
      );

      expect(resolved, '/Users/me/projects/app/.codex/skills');
    });

    test('is ignored when the variable is unset or blank', () {
      for (final env in const [
        <String, String>{},
        {'CODEX_HOME': ''},
        {'CODEX_HOME': '   '},
      ]) {
        expect(
          agent.resolvedInstallPath(home: '/Users/me', environment: env),
          '/Users/me/.codex/skills',
          reason: '$env',
        );
      }
    });

    test('resolves the config home itself', () {
      expect(
        agent.resolvedConfigHome(home: '/Users/me', environment: environment),
        '/opt/codex',
      );
      expect(agent.resolvedConfigHome(home: '/Users/me'), '/Users/me/.codex');
      expect(
        const AgentConfig(id: 'x', displayName: 'X', installPath: '{home}/.x')
            .resolvedConfigHome(home: '/Users/me', environment: environment),
        isNull,
      );
    });

    test('does not apply without a configHome prefix', () {
      const noPrefix = AgentConfig(
        id: 'x',
        displayName: 'X',
        installPath: '{home}/.x/skills',
        configHomeVariable: 'CODEX_HOME',
      );

      expect(
        noPrefix.resolvedInstallPath(home: '/h', environment: environment),
        '/h/.x/skills',
      );
    });
  });

  group('projectInstallPath', () {
    const agent = AgentConfig(
      id: 'copilot',
      displayName: 'GitHub Copilot',
      installPath: '{home}/.copilot/skills',
      projectInstallPath: '{home}/.github/skills',
    );

    test('is used for the project scope', () {
      final resolved = agent.resolvedScopedInstallPath(
        scope: InstallScope.project,
        home: '/Users/me',
        projectRoot: '/Users/me/projects/app',
      );

      expect(resolved, '/Users/me/projects/app/.github/skills');
    });

    test('is not used for the global scope', () {
      final resolved = agent.resolvedScopedInstallPath(
        scope: InstallScope.global,
        home: '/Users/me',
        projectRoot: '/Users/me/projects/app',
      );

      expect(resolved, '/Users/me/.copilot/skills');
    });

    test('is never relocated by the config-home variable', () {
      const underConfigHome = AgentConfig(
        id: 'test-agent',
        displayName: 'Test Agent',
        installPath: '{home}/.config/test/skills',
        projectInstallPath: '{home}/.config/test/project-skills',
        configHome: '{home}/.config',
        configHomeVariable: 'TEST_CONFIG_HOME',
      );

      final resolved = underConfigHome.resolvedScopedInstallPath(
        scope: InstallScope.project,
        home: '/Users/me',
        projectRoot: '/Users/me/projects/app',
        environment: const {'TEST_CONFIG_HOME': '/custom'},
      );

      expect(resolved, '/Users/me/projects/app/.config/test/project-skills');
    });
  });

  group('resolvedProjectInstallPaths', () {
    test('lists the legacy location after the current one', () {
      const agent = AgentConfig(
        id: 'windsurf',
        displayName: 'Windsurf',
        installPath: '{home}/.codeium/windsurf/skills',
        projectInstallPath: '{home}/.windsurf/skills',
        legacyInstallPath: '{home}/.windsurf/workflows',
      );

      expect(
        agent.resolvedProjectInstallPaths(projectRoot: '/p'),
        ['/p/.windsurf/skills', '/p/.windsurf/workflows'],
      );
    });

    test('keeps the legacy location of a globalOnly agent removable', () {
      const amazonq = AgentConfig(
        id: 'amazonq',
        displayName: 'Amazon Q',
        installPath: '{home}/.aws/amazonq/prompts',
        globalOnly: true,
        legacyInstallPath: '{home}/.amazonq/prompts',
      );

      expect(
        amazonq.resolvedProjectInstallPaths(projectRoot: '/p'),
        ['/p/.amazonq/prompts'],
      );
    });

    test('is empty for an agent without any project location', () {
      const agent = AgentConfig(
        id: 'x',
        displayName: 'X',
        installPath: '{home}/.x/prompts',
        globalOnly: true,
      );

      expect(agent.resolvedProjectInstallPaths(projectRoot: '/p'), isEmpty);
    });
  });
}
