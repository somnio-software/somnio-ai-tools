import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/utils/repo_name.dart';
import 'package:test/test.dart';

/// Builds a [GitRunner] that answers each git subcommand from [answers],
/// keyed by its first argument, and `null` for anything else.
GitRunner fakeGit(Map<String, String?> answers) =>
    (args, _) async => answers[args.first];

void main() {
  group('resolveRepoName', () {
    test('prefers the origin remote over the directory name', () async {
      final name = await resolveRepoName(
        '/work/backend',
        git: fakeGit({
          'remote': 'git@github.com:somnio/hoopis-backend.git',
          'rev-parse': '/work/backend/.git',
        }),
      );
      expect(name, 'hoopis-backend');
    });

    test('uses the main checkout when there is no origin', () async {
      // A linked worktree: its directory is named after the branch, but the
      // common dir points at the main checkout.
      final name = await resolveRepoName(
        '/work/hoopis-backend-feat-login/packages/api',
        git: fakeGit({'rev-parse': '/work/hoopis-backend/.git'}),
      );
      expect(name, 'hoopis-backend');
    });

    test('falls back to the directory name outside a git repo', () async {
      final name = await resolveRepoName(
        '/work/some-project',
        git: fakeGit({}),
      );
      expect(name, 'some-project');
    });

    test('skips an origin URL that yields no name', () async {
      final name = await resolveRepoName(
        '/work/backend',
        git: fakeGit({
          'remote': 'https://github.com/.git',
          'rev-parse': '/work/hoopis-backend/.git',
        }),
      );
      expect(name, 'hoopis-backend');
    });
  });

  group('resolveRepoName with real git', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('repo_name_test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    // Git hooks export GIT_DIR, GIT_INDEX_FILE and friends. Inherited, they
    // point every call below at the repository running the hook — a pre-push
    // would `git init` the real repo and flip it to `core.bare = true`.
    final env = Map.of(Platform.environment)
      ..removeWhere((key, _) => key.startsWith('GIT_'));

    Future<ProcessResult> runGit(List<String> args, String dir) => Process.run(
          'git',
          args,
          workingDirectory: dir,
          environment: env,
          includeParentEnvironment: false,
        );

    Future<void> git(List<String> args, String dir) async {
      final result = await runGit(args, dir);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }

    final isolatedGit = processGitRunner(environment: env);

    test('reads the origin remote', () async {
      final repo = p.join(tmp.path, 'checkout-dir');
      Directory(repo).createSync();
      await git(['init', '-q'], repo);
      await git(
        ['remote', 'add', 'origin', 'git@github.com:org/hoopis-backend.git'],
        repo,
      );
      expect(
        await resolveRepoName(repo, git: isolatedGit),
        'hoopis-backend',
      );
    });

    test('uses the checkout directory when there is no origin', () async {
      final repo = p.join(tmp.path, 'hoopis-backend');
      final sub = p.join(repo, 'packages', 'api');
      Directory(sub).createSync(recursive: true);
      await git(['init', '-q'], repo);
      expect(
        await resolveRepoName(sub, git: isolatedGit),
        'hoopis-backend',
      );
    });

    test('uses the directory name outside a git repo', () async {
      // The system temp dir may itself sit inside a repo on some machines;
      // GIT_CEILING_DIRECTORIES is not settable per call here, so only
      // assert when git agrees there is no repository.
      final dir = p.join(tmp.path, 'plain-dir');
      Directory(dir).createSync();
      final probe = await runGit(['rev-parse', '--git-dir'], dir);
      if (probe.exitCode == 0) return;
      expect(await resolveRepoName(dir, git: isolatedGit), 'plain-dir');
    });
  });
}
