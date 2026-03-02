import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'commands/add_command.dart';
import 'commands/init_command.dart';
import 'commands/install_command.dart';
import 'commands/quote_command.dart';
import 'commands/run_command.dart';
import 'commands/setup_command.dart';
import 'commands/status_command.dart';
import 'commands/uninstall_command.dart';
import 'commands/update_command.dart';
import 'utils/banner.dart';
import 'utils/quotes.dart';
import 'version.dart';

/// The main CLI runner for the Somnio tool.
class SomnioCliRunner extends CommandRunner<int> {
  SomnioCliRunner({Logger? logger})
      : _logger = logger ?? Logger(),
        super(
          'somnio',
          'Install Somnio AI agent skills from technology-tools.',
        ) {
    argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print the current version.',
    );
    argParser.addFlag(
      'quiet',
      abbr: 'q',
      negatable: false,
      help: 'Suppress the banner.',
    );

    addCommand(AddCommand(logger: _logger));
    addCommand(InitCommand(logger: _logger));
    addCommand(InstallCommand(logger: _logger));
    addCommand(UpdateCommand(logger: _logger));
    addCommand(QuoteCommand());
    addCommand(RunCommand(logger: _logger));
    addCommand(SetupCommand(logger: _logger));
    addCommand(StatusCommand(logger: _logger));
    addCommand(UninstallCommand(logger: _logger));
  }

  final Logger _logger;

  static const version = packageVersion;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final topLevelResults = parse(args);
      return await runCommand(topLevelResults) ?? ExitCode.success.code;
    } on FormatException catch (e) {
      _logger
        ..err(e.message)
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    } on UsageException catch (e) {
      _logger
        ..err(e.message)
        ..info('')
        ..info(e.usage);
      return ExitCode.usage.code;
    } catch (e) {
      _logger.err('$e');
      return ExitCode.software.code;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] as bool) {
      _logger.info('somnio v$version');
      return ExitCode.success.code;
    }
    if (!(topLevelResults['quiet'] as bool)) {
      _printBanner();
    }
    return super.runCommand(topLevelResults);
  }

  void _printBanner() {
    final quote = getRandomQuote();
    printBanner(version: version, quote: quote);
  }
}
