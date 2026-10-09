// coverage:ignore-file
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../utils/activated_version.dart';

/// Runs [executable] with [arguments]; mirrors [Process.run] for injection.
typedef ProcessRunner = Future<ProcessResult> Function(
    String executable, List<String> arguments);

/// Updates the Somnio CLI binary itself to the latest version.
///
/// This command used to also clean up and reinstall every skill across all
/// supported agents, but that responsibility now lives in `somnio skills
/// update`. Keeping this command scoped to only the CLI binary means it can
/// run quickly and safely without touching any agent's skill installations.
class UpdateCommand extends Command<int> {
  UpdateCommand({required Logger logger, ProcessRunner? processRunner})
      : _logger = logger,
        _runProcess = processRunner ?? Process.run {
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'Show the raw output of the update process.',
      negatable: false,
    );
  }

  final Logger _logger;
  final ProcessRunner _runProcess;

  static const _repoUrl = 'https://github.com/somnio-software/somnio-ai-tools';

  @override
  String get name => 'update';

  @override
  String get description =>
      'Update the somnio CLI itself to the latest version.';

  @override
  Future<int> run() async {
    final verbose = argResults!['verbose'] as bool;

    final updateProgress = _logger.progress('Updating somnio CLI');
    try {
      final result = await _runProcess('dart', [
        'pub',
        'global',
        'activate',
        '--source',
        'git',
        _repoUrl,
        '--git-path',
        'cli',
      ]);

      if (verbose) {
        final stdout = (result.stdout as String).trim();
        if (stdout.isNotEmpty) {
          _logger.info(stdout);
        }
        final stderr = (result.stderr as String).trim();
        if (stderr.isNotEmpty) {
          _logger.info(stderr);
        }
      }

      if (result.exitCode != 0) {
        updateProgress.fail('Failed to update CLI');
        _logger.err(result.stderr as String);
        _logger.info('');
        _logger.info(
          'You can update manually:\n'
          '  dart pub global activate --source git $_repoUrl --git-path cli',
        );
        return ExitCode.software.code;
      }
      // The running binary is still the old one, so the new version comes from
      // pub's own output, never from packageVersion.
      updateProgress.complete(updateSuccessMessage(result.stdout as String));
    } catch (e) {
      updateProgress.fail('Failed to update CLI: $e');
      return ExitCode.software.code;
    }

    _logger.info('');
    _logger.info(
      'Skills are updated separately — run "somnio skills update" to '
      'refresh installed skills.',
    );

    return ExitCode.success.code;
  }
}
