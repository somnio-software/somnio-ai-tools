import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../agents/agent_registry.dart';
import '../content/skill_registry.dart';
import '../utils/platform_utils.dart';

/// Shows the current installation status of all agents.
///
/// All technology detection is driven by [SkillRegistry] — adding a new
/// tech bundle there automatically makes it visible here without any
/// code changes.
class StatusCommand extends Command<int> {
  StatusCommand({required Logger logger}) : _logger = logger {
    _buildRegistryMaps();
  }

  final Logger _logger;

  // ── Registry-driven lookup maps (built once) ─────────────────────────

  /// skill/command name → tech display name.
  /// `somnio-fh` → `Flutter`
  final _nameToTech = <String, String>{};

  /// plan subdirectory → tech display name.
  /// `flutter_project_health_audit` → `Flutter`
  final _dirToTech = <String, String>{};

  /// Populates lookup maps from [SkillRegistry].
  void _buildRegistryMaps() {
    for (final bundle in SkillRegistry.skills) {
      final tech = bundle.techDisplayName;
      _nameToTech[bundle.name] = tech;
      _dirToTech[bundle.planSubDir] = tech;
    }
  }

  /// Resolves a technology display name from a skill/command name,
  /// plan subdirectory, or workflow file name.
  ///
  /// Falls back to title-casing the input if no match is found (so new
  /// bundles that are installed but not yet in the local registry still
  /// show something reasonable).
  String _resolveTech(String identifier) {
    // Try exact match on skill name
    if (_nameToTech.containsKey(identifier)) return _nameToTech[identifier]!;

    // Try exact match on plan subdirectory
    if (_dirToTech.containsKey(identifier)) return _dirToTech[identifier]!;

    // Try prefix match on directory name (e.g., `flutter_best_practices_check`
    // matches any key that shares the same prefix before `_`).
    final prefix = identifier.split('_').first;
    for (final entry in _dirToTech.entries) {
      if (entry.key.startsWith(prefix)) return entry.value;
    }

    // Workflow file name: `somnio_flutter_health_audit.md`
    // Strip `somnio_` prefix and `.md` extension, then re-try.
    final stripped = identifier
        .replaceFirst('somnio_', '')
        .replaceFirst(RegExp(r'\.md$'), '');
    if (_dirToTech.containsKey(stripped)) return _dirToTech[stripped]!;

    // Prefix match on stripped workflow name
    final wfPrefix = stripped.split('_').first;
    for (final entry in _dirToTech.entries) {
      if (entry.key.startsWith(wfPrefix)) return entry.value;
    }

    // Fallback: title-case the first segment.
    return prefix[0].toUpperCase() + prefix.substring(1);
  }

  // ── Command boilerplate ──────────────────────────────────────────────

  @override
  String get name => 'status';

  @override
  String get description => 'Show what skills are installed and where.';

  @override
  Future<int> run() async {
    _logger.info('');

    _logger.info('CLI Availability');
    _logger.info('');
    await _printCliTable();

    _logger.info('');
    _logger.info('Installed Skills');
    _logger.info('');
    _printSkillsTable();

    _logger.info('');
    return ExitCode.success.code;
  }

  // ── CLI availability table ───────────────────────────────────────────

  Future<void> _printCliTable() async {
    final checks = <_CliCheck>[];
    for (final agent in AgentRegistry.executableAgents) {
      if (agent.binary == null) continue;
      final path = await PlatformUtils.whichBinary(agent.binary!);
      checks.add(_CliCheck(
        name: agent.displayName,
        installed: path != null,
        path: path,
      ));
    }

    final rows = <List<String>>[];
    for (final r in checks) {
      rows.add([
        r.name,
        r.installed ? 'Found' : 'Not found',
        r.installed ? r.path! : '-',
      ]);
    }

    final headers = ['CLI', 'Status', 'Path'];
    final colWidths = _computeWidths(headers, rows);

    _printBorder(colWidths, _BorderType.top);
    _printRow(headers, colWidths);
    _printBorder(colWidths, _BorderType.mid);
    for (final row in rows) {
      _printRow(
        row,
        colWidths,
        colorOverrides: {
          1: row[1] == 'Found'
              ? lightGreen.wrap(row[1])!
              : lightRed.wrap(row[1])!,
        },
      );
    }
    _printBorder(colWidths, _BorderType.bot);
  }

  // ── Installed skills table ───────────────────────────────────────────

  void _printSkillsTable() {
    final agents = [
      _collectClaudeData(),
      _collectCursorData(),
      _collectAntigravityData(),
    ];

    final headers = ['Agent', 'Status', 'Tech', 'Items', 'Rules', 'Location'];

    final allRows = <List<String>>[];
    for (final agent in agents) {
      allRows.addAll(_agentToRows(agent));
    }
    final colWidths = _computeWidths(headers, allRows);

    _printBorder(colWidths, _BorderType.top);
    _printRow(headers, colWidths);

    for (var i = 0; i < agents.length; i++) {
      _printBorder(colWidths, _BorderType.mid);
      final rows = _agentToRows(agents[i]);
      for (var j = 0; j < rows.length; j++) {
        final overrides = <int, String>{};
        if (j == 0) {
          final status = rows[j][1];
          overrides[1] = status == 'Installed'
              ? lightGreen.wrap(status)!
              : lightRed.wrap(status)!;
        }
        _printRow(rows[j], colWidths, colorOverrides: overrides);
      }
    }
    _printBorder(colWidths, _BorderType.bot);
  }

  List<List<String>> _agentToRows(_AgentData agent) {
    if (agent.techs.isEmpty) {
      return [
        [agent.name, 'Not found', '-', '-', '-', 'Run: ${agent.installCmd}'],
      ];
    }

    final rows = <List<String>>[];
    for (var i = 0; i < agent.techs.length; i++) {
      final t = agent.techs[i];
      final items = '${t.itemCount} ${t.itemLabel}';
      final rules = '${t.ruleCount} ${t.ruleExt}';

      if (i == 0) {
        rows.add([
          agent.name, 'Installed', t.tech, items, rules, agent.location,
        ]);
      } else {
        rows.add(['', '', t.tech, items, rules, '']);
      }
    }
    return rows;
  }

  // ── Data collectors ──────────────────────────────────────────────────

  _AgentData _collectClaudeData() {
    final dir = Directory(PlatformUtils.claudeGlobalSkillsDir);
    final techMap = <String, List<int>>{};

    if (dir.existsSync()) {
      for (final entity in dir.listSync()) {
        if (entity is Directory &&
            p.basename(entity.path).startsWith('somnio-')) {
          final skillName = p.basename(entity.path);
          final tech = _resolveTech(skillName);
          techMap.putIfAbsent(tech, () => [0, 0]);
          techMap[tech]![0]++;
          final rulesDir = Directory(p.join(entity.path, 'rules'));
          if (rulesDir.existsSync()) {
            techMap[tech]![1] += rulesDir
                .listSync()
                .whereType<File>()
                .where((f) => f.path.endsWith('.md'))
                .length;
          }
        }
      }
    }

    return _AgentData(
      name: 'Claude Code',
      location: '~/.claude/skills/',
      installCmd: 'somnio claude',
      techs: _buildTechList(techMap, 'skill', 'skills', '.md'),
    );
  }

  _AgentData _collectCursorData() {
    final commandsDir = Directory(PlatformUtils.cursorGlobalCommandsDir);
    final techCmds = <String, int>{};
    if (commandsDir.existsSync()) {
      for (final f in commandsDir.listSync().whereType<File>()) {
        if (f.path.endsWith('.md') &&
            p.basename(f.path).startsWith('somnio-')) {
          final tech = _resolveTech(p.basenameWithoutExtension(f.path));
          techCmds[tech] = (techCmds[tech] ?? 0) + 1;
        }
      }
    }

    final rulesDir = Directory(PlatformUtils.cursorGlobalRulesDir);
    final techRules = <String, int>{};
    if (rulesDir.existsSync()) {
      for (final sub in rulesDir.listSync().whereType<Directory>()) {
        final tech = _resolveTech(p.basename(sub.path));
        final count = sub
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) =>
                f.path.endsWith('.md') && !f.path.contains('/templates/'))
            .length;
        techRules[tech] = (techRules[tech] ?? 0) + count;
      }
    }

    final allTechs = {...techCmds.keys, ...techRules.keys};
    final techMap = <String, List<int>>{};
    for (final tech in allTechs) {
      techMap[tech] = [techCmds[tech] ?? 0, techRules[tech] ?? 0];
    }

    return _AgentData(
      name: 'Cursor',
      location: '~/.cursor/',
      installCmd: 'somnio cursor',
      techs: _buildTechList(techMap, 'command', 'commands', '.md'),
    );
  }

  _AgentData _collectAntigravityData() {
    final baseDir = PlatformUtils.antigravityGlobalDir;

    final wfDir = Directory(p.join(baseDir, 'global_workflows'));
    final techWf = <String, int>{};
    if (wfDir.existsSync()) {
      for (final f in wfDir.listSync().whereType<File>()) {
        if (p.basename(f.path).startsWith('somnio_')) {
          final tech = _resolveTech(p.basename(f.path));
          techWf[tech] = (techWf[tech] ?? 0) + 1;
        }
      }
    }

    final rulesDir = Directory(p.join(baseDir, 'somnio_rules'));
    final techRules = <String, int>{};
    if (rulesDir.existsSync()) {
      for (final sub in rulesDir.listSync().whereType<Directory>()) {
        final tech = _resolveTech(p.basename(sub.path));
        final count = sub
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) =>
                f.path.endsWith('.yaml') && !f.path.contains('/templates/'))
            .length;
        techRules[tech] = (techRules[tech] ?? 0) + count;
      }
    }

    final allTechs = {...techWf.keys, ...techRules.keys};
    final techMap = <String, List<int>>{};
    for (final tech in allTechs) {
      techMap[tech] = [techWf[tech] ?? 0, techRules[tech] ?? 0];
    }

    return _AgentData(
      name: 'Gemini',
      location: '~/.gemini/antigravity/',
      installCmd: 'somnio antigravity',
      techs: _buildTechList(techMap, 'workflow', 'workflows', '.yaml'),
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────────

  List<_TechData> _buildTechList(
    Map<String, List<int>> techMap,
    String singular,
    String plural,
    String ruleExt,
  ) {
    return techMap.entries.map((e) {
      final items = e.value[0];
      return _TechData(
        tech: e.key,
        itemCount: items,
        itemLabel: items == 1 ? singular : plural,
        ruleCount: e.value[1],
        ruleExt: ruleExt,
      );
    }).toList()
      ..sort((a, b) => a.tech.compareTo(b.tech));
  }

  // ── Table rendering ──────────────────────────────────────────────────

  List<int> _computeWidths(List<String> headers, List<List<String>> rows) {
    final widths = List<int>.generate(
      headers.length,
      (i) => headers[i].length,
    );
    for (final row in rows) {
      for (var i = 0; i < row.length && i < widths.length; i++) {
        if (row[i].length > widths[i]) widths[i] = row[i].length;
      }
    }
    return widths;
  }

  void _printBorder(List<int> widths, _BorderType type) {
    final (left, cross, right) = switch (type) {
      _BorderType.top => ('┌', '┬', '┐'),
      _BorderType.mid => ('├', '┼', '┤'),
      _BorderType.bot => ('└', '┴', '┘'),
    };
    final segments = widths.map((w) => '─' * (w + 2));
    _logger.info('$left${segments.join(cross)}$right');
  }

  void _printRow(
    List<String> cells,
    List<int> widths, {
    Map<int, String>? colorOverrides,
  }) {
    final buf = StringBuffer('│');
    for (var i = 0; i < widths.length; i++) {
      final plain = i < cells.length ? cells[i] : '';
      final display = colorOverrides != null && colorOverrides.containsKey(i)
          ? colorOverrides[i]!
          : plain;
      final padding = widths[i] - plain.length;
      buf.write(' $display${' ' * padding} │');
    }
    _logger.info(buf.toString());
  }
}

// ── Private data models ──────────────────────────────────────────────

enum _BorderType { top, mid, bot }

class _CliCheck {
  const _CliCheck({
    required this.name,
    required this.installed,
    this.path,
  });

  final String name;
  final bool installed;
  final String? path;
}

class _AgentData {
  const _AgentData({
    required this.name,
    required this.location,
    required this.installCmd,
    required this.techs,
  });

  final String name;
  final String location;
  final String installCmd;
  final List<_TechData> techs;
}

class _TechData {
  const _TechData({
    required this.tech,
    required this.itemCount,
    required this.itemLabel,
    required this.ruleCount,
    required this.ruleExt,
  });

  final String tech;
  final int itemCount;
  final String itemLabel;
  final int ruleCount;
  final String ruleExt;
}
