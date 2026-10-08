import 'command_bundle.dart';

/// Static registry of all installable command bundles under `commands/` at
/// the repo root.
///
/// Each entry maps a root `commands/*.md` file to the metadata needed to
/// list and install it via `somnio commands install`. Adding a new command
/// requires only a new [CommandBundle] entry here.
class CommandRegistry {
  CommandRegistry._(); // coverage:ignore-line

  /// All registered command bundles.
  static const List<CommandBundle> commands = [
    CommandBundle(
      id: 'ship',
      name: 'ship',
      displayName: 'Ship',
      description: 'Ship workflow — merge base, run tests, review diff, bump '
          'VERSION, update CHANGELOG, commit, push, open PR.',
      sourceRelativePath: 'commands/ship.md',
    ),
    CommandBundle(
      id: 'audit',
      name: 'audit',
      displayName: 'Audit',
      description: 'Run a project health, best-practices, or security audit.',
      sourceRelativePath: 'commands/audit.md',
    ),
    CommandBundle(
      id: 'quick-check',
      name: 'quick-check',
      displayName: 'Quick Check',
      description: 'Quick project health assessment (2-3 min).',
      sourceRelativePath: 'commands/quick-check.md',
    ),
    CommandBundle(
      id: 'clockify-tracker',
      name: 'clockify-tracker',
      displayName: 'Clockify Tracker',
      description: 'Log or manage Clockify time entries via the Clockify API.',
      sourceRelativePath: 'commands/clockify-tracker.md',
    ),
  ];

  /// Find a command bundle by its [CommandBundle.name].
  static CommandBundle? findByName(String name) {
    for (final command in commands) {
      if (command.name == name) return command;
    }
    return null;
  }
}
