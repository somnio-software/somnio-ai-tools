import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../utils/platform_utils.dart';

/// The `attribution` value that turns off Claude Code's commit trailer and
/// pull request footer.
const disabledClaudeAttribution = {'commit': '', 'pr': ''};

/// Path to the user-level Claude Code settings file.
String claudeSettingsPath() =>
    p.join(PlatformUtils.homeDirectory, '.claude', 'settings.json');

/// Whether Claude Code adds its attribution to commits and pull requests.
enum ClaudeAttributionState {
  /// No `attribution` key: Claude Code adds its default trailer and footer.
  enabled,

  /// Both the commit and PR attribution are empty strings.
  disabled,

  /// An `attribution` key with custom text, or only one side turned off.
  custom,
}

/// Reads the attribution state from the settings file at [settingsPath].
///
/// Throws a [FormatException] when the file is not a JSON object.
ClaudeAttributionState readClaudeAttribution(String settingsPath) =>
    _attributionStateOf(_readSettings(settingsPath));

ClaudeAttributionState _attributionStateOf(Map<String, dynamic> settings) {
  final attribution = settings['attribution'];
  if (attribution == null) return ClaudeAttributionState.enabled;
  if (attribution is Map &&
      attribution['commit'] == '' &&
      attribution['pr'] == '') {
    return ClaudeAttributionState.disabled;
  }
  return ClaudeAttributionState.custom;
}

/// Turns Claude Code's commit and PR attribution off ([enabled] false) or
/// back to its default ([enabled] true) in the settings file at
/// [settingsPath], keeping every other key. Creates the file if absent.
///
/// Returns `true` when the file changed. Throws a [FormatException] and
/// leaves the file untouched when it is not a JSON object, so a malformed
/// settings file is never replaced.
bool setClaudeAttribution(String settingsPath, {required bool enabled}) {
  final settings = _readSettings(settingsPath);
  final state = _attributionStateOf(settings);

  if (enabled) {
    if (!settings.containsKey('attribution')) return false;
    settings.remove('attribution');
  } else {
    if (state == ClaudeAttributionState.disabled) return false;
    settings['attribution'] = Map<String, String>.from(
      disabledClaudeAttribution,
    );
  }

  final file = File(settingsPath);
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(settings)}\n');
  return true;
}

Map<String, dynamic> _readSettings(String settingsPath) {
  final file = File(settingsPath);
  if (!file.existsSync()) return {};
  final contents = file.readAsStringSync();
  if (contents.trim().isEmpty) return {};
  final decoded = jsonDecode(contents);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('$settingsPath is not a JSON object');
  }
  return decoded;
}

/// Top-level `somnio attribution` command: turns the "Generated with Claude
/// Code" footer on pull requests and the `Co-Authored-By` trailer on commits
/// off or on in `~/.claude/settings.json`.
///
/// Subcommands:
///   somnio attribution off     — remove the attribution
///   somnio attribution on      — restore Claude Code's default
///   somnio attribution status  — show the current state
class AttributionCommand extends Command<int> {
  /// [settingsPath] resolves the settings file; defaults to
  /// [claudeSettingsPath]. Tests point it at a temporary file.
  AttributionCommand({
    required Logger logger,
    String Function() settingsPath = claudeSettingsPath,
  }) {
    addSubcommand(
      _AttributionSetCommand(
        logger: logger,
        settingsPath: settingsPath,
        enabled: false,
      ),
    );
    addSubcommand(
      _AttributionSetCommand(
        logger: logger,
        settingsPath: settingsPath,
        enabled: true,
      ),
    );
    addSubcommand(
      _AttributionStatusCommand(logger: logger, settingsPath: settingsPath),
    );
  }

  @override
  String get name => 'attribution';

  @override
  String get description =>
      'Turn Claude Code\'s AI attribution on commits and pull requests '
      '(Co-Authored-By trailer, "Generated with Claude Code" footer) off '
      'or on.';
}

class _AttributionSetCommand extends Command<int> {
  _AttributionSetCommand({
    required Logger logger,
    required String Function() settingsPath,
    required bool enabled,
  })  : _logger = logger,
        _settingsPath = settingsPath,
        _enabled = enabled;

  final Logger _logger;
  final String Function() _settingsPath;
  final bool _enabled;

  @override
  String get name => _enabled ? 'on' : 'off';

  @override
  String get description => _enabled
      ? 'Restore Claude Code\'s default attribution on commits and PRs.'
      : 'Remove Claude Code\'s attribution from commits and PRs.';

  @override
  Future<int> run() async {
    final settingsPath = _settingsPath();
    try {
      final changed = setClaudeAttribution(settingsPath, enabled: _enabled);
      final state = _enabled ? 'on' : 'off';
      if (changed) {
        _logger.success('Claude Code attribution turned $state.');
        _logger.info('  Updated $settingsPath');
      } else {
        _logger.info('Claude Code attribution is already $state.');
      }
      if (!_enabled) {
        _logger.info(
          '  New commits and PRs will not get the Co-Authored-By trailer or '
          'the "Generated with Claude Code" footer.',
        );
      }
      return ExitCode.success.code;
    } on FormatException catch (e) {
      _logger.err(
        'Could not read $settingsPath: ${e.message}. Fix the file and '
        'run this again; it was not changed.',
      );
      return ExitCode.config.code;
    }
  }
}

class _AttributionStatusCommand extends Command<int> {
  _AttributionStatusCommand({
    required Logger logger,
    required String Function() settingsPath,
  })  : _logger = logger,
        _settingsPath = settingsPath;

  final Logger _logger;
  final String Function() _settingsPath;

  @override
  String get name => 'status';

  @override
  String get description =>
      'Show whether Claude Code adds attribution to commits and PRs.';

  @override
  Future<int> run() async {
    final settingsPath = _settingsPath();
    try {
      final state = readClaudeAttribution(settingsPath);
      switch (state) {
        case ClaudeAttributionState.enabled:
          _logger.info(
            'Claude Code attribution is on (default). Run '
            '${lightCyan.wrap('somnio attribution off')} to remove it.',
          );
        case ClaudeAttributionState.disabled:
          _logger.info('Claude Code attribution is off.');
        case ClaudeAttributionState.custom:
          _logger.info(
            'Claude Code attribution is customized in $settingsPath. Run '
            '${lightCyan.wrap('somnio attribution off')} to remove it.',
          );
      }
      return ExitCode.success.code;
    } on FormatException catch (e) {
      _logger.err('Could not read $settingsPath: ${e.message}');
      return ExitCode.config.code;
    }
  }
}
