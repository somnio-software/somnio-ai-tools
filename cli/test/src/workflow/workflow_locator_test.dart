import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/workflow/workflow_locator.dart';
import 'package:test/test.dart';

void main() {
  group('WorkflowLocator', () {
    group('isValidName', () {
      test('accepts valid kebab-case names', () {
        expect(WorkflowLocator.isValidName('my-workflow'), isTrue);
        expect(WorkflowLocator.isValidName('dependency-cleanup'), isTrue);
        expect(WorkflowLocator.isValidName('test'), isTrue);
        expect(WorkflowLocator.isValidName('a'), isTrue);
        expect(WorkflowLocator.isValidName('test123'), isTrue);
        expect(WorkflowLocator.isValidName('my-test-3'), isTrue);
      });

      test('rejects invalid names', () {
        expect(WorkflowLocator.isValidName('My-Workflow'), isFalse);
        expect(WorkflowLocator.isValidName('my_workflow'), isFalse);
        expect(WorkflowLocator.isValidName('my workflow'), isFalse);
        expect(WorkflowLocator.isValidName(''), isFalse);
        expect(WorkflowLocator.isValidName('123-abc'), isFalse);
        expect(WorkflowLocator.isValidName('-start'), isFalse);
        expect(WorkflowLocator.isValidName('end-'), isFalse);
        expect(WorkflowLocator.isValidName('double--dash'), isFalse);
      });
    });
  });

  group('WorkflowLocation', () {
    test('contextPath joins correctly', () {
      const loc = WorkflowLocation(
        path: '/test/workflows/my-wf',
        scope: WorkflowScope.project,
        name: 'my-wf',
      );
      expect(loc.contextPath, '/test/workflows/my-wf/context.md');
    });

    test('progressPath joins correctly', () {
      const loc = WorkflowLocation(
        path: '/test/workflows/my-wf',
        scope: WorkflowScope.project,
        name: 'my-wf',
      );
      expect(loc.progressPath, '/test/workflows/my-wf/progress.json');
    });

    test('outputsDir joins correctly', () {
      const loc = WorkflowLocation(
        path: '/test/workflows/my-wf',
        scope: WorkflowScope.project,
        name: 'my-wf',
      );
      expect(loc.outputsDir, '/test/workflows/my-wf/outputs');
    });

    test('configPath maps agent correctly', () {
      const loc = WorkflowLocation(
        path: '/test/workflows/my-wf',
        scope: WorkflowScope.project,
        name: 'my-wf',
      );
      expect(
        loc.configPath('claude'),
        '/test/workflows/my-wf/config.claudecode.json',
      );
      expect(
        loc.configPath('cursor'),
        '/test/workflows/my-wf/config.cursor.json',
      );
    });

    test('outputPath generates correct output file path', () {
      const loc = WorkflowLocation(
        path: '/test/workflows/my-wf',
        scope: WorkflowScope.project,
        name: 'my-wf',
      );
      expect(
        loc.outputPath('01-analyze-deps.md'),
        '/test/workflows/my-wf/outputs/01-analyze-deps-output.md',
      );
    });

    test('configPath maps gemini/antigravity/codex correctly', () {
      const loc = WorkflowLocation(
        path: '/test/workflows/my-wf',
        scope: WorkflowScope.project,
        name: 'my-wf',
      );
      expect(
        loc.configPath('gemini'),
        '/test/workflows/my-wf/config.gemini.json',
      );
      expect(
        loc.configPath('antigravity'),
        '/test/workflows/my-wf/config.gemini.json',
      );
      expect(
        loc.configPath('codex'),
        '/test/workflows/my-wf/config.codex.json',
      );
    });

    test('configPath falls back to config.<agentId>.json for unknown agent',
        () {
      const loc = WorkflowLocation(
        path: '/test/workflows/my-wf',
        scope: WorkflowScope.global,
        name: 'my-wf',
      );
      expect(
        loc.configPath('windsurf'),
        '/test/workflows/my-wf/config.windsurf.json',
      );
    });

    test('stepPath joins the file name onto the workflow directory', () {
      const loc = WorkflowLocation(
        path: '/test/workflows/my-wf',
        scope: WorkflowScope.project,
        name: 'my-wf',
      );
      expect(loc.stepPath('01-step.md'), '/test/workflows/my-wf/01-step.md');
    });
  });

  // ---------------------------------------------------------------------------
  // Path helpers + find + listAll + createWorkflowDir (filesystem-backed)
  // ---------------------------------------------------------------------------
  group('filesystem-backed', () {
    late Directory tmpProject;

    setUp(() {
      tmpProject = Directory.systemTemp.createTempSync('somnio_wfloc_');
      addTearDown(() => tmpProject.deleteSync(recursive: true));
    });

    /// Creates `.somnio/workflows/<name>/context.md` under [tmpProject].
    void seedWorkflow(String name) {
      final dir = Directory(
        p.join(tmpProject.path, '.somnio', 'workflows', name),
      )..createSync(recursive: true);
      File(p.join(dir.path, 'context.md')).writeAsStringSync('# ctx');
    }

    test('projectWorkflowPath uses Directory.current', () {
      IOOverrides.runZoned(
        () {
          final locator = WorkflowLocator();
          final path = locator.projectWorkflowPath('my-wf');
          expect(
            path,
            p.join(tmpProject.path, '.somnio', 'workflows', 'my-wf'),
          );
        },
        getCurrentDirectory: () => tmpProject,
      );
    });

    test('find returns project-scoped location when context.md exists', () {
      seedWorkflow('alpha');
      IOOverrides.runZoned(
        () {
          final locator = WorkflowLocator();
          final loc = locator.find('alpha');
          expect(loc, isNotNull);
          expect(loc!.scope, WorkflowScope.project);
          expect(loc.name, 'alpha');
          expect(File(loc.contextPath).existsSync(), isTrue);
        },
        getCurrentDirectory: () => tmpProject,
      );
    });

    test('find returns null when directory exists but context.md missing', () {
      // Directory present, but no context.md → should not match.
      Directory(
        p.join(tmpProject.path, '.somnio', 'workflows', 'empty'),
      ).createSync(recursive: true);
      IOOverrides.runZoned(
        () {
          final locator = WorkflowLocator();
          expect(locator.find('empty'), isNull);
        },
        getCurrentDirectory: () => tmpProject,
      );
    });

    test('find returns null when workflow does not exist', () {
      IOOverrides.runZoned(
        () {
          final locator = WorkflowLocator();
          expect(locator.find('nope'), isNull);
        },
        getCurrentDirectory: () => tmpProject,
      );
    });

    test('find falls back to the global scope when no project match exists',
        () {
      final locator = WorkflowLocator();
      const name = 'somnio-test-global-find-7f3a';
      final globalDir = Directory(locator.globalWorkflowPath(name));
      final workflowsDir = globalDir.parent; // ~/.somnio/workflows
      final somnioDir = workflowsDir.parent; // ~/.somnio
      final workflowsExisted = workflowsDir.existsSync();
      final somnioExisted = somnioDir.existsSync();

      // Clean up exactly what this test created, including parent dirs we had
      // to make, so nothing is left behind in the real home directory.
      addTearDown(() {
        if (globalDir.existsSync()) globalDir.deleteSync(recursive: true);
        if (!workflowsExisted &&
            workflowsDir.existsSync() &&
            workflowsDir.listSync().isEmpty) {
          workflowsDir.deleteSync();
        }
        if (!somnioExisted &&
            somnioDir.existsSync() &&
            somnioDir.listSync().isEmpty) {
          somnioDir.deleteSync();
        }
      });

      globalDir.createSync(recursive: true);
      File(p.join(globalDir.path, 'context.md')).writeAsStringSync('# ctx');

      // cwd points at a project with no matching workflow → falls back global.
      IOOverrides.runZoned(
        () {
          final loc = WorkflowLocator().find(name);
          expect(loc, isNotNull);
          expect(loc!.scope, WorkflowScope.global);
          expect(loc.name, name);
        },
        getCurrentDirectory: () => tmpProject,
      );
    });

    test('listAll returns project workflows and skips dirs without context.md',
        () {
      seedWorkflow('alpha');
      seedWorkflow('beta');
      // A directory with no context.md must be skipped.
      Directory(
        p.join(tmpProject.path, '.somnio', 'workflows', 'no-context'),
      ).createSync(recursive: true);

      IOOverrides.runZoned(
        () {
          final locator = WorkflowLocator();
          final all = locator.listAll();
          final names = all.map((l) => l.name).toList();
          expect(names, containsAll(['alpha', 'beta']));
          expect(names, isNot(contains('no-context')));
          expect(
            all.every((l) => l.scope == WorkflowScope.project),
            isTrue,
          );
        },
        getCurrentDirectory: () => tmpProject,
      );
    });

    test('listAll returns empty when workflows dir does not exist', () {
      IOOverrides.runZoned(
        () {
          final locator = WorkflowLocator();
          expect(locator.listAll(), isEmpty);
        },
        getCurrentDirectory: () => tmpProject,
      );
    });

    test('createWorkflowDir creates the project directory and returns path',
        () {
      IOOverrides.runZoned(
        () {
          final locator = WorkflowLocator();
          final path = locator.createWorkflowDir(
            'gamma',
            scope: WorkflowScope.project,
          );
          expect(
            path,
            p.join(tmpProject.path, '.somnio', 'workflows', 'gamma'),
          );
          expect(Directory(path).existsSync(), isTrue);
        },
        getCurrentDirectory: () => tmpProject,
      );
    });

    test('createWorkflowDir creates the global directory and returns path', () {
      final locator = WorkflowLocator();
      const name = 'somnio-test-global-mkdir-9c2b';
      final globalDir = Directory(locator.globalWorkflowPath(name));
      final workflowsDir = globalDir.parent;
      final somnioDir = workflowsDir.parent;
      final workflowsExisted = workflowsDir.existsSync();
      final somnioExisted = somnioDir.existsSync();

      addTearDown(() {
        if (globalDir.existsSync()) globalDir.deleteSync(recursive: true);
        if (!workflowsExisted &&
            workflowsDir.existsSync() &&
            workflowsDir.listSync().isEmpty) {
          workflowsDir.deleteSync();
        }
        if (!somnioExisted &&
            somnioDir.existsSync() &&
            somnioDir.listSync().isEmpty) {
          somnioDir.deleteSync();
        }
      });

      final path =
          locator.createWorkflowDir(name, scope: WorkflowScope.global);

      expect(path, globalDir.path);
      expect(Directory(path).existsSync(), isTrue);
    });
  });
}
