// Guards the six `skills/<stack>-best-practices/assets/report-template.md`
// files against re-diverging from the unified skeleton they were just moved
// onto (flutter, react, angular, angularjs, python, nestjs). Unlike the
// health-audit family (see `report_template_drift_test.dart`), these six
// templates legitimately have a different number of scored sections per
// stack — each stack runs a different set of analysis references — so this
// test tolerates that variability and asserts only what every one of the six
// genuinely shares: the section skeleton around the stack-variable middle,
// the `/100` scale, the scoring legend, the absence of a Weight column in
// the Score Breakdown table, and that each skill's own appendix weights
// match its own Score Breakdown row labels (never a sibling skill's).
//
// These templates are NOT read by the CLI at runtime, so nothing else in
// `dart analyze`/`dart test` would ever catch a hand-edit that quietly
// breaks the contract. This file is that safety net.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _stacks = ['flutter', 'react', 'angular', 'angularjs', 'python', 'nestjs'];

/// Expected total numbered-section count per stack, read from the real
/// templates (verified against the current files before writing this test).
const _expectedSectionCount = <String, int>{
  'flutter': 7,
  'react': 10,
  'angular': 10,
  'angularjs': 10,
  'python': 11,
  'nestjs': 9,
};

/// Expected titles of the stack-variable scored sections, in order, between
/// "Score Breakdown" and "Prioritized Recommendations". Legitimately
/// different per stack (different analysis references per skill) — never
/// cross-applied.
const _expectedScoredSections = <String, List<String>>{
  'flutter': ['Testing Quality', 'Architecture Compliance', 'Code Standards'],
  'react': [
    'Testing Quality',
    'Component Architecture',
    'Hooks Patterns',
    'State Management',
    'Performance',
    'TypeScript Standards',
  ],
  'angular': [
    'Testing Quality',
    'Component Architecture',
    'Lifecycle & DI Patterns',
    'Services & State Management',
    'Change Detection & Performance',
    'TypeScript Standards',
  ],
  'angularjs': [
    'Testing Quality',
    'Component Architecture',
    'Scope & Binding Patterns',
    'State Management',
    'Performance',
    'JavaScript Standards',
  ],
  'python': [
    'Typing',
    'Code Style',
    'Function Design',
    'Data Validation',
    'Error Handling',
    'Module Structure',
    'Testing Quality',
  ],
  'nestjs': [
    'Testing Quality',
    'Architecture Compliance',
    'Code Standards',
    'DTO Validation',
    'Error Handling',
  ],
};

/// Expected `| Section | Weight |` appendix rows per skill (label -> percent
/// value, `%` stripped). Each skill keeps its own weights — never
/// cross-applied between skills.
const _expectedWeights = <String, Map<String, double>>{
  'flutter': {
    'Testing Quality': 30,
    'Architecture Compliance': 40,
    'Code Standards': 30,
  },
  'react': {
    'Testing Quality': 20,
    'Component Architecture': 25,
    'Hooks Patterns': 15,
    'State Management': 15,
    'Performance': 15,
    'TypeScript Standards': 10,
  },
  'angular': {
    'Testing Quality': 20,
    'Component Architecture': 25,
    'Lifecycle & DI Patterns': 15,
    'Services & State Management': 15,
    'Change Detection & Performance': 15,
    'TypeScript Standards': 10,
  },
  'angularjs': {
    'Testing Quality': 20,
    'Component Architecture': 25,
    'Scope & Binding Patterns': 15,
    'State Management': 15,
    'Performance': 15,
    'JavaScript Standards': 10,
  },
  'python': {
    'Typing': 15,
    'Code Style': 10,
    'Function Design': 15,
    'Data Validation': 15,
    'Error Handling': 15,
    'Module Structure': 10,
    'Testing Quality': 20,
  },
  'nestjs': {
    'Testing Quality': 20,
    'Architecture Compliance': 25,
    'Code Standards': 20,
    'DTO Validation': 15,
    'Error Handling': 20,
  },
};

/// The scorecard's scoring-legend blockquote, byte-identical across all six
/// — including the en dash (U+2013) and middle dot (U+00B7). Same literal
/// as `report_template_drift_test.dart`'s `_scoringLegend`.
const _scoringLegend =
    '> **Scoring:** Strong (85–100) · Fair (70–84) · '
    'Weak (0–69)';

/// A `/10` occurrence that is not part of `/100` — e.g. a stray `/10` scale
/// left over from the pre-unification per-section scoring (D1: every scored
/// section in this family now reports on a `/100` scale with the standard
/// Strong/Fair/Weak bands, matching the health-audit family).
final _bareOutOfTen = RegExp(r'/10(?!\d)');

/// Walks up from the test's working directory until it finds the repo root
/// (the directory that contains the top-level `skills/` folder). Mirrors the
/// idiom used by `report_template_drift_test.dart` / `skill_registry_test.dart`.
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

String _templatePath(String stack) => p.join(
      _repoRoot(),
      'skills',
      '$stack-best-practices',
      'assets',
      'report-template.md',
    );

String _skillLabel(String stack) => '$stack-best-practices report-template.md';

/// The report generator for [stack]. This is the file the runner actually
/// feeds the model on the `somnio run` path, so it — not the template — is
/// what decides which sections a produced report contains.
String _generatorPath(String stack) => p.join(
      _repoRoot(),
      'skills',
      '$stack-best-practices',
      'references',
      'best-practices-generator.md',
    );

String _generatorLabel(String stack) =>
    '$stack-best-practices best-practices-generator.md';

/// `1. EXECUTIVE SUMMARY` entries under the generator's `## REPORT SECTIONS`.
final _generatorSectionPattern = RegExp(r'^(\d+)\.\s+([A-Z][A-Z0-9 &/():-]*?)\s*$');

/// `    - Testing Quality: 20%` rows under `COMPUTE OVERALL SCORE`.
final _generatorWeightPattern = RegExp(r'^\s*-\s+(.+?):\s*(\d+)%\s*$');

/// Parses the generator's numbered `## REPORT SECTIONS` list.
List<({int number, String title})> _generatorSections(String generator) {
  final lines = generator.split('\n');
  final start = lines.indexWhere((l) => l.trim() == '## REPORT SECTIONS');
  if (start == -1) return const [];
  final result = <({int number, String title})>[];
  for (var i = start + 1; i < lines.length; i++) {
    if (lines[i].startsWith('## ')) break;
    final m = _generatorSectionPattern.firstMatch(lines[i]);
    if (m != null) {
      result.add((number: int.parse(m.group(1)!), title: m.group(2)!.trim()));
    }
  }
  return result;
}

/// Parses the generator's `COMPUTE OVERALL SCORE` percentages.
Map<String, double> _generatorWeights(String generator) {
  final lines = generator.split('\n');
  final start = lines.indexWhere((l) => l.contains('COMPUTE OVERALL SCORE'));
  if (start == -1) return const {};
  final weights = <String, double>{};
  for (var i = start + 1; i < lines.length; i++) {
    if (RegExp(r'^\d+\.\s+\*\*').hasMatch(lines[i])) break; // next numbered step
    final m = _generatorWeightPattern.firstMatch(lines[i]);
    if (m != null) weights[m.group(1)!.trim()] = double.parse(m.group(2)!);
  }
  return weights;
}

/// A numbered `## N. Title` heading and the (0-based) line it starts on.
class _Heading {
  _Heading(this.number, this.title, this.lineIndex);
  final int number;
  final String title;
  final int lineIndex;
}

final _numberedHeadingPattern = RegExp(r'^## (\d+)\.\s+(.+?)\s*$');

List<_Heading> _numberedHeadings(List<String> lines) {
  final result = <_Heading>[];
  for (var i = 0; i < lines.length; i++) {
    final match = _numberedHeadingPattern.firstMatch(lines[i]);
    if (match != null) {
      result.add(_Heading(int.parse(match.group(1)!), match.group(2)!, i));
    }
  }
  return result;
}

/// Returns the [start, end) line range of the section whose heading line is
/// exactly [headingLine] — up to (but excluding) the next `## ` heading
/// line, or the end of the file if there is none.
({int start, int end}) _sectionRange(List<String> lines, String headingLine) {
  final start = lines.indexOf(headingLine);
  if (start == -1) {
    throw StateError('heading not found: "$headingLine"');
  }
  var end = lines.length;
  for (var i = start + 1; i < lines.length; i++) {
    if (lines[i].startsWith('## ')) {
      end = i;
      break;
    }
  }
  return (start: start, end: end);
}

/// Parses the `| Section | Weight |` rows out of the Appendix: Scoring
/// Methodology block, keyed by row label (with any `**bold**` stripped),
/// excluding the header/separator rows and the `Total` row. Weight values
/// are percentages with a trailing `%` (e.g. `20%`) — stripped before
/// parsing, unlike the health-audit family's decimal weights.
Map<String, double> _parseWeightRows(List<String> sectionLines) {
  final weights = <String, double>{};
  for (final line in sectionLines) {
    if (!line.trimLeft().startsWith('|')) continue;
    final cells = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    if (cells.length != 2) continue;
    final label = cells[0].replaceAll('*', '').trim();
    final rawValue = cells[1].replaceAll('*', '').replaceAll('%', '').trim();
    final value = double.tryParse(rawValue);
    if (value == null) continue; // header row ("Section"/"Weight") or the '---' separator
    if (label == 'Total') continue;
    weights[label] = value;
  }
  return weights;
}

/// Parses the row labels (column 1) out of a `| Section | Score | Label |`
/// table in section order, excluding the header/separator rows and the
/// `**Weighted Overall**` row.
List<String> _parseScoreBreakdownLabels(List<String> sectionLines) {
  final labels = <String>[];
  for (final line in sectionLines) {
    if (!line.trimLeft().startsWith('|')) continue;
    final cells = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    if (cells.length != 3) continue;
    final label = cells[0].replaceAll('*', '').trim();
    if (label == 'Section') continue; // header row
    if (label.replaceAll('-', '').isEmpty) continue; // '---------' separator
    if (label == 'Weighted Overall') continue;
    labels.add(label);
  }
  return labels;
}

void main() {
  final content = {for (final s in _stacks) s: File(_templatePath(s)).readAsStringSync()};
  final generators = {
    for (final s in _stacks) s: File(_generatorPath(s)).readAsStringSync(),
  };
  final lines = {for (final s in _stacks) s: content[s]!.split('\n')};
  final headings = {for (final s in _stacks) s: _numberedHeadings(lines[s]!)};

  group('best-practices report-template.md drift check (unified skeleton)', () {
    group('invariant 1: numbered headings run 1..N with no gaps or duplicates '
        '(N is per-skill)', () {
      for (final stack in _stacks) {
        test(stack, () {
          final numbers = headings[stack]!.map((h) => h.number).toList();
          final n = numbers.length;
          expect(
            numbers,
            List.generate(n, (i) => i + 1),
            reason: '${_skillLabel(stack)}: expected numbered headings 1..$n in order '
                'with no gaps or duplicates, found $numbers',
          );
          expect(
            n,
            _expectedSectionCount[stack],
            reason: '${_skillLabel(stack)}: expected ${_expectedSectionCount[stack]} '
                'numbered sections (verified against the file at authoring time), '
                'found $n. If this is a deliberate change to the section list, update '
                'both this test and docs/report-template-canonical.md\'s expectations '
                'for "$stack" — do not just widen the count.',
          );
        });
      }
    });

    group('invariant 2: section 1 = Executive Summary, section 2 = Score '
        'Breakdown, last two = Prioritized Recommendations then Evidence Index, '
        'stack-variable middle matches the scored sections that skill actually '
        'has analysis references for', () {
      for (final stack in _stacks) {
        test(stack, () {
          final titles = headings[stack]!.map((h) => h.title).toList();
          expect(
            titles.length >= 4,
            isTrue,
            reason: '${_skillLabel(stack)}: too few numbered sections to have a '
                'head/tail shape ($titles)',
          );

          expect(titles.first, 'Executive Summary',
              reason: '${_skillLabel(stack)}: section 1 diverged, found "${titles.first}"');
          expect(titles[1], 'Score Breakdown',
              reason: '${_skillLabel(stack)}: section 2 diverged, found "${titles[1]}"');
          expect(titles[titles.length - 2], 'Prioritized Recommendations',
              reason: '${_skillLabel(stack)}: second-to-last numbered section diverged, '
                  'found "${titles[titles.length - 2]}"');
          expect(titles.last, 'Evidence Index',
              reason: '${_skillLabel(stack)}: last numbered section diverged, '
                  'found "${titles.last}"');

          final middle = titles.sublist(2, titles.length - 2);
          expect(
            middle,
            _expectedScoredSections[stack],
            reason: '${_skillLabel(stack)}: stack-variable scored-section middle '
                'diverged from what this skill\'s references/ actually analyzes.\n'
                '  expected: ${_expectedScoredSections[stack]}\n'
                '  found:    $middle\n'
                'This is stack-variable by design, but the set must match this '
                'skill\'s own analysis references — not another skill\'s.',
          );
        });
      }
    });

    group('invariant 3: the literal heading form "## Section " never appears '
        '(it was flutter\'s pre-unification heading and is retired)', () {
      for (final stack in _stacks) {
        test(stack, () {
          final matches = lines[stack]!.where((l) => l.startsWith('## Section ')).toList();
          expect(
            matches,
            isEmpty,
            reason: '${_skillLabel(stack)}: found a literal "## Section " heading '
                '$matches — that heading form belonged to flutter\'s old skeleton '
                '(before it was unified onto "## N. Title" numbered headings) and '
                'must not reappear',
          );
        });
      }
    });

    group('invariant 4: exactly one "## 2. Score Breakdown" table with header '
        '"| Section | Score | Label |", a **Weighted Overall** row, and no Weight '
        'column', () {
      for (final stack in _stacks) {
        test(stack, () {
          final fileLines = lines[stack]!;
          final headingCount = fileLines.where((l) => l == '## 2. Score Breakdown').length;
          expect(
            headingCount,
            1,
            reason: '${_skillLabel(stack)}: expected exactly one '
                '"## 2. Score Breakdown" heading, found $headingCount',
          );

          final range = _sectionRange(fileLines, '## 2. Score Breakdown');
          final bodyLines = fileLines.sublist(range.start, range.end);
          final body = bodyLines.join('\n');

          final headerRowCount = bodyLines.where((l) => l == '| Section | Score | Label |').length;
          expect(
            headerRowCount,
            1,
            reason: '${_skillLabel(stack)}: expected exactly one '
                '"| Section | Score | Label |" header row in the Score Breakdown '
                'table, found $headerRowCount',
          );

          expect(
            body.contains('**Weighted Overall**'),
            isTrue,
            reason: '${_skillLabel(stack)}: Score Breakdown table is missing its '
                '"**Weighted Overall**" row',
          );

          // No table row in this section may carry a 4th column (a "Weight"
          // column) — weights live only in the Appendix: Scoring
          // Methodology. Checked by column count rather than a "Weight"
          // substring search, since "**Weighted Overall**" itself contains
          // the substring "Weight".
          for (final line in bodyLines) {
            if (!line.trimLeft().startsWith('|')) continue;
            final cells = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
            if (cells.isEmpty) continue;
            expect(
              cells.length,
              3,
              reason: '${_skillLabel(stack)}: Score Breakdown table row "$line" has '
                  '${cells.length} columns, expected 3 ("Section", "Score", "Label") — '
                  'weights must not appear as a column here, only in the Appendix: '
                  'Scoring Methodology',
            );
          }
        });
      }
    });

    group('invariant 5: scoring-legend blockquote is byte-identical, en dash + '
        'middle dot, exactly once', () {
      for (final stack in _stacks) {
        test(stack, () {
          final fileLines = lines[stack]!;
          final matches = fileLines.where((l) => l == _scoringLegend).length;
          expect(
            matches,
            1,
            reason: '${_skillLabel(stack)}: expected exactly one occurrence of the '
                'canonical scoring-legend line (with U+2013 en dash and U+00B7 '
                'middle dot):\n  $_scoringLegend\nbut found $matches. Check for '
                'plain ASCII hyphens/dots or reworded text.',
          );
        });
      }
    });

    group('invariant 6: /100 scale — no bare "/10" that is not part of "/100" '
        '(D1: every scored section in this family reports on a /100 scale with '
        'the standard Strong/Fair/Weak bands)', () {
      for (final stack in _stacks) {
        test(stack, () {
          final c = content[stack]!;
          final matches = _bareOutOfTen.allMatches(c).map((m) => m.group(0)).toList();
          expect(
            matches,
            isEmpty,
            reason: '${_skillLabel(stack)}: found a bare "/10" occurrence not part of '
                '"/100" at ${_bareOutOfTen.allMatches(c).map((m) => m.start).toList()} '
                '— every scored section in this unified skeleton scores on /100, '
                'never the old /10 scale',
          );
        });
      }
    });

    group('invariant 7: exactly one unnumbered "## Appendix: Scoring '
        'Methodology" and one "## Report Metadata", in that order, both after '
        'the last numbered section, neither matched as a numbered heading', () {
      for (final stack in _stacks) {
        test(stack, () {
          final c = content[stack]!;
          final fileLines = lines[stack]!;
          final lastHeading = headings[stack]!.last;

          final scoringCount =
              fileLines.where((l) => l == '## Appendix: Scoring Methodology').length;
          expect(
            scoringCount,
            1,
            reason: '${_skillLabel(stack)}: expected exactly one unnumbered '
                '"## Appendix: Scoring Methodology" heading, found $scoringCount',
          );
          final metadataCount = fileLines.where((l) => l == '## Report Metadata').length;
          expect(
            metadataCount,
            1,
            reason: '${_skillLabel(stack)}: expected exactly one unnumbered '
                '"## Report Metadata" heading, found $metadataCount',
          );

          final lastHeadingIdx = c.indexOf('## ${lastHeading.number}. ${lastHeading.title}');
          final scoringIdx = c.indexOf('## Appendix: Scoring Methodology');
          final metadataIdx = c.indexOf('## Report Metadata');
          expect(
            lastHeadingIdx < scoringIdx && scoringIdx < metadataIdx,
            isTrue,
            reason: '${_skillLabel(stack)}: expected order last numbered section '
                '("## ${lastHeading.number}. ${lastHeading.title}") → '
                '"Appendix: Scoring Methodology" → "Report Metadata", found offsets '
                '$lastHeadingIdx, $scoringIdx, $metadataIdx',
          );

          final numberedTitles = headings[stack]!.map((h) => h.title).toSet();
          expect(
            numberedTitles.contains('Appendix: Scoring Methodology'),
            isFalse,
            reason: '${_skillLabel(stack)}: "Appendix: Scoring Methodology" must stay '
                'unnumbered (no "## N." prefix)',
          );
          expect(
            numberedTitles.contains('Report Metadata'),
            isFalse,
            reason: '${_skillLabel(stack)}: "Report Metadata" must stay unnumbered '
                '(no "## N." prefix)',
          );
        });
      }
    });

    group('invariant 8: Appendix weight rows parse, sum to exactly 100, and their '
        'labels match that skill\'s own Score Breakdown row labels exactly and in '
        'the same order (catches a weight table copied from the wrong sibling '
        'skill)', () {
      for (final stack in _stacks) {
        test(stack, () {
          final fileLines = lines[stack]!;

          final appendixRange = _sectionRange(fileLines, '## Appendix: Scoring Methodology');
          final weights = _parseWeightRows(fileLines.sublist(appendixRange.start, appendixRange.end));
          expect(
            weights.isNotEmpty,
            isTrue,
            reason: '${_skillLabel(stack)}: could not parse any "| Section | Weight |" '
                'rows out of Appendix: Scoring Methodology',
          );

          final sum = weights.values.fold<double>(0, (a, b) => a + b);
          expect(
            sum,
            closeTo(100, 0.001),
            reason: '${_skillLabel(stack)}: Appendix weights sum to $sum, expected '
                '100. Rows: $weights',
          );

          final scorecardRange = _sectionRange(fileLines, '## 2. Score Breakdown');
          final scorecardLabels =
              _parseScoreBreakdownLabels(fileLines.sublist(scorecardRange.start, scorecardRange.end));
          final appendixLabelsInOrder = <String>[];
          for (final line in fileLines.sublist(appendixRange.start, appendixRange.end)) {
            if (!line.trimLeft().startsWith('|')) continue;
            final cells = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
            if (cells.length != 2) continue;
            final label = cells[0].replaceAll('*', '').trim();
            if (double.tryParse(cells[1].replaceAll('*', '').replaceAll('%', '').trim()) == null) {
              continue;
            }
            if (label == 'Total') continue;
            appendixLabelsInOrder.add(label);
          }

          expect(
            appendixLabelsInOrder,
            scorecardLabels,
            reason: '${_skillLabel(stack)}: Appendix: Scoring Methodology row labels '
                'diverged from this skill\'s own Score Breakdown row labels.\n'
                '  Score Breakdown labels: $scorecardLabels\n'
                '  Appendix labels:        $appendixLabelsInOrder\n'
                'A weight table copied from a sibling skill would fail exactly this '
                'check.',
          );
        });
      }
    });

    group('invariant 9: each skill\'s appendix maps each section label to its '
        'own expected weight (catches both a weight set cross-applied from a '
        'sibling skill and two weights transposed within one skill)', () {
      for (final stack in _stacks) {
        test(stack, () {
          final fileLines = lines[stack]!;
          final range = _sectionRange(fileLines, '## Appendix: Scoring Methodology');
          final weights = _parseWeightRows(fileLines.sublist(range.start, range.end));
          final expected = _expectedWeights[stack]!;

          // Compared as label -> weight PAIRS, deliberately not as a sorted
          // multiset of values. A multiset comparison cannot see two weights
          // swapped between two labels within the same skill (the sorted
          // values, the label set, the row order and the sum to 100 are all
          // unchanged by such a swap) — and for flutter that particular
          // mutation would silently invert decision D2, which deliberately
          // weights Architecture Compliance ABOVE Testing Quality.
          expect(
            weights,
            expected,
            reason: '${_skillLabel(stack)}: appendix weights diverged from the '
                'expected label -> weight mapping for "$stack".\n'
                '  expected: $expected\n'
                '  found:    $weights\n'
                'Every skill keeps its own weights. Two causes to check: a weight '
                'set cross-applied from a sibling skill '
                '(${_stacks.where((s) => s != stack).toList()}), or two weights '
                'transposed between sections within this skill — the second still '
                'sums to 100 and still uses the right numbers, so only this '
                'per-label check catches it.',
          );
        });
      }
    });

    // ---------------------------------------------------------------------
    // The template is NOT what the runner feeds the model. On the
    // `somnio run` path the operative instruction is
    // `references/best-practices-generator.md`, and a produced report follows
    // ITS section list. Adding a block to the template while leaving the
    // generator's list untouched yields a report missing that block — which
    // is exactly how the Appendix: Scoring Methodology silently failed to
    // appear in a real run. Invariants 10-12 guard that file too.
    // ---------------------------------------------------------------------

    group('invariant 10: the generator\'s REPORT SECTIONS list matches the '
        'template\'s numbered sections, in number and name and order', () {
      for (final stack in _stacks) {
        test(stack, () {
          final sections = _generatorSections(generators[stack]!);
          expect(
            sections,
            isNotEmpty,
            reason: '${_generatorLabel(stack)}: could not parse a numbered '
                '"## REPORT SECTIONS" list',
          );

          final templateTitles = headings[stack]!.map((h) => h.title).toList();
          final generatorTitles = sections.map((e) => e.title).toList();

          expect(
            generatorTitles.length,
            templateTitles.length,
            reason: '${_generatorLabel(stack)}: lists ${generatorTitles.length} '
                'numbered sections but the template renders '
                '${templateTitles.length}.\n'
                '  generator: $generatorTitles\n'
                '  template:  $templateTitles\n'
                'The generator drives what a produced report contains, so the '
                'two must agree.',
          );

          for (var i = 0; i < templateTitles.length; i++) {
            expect(
              generatorTitles[i].toUpperCase(),
              templateTitles[i].toUpperCase(),
              reason: '${_generatorLabel(stack)}: section ${i + 1} is '
                  '"${generatorTitles[i]}" in the generator but '
                  '"${templateTitles[i]}" in the template. A produced report '
                  'follows the generator, so this divergence ships.',
            );
          }

          expect(
            sections.map((e) => e.number).toList(),
            List.generate(templateTitles.length, (i) => i + 1),
            reason: '${_generatorLabel(stack)}: REPORT SECTIONS numbering has '
                'a gap or duplicate: ${sections.map((e) => e.number).toList()}',
          );
        });
      }
    });

    group('invariant 11: the generator also specifies the two unnumbered '
        'closing blocks (Appendix: Scoring Methodology, Report Metadata)', () {
      for (final stack in _stacks) {
        test(stack, () {
          final g = generators[stack]!;
          expect(
            g.toUpperCase().contains('APPENDIX: SCORING METHODOLOGY'),
            isTrue,
            reason: '${_generatorLabel(stack)}: does not mention '
                '"Appendix: Scoring Methodology". The template having the block '
                'is not enough — a report generated from this file would omit '
                'it entirely, which is how it silently went missing before.',
          );
          expect(
            g.toUpperCase().contains('REPORT METADATA'),
            isTrue,
            reason: '${_generatorLabel(stack)}: does not mention '
                '"Report Metadata", so a produced report may close with a '
                'plain-text block instead of the "| Field | Value |" table the '
                'template renders.',
          );
        });
      }
    });

    group('invariant 12: the generator\'s COMPUTE OVERALL SCORE weights match '
        'the template appendix per label, and sum to 100', () {
      for (final stack in _stacks) {
        test(stack, () {
          final genWeights = _generatorWeights(generators[stack]!);
          expect(
            genWeights,
            isNotEmpty,
            reason: '${_generatorLabel(stack)}: could not parse a '
                '"COMPUTE OVERALL SCORE" weight list. Without it the overall '
                'score is not reproducible between two runs.',
          );

          final sum = genWeights.values.fold<double>(0, (a, b) => a + b);
          expect(
            sum,
            closeTo(100, 0.001),
            reason: '${_generatorLabel(stack)}: weights sum to $sum, expected '
                '100. Rows: $genWeights',
          );

          final fileLines = lines[stack]!;
          final range = _sectionRange(fileLines, '## Appendix: Scoring Methodology');
          final appendixWeights =
              _parseWeightRows(fileLines.sublist(range.start, range.end));

          expect(
            genWeights,
            appendixWeights,
            reason: '${_generatorLabel(stack)}: the weights it declares differ '
                'from the ones the template appendix renders to the reader.\n'
                '  generator: $genWeights\n'
                '  appendix:  $appendixWeights\n'
                'The appendix bills itself as a read-only summary of the '
                'generator, so the two drifting apart makes the report lie '
                'about how its own score was computed.',
          );
        });
      }
    });
  });
}
