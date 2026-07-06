// coverage:ignore-file
import 'package:args/command_runner.dart';

/// Displays the Somnio banner with a random quote.
///
/// This is a lightweight command — the banner and quote are already
/// printed by [SomnioCliRunner.runCommand], so the command itself
/// simply returns success.
class QuoteCommand extends Command<int> {
  QuoteCommand();

  @override
  String get name => 'quote';

  @override
  List<String> get aliases => ['q'];

  @override
  String get description => 'Show a random Somnio quote.';

  @override
  Future<int> run() async => 0;
}