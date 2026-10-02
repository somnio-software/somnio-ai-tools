/// Resolves the git repository name used as the project segment of every
/// report file name.
///
/// Kept apart from `report_naming.dart` because it shells out to git, while
/// that file stays pure. The git call is injectable so the resolution order
/// is covered by tests without a real repository.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'report_naming.dart';

/// Runs `git <args>` in [workingDirectory] and returns its trimmed stdout, or
/// `null` when git is missing, the command fails, or it prints nothing.
typedef GitRunner = Future<String?> Function(
  List<String> args,
  String workingDirectory,
);

/// Resolves the repository name for the project at [cwd].
///
/// In order:
/// 1. The `origin` remote URL — the repo's canonical name, independent of the
///    directory it was cloned into.
/// 2. The main checkout directory, via `git rev-parse --git-common-dir` — for
///    a repo with no `origin`. Works from linked worktrees and subdirectories.
/// 3. The basename of [cwd] — when [cwd] is not inside a git repository.
Future<String> resolveRepoName(String cwd, {GitRunner? git}) async {
  final run = git ?? processGitRunner();

  final remote = await run(['remote', 'get-url', 'origin'], cwd);
  final fromRemote = remote == null ? null : repoNameFromRemoteUrl(remote);
  if (fromRemote != null) return fromRemote;

  final commonDir = await run(
    ['rev-parse', '--path-format=absolute', '--git-common-dir'],
    cwd,
  );
  final fromCommonDir =
      commonDir == null ? null : repoNameFromGitCommonDir(commonDir);
  if (fromCommonDir != null) return fromCommonDir;

  return p.basename(cwd);
}

/// Returns a [GitRunner] that shells out to the `git` executable.
///
/// When [environment] is given it replaces the parent environment entirely,
/// so callers can drop variables such as `GIT_DIR` that a git hook exports.
GitRunner processGitRunner({Map<String, String>? environment}) =>
    (args, workingDirectory) async {
      try {
        final result = await Process.run(
          'git',
          args,
          workingDirectory: workingDirectory,
          environment: environment,
          includeParentEnvironment: environment == null,
        );
        if (result.exitCode != 0) return null;
        final out = (result.stdout as String).trim();
        return out.isEmpty ? null : out;
      } on ProcessException {
        return null;
      }
    };
