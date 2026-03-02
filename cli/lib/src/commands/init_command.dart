import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../utils/command_helpers.dart';

/// Alias for `setup --skip-cli`.
///
/// Detects installed agents and installs all skills globally.
/// Hidden from help output to reduce confusion — users should use `setup`.
class InitCommand extends Command<int> {
  InitCommand({required Logger logger}) : _logger = logger;

  final Logger _logger;

  @override
  String get name => 'init';

  @override
  String get description =>
      'Alias for "setup --skip-cli". '
      'Detect agents and install skills.';

  @override
  bool get hidden => true;

  @override
  Future<int> run() async {
    return CommandHelpers.installToDetectedAgents(_logger);
  }
}
