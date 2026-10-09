// Scans the prose that tells a model how to write each audit report
// (generators, format enforcers, report-writer agents and report-writing
// SKILL.md files) for instructions that contradict the report templates.
// The templates are the contract; these phrases produced report variants
// (bullet scorecards, extra weight tables, bold score values) that the
// downstream pipeline had to repair.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Phrases that must never appear in report-shape prose.
final _forbidden = <String, RegExp>{
  'bullet scorecard ("- Overall: [")':
      RegExp(r'^- Overall: \[', multiLine: true),
  '"with weights" (weights belong in the appendix only)':
      RegExp(r'with weights', caseSensitive: false),
  '"key values" (bold rule must be label-only)': RegExp(r'key values'),
  '"bold ... for scores" (bold rule must be label-only)':
      RegExp(r'bold\*\*.? for scores'),
  'bold score value ("**Score:** **")': RegExp(r'\*\*Score:\*\* \*\*'),
  '"5 scored lines" (security section 1 is a table)': RegExp(r'5 scored lines'),
  '"[Section Name]: [Score]/100" line format (use the table)':
      RegExp(r'\[Section Name\]: \[Score\]/100'),
  '"No markdown syntax" (contradicts the Markdown rules)':
      RegExp(r'No markdown syntax'),
};

String _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (Directory(p.join(dir.path, 'skills')).existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate repo root from ${Directory.current}');
    }
    dir = parent;
  }
}

/// Report-shape prose files under [skillsDir].
List<File> _proseFiles(Directory skillsDir) {
  final files = <File>[];
  for (final skill in skillsDir.listSync().whereType<Directory>()) {
    final refs = p.join(skill.path, 'references');
    final agents = p.join(skill.path, 'agents');
    for (final name in const [
      'report-generator.md',
      'report-format-enforcer.md',
      'best-practices-format-enforcer.md',
    ]) {
      final f = File(p.join(refs, name));
      if (f.existsSync()) files.add(f);
    }
    final agentsDir = Directory(agents);
    if (agentsDir.existsSync()) {
      files.addAll(agentsDir.listSync().whereType<File>().where((f) {
        final base = p.basename(f.path);
        return base.startsWith('report-writer') && base.endsWith('.md');
      }));
    }
    final writesReport =
        File(p.join(skill.path, 'assets', 'report-template.md')).existsSync() ||
            File(p.join(refs, 'report-generator.md')).existsSync();
    final skillMd = File(p.join(skill.path, 'SKILL.md'));
    if (writesReport && skillMd.existsSync()) files.add(skillMd);
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// Returns "<file>: <rule>" for every violation found in [files].
List<String> findViolations(List<File> files, String root) {
  final out = <String>[];
  for (final f in files) {
    final text = f.readAsStringSync();
    _forbidden.forEach((rule, pattern) {
      if (pattern.hasMatch(text)) {
        out.add('${p.relative(f.path, from: root)}: $rule');
      }
    });
  }
  return out;
}

void main() {
  final root = _repoRoot();
  final skillsDir = Directory(p.join(root, 'skills'));
  final files = _proseFiles(skillsDir);

  group('skill prose drift check (report shape instructions)', () {
    test('finds the report-shape prose files to scan', () {
      expect(files, isNotEmpty);
      expect(
          files.any((f) => f.path.endsWith(
              p.join('security-audit', 'references', 'report-generator.md'))),
          isTrue);
      expect(
          files.any((f) => f.path.endsWith(p.join('flutter-best-practices',
              'references', 'best-practices-format-enforcer.md'))),
          isTrue);
    });

    test('security template uses only the allowed non-ASCII characters', () {
      final template = File(p.join(
              root, 'skills', 'security-audit', 'assets', 'report-template.md'))
          .readAsStringSync();
      const allowed = {0x2013, 0x00B7, 0x2014, 0x1F534, 0x1F7E1, 0x1F7E2};
      final bad = template.runes
          .where((r) => r > 127 && !allowed.contains(r))
          .map((r) => 'U+${r.toRadixString(16).toUpperCase()}')
          .toSet();
      expect(bad, isEmpty);
    });

    test('no report-shape prose contradicts the templates', () {
      expect(findViolations(files, root), isEmpty,
          reason: 'These instructions contradict the report templates; '
              'fix the prose, not the pattern.');
    });
  });
}
