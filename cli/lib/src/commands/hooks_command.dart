// coverage:ignore-file
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../utils/platform_utils.dart';

/// Installs Claude Code hooks shipped with somnio-ai-tools.
///
/// Currently installs the work-log Stop hook, which appends a 2-3 sentence
/// Haiku-generated summary of each session turn to ~/.work-log/YYYY-MM-DD.md.
class HooksCommand extends Command<int> {
  HooksCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Skip confirmation prompt.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Show each step in detail.',
        negatable: false,
      );
  }

  final Logger _logger;

  static const hookFilename = 'work-log-stop.sh';
  static const hookCommand = '~/.claude/hooks/work-log-stop.sh';

  // Keep in sync with hooks/work-log-stop.sh in the repo root.
  // Exposed without leading underscore so tests can verify drift against the source file.
  static const hookScript = r'''#!/usr/bin/env bash
set -euo pipefail

[ -n "${WORK_LOG_CHILD:-}" ] && exit 0

DATE=$(date '+%Y-%m-%d')
LOG=~/.work-log/$DATE.md
mkdir -p ~/.work-log

LAST=$(python3 -c "import os,sys; print(int(os.path.getmtime(sys.argv[1])))" "$LOG" 2>/dev/null || echo 0)
AGE=$(( $(date +%s) - LAST ))
[ "$AGE" -lt 5 ] && exit 0

STDIN=$(cat)

CWD=$(echo "$STDIN" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("cwd",""))' 2>/dev/null || true)
[ -z "$CWD" ] && CWD=$(pwd)

BRANCH=$(cd "$CWD" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'no-git')

GIT_COMMON=$(cd "$CWD" && git rev-parse --git-common-dir 2>/dev/null || echo "")
if [ -n "$GIT_COMMON" ]; then
  case "$GIT_COMMON" in /*) ;; *) GIT_COMMON="$CWD/$GIT_COMMON" ;; esac
  ROOT_REPO=$(basename "$(dirname "$GIT_COMMON")")
  WORKTREE=$(basename "$CWD")
  if [ "$ROOT_REPO" = "$WORKTREE" ]; then
    PROJ="$ROOT_REPO"
  else
    PROJ="$ROOT_REPO/$WORKTREE"
  fi
else
  PROJ=$(basename "$CWD")
fi

LAST_MSG=$(echo "$STDIN" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("last_assistant_message","")[:3000])' 2>/dev/null || true)

[ "${#LAST_MSG}" -lt 300 ] && exit 0

GIT_STAT=$(cd "$CWD" && { git log --oneline -3 2>/dev/null; echo "---"; git diff --stat HEAD 2>/dev/null | head -5; } || true)

TIMESTAMP=$(date '+%H:%M')

PROMPT=$(printf 'You are writing a developer work log. Classify this session and respond accordingly.\n\nIf the session is purely conversational Q&A (factual questions, general explanations, no real investigation or decision-making): output exactly the word SKIP and nothing else.\n\nOtherwise write 2-3 sentences: what was accomplished or investigated, the key technical finding or decision, and any next step. Be specific — name files, functions, concepts, root causes. For research or investigation sessions with no code changes, describe what was explored and what was found. Do NOT reference git commits unless they are directly mentioned in the session response.\n\nProject: %s (%s)\nRecent git (supplementary context only):\n%s\n\nSession response:\n%s' \
  "$PROJ" "$BRANCH" "$GIT_STAT" "$LAST_MSG")

CLAUDE_BIN=$(which claude 2>/dev/null || echo "claude")

(
  SUMMARY=$(WORK_LOG_CHILD=1 "$CLAUDE_BIN" -p \
    --model claude-haiku-4-5-20251001 \
    --no-session-persistence \
    "$PROMPT" 2>/dev/null \
    || echo "(summary unavailable)")

  case "$SUMMARY" in
    [Ss][Kk][Ii][Pp]*) ;;
    *)
      {
        printf "\n## %s - %s (%s)\n" "$TIMESTAMP" "$PROJ" "$BRANCH"
        printf "%s\n" "$SUMMARY"
      } >> "$LOG"
    ;;
  esac
) &

exit 0
''';

  @override
  String get name => 'hooks';

  @override
  String get description =>
      'Install Claude Code hooks from somnio-ai-tools.\n'
      '\n'
      'Installs the work-log Stop hook into ~/.claude/hooks/ and registers\n'
      'it in ~/.claude/settings.json. After each Claude Code session turn,\n'
      'the hook appends a 2-3 sentence summary to ~/.work-log/YYYY-MM-DD.md\n'
      'which the clockify-tracker skill can use to auto-fill time entries.';

  @override
  Future<int> run() async {
    final force = argResults!['force'] as bool;
    final verbose = argResults!['verbose'] as bool;

    final home = PlatformUtils.homeDirectory;
    final hooksDir = p.join(home, '.claude', 'hooks');
    final hookPath = p.join(hooksDir, hookFilename);
    final settingsPath = p.join(home, '.claude', 'settings.json');

    _logger.info('');
    _logger.info('This will:');
    _logger.info('  • Write  $hookPath');
    _logger.info('  • Update $settingsPath  (Stop hook)');
    _logger.info('  • Create ~/.work-log/ on first use (by the hook itself)');
    _logger.info('');

    if (!force) {
      final confirmed = _logger.confirm('Proceed?', defaultValue: true);
      if (!confirmed) {
        _logger.info('');
        _logger.info('Cancelled.');
        return ExitCode.success.code;
      }
      _logger.info('');
    }

    final progress = _logger.progress('Installing work-log hook');

    try {
      // 1. Write the script.
      final hooksDirectory = Directory(hooksDir);
      if (!hooksDirectory.existsSync()) {
        hooksDirectory.createSync(recursive: true);
        if (verbose) _logger.info('  Created $hooksDir');
      }
      File(hookPath).writeAsStringSync(hookScript);
      if (verbose) _logger.info('  Wrote $hookPath');

      // 2. Make executable.
      if (!Platform.isWindows) {
        final chmodResult = await Process.run('chmod', ['+x', hookPath]);
        if (chmodResult.exitCode != 0) {
          throw Exception('chmod +x failed: ${chmodResult.stderr}');
        }
        if (verbose) _logger.info('  chmod +x $hookPath');
      }

      // 3. Register in settings.json.
      final alreadyRegistered = mergeStopHookIntoSettings(
        settingsPath,
        hookCommand,
        onWarn: _logger.warn,
        onVerbose: verbose ? _logger.info : null,
      );
      if (verbose && alreadyRegistered) {
        _logger.info('  Stop hook already registered — skipped');
      }

      progress.complete('Work-log hook installed');
    } catch (e) {
      progress.fail('Failed: $e');
      return ExitCode.software.code;
    }

    _logger.info('');
    _logger.success(
      'Hook active — summaries will appear in ~/.work-log/ after each turn.',
    );
    _logger.info('');
    _logger.info(
      'Use ${lightCyan.wrap('/clockify-tracker')} with "use logs" to '
      'auto-fill Clockify from those summaries.',
    );
    _logger.info('');

    return ExitCode.success.code;
  }

}

/// Merges the Stop hook entry for [hookCommand] into the settings file at
/// [settingsPath]. Creates the file if absent.
///
/// Returns `true` if the command was already registered (no-op). Exposed at
/// the top level (not as a class member) so it can be exercised directly in
/// unit tests without spinning up the full command.
bool mergeStopHookIntoSettings(
  String settingsPath,
  String hookCommand, {
  void Function(String)? onWarn,
  void Function(String)? onVerbose,
}) {
  final file = File(settingsPath);
  Map<String, dynamic> settings = {};

  if (file.existsSync()) {
    try {
      settings = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      // Malformed JSON — back up and start fresh for the hooks key only.
      file.copySync('$settingsPath.bak');
      onWarn?.call(
        '  settings.json was malformed — backed up to settings.json.bak',
      );
    }
  }

  final hooks = Map<String, dynamic>.from(settings['hooks'] as Map? ?? {});
  final stopList = List<dynamic>.from(hooks['Stop'] as List? ?? []);

  final alreadyRegistered = stopList.any((entry) {
    if (entry is! Map) return false;
    final innerHooks = entry['hooks'] as List?;
    return innerHooks?.any(
          (h) => h is Map && h['command'] == hookCommand,
        ) ??
        false;
  });

  if (!alreadyRegistered) {
    stopList.add({
      'matcher': '',
      'hooks': [
        {'type': 'command', 'command': hookCommand},
      ],
    });
    hooks['Stop'] = stopList;
    settings['hooks'] = hooks;

    const encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync('${encoder.convert(settings)}\n');
    onVerbose?.call('  Updated $settingsPath');
  }

  return alreadyRegistered;
}